--[[
    A more advanced implimentation of lua patterns
    Included tokens are:
        .       - Any character
        %a      - Any letter
        %c      - Any control character
        %d      - Any digit
        %l      - Any lower case letter
        %p      - Any punctuation character
        %s      - Any space character
        %u      - Any upper case letter
        %w      - Any alphanumeric character
        %x      - Any hexadecimal digit
        %z      - The character with representation 0
        ^       - Start of string
        $       - End of string
        [set]   - Any character in set
        [^set]  - Any character not in set
        ()      - Capture group
        *       - 0 or more
        +       - 1 or more
        -       - 0 or more, ungreedy
        ?       - 0 or 1
        %n      - The n-th capture group
        %b()    - Balanced capture group
        %f[set] - Frontier pattern
        |       - Alternation
]]

-- Convert a string into a pattern table
-- EG "abc" -> {{type="literal", value="abc"}}
-- Or "(hi|there)" -> {{type="alternation", first={{type="literal", value="hi"}}, second={{type="literal", value="there"}}}
local _string = string
local sfind = oldString.find
local sgsub = oldString.gsub
local string = oldString
local byte = oldString.byte
local char = oldString.char
local min = math.min
local max = math.max
local function compile(pattern)
    local matchid = 1
    local classes = {
        a = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        c = "\0\1\2\3\4\5\6\7\8\9\10\11\12\13\14\15\16\17\18\19\20\21\22\23\24\25\26\27\28\29\30\31",
        d = "0123456789",
        l = "abcdefghijklmnopqrstuvwxyz",
        p = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
        s = " \t\n\r\v\f",
        u = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        w = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
        x = "0123456789ABCDEFabcdef",
        z = "\0"
    }
    -- Negative Classes
    for k, v in pairs(classes) do
        local s = ""
        for i=0, 255 do
            local c = string.char(i)
            if not sfind(v, c, 1, true) then
                s = s .. c
            end
        end
        classes[string.upper(k)] = s
    end
    local tokens = {}
    local i = 1
    local function next()
        local s = pattern:sub(i, i)
        i = i + 1
        return s
    end
    local function peek()
        return pattern:sub(i, i)
    end
    local function has()
        return i <= #pattern
    end
    local tokensStack = {}
    local function pushTokens()
        table.insert(tokensStack, tokens)
        tokens = {}
    end
    local function popTokens()
        local t = tokens
        tokens = table.remove(tokensStack)
        return t
    end

    local function set(chars, invert)
        local sanitizedChars = ""
        for i=1, 255 do
            local c = string.char(i)
            if not sfind(chars, c, 1, true) == invert then
                sanitizedChars = sanitizedChars .. c
            end
        end
        tokens[#tokens+1] = {type="set", value=sanitizedChars}
    end
    local function literal(char)
        tokens[#tokens+1] = {type="literal", value=char}
    end
    local function alternation(first, second)
        tokens[#tokens+1] = {type="alternation", first=first, second=second}
    end
    local function captureGroup(toks)
        tokens[#tokens+1] = {type="captureGroup", tokens=toks, id=matchid}
        matchid = matchid + 1
    end
    local function counted(token, min, max, greedy)
        tokens[#tokens+1] = {type="counted", token=token, min=min, max=max, greedy=greedy}
    end
    local function anchor(start)
        tokens[#tokens+1] = {type="anchor", start=start}
    end
    
    local parseToken;
    local parseSet;
    local parsePercent;
    local parseCaptureGroup;
    local parseCaptureGroupReference;
    local parseAlternation;
    local parseCounted;
    local parseBalancedCaptureGroup;
    local parseFrontierPattern;

    parseToken = function()
        local c = next()
        if c == "%" then
            parsePercent()
        elseif c == "[" then
            parseSet()
        elseif c == "]" then
            error("Unexpected character ']'")
        elseif c == "(" then
            parseCaptureGroup()
        elseif c == ")" then
            error("Unexpected character ')'")
        elseif c == "*" then
            parseCounted(0, math.huge, true)
        elseif c == "+" then
            parseCounted(1, math.huge, true)
        elseif c == "-" then
            parseCounted(0, math.huge, false)
        elseif c == "?" then
            parseCounted(0, 1, false)
        elseif c == "|" then
            parseAlternation()
        elseif c == "." then
            set("\0\r\n", true)
        elseif c == '^' then
            anchor(true)
        elseif c == '$' then
            anchor(false)
        else
            -- If the previous token is also a literal, append this
            local last = tokens[#tokens]
            if last and last.type == "literal" then
                last.value = last.value .. c
            else
                literal(c)
            end
        end
    end
    parseSet = function()
        local s = ""
        local invert = false
        if peek() == "^" then
            invert = true
            next()
        end
        while has() and peek() ~= "]" do
            if peek() == "%" then
                next()
                local c = next()
                if classes[c] then
                    s = s .. classes[c]
                else
                    s = s .. c
                end
            elseif peek() == '-' then
                if #s == 0 then
                    s = s .. next()
                else
                    next()
                    local last = s:sub(#s, #s)
                    if peek() == ']' then
                        s = s .. '-'
                    else
                        local c1, c2 = byte(last), byte(next())
                        for i=min(c1,c2), max(c1,c2) do
                            s = s .. char(i)
                        end
                    end
                end
            else
                s = s .. next()
            end
        end
        next()
        set(s, invert)
    end
    parsePercent = function()
        local c = next()
        if c == "b" then
            parseBalancedCaptureGroup()
        elseif c == "f" then
            parseFrontierPattern()
        elseif classes[c] then
            set(classes[c], false)
        elseif sfind(classes.d, c, 1, true) then
            parseCaptureGroupReference(c)
        else
            literal(c)
        end
    end
    parseCaptureGroup = function()
        pushTokens()
        while has() and peek() ~= ")" do
            parseToken()
        end
        next()
        captureGroup(popTokens())
    end
    parseCaptureGroupReference = function(c)
        local index = tonumber(c)
        if not index then
            error("Expected number after % (got '" .. c .."')")
        end
        tokens[#tokens+1] = {type="captureGroupReference", index=index}
    end
    parseAlternation = function()
        local first = tokens
        tokens = {}
        pushTokens()
        while has() and peek() ~= ")" do
            parseToken()
        end
        second = popTokens()
        alternation(first, second)
    end
    parseCounted = function(min, max, greedy)
        local t = tokens[#tokens]
        if not t then
            error("Unexpected counted token")
        end
        table.remove(tokens, #tokens)
        counted(t, min, max, greedy)
    end
    parseBalancedCaptureGroup = function()
        local start = next()
        local endc = next()
        tokens[#tokens] = {type="balancedCaptureGroup", start = start, endc = endc}
    end
    parseFrontierPattern = function()
        next()
        local set = ""
        local invert = false
        if peek() == "^" then
            invert = true
            next()
        end
        while peek() ~= "]" do
            if peek() == "%" then
                next()
                local c = next()
                if classes[c] then
                    set = set .. classes[c]
                else
                    set = set .. c
                end
            else
                set = set .. next()
            end
        end
        next()
        tokens[#tokens] = {type="frontierPattern", value=set, invert=invert}
    end
    while i <= #pattern do
        parseToken()
    end
    return tokens, matchid ~= 1
end

local pmatch = function(haystack, pattern, start)
    local start = start or 1
    local tokens = pattern
    local matches = {}
    if start > #haystack then
        return nil
    end

    local i = start
    local stack = {}
    local function next()
        local c = haystack:sub(i, i)
        i = i + 1
        return c
    end
    local function peek()
        return haystack:sub(i, i)
    end
    local function push()
        table.insert(stack, i)
    end
    local function pop()
        i = table.remove(stack)
    end
    local function forget()
        return table.remove(stack)
    end

    local match;
    local matchSet;
    local matchCaptureGroup;
    local matchTokens;

    -- Returns the length of the match if successful, or nil otherwise
    match = function(chunk)
        push()
        local len = 0
        for i = 1, #chunk do
            if next() ~= chunk:sub(i, i) then
                pop()
                return nil
            end
            len = len + 1
        end
        forget()
        return len
    end
    matchSet = function(set)
        local c = peek()
        if not sfind(set.value, c, 1, true) then
            return nil
        end
        next()
        return c
    end
    matchCaptureGroup = function(toks)
        if #toks.tokens == 0 then
            matches[toks.id] = i
            return 0
        end
        local start = i
        local endp = matchTokens(toks.tokens)
        if not endp then
            return nil
        end
        matches[toks.id] = haystack:sub(start, endp)
        return endp - start + 1
    end
    matchTokens = function(toks)
        local tokid = 1
        local start = i
        if i > #haystack then
            return nil
        end
        local backtrack = {}
        local function trybacktrack()
            repeat
                if #backtrack == 0 then
                    return false
                end
                local top = table.remove(backtrack, #backtrack)
            until top()
            return true
        end
        while tokid <= #toks do
            local function onbacktrack(method)
                local curtok = tokid
                backtrack[#backtrack+1] = function()
                    tokid = curtok
                    return method()
                end
            end
            local tok = toks[tokid]
            if tok.type == "literal" then
                if not match(tok.value) then
                    if trybacktrack() then
                        goto continue
                    else
                        return nil
                    end
                end
            elseif tok.type == "set" then
                if not matchSet(tok) then
                    if trybacktrack() then
                        goto continue
                    else
                        return nil
                    end
                end
            elseif tok.type == "alternation" then
                local oldMatches = {}
                for k, v in pairs(matches) do
                    oldMatches[k] = v
                end
                local first = matchTokens(tok.first)
                if first then
                    return first
                end
                matches = oldMatches
                local second = matchTokens(tok.second)
                if second then
                    return second
                end
                if trybacktrack() then
                    goto continue
                else
                    return nil
                end
            elseif tok.type == "captureGroup" then
                if not matchCaptureGroup(tok) then
                    if trybacktrack() then
                        goto continue
                    else
                        return nil
                    end
                end
            elseif tok.type == "counted" then
                if not tok.greedy then
                    local count = 0
                    while count < tok.min do
                        if i > #haystack then
                            if trybacktrack() then
                                goto continue
                            else
                                return nil
                            end
                        end
                        local len = matchTokens{tok.token}
                        if not len then
                            if trybacktrack() then
                                goto continue
                            else
                                return nil
                            end
                        end
                        count = count + 1
                    end
                    local retry
                    local tryfrom = i
                    retry = function()
                        i = tryfrom
                        local len = matchTokens{tok.token}
                        if not len then
                            return trybacktrack()
                        end
                        tryfrom = i
                        count = count + 1
                        onbacktrack(retry)
                        return true
                    end
                    onbacktrack(retry)
                else
                    local count = 0
                    while count < tok.min do
                        if i > #haystack then
                            if trybacktrack() then
                                goto continue
                            else
                                return nil
                            end
                        end
                        local len = matchTokens{tok.token}
                        if not len then
                            if trybacktrack() then
                                goto continue
                            else
                                return nil
                            end
                        end
                        count = count + 1
                    end
                    local tryfrom = {i}
                    while count < tok.max do
                        if i > #haystack then
                            break
                        end
                        local len = matchTokens{tok.token}
                        if not len then
                            break
                        end
                        count = count + 1
                        if i < #haystack then
                            tryfrom[#tryfrom+1] = i
                        end
                    end
                    local retry
                    retry = function()
                        if #tryfrom == 0 then
                            return false
                        end
                        i = table.remove(tryfrom, #tryfrom)
                        onbacktrack(retry)
                        return true
                    end
                    onbacktrack(retry)
                end
            elseif tok.type == "anchor" then
                if tok.start then
                    if i ~= 1 then
                        if trybacktrack() then
                            goto continue
                        else
                            return nil
                        end
                    end
                else
                    if i <= #haystack then
                        if trybacktrack() then
                            goto continue
                        else
                            return nil
                        end
                    end
                end
            elseif tok.type == "captureGroupReference" then
                local m = matches[tok.index]
                if not m then
                    if trybacktrack() then
                        goto continue
                    else
                        return nil
                    end
                end
                if not match(m) then
                    if trybacktrack() then
                        goto continue
                    else
                        return nil
                    end
                end
            elseif tok.type == "balancedCaptureGroup" then
                local count = 1
                while count > 0 do
                    local c = next()
                    if c == tok.start then
                        count = count + 1
                    elseif c == tok.endc then
                        count = count - 1
                    elseif not c then
                        if trybacktrack() then
                            goto continue
                        else
                            return nil
                        end
                    end
                end
            elseif tok.type == "frontierPattern" then
                local c = peek()
                if not sfind(tok.value, sgsub(c,"%p","%%%0"), 1, true) then
                    if trybacktrack() then
                        goto continue
                    else
                        return nil
                    end
                end
                next()
                local c = peek()
                if not sfind(tok.value, sgsub(c,"%p","%%%0"), 1, true) then
                    if trybacktrack() then
                        goto continue
                    else
                        return nil
                    end
                end
                next()
            else
                error("Unknown token type: " .. tok.type)
            end
            ::continue::
            tokid = tokid + 1
        end
        return i - 1
    end

    -- Search for the pattern, doing i, i+1, i+2, etc
    local p = start
    while p <= #haystack do
        i = p
        local endp = matchTokens(tokens)
        if endp then
            matches[0] = haystack:sub(p, endp)
            return matches, p, endp
        end
        p = p + 1
    end
    return nil
end

_G.match = wrap(function(haystack, needle, start)
    start = start or 1
    local p, hasGroups = compile(needle)
    local matches, start, endp = pmatch(haystack, p, start)
    if not matches then
        return nil
    end
    if hasGroups then
        local maxIndex = 0
        for k, v in pairs(matches) do
            if type(k) == "number" then
                maxIndex = math.max(maxIndex, k)
            end
        end
        for i = 0, maxIndex do
            if not matches[i] then
                matches[i] = ""
            end
        end
        return table.unpack(matches)
    else
        return matches[0]
    end
    return nil
end, "match", 2)

_string.match = _G.match

_G.find = wrap(function(haystack, needle, start)
    start = start or 1
    local matches, start, endp = pmatch(haystack, compile(needle), start)
    if matches then
        return start, endp
    else
        return nil
    end
end, "find", 2)

_string.find = _G.find

_G.gmatch = wrap(function(haystack, needle)
    local matches = {}
    local start = 1
    local p, hasGroups = compile(needle)
    return function()
        local m, s, e = pmatch(haystack, p, start)
        if not m then
            return
        end
        start = e + 1
        if hasGroups then
            local maxIndex = 0
            for k, v in pairs(m) do
                if type(k) == "number" then
                    maxIndex = math.max(maxIndex, k)
                end
            end
            for i = 0, maxIndex do
                if not m[i] then
                    m[i] = ""
                end
            end
            return table.unpack(m)
        else
            return m[0]
        end
    end
end, "gmatch", 2)

_string.gmatch = _G.gmatch

_G.gsub = wrap(function(haystack, needle, replace, limit)
    local matches = {}
    local start = 1
    local count = 0
    local out = ""
    if isEq(replace) then
        replace = makeFunky(replace)
    end
    local p, hasGroups = compile(needle)
    while true do
        local m, s, e = pmatch(haystack, p, start)
        if not m then
            break
        end
        count = count + 1
        if limit and count > limit then
            break
        end
        -- Append everything up to the new start
        out = out .. haystack:sub(start, s - 1)
        start = e + 1
        if hasGroups then
            local maxIndex = 0
            for k, v in pairs(m) do
                if type(k) == "number" then
                    maxIndex = math.max(maxIndex, k)
                end
            end
            for i = 0, maxIndex do
                if not m[i] then
                    m[i] = ""
                end
            end
            if type(replace) == "function" then
                out = out .. replace(table.unpack(m))
            else
                out = out .. sgsub(replace, "%%(%d)", m)
            end
        else
            if type(replace) == "function" then
                out = out .. replace(m[0])
            else
                out = out .. sgsub(replace, "%%0", m[0])
            end
        end
    end
    out = out .. haystack:sub(start)
    return out, count
end, "gsub", 2)

_G.compile = compile
_G.pmatch = pmatch
_G.advancedstring = {
    match = match,
    gmatch = gmatch,
    gsub = gsub,
    compilepattern = compile,
    pmatch = pmatch
}
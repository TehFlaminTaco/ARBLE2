local _str = {
    rep = string.rep,
    sub = string.sub,
    gsub = string.gsub,
    match = string.match,
    gmatch = string.gmatch,
    format = string.format
}
local _load = load

local function getsegment(src, index)
    -- Return one of: "code", "comment", "string", "none"
    if index <= 0 or index > #src then
        return "none"
    end
    local i = 1
    local function next(match)
        if type(match) == 'table' then
            -- Search each match, return the next one.
            local minDist = math.huge;
            local minMatch = nil
            local minBody = nil
            for _, m in ipairs(match) do
                local p, b = _str.match(src, "()("..m..")", i)
                if p and p < minDist then
                    minDist = p
                    minMatch = m
                    minBody = b
                end
            end
            if minMatch then
                i = minDist + #minBody
                return minDist, _str.match(minBody, minMatch)
            end
            return nil
        end
        if match then
            local p, b = _str.match(src, '()('..match..')', i)
            if p then
                i = p + #b
                return p, _str.match(b, match)
            end
            return nil
        end
        if i <= #src then
            local s = _str.sub(src, i,i)
            i = i + 1
            return s
        end
        return nil
    end
    local function peek(match)
        if type(match) == 'table' then
            -- Search each match, return the next one.
            local minDist = math.huge;
            local minMatch = nil
            local minBody = nil
            for _, m in ipairs(match) do
                local p, b = _str.match(src, "()("..m..")", i)
                if p and p < minDist then
                    minDist = p
                    minMatch = m
                    minBody = b
                end
            end
            if minMatch then
                return minDist, _str.match(minBody, minMatch)
            end
        end
        if match then
            local p, b = _str.match(src, '()('..match..')', i)
            if p then
                return p, b
            end
            return nil
        end
        if i <= #src then
            return _str.sub(src, i,i)
        end
        return nil
    end
    local state = {type = "code"}
    local lastI = -1
    while i <= index do
        if i == lastI then
            error("We're stuck! " .. i)
        end
        if i >= index then
            return state.type
        end
        if state.type == 'code' then
            local nextChange, changeType = next{'"', "'", "%-%-%[=-%[", "%[=-%[", "%-%-"}
            if not nextChange or nextChange > index then
                return 'code'
            end
            if changeType == '"' or changeType == "'" then
                state = {type = 'string', endQoute = changeType}
            elseif _str.sub(changeType, 1,1) == '[' then
                local equals = _str.match(changeType, "%[(=-)%[")
                state = {type = 'string', endQoute = '%]' .. equals .. '%]'}
            elseif _str.sub(changeType, 1,3) == "--[" then
                local equals = _str.match(changeType, "%[(=-)%[")
                state = {type = 'comment', endQoute = '%]' .. equals .. '%]'}
            elseif changeType == '--' then
                state = {type = 'comment', endQoute = '\n'}
            else
                error("Uknown changetype: " .. changeType)
            end
        elseif state.type == 'string' then
            local nextChange, body = next('\\*'..state.endQoute)
            if not nextChange or nextChange > index then
                return 'string'
            end
            if #state.endQoute == 1 then
                local slashes = #_str.match(body, '\\*')
                if slashes%2 == 0 then
                    state = {type = 'code'}
                end
            else
                state = {type = 'code'}
            end
        elseif state.type == 'comment' then
            local nextChange, body = next('\\*' .. state.endQoute)
            if not nextChange or nextChange > index then
                return 'comment'
            end
            state = {type = 'code'}
        else
            error('Unknown state ' .. state.type)
        end
    end
    return state.type
end

local function funkyPass(str)
    -- Find all code instances of @{
    -- From there, depth count until we find the matching }
    -- Replace it with (function() end)
    local out = ""
    local i = 1
    while true do
        local isntPos = _str.match(str, "()%(@", i)
        if not isntPos then
            out = out .. _str.sub(str, i)
            return out
        end
        out = out .. _str.sub(str, i, isntPos - 1)
        i = isntPos + 2
        if getsegment(str, isntPos) == "code" then
            local d = 1
            local codeStart = i
            while true do
                local p, c = _str.match(str, "()([()])", i)
                if not p then
                    local _, c = _str.gsub(_str.sub(str, 1, codeStart), "\n", "")
                    -- Quickly search to the line
                    local lines = _str.gmatch(str, "([^\n]*)")
                    for i=1, c do
                        lines()
                    end
                    local line = _str.match(lines(), match("%s*(.*)%s-"))
                    error(_str.format('Unterminated lambda beginning at line %i %s...', c + 1, line))
                end
                i = p + 1
                if getsegment(str, p) == "code" then
                    -- If it's a {, increase d
                    -- if it's a }, decrease
                    -- If d is 0, we're done 
                    if c == "(" then
                        d = d + 1
                    else
                        d = d - 1
                        if d == 0 then
                            break
                        end
                    end
                end
            end
            local codeBody = mutate(_str.sub(str, codeStart, i - 2))
            local compiled, err = _load("return (...)" .. codeBody)
            if compiled then
                codeBody = "return (...)" .. codeBody
            else
                compiled, err = _load("return " .. codeBody)
                if compiled then
                    codeBody = "return " .. codeBody
                else
                    compiled, err = _load('(...)' .. codeBody)
                    if compiled then
                        codeBody = '(...)' .. codeBody
                    end
                end
            end
            out = out .. '(function(...)' .. codeBody .. ' end)'
        else
            out = out .. "(@"
        end
    end
end

local function queryPass(str)
    return _str.gsub(str, "()%?=",function(p)
        if getsegment(str, p) == "code" then
            return "_PRINTRESULT = "
        else
            return "?="
        end
    end)
end

local function returnPass(str)
    return _str.gsub(_str.gsub(str, "()%.=",function(p)
        if getsegment(str, p) == "code" then
            return "return "
        else
            return ".="
        end
    end), "(([!\"#$%%&'()*+,-./:;?@\\^_`{|}])%s*()=%s*%f[^=])",function(o,c,p)
        if getsegment(str, p) == "code" then
            return c .. " return "
        else
            return o
        end
    end)
end

local function quickArgPass(str)
    -- Higher priority than funkyPass, replace (@) with ((...)), if the user wants a noop, they can do (@ )
    return _str.gsub(str, "()%(@%)", function(p)
        if getsegment(str, p) == "code" then
            return "((...))"
        else
            return "(@)"
        end
    end)
end

local function argPass(str)
    -- Replace spare instances of @ with (...)
    return _str.gsub(str, "()@(%d*)",function(p,n)
        if getsegment(str, p) == "code" then
            -- If immediately following the @ is a number, select that argument number
            if n and #n > 0 then
                return "(select(" .. n .. ", ...))"
            else
                return "(...)"
            end
        else
            return "@"
        end
    end)
end

local function quickCall(str)
    -- Replace all code instances of ! with ()
    return _str.gsub(str, "()%!",function(p)
        if getsegment(str, p) == "code" then
            return "()"
        else
            return "!"
        end
    end)
end

local function forof(str)
    return _str.gsub(str, "()for%f[%A](.-)()of%f[%A](.-)()do%f[%A]", function(i1,args,i2,target,i3)
        if getsegment(str,i1)~="code" or getsegment(str,i2)~="code" or getsegment(str,i3)~="code" then
            return "for" .. args .. "of" .. target .. "do"
        else
            return "for" .. args .. "in iter(" .. target .. ")() do"
        end
    end)
end

function mutate(str)
    str = quickArgPass(str)
    str = funkyPass(str)
    str = queryPass(str)
    str = returnPass(str)
    str = argPass(str)
    str = quickCall(str)
    str = forof(str)
    return str
end
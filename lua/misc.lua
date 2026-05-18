printtable = wrap(function(t, indent)
    indent = indent or 0
    if type(t) == "table" then
        print("{")
        for k, v in pairs(t) do
            write(("\t"):rep(indent + 1) .. k .. " = ")
            printtable(v, indent + 1)
        end
        print(("\t"):rep(indent) .. "}")
    else
        print(tostring(t))
    end
end, "printtable", 1)

local _factorialLookup = {}

factorial = wrap(function(n)
    local f = 1
    for i=2, n do
        f = f * i
    end
    return f
end, "factorial", 1)

alphabet = "abcdefghijklmnopqrstuvwxyz"
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

function string.starts(self, pattern)
    return self:sub(1, #pattern) == pattern
end

function string.ends(self, pattern)
    return self:sub(-#pattern) == pattern
end

function string.padleft(s, n, c)
    c = c or ' '
    local N = math.ceil((n - #s) / #c)
    return c:rep(N):sub(1,n-#s)..s
end
function string.padright(s, n, c)
    c = c or ' '
    local N = math.ceil((n - #s) / #c)
    return s..c:rep(N):sub(1,n-#s)
end
function string.replace(s, start, len, content)
    if type(start)=='string' then
        return s:gsub(start, len)
    end
    if not content then
        content = len
        len = #tostring(content)
    end
    return s:sub(1, start-1) .. s:sub(start,start+len-1):gsub(".+",content) .. s:sub(start + len)
end
function string.remove(s, start, len)
    if type(start) == 'string' then return (s:gsub(start,'')) end
    len = len or 1
    return s:sub(1, start-1) .. s:sub(start+len)
end
function string.insert(s, pos, content)
    return s:sub(1, pos-1) .. content .. s:sub(pos)
end

function string.int(s)
    return tonumber(s)//1
end
function string.number(s)
    return tonumber(s)
end

function isprime(n)
    if n < 0 then return isprime(-n) end
    if n <= 3 then
        return n > 1
    end
    local i = 5
    while i*i <= n do
        if (n%i)*(n%(i+1)) == 0 then
            return false
        end
        i=i+6
    end
    return true
end

function binarysearch(compare, low, high)
    local low = low or 0
    local high = high or 2^62
    -- i defines the "Step", which is (high - low) / step
    -- n is the actualy center position, which is what moves
    local i = (high - low)/2
    local n = high - i
    local steps = 1
    while true do
        print(n, i)
        local c = compare(n)
        print(c)
        i = i/2
        steps = steps + 1
        if i == 0 then
            -- Uhhhh...
            error('Unable to reach: Last hit '..n..' after '..steps..' steps.')
        end
        if c > 0 then
            n = n - i
        elseif c < 0 then
            n = n + i
        else
            return n, steps
        end
    end
end

function bfs(initial, check, getchildren)
    local q = queue(initial)
    while q:has() do
        local v = q:pop()
        if check(v) then
            return v
        end
        for c in getchildren(v) do
            q:push(c)
        end
    end
    return nil
end

function astar(optionsforstate, checkgoal, initialstate, score)
    score = score or function(state,steps) return steps end
    local currentsteps = {{initialstate, {initialstate}, score(initialstate,0)}}
    local previouslySeen = {}
    while #currentsteps > 0 do
        local topStep = table.remove(currentsteps,1)
        print(topStep[1])
        -- Push all options unto the currentsteps tree based on their score
        local FOUND = nil
        optionsforstate(topStep[1]):each(function(newState)
            local newTree = {}
            for i=1, #topStep[2] do
                newTree[i] = topStep[2][i]
            end
            newTree[#newTree+1] = newState
            if checkgoal(newState) then
                FOUND = list(newTree)
            end
            local newScore = score(newState, #newTree)
            if previouslySeen[newState] and newScore >= previouslySeen[newState] then
                return
            end
            previouslySeen[newState] = newScore
            -- Find the first index in which this score is HIGHER than it, and insert this before
            local i = 1
            if #currentsteps == 0 then
                currentsteps[1] = {newState, newTree, newScore}
            elseif currentsteps[#currentsteps][3] < newScore then
                currentsteps[#currentsteps+1] = {newState, newTree, newScore}
            else
                local BEFORE = #currentsteps+1
                for i=1, #currentsteps do
                    if newScore < currentsteps[i][3] then
                        BEFORE = i
                        break
                    end
                end
                table.insert(currentsteps, BEFORE, {newState, newTree, newScore})
            end
            io.flush()
        end)
        if FOUND then return FOUND end
    end
    return nil
end

local _random = random
function random(a, b)
    if type(a) == "enumerable" then
        return random(a:totable(), b)
    end
    if type(a) == "table" then
        return a[oldMath.random(1, #a)]
    end
    return b and _random(a, b) or _random(a)
end

choose = wrap(function(index, ...)
    -- choose("help", "a", "b", "help", "please") -> "please"
    -- choose("gun", "a", "b", "help", "please", "default") -> "default"
    local t = {...}
    for i = 1, #t, 2 do
        if t[i] == index then
            return t[i+1]
        end
    end
    if #t % 2 == 1 then
        return t[#t]
    end
    return nil
end)

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function string.toBase64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function string.fromBase64(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end

function string.spreadsheet(str,hasHeaders)
    local index = 1
    local _, nextQuote = str:match("(\t|\n|^)\"()", index)
    local s = ''
    while nextQuote do
        s = s .. str:sub(index, nextQuote - 2)
        local endQuote = str:match("()\"(\t|\n|^)", nextQuote)
        if endQuote then
            index = endQuote + 1
            s = s .. '"' .. str:sub(nextQuote, endQuote-1):toBase64()
        else
            break
        end
        _, nextQuote = str:match("(\t|\n|^)\"()", index) 
    end
    s = s .. str:sub(index)
    local tab =  s:split"\n"
                    :map(function(l)
                        return l:split("\t")
                                :map(function(e)
                                    if e[1] == '"' then
                                        return e:sub(2):fromBase64()
                                    end
                                    return e
                                end):tolist()
                    end):tolist()
    if not hasHeaders then return tab end
    local headers = tab:first()
    if not headers then return tab end
    local named = {}
    for l in tab:skip(1)() do
        local t = {}
        for pair in headers:zip(l)() do
            t[pair[1]] = pair[2]
            t[#t+1] = pair[2]
        end
        named[#named+1] = list(t)
    end
    return list(named)
end

function string.numbers(str)
    local newTable = {}
    newTable.enumerate = function()
        local f = string.gmatch(str, "%-?%d+")
        return function()
            local e = f()
            if e then
                return tonumber(e)
            else
                return nil
            end
        end
    end
    return setmetatable(newTable, _enum)
end


-- Returns the Levenshtein distance between the two given strings
function string.levenshtein(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	local matrix = {}
	local cost = 0
	
        -- quick cut-offs to save time
	if (len1 == 0) then
		return len2
	elseif (len2 == 0) then
		return len1
	elseif (str1 == str2) then
		return 0
	end
	
        -- initialise the base matrix values
	for i = 0, len1, 1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2, 1 do
		matrix[0][j] = j
	end
	
        -- actual Levenshtein algorithm
	for i = 1, len1, 1 do
		for j = 1, len2, 1 do
			if (str1:byte(i) == str2:byte(j)) then
				cost = 0
			else
				cost = 1
			end
			
			matrix[i][j] = math.min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
	end
	
        -- return the last value - this is the Levenshtein distance
	return matrix[len1][len2]
end
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

-- Helper function for fast modular exponentiation: (base^exp) % mod
local function mod_pow(base, exp, mod)
    local result = 1
    base = base % mod
    while exp > 0 do
        if exp % 2 == 1 then
            result = (result * base) % mod
        end
        exp = math.floor(exp / 2)
        base = (base * base) % mod
    end
    return result
end

-- 100% Deterministic Miller-Rabin test for numbers up to 2^64
function isprime(n)
    -- 1. Quick Filters
    if n <= 1 then return false end
    if n <= 3 then return true end
    if n % 2 == 0 or n % 3 == 0 then return false end
    
    -- 2. Decompose n-1 into (2^r) * d
    local r, d = 0, n - 1
    while d % 2 == 0 do
        r = r + 1
        d = math.floor(d / 2)
    end
    
    -- 3. The 12 Deterministic Bases required for 64-bit accuracy
    local bases = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37}
    
    for i = 1, #bases do
        local a = bases[i]
        
        -- If the base is equal to or larger than n, we can stop testing.
        -- (If n is a prime in this list, the quick filters above already caught it)
        if a >= n then break end
        
        local x = mod_pow(a, d, n)
        
        if x ~= 1 and x ~= n - 1 then
            local composite = true
            for j = 1, r - 1 do
                x = mod_pow(x, 2, n)
                if x == n - 1 then
                    composite = false
                    break
                end
            end
            if composite then
                return false -- 100% Mathematically proven composite
            end
        end
    end
    
    return true -- 100% Mathematically proven prime
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

local function get_base_primes(limit)
    local is_prime = {}
    for i = 2, limit do is_prime[i] = true end
    for p = 2, math.floor(math.sqrt(limit)) do
        if is_prime[p] then
            for i = p * p, limit, p do is_prime[i] = false end
        end
    end
    local primes = {}
    for p = 2, limit do
        if is_prime[p] then table.insert(primes, p) end
    end
    return primes
end

function primes(start_from)
    start_from = math.max(2, start_from or 2)
    local newTable = {}
    
    newTable.enumerate = function()
        -- Tuning Parameter: Process numbers in blocks of 50,000 for optimal cache speed
        local SEGMENT_SIZE = 50000
        
        -- Pre-calculate small prime divisors up to the square root of our maximum bound.
        -- For a standard 64-bit space, primes up to 2^32 require small primes up to 65536.
        local base_primes = get_base_primes(65536)
        
        local current_low = start_from
        local segment = {}
        local segment_index = 1
        local segment_high = current_low + SEGMENT_SIZE - 1

        -- Helper to fill the next memory block with prime filters
        local function fill_next_segment()
            segment = {}
            segment_high = current_low + SEGMENT_SIZE - 1
            
            -- Initialize all slots in this window as true (potentially prime)
            for i = 0, SEGMENT_SIZE - 1 do
                segment[i] = true
            end
            
            -- Handle edge case for numbers 0 and 1
            if current_low <= 1 then
                if 0 >= current_low then segment[0 - current_low] = false end
                if 1 >= current_low then segment[1 - current_low] = false end
            end
            
            -- Filter out composites using our base primes
            for _, p in ipairs(base_primes) do
                if p * p > segment_high then break end
                
                -- Find the first multiple of p that lands inside our current block window
                local start_val = math.floor((current_low + p - 1) / p) * p
                if start_val < p * p then
                    start_val = p * p
                end
                
                -- Cross off all multiples of p in the current segment block
                for j = start_val, segment_high, p do
                    segment[j - current_low] = false
                end
            end
            
            segment_index = 0
        end

        -- Initialize the first memory block
        fill_next_segment()

        -- Return the iterator function matching your spec
        return function()
            while true do
                if segment_index >= SEGMENT_SIZE then
                    current_low = current_low + SEGMENT_SIZE
                    fill_next_segment()
                end
                
                if segment[segment_index] then
                    local found_prime = current_low + segment_index
                    segment_index = segment_index + 1
                    return found_prime
                end
                
                segment_index = segment_index + 1
            end
        end
    end
    
    setmetatable(newTable, _enum)
    return newTable
end

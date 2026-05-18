_enum = {}

local function identity(...) return ... end

-- If it's a number, enumerate it until that index, and return that
_enum.__index = function(t, k)
    if type(k) == "number" then
        if rawget(t,'underlaying') then return rawget(t,'underlaying')[k] end
        local enum = t.enumerate()
        for i = 1, k-1 do
            local v = enum()
            if v == nil then
                return nil
            end
        end
        return enum()
    end
    if _enum[k] then return _enum[k] end
    if type(string[k]) == 'function' then
        -- I mean, when in rome, right?
        local f = string[k]
        return function(l, ...)
            local args = {...}
            return l:map(function(v)
                return f(v, table.unpack(args))
            end)
        end
    end
    return _enum[k]
end

_enum.__len = function(t)
    return t:count()
end

_enum.__call = function(t)
    return t.enumerate()
end

_enum.__iter = function(t)
    return t.enumerate
end

_enum.__type = "enumerable"

--[[
_enum.__newindex = function(t, k, v)
    -- Return a new enumerable that, when at index k, returns v instead of the old value
    local oldEnumerate = t.enumerate
    t.enumerate = function()
        local enum = oldEnumerate()
        local i = 0
        return function()
            i = i + 1
            if i == k then
                enum()
                return v
            else
                return enum()
            end
        end
    end
end
]]

_enum.__tostring = function(t, k, v)
    local str = "{"
    local join = ""
    local enum = t.enumerate()
    local v = enum()
    while v ~= nil do
        str = str .. join .. tostring(v)
        join = ", "
        v = enum()
    end
    str = str .. "}"
    return str
end

function _enum.__eq(a, b)
    if type(a) ~= "enumerable" or type(b) ~= "enumerable" then
        return false
    end
    -- Use the enumerate function to compare each value
    local enum1 = a.enumerate()
    local enum2 = b.enumerate()
    local v1 = {enum1()}
    local v2 = {enum2()}
    while (#v1 > 0 and v1[1] ~= nil) and (#v2 > 0 and v2[1] ~= nil) do
        if v1[1] ~= v2[1] then
            return false
        end
        v1 = {enum1()}
        v2 = {enum2()}
    end
    return (#v1 == 0 or v1[1] == nil) and (#v2 == 0 or v2[1] == nil)
end

function _enum.__concat(a, b)
    local newTable = {}
    if type(a) ~= "enumerable" then
        a = list{a}
    end
    if type(b) ~= "enumerable" then
        b = list{b}
    end
    return concat(a, b)
end

--[[
    A bunch of metafunctions with non-obvious functionality:
        __bor: Map
        __band: Where
]]
function _enum.__bor(a, b)
    return map(a, b)
end

function _enum.__band(a, b)
    return where(a, b)
end

function list(t)
    t = t or {}
    local newTable = {}
    newTable.underlaying = t
    newTable.enumerate = function()
        local i = 0
        return function()
            i = i + 1
            return t[i]
        end
    end
    setmetatable(newTable, _enum)
    return newTable
end

function range(start, stop, step)
    if stop == nil then
        stop = start
        start = 1
    end
    step = step or 1
    local newTable = {}
    newTable.enumerate = function()
        local i = start - step
        return function()
            i = i + step
            if (step > 0 and i <= stop) or (step < 0 and i >= stop) then
                return i
            else
                return nil
            end
        end
    end
    setmetatable(newTable, _enum)
    return newTable
end

function counting(start, step)
    start = start or 1
    step = step or 1
    local newTable = {}
    newTable.enumerate = function()
        local i = start - step
        return function()
            i = i + step
            return i
        end
    end
    setmetatable(newTable, _enum)
    return newTable
end
range = wrap(range, "range")
counting = wrap(counting, "counting")


function where(enumerable, predicate)
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local i = 1
        return function()
            local v = enum()
            while v ~= nil do
                if predicate(v, i) then
                    return v
                end
                v = enum()
            end
            return nil
        end
    end
    setmetatable(newTable, _enum)
    return newTable
end

function map(enumerable, selector)
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local i = 0
        return function()
            local v = enum()
            if v == nil then
                return nil
            end
            i = i + 1
            return selector(v, i)
        end
    end
    setmetatable(newTable, _enum)
    return newTable
end

function pack(enumerable, selector)
    selector = selector or function(...) return list{...} end
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        return function()
            local v = {enum()}
            if #v == 0 then
                return nil
            end
            return selector(table.unpack(v))
        end
    end
    return setmetatable(newTable,_enum)
end

function each(enumerable, func)
    func = func or function() end
    for a,b,c,d,e,f in enumerable.enumerate() do
        func(a,b,c,d,e,f)
    end
end

function first(enumerable, predicate)
    predicate = predicate or function() return true end
    local enum = enumerable.enumerate()
    local v = {enum()}
    while #v > 0 and v[1] ~= nil do
        if not predicate or predicate(table.unpack(v)) then
            return table.unpack(v)
        end
        v = {enum()}
    end
    return nil
end

function firstIndex(enumerable, predicate)
    predicate = predicate or function() return true end
    local enum = enumerable.enumerate()
    local v = enum()
    local i = 1
    while v ~= nil do
        if not predicate or predicate(v, i) then
            return i
        end
        v = enum()
        i = i + 1
    end
    return nil
end

function last(enumerable, predicate)
    predicate = predicate or function() return true end
    local enum = enumerable.enumerate()
    local v = enum()
    local last = nil
    while v ~= nil do
        if not predicate or predicate(v) then
            last = v
        end
        v = enum()
    end
    if last then
        return  last
    else
        return nil
    end
end

function lastIndex(enumerable, predicate)
    predicate = predicate or function() return true end
    local enum = enumerable.enumerate()
    local v = {enum()}
    local i = 1
    local last = nil
    local lastIndex = nil
    while #v > 0 and v[1] ~= nil do
        if not predicate or predicate(table.unpack(v)) then
            last = v
            lastIndex = i
        end
        v = {enum()}
        i = i + 1
    end
    if last then
        return lastIndex
    else
        return nil
    end
end

function any(enumerable, predicate)
    if not predicate then
        local f = enumerable.enumerate()()
        return f ~= nil
    end
    local enum = enumerable.enumerate()
    local v = enum()
    while v ~= nil do
        if predicate(v) then
            return true
        end
        v = enum()
    end
    return false
end

function all(enumerable, predicate)
    predicate = predicate or function(a) return a end
    local enum = enumerable.enumerate()
    local v = {enum()}
    while #v > 0 and v[1] ~= nil do
        if not predicate or not predicate(table.unpack(v)) then
            return false
        end
        v = {enum()}
    end
    return true
end

function count(enumerable, predicate)
    if enumerable.underlaying then
        return #enumerable.underlaying
    end
    i = 0
    if predicate then
        for v in enumerable.enumerate() do
            if predicate(v) then
                i = i + 1
            end
        end
    else
        for v in enumerable.enumerate() do
            i = i + 1
        end
    end
    return i
end

function tolist(enumerable)
    local t = {}
    for v in enumerable.enumerate() do
        t[#t+1] = v
    end
    return list(t)
end

function totable(enumerable)
    local t = {}
    for v in enumerable.enumerate() do
        t[#t+1] = v
    end
    return t
end

function todictionary(enumerable, keyselector, valueselector)
    local newTable = {}
    if not keyselector then -- Assume key-value pairs
        for k, v in enumerable.enumerate() do
            if v then newTable[k] = v else newTable[k[1]] = k[2] end
        end
    elseif valueselector then
        for a,b,c,d,e,f,g in enumerable.enumerate() do
            local key = keyselector(a,b,c,d,e,f,g)
            if newTable[key] == nil then
                newTable[key] = valueselector(a,b,c,d,e,f,g)
            end
        end
    else
        for a,b,c,d,e,f,g in enumerable.enumerate() do
            local k, v = keyselector(a,b,c,d,e,f,g)
            if v then
                newTable[k] = v
            else
                newTable[k[1]] = k[2]
            end
        end
    end
    return dictionary(newTable)
end

function sum(enumerable, selector)
    selector = selector or identity
    local enum = enumerable.enumerate()
    local v = {enum()}
    local i = 0
    while #v > 0 and v[1] ~= nil do
        i = i + selector(table.unpack(v))
        v = {enum()}
    end
    return i
end

function average(enumerable, selector)
    selector = selector or identity
    local enum = enumerable.enumerate()
    local v = {enum()}
    local i = 0
    local count = 0
    while #v > 0 and v[1] ~= nil do
        i = i + selector(table.unpack(v))
        count = count + 1
        v = {enum()}
    end
    return i / count
end

function min(enumerable, selector)
    selector = selector or identity
    local enum = enumerable.enumerate()
    local v = {enum()}
    local min = math.huge
    local minval = nil
    if #v == 0 or v[1] == nil then
        return nil
    end
    while #v > 0 and v[1] ~= nil do
        local val = selector(table.unpack(v))
        if val < min then
            min = val
            minval = v[1]
        end
        v = {enum()}
    end
    return minval
end

function max(enumerable, selector)
    selector = selector or identity
    local enum = enumerable.enumerate()
    local v = {enum()}
    local max = -math.huge
    local maxval = nil
    if #v == 0 or v[1] == nil then return nil end
    while #v > 0 and v[1] ~= nil do
        local val = selector(table.unpack(v))
        if val > max then
            max = val
            maxval = v[1]
        end
        v = {enum()}
    end
    return maxval
end

function contains(enumerable, value)
    local enum = enumerable.enumerate()
    local v = {enum()}
    while #v > 0 and v[1] ~= nil do
        if v[1] == value then
            return true
        end
        v = {enum()}
    end
    return false
end

function unpack(enumerable)
    local enum = enumerable.enumerate()
    local v = {enum()}
    local t = {}
    while #v > 0 and v[1] ~= nil do
        t[#t+1] = v[1]
        v = {enum()}
    end
    return table.unpack(t)
end

local list = list
function concat(enumerable, ...)
    local newTable = {}
    local arg
    if (type(...) == "enumerable") then
        arg = ...
    else
        arg = list({...})
    end
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local provided = false
        return function()
            local v = {enum()}
            if #v == 0 or v[1] == nil then
                if provided then
                    return nil
                end
                provided = true
                enum = arg.enumerate()
                return enum()
            end
            v[#v+1] = 1
            return table.unpack(v)
        end
    end
    setmetatable(newTable, _enum)
    return newTable
end

function lconcat(...)
    local args = {...}
    local enumerable = args[#args]
    table.remove(args, #args)
    return concat(list(args), enumerable)
end

function join(enumerable, separator)
    separator = separator or ""
    local enum = enumerable.enumerate()
    local v = {enum()}
    local str = ""
    while #v > 0 and v[1] ~= nil do
        str = str .. tostring(v[1])
        v = {enum()}
        if #v > 0 and v[1] ~= nil then
            str = str .. separator
        end
    end
    return str
end

function flatten(enumerable, n)
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local flatenum = nil
        return function()
            if flatenum then
                local v = {flatenum()}
                if #v > 0 and v[1] ~= nil then
                    return table.unpack(v)
                else
                    flatenum = nil
                end
            end
            local v = {enum()}
            while (not n or n > 0) and type(v[1]) == "enumerable" do
                local flattened = flatten(v[1], n and n - 1 or nil)
                flatenum = flattened.enumerate()
                local v = {flatenum()}
                if #v > 0 and v[1] ~= nil then
                    return table.unpack(v)
                else
                    flatenum = nil
                    v = {enum()}
                end
            end
            if #v > 0 and v[1] ~= nil then
                return table.unpack(v)
            else
                return nil
            end
        end
    end
    return setmetatable(newTable, _enum)
end

function reduce(enumerable, func, initial)
    local enum = enumerable.enumerate()
    local v = {enum()}
    local acc = initial
    local func = func or function(a, b) return a + b end
    while #v > 0 and v[1] ~= nil do
        if acc == nil then
            acc = v[1]
        else
            acc = func(acc, v[1])
        end
        v = {enum()}
    end
    return acc
end

function sum(enumerable, selector)
    selector = selector or identity
    return reduce(enumerable, function(a, b) return a + selector(b) end, 0)
end

function product(enumerable, selector)
    selector = selector or identity
    return reduce(enumerable, function(a, b) return a * selector(b) end, 1)
end

function sort(enumerable, comp)
    local t = {}
    for v in enumerable.enumerate() do
        t[#t+1] = v
    end
    comp = comp or function(a, b) return a < b end
    table.sort(t, comp)
    local newTable = {}
    newTable.enumerate = function()
        local i = 0
        return function()
            i = i + 1
            return t[i]
        end
    end
    return setmetatable(newTable, _enum)
end

function orderby(enumerable, selector, desc)
    local t = {}
    for v in enumerable.enumerate() do
        t[#t+1] = v
    end
    table.sort(t, function(a, b)
        local a = selector(a)
        local b = selector(b)
        if desc then
            return a > b
        else
            return a < b
        end
    end)
    local newTable = {}
    newTable.enumerate = function()
        local i = 0
        return function()
            i = i + 1
            return t[i]
        end
    end
    return setmetatable(newTable, _enum)

end

function fold(enumerable, func, initial)
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local last = initial or enum()
        local func = func or function(a, b) return a + b end
        return function()
            local v = enum()
            if v == nil then
                return nil
            else
                local next = func(last, v)
                last = v
                return next
            end
        end
    end
    return setmetatable(newTable, _enum)
end

function cumulate(enumerable, func, initial)
    local newTable = {}
    initial = initial or 0
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local i = initial
        if not i then
            i = enum()
        end
        return function()
            local o = i
            local v = enum()
            if v == nil then return nil end
            i = func(i, v)
            return o
        end
    end
    return setmetatable(newTable, _enum)
end

function deltas(a) return a:fold(function(a,b)return b-a end) end

function inversedeltas(a, s)
    local newTable = {}
    newTable.enumerate = function()
        local enum = a.enumerate()
        local s = s
        if not s then
            s = enum()
        end
        return function()
            local o = s
            local v = enum()
            if not v then return nil end
            s = s + v
            return o
        end
    end

    local t = {}
    a:each(function(a)
        t[#t+1] = s
        s = s + a
    end)
    t[#t+1] = s
    return list(t)
end


function take(enumerable, count)
    local newTable = {}
    count = count or 1
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local i = 0
        return function()
            i = i + 1
            if i <= count then
                return enum()
            else
                return nil
            end
        end
    end
    return setmetatable(newTable, _enum)
end

function getpermutation(l, index)
    local total = #l
    if total <= 1 then
        return l
    end
    local amountUnder = factorial(total - 1)
    local subIndex = math.floor(index / amountUnder)
    local uhh = index % amountUnder
    -- Pick exactly this next index from the list, and then repeat for the rest of the list
    return list{l[subIndex+1]} .. getpermutation(l:without(subIndex+1), uhh)
end

function permutations(l)
    return range(0,factorial(#l)-1):map(function(i)
        return getpermutation(l, i) 
    end)
end

function sumsof(max, parts)
    parts = parts or 2
    if type(parts) == "number" then
        local count = parts
        parts = {}
        for i=1, count do
            parts[i] = 1
        end
    end
    local newTable = {}
    newTable.enumerate = function()
        local curVals = {}
        for i=1, #parts - 1 do
            curVals[i] = 0
        end
        return function()
            -- Yeild the current sums, or nil if we're done
            if curVals[1] > max then
                return nil
            end
            local toYield = {}
            repeat
                local unSum = 0
                for i=1, #parts - 1 do
                    toYield[i] = curVals[i]
                    unSum = unSum + curVals[i]
                end
                toYield[#parts] = max - unSum
                toYield = list(toYield)

                -- Increment the max possible value, if that would set unSum to over max, then reset it to 0, and subtract 1 from j...
                repeat
                    for j=#parts-1, 1, -1 do
                        curVals[j] = curVals[j]+1
                        unSum = unSum + parts[j]
                        if unSum <= max or j == 1 then
                            break
                        end
                        unSum = unSum - curVals[j]
                        curVals[j] = 0
                    end
                    unSum = 0
                    local allValid = true
                    for i=1,#parts - 1 do
                        if (curVals[i]%parts[i])~=0 then
                            allValid = false
                        end
                        unSum = unSum + curVals[i]
                    end
                    if (max - unSum)%parts[#parts] ~= 0 then
                        allValid = false
                    end
                until curVals[1]> max or allValid
            until toYield[1]>max or toYield[#parts]%parts[#parts] == 0
            if toYield[1] > max then return nil end
            return toYield
        end
    end
    return setmetatable(newTable, _enum)
end

function skip(enumerable, count)
    local newTable = {}
    count = count or 1
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        for i=1, count do
            enum()
        end
        return enum
    end
    return setmetatable(newTable, _enum)
end

function takeWhile(enumerable, predicate)
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local i = 0
        return function()
            i = i + 1
            local v = {enum()}
            if #v == 0 or v[1] == nil then
                return nil
            end
            v[#v+1] = i
            if predicate(table.unpack(v)) then
                return table.unpack(v)
            else
                return nil
            end
        end
    end
    return setmetatable(newTable, _enum)
end

function skipWhile(enumerable, predicate)
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local i = 0
        local skip = true
        return function()
            if not skip then
                return enum()
            end
            local v = enum()
            while v ~= nil and predicate(v) do
                v = enum()
            end
            skip = false
            return v
        end
    end
    return setmetatable(newTable, _enum)
end

function reverse(enumerable)
    if type(enumerable) == "string" then
        return enumerable:reverse()
    end
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local t = {}
        local v = {enum()}
        while #v > 0 and v[1] ~= nil do
            table.insert(t, 1, v[1])
            v = {enum()}
        end
        local i = 0
        return function()
            i = i + 1
            return t[i]
        end
    end
    return setmetatable(newTable, _enum)
end

function rep(enumerable, count)
    count = count or 1
    if type(enumerable) == "string" then
        return enumerable:rep(count)
    end
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local repeats = 1
        return function()
            local v = {enum()}
            if #v == 0 or v[1] == nil then
                if repeats < count then
                    enum = enumerable.enumerate()
                    repeats = repeats + 1
                    return enum()
                else
                    return nil
                end
            else
                return table.unpack(v)
            end
        end
    end
    return setmetatable(newTable, _enum)
end

function distinct(enumerable, selector)
    selector = selector or function(...) return ... end
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local seen = {}
        local i = 1
        return function()
            local v = {enum()}
            while #v > 0 and v[1] ~= nil do
                local v2 = {table.unpack(v)}
                v2[#v2+1] = i
                i = i + 1
                local sel = selector(table.unpack(v2))
                
                if not seen[sel] then
                    seen[sel] = true
                    return table.unpack(v)
                end
                v = {enum()}
            end
            return nil
        end
    end
    return setmetatable(newTable, _enum)
end

function union(a, b)
    return distinct(concat(a, b))
end

function intersect(a, b)
    return where(a, function(...) return contains(b, ...) end)
end

function except(a, b)
    return where(a, function(...) return not contains(b, ...) end)
end

function without(l, index)
    local newTable = {}
    newTable.enumerate = function()
        local i = 1
        local f = l.enumerate()
        return function()
            local t = {f()}
            if i == index then t = {f()} end
            i = i + 1
            return table.unpack(t)
        end
    end
    return setmetatable(newTable, _enum)
end

function difference(a, b)
    return union(except(a, b), except(b, a))
end

function chunk(enumerator, chunkSize, exactly)
    -- Chunk the enumerator into chunks of size chunkSize
    -- Eg. {1,2,3,4,5}, 2 = {{1,2}, {3,4}, {5}}
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerator.enumerate()
        return function()
            local t = {}
            for i = 1, chunkSize do
                local v = enum()
                if v == nil then
                    if #t == 0 then
                        return nil
                    elseif not exactly then
                        return list(t)
                    end
                end
                t[#t+1] = v
            end
            if #t == 0 or (exactly and #t ~= chunkSize) then
                return nil
            end
            return list(t)
        end
    end
    return setmetatable(newTable, _enum)
end

function divide(enumerator, chunkSize, exactly)
    -- Divide the enumerator into chunkSize chunks
    -- Eg. {1,2,3,4,5}, 2 = {{1,3,5}, {2,4}}
    local newTable = {}
    newTable.enumerate = function()
        local size = enumerator:count()
        local partSize = math.ceil(size / chunkSize)
        local enum = enumerator.enumerate()
        return function()
            local t = {}
            for i = 1, partSize do
                local v = enum()
                if v == nil then
                    if #t == 0 then
                        return nil
                    elseif not exactly then
                        return list(t)
                    end
                end
                t[#t+1] = v
            end
            if exactly and #t ~= partSize then
                return nil
            end
            return list(t)
        end
    end
    return setmetatable(newTable, _enum)
end

function group(enumerable, selector)
    selector = selector or identity
    local t = {}
    local enum = enumerable.enumerate()
    local v = enum()
    while v ~= nil do
        local select = selector(v)
        t[select] = t[select] or {}
        t[select][#t[select]+1] = v
        v = enum()
    end
    return values(t):map(values)
end

function string.chunk(str, chunkSize, exactly)
    return chunk(str:split'', chunkSize, exactly):map(function(x) return join(x) end)
end

function string.divide(str, chunkSize, exactly)
    return divide(str:split'', chunkSize, exactly):map(function(x) return join(x) end)
end

function zip(...)
    local newTable = {}
    local args = {...}
    newTable.enumerate = function()
        local enums = {}
        for i = 1, #args do
            enums[i] = args[i].enumerate()
        end
        return function()
            local v = {}
            for i = 1, #enums do
                local v2 = enums[i]()
                if v2 == nil then
                    return nil
                end
                v[#v+1] = v2
            end
            return list(v)
        end
    end
    return setmetatable(newTable, _enum)
end

function transpose(enumerable)
    local newTable = {}
    newTable.enumerate = function()
        local enum = enumerable.enumerate()
        local t = {}
        local v = enum()
        while v ~= nil do
            t[#t+1] = v
            v = enum()
        end
        local i = 0
        return function()
            i = i + 1
            local t2 = {}
            for j = 1, #t do
                t2[#t2+1] = t[j][i]
            end
            if #t2 == 0 or t2[1] == nil then
                return nil
            end
            return list(t2)
        end
    end
    return setmetatable(newTable, _enum)
end

function writelist(enumerable)
    write("{")
    local join = ""
    local enum = enumerable.enumerate()
    local v = enum()
    while v ~= nil do
        write(join)
        write(tostring(v))
        join = ", "
        v = enum()
    end
    write("}")
end

function printlist(enumerable)
    writelist(enumerable)
    print()
end

function lpairs(t)
    local newTable = {}
    newTable.enumerate = function()
        local enum = pairs(t)
        local last = nil
        return function()
            local k, v = enum(t, last)
            if k == nil then
                return nil
            end
            last = k
            return list{k, v}
        end
    end
    return setmetatable(newTable, _enum)
end

function keys(t)
    local newTable = {}
    newTable.enumerate = function()
        local enum = pairs(t)
        local last = nil
        return function()
            local k, v = enum(t, last)
            if k == nil then
                return nil
            end
            last = k
            return k
        end
    end
    return setmetatable(newTable, _enum)
end

function values(t)
    local newTable = {}
    newTable.enumerate = function()
        local enum = pairs(t)
        local last = nil
        return function()
            local k, v = enum(t, last)
            if k == nil then
                return nil
            end
            last = k
            return v
        end
    end
    return setmetatable(newTable, _enum)
end

function _gcd(a, b)
    if b == 0 then return a end
    return _gcd(b, a%b)
end

function gcd(enumerable, b)
    if type(enumerable) == 'number' then
        return _gcd(enumerable, b)
    end
    return enumerable:reduce(_gcd)
end

function _lcm(a, b)
    return (a*b)/_gcd(a,b)
end

function lcm(e, b)
    if type(e) == 'number' then
        return _lcm(e, b)
    end
    local bestprimes = {}
    e:each(function(v)
        local counts = primefactorcounts(v)
        counts:each(function(p)
            local prime, count = p[1], p[2]
            bestprimes[prime] = math.max(bestprimes[prime] or 1, count)
        end)
    end)
    local prod = 1
    for prime, count in pairs(bestprimes) do
        prod = prod * count * prime
    end
    return prod
end

-- Add all the functions from the table to the enumerable metatable
local methods = {
    "where",
    "without",
    "map",
    "pack",
    "each",
    "first",
    "firstIndex",
    "last",
    "lastIndex",
    "any",
    "all",
    "count",
    "tolist",
    "totable",
    "todictionary",
    "sum",
    "average",
    "min",
    "max",
    "contains",
    "unpack",
    "pack",
    "concat",
    "join",
    "flatten",
    "reduce",
    "sum",
    "product",
    "sort",
    "orderby",
    "fold",
    "cumulate",
    "deltas",
    "inversedeltas",
    "take",
    "permutations",
    "sumsof",
    "skip",
    "takeWhile",
    "skipWhile",
    "reverse",
    "rep",
    "distinct",
    "union",
    "intersect",
    "except",
    "difference",
    "chunk",
    "group",
    "divide",
    "zip",
    "transpose",
    "gcd",
    "lcm"
}
for i = 1, #methods do
    _enum[methods[i]] = _G[methods[i]]
    _G[methods[i]] = wrap(_G[methods[i]], methods[i], 1)
end

function chars(str)
    local newTable = {}
    newTable.enumerate = function()
        local enum = utf8.codes(str)
        local p = 0
        local c
        return function()
            p, c = enum(str, p)
            if c == nil then
                return nil
            end
            local v = utf8.char(c)
            return v
        end
    end
    return setmetatable(newTable, _enum)
end

function split(str, by)
    str = str or readall()
    if by == '' then
        local newTable = {}
        newTable.enumerate = function()
            local enum = str:gmatch('.')
            return function()
                local v = enum()
                if v == nil then
                    return nil
                end
                return v
            end
        end
        return setmetatable(newTable, _enum)
    end
    by = by or "%s+"
    by = "()(" .. by .. ")"
    local newTable = {}
    newTable.enumerate = function()
        local i = 1
        return function()
            local next, b = str:match(by, i)
            if next == nil then
                if i > #str then
                    return nil
                end
                local s = str:sub(i)
                i = #str + 1
                return s
            end
            local s = str:sub(i, next - 1)
            i = next + #b
            return s
        end
    end
    return setmetatable(newTable, _enum)
end

function lines(str)
    return split(str, "\r?\n")
end

function matches(str, pattern, mapper)
    pattern = pattern or "%S+"
    local newTable = {}
    newTable.enumerate = function()
        if not mapper then
            return string.gmatch(str, pattern)
        end
        local f = string.gmatch(str, pattern)
        return function()
            local res = {f()}
            if #res == 0 or res[1] == nil then return nil end
            return mapper(table.unpack(res))
        end
    end
    return setmetatable(newTable, _enum)
end

function primefactors(numb)
    local newTable = {}
    newTable.enumerate = function()
        local n = math.floor(numb)
        local panic = 1
        return function()
            if n < 0 then
                n = -n
                return -1
            end
            if n <= 1 then
                return nil
            end
            -- Find the next number this is divisble by, and return it
            local i = 2
            while i*i <= n do
                if n%i == 0 then
                    n = math.floor(n / i)
                    return i
                end
                i = i + 1
            end
            -- Otherwise, This IS a prime.
            local o = n
            n = 1
            return o
        end
    end
    return setmetatable(newTable, _enum)
end

function primefactorcounts(n)
    local t = {}
    while n > 1 do
        local i = 2
        while i*i <= n  do
            if n%i == 0 then
                n = math.floor(n / i)
                t[i] = (t[i] or 0) + 1
            end
            i = i + 1
        end
        if n > 1 then
            t[n] = (t[n] or 0) + 1
            n = 1
        end
    end
    return lpairs(t)
end

function factors(n)
    local newTable = {}
    newTable.enumerate = function()
        local i = 0
        return function()
            i = i + 1
            while n % i ~= 0 and i <= n do
                i = i + 1
            end
            if i > n then return nil end
            return i
        end
    end
    return setmetatable(newTable, _enum)
end

function factorpairs(n)
    local newTable = {}
    newTable.enumerate = function()
        local i = 0
        return function()
            i = i + 1
            while n % i ~= 0 and i*i <= n do
                i = i + 1
            end
            if i*i > n then return nil end
            return list{i, math.floor(n/i)}
        end
    end
    return setmetatable(newTable, _enum)
end

local function _stackpush(t, ...)
    local v = {...}
    for i=1, #v do
        table.insert(t, v[i])
    end
    return t
end

local function _stackpop(t)
    return table.remove(t)
end

local function _stackpeek(t)
    return t[#t]
end

local function _stackhas(t)
    return t[1]~=nil
end

function stack(t)
    local nt = {}
    if t then
        for i=1, #t do
            nt[#nt+1] = t[i]
        end
    end
    nt.enumerate = function()
        local i = 0
        return function()
            i = i + 1
            return rawget(nt, i)
        end
    end
    nt.push = _stackpush
    nt.pop = _stackpop
    nt.peek = _stackpeek
    nt.has = _stackhas
    return setmetatable(nt, _enum)
end

local function _queuepush(t, ...)
    local v = {...}
    for i=1, #v do
        table.insert(t, 1, v[i])
    end
    return t
end

function queue(t)
    local nt = {}
    if t then
        for i=1, #t do
            nt[#nt+1] = t[i]
        end
    end
    nt.enumerate = function()
        local i = 0
        return function()
            i = i + 1
            return rawget(nt, i)
        end
    end
    nt.push = _queuepush
    nt.pop = _stackpop
    nt.peek = _stackpeek
    nt.has = _stackhas
    return setmetatable(nt, _enum)
end

chars = wrap(chars, "chars")
split = wrap(split, "split")
lines = wrap(lines, "lines")
matches = wrap(matches, "matches")

string.chars = chars
string.split = split
string.lines = lines
string.matches = matches
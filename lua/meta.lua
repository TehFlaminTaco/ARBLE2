local functionMeta = {}
debug.setmetatable(function() end, functionMeta)
local stringMeta = getmetatable("")
local string = string

-- Function math!
-- function * number = (function):rep(number)
-- function + function = function(...) function(...)

function functionMeta.__mul(a, b)
    local func
    local number
    if type(a) == "function" then
        func = a
        number = b
    else
        func = b
        number = a
    end
    if type(number) ~= "number" then
        error("Attempt to multiply a function by a non-number")
    end
    if type(func) ~= "function" then
        error("Attempt to multiply a non-function by a number")
    end

    local function newFunc(...)
        local last
        for i = 1, number do
            last = {func(...)}
        end
        return table.unpack(last)
    end
    return newFunc
end

function functionMeta.__add(a, b)
    local func1
    local func2
    if type(a) == "function" then
        func1 = a
        func2 = b
    else
        func1 = b
        func2 = a
    end
    if type(func1) ~= "function" then
        error("Attempt to add a non-function to a function")
    end
    if type(func2) ~= "function" then
        error("Attempt to add a function to a non-function")
    end

    local function newFunc(...)
        local outv = {func1(...)}
        if #outv == 1 and (isEq(outv[1]) or type(outv[1]) == "function") then
            outv = {outv[1](...)}
        end
        return table.unpack(outv)
    end
    return newFunc
end

-- String Stuff
-- string * number = string:rep(number)
-- string + string = string:concat(string)

function stringMeta.__mul(a, b)
    local str
    local number
    if type(a) == "string" then
        str = a
        number = b
    else
        str = b
        number = a
    end
    if type(number) ~= "number" then
        error("Attempt to multiply a string by a non-number")
    end
    if type(str) ~= "string" then
        error("Attempt to multiply a non-string by a number")
    end

    return str:rep(number)
end

function stringMeta.__add(a, b)
    return a .. b
end

function stringMeta.__call(str, ...)
    return run(str, ...)
end

function stringMeta.__index(str, index)
    if type(index) == "number" then
        return str:sub(index, index)
    end
    return advancedstring[index] or string[index]
end

function stringMeta.__mod(str, a)
    if type(a) == "table" then
        return str:format(table.unpack(a))
    end
    return str:format(a)
end

local oldType = type
function type(e)
    -- Print stack trace
    local ot = oldType(e)
    if ot == "table" then
        local meta = getmetatable(e)
        if meta and meta.__type then
            return meta.__type
        end
    end
    return ot
end



function iter(obj)
    local t = oldType(obj)
    if t == "number" then
        obj = counting(obj)
    elseif t == "string" then
        obj = chars(obj)
    elseif t == "function" then
        return obj
    end
    local m = getmetatable(obj)
    if m and m.__iter then return m.__iter(obj) end
    return obj
end
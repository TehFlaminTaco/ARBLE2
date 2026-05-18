local _dict = {}

_dict.__index = function(t, k)
    return _dict[k] or _enum[k] or t.underlaying[k]
end
_dict.__setindex = function(t, k, v)
    t.underlaying[k] = v;
end
_dict.__len = function(t, k)
    local i = 0
    for k in pairs(t.underlaying) do
        i = i + 1
    end
    return i
end
_dict.__call = function(t)
    return t.enumerate()
end
_dict.__type = "enumerable"

_dict.__tostring = function(t)
    local str = "{\n"
    for k,v in pairs(t.underlaying) do
        if(type(k) == "string") then
            k = string.format("%q",k)
        end
        k = tostring(k)
        v = tostring(v)
        str = string.format("%s\t[%s] = %s,\n", str, k, string.gsub(tostring(v), "\n", "\n\t"))
    end
    return str .. "}"
end
function _dict.__eq(a, b)
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

function _dict.__concat(a, b)
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
function _dict.__bor(a, b)
    return map(a, b)
end

function _dict.__band(a, b)
    return where(a, b)
end

function dictionary(fromtable)
    fromtable = fromtable or {}
    local dict = {
        underlaying = fromtable,
        enumerate = function()
            local iter = pairs(fromtable)
            local k = nil
            local v
            return function()
                k, v = iter(fromtable, k)
                if k == nil then
                    return nil
                end
                return list{k,v}
            end
        end
    }
    return setmetatable(dict, _dict)
end

function keys(dict)
    local newTable = {}
    newTable.enumerate = function()
        local iter = pairs(dict.underlaying)
        local k = nil
        local v
        return function()
            k, v = iter(dict.underlaying, k)
            if k == nil then
                return nil
            end
            return k
        end
    end
    return setmetatable(newTable, _enum)
end
function _dict.values(dict)
    local newTable = {}
    newTable.enumerate = function()
        local iter = pairs(dict.underlaying)
        local k = nil
        local v
        return function()
            k, v = iter(dict.underlaying, k)
            if k == nil then
                return nil
            end
            return v
        end
    end
    return setmetatable(newTable, _enum)
end
function keyvaluepairs(dict)
    local newTable = {}
    newTable.enumerate = function()
        local iter = pairs(dict.underlaying)
        local k = nil
        local v
        return function()
            k, v = iter(dict.underlaying, k)
            if k == nil then
                return nil
            end
            return list{k,v}
        end
    end
    return setmetatable(newTable, _enum)
end

function has(dict, key)
    return dict.underlaying[key] ~= nil
end

function get(dict, key, default)
    if dict.underlaying[key] == nil then
        if type(default) == "function" then
            return default()
        else
            return default
        end
    end
    return dict.underlaying[key]
end

function set(dict, key, value)
    dict.underlaying[key] = value
    return value
end

function update(dict, key, selector, default)
    local v = dict.underlaying[key]
    if v == nil then
        if type(default) == "function" then
            v = default()
        else
            v = default
        end
    end
    dict.underlaying[key] = selector(v)
    return dict
end

function with(dict, key, value)
    dict.underlaying[key] = value
    return dict
end

function _dict.where(dict, predicate)
    local newTable = {}
    for k, v in pairs(dict.underlaying) do
        if predicate(list{k, v}) then
            newTable[k] = v
        end
    end
    return dictionary(newTable)
end

function _dict.map(dict, selector)
    local newTable = {}
    for k, v in pairs(dict.underlaying) do
        newTable[k] = selector(list{k, v})
    end
    return dictionary(newTable)
end

local methods = {
    "keys",
    "keyvaluepairs",
    "has",
    "get",
    "update",
    "set",
    "with"
}

for i = 1, #methods do
    _dict[methods[i]] = _G[methods[i]]
    _G[methods[i]] = wrap(_G[methods[i]], methods[i], 1)
end
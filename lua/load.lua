-- An enhanced version of the load function, as well as a run function
-- These will dynamically check for a last statement and return it

local oldLoad = load
_G._LOAD = oldLoad
function load(str)
    str = mutate(str)
    -- Try just prepending a 'return ', if that works, return the function
    local func, err = oldLoad('return ' .. str)
    if func then
        return func
    end
    -- Try just running the string, if that works, return the function
    func, err = oldLoad(str)
    if func then
        return func
    end
    -- If err contains "unexpected symbol near '='", assume it might be a `=...` style return. In this case, search backwards through each `=`, and replace them with `return ` untill it works
    if err:find("unexpected symbol near '='") or err:find("syntax error near '='") or err:find("expected near '='") then
        local allMatches = {}
        for match in str:gmatch("()=") do
            table.insert(allMatches, match)
        end
        for i = #allMatches, 1, -1 do
            local newStr = str:sub(1, allMatches[i]-1) .. "return " .. str:sub(allMatches[i]+1)
            func, err = oldLoad(newStr)
            if func then
                return func
            end
        end
    end
    -- If we get here, we have no idea what's going on, so just return the error
    return nil, err
end

function run(str, ...)
    local func, err = load(str)
    if func then
        local outv = {func(...)}
        if #outv == 1 and type(outv[1]) == "function" then
            outv = {outv[1](...)}
        end
        return table.unpack(outv)
    else
        error(err, 2)
    end
end
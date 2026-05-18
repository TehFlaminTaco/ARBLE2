require "mutate"
--require "equa"
require "equalite"
require "advancedpatterns"
require "load"
require "meta"
require "list"
require "dictionary"
require "misc"

local function thousands(n)
    local s = ''
    if n%1 > 0 then
        s = ('%f'):format(n%1):match("%.(%d+)") or ""
        s = s:gsub("0+$", "")
        if #s > 0 then
            s = '.' .. s
        end
        n = n // 1
    end
    while n > 1000 do
        s = (',%i%s'):format(n%1000, s)
        n = n // 1000
    end
    return ('%i%s'):format(n, s)
end

function formattime(s)
    if type(s) ~= "number" then
        error("Expected number, got " .. type(s))
    end
    if s == 0 then
        return "0s"
    end
    if s < 0 then
        return '-' .. formattime(-s)
    end
    if s < 1 then
        -- MS
        return ('%ims'):format(math.floor(s*1000))
    end
    if s < 60 then
        -- S:MS
        return ('%is %02ims'):format(math.floor(s), math.floor((s%1)*1000))
    end
    if s < 3600 then
        -- M:S:MS
        return ('%im %02is %02ims'):format(math.floor(s//60), math.floor(s%60), math.floor(s%1*1000))
    end
    if s < 86400 then
        -- H:M:S:MS
        return ('%ih %02im %02is %02ims'):format(math.floor(s//3600), math.floor((s//60%60)), math.floor((s%60)), math.floor((s%1*1000)))
    end
    -- D days, H:M:S:MS
    return ('%id %ih %02im %02is %02ims'):format(math.floor(s//86400), math.floor(s//3600%24), math.floor(s//60%60), math.floor(s%60), math.floor(s%1*1000))
end


function _G.showruncode(code)
    local status, result = xpcall(function()
        showmutated(mutate(code))
        local start = os.clock()
        local res = {run(code)}
        local endt = os.clock()
        -- For everything but the last, print, for the last, write
        if #res == 0 then
            return
        end
        for i = 1, #res-1 do
            if type(res[i])=="enumerable" then
                printlist(res[i])
            else
                print(res[i])
            end
        end
        if type(res[#res])=="enumerable" then
            writelist(res[#res])
        else
            write(res[#res])
        end
        writeerror(("Finished in %s\n"):format(formattime(endt - start)))
    end,debug.traceback)
    if(not status) then
        print(result)
    end
end

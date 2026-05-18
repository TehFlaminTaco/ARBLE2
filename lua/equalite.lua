_G.oldString = {}
for k, v in pairs(string) do oldString[k] = v end

function wrap(...) return ... end
function isEq() return false end

setmetatable(_G, {__index = function(a,k)
	return math[k] or string[k] or io[k]
end, __newindex = function(t, k, v)
	if k == "_PRINTRESULT" then
		print(v)
	else
		rawset(t,k,v)
	end
end})


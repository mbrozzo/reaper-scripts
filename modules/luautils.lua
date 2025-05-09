local luautils = {}

function luautils.round(x)
	return math.floor(x + 0.5)
end

function luautils.map(table, func, iterator_func)
	iterator_func = iterator_func or pairs
	local retvals = {}
	for k, v in pairs(table) do
		retvals[k] = func(v, k)
	end
	return retvals
end

function luautils.imap(table, func)
	local retvals = {}
	for i, v in ipairs(table) do
		table.insert(retvals, func(v, i))
	end
	return retvals
end

function luautils.any(table, test_func)
	test_func = test_func or function(v)
		return v
	end
	for k, v in ipairs(table) do
		if test_func(v, k) then -- also accepts a test_func which only operates on the value
			return true
		end
	end
	return false
end

function luautils.all(table, test_func)
	return not luautils.any(table, function(v, k)
		return not test_func(v, k)
	end)
end

function luautils.only_contains_value(table, value)
	return luautils.all(table, function(v, k)
		return v == value
	end)
end

function luautils.contains_value(table, value)
	return luautils.any(table, function(v, k)
		return v == value
	end)
end

function luautils.does_not_contain_value(table, value)
	return luautils.all(table, function(v, k)
		return v ~= value
	end)
end

return luautils

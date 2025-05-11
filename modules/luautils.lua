local luautils = {}

-- Math
luautils.math = {}

function luautils.math.round(x)
	return math.floor(x + 0.5)
end

-- Tables
luautils.table = {}

function luautils.table.map(table, func, iterator_func)
	iterator_func = iterator_func or pairs
	local retvals = {}
	for k, v in pairs(table) do
		retvals[k] = func(v, k)
	end
	return retvals
end

function luautils.table.imap(table, func)
	return luautils.table.map(table, func, ipairs)
end

function luautils.table.any(table, test_func, iterator_func)
	iterator_func = iterator_func or pairs
	test_func = test_func or function(v)
		return v
	end
	for i, v in iterator_func(table) do
		if test_func(v, i) then -- also accepts a test_func which only operates on the value
			return true
		end
	end
	return false
end

function luautils.table.iany(table, test_func)
	luautils.table.any(table, test_func, ipairs)
end

function luautils.table.all(table, test_func, iterator_func)
	return not luautils.table.any(table, function(v, k)
		return not test_func(v, k)
	end, iterator_func)
end

function luautils.table.iall(table, test_func)
	luautils.table.all(table, test_func, ipairs)
end

function luautils.table.contains(table, value, iterator_func)
	return luautils.table.any(table, function(v, k)
		return v == value
	end, iterator_func)
end

function luautils.table.icontains(table, value)
	luautils.table.contains(table, value, ipairs)
end

function luautils.table.only_contains(table, value, iterator_func)
	return luautils.table.all(table, function(v, k)
		return v == value
	end, iterator_func)
end

function luautils.table.ionly_contains(table, value)
	luautils.table.only_contains(table, value, ipairs)
end

function luautils.table.does_not_contain(table, value, iterator_func)
	return luautils.table.all(table, function(v, k)
		return v ~= value
	end, iterator_func)
end

function luautils.table.idoes_not_contain(table, value)
	luautils.table.does_not_contain(table, value, ipairs)
end

return luautils

local lu = {}

-- Math
lu.math = {}

function lu.math.round(x)
	return math.floor(x + 0.5)
end

-- Tables
lu.table = {}

function lu.table.map(table, func, iterator_func)
	iterator_func = iterator_func or pairs
	local retvals = {}
	for k, v in pairs(table) do
		retvals[k] = func(v, k)
	end
	return retvals
end

function lu.table.imap(table, func)
	return lu.table.map(table, func, ipairs)
end

function lu.table.any(table, test_func, iterator_func)
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

function lu.table.iany(table, test_func)
	lu.table.any(table, test_func, ipairs)
end

function lu.table.all(table, test_func, iterator_func)
	return not lu.table.any(table, function(v, k)
		return not test_func(v, k)
	end, iterator_func)
end

function lu.table.iall(table, test_func)
	lu.table.all(table, test_func, ipairs)
end

function lu.table.contains(table, value, iterator_func)
	return lu.table.any(table, function(v, k)
		return v == value
	end, iterator_func)
end

function lu.table.icontains(table, value)
	lu.table.contains(table, value, ipairs)
end

function lu.table.only_contains(table, value, iterator_func)
	return lu.table.all(table, function(v, k)
		return v == value
	end, iterator_func)
end

function lu.table.ionly_contains(table, value)
	lu.table.only_contains(table, value, ipairs)
end

function lu.table.does_not_contain(table, value, iterator_func)
	return lu.table.all(table, function(v, k)
		return v ~= value
	end, iterator_func)
end

function lu.table.idoes_not_contain(table, value)
	lu.table.does_not_contain(table, value, ipairs)
end

return lu

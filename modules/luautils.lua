local utils = {}

function utils.contains_value(table, value)
	for _, v in ipairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

return utils

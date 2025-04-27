MAXIMUM_DISTANCE = 5 -- Maximum distance between the mouse cursor and the envelope point in pixels

function main()
	-- Get mouse cursor context
	local window, segment, details = reaper.BR_GetMouseCursorContext()

	-- Exit if the mouse is not over an envelope point (broken atm)
	-- if arrange ~= "arrange" or segment ~= "envelope" or details ~= "env_point" then return end
	-- Exit if the mouse is not over an envelope (while env_point is broken)
	if window ~= "arrange" or segment ~= "envelope" then return end

	-- Get mouse cursor envelope context
	local env, takeEnvelope = reaper.BR_GetMouseCursorContext_Envelope()
	if env == nil then return end

	-- Get mouse cursor time position
	local mouse_time = reaper.BR_GetMouseCursorContext_Position()

	-- Get horizontal zoom level (pixels/second)
	local zoom = reaper.GetHZoomLevel()
	local max_time = mouse_time + MAXIMUM_DISTANCE / zoom
	local min_time = mouse_time - MAXIMUM_DISTANCE / zoom

	-- Get count of automation items
	local ai_count = reaper.CountAutomationItems(env)

	-- Search
	local found_autoitem_idx
	for autoitem_idx = -1, ai_count do
		-- Get envelope point before mouse cursor or within a certain horizontal distance
		local envpoint_idx = reaper.GetEnvelopePointByTimeEx(env, autoitem_idx, max_time)
		if envpoint_idx == -1 then goto continue end -- No envelope point found

		-- Get envelope point information
		local success, point_time, value, shape, tension, selected = reaper.GetEnvelopePointEx(env, autoitem_idx,
			envpoint_idx)
		if success == false then goto continue end -- No envelope point found

		-- Check if point in horizontal range
		if point_time < min_time then goto continue end -- Point too far to the left

		-- Point found
		found_autoitem_idx = autoitem_idx
		found_envpoint_idx = envpoint_idx
		break
		::continue::
	end

	-- Select
	for autoitem_idx = -1, ai_count do
		-- Get total points in the envelope
		local num_points = reaper.CountEnvelopePointsEx(env, autoitem_idx)

		-- Select the point under the mouse and unselect all others
		for i = 0, num_points - 1 do
			reaper.SetEnvelopePointEx(env, autoitem_idx, i, nil, nil, nil, nil, false, true)
		end
	end
	reaper.SetEnvelopePointEx(env, found_autoitem_idx, found_envpoint_idx, nil, nil, nil, nil, true, true)
end

-- Run the main function
main()

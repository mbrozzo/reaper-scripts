MAXIMUM_DISTANCE = 5 -- Maximum distance between the mouse cursor and the envelope point in pixels
NUM_SHAPES = 6       -- Number of available shapes

function main()
	-- Get mouse cursor context
	local window, segment, details = reaper.BR_GetMouseCursorContext()

	-- Exit if the mouse is not over an envelope point (broken atm)
	-- if segment ~= "envelope" or details ~= "env_point" then return end
	-- Exit if the mouse is not over an envelope (while env_point is broken)
	if window ~= "arrange" or segment ~= "envelope" then return end

	-- Get mouse cursor envelope context
	local env, _ = reaper.BR_GetMouseCursorContext_Envelope()
	if env == nil then return end

	-- Get mouse cursor time position
	local mouse_time = reaper.BR_GetMouseCursorContext_Position()

	-- Get horizontal zoom level (pixels/second)
	local zoom = reaper.GetHZoomLevel()
	local max_time = mouse_time + MAXIMUM_DISTANCE / zoom
	local min_time = mouse_time - MAXIMUM_DISTANCE / zoom

	-- Get count of automation items
	local autoitem_count = reaper.CountAutomationItems(env)

	-- Search
	for autoitem_idx = -1, autoitem_count do
		-- Get envelope point before mouse cursor or within a certain horizontal distance
		local envpoint_idx = reaper.GetEnvelopePointByTimeEx(env, autoitem_idx, max_time)
		if envpoint_idx == -1 then goto continue end -- No envelope point found

		-- Get envelope point information
		local success, envpoint_time, _, envpoint_shape, _, _ = reaper.GetEnvelopePointEx(env, autoitem_idx, envpoint_idx)
		if success == false then goto continue end -- No envelope point found

		-- Check if point in horizontal range
		if envpoint_time < min_time then goto continue end -- Point too far to the left

		-- Point found: cycle shape and return
		reaper.Undo_BeginBlock()
		reaper.SetEnvelopePointEx(env, autoitem_idx, envpoint_idx, nil, nil, (envpoint_shape + 1) % NUM_SHAPES, nil, nil,
			true)
		reaper.Undo_EndBlock("Cycle through shapes of envelope point at mouse cursor", -1)
		break
		::continue::
	end
end

-- Run the main function
main()
reaper.UpdateArrange()

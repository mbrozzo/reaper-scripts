function main()
	-- Get mouse cursor context
	local window, segment, details = reaper.BR_GetMouseCursorContext()

	-- Exit if the mouse is not over an envelope segment (broken atm)
	-- if segment ~= "envelope" or details ~= "env_segment" then return end
	-- Exit if the mouse is not over an envelope (while env_segment is broken)
	if window ~= "arrange" or segment ~= "envelope" then return end

	-- Get mouse cursor envelope context
	local env, takeEnvelope = reaper.BR_GetMouseCursorContext_Envelope()
	if env == nil then return end

	-- Get mouse cursor time position
	local mouse_time = reaper.BR_GetMouseCursorContext_Position()
	
	-- Get count of automation items
	local autoitem_count = reaper.CountAutomationItems(env)

	-- Select an automation item
	-- Due to API limitations, the action is applied to the first selected automation item at mouse time position,
	-- or to the envelope if no automation item is selected
	local found_autoitem_idx = -1
	for autoitem_idx = -1, autoitem_count do
		local autoitem_sel = reaper.GetSetAutomationItemInfo(env, autoitem_idx, "D_UISEL", -1, false)
		if autoitem_sel == 0 then goto continue end -- Automation item not selected
		local autoitem_pos = reaper.GetSetAutomationItemInfo(env, autoitem_idx, "D_POSITION", -1, false)
		if mouse_time < autoitem_pos then goto continue end -- Mouse before automation item start
		local autoitem_len = reaper.GetSetAutomationItemInfo(env, autoitem_idx, "D_LENGTH", -1, false)
		if mouse_time > autoitem_pos + autoitem_len then goto continue end -- Mouse after automation item end
		
		-- Mouse is in this selected automation item's time range
		found_autoitem_idx = autoitem_idx
		break
		::continue::
	end
	
	-- Get envelope point before mouse cursor
	local envpoint_idx = reaper.GetEnvelopePointByTimeEx(env, found_autoitem_idx, mouse_time)
	if envpoint_idx == -1 then return end -- No envelope point found
	
	-- Get envelope point information
	local success, envpoint_time, _, envpoint_shape, _, _ = reaper.GetEnvelopePointEx(env, found_autoitem_idx, envpoint_idx)
	if success == false then return end -- No envelope point found

	-- Point found: cycle shape
	reaper.Undo_BeginBlock()
	reaper.SetEnvelopePointEx(env, found_autoitem_idx, envpoint_idx, nil, nil, 0, nil, nil, true)
	reaper.Undo_EndBlock("Cycle through shapes of envelope segment at mouse cursor", -1)
end

-- Run the main function
main()
reaper.UpdateArrange()

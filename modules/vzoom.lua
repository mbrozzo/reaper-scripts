local vzoom = {}

MINIMIZE_TOGGLE_COMMAND = 40110
MAXIMIZE_TOGGLE_COMMAND = 40113
ZOOM_IN_COMMAND = 40111
ZOOM_OUT_COMMAND = 40112

function vzoom.execute_with_current_track_heights_locked(func, ...)
	-- Store toggle command states
	local minimize_toggle_command_state = reaper.GetToggleCommandState(MINIMIZE_TOGGLE_COMMAND)
	local maximize_toggle_command_state = reaper.GetToggleCommandState(MAXIMIZE_TOGGLE_COMMAND)
	-- Lock track heights and save lock state
	local master_track = reaper.GetMasterTrack(0)
	local master_track_lock = reaper.GetMediaTrackInfo_Value(master_track, "B_HEIGHTLOCK")
	local master_track_override = reaper.GetMediaTrackInfo_Value(master_track, "I_HEIGHTOVERRIDE")
	reaper.SetMediaTrackInfo_Value(master_track, "I_HEIGHTOVERRIDE",
		reaper.GetMediaTrackInfo_Value(master_track, "I_TCPH"))
	reaper.SetMediaTrackInfo_Value(master_track, "B_HEIGHTLOCK", 1)
	local n_tracks = reaper.CountTracks(0)
	if n_tracks < 0 then return end
	local locks = {}
	local overrides = {}
	for i = 0, n_tracks - 1 do
		local track = reaper.GetTrack(0, i)
		locks[i] = reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
		overrides[i] = reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE",
			reaper.GetMediaTrackInfo_Value(track, "I_TCPH"))
		reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", 1)
	end

	local retvals = { func(...) }

	-- Restore toggle command states
	if reaper.GetToggleCommandState(MINIMIZE_TOGGLE_COMMAND) ~= minimize_toggle_command_state then
		reaper.Main_OnCommand(MINIMIZE_TOGGLE_COMMAND, 0)
	end
	if reaper.GetToggleCommandState(MAXIMIZE_TOGGLE_COMMAND) ~= maximize_toggle_command_state then
		reaper.Main_OnCommand(MAXIMIZE_TOGGLE_COMMAND, 0)
	end

	-- Restore track locks
	reaper.SetMediaTrackInfo_Value(reaper.GetMasterTrack(0), "B_HEIGHTLOCK", master_track_lock)
	for i = 0, n_tracks - 1 do
		reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, i), "B_HEIGHTLOCK", locks[i])
	end

	-- Restore track height overrides
	reaper.SetMediaTrackInfo_Value(reaper.GetMasterTrack(0), "I_HEIGHTOVERRIDE", master_track_override)
	for i = 0, n_tracks - 1 do
		reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, i), "I_HEIGHTOVERRIDE", overrides[i])
	end

	reaper.TrackList_AdjustWindows(false)

	return table.unpack(retvals)
end

function vzoom.calculate_current_default_track_height_steps()
	return vzoom.execute_with_current_track_heights_locked(function()
		-- Insert a new track at the top of the track control panel
		reaper.InsertTrackAtIndex(0, false)

		-- If the MAXIMIZE_TOGGLE_COMMAND is not on, execute it
		if reaper.GetToggleCommandState(MAXIMIZE_TOGGLE_COMMAND) < 1 then
			reaper.Main_OnCommand(MAXIMIZE_TOGGLE_COMMAND, 0)
		end
		-- Get track height and save it
		local max_h = reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, 0), "I_TCPH")

		-- If the MINIMIZE_TOGGLE_COMMAND is not on, execute it
		if reaper.GetToggleCommandState(MINIMIZE_TOGGLE_COMMAND) < 1 then
			reaper.Main_OnCommand(MINIMIZE_TOGGLE_COMMAND, 0)
		end
		-- Get track height and save it
		local min_h = reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, 0), "I_TCPH")

		-- Store the track height steps
		local steps = {}
		table.insert(steps, min_h)
		while true do
			-- Calculate new height
			reaper.Main_OnCommand(ZOOM_IN_COMMAND, 0)
			local height = reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, 0), "I_TCPH")
			if height >= max_h then break end

			-- Store new height
			table.insert(steps, height)
		end
		table.insert(steps, max_h)

		-- Delete the new track
		reaper.DeleteTrack(reaper.GetTrack(0, 0))

		return steps
	end)
end

function vzoom.get_current_min_track_height()
	local supercollapsed, collapsed, small, recarm = reaper.NF_GetThemeDefaultTCPHeights()
	return collapsed
end

function vzoom.get_current_max_track_height()
	return vzoom.execute_with_current_track_heights_locked(function()
		-- Insert a new track at the top of the track control panel
		reaper.InsertTrackAtIndex(0, false)

		-- If the MAXIMIZE_TOGGLE_COMMAND is not on, execute it
		if reaper.GetToggleCommandState(MAXIMIZE_TOGGLE_COMMAND) < 1 then
			reaper.Main_OnCommand(MAXIMIZE_TOGGLE_COMMAND, 0)
		end
		-- Get track height and save it
		local h = reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, 0), "I_TCPH")

		-- Delete the new track
		reaper.DeleteTrack(reaper.GetTrack(0, 0))

		return h
	end)
end

-- Aliased for get_max_track_h
vzoom.get_tcp_height = vzoom.get_current_max_track_height
vzoom.get_arrange_view_height = vzoom.get_current_max_track_height

--[[
	New heights are calculated as follows: `new_height = old_height + old_height * scale_factor + height_increase`.
	The maximum track height is considered as the height of the arrange view.
]]
function vzoom.zoom_vertically_preserving_track_heights(
	scale_factor, --number, optional (default: 1), scaling factor
	height_increase --umber, optional (default: 0), height increase
)
	-- Set default values
	scale_factor = scale_factor or 1
	height_increase = height_increase or 0

	local n_tracks = reaper.CountTracks(0)
	if n_tracks <= 0 then return end

	local min_h = vzoom.get_current_min_track_height()

	-- Master track height
	local master_height
	master_height = reaper.GetMediaTrackInfo_Value(reaper.GetMasterTrack(0), "I_TCPH")
	local locked = reaper.GetMediaTrackInfo_Value(reaper.GetMasterTrack(0), "B_HEIGHTLOCK")
	-- Ignore if locked
	if locked == 0 then
		-- Calculate new height
		master_height = math.max(master_height * scale_factor + height_increase, min_h)
	end

	-- Other track heights
	local heights = {}
	for i = 0, n_tracks - 1 do
		heights[i] = reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, i), "I_TCPH")
		local locked = reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, i), "B_HEIGHTLOCK")

		-- Ignore locked tracks
		if locked ~= 0 then goto continue end

		-- Calculate new height
		heights[i] = math.max(heights[i] * scale_factor + height_increase, min_h)
		::continue::
	end

	reaper.PreventUIRefresh(1)
	reaper.SetMediaTrackInfo_Value(reaper.GetMasterTrack(0), "I_HEIGHTOVERRIDE", master_height)
	for i = 0, n_tracks - 1 do
		reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, i), "I_HEIGHTOVERRIDE", heights[i])
	end
	reaper.PreventUIRefresh(-1)
	reaper.TrackList_AdjustWindows(true)
end

function vzoom.set_track_height_lock_indicator(track, lock_state)
	local success, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
	if not success then
		return
	end
	if lock_state == 0 then
		if track_name:find("^🔒 ") then
			reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name:gsub("^🔒 ", ""), true)
		end
	else
		if not track_name:find("^🔒 ") then
			reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "🔒 " .. track_name, true)
		end
	end
end

function vzoom.update_track_height_lock_indicators()
	local track = reaper.GetMasterTrack(0)
	local lock_state = reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	vzoom.set_track_height_lock_indicator(track, lock_state)
	for i = 0, reaper.CountTracks(0) - 1 do
		track = reaper.GetTrack(0, i)
		lock_state = reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
		vzoom.set_track_height_lock_indicator(track, lock_state)
	end
end

return vzoom

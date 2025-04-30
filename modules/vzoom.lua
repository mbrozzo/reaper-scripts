local vzoom = {}

vzoom.MAX_VZOOM = 40 -- Maximum zoom level
vzoom.MINIMIZE_TOGGLE_COMMAND_ID = 40110 -- Command ID for toggling track height to minimum
vzoom.MAXIMIZE_TOGGLE_COMMAND_ID = 40113 -- Command ID for toggling track height to maximum
vzoom.ZOOM_IN_COMMAND_ID = 40111 -- Command ID for zooming in
vzoom.ZOOM_OUT_COMMAND_ID = 40112 -- Command ID for zooming out

function vzoom.execute_keeping_vzoom_and_track_heights(func, ...)
	-- Store vzoom3 value
	local vzoom3 = reaper.SNM_GetDoubleConfigVar("vzoom3", -1)
	if vzoom3 == -1 then
		reaper.ShowMessageBox("vzoom3 not found", "Error", 0)
		return
	end

	-- Lock track heights, and save lock and override states
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

	-- Restore vzoom3 value
	reaper.SNM_SetDoubleConfigVar("vzoom3", vzoom3)

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

function vzoom.zoom_proportionally(change_zoom, ...)
	-- Save lock and override states
	local master_track = reaper.GetMasterTrack(0)
	local master_track_lock = reaper.GetMediaTrackInfo_Value(master_track, "B_HEIGHTLOCK")
	local master_track_override = reaper.GetMediaTrackInfo_Value(master_track, "I_HEIGHTOVERRIDE")
	local n_tracks = reaper.CountTracks(0)
	if n_tracks < 0 then return end
	local locks = {}
	local overrides = {}
	for i = 0, n_tracks - 1 do
		local track = reaper.GetTrack(0, i)
		locks[i] = reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
		overrides[i] = reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
	end

	-- Insert a new track at the bottom of the track control panel
	reaper.InsertTrackInProject(0, n_tracks, 0)
	local track = reaper.GetTrack(0, n_tracks)

	-- Get track height and save it
	local old_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

	local retvals = { change_zoom(...) }

	-- Get track height and save it
	local new_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

	-- Delete the new track
	reaper.DeleteTrack(track)

	-- Calculate height ratio
	local ratio = new_h / old_h

	-- Restore track height overrides
	if master_track_override ~= 0 then
		if master_track_lock ~= 0 then
			master_track_override = master_track_override * ratio
		end
		reaper.SetMediaTrackInfo_Value(reaper.GetMasterTrack(0), "I_HEIGHTOVERRIDE", master_track_override)
	end
	for i = 0, n_tracks - 1 do
		if overrides[i] ~= 0 then
			if locks[i] ~= 0 then
				overrides[i] = overrides[i] * ratio
			end
			reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, i), "I_HEIGHTOVERRIDE", overrides[i])
		end
	end

	reaper.TrackList_AdjustWindows(false)

	return table.unpack(retvals)
end

function vzoom.get_current_min_track_height()
	local supercollapsed, collapsed, small, recarm = reaper.NF_GetThemeDefaultTCPHeights()
	return collapsed
end

function vzoom.get_current_max_track_height()
	return vzoom.execute_keeping_vzoom_and_track_heights(function()
		-- Get the number of tracks
		local n_tracks = reaper.GetNumTracks()

		-- Insert a new track at the bottom of the track control panel
		reaper.InsertTrackAtIndex(n_tracks, false)
		local track = reaper.GetTrack(0, n_tracks)

		-- Set maximum zoom
		reaper.SNM_SetDoubleConfigVar("vzoom3", vzoom.MAX_VZOOM)
		reaper.TrackList_AdjustWindows(true)

		-- Get track height and save it
		local h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

		-- Delete the new track
		reaper.DeleteTrack(track)

		return h
	end)
end

-- Aliases for get_max_track_h
vzoom.get_tcp_height = vzoom.get_current_max_track_height
vzoom.get_arrange_view_height = vzoom.get_current_max_track_height


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

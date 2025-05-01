local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '?.lua;' .. package.path;
local luautils = require("luautils")
local reautils = require("reautils")

local vzoom = {}

vzoom.MAX_VZOOM = 40                     -- Maximum zoom level
vzoom.MINIMIZE_TOGGLE_COMMAND_ID = 40110 -- Command ID for toggling track height to minimum
vzoom.MAXIMIZE_TOGGLE_COMMAND_ID = 40113 -- Command ID for toggling track height to maximum
vzoom.ZOOM_IN_COMMAND_ID = 40111         -- Command ID for zooming in
vzoom.ZOOM_OUT_COMMAND_ID = 40112        -- Command ID for zooming out

function vzoom.execute_keeping_vzoom_and_track_heights(func, ...)
	-- Store vzoom3 value
	local vzoom3 = reaper.SNM_GetDoubleConfigVar("vzoom3", -1)
	if vzoom3 == -1 then
		reaper.ShowMessageBox("vzoom3 not found", "Error", 0)
		return
	end

	-- Save lock and override states
	local tracks = reautils.get_all_tracks(true)
	local locks = luautils.map(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	end)
	local overrides = luautils.map(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
	end)

	-- Lock track heights
	for _, track in ipairs(tracks) do
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE",
			reaper.GetMediaTrackInfo_Value(track, "I_TCPH"))
		reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", 1)
	end

	-- Execute function
	local retvals = { func(...) }

	-- Restore vzoom3 value
	reaper.SNM_SetDoubleConfigVar("vzoom3", vzoom3)

	-- Restore track height locks and overrides
	for i, track in ipairs(tracks) do
		reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", locks[i])
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", overrides[i])
	end

	reaper.TrackList_AdjustWindows(false)

	return table.unpack(retvals)
end

function vzoom.zoom_proportionally(change_zoom, ...)
	-- Save lock and override states
	local tracks = reautils.get_all_tracks(true)
	local locks = luautils.map(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	end)
	local overrides = luautils.map(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
	end)
	-- If all overrides are 0 or locked, just call the function
	if luautils.all(overrides, function(override, i)
			return override == 0 or (override ~= 0 and locks[i] == 1)
		end) then
		return change_zoom(...)
	end
	-- else
	reaper.ShowConsoleMsg("not all overrides are 0 or locked\n")

	-- Search for an unlocked track without height override, excluding the master track
	local measured_track = nil
	for i, override in pairs(overrides) do
		if override == 0 and locks[i] == 0 and i > 1 then
			measured_track = tracks[i]
			break
		end
	end
	-- If no unlocked track without height overrides found, add one at the end
	local was_new_track_added = false
	if measured_track == nil then
		local n_tracks = reaper.GetNumTracks()
		reaper.InsertTrackInProject(0, n_tracks, 0)
		measured_track = reaper.GetTrack(0, n_tracks)
		was_new_track_added = true
		reaper.ShowConsoleMsg("New track added\n")
	end

	-- Get track height and save it
	local old_h = reaper.GetMediaTrackInfo_Value(measured_track, "I_TCPH")

	-- -- Set all track height overrides to 0
	-- -- This is needed to avoid other track heights being set to the tallest track
	-- if not luautils.only_contains_value(overrides, 0) then
	-- 	for _, track in pairs(tracks) do
	-- 		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 0)
	-- 	end
	-- 	reaper.TrackList_AdjustWindows(false)
	-- end

	-- Execute the change zoom function
	local retvals = { change_zoom(...) }

	-- Get track height and save it
	local new_h = reaper.GetMediaTrackInfo_Value(measured_track, "I_TCPH")

	-- If a new track was added, delete it
	if was_new_track_added then
		reaper.DeleteTrack(measured_track)
	end

	-- Calculate height ratio
	local ratio = new_h / old_h

	-- Update track height overrides
	for i, track in pairs(tracks) do
		if overrides[i] ~= 0 then
			if locks[i] == 0 then
				overrides[i] = overrides[i] * ratio
			end
			reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", overrides[i])
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
			track_name = track_name:gsub("^🔒 ", "")
		end
		if not track_name:find("^🔓 ") then
			track_name = "🔓 " .. track_name
		end
	else
		if track_name:find("^🔓 ") then
			track_name = track_name:gsub("^🔓 ", "")
		end
		if not track_name:find("^🔒 ") then
			track_name = "🔒 " .. track_name
		end
	end
	reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name, true)
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

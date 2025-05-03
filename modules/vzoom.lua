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

function vzoom.get_current_min_track_height()
	local _, collapsed, _, _ = reaper.NF_GetThemeDefaultTCPHeights()
	return collapsed
end

function vzoom.get_arrange_view_height()
	local _, _, top, _, bottom = reaper.JS_Window_GetClientRect(reautils.get_arrange_hwnd())
	return bottom - top
end

-- Aliases for get_arrange_view_height
vzoom.get_tcp_height = vzoom.get_arrange_view_height
vzoom.get_current_max_track_height = vzoom.get_arrange_view_height

function vzoom.estimate_track_height(vzoom3)
	local _, collapsed, small, recarm = reaper.NF_GetThemeDefaultTCPHeights()
	local h_max = vzoom.get_current_max_track_height()
	local h_30 = luautils.round(recarm + (h_max - recarm) * 0.4636)
	if vzoom3 < 2 then
		return luautils.round(collapsed + (small - collapsed) / 2 * vzoom3)
	end
	if vzoom3 < 4 then
		return luautils.round(small + (recarm - small) / 2 * (vzoom3 - 2))
	end
	if vzoom3 < 30 then
		return luautils.round(recarm + (h_30 - recarm) / 26 * (vzoom3 - 4))
	end
	if vzoom3 < 40 then
		return luautils.round(h_30 + (h_max - h_30) / 10 * (vzoom3 - 30))
	end
	return h_max
end

function vzoom.estimate_vzoom3(track_height)
	local _, collapsed, small, recarm = reaper.NF_GetThemeDefaultTCPHeights()
	local h_max = vzoom.get_current_max_track_height()
	local h_30 = luautils.round(recarm + (h_max - recarm) * 0.4636)
	if track_height < small then
		return 2 / (small - collapsed) * (track_height - collapsed)
	end
	if track_height < recarm then
		return 2 + 2 / (recarm - small) * (track_height - small)
	end
	if track_height < h_30 then
		return 4 + 26 / (h_30 - recarm) * (track_height - recarm)
	end
	if track_height < h_max then
		return 30 + 10 / (h_max - h_30) * (track_height - h_30)
	end
	return vzoom.MAX_VZOOM
end

function vzoom.get_max_vzoom()
	return vzoom.estimate_vzoom3(vzoom.get_current_max_track_height() *
		reaper.SNM_GetDoubleConfigVar("maxvzoom", 1))
end

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

function vzoom.zoom_proportionally_no_scroll(change_zoom, ...)
	-- Save lock and override states
	local tracks = reautils.get_all_tracks(true)
	local locks = luautils.map(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	end)
	local overrides = luautils.map(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
	end)
	-- Save envelope states
	local envelopes_by_track = luautils.map(tracks, function(track)
		return reautils.get_all_envelopes(track)
	end)
	local envelope_overrides_by_track = luautils.map(envelopes_by_track, function(envelopes)
		return luautils.map(envelopes, function(envelope)
			return reautils.get_envelope_height_override(envelope)
		end)
	end)
	-- If all track are locked or don't have overrides, just call the function
	if luautils.all(locks, function(lock, i)
			return lock == 1 or (overrides[i] == 0 and luautils.only_contains_value(envelope_overrides_by_track[i], 0))
		end) then
		local retvals = { change_zoom(...) }
		reaper.TrackList_AdjustWindows(false)
		return retvals
	end
	-- else

	-- Estimate track height and save it
	local old_h = vzoom.estimate_track_height(reaper.SNM_GetDoubleConfigVar("vzoom3", -1))

	-- Execute the change zoom function
	local retvals = { change_zoom(...) }

	-- Estimate track height and save it
	local new_h = vzoom.estimate_track_height(reaper.SNM_GetDoubleConfigVar("vzoom3", -1))

	-- Calculate height ratio
	local ratio = new_h / old_h

	-- Update track and envelope height overrides
	for i, track in pairs(tracks) do
		if locks[i] == 1 then goto continue end
		-- Tracks
		if overrides[i] ~= 0 then
			new_override = math.max(luautils.round(overrides[i] * ratio), 1)
			reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", new_override)
		end
		-- Envelopes
		for j, envelope in pairs(envelopes_by_track[i]) do
			if envelope_overrides_by_track[i][j] ~= 0 then
				new_height = math.max(luautils.round(envelope_overrides_by_track[i][j] * ratio), 1)
				reautils.set_envelope_height_override(envelope, new_height)
			end
		end
		::continue::
	end

	reaper.TrackList_AdjustWindows(false)

	return table.unpack(retvals)
end

vzoom.vertical_zoom_modes = {
	TRACK_AT_VIEW_CENTER = 0,
	TOP_OF_VIEW = 1,
	LAST_SELECTED_TRACK = 2,
	TRACK_UNDER_MOUSE = 3,
}

function vzoom.zoom_proportionally(change_zoom, ...)
	-- Get information to handle scrolling
	local is_success, position, page_size, min, max, track_pos =
		reaper.JS_Window_GetScrollInfo(reautils.get_tcp_hwnd(), "SB_VERT")
	reaper.ShowConsoleMsg("is_success: " .. tostring(is_success) .. "\n")
	reaper.ShowConsoleMsg("position: " .. position .. "\n")
	reaper.ShowConsoleMsg("page_size: " .. page_size .. "\n")
	reaper.ShowConsoleMsg("min: " .. min .. "\n")
	reaper.ShowConsoleMsg("max: " .. max .. "\n")
	reaper.ShowConsoleMsg("track_pos: " .. track_pos .. "\n")

	local vzoommode = reaper.SNM_GetDoubleConfigVar("vzoommode", 0)
	local vzoom_center_track = nil -- TOP_OF_VIEW
	if was_scroll_info_retrieved_successfully then
		if vzoommode == vzoom.vertical_zoom_modes.LAST_SELECTED_TRACK then
			vzoom_center_track = reaper.GetLastTouchedTrack()
		elseif vzoommode == vzoom.vertical_zoom_modes.TRACK_UNDER_MOUSE then
			vzoom_center_track = reautils.get_track_at_mouse()
		else -- TRACK_AT_VIEW_CENTER (default)
			vzoom_center_track = reautils.get_track_at_view_center()
		end
	end

	-- Zoom
	vzoom.zoom_proportionally_no_scroll(change_zoom, ...)

	-- Handle scrolling
	if was_scroll_info_retrieved_successfully then
		-- Idea per corretto resizing della pagina quando dezoommi:
		-- - spostare scroll in cima
		-- - renderizzare se necessario
		-- - leggere pagesize

		local is_success, new_position, new_page_size, new_min, new_max, new_track_pos =
			reaper.JS_Window_GetScrollInfo(reautils.get_arrange_hwnd(), "SB_VERT")
		reaper.ShowConsoleMsg("retval: " .. tostring(is_success) .. "\n")
		reaper.ShowConsoleMsg("new_position: " .. new_position .. "\n")
		reaper.ShowConsoleMsg("new_page_size: " .. new_page_size .. "\n")
		reaper.ShowConsoleMsg("new_min: " .. new_min .. "\n")
		reaper.ShowConsoleMsg("new_max: " .. new_max .. "\n")
		reaper.ShowConsoleMsg("new_track_pos: " .. new_track_pos .. "\n")
		local max_position
		if was_scroll_info_retrieved_successfully then
			max_position = max - pageSize
		else
			max_position = vzoom.get_tcp_height()
		end

		local target_pos = position * new_max / max -- TOP_OF_VIEW
		-- TODO
		-- if vzoommode == vzoom.vertical_zoom_modes.LAST_SELECTED_TRACK and vzoom_center_track then
		-- 	vzoom_center_track = reaper.GetLastTouchedTrack()
		-- 	if last_sel_track then
		-- 		target_pos = reaper.GetMediaTrackInfo_Value(last_sel_track, "I_TCPY")
		-- 	end
		-- elseif vzoommode == vzoom.vertical_zoom_modes.TRACK_UNDER_MOUSE and vzoom_center_track then
		-- elseif vzoommode == vzoom.vertical_zoom_modes.TRACK_AT_VIEW_CENTER and vzoom_center_track then
		-- else --
		-- end
		reaper.JS_Window_SetScrollPos(reautils.get_arrange_hwnd(), "SB_VERT", math.min(target_pos, max_position))
	end
end

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

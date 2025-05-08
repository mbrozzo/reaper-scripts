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

function vzoom.get_arrange_view_height(arrange_view_hwnd)
	arrange_view_hwnd = arrange_view_hwnd or reautils.get_arrange_view_hwnd()
	local _, _, top, _, bottom = reaper.JS_Window_GetClientRect(arrange_view_hwnd)
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
	local locks = luautils.imap(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	end)
	local overrides = luautils.imap(tracks, function(track)
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

vzoom.vertical_zoom_modes = {
	TRACK_AT_VIEW_CENTER = 0,
	TOP_OF_VIEW = 1,
	LAST_SELECTED_TRACK = 2,
	TRACK_UNDER_MOUSE = 3,
}

vzoom.DEFAULT_VERTICAL_SPACE_AFTER_TRACKS = 60 -- pixels

function vzoom.get_tcp_elements_height(master_track, last_track)
	master_track = master_track or reaper.GetMasterTrack(0)
	last_track = last_track or reaper.GetTrack(0, reaper.CountTracks(0) - 1) or master_track
	local y_start = reaper.GetMediaTrackInfo_Value(master_track, "I_TCPY")
	local y_end = reaper.GetMediaTrackInfo_Value(last_track, "I_TCPY") +
		reaper.GetMediaTrackInfo_Value(last_track, "I_WNDH")
	return y_end - y_start
end

function vzoom.get_vzoom_center_y(vzoom_mode, arrange_view_hwnd)
	vzoom_mode = vzoom_mode or reaper.SNM_GetDoubleConfigVar("vzoommode", 0)
	arrange_view_hwnd = arrange_view_hwnd or reautils.get_arrange_view_hwnd()
	local arrange_view_height = vzoom.get_arrange_view_height(arrange_view_hwnd)
	local vzoom_center_y = arrange_view_height / 2 -- Default to center of arrange view
	if vzoom_mode == vzoom.vertical_zoom_modes.TOP_OF_VIEW then
		vzoom_center_y = 0
	elseif vzoom_mode == vzoom.vertical_zoom_modes.LAST_SELECTED_TRACK then
		local vzoom_center_track = reaper.GetLastTouchedTrack()
		if vzoom_center_track then
			vzoom_center_y = reaper.GetMediaTrackInfo_Value(vzoom_center_track, "I_TCPY") +
				reaper.GetMediaTrackInfo_Value(vzoom_center_track, "I_TCPH") / 2
		end
	elseif vzoom_mode == vzoom.vertical_zoom_modes.TRACK_UNDER_MOUSE then
		-- Get mouse vertical position relative to arrange view
		local _, mouse_y = reaper.GetMousePosition()
		local success, _, _, _, top = reaper.JS_Window_GetClientRect(arrange_view_hwnd)
		if success then
			vzoom_center_y = math.min(math.max(mouse_y - top, 0), arrange_view_height)
		end
	end
	return vzoom_center_y
end

function vzoom.zoom_proportionally(
	change_zoom,                 -- Zooming function
	is_adjust_scroll,            -- Adjust scroll position after zooming
	is_remove_and_restore_overrides -- Remove height overrides to prevent wrong track sizing
)
	is_adjust_scroll = is_adjust_scroll or true
	is_remove_and_restore_overrides = is_remove_and_restore_overrides or false

	-- Save lock and override states
	local tracks = reautils.get_all_tracks(true)
	local locks = luautils.imap(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	end)
	local overrides = luautils.imap(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
	end)
	-- Save envelope states
	local envelopes_by_track = luautils.imap(tracks, reautils.get_all_envelopes)
	local envelope_overrides_by_track = luautils.imap(envelopes_by_track, function(envelopes)
		return luautils.imap(envelopes, function(envelope)
			return reautils.get_envelope_height_override(envelope)
		end)
	end)

	local arrange_view_hwnd
	local is_scroll_success, scroll_position, scroll_page_size, scroll_min, scroll_max, scroll_track_pos
	local tcp_elements_height
	local vzoom_mode
	local vzoom_y
	local vzoom_el_type, vzoom_el, vzoom_el_after, vzoom_el_y, vzoom_el_h
	if is_adjust_scroll then
		-- Gather information to handle scrolling
		arrange_view_hwnd = reautils.get_arrange_view_hwnd()

		is_scroll_success, scroll_position, scroll_page_size, scroll_min, scroll_max, scroll_track_pos =
			reaper.JS_Window_GetScrollInfo(arrange_view_hwnd, "SB_VERT")
		tcp_elements_height = vzoom.get_tcp_elements_height(tracks[1], tracks[#tracks])

		vzoom_mode = reaper.SNM_GetDoubleConfigVar("vzoommode", 0)
		vzoom_y = vzoom.get_vzoom_center_y(vzoom_mode, arrange_view_hwnd)
		vzoom_el_type, vzoom_el, vzoom_el_after, vzoom_el_y, vzoom_el_h =
			reautils.get_element_at_tcp_y(tracks, vzoom_y)
	end

	-- Estimate track height before zooming
	local old_h = vzoom.estimate_track_height(reaper.SNM_GetDoubleConfigVar("vzoom3", -1))

	if is_remove_and_restore_overrides then
		-- Remove height overrides to prevent zoom actions and functions using the wrong track size
		-- Causes flickering
		for _, track in ipairs(tracks) do
			reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 0)
		end
	end

	-- Execute the change zoom function
	local retvals = { change_zoom() }

	-- Estimate track height after zooming
	local new_h = vzoom.estimate_track_height(reaper.SNM_GetDoubleConfigVar("vzoom3", -1))

	-- Calculate height ratio
	local ratio = new_h / old_h

	-- Update track and envelope height overrides where necessary
	local new_overrides = luautils.imap(overrides, function(override, i)
		local new_override = override
		if override ~= 0 then
			if locks[i] ~= 1 then
				new_override = math.max(luautils.round(override * ratio), 1)
			end
			reaper.SetMediaTrackInfo_Value(tracks[i], "I_HEIGHTOVERRIDE", new_override)
		end
		return new_override
	end)
	local new_envelope_overrides_by_track = luautils.imap(envelope_overrides_by_track, function(overrides, i)
		return luautils.imap(overrides, function(override, j)
			local new_override = override
			if override ~= 0 then
				if locks[i] ~= 1 then
					new_override = math.max(luautils.round(override * ratio), 1)
				end
				reautils.set_envelope_height_override(envelopes_by_track[i][j], new_override)
			end
			return new_override
		end)
	end)

	-- reaper.TrackList_AdjustWindows(false) -> TODO necessario?

	if is_adjust_scroll then
		-- Handle scrolling
		-- TODO
		if vzoom_mode == vzoom.vertical_zoom_modes.TOP_OF_VIEW then
		elseif vzoom_mode == vzoom.vertical_zoom_modes.LAST_SELECTED_TRACK then
		elseif vzoom_mode == vzoom.vertical_zoom_modes.TRACK_UNDER_MOUSE then
		end

		local new_is_success, new_position, new_page_size, new_min, new_max, new_track_pos =
			reaper.JS_Window_GetScrollInfo(arrange_view_hwnd, "SB_VERT")
		local new_all_tracks_height = vzoom.get_tcp_elements_height(tracks[1], tracks[#tracks])
		-- reaper.ShowConsoleMsg("retval: " .. tostring(is_success) .. "\n")
		-- reaper.ShowConsoleMsg("new_position: " .. new_position .. "\n")
		-- reaper.ShowConsoleMsg("new_page_size: " .. new_page_size .. "\n")
		-- reaper.ShowConsoleMsg("new_min: " .. new_min .. "\n")
		-- reaper.ShowConsoleMsg("new_max: " .. new_max .. "\n")
		-- reaper.ShowConsoleMsg("new_track_pos: " .. new_track_pos .. "\n")
		-- reaper.ShowConsoleMsg("new_all_tracks_height: " .. new_all_tracks_height .. "\n")
		if new_is_success then
			-- Zoom mode TOP_OF_VIEW
			-- TODO
			-- -- Other zoom modes
			-- if vzoommode == vzoom.vertical_zoom_modes.LAST_SELECTED_TRACK and vzoom_center_track then
			-- 	vzoom_center_track = reaper.GetLastTouchedTrack()
			-- 	if last_sel_track then
			-- 		target_pos = reaper.GetMediaTrackInfo_Value(last_sel_track, "I_TCPY")
			-- 	end
			-- elseif vzoommode == vzoom.vertical_zoom_modes.TRACK_UNDER_MOUSE and vzoom_center_track then
			-- elseif vzoommode == vzoom.vertical_zoom_modes.TRACK_AT_VIEW_CENTER and vzoom_center_track then
			-- else --
			-- end
			reaper.ShowConsoleMsg("target_position: " .. target_position .. "\n")
			-- reaper.JS_Window_SetScrollPos(arrange_view_hwnd, "SB_VERT", target_position)
		end
		-- TODO: when zooming in, scroll so that center track stays in view
	end

	reaper.TrackList_AdjustWindows(false)
	return table.unpack(retvals)
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

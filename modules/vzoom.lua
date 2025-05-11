local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '?.lua;' .. package.path;
local lu = require("luautils")
local ru = require("reautils")

local vzoom = {}

vzoom.DEFAULT_MAX_VZOOM = 40                   -- Maximum zoom level
vzoom.MINIMIZE_TOGGLE_COMMAND_ID = 40110       -- Command ID for toggling track height to minimum
vzoom.MAXIMIZE_TOGGLE_COMMAND_ID = 40113       -- Command ID for toggling track height to maximum
vzoom.ZOOM_IN_COMMAND_ID = 40111               -- Command ID for zooming in
vzoom.ZOOM_OUT_COMMAND_ID = 40112              -- Command ID for zooming out
vzoom.DEFAULT_VERTICAL_SPACE_AFTER_TRACKS = 60 -- pixels
vzoom.VERTICAL_ZOOM_MODES = {
	TRACK_AT_VIEW_CENTER = 0,
	TOP_OF_VIEW = 1,
	LAST_SELECTED_TRACK = 2,
	TRACK_UNDER_MOUSE = 3,
}

function vzoom.get_current_min_track_height()
	local _, collapsed, _, _ = reaper.NF_GetThemeDefaultTCPHeights()
	return collapsed
end

function vzoom.get_arrange_view_height(arrange_view_hwnd)
	arrange_view_hwnd = arrange_view_hwnd or ru.arrange_view.get_hwnd()
	local _, _, top, _, bottom = reaper.JS_Window_GetClientRect(arrange_view_hwnd)
	return bottom - top
end

-- Aliases for get_arrange_view_height
vzoom.get_tcp_height = vzoom.get_arrange_view_height
vzoom.get_current_max_track_height = vzoom.get_arrange_view_height

function vzoom.estimate_default_track_height(vzoom3)
	local _, collapsed, small, recarm = reaper.NF_GetThemeDefaultTCPHeights()
	local h_max = vzoom.get_current_max_track_height()
	local h_30 = lu.math.round(recarm + (h_max - recarm) * 0.4636)
	if vzoom3 < 2 then
		return lu.math.round(collapsed + (small - collapsed) / 2 * vzoom3)
	end
	if vzoom3 < 4 then
		return lu.math.round(small + (recarm - small) / 2 * (vzoom3 - 2))
	end
	if vzoom3 < 30 then
		return lu.math.round(recarm + (h_30 - recarm) / 26 * (vzoom3 - 4))
	end
	if vzoom3 < 40 then
		return lu.math.round(h_30 + (h_max - h_30) / 10 * (vzoom3 - 30))
	end
	return h_max
end

function vzoom.estimate_vzoom3(default_track_height)
	local _, collapsed, small, recarm = reaper.NF_GetThemeDefaultTCPHeights()
	local h_max = vzoom.get_current_max_track_height()
	local h_30 = lu.math.round(recarm + (h_max - recarm) * 0.4636)
	if default_track_height < small then
		return 2 / (small - collapsed) * (default_track_height - collapsed)
	end
	if default_track_height < recarm then
		return 2 + 2 / (recarm - small) * (default_track_height - small)
	end
	if default_track_height < h_30 then
		return 4 + 26 / (h_30 - recarm) * (default_track_height - recarm)
	end
	if default_track_height < h_max then
		return 30 + 10 / (h_max - h_30) * (default_track_height - h_30)
	end
	return vzoom.DEFAULT_MAX_VZOOM
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
	local tracks = ru.track.get_all(true)
	local locks = lu.table.imap(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	end)
	local overrides = lu.table.imap(tracks, function(track)
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

function vzoom.get_vzoom_center_y(vzoom_mode, arrange_view_hwnd)
	vzoom_mode = vzoom_mode or reaper.SNM_GetIntConfigVar("vzoommode", 0)
	arrange_view_hwnd = arrange_view_hwnd or ru.arrange_view.get_hwnd()
	local arrange_view_height = vzoom.get_arrange_view_height(arrange_view_hwnd)
	local vzoom_y = arrange_view_height / 2 -- Default to center of arrange view
	if vzoom_mode == vzoom.VERTICAL_ZOOM_MODES.TOP_OF_VIEW then
		vzoom_y = 0
	elseif vzoom_mode == vzoom.VERTICAL_ZOOM_MODES.LAST_SELECTED_TRACK then
		local vzoom_center_track = reaper.GetLastTouchedTrack()
		if vzoom_center_track then
			vzoom_y = reaper.GetMediaTrackInfo_Value(vzoom_center_track, "I_TCPY") +
				reaper.GetMediaTrackInfo_Value(vzoom_center_track, "I_TCPH") / 2
		end
	elseif vzoom_mode == vzoom.VERTICAL_ZOOM_MODES.TRACK_UNDER_MOUSE then
		-- Get mouse vertical position relative to arrange view
		local _, mouse_y = reaper.GetMousePosition()
		local success, _, top, _, _ = reaper.JS_Window_GetClientRect(arrange_view_hwnd)
		if success then
			vzoom_y = math.min(math.max(mouse_y - top, 0), arrange_view_height)
		end
	end
	return vzoom_y
end

function vzoom.zoom_proportionally(change_zoom)
	-- Save lock and override states
	local tracks = ru.track.get_all(true)
	local locks = lu.table.imap(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
	end)
	local overrides = lu.table.imap(tracks, function(track)
		return reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
	end)
	-- Save envelope states
	local envelopes_by_track = lu.table.imap(tracks, ru.envelope.get_all)
	local envelope_overrides_by_track = lu.table.imap(envelopes_by_track, function(envelopes)
		return lu.table.imap(envelopes, function(envelope)
			return ru.envelope.get_height_override(envelope)
		end)
	end)

	-- Gather information to handle scrolling
	local vzoom_mode = reaper.SNM_GetIntConfigVar("vzoommode", 0)
	local arrange_view_hwnd = ru.arrange_view.get_hwnd()
	local vzoom_y = vzoom.get_vzoom_center_y(vzoom_mode, arrange_view_hwnd)
	local vzoom_el_type, vzoom_el, vzoom_el_y, vzoom_el_h = ru.tcp.get_element_at_y(tracks, vzoom_y)
	local arrange_view_height = vzoom.get_arrange_view_height(arrange_view_hwnd)

	-- Estimate track height before zooming
	local old_h = vzoom.estimate_default_track_height(reaper.SNM_GetDoubleConfigVar("vzoom3", -1))

	-- Execute the change zoom function
	local retvals = { change_zoom() }

	-- Estimate track height after zooming
	local new_h = vzoom.estimate_default_track_height(reaper.SNM_GetDoubleConfigVar("vzoom3", -1))

	-- Calculate height ratio
	local ratio = new_h / old_h

	-- Update track and envelope height overrides where necessary
	for i, override in ipairs(overrides) do
		if override ~= 0 then
			local new_override
			if locks[i] ~= 1 then
				new_override = math.max(lu.math.round(override * ratio), 1)
			else
				new_override = override
			end
			reaper.SetMediaTrackInfo_Value(tracks[i], "I_HEIGHTOVERRIDE", new_override)
		end
	end
	for i, overrides in ipairs(envelope_overrides_by_track) do
		for j, override in ipairs(overrides) do
			if override ~= 0 then
				local new_override = override
				if locks[i] ~= 1 then
					new_override = math.max(lu.math.round(override * ratio), 1)
				end
				ru.envelope.set_height_override(envelopes_by_track[i][j], new_override)
			end
		end
	end

	-- Causes flickering but is necessary to get TCP heights after overrides
	reaper.TrackList_AdjustWindows(false)

	if vzoom_el then
		-- Gather new information on vzoom center element after zooming
		local new_scroll_y = -reaper.GetMediaTrackInfo_Value(tracks[1], "I_TCPY")
		local new_vzoom_el_y = nil
		local new_vzoom_el_h = 0
		if vzoom_el_type == ru.tcp.ELEMENT_TYPES.TRACK then
			new_vzoom_el_y = reaper.GetMediaTrackInfo_Value(vzoom_el, "I_TCPY")
			new_vzoom_el_h = reaper.GetMediaTrackInfo_Value(vzoom_el, "I_TCPH")
		elseif vzoom_el_type == ru.tcp.ELEMENT_TYPES.ENVELOPE then
			local track = reaper.GetEnvelopeInfo_Value(vzoom_el, "P_TRACK")
			if track then
				local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
				new_vzoom_el_y = track_y + reaper.GetEnvelopeInfo_Value(vzoom_el, "I_TCPY")
				new_vzoom_el_h = reaper.GetEnvelopeInfo_Value(vzoom_el, "I_TCPH")
			end
		elseif vzoom_el_type == ru.tcp.ELEMENT_TYPES.SPACE then
			-- Space starts at the bottom of vzoom_el track (including envelopes)
			new_vzoom_el_y = reaper.GetMediaTrackInfo_Value(vzoom_el, "I_TCPY") +
				reaper.GetMediaTrackInfo_Value(vzoom_el, "I_WNDH")
			local vzoom_el_idx = reaper.GetMediaTrackInfo_Value(vzoom_el, "IP_TRACKNUMBER")
			if vzoom_el_idx then
				local vzoom_el_after = reaper.GetTrack(0, vzoom_el_idx + 1)
				if vzoom_el_after then
					new_vzoom_el_h = reaper.GetMediaTrackInfo_Value(vzoom_el_after, "I_TCPY") -
						new_vzoom_el_y
				end
			end
		end

		-- Handle scrolling
		local is_new_scroll_info_success, _, page_size, scroll_min, scroll_max, _ =
			reaper.JS_Window_GetScrollInfo(arrange_view_hwnd, "SB_VERT")
		if is_new_scroll_info_success and new_vzoom_el_y ~= nil and new_vzoom_el_h ~= nil and new_scroll_y ~= nil then
			-- vzoom_y = vzoom.get_arrange_view_height(arrange_view_hwnd) / 2
			local final_scroll_y
			if not vzoom_el_h then
				final_scroll_y = scroll_max - page_size
			elseif vzoom_mode == vzoom.VERTICAL_ZOOM_MODES.LAST_SELECTED_TRACK then
				final_scroll_y = new_scroll_y + new_vzoom_el_y + new_vzoom_el_h / 2 -
					arrange_view_height / 2
			else
				-- offset between vzoom center and top of vzoom center element
				local vzoom_y_offset = vzoom_y - vzoom_el_y
				-- offset after zoom is proportional to height change of element
				local new_vzoom_y_offset = vzoom_y_offset * (new_vzoom_el_h / vzoom_el_h)
				-- scroll errpr
				local new_scroll_err = new_vzoom_el_y + new_vzoom_y_offset - vzoom_y
				-- final scroll value
				final_scroll_y = new_scroll_y + new_scroll_err
				-- Constrain new_scroll_y to TCP
				final_scroll_y = math.max(scroll_min,
					math.min(scroll_max - page_size, final_scroll_y))
			end

			if
				vzoom_el_type == ru.tcp.ELEMENT_TYPES.TRACK or
				vzoom_el_type == ru.tcp.ELEMENT_TYPES.ENVELOPE
			then
				-- Check if element was inside TCP or was at top of it before zoom
				if
					(vzoom_el_y >= 0 and -- Element is not above visible part of TCP
					vzoom_el_y + vzoom_el_h <= arrange_view_height) or -- Element is not below visible part of TCP
					vzoom_el_y == 0 -- Element touches the top of the visible part of TCP
				then
					-- Calculate min and max scroll to fit element in window
					local scroll_max_for_track = new_scroll_y + new_vzoom_el_y
					local scroll_min_for_track = scroll_max_for_track - arrange_view_height + new_vzoom_el_h
					-- Constrain vzoom_el to TCP
					final_scroll_y = math.min(scroll_max_for_track, math.max(scroll_min_for_track, final_scroll_y))
				end
			end

			-- Round new_scroll_y to nearest integer
			final_scroll_y = lu.math.round(final_scroll_y)

			reaper.JS_Window_SetScrollPos(arrange_view_hwnd, "SB_VERT", final_scroll_y)
		end
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

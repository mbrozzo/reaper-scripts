local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '?.lua;' .. package.path;
local lu = require("luautils")

local ru = {}

-- Actions
ru.action = {}
ru.action.ids = {
	TOGGLE_MASTER_TRACK_VISIBLE = 40075
}

-- Set ToolBar Button State
function ru.action.set_state(state)
	local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
	reaper.SetToggleCommandState(sec, cmd, state or 0)
	reaper.RefreshToolbar2(sec, cmd)
end

-- Tracks
ru.track = {}
ru.track.COMPACT_STATES = {
	NORMAL = 0.0,
	SMALL = 1.0,
	COLLAPSED_OR_HIDDEN = 2.0,
}

function ru.track.get_all(include_master)
	include_master = include_master or false
	local tracks = {}
	if include_master then
		local master_track = reaper.GetMasterTrack(0)
		table.insert(tracks, master_track)
	end
	for i = 0, reaper.CountTracks(0) - 1 do
		local track = reaper.GetTrack(0, i)
		table.insert(tracks, track)
	end
	return tracks
end

function ru.track.get_all_compact_states(ordered_tracks_no_master)
	ordered_tracks_no_master = ordered_tracks_no_master or ru.track.get_all(false)
	local track_compact_states = {}
	local folder_depth = 1
	local folder_compact_state_stack = { ru.track.COMPACT_STATES.NORMAL }
	for i, track in ipairs(ordered_tracks_no_master) do
		local prev_folder_compact_state = folder_compact_state_stack[folder_depth]
		table.insert(track_compact_states, prev_folder_compact_state)
		local depth_change = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
		folder_depth = folder_depth + depth_change
		if depth_change == 1 then -- Folder is a parent: insert folder compact state in stack
			table.insert(folder_compact_state_stack,
				math.max(reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT"), prev_folder_compact_state))
		else -- Folder is an n-th level child: pop n times from stack
			while depth_change < 0 do
				table.remove(folder_compact_state_stack)
				depth_change = depth_change + 1
			end
		end
	end
	return track_compact_states
end

-- Envelopes
ru.envelope = {}

function ru.envelope.get_all(track)
	local envelopes = {}
	for i = 0, reaper.CountTrackEnvelopes(track) - 1 do
		local envelope = reaper.GetTrackEnvelope(track, i)
		table.insert(envelopes, envelope)
	end
	return envelopes
end

function ru.envelope.get_height_override(envelope)
	local br_envelope = reaper.BR_EnvAlloc(envelope, false)
	local _, _, _, _, height, _, _, _, _, _, _ = reaper.BR_EnvGetProperties(br_envelope)
	return height
end

-- Credits: Edgemeal https://forum.cockos.com/showpost.php?p=2664097&postcount=5
function ru.envelope.set_height_override(envelope, height)
	local BR_envelope = reaper.BR_EnvAlloc(envelope, false)
	local active, visible, armed, inLane, _, defaultShape, _, _, _, _, faderScaling =
		reaper.BR_EnvGetProperties(BR_envelope)
	reaper.BR_EnvSetProperties(BR_envelope, active, visible, armed, inLane, height, defaultShape, faderScaling)
	reaper.BR_EnvFree(BR_envelope, true)
end

-- Configuration
ru.config = {}

function ru.config.get_folder_collapse_cycle()
	local tcpalign = reaper.SNM_GetIntConfigVar("tcpalign", 0)
	local is_skip_small_state = tcpalign & 512 == 512      -- 512 = b001000000000
	local is_hide_instead_of_collapse = tcpalign & 256 == 256 -- 256 = b000100000000
	return is_skip_small_state, is_hide_instead_of_collapse
end

-- Arrange view
ru.arrange_view = {}

function ru.arrange_view.get_hwnd(main_window_hwnd)
	main_window_hwnd = main_window_hwnd or reaper.GetMainHwnd()
	return reaper.JS_Window_FindEx(main_window_hwnd, nil, "REAPERTrackListWindow", "trackview")
end

-- TCP
ru.tcp = {}
ru.tcp.ELEMENT_TYPES = {
	TRACK = 1,
	ENVELOPE = 2,
	SPACE = 3,
}

function ru.tcp.get_hwnd(main_window_hwnd)
	main_window_hwnd = main_window_hwnd or reaper.GetMainHwnd()
	return reaper.JS_Window_FindEx(main_window_hwnd, nil, "REAPERTCPDisplay", "")
end

-- Returns:
-- 1. type (track/envelope/space)
-- 2. element (track/envelope) or track before space
-- 4. y of element
-- 5. height of element or nil if space at the bottom of TCP
function ru.tcp.get_element_at_y(ordered_tracks, tcp_y)
	-- initialize variables
	ordered_tracks = ordered_tracks or ru.track.get_all(true)
	local ordered_envelopes_by_track = lu.table.imap(ordered_tracks, ru.envelope.get_all)

	-- check tracks starting from the bottom
	local below_track_y = nil -- y of the previously checked track (the next track in the TCP)
	for i = #ordered_tracks, 1, -1 do
		-- check space under the current track
		local track = ordered_tracks[i]
		local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
		local space_y = track_y + reaper.GetMediaTrackInfo_Value(track, "I_WNDH")
		if tcp_y >= space_y then
			-- found spacer, return
			return
				ru.tcp.ELEMENT_TYPES.SPACE,
				track, -- track above space
				space_y,
				below_track_y and below_track_y - space_y or nil
		end
		below_track_y = track_y -- set previously checked track y to current track y
		-- check envelopes of track
		for j = #ordered_envelopes_by_track[i], 1, -1 do
			local envelope = ordered_envelopes_by_track[i][j]
			local br_envelope = reaper.BR_EnvAlloc(envelope, false)
			local _, is_visible, _, is_in_lane, _, _, _, _, _, _, _ = reaper.BR_EnvGetProperties(br_envelope)
			if is_visible and is_in_lane then
				local envelope_y = track_y + reaper.GetEnvelopeInfo_Value(envelope, "I_TCPY")
				if tcp_y >= envelope_y then
					-- found envelope, return
					return
						ru.tcp.ELEMENT_TYPES.ENVELOPE,
						envelope,
						envelope_y,
						reaper.GetEnvelopeInfo_Value(envelope, "I_TCPH")
				end
			end
		end
		-- check track
		local is_visible
		if i > 1 then
			is_visible = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP")
		else
			is_visible = reaper.GetToggleCommandStateEx(0, ru.action.ids.TOGGLE_MASTER_TRACK_VISIBLE)
		end
		if is_visible and track_y <= tcp_y then
			-- found track, return
			return
				ru.tcp.ELEMENT_TYPES.TRACK,
				track,
				track_y,
				reaper.GetMediaTrackInfo_Value(ordered_tracks[i], "I_TCPH")
		end
	end
end

return ru

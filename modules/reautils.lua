local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '?.lua;' .. package.path;
local luautils = require("luautils")

local reautils = {}

-- Set ToolBar Button State
function reautils.set_action_state(state)
	local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
	reaper.SetToggleCommandState(sec, cmd, state or 0)
	reaper.RefreshToolbar2(sec, cmd)
end

function reautils.get_all_tracks(include_master)
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

function reautils.get_all_envelopes(track)
	local envelopes = {}
	for i = 0, reaper.CountTrackEnvelopes(track) - 1 do
		local envelope = reaper.GetTrackEnvelope(track, i)
		table.insert(envelopes, envelope)
	end
	return envelopes
end

function reautils.get_envelope_height_override(envelope)
	local BR_envelope = reaper.BR_EnvAlloc(envelope, false)
	local _, _, _, _, height, _, _, _, _, _, _ = reaper.BR_EnvGetProperties(BR_envelope)
	return height
end

-- Credits: Edgemeal https://forum.cockos.com/showpost.php?p=2664097&postcount=5
function reautils.set_envelope_height_override(envelope, height)
	local BR_envelope = reaper.BR_EnvAlloc(envelope, false)
	local active, visible, armed, inLane, _, defaultShape, _, _, _, _, faderScaling =
		reaper.BR_EnvGetProperties(BR_envelope)
	reaper.BR_EnvSetProperties(BR_envelope, active, visible, armed, inLane, height, defaultShape, faderScaling)
	reaper.BR_EnvFree(BR_envelope, true)
end

reautils.track_compact_states = {
	NORMAL = 0.0,
	SMALL = 1.0,
	COLLAPSED_OR_HIDDEN = 2.0,
}
function reautils.get_all_track_compact_states(ordered_tracks_no_master)
	ordered_tracks_no_master = ordered_tracks_no_master or reautils.get_all_tracks(false)
	local track_compact_states = {}
	local folder_depth = 1
	local folder_compact_state_stack = { reautils.track_compact_states.NORMAL }
	for i, track in ipairs(ordered_tracks_no_master) do
		reaper.ShowConsoleMsg("Track " .. i .. "\n")
		reaper.ShowConsoleMsg("Depth: " .. folder_depth .. "\n")
		reaper.ShowConsoleMsg("Stack before: " .. table.concat(folder_compact_state_stack, ", ") .. "\n")
		local prev_folder_compact_state = folder_compact_state_stack[folder_depth]
		table.insert(track_compact_states, prev_folder_compact_state)
		local depth_change = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
		reaper.ShowConsoleMsg("Depth change: " .. depth_change .. "\n")
		reaper.ShowConsoleMsg("Folder compact: " .. reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT") .. "\n")
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
		reaper.ShowConsoleMsg("Stack after: " .. table.concat(folder_compact_state_stack, ", ") .. "\n")
	end
	return track_compact_states
end

function reautils.get_folder_collapse_cycle_config()
	local tcpalign = reaper.SNM_GetIntConfigVar("tcpalign", 0)
	local is_skip_small_state = tcpalign & 512 == 512      -- 512 = b001000000000
	local is_hide_instead_of_collapse = tcpalign & 256 == 256 -- 256 = b000100000000
	return is_skip_small_state, is_hide_instead_of_collapse
end

function reautils.get_arrange_view_hwnd(main_window_hwnd)
	main_window_hwnd = main_window_hwnd or reaper.GetMainHwnd()
	return reaper.JS_Window_FindEx(main_window_hwnd, nil, "REAPERTrackListWindow", "trackview")
end

function reautils.get_tcp_hwnd(main_window_hwnd)
	main_window_hwnd = main_window_hwnd or reaper.GetMainHwnd()
	return reaper.JS_Window_FindEx(main_window_hwnd, nil, "REAPERTCPDisplay", "")
end

reautils.tcp_element_types = {
	TRACK = 1,
	ENVELOPE = 2,
	SPACE = 3,
}
-- Returns:
-- 1. type (track/envelope/space)
-- 2. element (track/envelope) or track before space
-- 3. element (track/envelope) or track after space or nil if space at the bottom of TCP
-- 4. y of element
-- 5. height of element or nil if space at the bottom of TCP
function reautils.get_element_at_tcp_y(ordered_tracks, tcp_y)
	-- initialize variables
	ordered_tracks = ordered_tracks or reautils.get_all_tracks(true)
	local ordered_envelopes_by_track = luautils.imap(ordered_tracks, reautils.get_all_envelopes)

	-- check tracks starting from the bottom
	local previously_checked_track = nil
	local previously_checked_track_y = nil -- y of the previously checked track (the next track in the TCP)
	for i = #ordered_tracks, 1, -1 do
		-- check space between this and the previously checked track track (or empty space after last track)
		local track = ordered_tracks[i]
		local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
		local spacer_y = track_y + reaper.GetMediaTrackInfo_Value(track, "I_WNDH")
		if tcp_y >= spacer_y then
			if previously_checked_track_y and tcp_y < previously_checked_track_y then
				-- found spacer, return
				return
					reautils.tcp_element_types.SPACE,
					track,     -- track over space
					previously_checked_track, -- track under space
					spacer_y,
					previously_checked_track_y - spacer_y
			elseif previously_checked_track_y == nil then -- only happens when checking bottom track
				-- found empty space, return
				return
					reautils.tcp_element_types.SPACE,
					track, -- track over space
					nil, -- no track under space
					spacer_y,
					nil -- no height
			end
		end
		previously_checked_track = track -- set previously checked track to current track
		previously_checked_track_y = track_y -- set previously checked track y to current track y
		-- check envelopes of track
		for j = #ordered_envelopes_by_track[i], 1, -1 do
			local envelope = ordered_envelopes_by_track[i][j]
			local envelope_y = reaper.GetEnvelopeInfo_Value(envelope, "I_TCPY")
			if tcp_y >= envelope_y then
				-- found envelope, return
				return
					reautils.tcp_element_types.ENVELOPE,
					envelope,
					envelope,
					envelope_y,
					reaper.GetEnvelopeInfo_Value(envelope, "I_TCPH")
			end
		end
		-- check track
		if track_y <= tcp_y then
			-- found track, return
			return
				reautils.tcp_element_types.TRACK,
				track,
				track,
				track_y,
				reaper.GetMediaTrackInfo_Value(ordered_tracks[i], "I_TCPH")
		end
	end
end

return reautils

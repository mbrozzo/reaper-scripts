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
function reautils.get_all_track_compact_states()
	local tracks = reautils.get_all_tracks(false)
	local track_compact_states = {}
	local folder_depth = 1
	local folder_compact_state_stack = { reautils.track_compact_states.NORMAL }
	for i, track in ipairs(tracks) do
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
	local skips_small_state = tcpalign & 512 == 512 -- 512 = b001000000000
	local hides_instead_of_collapsing = tcpalign & 256 == 256 -- 256 = b000100000000
	return skips_small_state, hides_instead_of_collapsing
end

reautils.SPACE_BELOW_MASTER_TRACK = 5 -- pixels
reautils.tcp_ui_element_types = {
	SPACER = 1,
	TRACK = 2,
	ENVELOPE = 3,
}
local TOGGLE_MASTER_TRACK_VISIBLE_COMMAND_ID = 40110

function reautils.get_tcp_ui_element_vertical_positions()
	local ui_element_positions = {}
	local previous_element_type = nil
	local next_top_position = 0
	local function insert_element_object(track, envelope, element_type, is_master, height)
		if height < 1 then return false end -- Ignore elements with height < 1
		table.insert(ui_element_positions, {
			track = track,
			envelope = envelope,
			element_type = element_type,
			is_master = is_master,
			height = height,
			top_position = next_top_position
		})
		previous_element_type = element_type
		next_top_position = next_top_position + height
		return true
	end

	-- Master track
	if reaper.GetToggleCommandState(TOGGLE_MASTER_TRACK_VISIBLE_COMMAND_ID) == 1 then
		local track = reaper.GetMasterTrack(0)

		-- Track controls
		insert_element_object(track, nil, reautils.tcp_ui_element_types.TRACK,
			true, reaper.GetMediaTrackInfo_Value(track, "I_TCPH"))

		-- Envelopes
		if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 1 then
			local envelopes = reautils.get_all_envelopes(track)
			for _, envelope in ipairs(envelopes) do
				local _, is_visible, _, is_in_lane, height, _, _, _, _, _, _ = reaper.BR_EnvGetProperties(envelope)
				if is_visible and is_in_lane then
					insert_element_object(track, envelope, reautils.tcp_ui_element_types.ENVELOPE,
						true, height)
				end
			end
		end

		-- Default space below master track
		insert_element_object(track, nil,
			reautils.tcp_ui_element_types.SPACER, true, reautils.SPACE_BELOW_MASTER_TRACK)
	end

	-- Other tracks
	local tracks = reautils.get_all_tracks(false)
	local track_compact_states = reautils.get_all_track_compact_states()
	local spacer_normal_height = reaper.SNM_GetIntConfigVar("trackgapmax", 16)
	local supercollapsed, _, _, _ = reaper.NF_GetThemeDefaultTCPHeights()
	for i, track in ipairs(tracks) do
		local is_visible = reaper.IsTrackVisible(track, false)

		-- If previous element was not a spacer, check if track has a spacer above
		-- This way spacers are counted for hidden tracks too, but not when they are consecutive
		if
			previous_element_type ~= reautils.tcp_ui_element_types.SPACER and
			reaper.GetMediaTrackInfo_Value(track, "I_SPACER") == 1
		then
			local spacer_height = spacer_normal_height
			if -- If track is collapsed by folder and visible
				track_compact_states[i] == reautils.track_compact_states.COLLAPSED_OR_HIDDEN
				and is_visible
			then
				spacer_height = supercollapsed
			end
			insert_element_object(track, nil,
				reautils.tcp_ui_element_types.SPACER, false, spacer_height)
		end

		-- Ignore rest of track if is not visible
		if not is_visible then
			goto continue
		end

		-- Track controls
		insert_element_object(track, nil, reautils.tcp_ui_element_types.TRACK,
			false, reaper.GetMediaTrackInfo_Value(track, "I_TCPH"))

		-- Envelopes
		local envelopes = reautils.get_all_envelopes(track)
		for _, envelope in ipairs(envelopes) do
			insert_element_object(track, envelope, reautils.tcp_ui_element_types.ENVELOPE,
				false, reaper.GetEnvelopeInfo_Value(envelope, "I_TCPH"))
		end
		::continue::
	end
	return ui_element_positions
end

function reautils.get_arrange_view_hwnd(main_window_hwnd)
	main_window_hwnd = main_window_hwnd or reaper.GetMainHwnd()
	return reaper.JS_Window_FindEx(main_window_hwnd, nil, "REAPERTrackListWindow", "trackview")
end

function reautils.get_tcp_hwnd(main_window_hwnd)
	main_window_hwnd = main_window_hwnd or reaper.GetMainHwnd()
	return reaper.JS_Window_FindEx(main_window_hwnd, nil, "REAPERTCPDisplay", "")
end

return reautils

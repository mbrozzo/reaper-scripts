local reautils = {}

-- Set ToolBar Button State
function reautils.set_button_state(state)
	local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
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

function reautils.get_envelope_height(envelope)
	local BR_envelope = reaper.BR_EnvAlloc(envelope, false)
	local _, _, _, _, height, _, _, _, _, _, _ = reaper.BR_EnvGetProperties(BR_envelope)
	return height
end

function reautils.set_envelope_height(envelope, height)
	local BR_envelope = reaper.BR_EnvAlloc(envelope, false)
	local active, visible, armed, inLane, _, defaultShape, _, _, _, _, faderScaling = reaper.BR_EnvGetProperties(BR_envelope)
	reaper.BR_EnvSetProperties(BR_envelope, active, visible, armed, inLane, height, defaultShape, faderScaling)
	reaper.BR_EnvFree(BR_envelope, true)
end

return reautils

local reautils = {}

-- Set ToolBar Button State
function reautils.set_button_state(state)
	local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
	reaper.SetToggleCommandState(sec, cmd, state or 0)
	reaper.RefreshToolbar2(sec, cmd)
end

-- TODO: ricontrolla
-- function reautils.SetEnvHeight(envelope, laneHeight)
-- 	local BR_env = reaper.BR_EnvAlloc(envelope, false)
-- 	local active, visible, armed, inLane, _, defaultShape, _, _, _, _, faderScaling = reaper.BR_EnvGetProperties(BR_env)
-- 	reaper.BR_EnvSetProperties(BR_env, active, visible, armed, inLane, laneHeight, defaultShape, faderScaling)
-- 	reaper.BR_EnvFree(BR_env, true)
-- end

return reautils

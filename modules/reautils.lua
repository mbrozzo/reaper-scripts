local reautils = {}

-- TODO: ricontrolla
-- function reautils.SetEnvHeight(envelope, laneHeight)
-- 	local BR_env = reaper.BR_EnvAlloc(envelope, false)
-- 	local active, visible, armed, inLane, _, defaultShape, _, _, _, _, faderScaling = reaper.BR_EnvGetProperties(BR_env)
-- 	reaper.BR_EnvSetProperties(BR_env, active, visible, armed, inLane, laneHeight, defaultShape, faderScaling)
-- 	reaper.BR_EnvFree(BR_env, true)
-- end

return reautils

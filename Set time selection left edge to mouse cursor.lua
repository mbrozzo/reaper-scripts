function main()
	t_start, t_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
	pos = reaper.BR_PositionAtMouseCursor(true)
	if pos < 0 then return end
	t_start = reaper.BR_GetClosestGridDivision(pos)
	reaper.GetSet_LoopTimeRange(true, false, t_start, t_end, false)
end

reaper.defer(main)

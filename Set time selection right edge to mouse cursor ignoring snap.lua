function main()
	t_start, t_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
	t_end = reaper.BR_PositionAtMouseCursor(true)
	if t_end < 0  then return end
	reaper.GetSet_LoopTimeRange(true, false, t_start, t_end, false)
end

reaper.defer(main)

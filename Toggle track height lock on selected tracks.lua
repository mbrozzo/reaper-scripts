function main()
	local tracks = {}
	local must_lock = false
	for i = 0, reaper.CountSelectedTracks2(0, true) - 1 do
		local track = reaper.GetSelectedTrack2(0, i, true)
		table.insert(tracks, track)
		local lock_state = reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
		if lock_state == 0 then
			must_lock = true
		end
	end

	for _, track in ipairs(tracks) do
		if must_lock then
			reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", reaper.GetMediaTrackInfo_Value(track, "I_TCPH"))
			reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", 1)
		else
			reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", 0)
		end
	end
end

reaper.defer(main) -- Prevent undo point creation

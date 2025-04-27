local script_path = debug.getinfo (1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. 'modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

local s = ""
-- s = s .. "Default Track Height Steps:\n"
-- prev = 0
-- for k,v in pairs(vzoom.calculate_current_default_track_height_steps()) do
--	 s = s .. v .. " | " .. v - prev .. "\n"
--	 prev = v
-- end
-- s = s .. "Min: " .. vzoom.get_current_min_track_height() .. "\n"
-- s = s .. "Max: " .. vzoom.get_current_max_track_height() .. "\n"
-- local supercollapsed, collapsed, small, recarm = reaper.NF_GetThemeDefaultTCPHeights()
-- s = s .. "supercollapsed: " .. supercollapsed .. "\n"
-- s = s .. "collapsed: " .. collapsed .. "\n"
-- s = s .. "small: " .. small .. "\n"
-- s = s .. "recarm: " .. recarm .. "\n"

-- reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, 1), "I_HEIGHTOVERRIDE", supercollapsed)
-- reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, 2), "I_HEIGHTOVERRIDE", supercollapsed+1)
-- reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, 3), "I_HEIGHTOVERRIDE", 10)
-- reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, 4), "I_HEIGHTOVERRIDE", collapsed-1)
-- reaper.TrackList_AdjustWindows(false)


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
		local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
		if not track_name:find("^🔒 ") then
			reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "🔒 " .. track_name, true)
		end
	else
		reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", 0)
		local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
		if track_name:find("^🔒 ") then
			reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name:gsub("^🔒 ", ""), true)
		end
	end
end



-- reaper.ShowConsoleMsg(s)
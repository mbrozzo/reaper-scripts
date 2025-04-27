undo_block_begun = false

-- Function to generate a unique key from two numbers
local function generate_string_key(x, y)
	return x .. ";" .. y -- Concatenate the numbers as a string
end

-- Fade-in item
local function fadein(item_data, fade_len)
	-- Gather item data to avoid looping
	local take = reaper.GetActiveTake(item_data.item)
	if take == nil then return end
	local item_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
	local item_playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
	-- Adjust start offset to project time by taking playrate into account
	local item_min_start_offset = item_start_offset / item_playrate
	-- Calculate minimum start time to avoid looping, limited by project start
	local item_min_start = math.max(0, item_data.start - item_min_start_offset)
	-- Recalculate item minimum start time offset from current start time
	item_min_start_offset = item_data.start - item_min_start

	if item_min_start_offset <= 0 then return end
	-- else
	-- Shrink fade if item cannot extend enough
	fade_len = math.min(fade_len, item_min_start_offset)

	-- Begin undo block if not already begun
	if not undo_block_begun then
		reaper.Undo_BeginBlock()
		undo_block_begun = true
	end

	-- Extend item
	reaper.SetMediaItemInfo_Value(item_data.item, "D_POSITION", item_data.start - fade_len)
	reaper.SetMediaItemInfo_Value(item_data.item, "D_LENGTH", item_data.len + fade_len)
	reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", item_start_offset - fade_len * item_playrate)
	-- Crossfade items
	reaper.SetMediaItemInfo_Value(item_data.item, "D_FADEINLEN", fade_len)
end

-- Fade-out item
local function fadeout(item_data, fade_len)
	-- Shrink fade to avoid overlapping fade-in
	fade_len = math.min(fade_len, item_data.endd - (item_data.start + item_data.fadein))

	-- Begin undo block if not already begun
	if not undo_block_begun then
		reaper.Undo_BeginBlock()
		undo_block_begun = true
	end

	-- Fade-out item
	reaper.SetMediaItemInfo_Value(item_data.item, "D_FADEOUTLEN", fade_len)
end

-- Crossfade item1 into item2
-- Warning: it is assumed that item1 and item2 are adjacent and item1 is before item2
local function crossfade(item1_data, item2_data, xfade_len)
	fadein(item2_data, xfade_len)
	fadeout(item1_data, xfade_len)
end

function main()
	-- Get default crossfade time
	local xfade_len = reaper.SNM_GetDoubleConfigVar("defsplitxfadelen", -1)
	local fade_len = reaper.SNM_GetDoubleConfigVar("deffadelen", -1)

	-- Get count of items
	local items_count = reaper.CountMediaItems(0)
	if items_count <= 0 then return end -- No items: do nothing

	-- Loop through items, gather timing information, crossfade if applicable,
	-- and group by track and lane
	local fadeinable_items_by_tracklane = {}
	local fadeoutable_items_by_tracklane = {}
	for i = 0, items_count - 1 do
		-- Get i-th item
		local item = reaper.GetMediaItem(0, i)
		if item == nil then goto continue end

		-- If item is not selected, it is ignored
		if not reaper.IsMediaItemSelected(item) then goto continue end

		-- Initialize item info table
		local item_data = {}
		item_data.item = item

		-- Get item timing information
		item_data.start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		item_data.len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		item_data.endd = item_data.start + item_data.len

		-- Get fade lengths
		item_data.fadein = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
		item_data.fadeout = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
		if item_data.fadein > 0 and item_data.fadeout > 0 then goto continue end -- Fades already set, item is ignored

		-- Keep track if available to fade in or out (used later)
		item_fadeinable = item_data.fadein <= 0
		item_fadeoutable = item_data.fadeout <= 0

		-- Get item track and lane
		local item_track = reaper.GetMediaItemInfo_Value(item, "P_TRACK")
		if item_track == nil then goto continue end
		local item_track_number = reaper.GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER")
		local item_lane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")

		local tracklane_key = generate_string_key(item_track_number, item_lane)

		-- Handle fadeinable items
		local fadeinable_items_in_tracklane = fadeinable_items_by_tracklane[tracklane_key]
		-- If tiem is fadeoutable and there are fadeinable items
		if item_fadeoutable and fadeinable_items_in_tracklane ~= nil then
			-- Check if there are any adjacent selected items on the same track and lane
			for j = #fadeinable_items_in_tracklane, 1, -1 do
				item_j_data = fadeinable_items_in_tracklane[j]
				-- If item_j is right after item
				if item_j_data.start == item_data.endd then
					-- Cross-fade the items
					crossfade(item_data, item_j_data, xfade_len)
					-- Remove item_j from fadeinable items
					table.remove(fadeinable_items_in_tracklane, j)
					-- Mark item as not fadeoutable
					item_fadeoutable = false
				end
			end
		end

		-- Handle fadeoutable items
		local fadeoutable_items_in_tracklane = fadeoutable_items_by_tracklane[tracklane_key]
		-- If tiem is fadeinable and there are fadeoutable items
		if item_fadeinable and fadeoutable_items_in_tracklane ~= nil then
			-- Check if there are any adjacent selected items on the same track and lane
			for j = #fadeoutable_items_in_tracklane, 1, -1 do
				item_j_data = fadeoutable_items_in_tracklane[j]
				-- If item_j is right before item
				if item_j_data.endd == item_data.start then
					-- Cross-fade the items
					crossfade(item_j_data, item_data, xfade_len)
					-- Remove item_j from fadeoutable items
					table.remove(fadeoutable_items_in_tracklane, j)
					-- Mark item as not fadeinable
					item_fadeinable = false
				end
			end
		end

		-- Add item in fadeable lists if appropriate

		if item_fadeinable then
			-- Add item data to fadeinable items by track and lane
			if fadeinable_items_in_tracklane == nil then
				-- First item in track and lane
				fadeinable_items_by_tracklane[tracklane_key] = { item_data }
			else
				table.insert(fadeinable_items_by_tracklane[tracklane_key], item_data)
			end
		end

		if item_fadeoutable then
			-- Add item data to fadeoutable items by track and lane
			if fadeoutable_items_in_tracklane == nil then
				-- First item in track and lane
				fadeoutable_items_by_tracklane[tracklane_key] = { item_data }
			else
				table.insert(fadeoutable_items_by_tracklane[tracklane_key], item_data)
			end
		end

		::continue::
	end

	-- Fade remaining items
	for tracklane, fadeinable_items_in_tracklane in pairs(fadeinable_items_by_tracklane) do
		for i, item_data in pairs(fadeinable_items_in_tracklane) do
			fadein(item_data, fade_len)
		end
	end
	for tracklane, fadeoutable_items_in_tracklane in pairs(fadeoutable_items_by_tracklane) do
		for i, item_data in pairs(fadeoutable_items_in_tracklane) do
			fadeout(item_data, fade_len)
		end
	end
end

reaper.PreventUIRefresh(1) -- Prevent UI refreshing, uncomment it only if the script works
success, err = pcall(main) -- Run the main function with pcall so that errors do not terminate script execution
if not success then
	reaper.ShowMessageBox(tostring(err), "Script error", 0)
end
if undo_block_begun then
	reaper.Undo_EndBlock("Smart crossfade adjacent selected items", -1)
end
reaper.PreventUIRefresh(-1) -- Restore UI refreshing, uncomment it only if the script works
reaper.UpdateArrange()

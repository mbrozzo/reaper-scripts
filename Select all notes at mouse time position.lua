function main()
	-- Check if mouse is on MIDI editor
	local window, segment, details = reaper.BR_GetMouseCursorContext()
	if window ~= "midi_editor" then return end

	-- Get mouse time position
	local mouse_time = reaper.BR_GetMouseCursorContext_Position()

	-- Get the active MIDI editor
	local editor = reaper.MIDIEditor_GetActive()
	if editor == nil then return end

	-- Get the take from the MIDI editor
	local take = reaper.MIDIEditor_GetTake(editor)
	if take == nil then return end

	-- Get the ppq position of the mouse
	local mouse_ppqpos = reaper.MIDI_GetPPQPosFromProjTime(take, mouse_time)

	-- Initialize variables to loop through MIDI events
	local found, start_ppqpos, end_ppqpos = true, nil, nil
	local i = 0

	-- Loop through all MIDI notes
	while found do
		found, _, _, start_ppqpos, end_ppqpos, _, _, _ = reaper.MIDI_GetNote(take, i)
		if not found then break end -- No more notes

		-- Check if note is under the mouse position (within note's start and end time)
		if start_ppqpos <= mouse_ppqpos and mouse_ppqpos <= end_ppqpos then
			-- Select the note
			reaper.MIDI_SetNote(take, i, true, nil, nil, nil, nil, nil, nil, false)
		else
			-- Unselect the note
			reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
		end
		i = i + 1
	end

	-- Update the MIDI editor
	reaper.MIDI_Sort(take)
end

main()

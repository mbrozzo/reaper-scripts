function main()
	-- Get the active MIDI editor
	local editor = reaper.MIDIEditor_GetActive()
	if editor == nil then return end

	-- Get the take from the MIDI editor
	local take = reaper.MIDIEditor_GetTake(editor)
	if take == nil then return end

	-- Initialize variables to loop through MIDI events
	local found = true
	local i = 0

	-- Loop through all MIDI notes
	while found do
		found, _, _, _, _, _, _, _ = reaper.MIDI_GetNote(take, i)
		if not found then break end -- No more notes

		-- Unselect the note
		reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)

		i = i + 1
	end

	-- Update the MIDI editor
	reaper.MIDI_Sort(take)
end

main()

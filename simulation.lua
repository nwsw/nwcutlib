-- This file can be used to load up a simulated `nwcut` environment.
-- This file has no role in the true `nwcut` environment, but you can
-- use it to better understand the true environment.

local fakeInput = [[
!NoteWorthyComposerClip(2.75,Single)
|Note|Dur:4th|Pos:0
!NoteWorthyComposerClip-End
]]

dofile('synthesize.lua')(fakeInput)

if arg[1] then
	nwcut.run(arg[1])
else
	nwcut.warn('Warning: user tool script should be passed as first argument')
end

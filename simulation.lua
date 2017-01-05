-- This file can be used to load up a simulated `nwcut` environment.
-- This file has no role in the true `nwcut` environment, but you can
-- use it to better understand the true environment.

local fakeInput = [[
!NoteWorthyComposerClip(2.75,Single)
|Note|Dur:4th|Pos:0
!NoteWorthyComposerClip-End
]]

-- nwc.exe provides a `gzreadline` global function for loading stdin; we fake it here
gzreadline = fakeInput:gmatch("([^\r\n]*)")

-- utf8string = require('lua-utf8')
utf8string = string

nwcut = {}

nwcut.status = 0

function nwcut.nwcversion()
	return "2.75a"
end
	
function nwcut.msgbox(msg, msgtitle)
	return 0
end

function nwcut.askbox(msg, msgtitle, flags)
	return 1
end

function nwcut.prompt(msg, datatype, default)
	return default
end

nwcut.clock = os.clock

nwc = {VERSION='2.75',VERSIONDATE='20161231',VERSIONKEY='2.75a.beta.009',VERSIONTEXT='Version 2.75a Beta 9'}

nwc.txt = {
--[[$EMBEDFILE:(nwc.txt)]]--
	AttachLyricSyllable	= {'Default','Always','Never'},
	BarLineType	= {'Single','Double','BrokenSingle','BrokenDouble','SectionOpen','SectionClose','LocalRepeatOpen','LocalRepeatClose','MasterRepeatOpen','MasterRepeatClose','Transparent'},
	BoundaryTypes	= {'Reset','NewSize','Collapse','EndCollapse','Gap','NewSystem'},
	ClefType	= {'Treble','Bass','Alto','Tenor','Percussion'},
	DrawFillStyle	= {'fill','stroke','strokeandfill'},
	DrawPenStyle	= {'solid','dot','dash'},
	DrawTextAlign	= {'left','center','right'},
	DrawTextVAlign	= {'top','middle','baseline','bottom'},
	DynamicLevels	= {'ppp','pp','p','mp','mf','f','ff','fff'},
	DynamicVariance	= {'Crescendo','Decrescendo','Diminuendo','Rinforzando','Sforzando'},
	ExpressionJustify	= {'Left','Center','Right'},
	ExpressionPlacement	= {'BestFit','BestFitForward','AsStaffSignature','AtNextNote'},
	FlowDirTypes	= {'Coda','Segno','Fine','ToCoda','DaCapo','DCalCoda','DCalFine','DalSegno','DSalCoda','DSalFine'},
	ItemColor	= {'Default','Highlight 1','Highlight 2','Highlight 3','Highlight 4','Highlight 5','Highlight 6','Highlight 7'},
	ItemVisibility	= {'Default','Always','TopStaff','SingleStaff','MultiStaff','Never'},
	Lyric2NoteAlignment	= {'Start of Accidental/Note','Standard Rules'},
	LyricAlignment	= {'Bottom','Top'},
	MPCControllers	= {'tempo','vol','pan','bc','pitch','mod','foot','portamento','datamsb','bal','exp','fx1','fx2','reverb','tremolo','chorus','detune','phaser'},
	MPCStyle	= {'Absolute','Linear Sweep'},
	MarkerTargets	= {'Articulation','Slur','Triplet'},
	MeasureNumStyles	= {'None','Plain','Circled','Boxed'},
	NoteConnectState	= {'None','First','Middle','End'},
	NoteDurBase	= {'Whole','Half','4th','8th','16th','32nd','64th'},
	NoteDuration	= {'Whole','Half','Quarter','Eighth','Sixteenth','Thirtysecond','Sixtyfourth'},
	NoteScale	= {'A','B','C','D','E','F','G'},
	ObjLabels	= {'Clef','Key','Bar','Ending','Instrument','TimeSig','Tempo','Dynamic','Note','Rest','Chord','SustainPedal','Flow','MPC','TempoVariance','DynamicVariance','PerformanceStyle','Text','RestChord','User','Spacer','RestMultiBar','Boundary','Marker'},
	OctaveShift	= {'None','Octave Up','Octave Down'},
	PageMarginFields	= {'Left','Top','Right','Bottom','Mirror'},
	PageSetupFields	= {'TitlePage','JustifyVertically','PrintSystemSepMark','ExtendLastSystem','DurationPadding','PageNumbers','StaffLabels','BarNumbers','StartingBar','AllowLayering'},
	PerformanceStyle	= {'Ad Libitum','Animato','Cantabile','Con brio','Dolce','Espressivo','Grazioso','Legato','Maestoso','Marcato','Meno mosso','Poco a poco','Più mosso','Semplice','Simile','Solo','Sostenuto','Sotto Voce','Staccato','Subito','Tenuto','Tutti','Volta Subito'},
	PlayMidiCmds	= {'noteOff','noteOn','keyAftertouch','controller','patch','channelAftertouch','pitchBend'},
	SongInfoFields	= {'Title','Author','Lyricist','Copyright1','Copyright2','Comments'},
	SpanTypes	= {'notes','syllables','bars','ticks','items'},
	SpecialSignatures	= {'Standard','Common','AllaBreve'},
	StaffEndBarLineType	= {'Section Close','Master Repeat Close','Single','Double','Open (hidden)'},
	StaffLabelStyles	= {'None','First System','Top Systems','All Systems'},
	StaffProperties	= {'Name','Label','LabelAbbr','Group','EndingBar','BoundaryTop','BoundaryBottom','Lines','BracketWithNext','BraceWithNext','ConnectBarsWithNext','LayerWithNext','MultiPartDotPlacement','Color','Muted','Volume','StereoPan','Device','Channel'},
	SustainPedalStatus	= {'Down','Released'},
	TempoBase	= {'Eighth','Eighth Dotted','Quarter','Quarter Dotted','Half','Half Dotted'},
	TempoVariance	= {'Breath Mark','Caesura','Fermata','Accelerando','Allargando','Rallentando','Ritardando','Ritenuto','Rubato','Stringendo'},
	TextExpressionFonts	= {'StaffSymbols','StaffCueSymbols','StaffItalic','StaffBold','StaffLyric','PageTitleText','PageText','PageSmallText','User1','User2','User3','User4','User5','User6'},
	TieDir	= {'Default','Upward','Downward'},
	UserObjClassTypes	= {'Standard','StaffSig','Span'},
	UserPropValueTypes	= {'text','enum','bool','int','float'},
--[[/$EMBEDFILE:(nwc.txt)]]--
}

dofile('nwcut.lua')

-- protect the `nwc` tables...this just simulated the behavior in the true env
for k,v in pairs(nwc.txt) do nwc.txt[k] = nwcut.ProtectTable(v) end
nwc.txt = nwcut.ProtectTable(nwc.txt)
nwc = nwcut.ProtectTable(nwc)

if arg[1] then
	nwcut.run(arg[1])
else
	nwcut.warn('Warning: user tool script should be passed as first argument')
end

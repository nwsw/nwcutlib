-- This file can be used to load up a simulated `nwcut` environment.
-- This file has no role in the true `nwcut` environment, but you can
-- use it to better understand the true environment.

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

nwc = {VERSION='2.75',VERSIONDATE='20161018',VERSIONKEY='2.75a.beta.003',VERSIONTEXT='Version 2.75a Beta 3'}

nwc.txt = {
	OctaveShift	= {'None','Octave Up','Octave Down'},
	AttachLyricSyllable	= {'Default','Always','Never'},
	SongInfoFields	= {'Title','Author','Lyricist','Copyright1','Copyright2','Comments'},
	BarLineType	= {'Single','Double','BrokenSingle','BrokenDouble','SectionOpen','SectionClose','LocalRepeatOpen','LocalRepeatClose','MasterRepeatOpen','MasterRepeatClose','Transparent'},
	MPCStyle	= {'Absolute','Linear Sweep'},
	StaffProperties	= {'Name','Label','LabelAbbr','Group','EndingBar','BoundaryTop','BoundaryBottom','Lines','BracketWithNext','BraceWithNext','ConnectBarsWithNext','LayerWithNext','MultiPartDotPlacement','Color','Muted','Volume','StereoPan','Device','Channel'},
	NoteConnectState	= {'None','First','Middle','End'},
	TextExpressionFonts	= {'StaffSymbols','StaffCueSymbols','StaffItalic','StaffBold','StaffLyric','PageTitleText','PageText','PageSmallText','User1','User2','User3','User4','User5','User6'},
	NoteScale	= {'A','B','C','D','E','F','G'},
	UserObjClassTypes	= {'Standard','StaffSig'},
	ObjLabels	= {'Clef','Key','Bar','Ending','Instrument','TimeSig','Tempo','Dynamic','Note','Rest','Chord','SustainPedal','Flow','MPC','TempoVariance','DynamicVariance','PerformanceStyle','Text','RestChord','User','Spacer','RestMultiBar','Boundary','Marker'},
	PageMarginFields	= {'Left','Top','Right','Bottom','Mirror'},
	StaffEndBarLineType	= {'Section Close','Master Repeat Close','Single','Double','Open (hidden)'},
	StaffLabelStyles	= {'None','First System','Top Systems','All Systems'},
	MPCControllers	= {'tempo','vol','pan','bc','pitch','mod','foot','portamento','datamsb','bal','exp','fx1','fx2','reverb','tremolo','chorus','detune','phaser'},
	SustainPedalStatus	= {'Down','Released'},
	TempoBase	= {'Eighth','Eighth Dotted','Quarter','Quarter Dotted','Half','Half Dotted'},
	BoundaryTypes	= {'Reset','NewSize','Collapse','EndCollapse','Gap','NewSystem'},
	Lyric2NoteAlignment	= {'Start of Accidental/Note','Standard Rules'},
	PageSetupFields	= {'TitlePage','JustifyVertically','PrintSystemSepMark','ExtendLastSystem','DurationPadding','PageNumbers','StaffLabels','BarNumbers','StartingBar','AllowLayering'},
	ItemVisibility	= {'Default','Always','TopStaff','SingleStaff','MultiStaff','Never'},
	ExpressionPlacement	= {'BestFit','BestFitForward','AsStaffSignature','AtNextNote'},
	DynamicLevels	= {'ppp','pp','p','mp','mf','f','ff','fff'},
	DynamicVariance	= {'Crescendo','Decrescendo','Diminuendo','Rinforzando','Sforzando'},
	TieDir	= {'Default','Upward','Downward'},
	TempoVariance	= {'Breath Mark','Caesura','Fermata','Accelerando','Allargando','Rallentando','Ritardando','Ritenuto','Rubato','Stringendo'},
	SpecialSignatures	= {'Standard','Common','AllaBreve'},
	PerformanceStyle	= {'Ad Libitum','Animato','Cantabile','Con brio','Dolce','Espressivo','Grazioso','Legato','Maestoso','Marcato','Meno mosso','Poco a poco','Più mosso','Semplice','Simile','Solo','Sostenuto','Sotto Voce','Staccato','Subito','Tenuto','Tutti','Volta Subito'},
	NoteDuration	= {'Whole','Half','Quarter','Eighth','Sixteenth','Thirtysecond','Sixtyfourth'},
	NoteDurBase	= {'Whole','Half','4th','8th','16th','32nd','64th'},
	MeasureNumStyles	= {'None','Plain','Circled','Boxed'},
	ClefType	= {'Treble','Bass','Alto','Tenor','Percussion'},
	FlowDirTypes	= {'Coda','Segno','Fine','ToCoda','DaCapo','DCalCoda','DCalFine','DalSegno','DSalCoda','DSalFine'},
	LyricAlignment	= {'Bottom','Top'},
	ExpressionJustify	= {'Left','Center','Right'},
	ItemColor	= {'Default','Highlight 1','Highlight 2','Highlight 3','Highlight 4','Highlight 5','Highlight 6','Highlight 7'},
	MarkerTargets	= {'Articulation','Slur','Triplet'},
}

gzreadline = io.lines()

local function locktables()
	-- protect the `nwc` tables...this just simulated the behavior in the true env
	for k,v in pairs(nwc.txt) do nwc.txt[k] = nwctxt.ProtectTable(v) end
	nwc.txt = nwctxt.ProtectTable(nwc.txt)
	nwc = nwctxt.ProtectTable(txt)
end

dofile('nwctxt.lua')
locktables()
dofile('nwcut.lua')
dofile('shim.lua')
dofile('sandbox.lua')

-- Establish the NoteWorthy Composer user tool support classes

nwcut.ID='nwcut'

local StringBuilder = {ID='StringBuilder'}
local nwcOptList = {ID='nwcOptList'}
local nwcOptText = {ID='nwcOptText'}
local nwcUserObjOpt = {ID='nwcUserObjOpt'}
local nwcOptGroup = {ID='nwcOptGroup'}
local nwcNotePos = {ID='nwcNotePos'}
local nwcNotePosList = {ID='nwcNotePosList'}
local nwcItem = {ID='nwcItem',DefaultLevel=-1}
local nwcStaff = {ID='nwcStaff'}
local nwcFile = {ID='nwcFile'}
local nwcPlayContext = {ID='nwcPlayContext'}

-- some local data cannot be initialized until all classes are fully defined
local initProcs = setmetatable({},{__index=table})

initProcs:insert(function() nwcut = setmetatable({},{__index=nwcut}) end)

local function ProtectTable(tbl) return setmetatable({},{
	__index = tbl,
	__newindex = function (t, n, v) error("constant change "..tostring(n).." to "..tostring (v), 2)  end,
	__pairs = function() return function(_,k) return next(tbl,k) end end,
	})
end

local function typeOf(o) local t=type(o) return (t=='table') and o.ID or t end
local function hasValue(v) return (v and (v ~= "")) or false end
local function parmswap(swap,v1,v2) if swap then return v2,v1 else return v1,v2 end end
local function copyKeySig(dest,src)	for k,v in pairs(src) do dest[k] = v end end
local function ripairs(t) local function r2(t,i) i=i-1;if t[i]~=nil then return i,t[i] end end return r2, t, #t+1 end
local function mergeItem(o1,o2)	for k,v in pairs(o2.Opts) do o1.Opts[k] = v end end
local function tableContains(t,o) for k,v in pairs(t) do if v==o then return k end end end
local function iterlistvals(t) local i=0;return function() i=i+1;if t[i] then return t[i] end;end;end

nwcut.ProtectTable = ProtectTable
nwcut.typeOf = typeOf
nwcut.write=io.write
nwcut.stderr=io.stderr
nwcut.warn=function(...) nwcut.stderr:write(...) end

nwcut.const = ProtectTable({
	-- Possible processing modes
	mode_ClipText = 1,
	mode_FileText = 2,

	-- User tool return codes assigned into nwcut.status
	rc_Success	= 0,	-- Standard output is processed..contents in standard error is presented as a warning
	rc_Error	= 1,	-- Standard error is shown to the user
	rc_Report	= 99,	-- Standard output is shown to the user

	-- every line os user tool input can be classified as one of these types
	ltyp_Error			= 0,
	ltyp_FormatHeader	= 1,
	ltyp_Comment		= 2,
	ltyp_Object			= 3,

	-- if a line is ltyp_Object, then it can be further classified by one of these types
	objtyp_Error			= 0,
	objtyp_FileProperty		= 1,
	objtyp_StaffProperty	= 2,
	objtyp_StaffLyric		= 3,
	objtyp_StaffNotation	= 4,

	-- the fields in a nwcItem can be classified as belonging to one of these groups
	opt_Raw			= 1,
	opt_Num			= 2,
	opt_Text		= 3,
	opt_List		= 4,
	opt_Associative	= 5,
	opt_NotePos		= 6,
	opt_UserObjOpt	= 7,
	})

-- quick lookup dictionaries
local dict = {
	NoteObjTypes = {Note=1,Chord=1,Rest=1,RestChord=1},
	NoteNames = {'C','D','E','F','G','A','B'},
	Accidentals = {'v','b','n','#','x'},
	AccidentalOffsets = {v=-2,b=-1,n=0,['#']=1,x=2},
	BaseNoteSemitones = {C=0,D=2,E=4,F=5,G=7,A=9,B=11},
	ClefCenterTones = {Treble=34,Bass=22,Alto=28,Tenor=26,Drum=22},
	}

local cd=nwcut.const

local ldata={
	FileName=false,
	SavePending=false,
	StartingLine=nil,
	EndingLine=false,
	HdrVersion=nil,
	Mode=0,
	ReturnMode=cd.mode_ClipText,
	ItemsRetrieved=0
}

function nwcut.GetClefStdCenterTone(clef) return dict.ClefCenterTones[clef] or dict.ClefCenterTones['Treble'] end
function nwcut.GetOffsetAccidental(offset) return dict.Accidentals[tonumber(offset)+3] or "" end
function nwcut.GetAccidentalOffset(acc) return dict.AccidentalOffsets[acc] or 0 end

function nwcut.AllNoteNames() return iterlistvals(dict.NoteNames) end
function nwcut.AllAccidentals() return iterlistvals(dict.Accidentals) end

function nwcut.getprop(s)
	if s == "ItemLevel" then return nwcItem.DefaultLevel end
	return ldata[s]
end

function nwcut.setlevel(lvl) nwcItem.SetDefaultLevel(lvl) end

function nwcut.writeline(...)
	local a = {...}
	local w = nwcut.write
	for _,v in ipairs(a) do
		local t = type(v)
		if (t == "string") or (t == "number") then
			w(v)
		elseif (t == "table") and v.WriteUsing then
			v:WriteUsing(w)
		else
			w(tostring(v))
		end
	end

	w("\n")
end

function nwcut.preload()
	-- Load the stdin stream header data, which makes it available
	-- to the user tool immediately
	while ldata.Mode < 1 do
		local ln = gzreadline()
		if not ln then error("nwctxt required header not found") end

		local lt = nwcut.ClassifyLine(ln)

		if lt == cd.ltyp_FormatHeader then
			local i1,i2,m,v = ln:find("^!(%w+)%(([^%,%)]+)")

			ldata.StartingLine = ln
			ldata.HdrVersion = v or "0"

			if m == "NoteWorthyComposer" then
				-- File mode
				ldata.EndingLine = "!NoteWorthyComposer-End"
				ldata.Mode = 2
			elseif m == "NoteWorthyComposerClip" then
				-- Clip mode
				ldata.EndingLine = "!NoteWorthyComposerClip-End"
				ldata.Mode = 1
			end
		elseif lt == cd.ltyp_Comment then
			local i1,i2,opt,v = ln:find("^%#%/(%w+)%:%s*(.+)$")
			if opt == "File" then
				ldata.FileName = v
			elseif opt == "SavePending" then
				ldata.SavePending = (v == "Y")
			elseif opt == "ReturnFormat" then
				ldata.ReturnMode = (v == "FileText") and cd.mode_FileText or cd.mode_ClipText
			end
		end
	end
end

function nwcut.getitem()
	while true do
		local ln = gzreadline()
		if not ln then return nil end

		local lt = nwcut.ClassifyLine(ln)
		if lt == cd.ltyp_Object then
			ldata.ItemsRetrieved = ldata.ItemsRetrieved+1
			return nwcItem.new(ln)
		elseif lt == cd.ltyp_FormatHeader then
			while gzreadline() do end
			return nil
		end
	end
end

function nwcut.items() return nwcut.getitem end

function nwcut.loadFile(items)
	local score = nwcFile.new()
	score:load(items)
	return score
end

local ltyp_D = {[0x21]=1,[0x23]=2,[0x7c]=3}
--
function nwcut.ClassifyLine(ln)
	local fc = string.byte(ln,1)
	if fc == nil
		then return cd.ltyp_Comment
	else
		return ltyp_D[fc] or cd.ltyp_Error
	end
end

function nwcut.objtyp(s)
	local _,_,objt = string.find(s,"^|(%w+)")
	return objt
end

local ObjTyp_D = {
	Note=1,Chord=1,Bar=1,Rest=1,Text=1,Dynamic=1,Clef=1,Key=1,TimeSig=1,
	Locale=3,Editor=3,SongInfo=3,PgSetup=3,Font=3,PgMargins=3,
	AddStaff=2,StaffProperties=2,StaffInstrument=2
	}

function nwcut.ClassifyObjType(ObjType)
	if not ObjType then return cd.objtyp_Error end

	local otc = ObjTyp_D[ObjType]
	if otc == 1 then
		return cd.objtyp_StaffNotation
	elseif otc == 2 then
		return cd.objtyp_StaffProperty
	elseif otc == 3 then
		return cd.objtyp_FileProperty
	elseif ObjType:find("^Lyric") then
		return cd.objtyp_StaffLyric
	end

	return cd.objtyp_StaffNotation
end

local OptTag_D = {
	Visibility=false,Color=false,
	Opts=1,Dur=1,Dur2=1,Endings=1,
	Pos=2,Pos2=2,
	Text=3,Name=3,Label=3,Group=3,Typeface=3,
	DynVel=4,WithNextStaff=4,WhenHidden=4,
	Signature=5,
	Bar=6,
	BracketHeight=7,BracketOffsetNP=7,Color=7,Lower=7,NumBars=7,Pause=7,Repeat=7,StemLength=7,SweepRes=7,Tempo=7,Trans=7,Upper=7,VertOffset=7,Width=7,XAccSpace=7,XNoteSpace=7,
}

local UserObjNativeOpts = {Class=1,Pos=1,Color=1,Visibility=1}

function nwcut.ClassifyOptTag(ObjType,Tag)
	-- The OptTag_D dictionary is optimized for speed
	local c = OptTag_D[Tag]

	if (ObjType == "User") and (not UserObjNativeOpts[Tag]) then return cd.opt_UserObjOpt end

	if not c then
		-- Tag is Visibility,Color or unlisted
		return cd.opt_Raw
	elseif c == 1 then
		-- Tag is Opts,Dur,Dur2,Endings
		return cd.opt_Associative
	elseif c == 2 then
		-- Tag is Pos,Pos2
		if dict.NoteObjTypes[ObjType] then return cd.opt_NotePos end
		return cd.opt_Num
	elseif c == 3 or (ObjType == "SongInfo") then
		-- Tag is Text,Name,Label,Group,Typeface
		return cd.opt_Text
	elseif c == 4 then
		-- Tag is DynVel,WithNextStaff,WhenHidden
		return cd.opt_List
	elseif c == 5 then
		-- Tag is Signature
		if ObjType == "Key" then return cd.opt_Associative end
	elseif c == 6 then
		-- Tag is Bar
		if ObjType == "Context" then return cd.opt_List end
	elseif c == 7 then
		return cd.opt_Num
	end

	return cd.opt_Raw
end

local function retstr(s) return tostring(s) end
local function retnum(n) return tonumber(n) or tostring(n) end
--
local OptCapture_D
initProcs:insert(function() OptCapture_D = {
	[cd.opt_Raw] = retstr,
	[cd.opt_Num] = retnum,
	[cd.opt_Text] = nwcOptText.new,
	[cd.opt_List] = nwcOptList.new,
	[cd.opt_Associative] = nwcOptGroup.new,
	[cd.opt_NotePos] = nwcNotePosList.new,
	[cd.opt_UserObjOpt] = nwcUserObjOpt.new
} end)
--
function nwcut.CaptureOptData(Level,ObjType,Tag,Data)
	local c = cd.opt_Raw
	if Level > 1 then c = nwcut.ClassifyOptTag(ObjType,Tag) end
	return OptCapture_D[c](tostring(Data))
end

function nwcut.buildEnv() return {
	nwc=nwc,nwcut=nwcut,StringBuilder=StringBuilder,
	nwcFile=nwcFile,nwcStaff=nwcStaff,nwcItem=nwcItem,nwcNotePos=nwcNotePos,nwcNotePosList=nwcNotePosList,
	nwcOptGroup=nwcOptGroup,nwcOptList=nwcOptList,nwcOptText=nwcOptText,nwcUserObjOpt=nwcUserObjOpt,
	nwcPlayContext=nwcPlayContext,
	}
end

function nwcut.run(usertoolCmd)
	local vlist = [[_VERSION,arg,assert,bit32,error,getmetatable,ipairs,math,next,pairs,pcall,print,rawequal,rawget,rawset,select,setmetatable,string,utf8string,table,tonumber,tostring,type]]
	local SandboxEnv = nwcut.buildEnv()
	for o in vlist:gmatch("[%w_]+") do SandboxEnv[o] = _ENV[o] end
	
	nwcut.preload()

	assert(loadfile(usertoolCmd,"t",SandboxEnv))()
end

-------------------------------------
StringBuilder.__index = StringBuilder

function StringBuilder.new(...)
	local o = {t={}}
	setmetatable(o,StringBuilder)
	o:add(...)
	return o
end

function StringBuilder:reset()
	for k in pairs (self.t) do
		self.t[k] = nil
	end
end

function StringBuilder:add(...)
	local a = {...}
	for i = 1, #a do table.insert(self.t,tostring(a[i])) end
end

function StringBuilder:prepend(...)
	local a = {...}
	for i = 1, #a do table.insert(self.t,i,tostring(a[i])) end
end

function StringBuilder:__tostring()
	return table.concat(self.t)
end

function StringBuilder.Writer(obj)
	local st = StringBuilder.new()
	obj:WriteUsing(function(...) st:add(...) end)
	return tostring(st)
end

------------------------------
nwcOptText.__index = nwcOptText
nwcOptText.__tostring = StringBuilder.Writer

local TextUnesc_D = {["}"]="|",["]"]="\\",["|"]="|",["\'"]="\'",["\""]="\"",r="\r",n="\n",t="\t"}
local TextEsc_D = {["|"]="\\}",["\\"]="\\]",["\'"]="\\\'",["\""]="\\\"",["\r"]="\\r",["\n"]="\\n",["\t"]="\\t"}
local new_nwcOptText = function(c,s)
	local t = {Text=''}
	if s:match("^[\"\']") then s = s:sub(2,-2) end
	t.Text = s:gsub("\\(.)",TextUnesc_D)
	return setmetatable(t,c)
end

function nwcOptText.new(s)
	return new_nwcOptText(nwcOptText,s)
end

function nwcOptText:WriteUsing(writeFunc)
	writeFunc('"',self.Text:gsub("([\r\n\t\\|\'\"])",TextEsc_D),'"')
end

function nwcOptText:gettext() return self.Text end
function nwcOptText:settext(s) self.Text = tostring(s or '') end

function nwcOptText:len() return self.Text:len() end
function nwcOptText:lower() return self.Text:lower() end
function nwcOptText:upper() return self.Text:upper() end
function nwcOptText:gmatch(p) return self.Text:gmatch(p) end
function nwcOptText:match(p) return self.Text:match(p) end
function nwcOptText:find(...) return self.Text:find(...) end
function nwcOptText:gsub(...) return self.Text:gsub(...) end
function nwcOptText:sub(...) return self.Text:sub(...) end

------------------------------
nwcUserObjOpt.__index = nwcUserObjOpt
nwcUserObjOpt.__tostring = StringBuilder.Writer
setmetatable(nwcUserObjOpt,{__index=nwcOptText})

function nwcUserObjOpt.new(s)
	return new_nwcOptText(nwcUserObjOpt,s)
end

function nwcUserObjOpt:WriteUsing(writeFunc)
	local s = self.Text:gsub("([\r\n\t\\|\'\"])",TextEsc_D)
	if s:match('[ \\]') then
		writeFunc('"',s,'"')
	else
		writeFunc(s)
	end
end

------------------------------
nwcOptList.__index = nwcOptList
setmetatable(nwcOptList,{__index=table})

function nwcOptList.new(s)
	local ol = {}
	setmetatable(ol,nwcOptList)
	for o in s:gmatch("[^,]+") do ol:insert(o) end
	return ol
end

function nwcOptList:WriteUsing(writeFunc)
	for k,v in ipairs(self) do
		if k > 1 then writeFunc(',') end
		writeFunc(v)
	end
end

function nwcOptList:__tostring() return self:concat(',') end

function nwcOptList:Find(a) return tableContains(self,a) end

------------------------------
nwcOptGroup.__index = nwcOptGroup
nwcOptGroup.__tostring = StringBuilder.Writer

function nwcOptGroup.new(s)
	local a = {}
	setmetatable(a,nwcOptGroup)
	for o in s:gmatch('[^,]+') do
		local m1,m2 = o:match('^([^%=]+)%=(.*)$')
		a[m1 or o] = m2 or ''
	end
	return a
end

function nwcOptGroup:WriteUsing(writeFunc)
	local i=0
	for k,v in pairs(self) do
		local v_out = tostring(v)
		if i>0 then writeFunc(',') end
		writeFunc(k)
		if v_out:len() > 0 then
			writeFunc('=',v_out)
		end
		i=i+1
	end
end

------------------------------
nwcNotePos.__index = nwcNotePos
nwcNotePos.__tostring = StringBuilder.Writer

function nwcNotePos.new(s)
	local a = {Position=0}
	local Accidental, Position, Notehead, Tied, Color, CourtesyAcc = s:match("([#bnxv]?)(-?%d+)(%a?)(^?)!?(%d?)(%)?)")
	if Accidental ~= "" then a.Accidental = Accidental end
	if Position ~= "" then a.Position = tonumber(Position) end
	if Notehead ~= "" then a.Notehead = Notehead end
	if Tied == "^" then a.Tied = true end
	if Color ~= "" then a.Color = tonumber(Color) end
	if CourtesyAcc == ")" then a.CourtesyAcc = true end
	return setmetatable(a,nwcNotePos)
end

function nwcNotePos:WriteUsing(writeFunc)
	if self.Accidental then writeFunc(self.Accidental) end
	writeFunc(self.Position)
	if self.Notehead then writeFunc(self.Notehead) end
	if self.Tied then writeFunc("^") end
	if self.Color and (tonumber(self.Color) > 0) then  writeFunc("!",self.Color) end
	if self.CourtesyAcc then writeFunc(")") end
end

function nwcNotePos:GetAccidentalPitchOffset()
	return self.Accidental and dict.AccidentalOffsets[self.Accidental] or 0
end

function nwcNotePos:GetNoteName(clef)
	local n = math.fmod(nwcut.GetClefStdCenterTone(clef) + self.Position, 7)
	return dict.NoteNames[(n < 0) and (n+8) or (n+1)]
end


------------------------------
nwcNotePosList.__index = nwcNotePosList
nwcNotePosList.__tostring = StringBuilder.Writer

function nwcNotePosList.new(s)
	local a = {}
	setmetatable(a,nwcNotePosList)

	for o in s:gmatch("[^,]+") do
		table.insert(a,nwcNotePos.new(o))
	end

	return a
end

function nwcNotePosList:WriteUsing(writeFunc)
	for k,v in ipairs(self) do
		if k > 1 then writeFunc(',') end
		writeFunc(tostring(v))
	end
end

----------------------------------------------------------------
nwcItem.__index = nwcItem
nwcItem.__tostring = StringBuilder.Writer

function nwcItem.SetDefaultLevel(lvl) nwcItem.DefaultLevel = math.max(math.min(tonumber(lvl),2),0) end

function nwcItem.new(cliptext,level)
	level = tonumber(level) or nwcItem.DefaultLevel
	level = math.min(level,2)

	if level < 1 then return cliptext end

	local ObjType = nil
	local UserType = nil
	local Opts = {}
	local isFake = false
	local doCapture = nwcut.CaptureOptData

	for sep,fld in cliptext:gmatch("([|%s]+)([^|]+)") do
		if not ObjType then
			ObjType = fld
		elseif ObjType == "Fake" then
			ObjType = fld
			isFake = true
		elseif (ObjType == "User") and not UserType then
			UserType = fld
		else
			local lbl,data = fld:match("^([%w%-%_]+)[%:%s]+(.*)")
			lbl = lbl or fld
			data = data or ""
			Opts[lbl] = doCapture(level,ObjType,lbl,data)
		end
	end

	if ObjType then
		local item = {["ObjType"]=ObjType,["Opts"]=Opts,["Level"]=level}
		if isFake then item.Fake = true end
		if ObjType == "User" then item.UserType = UserType or "..." end
		setmetatable(item,nwcItem)
		return item
	end

	return nil
end

function nwcItem:WriteUsing(writeFunc)
	if self.Fake then writeFunc("|Fake") end

	writeFunc("|",self.ObjType)

	if self.UserType then writeFunc("|",self.UserType) end

	for k,v in pairs(self.Opts) do
		writeFunc("|",k)
		if v then
			writeFunc(":")
			if (type(v) == "table") and v.WriteUsing then 
				v:WriteUsing(writeFunc)
			else
				writeFunc(tostring(v))
			end
		end
	end
end

function nwcItem:IsFake() return (self.Fake == true) or (self.ObjType == 'Context') end

function nwcItem:Is(t,t2)
	if self.ObjType == t then
		if t2 and (t=='User') then return self.UserType == t2 end
		return true
	end
	return false
end

function nwcItem:GetUserType() return self:Is('User') and self.UserType or false end

function nwcItem:IsNoteRestChord()
	return (dict.NoteObjTypes[self.ObjType] == 1)
end

function nwcItem:ContainsNotes()
	return (dict.NoteObjTypes[self.ObjType] == 1) and (self.ObjType ~= 'Rest')
end

function nwcItem:Get(...)
	local a = {...}
	local v = self.Opts
	for i = 1, #a do
		if v == nil then break end
		v = v[a[i]]
	end
	return v
end

function nwcItem:GetNum(...) return tonumber(self:Get(...)) end

function nwcItem:Set(lbl,data)
	self.Opts[lbl] = nwcut.CaptureOptData(self.Level,self.ObjType,lbl,data or "")
end

function nwcItem:Provide(lbl,data)
	if not self.Opts[lbl] then self:Set(lbl,data) end
	return self.Opts[lbl]
end

local function sanitizeDur(v)
	if not v then return 'Dur'
	elseif v == 1 then return 'Dur'
	elseif v == 2 then return 'Dur2'
	end
	return v
end

function nwcItem:NoteDurBase(v)
	if not self:IsNoteRestChord() then return nil end
	v = sanitizeDur(v)
	local tDur = self:Get(v)
	if not tDur then return (v ~= 'Dur2') and '4th' or nil end
	for _,k in ipairs(nwc.txt.NoteDurBase) do
		if tDur[k] then return k end
	end
	return '4th'
end

function nwcItem:NoteDots(v)
	v = sanitizeDur(v)
	local tDur = self:Get(v)
	if not tDur then return 0
	elseif tDur.DblDotted then return 2
	elseif tDur.Dotted then return 1
	end
	return 0
end

function nwcItem:HasDuration()
	if self:NoteDurBase() then
		return not hasValue(self:Get('Dur','Grace'))
	elseif self.ObjType == 'RestMultiBar' then 
		return true
	end

	return false
end

function nwcItem:AllNotePositions()
	local p1 = self:Get('Pos')
	local p2 = self:Get('Pos2')
	local idx = 0
	if not self:ContainsNotes() then
		return function() return nil end
	elseif not p1 then
		if not p2 then
			return function() return nil end
		end
		p1,p2 = p2,nil
	elseif p2 and (self:Get('Opts','Stem') == 'Up') then
		p1,p2 = p2,p1
	end

	return function()
		idx = idx + 1
		if p1[idx] ~= nil then return p1[idx] end
		if not p2 then return nil end
		idx = 1
		p1,p2 = p2,nil
		return p1[1]
	end
end

		
----------------------------------------------------------------
nwcStaff.__index = nwcStaff

function nwcStaff.new()
	local o = {
		AddStaff = nwcItem.new('|AddStaff|Name:"Staff"|Group:"Standard"'),
		StaffProperties = nwcItem.new('|StaffProperties|Device:0|Channel:1|EndingBar:Section Close|Visible:Y|BoundaryTop:12|BoundaryBottom:12|Lines:5|Color:Default'),
		StaffInstrument = nwcItem.new('|StaffInstrument|Trans:0|DynVel:10,30,45,60,75,92,108,127'),
		Lyrics = nwcItem.new('|Lyrics|Placement:Bottom|Align:Standard Rules|Offset:0'),
		Lyric = {},
		Items = {},
		}

	setmetatable(o,nwcStaff)
	return o
end

function nwcStaff:add(item)
	local c = nwcut.ClassifyObjType(item.ObjType)
	if c == nwcut.const.objtyp_StaffNotation then
		table.insert(self.Items,item)
	elseif item.ObjType:match('Lyric%d') then
		table.insert(self.Lyric,item)
	elseif self[item.ObjType] then
		mergeItem(self[item.ObjType],item)
	else
		assert(false,'Unrecognized staff object '..item.ObjType)
	end
end

function nwcStaff:save(f)
	f = f or nwcut.writeline
	f(self.AddStaff)
	f(self.StaffProperties)
	f(self.StaffInstrument)
	if #self.Lyric > 0 then
		f(self.Lyrics)
		for i,v in ipairs(self.Lyric) do
			if v then f(v) end
		end
	end
	for i,v in ipairs(self.Items) do f(v) end
end

----------------------------------------------------------------
nwcFile.__index = nwcFile

local nwcFilePropOrder = {'Editor','SongInfo','PgSetup','PgMargins'}
local nwcFilePropDefaults = {
	Editor='|Editor|ActiveStaff:1|CaretIndex:1|SelectIndex:0|CaretPos:0',
	SongInfo='|SongInfo|Title:""|Author:""|Lyricist:""|Copyright1:""|Copyright2:""',
	PgSetup='|PgSetup|StaffSize:16|Zoom:4||TitlePage:Y|JustifyVertically:Y|PrintSystemSepMark:N|ExtendLastSystem:N|DurationPadding:Y|PageNumbers:0|StaffLabels:None|BarNumbers:None|StartingBar:1',
	PgMargins='|PgMargins|Left:1.27|Top:1.27|Right:1.27|Bottom:1.27|Mirror:N'
}

function nwcFile.new()
	local o = {}

	-- force level 2 for this functionality
	nwcut.setlevel(2)

	for k,v in pairs(nwcFilePropDefaults) do
		o[k] = nwcItem.new(v)
	end

	o.Font = {
		StaffItalic = nwcItem.new('|Font|Style:StaffItalic|Typeface:"Times New Roman"|Size:10|Bold:Y|Italic:Y|CharSet:0'),
		StaffBold = nwcItem.new('|Font|Style:StaffBold|Typeface:"Times New Roman"|Size:8|Bold:Y|Italic:N|CharSet:0'),
		};

	o.Staff = {nwcStaff.new()}

	setmetatable(o,nwcFile)
	return o
end

function nwcFile:load(items)
	items = items or nwcut.items
	local cstaff = false

	for item in items() do
		local objt = item.ObjType
		local c = nwcut.ClassifyObjType(objt)

		if nwcFilePropDefaults[objt] then
			mergeItem(self[objt],item)
		elseif item:Is('Font') then
			local fs = item:Get('Style')
			if fs then self.Font[fs] = item end
		else
			if (objt == 'AddStaff') or not cstaff then
				if cstaff then table.insert(self.Staff,nwcStaff.new()) end
				cstaff = self.Staff[#self.Staff]
			end

			cstaff:add(item)
		end
	end

	if nwcut.getprop('Mode') == nwcut.const.mode_ClipText then
		self.Editor.Opts.SelectIndex = #cstaff.Items + 1
	end
end

function nwcFile:getSelection()
	local e = self.Editor
	local staffidx, i1, i2 = e:GetNum('ActiveStaff'),e:GetNum('CaretIndex') or 1,e:GetNum('SelectIndex') or 0
	local staff = self.Staff[staffidx] or self.Staff[1]
	if i2 > 0 then i1,i2 = math.min(i1,i2),math.max(i1,i2)-1 end
	return staff,i1,i2
end

local function l2rSelection(e)
	local i1,i2 = e:GetNum('CaretIndex') or 1,e:GetNum('SelectIndex') or 0
	return (i2>0) and (i2<i1)
end
--
function nwcFile:setSelection(p1,p2,p3)
	local e = self.Editor
	local l2r = l2rSelection(self.Editor)
	local staff,i1,i2 = self:getSelection(),p1,p2 or 0
	if (typeOf(p1) == 'nwcStaff') or p3 then
		if typeOf(p1) == 'nwcStaff' then p1 = tableContains(self.Staff,p1) end
		staff = self.Staff[p1]
		assert(staff,"staff not found")
		e.Opts.ActiveStaff = p1
		if p2 then i1,i2 = p2,(p3 or 0) else i1,i2 = 1,#staff.Items end
	end
	
	if i2 >= i1 then
		e.Opts.CaretIndex,e.Opts.SelectIndex = parmswap(l2r,i1,i2+1)
	else
		e.Opts.CaretIndex = i1
		e.Opts.SelectIndex = nil
	end
end

function nwcFile:forSelection(f)
	local staff,i1,i2 = self:getSelection()
	local items,i = staff.Items,i1
	while i <= i2 do
		local o = items[i]
		if not o then break end
		local o2 = f(o,i-i1+1,i==i2)
		local tid = typeOf(o2)
		if tid == 'nwcItem' then
			items[i],i = o2,i+1
		elseif tid == 'table' then
			table.remove(items,i)
			i2 = i2 - 1
			for _,v in ipairs(o2) do
				table.insert(items,i,v)
				i,i2 = i+1,i2+1
			end
		elseif o2 == 'delete' then
			table.remove(items,i)
			i2=i2-1
		else
			i=i+1
		end
	end

	self:setSelection(i1,i2)
	return self
end

function nwcFile:save(f)
	f = f or nwcut.writeline
	if nwcut.getprop('ReturnMode') == cd.mode_FileText then
		f(string.format('!NoteWorthyComposer(%s)',nwcut.getprop('HdrVersion')))
		for _,k in ipairs(nwcFilePropOrder) do
			f(self[k])
		end

		for _,k in ipairs(nwc.txt.TextExpressionFonts) do
			if self.Font[k] then f(self.Font[k]) end
		end

		for i,v in ipairs(self.Staff) do
			v:save(f)
		end
		f('!NoteWorthyComposer-End')
	else
		f(string.format('!NoteWorthyComposerClip(%s,Single)',nwcut.getprop('HdrVersion')))
		self:forSelection(function(o) if not o:IsFake() then f(o) end end)
		f('!NoteWorthyComposerClip-End')
	end
end

----------------------------------------------------------------
nwcPlayContext.__index = nwcPlayContext
nwcPlayContext.__tostring = StringBuilder.Writer

function nwcPlayContext.new()
	local c = {
		Clef="Treble",
		ClefOctave="None",
		Transposition=0,
		KeyTonic='C',
		NextBarNum=1,
		PendingBarIncrement=true,
		Slur=false,
		SeenFirstEnding=false,
		Ending1Context={},
		RunKey={C=0,D=0,E=0,F=0,G=0,A=0,B=0},
		Key={C=0,D=0,E=0,F=0,G=0,A=0,B=0},
		Ties={},
		}

	if nwcItem.DefaultLevel < 0 then nwcItem.DefaultLevel = 2 end

	return setmetatable(c,nwcPlayContext)
end

function nwcPlayContext:GetBarNum() return self.NextBarNum end

function nwcPlayContext:GetOctaveShift()
	if self.ClefOctave == "Octave Up" then return 1 end
	if self.ClefOctave == "Octave Down" then return -1 end
	return 0
end

function nwcPlayContext:GetPlayPitchShift()
	return (12 * self:GetOctaveShift()) + self.Transposition
end

function nwcPlayContext:GetNoteName(notepitchObj)
	return notepitchObj:GetNoteName(self.Clef)
end

local function GetTiePosFromStr(s)
	return tonumber(s:sub(2))
end
--
function nwcPlayContext:GetNoteAccidental(notepitchObj)
	if (hasValue(notepitchObj.Accidental)) then return notepitchObj.Accidental end

	for _,tie in ipairs(self.Ties) do
		if (GetTiePosFromStr(tie) == notepitchObj.Position) then return tie:sub(1,1) end
	end
		
	local n = notepitchObj:GetNoteName(self.Clef)
	return nwcut.GetOffsetAccidental(self.RunKey[n])
end

function nwcPlayContext:GetScientificPitchOctave(notepitchObj)
	return math.floor((nwcut.GetClefStdCenterTone(self.Clef) + notepitchObj.Position) / #dict.NoteNames) + self:GetOctaveShift()
end

function nwcPlayContext:GetNoteMidiPitch(notepitchObj)
	local d = (12 * (self:GetScientificPitchOctave(notepitchObj) + 1))
	d = d + dict.BaseNoteSemitones[notepitchObj:GetNoteName(self.Clef)]
	d = d + dict.AccidentalOffsets[self:GetNoteAccidental(notepitchObj)]
	d = d + self.Transposition

	if (d < 0) then
		d = 12 - math.fmod(math.abs(d),12)
	elseif (d > 127) then
		d = 115 + math.fmod(d - 115,12)
	end

	return d
end

function nwcPlayContext:FindTieIndex(o)
	local accPos = (typeOf(o) == "nwcNotePos") and string.format("%s%d",self:GetNoteAccidental(o),o.Position) or tostring(o)

	for i,v in ripairs(self.Ties) do
		if v == accPos then return i end
	end

	return false
end

local PlayContextSaveRestoreFlds = {"Clef","ClefOctave","Transposition","Key","RunKey","KeyTonic","Ties","Slur"}
local function copyPlayContextFromTo(r1,r2)
	for _,k in ipairs(PlayContextSaveRestoreFlds) do
		local v = r1[k]
		if (type(v) == 'table') then
			local v2 = {}
			for v_k,v_v in pairs(v) do v2[v_k] = v_v end
			r2[k] = v2
		else
			r2[k] = v
		end
	end
end

function nwcPlayContext:put(o)
	assert(o.ObjType and (o.Level > 1),"a level 2 instance of nwcItem is required")

	if (dict.NoteObjTypes[o.ObjType] == 1) then
		local RunKey_Changes = {}
		copyKeySig(RunKey_Changes,self.RunKey)

		for notepitchObj in o:AllNotePositions() do
			local notename = notepitchObj:GetNoteName(self.Clef)
			local noteacc = self:GetNoteAccidental(notepitchObj)
			local tieSpec = noteacc..notepitchObj.Position

			local runningTieKey = self:FindTieIndex(tieSpec)
			if runningTieKey then
				if not hasValue(notepitchObj.Tied) then
					table.remove(self.Ties,runningTieKey)
				end
			elseif hasValue(notepitchObj.Tied) then
				table.insert(self.Ties,tieSpec)
			end

			if hasValue(notepitchObj.Accidental) then
				RunKey_Changes[notename] = notepitchObj:GetAccidentalPitchOffset()
			end
		end

		copyKeySig(self.RunKey,RunKey_Changes)

		if (not hasValue(o:Get("Dur","Grace"))) then
			self.Slur = hasValue(o:Get("Dur","Slur"))
		end

		if (self.PendingBarIncrement) then
			self.NextBarNum = self.NextBarNum + 1
			self.PendingBarIncrement = false
		end
	elseif (o.ObjType == "Context") then
		local OptBar = o:Get("Bar")
		if (hasValue(OptBar)) then
			self.NextBarNum = tonumber(OptBar[1] or 1)
			self.PendingBarIncrement = (OptBar:Find("AtStart") ~= nil)
			if (not self.PendingBarIncrement) then self.NextBarNum = self.NextBarNum + 1 end
		end
	elseif (o.ObjType == "Bar") then
		copyKeySig(self.RunKey,self.Key)
		if (o:Get("Style") == "MasterRepeatOpen") then self.SeenFirstEnding = false end
		self.PendingBarIncrement = (o:Get("XBarCnt") ~= "Y")
	elseif (o.ObjType == "RestMultiBar") then
		if (self.PendingBarIncrement) then self.NextBarNum=self.NextBarNum+1 end
		self.PendingBarIncrement = false;
		self.NextBarNum = self.NextBarNum + tonumber(o:Get("NumBars") or 1) - 1
	elseif (o.ObjType == "Clef") then
		self.Clef = o:Get("Type") or "Treble"
		self.ClefOctave = o:Get("OctaveShift") or "None"
	elseif (o.ObjType == "Key") then
		local k = o:Get("Signature")
		if (hasValue(k)) then
			for _,notename in ipairs(dict.NoteNames) do
				local a = 0
				if (k[notename.."b"]) then a = a - 1
				elseif (k[notename.."#"]) then a = a + 1
				end

				self.Key[notename] = a
			end
		end

		copyKeySig(self.RunKey,self.Key)
		self.KeyTonic = o:Get("Tonic") or "C"
	elseif (o.ObjType == "Instrument") then
		self.Transposition = tonumber(o:Get("Trans") or 0)
	elseif (o.ObjType == "Ending") then
		local e = o:Get("Endings")
		if (hasValue(e)) then
			if e["1"] then
				if (not self.SeenFirstEnding) then
					self.SeenFirstEnding = true
					copyPlayContextFromTo(self,self.Ending1Context)
				end
			elseif (self.SeenFirstEnding) then
				copyPlayContextFromTo(self.Ending1Context,self)
			end
		end
	end

	return o
end

---------------------------------------
for _,f in ipairs(initProcs) do f() end

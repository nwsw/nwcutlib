-- nwctxt.lua: Utility definitions and classes for processing NoteWorthy Composer nwctxt using Lua 

nwctxt = {}

function nwctxt.ProtectTable(tbl) return setmetatable({},{
	__index = tbl,
	__newindex = function (t, n, v) error("nwctxt constant change "..tostring(n).." to "..tostring (v), 2)  end,
	__pairs = function() return function(_,k) return next(tbl,k) end end,
	})
end

nwctxt.const = nwctxt.ProtectTable({
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
	opt_NotePos		= 6
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

local cd=nwctxt.const

local function hasValue(v) return (v and (v ~= "")) or false end
local function CopyKeySig(dest,src)	for k,v in pairs(src) do dest[k] = v end end
local function ripairs(t) local function r2(t,i) i=i-1;if t[i]~=nil then return i,t[i] end end return r2, t, #t+1 end

function nwctxt.GetClefStdCenterTone(clef) return dict.ClefCenterTones[clef] or dict.ClefCenterTones['Treble'] end
function nwctxt.GetOffsetAccidental(offset) return dict.Accidentals[tonumber(offset)+3] or "" end
function nwctxt.GetAccidentalOffset(acc) return dict.AccidentalOffsets[acc] or 0 end

local function iterlistvals(t) local i=0;return function() i=i+1;if t[i] then return t[i] end;end;end
function nwctxt.AllNoteNames() return iterlistvals(dict.NoteNames) end
function nwctxt.AllAccidentals() return iterlistvals(dict.Accidentals) end

----------------------------------------------------------------

StringBuilder = {ID='StringBuilder'}
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

nwcOptText = {ID='nwcOptText',__tostring=StringBuilder.Writer}
------------------------------
nwcOptText.__index = nwcOptText

local TextUnesc_D = {["}"]="|",["]"]="\\",["|"]="|",["\'"]="\'",["\""]="\"",r="\r",n="\n",t="\t"}
local TextEsc_D = {["|"]="\\}",["\\"]="\\]",["\'"]="\\\'",["\""]="\\\"",["\r"]="\\r",["\n"]="\\n",["\t"]="\\t"}
function nwcOptText.new(s)
	if s:match("^[\"\']") then s = s:sub(2,-2) end
	s = s:gsub("\\(.)",TextUnesc_D)
	local t = {Text=s}
	return setmetatable(t,nwcOptText)
end

function nwcOptText:WriteUsing(writeFunc)
	local s = self.Text:gsub("([\r\n\t\\|\'\"])",TextEsc_D)

	writeFunc('"',s,'"')
end

nwcOptList = {ID='nwcOptList'}
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

function nwcOptList:Find(a) 
	for k,v in ipairs(self) do
		if (v == a) then return k end
	end
	return nil
end


nwcOptGroup = {ID='nwcOptGroup',__tostring=StringBuilder.Writer}
------------------------------
nwcOptGroup.__index = nwcOptGroup

function nwcOptGroup.new(s)
	local a = {}
	setmetatable(a,nwcOptGroup)
	for o in s:gmatch("[^,]+") do
		local m1,m2 = o:match("^([^%=]+)%=(.*)$")
		a[m1 or o] = m2 or ""
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

nwcNotePos = {ID='nwcNotePos',__tostring=StringBuilder.Writer}
------------------------------
nwcNotePos.__index = nwcNotePos

function nwcNotePos.new(s)
	local a = {Position=0}
	local Accidental, Position, Notehead, Tied, Color = s:match("([#bnxv]?)(-?%d+)(%a?)(^?)!?(%d?)")
	if Accidental ~= "" then a.Accidental = Accidental end
	if Position ~= "" then a.Position = tonumber(Position) end
	if Notehead ~= "" then a.Notehead = Notehead end
	if Tied == "^" then a.Tied = true end
	if Color ~= "" then a.Color = tonumber(Color) end
	return setmetatable(a,nwcNotePos)
end

function nwcNotePos:WriteUsing(writeFunc)
	if self.Accidental then writeFunc(self.Accidental) end
	writeFunc(self.Position)
	if self.Notehead then writeFunc(self.Notehead) end
	if self.Tied then writeFunc("^") end
	if self.Color and (tonumber(self.Color) > 0) then  writeFunc("!",self.Color) end
end

function nwcNotePos:GetAccidentalPitchOffset()
	return self.Accidental and dict.AccidentalOffsets[self.Accidental] or 0
end

function nwcNotePos:GetNoteName(clef)
	local n = math.fmod(nwctxt.GetClefStdCenterTone(clef) + self.Position, 7)
	return dict.NoteNames[(n < 0) and (n+8) or (n+1)]
end


nwcNotePosList = {ID='nwcNotePosList',__tostring=StringBuilder.Writer}
------------------------------
nwcNotePosList.__index = nwcNotePosList

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
local ltyp_D = {[0x21]=1,[0x23]=2,[0x7c]=3}

function nwctxt.ClassifyLine(ln)
	local fc = string.byte(ln,1)
	if fc == nil
		then return cd.ltyp_Comment
	else
		return ltyp_D[fc] or cd.ltyp_Error
	end
end

function nwctxt.objtyp(s)
	local _,_,objt = string.find(s,"^|(%w+)")
	return objt
end

local ObjTyp_D = {
	Note=1,Chord=1,Bar=1,Rest=1,Text=1,Dynamic=1,Clef=1,Key=1,TimeSig=1,
	Locale=2,Editor=2,SongInfo=2,PgSetup=2,Font=2,PgMargins=2,
	AddStaff=2,StaffProperties=2,StaffInstrument=2
	}

function nwctxt.ClassifyObjType(ObjType)
	if not ObjType then return cd.objtyp_Error end

	local otc = ObjTyp_D[ObjType]
	if otc == 1 then
		return cd.objtyp_StaffNotation
	elseif otc == 2 then
		return cd.objtyp_StaffProperty
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

function nwctxt.ClassifyOptTag(ObjType,Tag)
	-- The OptTag_D dictionary is optimized for speed
	local c = OptTag_D[Tag]

	if not c then
		-- Tag is Visibility,Color or unlisted
		return cd.opt_Raw
	elseif ObjType == "User" then
		return (Tag == "Pos") and cd.opt_Num or cd.opt_Raw
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

local OptCapture_D = {
	[cd.opt_Raw] = retstr,
	[cd.opt_Num] = retnum,
	[cd.opt_Text] = nwcOptText.new,
	[cd.opt_List] = nwcOptList.new,
	[cd.opt_Associative] = nwcOptGroup.new,
	[cd.opt_NotePos] = nwcNotePosList.new
	}
--
function nwctxt.CaptureOptData(Level,ObjType,Tag,Data)
	local c = cd.opt_Raw
	if Level > 1 then c = nwctxt.ClassifyOptTag(ObjType,Tag) end
	return OptCapture_D[c](tostring(Data))
end

----------------------------------------------------------------
nwcItem = {ID='nwcItem',__tostring=StringBuilder.Writer,DefaultLevel=-1}
nwcItem.__index = nwcItem

function nwcItem.SetDefaultLevel(lvl) nwcItem.DefaultLevel = math.max(math.min(tonumber(lvl),2),0) end

function nwcItem.new(cliptext,level)
	level = tonumber(level) or nwcItem.DefaultLevel
	level = math.min(level,2)

	if level < 1 then return cliptext end

	local ObjType = nil
	local UserType = nil
	local Opts = {}
	local isFake = false
	local doCapture = nwctxt.CaptureOptData

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

function nwcItem:IsFake() return (self.Fake == true) or (self.ObjType == "Context") end

function nwcItem:GetUserType() return (self.ObjType == "User") and self.UserType or false end

function nwcItem:Is(t)
	return (self.ObjType == t)
end

function nwcItem:IsNoteRestChord()
	return (dict.NoteObjTypes[self.ObjType] == 1)
end

function nwcItem:ContainsNotes()
	return (dict.NoteObjTypes[self.ObjType] == 1) and (self.ObjType ~= "Rest")
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

function nwcItem:Provide(lbl,data)
	if not self.Opts[lbl] then
		self.Opts[lbl] = nwctxt.CaptureOptData(self.Level,self.ObjType,lbl,data or "")
	end

	return self.Opts[lbl]
end

function nwcItem:HasDuration()
	if (dict.NoteObjTypes[self.ObjType] == 1) then
		return not hasValue(self:Get("Dur","Grace"))
	elseif self.ObjType == "RestMultiBar" then 
		return true
	end

	return false
end

function nwcItem:AllNotePositions()
	local p1 = self:Get("Pos")
	local p2 = self:Get("Pos2")
	local idx = 0
	if not self:ContainsNotes() then
		return function() return nil end
	elseif not p1 then
		if not p2 then
			return function() return nil end
		end
		p1,p2 = p2,nil
	elseif p2 and (self:Get('Opts','Stem') == "Up") then
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
nwcPlayContext = {ID='nwcPlayContext',__tostring=StringBuilder.Writer}
nwcPlayContext.__index = nwcPlayContext

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
	return nwctxt.GetOffsetAccidental(self.RunKey[n])
end

function nwcPlayContext:GetScientificPitchOctave(notepitchObj)
	return math.floor((nwctxt.GetClefStdCenterTone(self.Clef) + notepitchObj.Position) / #dict.NoteNames) + self:GetOctaveShift()
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
	local accPos = (o.ID == "nwcNotePos") and string.format("%s%d",self:GetNoteAccidental(o),o.Position) or tostring(o)

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
		CopyKeySig(RunKey_Changes,self.RunKey)

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

		CopyKeySig(self.RunKey,RunKey_Changes)

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
		CopyKeySig(self.RunKey,self.Key)
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

		CopyKeySig(self.RunKey,self.Key)
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

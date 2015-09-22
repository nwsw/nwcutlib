-- nwcut.lua: Establish the NoteWorthy Composer user tool environment

-- inherit everything from the nwctxt class
setmetatable(nwcut,{__index=nwctxt})

nwcut.write=io.write
nwcut.stderr=io.stderr
nwcut.warn=function(...) nwcut.stderr:write(...) end

local cd=nwctxt.const
local ldata={FileName=false,SavePending=false,StartingLine=nil,EndingLine=false,HdrVersion=nil,Mode=0,ReturnMode=cd.mode_ClipText,ItemsRetrieved=0}
function nwcut.getprop(s)
	if s == "ItemLevel" then return nwcItem.DefaultLevel end
	return ldata[s]
end

nwcut.setlevel = nwcItem.SetDefaultLevel

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

function nwcut.run(usertoolCmd)
	local vlist = "_VERSION,arg,assert,bit32,error,getmetatable,ipairs,math,next,nwc,nwcItem,nwcNotePos,nwcNotePosList,nwcOptGroup,nwcOptList,nwcOptText,nwcPlayContext,nwcut,pairs,pcall,print,select,setmetatable,string,utf8string,StringBuilder,table,tonumber,tostring,type"
	local SandboxEnv = {}
	for o in vlist:gmatch("[^,]+") do SandboxEnv[o] = _ENV[o] end

	assert(loadfile(usertoolCmd,"t",SandboxEnv))()
end

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

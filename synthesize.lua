-- This file can be used to synthesize a simulated `nwcut` environment.
-- This file has no role in the true `nwcut` environment, but you can
-- use it to better understand the true environment.

return function(input_string)
	-- nwc.exe provides a `gzreadline` global function for loading stdin; we fake it here
	gzreadline = input_string:gmatch("([^\r\n]*)")

	-- utf8string = require('lua-utf8')
	utf8string = string

	nwc = dofile('synthesized-nwc.lua')
	nwcut = {}

	nwcut.status = 0

	nwcut.nwcversion = function()
		return nwc.VERSIONTEXT:sub(8)
	end
		
	nwcut.msgbox = function(msg, msgtitle)
		return 0
	end

	nwcut.askbox = function(msg, msgtitle, flags)
		return 1
	end

	nwcut.prompt = function(msg, datatype, default)
		return default
	end

	nwcut.clock = os.clock

	dofile('nwcut.lua')

	-- protect the `nwc` tables...this just simulated the behavior in the true env
	for k,v in pairs(nwc.txt) do nwc.txt[k] = nwcut.ProtectTable(v) end
	nwc.txt = nwcut.ProtectTable(nwc.txt)
	nwc = nwcut.ProtectTable(nwc)
end

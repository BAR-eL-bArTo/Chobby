
Spring.Utilities = Spring.Utilities or {}

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
--deep not safe with circular tables! defaults To false
function Spring.Utilities.CopyTable(tableToCopy, deep)
	local copy = {}
	for key, value in pairs(tableToCopy) do
		if (deep and type(value) == "table") then
			copy[key] = Spring.Utilities.CopyTable(value, true)
		else
			copy[key] = value
		end
	end
	return copy
end

function Spring.Utilities.MergeTable(primary, secondary, deep)
	local new = Spring.Utilities.CopyTable(primary, deep)
	for i, v in pairs(secondary) do
		-- key not used in primary, assign it the value at same key in secondary
		if not new[i] then
			if (deep and type(v) == "table") then
				new[i] = Spring.Utilities.CopyTable(v, true)
			else
				new[i] = v
			end
		-- values at key in both primary and secondary are tables, merge those
		elseif type(new[i]) == "table" and type(v) == "table"  then
			new[i] = Spring.Utilities.MergeTable(new[i], v, deep)
		end
	end
	return new
end

function Spring.Utilities.TableEqual(table1, table2)
	if not table1 then
		return not ((table2 and true) or false)
	end
	if not table2 then
		return false
	end
	for key, value in pairs(table1) do
		if table2[key] ~= value then
			return false
		end
	end
	for key, value in pairs(table2) do
		if table1[key] ~= value then
			return false
		end
	end
	return true
end

-- Returns whether the first table is equal to a subset of the second
function Spring.Utilities.TableSubsetEquals(table1, table2)
	if not table1 then
		return true
	end
	if not table2 then
		return false
	end
	for key, value in pairs(table1) do
		if table2[key] ~= value then
			return false
		end
	end
	return true
end

function Spring.Utilities.TableToString(data, key)
	 local dataType = type(data)
	-- Check the type
	if key then
		if type(key) == "number" then
			key = "[" .. key .. "]"
		end
	end
	if dataType == "string" then
		local cleaned = data:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"):gsub("\a", "\\a"):gsub("\v", "\\v"):gsub("\"", "\\\"")
		return key .. [[="]] .. cleaned .. [["]]
	elseif dataType == "number" then
		return key .. "=" .. data
	elseif dataType == "boolean" then
		return key .. "=" .. ((data and "true") or "false")
	elseif dataType == "table" then
		local str
		if key then
			str = key ..  "={"
		else
			str = "{"
		end
		for k, v in pairs(data) do
			str = str .. Spring.Utilities.TableToString(v, k) .. ","
		end
		return str .. "}"
	else
		Spring.Echo("TableToString Error: unknown data type", dataType)
	end
	return ""
end

-- need this because SYNCED.tables are merely proxies, not real tables
local function MakeRealTable(proxy)
	local proxyLocal = proxy
	local ret = {}
	for i,v in spairs(proxyLocal) do
		if type(v) == "table" then
			ret[i] = MakeRealTable(v)
		else
			ret[i] = v
		end
	end
	return ret
end

local function TableEcho(data, name, indent, tableChecked)
	name = name or "TableEcho"
	indent = indent or ""
	if (not tableChecked) and type(data) ~= "table" then
		Spring.Echo(indent .. name, data)
		return
	end
	Spring.Echo(indent .. name .. " = {")
	local newIndent = indent .. "    "
	for name, v in pairs(data) do
		local ty = type(v)
		--Spring.Echo("type", ty)
		if ty == "table" then
			TableEcho(v, name, newIndent, true)
		elseif ty == "boolean" then
			Spring.Echo(newIndent .. name .. " = " .. (v and "true" or "false"))
		elseif ty == "string" or ty == "number" then
			if type(name) == "userdata" then
				Spring.Echo(newIndent, name, v)
			else
				Spring.Echo(newIndent .. name .. " = " .. v)
			end
		elseif ty == "userdata" then
			Spring.Echo(newIndent .. "userdata", name, v)
		else
			Spring.Echo(newIndent .. name .. " = ", v)
		end
	end
	Spring.Echo(indent .. "},")
end

function Spring.Utilities.ShallowCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

Spring.Utilities.TableEcho = TableEcho

local function TraceFullEcho(maxdepth, maxwidth, maxtableelements, ...)
    -- Call it at any point, and it will give you the name of each function on the stack (up to maxdepth), 
	-- all arguments and first #maxwidth local variables of that function
	-- if any of the values of the locals are tables, then it will try to shallow print + count them up to maxtablelements numbers. 
	-- It will also just print any args after the first 3. (the ... part)
	-- It will also try to print the source file+line of each function
	local tracedebug = false -- to debug itself
	local functionsource = true
	maxdepth = maxdepth or 16
	maxwidth = maxwidth or 10
    maxtableelements = maxtableelements or 6 -- max amount of elements to expand from table type values

    local function dbgt(t, maxtableelements)
        local count = 0
        local res = ''
        for k,v in pairs(t) do
            count = count + 1
            if count < maxtableelements then
				if tracedebug then Spring.Echo(count, k) end 
				if type(k) == "number" and type(v) == "function" then -- try to get function lists?
					if tracedebug then Spring.Echo(k,v, debug.getinfo(v), debug.getinfo(v).name) end  --debug.getinfo(v).short_src)?
                	res = res .. tostring(k) .. ':' .. ((debug.getinfo(v) and debug.getinfo(v).name) or "<function>") ..', '
				else
                	res = res .. tostring(k) .. ':' .. tostring(v) ..', '
				end
            end
        end
        res = '{'..res .. '}[#'..count..']'
        return res
    end

	local myargs = {...}
	infostr = ""
	for i,v in ipairs(myargs) do
		infostr = infostr .. tostring(v) .. "\t"
	end
	if infostr ~= "" then infostr = "Trace:[" .. infostr .. "]\n" end 
	local functionstr = "" -- "Trace:["
	for i = 2, maxdepth do
		if debug.getinfo(i) then
			local funcName = (debug and debug.getinfo(i) and debug.getinfo(i).name)
			if funcName then
				functionstr = functionstr .. tostring(i-1) .. ": " .. tostring(funcName) .. " "
				local arguments = ""
				local funcName = (debug and debug.getinfo(i) and debug.getinfo(i).name) or "??"
				if funcName ~= "??" then
					if functionsource and debug.getinfo(i).source then 
						local source = debug.getinfo(i).source 
						if string.len(source) > 128 then source = "sourcetoolong" end
						functionstr = functionstr .. " @" .. source
					end 
					if functionsource and debug.getinfo(i).linedefined then 
						functionstr = functionstr .. ":" .. tostring(debug.getinfo(i).linedefined) 
					end 
					for j = 1, maxwidth do
						local name, value = debug.getlocal(i, j)
						if not name then break end
						if tracedebug then Spring.Echo(i,j, funcName,name) end 
						local sep = ((arguments == "") and "") or  "; "
                        if tostring(name) == 'self'  then
    						arguments = arguments .. sep .. ((name and tostring(name)) or "name?") .. "=" .. tostring("??")
                        else
                            local newvalue
                            if maxtableelements > 0 and type({}) == type(value) then newvalue = dbgt(value, maxtableelements) else newvalue = value end 
    						arguments = arguments .. sep .. ((name and tostring(name)) or "name?") .. "=" .. tostring(newvalue)
                        end
					end
				end
				functionstr  = functionstr .. " Locals:(" .. arguments .. ")" .. "\n"
			else 
				functionstr = functionstr .. tostring(i-1) .. ": ??\n"
			end
		else break end
	end
	Spring.Echo(infostr .. functionstr)
end

Spring.Utilities.TraceFullEcho = TraceFullEcho

function Spring.Utilities.CustomKeyToUsefulTable(dataRaw)
	if not dataRaw then
		return
	end
	if not (dataRaw and type(dataRaw) == 'string') then
		if dataRaw then
			Spring.Echo("Customkey data error for team", teamID)
		end
	else
		dataRaw = string.gsub(dataRaw, '_', '=')
		dataRaw = Spring.Utilities.Base64Decode(dataRaw)
		local dataFunc, err = loadstring("return " .. dataRaw)
		if dataFunc then
			local success, usefulTable = pcall(dataFunc)
			if success then
				if collectgarbage then
					collectgarbage("collect")
				end
				return usefulTable
			end
		end
		if err then
			Spring.Echo("Customkey error", err)
		end
	end
	if collectgarbage then
		collectgarbage("collect")
	end
end

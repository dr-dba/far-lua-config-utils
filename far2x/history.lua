require("Lib-Common-@Xer0X")
require("introspection-@Xer0X")

-- allow only as module usage:
local is_mdl, inp, own_file_path, own_file_fold, own_file_name, own_file_extn 
	= Xer0X.fnc_file_whoami({ ... })
if not is_mdl then return end

-- ##### 222222

local	srl_file_path, far2srl
do      srl_file_path = own_file_fold.."far2x_serial"..own_file_extn
end
if not	Xer0X.fnc_file_exists(srl_file_path)
then	srl_file_path = own_file_fold.."serial"..own_file_extn
end
if	Xer0X.fnc_file_exists(srl_file_path)
then	far2srl = loadfile(srl_file_path)("load_as_module")
end

--[=[
  Library functions:
    *  hobj = history.newfile (filename)
       *  description:   create a new history object from file
       *  @param filename: file name
       *  @return:       history object

    *  hobj = history.newsettings (subkey, name [, locat])
       *  description:   create a new history object from Far database
       *  @param subkey: subkey name of the plugin root key; nil for the root
       *  @param name:   name of the value
       *  @param locat:  database location, either "PSL_ROAMING" (default) or "PSL_LOCAL"
       *  @return:       history object

  Methods of history object:
    *  value = hobj:field (name)
       *  description:   get or create a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @return:       either value of existing field or a new table
       *  example:       hist:field("mydialog.namelist").width = 120

    *  value = hobj:getfield (name)
       *  description:   get a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @return:       value of a field
       *  example:       local namelist = hist:field("mydialog.namelist")

    *  value = hobj:setfield (name, value)
       *  description:   set a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @param value:  value to set the field
       *  @return:       value
       *  example:       hist:setfield("mydialog.namelist.width", 120)

    *  hobj:save ([locat])
       *  @param locat:  file name or database location, defaults to value used when object was created
       *  description:   save history object

    *  str = hobj:serialize()
       *  description:   serialize history object
       *  @return:       serialized history object
--]=]

local serial  = far2srl or require("far2x.serial")
local history = {}
local meta = { __index = history }

function history:serialize()
  return serial.SaveToString("Data", self.Data)
end

function history:field (fieldname)
  local tb = self.Data
  for v in fieldname:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  return tb
end

function history:getfield (fieldname)
  local tb = self.Data
  for v in fieldname:gmatch("[^.]+") do
    tb = tb[v]
  end
  return tb
end

function history:setfield (name, val)
  local tb = self.Data
  local part1, part2 = name:match("^(.-)([^.]*)$")
  for v in part1:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  tb[part2] = val
  return val
end

local function new (chunk)
  local self
  if chunk then
    self = {}
    setfenv(chunk, self)()
    if type(self.Data) ~= "table" then self = nil end
  end
  self = self or { Data={} }
  return setmetatable(self, meta)
end

local function newfile(FileName)
  assert(type(FileName) == "string")
  local self = new(loadfile(FileName))
  self.FileName = FileName
  return self
end

local function GetSubkey(sett, strSubkey)
  local iSubkey = 0
  for name in strSubkey:gmatch("[^.]+") do
    iSubkey = sett:CreateSubkey(iSubkey, name)
    if iSubkey == nil then return nil end
  end
  return iSubkey
end

local function newsettings(strSubkey, strName, flgLocation)
  flgLocation = flgLocation or "PSL_ROAMING"
  local sett = far.CreateSettings(
  	nil, flgLocation)
  if sett then
    local iSubkey = strSubkey and GetSubkey(sett, strSubkey) or 0
    local data = sett:Get(iSubkey, strName, "FST_DATA") or ""
    sett:Free()
    local self = new(loadstring(data))
    self.Subkey = strSubkey
    self.Name = strName
    self.Location = flgLocation
    return self
  end
end

function history:save(
	location)
  if self.FileName then
    serial.SaveToFile(
    	location or 
    		self.FileName, 
    	"Data", self.Data)
  elseif self.Name then
    local sett = far.CreateSettings(
    	nil, location or self.Location)
    if sett then
      local iSubkey = self.Subkey and GetSubkey(sett, self.Subkey) or 0
      sett:Set(iSubkey, self.Name, "FST_DATA", self:serialize())
      sett:Free()
    end
  end
end

local function dialoghistory (name, from, to)
  local obj = far.CreateSettings("far")
  if obj then
    local root = obj:OpenSubkey(0, name) -- e.g., "NewFolder"
    local data = root and obj:Enum(root, from, to)
    obj:Free()
    return data
  end
end

return {
  newfile = newfile,
  newsettings = newsettings,
  dialoghistory = dialoghistory,
}

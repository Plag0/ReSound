-- This mod runs client-side only
if SERVER then return end

-- Global vars
Resound = {}
Resound.PATH = table.pack(...)[1]
Resound.LoadedPackages = {}

function StartMod()
    dofile(Resound.PATH .. "/Lua/start_mod.lua")
end

Resound.ConfigPath = Resound.PATH .. "/config.json"
Resound.Config = dofile(Resound.PATH .. "/Lua/Menu/load_config.lua")
dofile(Resound.PATH .. "/Lua/Menu/menu.lua")

if not Resound.Config.Enabled then return end

StartMod()
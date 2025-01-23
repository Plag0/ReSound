-- This mod runs client-side only
if SERVER then return end

-- Global vars
Resound = {}
Resound.PATH = table.pack(...)[1]
Resound.SoundPairs = {}

-- Load mod features
local path = Resound.PATH
dofile(path .. "/Lua/load_sound_overrides.lua")
dofile(path .. "/Lua/swap_future_sounds.lua")
dofile(path .. "/Lua/swap_past_sounds.lua")
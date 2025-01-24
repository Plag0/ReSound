-- This mod runs client-side only
if SERVER then return end

-- Global vars
Resound = {}

Resound.PATH = table.pack(...)[1]

-- Vanilla sounds and their custom replacement.
Resound.SoundPairs = {} -- Pairs of "vanilla/path":"custom/path"

-- Sound params for the custom replacements.
Resound.SoundFields = {} -- Pairs of "vanilla/path":{gain, near, far}

-- Additional sounds.
Resound.SoundGroups = {} -- Pairs of "sound/group/path":{sounds={}, sound_fields={{gain, near, far}}, total_num_of_sounds, chance_of_playing}

-- Load files.
local path = Resound.PATH
dofile(path .. "/Lua/load_sound_overrides.lua")
dofile(path .. "/Lua/swap_future_sounds.lua")
dofile(path .. "/Lua/swap_past_sounds.lua")
dofile(path .. "/Lua/edit_sounds.lua")
dofile(path .. "/Lua/stop_sounds.lua")
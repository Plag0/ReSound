-- This mod runs client-side only
if SERVER then return end

-- Global vars
Resound = {}
Resound.PATH = table.pack(...)[1]
-- Original sound directories mapped to their custom replacement.
Resound.OriginalToCustomMap = {} -- Pairs of "original_path":"custom_path"
-- A sound object hash mapped to its original file path.
Resound.HashToOriginalMap = {}
-- Gain, near, and far values for custom sounds mapped to the directory of the original sound.
Resound.CustomSoundParams = {} -- Pairs of "sound_path":{ gain=1, near=100, far=200 }
-- Groups of sounds that share a name and directory. Used as a virtual pool of sounds to play from when a related sound has been subtracted or added.
Resound.SoundGroups = {} -- Pairs of "group_id":{ sounds_to_load={}, sounds={} }
-- Sound paths mapped to their group ID (if they are involved in one).
Resound.SoundPathToGroupID = {} -- Pairs of "sound_path":"group_id"
-- Flag used in the swap_future_sounds.lua code that disables it when UpdateAllSounds() is running.
Resound.IsUpdatingSounds = false

-- Load files.
local path = Resound.PATH
dofile(path .. "/Lua/load_data.lua")
dofile(path .. "/Lua/swap_future_sounds.lua")
dofile(path .. "/Lua/swap_past_sounds.lua")
dofile(path .. "/Lua/edit_sounds.lua")
dofile(path .. "/Lua/stop_sounds.lua")
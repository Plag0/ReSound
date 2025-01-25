-- This code runs once at the start of a round and replaces any loaded sounds that the swap_future_sounds.lua file can't get (because the sounds were created before it was running).

-- These functions go through all the places (that I know of) where Sound objects need to be replaced and swaps in the new sounds.
UpdateAllSounds(Resound.SoundPairs)
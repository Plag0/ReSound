print(string.format("Resound - Reading sound overrides...", #Resound.SoundPairs))

for package in ContentPackageManager.EnabledPackages.All do
    local sound_overrides_file = package.Dir .. "/sound_overrides.json"
    local sound_pairs = {}
    
    if File.Exists(sound_overrides_file) then
        print(string.format("Resound - Reading sound overrides from \"%s\":", package.Name))
        sound_pairs = json.parse(File.Read(sound_overrides_file))
    end

    -- TODO Test what happens if json file not properly formatted.

    for key, value in pairs(sound_pairs) do

        local sound_path = package.Dir .. "/" .. value

        if not File.Exists(sound_path) then
            print(string.format("\tResound - Error in mod \"%s\": \"%s\" does not exist", package.Name, sound_path))

        else
            -- Cosmetics.
            local previous_directory = Resound.SoundPairs[key]
            local new_filename = sound_path:match("^.+/(.+)$")

            if previous_directory then
                local previous_filename = previous_directory:match("^.+/(.+)$")
                print(string.format("\tResound - Load order warning: \"%s\" is replacing \"%s\" with \"%s\"", package.Name, previous_filename, new_filename))
            else
                print(string.format("\tResound - Registered sound: \"%s\"", new_filename))
            end

            Resound.SoundPairs[key] = sound_path
        end
    end
end

local count = 0
for _ in Resound.SoundPairs do
    count = count + 1
end
print(string.format("Resound - Successfully registered %d sound overrides!", count))
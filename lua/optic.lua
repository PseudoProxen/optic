clua_version = 2.056

-- Modules
local harmony = require "mods.harmony"
local optic = harmony.optic
local blam = require "blam"
local json = require "json"
-- local glue = require "glue"

local DebugMode = false
local opticVersion = "2.0.0"
local medalsQueue = {}
-- Controlled by optic.json config file, do not edit on the script!
local configuration = {
    hitmarker = true,
    hudMessages = true,
    style = "halo_4"
}

local function dprint(message)
    if (DebugMode) then
        console_out(message)
    end
end

local events = {
    fallingDead = "falling dead",
    guardianKill = "guardian kill",
    vehicleKill = "vehicle kill",
    playerKill = "player kill",
    betrayed = "betrayed",
    suicide = "suicide",
    localKilledPlayer = "local killed player",
    localDoubleKill = "local double kill",
    localTripleKill = "local triple kill",
    localKilltacular = "local killtacular",
    localKillingSpree = "local killing spree",
    localRunningRiot = "local running riot",
    localCtfScore = "local ctf score",
    ctfEnemyScore = "ctf enemy score",
    ctfAllyScore = "ctf ally score",
    ctfEnemyStoleFlag = "ctf enemy stole flag",
    ctfEnemyReturnedFLag = "ctf enemy returned flag",
    ctfAllyStoleFlag = "ctf ally stole flag",
    ctfAllyReturnedFlag = "ctf ally returned flag",
    ctfFriendlyFlagIdleReturned = "ctf friendly flag idle returned",
    ctfEnemyFlagIdleReturned = "ctf enemy flag idle returned"
}

local soundsEvents = {
    hitmarker = "ting"
}

local imagesPath = "%s/images/%s.png"
local soundsPath = "%s/sounds/%s.mp3"
local opticStylePath = "%s/style.json"
-- local defaultMedalSize = 70
local playerData = {deaths = 0, kills = 0, noKillSinceDead = false}
local screenWidth = read_word(0x637CF2)
local screenHeight = read_word(0x637CF0)
-- FIXME There should be a better way to scale this, I just did simple math to obtain this value
-- local defaultMedalSize = (screenHeight * 0.065) - 1
local defaultMedalSize = (screenHeight / 15) - 1
local medalsLoaded = false

---@class sprite
---@field name string Name of the image file name of the sprite
---@field width number Width of the sprite image
---@field height number Height of sprite image
---@field renderGroup string Alternative render group for the sprite, medal group by default
---@field hasAudio boolean

--- Create and format paths for sprite images
--- This is helpful to avoid hardcoding sprite absolute paths
local function image(spriteName)
    return imagesPath:format(configuration.style, spriteName)
end

--- Create and format paths for sprite images
-- This is helpful to avoid hardcoding sprite absolute paths
local function audio(spriteName)
    return soundsPath:format(configuration.style, spriteName)
end

local sprites

local function loadOpticStyle()
    local styleFile = read_file(opticStylePath:format(configuration.style))
    if (styleFile) then
        local style = json.decode(styleFile)
        if (style) then
            defaultMedalSize = (screenHeight / style.medalSizeFactor) - 1
            return true
        end
    end
    console_out("Error, Optic style does not have a style.json file!")
    return false
end

local function loadOpticConfiguration()
    dprint("Loading optic configuration...")
    local opticConfiguration = read_file("optic.json")
    if (opticConfiguration) then
        configuration = json.decode(opticConfiguration)
        dprint("Success, configuration loaded correctly.")
        loadOpticStyle()
        return true
    end
    dprint("Warning, unable to load optic configuration.")
    return false
end


function OnScriptLoad()
    loadOpticConfiguration()

    -- Create custom announcer sounds
    optic.create_sound("suicide", audio("suicide"))
    optic.create_sound("betrayal", audio("betrayal"))


    sprites = {
        kill = {name = "normal_kill", width = defaultMedalSize, height = defaultMedalSize},
        doubleKill = {name = "double_kill", width = defaultMedalSize, height = defaultMedalSize},
        tripleKill = {name = "triple_kill", width = defaultMedalSize, height = defaultMedalSize},
        killtacular = {name = "killtacular", width = defaultMedalSize, height = defaultMedalSize},
        killingSpree = {name = "killing_spree", width = defaultMedalSize, height = defaultMedalSize},
        runningRiot = {name = "running_riot", width = defaultMedalSize, height = defaultMedalSize},
        snapshot = {name = "snapshot_kill", width = defaultMedalSize, height = defaultMedalSize},
        closeCall = {name = "close_call", width = defaultMedalSize, height = defaultMedalSize},
        fromTheGrave = {name = "from_the_grave", width = defaultMedalSize, height = defaultMedalSize},
        firstStrike = {name = "first_strike", width = defaultMedalSize, height = defaultMedalSize},
        rocketKill = {name = "rocket_kill", width = defaultMedalSize, height = defaultMedalSize},
        supercombine = {name = "needler_kill", width = defaultMedalSize, height = defaultMedalSize},
        hitmarkerHit = {
            name = "hitmarker",
            width = defaultMedalSize,
            height = defaultMedalSize,
            renderGroup = "crosshair",
            noHudMessage = true
        },
        hitmarkerKill = {
            name = "hitmarker_kill",
            width = defaultMedalSize,
            height = defaultMedalSize,
            renderGroup = "crosshair",
            noHudMessage = true
        }
    }
    -- Create sprites
    for event, sprite in pairs(sprites) do
        if (sprite.name) then
            local medalImagePath = image(sprite.name)
            local medalSoundPath = audio(sprite.name)
            dprint("Loading sprite: " .. sprite.name)
            dprint("Image: " .. medalImagePath)
            if (file_exists(image(sprite.name))) then
                if (file_exists(audio(sprite.name))) then
                    dprint("Sound: " .. medalSoundPath)
                    optic.create_sprite(sprite.name, medalImagePath, sprite.width, sprite.height)
                    optic.create_sound(sprite.name, medalSoundPath)
                    sprites[event].hasAudio = true
                else
                    -- dprint("Warning, there is no sound for this sprite!")
                    optic.create_sprite(sprite.name, medalImagePath, sprite.width, sprite.height)
                end
            end
        end
    end

    -- Fade in animation
    optic.create_animation("fade in", 200)
    optic.set_animation_property("fade in", "ease in", "position x", defaultMedalSize)
    optic.set_animation_property("fade in", "ease in", "opacity", 255)

    -- Fade out animation
    optic.create_animation("fade out", 200)
    optic.set_animation_property("fade out", "ease out", "opacity", -255)

    -- Slide animation
    optic.create_animation("slide", 300)
    optic.set_animation_property("slide", 0.4, 0.0, 0.6, 1.0, "position x", defaultMedalSize)

    -- Create sprites render queue
    optic.create_render_queue("medals", 50, (screenHeight / 2), 255, 0, 4000, 0, "fade in",
                              "fade out", "slide")

    -- Create audio engine instance
    optic.create_audio_engine("medals")

    medalsLoaded = true

    -- Load medals callback
    harmony.set_callback("multiplayer sound", "OnMultiplayerSound")
    harmony.set_callback("multiplayer event", "OnMultiplayerEvent")

    dprint("Medals loaded!")
end

--- Normalize any map name or snake case name to a name with sentence case
---@param name string
local function toSentenceCase(name)
    return string.gsub(" " .. name:gsub("_", " "), "%W%l", string.upper):sub(2)
end

---@param sprite sprite
local function medal(sprite)
    if (medalsLoaded) then
        medalsQueue[#medalsQueue + 1] = sprite.name
        local renderGroup = sprite.renderGroup
        if (renderGroup) then
            -- Crosshair sprite
            optic.render_sprite(sprite.name, (screenWidth - sprites.hitmarkerHit.width) / 2,
                                (screenHeight - sprites.hitmarkerHit.height) / 2, 255, 0, 200)

        else
            optic.render_sprite(sprite.name, "medals")
            if (sprite.hasAudio) then
                optic.play_sound(sprite.name, "medals")
            end
        end
        if (configuration.hudMessages) then
            if (not sprite.name:find("hitmarker")) then
                hud_message(toSentenceCase(sprite.name))
            end                
        end
    else
        console_out("Error, medals were not loaded properly!")
    end
end

function OnMultiplayerSound(eventName)
    dprint("sound: " .. eventName)
    if (eventName == soundsEvents.hitmarker) then
        if (configuration.hitmarker) then
            medal(sprites.hitmarkerHit)
        end
    end
    -- Cancel default sounds that are using medals sounds
    if (eventName:find("kill") or eventName:find("running")) then
        dprint("Cancelling sound...")
        return false
    end
    return true
end

local function isPreviousMedalKillVariation()
    local lastMedal = medalsQueue[#medalsQueue]
    if (lastMedal and lastMedal:find("kill") and lastMedal ~= "normal_kill") then
        medalsQueue[#medalsQueue] = nil
        return true
    end
    return false
end

function OnMultiplayerEvent(eventName, localId, killerId, victimId)
    dprint("event: " .. eventName)
    dprint("localId: " .. tostring(localId))
    dprint("killerId: " .. tostring(killerId))
    dprint("victimId: " .. tostring(victimId))
    if (eventName == events.localKilledPlayer) then
        local player = blam.biped(get_dynamic_player())
        local victim = blam.biped(victimId)
        if (victim) then
            dprint("Victim is alive!")
        end
        if (player) then
            local firstPerson = blam.firstPerson()
            if (firstPerson) then
                local weapon = blam.weapon(get_object(firstPerson.weaponObjectId))
                if (weapon) then
                    local tag = blam.getTag(weapon.tagId)
                    if (tag and blam.isNull(player.vehicleObjectId)) then
                        if (tag.path:find("sniper")) then
                            -- FIXME Check if there is a way to tell how our victim died
                            if (blam.isNull(player.zoomLevel) and player.weaponPTH) then
                                medal(sprites.snapshot)
                            end
                        elseif (tag.path:find("rocket")) then
                            medal(sprites.rocketKill)
                        elseif (tag.path:find("needler")) then
                            medal(sprites.supercombine)
                        end
                    end
                end
            end
            local localPlayer = blam.player(get_player())
            local allServerKills = 0
            for playerIndex = 0, 15 do
                local playerData = blam.player(get_player(playerIndex))
                if (playerData and playerData.index ~= localPlayer.index) then
                    allServerKills = allServerKills + playerData.kills
                end
            end
            dprint("All server kills: " .. allServerKills)
            if (allServerKills == 0 and localPlayer.kills == 1) then
                medal(sprites.firstStrike)
            end
            if (player.health <= 0.25) then
                medal(sprites.closeCall)
            end
            if (not isPreviousMedalKillVariation()) then
                medal(sprites.kill)
            end
            if (configuration.hitmarker) then
                medal(sprites.hitmarkerKill)
            end
        else
            dprint("Player is dead!")
            medal(sprites.fromTheGrave)
        end
    elseif (eventName == events.localDoubleKill) then
        medal(sprites.doubleKill)
    elseif (eventName == events.localTripleKill) then
        medal(sprites.tripleKill)
    elseif (eventName == events.localKilltacular) then
        medal(sprites.killtacular)
    elseif (eventName == events.localKillingSpree) then
        medal(sprites.killingSpree)
    elseif (eventName == events.localRunningRiot) then
        medal(sprites.runningRiot)
    elseif (eventName == events.suicide) then
        optic.play_sound("suicide", "medals")
    end
end

function OnCommand(command)
    if (command == "optic_test" or command == "otest") then
        medal(sprites.firstStrike)
        medal(sprites.runningRiot)
        medal(sprites.doubleKill)
        medal(sprites.killtacular)
        if (configuration.hitmarker) then
            medal(sprites.hitmarkerHit)
        end
        return false
    elseif (command == "optic_debug" or command == "odebug") then
        DebugMode = not DebugMode
        console_out("Debug Mode: " .. tostring(DebugMode))
        return false
    elseif (command == "optic_version" or command == "oversion") then
        console_out(opticVersion)
        return false
    elseif (command == "optic_reload"  or command == "oreload") then
        loadOpticConfiguration()
        return false
    end
end

function OnMapLoad()
    loadOpticConfiguration()
    if (not medalsLoaded) then
        console_out("Error, medals were not loaded properly!")
    end
end

set_callback("command", "OnCommand")
set_callback("map load", "OnMapLoad")

OnScriptLoad()

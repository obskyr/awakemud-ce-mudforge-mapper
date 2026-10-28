plugin = {
  name        = "AwakeMUD CE Mapper",
  version     = "0.1.1-dev",
  author      = "Molly Memories",
  description = "Make MudForge’s built-in map widget compatible with the venerable AwakeMUD CE."
}


-- ------------------------------- -- Data -- ------------------------------ --

local DOOR_FLAG_GMCP_TO_MUDFORGE = {
    LOCKED = 3,
    CLOSED = 2,
    OPEN   = 1
}


local IGNORE_EXITS_TO_AND_FROM = {
    [600] = true  -- The taxi cab.
}


-- TODO: Lots to add here.
-- TODO: Add default icons for new tags.
-- At the time of writing, MudForge’s tags are coerced to the lower case.
local REGEX_TO_FLAG = {
    ['^...(?:he|she|they) might have a job for you.']                               = 'johnson',
    ['^...See HELP ATM for details.$']                                              = 'atm',
    ['^...(?:(?:he|she) looks|they look) willing to help you practice your skills'] = 'teacher',
    ['^[\\w\' ]+ \\(Treacherous\\)$']                                               = 'treacherous'
}


-- ----------------------------- -- Program -- ----------------------------- --

local updateOrAddRoom
local populateRoom

-- At the time of writing, `getPlayerRoom()` doesn’t work properly.
-- This is something I’ve noticed about MudForge: It being AI-assisted
-- in its development, it has an *incredibly* large feature set, but, er…
-- things don’t always work very *well,* since they weren’t tested
-- properly or developed with enough intention. What a world.
CurrentPlayerRoomNum = nil

-- Total assumption. No way to check, at the time of writing.
-- It doesn’t even show up in `getWidgetSettings()`.
MapWidgetIsProbablyOpen = true


onMapReady(function()
    -- `getPlayerRoom()` *is,* however, set to your starting room, at least.
    -- …It seems.
    CurrentPlayerRoomNum = getPlayerRoom()

    -- This way, we get a semi-accurate guess as to whether the player
    -- has the map widget open or not from the very start, potentially
    -- avoiding a superfluous warning. (See issue #1.)
    getMapView(function(result)
        MapWidgetIsProbablyOpen = result.success
    end)
end)


onGMCPUpdate('Room.Info', function(gmcpRoomInfo)
    CurrentPlayerRoomNum = gmcpRoomInfo.vnum

    local formattedDescription = string.trim(gmcpRoomInfo.description)
    -- Might be a bit of a naïve text unwrap, but. Eh.
    -- (At the time of writing, MudForge removes newlines in room details either way.)
    formattedDescription = string.gsub(formattedDescription, '([^\r\n])\r\n[ \t]+([^\r\n])', '%1\r\n\r\n%2')
    formattedDescription = string.gsub(formattedDescription, '([^\r\n])\r\n([^\r\n])', '%1 %2')

    -- TODO: At the time of writing, terrain and area are not provided via GMCP.
    --       Thus, setting those is only really feasible by fetching and parsing
    --       the MUD’s source code, which I’d rather not do. We’ll see, though.
    local fields = {
        name = gmcpRoomInfo.name,
        details = formattedDescription
    }

    -- At the time of writing, using `addMapRoom` or `mergeMapRooms` causes
    -- the map layout to break. Instead, we prefer to rely on the map widget’s
    -- automatic room adding, but unfortunately, that means `updateMapRoom`
    -- prints an unsuppressable warning.
    -- (Using `addMapRoom` still results in a correct *graph,* but since it
    -- causes visual issues, it’s preferable to get a warning.)
    if roomExists(gmcpRoomInfo.vnum) then
        -- `updateMapRoom` will always work if the room already exists,
        -- regardless of whether the map widget is open or not.
        updateMapRoom(gmcpRoomInfo.vnum, fields)
        populateRoom(gmcpRoomInfo)
    else
        if MapWidgetIsProbablyOpen then
            updateOrAddRoom(gmcpRoomInfo, fields)
            populateRoom(gmcpRoomInfo)
        else
            -- To avoid visual glitches, we should only use `addMapRoom` when
            -- the map widget is closed. To check whether it truly is closed,
            -- we use a method with a callback that tells us.
            -- (This callback may take a few seconds to fire, however, so
            -- we shouldn’t always use it.)
            getMapView(function(result)
                if result.success then
                    MapWidgetIsProbablyOpen = true
                else
                    addMapRoom(gmcpRoomInfo.vnum, fields)
                end
                populateRoom(gmcpRoomInfo)
            end)
        end
    end
end)


function updateOrAddRoom(gmcpRoomInfo, fields)
    if not updateMapRoom(gmcpRoomInfo.vnum, fields) then
        echo("NOTE: At the time of writing (MudForge v2.0.4575), the above warning is\n      impossible to avoid. When you next open the map widget, MudForge will\n      have placed at least one room wrong. Run `mapper relayout confirm` then\n      to improve it.\n      See: https://github.com/obskyr/awakemud-ce-mudforge-mapper/issues/1", "yellow")
        addMapRoom(gmcpRoomInfo.vnum, fields)
        MapWidgetIsProbablyOpen = false
    end
end


function populateRoom(gmcpRoomInfo)
    for _, flag in ipairs(gmcpRoomInfo.flags) do
        setRoomFlag(gmcpRoomInfo.vnum, flag, true)
    end

    -- TODO: Set the other side of a locked or closed door, probably.
    for _, exit in ipairs(gmcpRoomInfo.exits) do
        if not IGNORE_EXITS_TO_AND_FROM[exit.to] then
            setMapExit(gmcpRoomInfo.vnum, exit.direction, exit.to)
            local doorStateFlag = DOOR_FLAG_GMCP_TO_MUDFORGE[exit.state]
            if exit.state ~= 'OPEN' and doorStateFlag > getDoors(gmcpRoomInfo.vnum)[exit.direction] then
                setDoor(gmcpRoomInfo.vnum, exit.direction, doorStateFlag)
            end
        end
    end
end


for regex, flag in pairs(REGEX_TO_FLAG) do
    addTrigger(regex, function()
        -- We shouldn’t need to check if `CurrentPlayerRoomNum` is nil or not here,
        -- since we set it in `onMapReady`, but let’s be safe.
        if CurrentPlayerRoomNum then
            setRoomFlag(CurrentPlayerRoomNum, flag, true)
        end
    end, {type = 'regex'})
end

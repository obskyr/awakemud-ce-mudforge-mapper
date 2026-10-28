plugin = {
  name        = "AwakeMUD CE Mapper",
  version     = "0.1.0-dev",
  author      = "Molly Memories",
  description = "Make MudForge’s built-in map widget compatible with the venerable AwakeMUD CE."
}


-- ------------------------------- -- Data -- ------------------------------ --

local DOOR_FLAG_GCMP_TO_MUDFORGE = {
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
    ['^[\w\' ]+ \(Treacherous\)$']                                                  = 'treacherous'
}


-- ----------------------------- -- Program -- ----------------------------- --

-- At the time of writing, `getPlayerRoom()` doesn’t work properly.
-- This is something I’ve noticed about MudForge: It being AI-assisted
-- in its development, it has an *incredibly* large feature set, but, er…
-- things don’t always work very *well,* since they weren’t tested
-- properly or developed with enough intention. What a world.
currentPlayerRoomVnum = nil


-- `getPlayerRoom()` *is,* however, set to your starting room, at least.
-- …It seems.
onMapReady(function()
    currentPlayerRoomVnum = getPlayerRoom()
end)


onGMCPUpdate('Room.Info', function(room)
    currentPlayerRoomVnum = room.vnum

    local formattedDescription = string.trim(room.description)
    -- Might be a bit of a naïve text unwrap, but. Eh.
    -- (At the time of writing, MudForge removes newlines in room details either way.)
    formattedDescription = string.gsub(formattedDescription, '([^\r\n])\r\n[ \t]+([^\r\n])', '%1\r\n\r\n%2')
    formattedDescription = string.gsub(formattedDescription, '([^\r\n])\r\n([^\r\n])', '%1 %2')
    -- TODO: At the time of writing, terrain and area are not provided via GMCP.
    --       Thus, setting those is only really feasible by fetching and parsing
    --       the MUD’s source code, which I’d rather not do. We’ll see, though.
    local fields = {
        name = room.name,
        details = formattedDescription
    }
    -- I ran into major buggage trying to use `addMapRoom`.
    -- Instead, we’re letting the automatic feature of the map widget
    -- add us to the map.
    updateMapRoom(room.vnum, fields)

    for _, flag in ipairs(room.flags) do
        setRoomFlag(room.vnum, flag, true)
    end

    -- TODO: Set the other side of a locked or closed door, probably.
    for _, exit in ipairs(room.exits) do
        if not IGNORE_EXITS_TO_AND_FROM[exit.to] then
            setMapExit(room.vnum, exit.direction, exit.to)
            local doorStateFlag = DOOR_FLAG_GCMP_TO_MUDFORGE[exit.state]
            if exit.state ~= 'OPEN' and doorStateFlag > getDoors(room.vnum)[exit.direction] then
                setDoor(room.vnum, exit.direction, doorStateFlag)
            end
        end
    end
end)


for regex, flag in pairs(REGEX_TO_FLAG) do
    addTrigger(regex, function()
        -- We shouldn’t need to check if `currentPlayerRoomVnum` is nil or not here,
        -- since we set it in `onMapReady`, but let’s be safe.
        if currentPlayerRoomVnum then
            setRoomFlag(currentPlayerRoomVnum, flag, true)
        end
    end, {type = 'regex'})
end

_addon.name = 'pathlog'
_addon.author = 'Duke'
_addon.version = '2.0'
_addon.commands = {'pathlog', 'pl'}

resources = require('resources')
config = require('config')
packets = require('packets')
files = require('files')
require('strings')
require('lists')
require('tables')

defaults = {}
defaults.messageColor = 219
defaults.logPath = false
defaults.mode = 'target'
defaults.filter = 'rot'
defaults.TimestampFormat = '-- %H:%M:%S'
defaults.logRot = false
defaults.AddTimestamp = true
defaults.pauseLegs = true
defaults.tableEachPoint = false
defaults.defineCoordinates = false
defaults.all = false
defaults.cumulativeDiff = 5
defaults.xDiff = 3
defaults.yDiff = 0.5
defaults.zDiff = 3
defaults.rotDiff = 0
defaults.timeDiff = 4

settings = config.load(defaults)

local pathlog = {}
pathlog.trackList = L{}
pathlog.ghostLog = T{}

local logType =
{
    npcByTarget  = 1,
    npcByList    = 2,
    selfByTarget = 3,
    firstPoint   = 4,
    lastPoint    = 5,
    closeBracket = 6,
}

windower.register_event('load', 'login', 'logout', function()
    pathlog.logged_in = windower.ffxi.get_info().logged_in
    pathlog.zone = pathlog.logged_in and resources.zones[windower.ffxi.get_info().zone].name
    pathlog.player = pathlog.logged_in and windower.ffxi.get_player()
    pathlog.playerID = pathlog.logged_in and pathlog.player.id
    pathlog.playerName = pathlog.logged_in and pathlog.player.name
end)

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
    if not settings.logPath or not id == 0x0E or not pathlog.logged_in then return end

    local packet = packets.parse('incoming', data)
    local npc = {}
    local pos = {}

    npc.index = packet['Index']
    npc.id = packet['NPC']
    npc.look = packet['look']
    npc.polutils = packet['polutils_name']

    if pathlog.willScan(npc.look, npc.polutils) and npc.id then
        walkCount = packet['Walk Count'] -- not currently in use
        pos.x = packet['X']
        pos.y = packet['Z'] -- Windower has Z and Y axis swapped
        pos.z = packet['Y']
        pos.rot = packet['Rotation']
        pos.time = os.time()

        if settings.mode == 'target' then
            --pathlog.logToFile(logType.npcByTarget, npc.id, pos.x, pos.y, pos.z, pos.rot, pos.time)
            pathlog.logNpcByTarget(npc.id, pos.x, pos.y, pos.z, pos.rot, pos.time)
        elseif settings.mode == 'list' then
            --pathlog.logToFile(logType.npcByList, npc.id, pos.x, pos.y, pos.z, pos.rot, pos.time)
            pathlog.logNpcByList(npc.id, pos.x, pos.y, pos.z, pos.rot, pos.time)
        end
    end
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    if settings.logPath and settings.mode == 'target' and id == 0x015 and pathlog.logged_in then
        --pathlog.logToFile(logType.selfByTarget)
        pathlog.logSelfByTarget()
    end
end)

windower.register_event('target change', function(index)
    if settings.logPath and settings.mode == 'target' and #pathlog.ghostLog > 0 and pathlog.logged_in then
        local ghostLog = pathlog.ghostLog
        local isFirst = false
        local isFinal = true

        for entry = #ghostLog, 1, -1 do
            local id = tonumber(ghostLog[entry][1])
            local lastX, lastY, lastZ, lastRot, lastTime = getLastPosByID(id)

            pathlog.logFirstOrFinalPoint(isFirst, isFinal, id, lastX, lastY, lastZ, lastRot, lastTime)
            break
        end

        ghostLog:clear()
    end
end)

windower.register_event('zone change', function(new)
    pathlog.zone = resources.zones[new].name
    pathlog.trackList:clear()
    pathlog.ghostLog:clear()
end)

pathlog.padCoords = function(coord, isY, isRot)
    local padding = 8

    if isY then
        padding = padding - 1
    end

    if isRot then
        padding = padding - 3
    end

    return string.rep(' ', padding - #coord) .. coord
end

--[[function pathlog.logSetup(path, data)
    data = data or {}
    data.logFile = get_log_file_handle(path)
    data.player = data.player or windower.ffxi.get_player()
    data.target = data.target or windower.ffxi.get_mob_by_target('t')
    data.targetByID = data.targetByID or windower.ffxi.get_mob_by_id(data.targetID)
    data.me = data.me or windower.ffxi.get_mob_by_target('me')
    data.playerName = data.player.name or data.player.name
    data.targetName = data.target.name or data.target.name
    data.id = data.target.id or data.target.id
    data.index = data.target.index or data.target.index
    data.timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
    data.openBracket = settings.tableEachPoint and '{ ' or ''
    data.closeBracket = settings.tableEachPoint and ' },' or ''
    data.defineX = settings.defineCoordinates and 'x = ' or ''
    data.defineY = settings.defineCoordinates and 'y = ' or ''
    data.defineZ = settings.defineCoordinates and 'z = ' or ''
    data.x = data.target and data.target.x
    data.y = data.target and data.target.z -- Windower has Z and Y axis swapped
    data.z = data.target and data.target.y
    data.defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
    data.logRot = settings.logRot and rot or ''
    data.time = data.time or os.time()
    data.zone = data.zone or pathlog.zone
end]]

function pathlog.logToFile(type, logFile, npcID, x, y, z, rot, time)
    if not type or not logFile or not npcID then return end

    local player = pathlog.player
    local target = windower.ffxi.get_mob_by_target('t')
    local zone = pathlog.zone

    if target and npcID == target.id then
        local playerName = pathlog.playerName
        local playerID = pathlog.playerID
        local targetName = target.name
        local id = target.id
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'/'..id..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' },' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''
        local defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
        local logRot = settings.logRot and rot or ''

        if not logFile:exists() then
            logFile:create()
        end

        if pathlog.shouldLogPoint(logFile, npcID, x, y, z, rot, time) then
            x = pathlog.padCoords(string.format('%.3f', x))
            y = pathlog.padCoords(string.format('%.3f', y), true)
            z = pathlog.padCoords(string.format('%.3f', z))
            rot = pathlog.padCoords(string.format('%i,', rot), false, true)
            logRot = settings.logRot and rot or ''

            if type == logType.npcByTarget then
                logFile:append(string.format('    %s%s%s, %s%s, %s%s,%s%s%s    %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
            elseif type == logType.npcByList then
            elseif type == logType.selfByTarget then
            elseif type == logType.firstPoint then
                logFile:append(string.format('{\n    %s%s%s, %s%s, %s%s,%s%s%s    %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
            elseif type == logType.lastPoint then
                logFile:append(string.format('    %s%s%s, %s%s, %s%s,%s%s%s    %s\n},\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
            elseif type == logType.closeBracket then
                logFile:append(string.format('},\n'))
            end
        end
    end
end

function pathlog.logNpcByTarget(npcID, x, y, z, rot, time)
    local player = pathlog.player
    local target = windower.ffxi.get_mob_by_target('t')
    local zone = pathlog.zone

    if target and npcID == target.id then
        local playerName = player.name
        local targetName = target.name
        local id = target.id
        local index = target.index
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'/'..id..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' },' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''
        local defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
        local logRot = settings.logRot and rot or ''

        if not logFile:exists() then
            logFile:create()
        end

        if pathlog.shouldLogPoint(logFile, npcID, x, y, z, rot, time) then
            local x = string.format('%.3f', x)
            local y = string.format('%.3f', y)
            local z = string.format('%.3f', z)
            local rot = string.format('%i,', rot)

            x = pathlog.padCoords(x)
            y = pathlog.padCoords(y, true)
            z = pathlog.padCoords(z)
            rot = pathlog.padCoords(rot, false, true)
            logRot = settings.logRot and rot or ''

            logFile:append(string.format('    %s%s%s, %s%s, %s%s,%s%s%s    %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
        end
    end
end

function pathlog.logNpcByList(npcID, x, y, z, rot, time)
    local player = windower.ffxi.get_player()
    local zone = pathlog.zone
    local trackList = pathlog.trackList

    if #trackList <= 0 then return end

    for entry = 1, #trackList do
        local listID = trackList[entry]
        local target = windower.ffxi.get_mob_by_id(listID)

        if target and npcID == target.id then
            local playerName = player.name
            local targetName = target.name
            local id = target.id
            local index = target.index
            local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'/'..id..'.log')
            local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
            local openBracket = settings.tableEachPoint and '{ ' or ''
            local closeBracket = settings.tableEachPoint and ' },' or ''
            local defineX = settings.defineCoordinates and 'x = ' or ''
            local defineY = settings.defineCoordinates and 'y = ' or ''
            local defineZ = settings.defineCoordinates and 'z = ' or ''
            local defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
            local logRot = settings.logRot and rot or ''

            if not logFile:exists() then
                logFile:create()
            end

            if pathlog.shouldLogPoint(logFile, npcID, x, y, z, rot, time) then
                local x = string.format('%.3f', x)
                local y = string.format('%.3f', y)
                local z = string.format('%.3f', z)
                local rot = string.format('%i,', rot)

                x = pathlog.padCoords(x)
                y = pathlog.padCoords(y, true)
                z = pathlog.padCoords(z)
                rot = pathlog.padCoords(rot, false, true)
                logRot = settings.logRot and rot or ''

                logFile:append(string.format('    %s%s%s, %s%s, %s%s,%s%s%s    %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
            end
        end
    end
end

function pathlog.logSelfByTarget()
    local player = windower.ffxi.get_player()
    local me = windower.ffxi.get_mob_by_target('me')
    local target = windower.ffxi.get_mob_by_target('t')
    local zone = pathlog.zone

    if target and target.index == player.index then
        local playerName = player.name
        local targetName = target.name
        local ID = target.id
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' },' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''
        local x = target.x
        local y = target.z -- Windower has Z and Y axis swapped
        local z = target.y
        local rot = headingToByteRotation(me.heading)
        local time = os.time()
        local defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
        local logRot

        if not logFile:exists() then
            logFile:create()
        end

        if pathlog.shouldLogPoint(logFile, ID, x, y, z, rot, time) then
            local x = string.format('%.3f', x)
            local y = string.format('%.3f', y)
            local z = string.format('%.3f', z)
            local rot = string.format('%i,', rot)

            x = pathlog.padCoords(x)
            y = pathlog.padCoords(y, true)
            z = pathlog.padCoords(z)
            rot = pathlog.padCoords(rot, false, true)
            logRot = settings.logRot and rot or ''

            logFile:append(string.format('    %s%s%s, %s%s, %s%s,%s%s%s    %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
        end
    end
end

function pathlog.logPointWithComment(comment)
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_target('me')
    local zone = pathlog.zone

    if target then
        local playerName = player.name
        local targetName = target.name
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' },' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''
        local x = string.format('%.3f', target.x)
        local y = string.format('%.3f', target.z) -- Windower has Z and Y axis swapped
        local z = string.format('%.3f', target.y)
        local rot = string.format('%i,', headingToByteRotation(target.heading))
        local defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
        local logRot

        if not comment then
            comment = ''
        else
            comment = table.sconcat(comment)
        end

        if not logFile:exists() then
            logFile:create()
        end

        x = pathlog.padCoords(x)
        y = pathlog.padCoords(y, true)
        z = pathlog.padCoords(z)
        rot = pathlog.padCoords(rot, false, true)
        logRot = settings.logRot and rot or ''

        logFile:append(string.format('%s%s%s, %s%s, %s%s,%s%s%s   %s    -- %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp, comment))
    end
end

function pathlog.logFirstOrFinalPoint(isFirst, isFinal, npcID, x, y, z, rot, time)
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_id(npcID)
    local zone = pathlog.zone

    if target and npcID ~= player.id then
        local playerName = player.name
        local targetName = target.name
        local id = target.id
        local index = target.index
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'/'..id..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, time) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' },' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''
        local defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
        local logRot
        local x = string.format('%.3f', x)
        local y = string.format('%.3f', y)
        local z = string.format('%.3f', z)
        local rot = string.format('%i,', rot)

        x = pathlog.padCoords(x)
        y = pathlog.padCoords(y, true)
        z = pathlog.padCoords(z)
        rot = pathlog.padCoords(rot, false, true)
        logRot = settings.logRot and rot or ''

        if isFirst then
            logFile:append(string.format('{\n    %s%s%s, %s%s, %s%s,%s%s%s    %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
        elseif isFinal then
            logFile:append(string.format('    %s%s%s, %s%s, %s%s,%s%s%s    %s\n},\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
        end

    elseif target and player.id == npcID then
        local playerName = player.name
        local ID = target.id
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..playerName..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, time) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' },' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''
        local x = target.x
        local y = target.z -- Windower has Z and Y axis swapped
        local z = target.y
        local rot = headingToByteRotation(target.heading)
        local defineRot = settings.defineCoordinates and settings.logRot and ' rot =' or ''
        local logRot
        local x = string.format('%.3f', x)
        local y = string.format('%.3f', y)
        local z = string.format('%.3f', z)
        local rot = string.format('%i,', rot)

        x = pathlog.padCoords(x)
        y = pathlog.padCoords(y, true)
        z = pathlog.padCoords(z)
        rot = pathlog.padCoords(rot, false, true)
        logRot = settings.logRot and rot or ''

        if isFirst then
            logFile:append(string.format('{\n    %s%s%s, %s%s, %s%s,%s%s%s    %s\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
        elseif isFinal then
            logFile:append(string.format('    %s%s%s, %s%s, %s%s,%s%s%s    %s\n},\n', openBracket, defineX, x, defineY, y, defineZ, z, defineRot, logRot, closeBracket, timestamp))
        end
    end
end

function pathlog.closeBracketOnly(npcID)
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_id(npcID)
    local zone = pathlog.zone

    if target and npcID ~= player.id then
        local playerName = player.name
        local targetName = target.name
        local id = target.id
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'/'..id..'.log')

        logFile:append(string.format('},\n'))
    elseif target and player.id == npcID then
        local playerName = player.name
        local ID = target.id
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..playerName..'.log')

        logFile:append(string.format('},\n'))
    end
end

function pathlog.shouldLogPoint(logFile, npcID, x, y, z, rot, time)
    local lastLoggedX, lastLoggedY, lastLoggedZ, lastLoggedRot, lastLoggedTime = getLastLoggedPosByID(npcID)
    local lastX, lastY, lastZ, lastRot, lastTime = getLastPosByID(npcID)

    if x == 0 and y == 0 and z == 0 then
        return false
    end

    if not lastLoggedX or not lastLoggedY or not lastLoggedZ or not lastLoggedRot then
        local isFirst = true
        local isFinal = false

        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))
        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))
        pathlog.logFirstOrFinalPoint(isFirst, isFinal, npcID, x, y, z, rot, time)
        return false
    end

    local xDiff = tonumber(string.format('%.3f', math.abs(lastLoggedX - x)))
    local yDiff = tonumber(string.format('%.3f', math.abs(lastLoggedY - y)))
    local zDiff = tonumber(string.format('%.3f', math.abs(lastLoggedZ - z)))
    local cumulativeDiff = xDiff + yDiff + zDiff
    local rotDiff = math.abs(lastLoggedRot - rot)
    local timeDiff = math.abs(lastTime - time)

    if timeDiff >= settings.timeDiff and settings.pauseLegs and settings.mode == 'list' and #pathlog.ghostLog > 0 then
        local logLastX = math.abs(lastLoggedX - lastX)
        local logLastY = math.abs(lastLoggedY - lastY)
        local logLastZ = math.abs(lastLoggedZ - lastZ)
        local logLastRot = math.abs(lastLoggedRot - lastRot)

        if logLastX < 1 and logLastY < 1 and logLastZ < 1 and logLastRot < 1 then
            pathlog.closeBracketOnly(npcID)
        else
            pathlog.logFirstOrFinalPoint(false, true, npcID, lastX, lastY, lastZ, lastRot, lastTime)
        end

        pathlog.logFirstOrFinalPoint(true, false, npcID, x, y, z, rot, time)

        for entry = #pathlog.ghostLog, 1, -1 do
            if npcID == tonumber(pathlog.ghostLog[entry][1]) then
                pathlog.ghostLog:delete(pathlog.ghostLog[entry])
            end
        end

        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))
        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))

        return false
    end

    if settings.all then
        return true
    end

    if settings.filter == 'rot' and  #pathlog.ghostLog > 0 and (yDiff >= settings.yDiff or rotDiff > settings.rotDiff) then
        for entry = #pathlog.ghostLog, 1, -1 do
            if npcID == tonumber(pathlog.ghostLog[entry][1]) then
                pathlog.ghostLog:delete(pathlog.ghostLog[entry])
            end
        end

        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))
        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))

        return true
    elseif settings.filter == 'xyz' and #pathlog.ghostLog > 0 and (cumulativeDiff >= settings.cumulativeDiff or xDiff >= settings.xDiff or yDiff >= settings.yDiff or zDiff >= settings.zDiff) then
        for entry = #pathlog.ghostLog, 1, -1 do
            if npcID == tonumber(pathlog.ghostLog[entry][1]) then
                pathlog.ghostLog:delete(pathlog.ghostLog[entry])
            end
        end

        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))
        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))

        return true
    end

    if #pathlog.ghostLog > 0 then
        for entry = #pathlog.ghostLog, 1, -1 do
            if npcID == tonumber(pathlog.ghostLog[entry][1]) then
                pathlog.ghostLog:delete(pathlog.ghostLog[entry])
                break
            end
        end

        pathlog.ghostLog:append(string.format(npcID..','..x..','..y..','..z..','..rot..','..time):split(','))

        return false
    end
end

function getLastLoggedPosByID(id)
    local ghostLog = pathlog.ghostLog

    if #ghostLog <= 0 then return end
    for entry = 1, #ghostLog do
        if ghostLog[entry][1] == tostring(id) then
            return tonumber(ghostLog[entry][2]), tonumber(ghostLog[entry][3]), tonumber(ghostLog[entry][4]), tonumber(ghostLog[entry][5]), tonumber(ghostLog[entry][6])
        end
    end
end

function getLastPosByID(id)
    local ghostLog = pathlog.ghostLog

    if #ghostLog <= 0 then return end
    for entry = #ghostLog, 1, -1 do
        if ghostLog[entry][1] == tostring(id) then
            return tonumber(ghostLog[entry][2]), tonumber(ghostLog[entry][3]), tonumber(ghostLog[entry][4]), tonumber(ghostLog[entry][5]), tonumber(ghostLog[entry][6])
        end
    end
end

function headingToByteRotation(oldHeading)
    local newHeading = oldHeading

    if newHeading < 0 then
        newHeading = (math.pi * 2) - (newHeading * -1)
    end

    return math.round((newHeading / (math.pi * 2)) * 256)
end

function pathlog.willScan(look, polutils)
    if look == '00003400' or polutils == 'NPC' then
        return false
    end
    return true
end

local commands = {}

commands.start = function()
    settings.logPath = true
    windower.add_to_chat(settings.messageColor, 'Path logging ON')
end

commands.st = function()
    return commands.start()
end

commands.stop = function()
    local ghostLog = pathlog.ghostLog
    local trackList = pathlog.trackList

    if settings.mode == 'list' then
        for entry = 1, #trackList do
            local id = tonumber(trackList[entry])

            if #ghostLog > 0 then
                local isFirst = false
                local isFinal = true
                local lastX, lastY, lastZ, lastRot, lastTime = getLastPosByID(id)

                if lastX and lastY and lastZ then
                    pathlog.logFirstOrFinalPoint(isFirst, isFinal, id, lastX, lastY, lastZ, lastRot, lastTime)
                end

                for entry = #ghostLog, 1, -1 do
                    if id == tonumber(ghostLog[entry][1]) then
                        ghostLog:delete(ghostLog[entry])
                    end
                end
            end
        end
    elseif settings.mode == 'target' and #ghostLog > 0 then
        local isFirst = false
        local isFinal = true

        for entry = #ghostLog, 1, -1 do
            local id = tonumber(ghostLog[entry][1])
            local lastX, lastY, lastZ, lastRot, lastTime = getLastPosByID(tonumber(id))

            pathlog.logFirstOrFinalPoint(isFirst, isFinal, id, lastX, lastY, lastZ, lastRot, lastTime)
            break
        end
        ghostLog:clear()
    end

    settings.logPath = false
    windower.add_to_chat(settings.messageColor, 'Path logging OFF')
end

commands.sp = function()
    return commands.stop()
end

commands.mode = function(args)
    local newMode = args:remove(1)

    if newMode == 't' then
        newMode = 'target'
    elseif newMode == 'l' then
        newMode = 'list'
    end

    if newMode == 'target' or newMode == 'list' then
        settings.mode = newMode
        windower.add_to_chat(settings.messageColor, 'Pathlog mode: '..settings.mode)
    else
        commands.help()
    end

    settings:save()
end

commands.m = function(args)
    return commands.mode(args)
end

commands.filter = function(args)
    local newFilter = args:remove(1)

    if newFilter == 'r' then
        newFilter = 'rot'
    end

    if newFilter == 'xyz' or newFilter == 'rot' then
        settings.filter = newFilter
        windower.add_to_chat(settings.messageColor, 'Pathlog filter: '..settings.filter)
    else
        commands.help()
    end

    settings:save()
end

commands.f = function(args)
    return commands.filter(args)
end

commands.list = function(args)
    local option = args:remove(1)
    local id = tonumber(args:concat(' '))
    local target = windower.ffxi.get_mob_by_target('t')
    local player = windower.ffxi.get_mob_by_target('me')

    if option == 'show' or option == 's' then
        local trackList = pathlog.trackList

        if #trackList > 0 then
            windower.add_to_chat(settings.messageColor, 'Pathlog Tracklist:')

            for entry = 1, #trackList do
                windower.add_to_chat(settings.messageColor, ''..trackList[entry])
            end
        else
            windower.add_to_chat(settings.messageColor, 'Pathlog Tracklist is Empty')
        end

        return
    end

    if id then -- Look for explicitly desired ID first
        if type(id) ~= 'number' or id == player.id then -- Make sure its a not players id number
            commands.help()
            return
        end
    elseif not id then -- Look for cursor target next
        if target then
            if target.name == player.name or target.index == player.index then
                windower.add_to_chat(settings.messageColor, 'Cannot target player in list mode. Switch to target mode to log player path')
            else
                id = target.id
            end
        end
    else
        commands.help()
        return
    end

    if option == 'add' or option == 'a' then
        if id and not pathlog.trackList:contains(id) then
            pathlog.trackList:append(id)
            windower.add_to_chat(settings.messageColor, 'Added '..id.. ' to tracking list. ')
        else
            windower.add_to_chat(settings.messageColor, 'Must provivde an ID or target an entity to add to tracking list.')
        end
    elseif option == 'remove' or option == 'r' then
        if id and pathlog.trackList:contains(id) then
            if settings.logPath then -- if removing an id while logging, log the last point and remove entries from ghost log
                local ghostLog = pathlog.ghostLog

                if #ghostLog > 0 then
                    local isFirst = false
                    local isFinal = true
                    local lastX, lastY, lastZ, lastRot, lastTime = getLastPosByID(id)

                    if lastX and lastY and lastZ then
                        pathlog.logFirstOrFinalPoint(isFirst, isFinal, id, lastX, lastY, lastZ, lastRot, lastTime)
                    end

                    for entry = #ghostLog, 1, -1 do
                        if id == tonumber(ghostLog[entry][1]) then
                            ghostLog:delete(ghostLog[entry])
                        end
                    end
                end
            end

            pathlog.trackList:remove(entry)

            windower.add_to_chat(settings.messageColor, 'Removed '..id.. ' from tracking list. ')
        else
            windower.add_to_chat(settings.messageColor, 'Must provivde an ID or target an entity to remove from tracking list.')
        end
    elseif option == 'clear' or option == 'c' then
        if not pathlog.trackList:empty() then
            pathlog.trackList:clear()
            windower.add_to_chat(settings.messageColor, 'Cleared tracking list! ')
        else
            windower.add_to_chat(settings.messageColor, 'Trackling list is empty.')
        end
    else
        commands.help()
        return
    end
end

commands.l = function(args)
    return commands.list(args)
end

commands.all = function()
    if settings.all == true then
        settings.all = false
        windower.add_to_chat(settings.messageColor, 'Log all = FALSE')
    elseif settings.all == false then
        settings.all = true
        windower.add_to_chat(settings.messageColor, 'Log all = TRUE')
    end

    settings:save()
end

commands.a = function()
    return commands.all()
end

commands.diff = function(args)
    local option = args:remove(1)
    local value = tonumber(args:concat(' '))

    if option == 'cumulative' or option == 'c' then
        settings.cumulativeDiff = value
        windower.add_to_chat(settings.messageColor, 'Cumulative Diff = '..settings.cumulativeDiff)
    elseif option == 'x' then
        settings.xDiff = value
        windower.add_to_chat(settings.messageColor, 'x Diff = '..settings.xDiff)
    elseif option == 'y' then
        settings.yDiff = value
        windower.add_to_chat(settings.messageColor, 'y Diff = '..settings.yDiff)
    elseif option == 'z' then
        settings.zDiff = value
        windower.add_to_chat(settings.messageColor, 'z Diff = '..settings.zDiff)
    elseif option == 'rot' then
        settings.rotDiff = value
        windower.add_to_chat(settings.messageColor, 'rot Diff = '..settings.rotDiff)
    elseif option == 'time' or option == 't' then
        settings.timeDiff = value
        windower.add_to_chat(settings.messageColor, 'time Diff = '..settings.timeDiff)
    else
        windower.add_to_chat(settings.messageColor, 'Valid arguments are cumulative(c), x, y, z, or rot followed by a number')
        return
    end

    settings:save()
end

commands.d = function(args)
    return commands.diff(args)
end

commands.timestamp = function()
    if settings.AddTimestamp == true then
        settings.AddTimestamp = false
        windower.add_to_chat(settings.messageColor, 'Add timestamp to logs = FALSE')
    elseif settings.AddTimestamp == false then
        settings.AddTimestamp = true
        windower.add_to_chat(settings.messageColor, 'Add timestamp to logs = TRUE')
    end

    settings:save()
end

commands.ts = function()
    return commands.timestamp()
end

commands.rot = function()
    if settings.logRot == true then
        settings.logRot = false
        windower.add_to_chat(settings.messageColor, 'Add rot to logs = FALSE')
    elseif settings.logRot == false then
        settings.logRot = true
        windower.add_to_chat(settings.messageColor, 'Add rot to logs = TRUE')
    end

    settings:save()
end

commands.r = function()
    return commands.rot()
end

commands.tablepoints = function()
    if settings.tableEachPoint == true then
        settings.tableEachPoint = false
        windower.add_to_chat(settings.messageColor, 'Table each point = FALSE')
    elseif settings.tableEachPoint == false then
        settings.tableEachPoint = true
        windower.add_to_chat(settings.messageColor, 'Table each point = TRUE')
    end

    settings:save()
end

commands.tp = function()
    return commands.tablepoints()
end

commands.definecoordinates = function()
    if settings.defineCoordinates == true then
        settings.defineCoordinates = false
        windower.add_to_chat(settings.messageColor, 'Define coordinates = FALSE')
    elseif settings.defineCoordinates == false then
        settings.defineCoordinates = true
        windower.add_to_chat(settings.messageColor, 'Define coordinates = TRUE')
    end

    settings:save()
end

commands.dc = function()
    return commands.definecoordinates()
end

commands.pauselegs = function()
    if settings.pauseLegs == true then
        settings.pauseLegs = false
        windower.add_to_chat(settings.messageColor, 'In list mode, divide pauses into path legs = FALSE')
    elseif settings.pauseLegs == false then
        settings.pauseLegs = true
        windower.add_to_chat(settings.messageColor, 'In list mode, divide pauses into path legs = TRUE')
    end

    settings:save()
end

commands.pl = function()
    return commands.pauselegs()
end

commands.point = function(args)
    pathlog.logPointWithComment(args)
    windower.add_to_chat(settings.messageColor, 'Point added to logs')
end

commands.p = function(args)
    return commands.point(args)
end

commands.help = function()
    windower.add_to_chat(settings.messageColor, 'pathlog (or //pl)')
    windower.add_to_chat(settings.messageColor, '//pathlog start(st) - Begin logging targeted entity\'s path')
    windower.add_to_chat(settings.messageColor, '//pathlog stop(sp) - Stop logging targeted entity\'s path')
    windower.add_to_chat(settings.messageColor, '//pathlog mode(m) target(t)|list(l) - change tracking mode between cursor target and a set list (default target)')
    windower.add_to_chat(settings.messageColor, '//pathlog filter(f) xyz|rot(r) - change filter between xyz diff and rot diff. Will always use 0.5 y diff (default rot)')
    windower.add_to_chat(settings.messageColor, '//pathlog list(l) add(a)|remove(r)|show(s) ID - In list mode, add/remove ID|target to/from tracking list.')
    windower.add_to_chat(settings.messageColor, '//pathlog all(a) - log all positions without difference filtering (default FALSE)')
    windower.add_to_chat(settings.messageColor, '//pathlog diff(d) cumulative(c)|x|y|z|rot|time(t) (value) - set diffs required between points to log or split')
    windower.add_to_chat(settings.messageColor, 'diff defaults: cumulative 4, x = 3, y = 0.5, z = 3, rot = 0, time = 4')
    windower.add_to_chat(settings.messageColor, '//pathlog timestamp(ts) - toggle timestamp in log (default TRUE)')
    windower.add_to_chat(settings.messageColor, '//pathlog rot(r) - toggle rot in log (default FALSE)')
    windower.add_to_chat(settings.messageColor, '//pathlog tablepoints(tp) - toggle table each path point (default FALSE)')
    windower.add_to_chat(settings.messageColor, '//pathlog definecoordinates(dc) - toggle define coordinates (x = #) (default FALSE)')
    windower.add_to_chat(settings.messageColor, '//pathlog pauselegs(pl) - In list mode, auto divide mob/npc pauses into separate path legs (default TRUE)')
    windower.add_to_chat(settings.messageColor, '//pathlog point(p) \'...\' - will add a point and anything typed after to a comment in the logs')
end

windower.register_event('addon command', function(command, ...)
    command = command and command:lower()

    if commands[command] then
        commands[command](L{...})
    else
        commands.help()
    end
end)

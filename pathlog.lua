_addon.name = 'pathlog'
_addon.author = 'Duke'
_addon.version = '1.0'
_addon.commands = {'pathlog', 'pl'}

resources = require('resources')
config = require('config')
packets = require('packets')
files = require('files')
require('strings')
require('lists')

defaults = {}
defaults.messageColor = 219
defaults.logPath = false
defaults.mode = 'target'
defaults.TimestampFormat = '-- %H:%M:%S'
defaults.AddTimestamp = true
defaults.tableEachPoint = false
defaults.defineCoordinates = false
defaults.all = false
defaults.cumulativeDiff = 4
defaults.xDiff = 3
defaults.yDiff = 0.5
defaults.zDiff = 3

settings = config.load(defaults)

local pathlog = {}
pathlog.trackList = L{}

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
    if not windower.ffxi.get_info().logged_in or not settings.logPath or not id == 0x0E then return end

    local packet = packets.parse('incoming', data)
    local npc = {}
    local pos = {}

    npc.index = packet['Index']
    npc.id = packet['NPC']
    npc.look = packet['look']
    npc.polutils = packet['polutils_name']

    if pathlog.willScan(npc.look, npc.polutils) and npc.id then
        -- pos.rot = packet['Rotation']
        -- walkCount = packet['Walk Count'] -- on the shelf until v2

        pos.x = packet['X']
        pos.y = packet['Z'] -- Windower has Z and Y axis swapped
        pos.z = packet['Y']

        if settings.mode == 'target' then
            pathlog.logNpcByTarget(npc.id, pos.x, pos.y, pos.z)
        elseif settings.mode == 'list' then
            pathlog.logNpcByList(npc.id, pos.x, pos.y, pos.z)
        end
    end
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    if not windower.ffxi.get_info().logged_in or not settings.logPath then return end

    if settings.mode == 'target' then
        pathlog.logSelfByTarget()
    end
end)

windower.register_event('zone change', function(new, old)
    pathlog.trackList:clear()
end)

pathlog.caluclateCoordLen = function(isY)
    local len = 8

    if isY then
        len = len - 1
    end

    return len
end

pathlog.padLeft = function(str, length, char)
    local padded = string.rep(char or ' ', length - #str) .. str
    return padded
end

pathlog.padCoords = function(coord, isY)
    local padding = pathlog.caluclateCoordLen(isY)

    return pathlog.padLeft(coord, padding)
end

function pathlog.logNpcByTarget(npcID, x, y, z)
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_target('t')
    local zone = resources.zones[windower.ffxi.get_info().zone].name

    if target and npcID == target.id then
        local playerName = player.name
        local targetName = target.name
        local id = target.id
        local index = target.index
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'/'..id..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' }' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''

        if not logFile:exists() then
            logFile:create()
        end

        if pathlog.shouldLogPoint(logFile, x, y, z) then
            local x = string.format('%.3f', x)
            local y = string.format('%.3f', y)
            local z = string.format('%.3f', z)

            x = pathlog.padCoords(x)
            y = pathlog.padCoords(y, true)
            z = pathlog.padCoords(z)

            logFile:append(string.format("%s%s%s, %s%s, %s%s%s,   %s\n", openBracket, defineX, x, defineY, y, defineZ, z, closeBracket, timestamp))
        end
    end
end

function pathlog.logNpcByList(npcID, x, y, z)
    local player = windower.ffxi.get_player()
    local zone = resources.zones[windower.ffxi.get_info().zone].name
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
            local closeBracket = settings.tableEachPoint and ' }' or ''
            local defineX = settings.defineCoordinates and 'x = ' or ''
            local defineY = settings.defineCoordinates and 'y = ' or ''
            local defineZ = settings.defineCoordinates and 'z = ' or ''

            if not logFile:exists() then
                logFile:create()
            end

            if pathlog.shouldLogPoint(logFile, x, y, z) then
                local x = string.format('%.3f', x)
                local y = string.format('%.3f', y)
                local z = string.format('%.3f', z)

                x = pathlog.padCoords(x)
                y = pathlog.padCoords(y, true)
                z = pathlog.padCoords(z)

                logFile:append(string.format("%s%s%s, %s%s, %s%s%s,   %s\n", openBracket, defineX, x, defineY, y, defineZ, z, closeBracket, timestamp))
            end
        end
    end
end

function pathlog.logSelfByTarget()
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_target('t')
    local zone = resources.zones[windower.ffxi.get_info().zone].name

    if target and target.index == player.index then
        local playerName = player.name
        local targetName = target.name
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' }' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''
        local x = target.x
        local y = target.z -- Windower has Z and Y axis swapped
        local z = target.y

        if not logFile:exists() then
            logFile:create()
        end

        if pathlog.shouldLogPoint(logFile, x, y, z) then
            local x = string.format('%.3f', x)
            local y = string.format('%.3f', y)
            local z = string.format('%.3f', z)

            x = pathlog.padCoords(x)
            y = pathlog.padCoords(y, true)
            z = pathlog.padCoords(z)

            logFile:append(string.format("%s%s%s, %s%s, %s%s%s,   %s\n", openBracket, defineX, x, defineY, y, defineZ, z, closeBracket, timestamp))
        end
    end
end

function pathlog.logPointWithComment(comment)
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_target('me')
    local zone = resources.zones[windower.ffxi.get_info().zone].name

    if target then
        local playerName = player.name
        local targetName = target.name
        local logFile = files.new('data/pathlogs/'..playerName..'/'..zone..'/'..targetName..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' }' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and ' y = ' or ' '
        local defineZ = settings.defineCoordinates and ' z = ' or ' '
        local x = target.x
        local y = target.z -- Windower has Z and Y axis swapped
        local z = target.y

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

        logFile:append(string.format("%s%s%.3f,%s%.3f,%s%.3f%s,   %s    -- %s\n", openBracket, defineX, x, defineY, y, defineZ, z, closeBracket, timestamp, comment))
    end
end

function pathlog.shouldLogPoint(logFile, x, y, z)
    local readLines = files.readlines(logFile)
    local lastLine = readLines[#readLines - 1]
    local chars = '}{xyz= '

    if x == 0 and y == 0 and z == 0 then
        return false
    end

    if not readLines or not lastLine or settings.all then
        return true
    end

    local lastX = lastLine:split(',')[1]:stripchars(chars)
    local lastY = lastLine:split(',')[2]:stripchars(chars)
    local lastZ = lastLine:split(',')[3]:stripchars(chars)
    local xDiff = math.abs(lastX - x)
    local yDiff = math.abs(lastY - y)
    local zDiff = math.abs(lastZ - z)
    local cumulativeDiff = xDiff + yDiff + zDiff

    if cumulativeDiff >= settings.cumulativeDiff or xDiff >= settings.xDiff or yDiff >= settings.yDiff or zDiff >= settings.zDiff then
        return true
    end

    return false
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
        if type(id) ~= "number" or id == player.id then -- Make sure its a not players id number
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
            pathlog.trackList:remove(id)
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
    else
        windower.add_to_chat(settings.messageColor, 'Valid arguments are cumulative(c), x, y, or z followed by a number')
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
    windower.add_to_chat(settings.messageColor, '//pathlog mode(m) target(t)|list(l) - change tracking mode from cursor target to a set list (default target))')
    windower.add_to_chat(settings.messageColor, '//pathlog list(l) add(a)|remove(r)|show(s) ID - In list mode, add/remove ID|target to/from tracking list.')
    windower.add_to_chat(settings.messageColor, '//pathlog all(a) - log all positions without difference filtering (default FALSE)')
    windower.add_to_chat(settings.messageColor, '//pathlog diff(d) cumulative(c)|x|y|z (value)- set diff required between points to log (default cumulative 4, x = 3, y = 0.5, z = 3)')
    windower.add_to_chat(settings.messageColor, '//pathlog timestamp(ts) - toggle timestamp in log (default TRUE)')
    windower.add_to_chat(settings.messageColor, '//pathlog tablepoints(tp) - toggle table each path point (default FALSE)')
    windower.add_to_chat(settings.messageColor, '//pathlog definecoordinates(dc) - toggle define coordinates (x = #) (default FALSE)')
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

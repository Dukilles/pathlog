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
defaults.logPath = false
defaults.dsp = false
defaults.mode = 'target'
defaults.TimestampFormat = '-- [ %H:%M:%S ]'
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
    if not windower.ffxi.get_info().logged_in then return end
    if not settings.logPath then return end

    local packet = packets.parse('incoming', data)
    local npc = {}
    local pos = {}

    npc.index = packet['Index']
    npc.id = packet['NPC']
    npc.look = packet['look']
    npc.polutils = packet['polutils_name']

    if npc.id then
        -- walkCount = packet['Walk Count'] -- on the shelf until v2

        if settings.dsp then
            pos.x = packet['X']
            pos.y = packet['Y'] -- Windower and DSP have Z and Y axis swapped vs each other
            pos.z = packet['Z']
        else
            pos.x = packet['X']
            pos.y = packet['Z']
            pos.z = packet['Y']
        end

        if settings.logPath then
            if settings.mode == 'target' then
                pathlog.logNpcByTarget(npc.id, pos.x, pos.y, pos.z)
            elseif settings.mode == 'list' then
                pathlog.logNpcByList(npc.id, pos.x, pos.y, pos.z)
            end
        end
    end
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    if not windower.ffxi.get_info().logged_in then return end
    if not settings.logPath then return end

    local packet = packets.parse('outgoing', data)
    -- local runCount = packet['Run Count'] -- on the shelf until v2

    if settings.logPath and settings.mode == 'target' then
        pathlog.logSelfByTarget()
    end
end)

windower.register_event('zone change', function(new, old)
    pathlog.trackList:clear()
end)

function pathlog.logNpcByTarget(npcID, x, y, z)
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_target('t')
    local zone = resources.zones[windower.ffxi.get_info().zone].name

    if target and npcID == target.id then
        local playerName = player.name
        local targetName = target.name
        local id = target.id
        local index = target.index
        local logFile = files.new('data/'..playerName..'/'..zone..'/'..targetName..'/'..'['..index..']'..id..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' }' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''

        if not logFile:exists() then
            logFile:create()
        end

        if pathlog.shouldLogPoint(logFile, target.x, target.y, target.z) then
            logFile:append(string.format("%s%s%.3f, %s%.3f, %s%.3f%s,   %s\n", openBracket, defineX, target.x, defineY, target.y, defineZ, target.z, closeBracket, timestamp))
        end
    end
end

function pathlog.logNpcByList(npcID, x, y, z)
    local player = windower.ffxi.get_player()
    local zone = resources.zones[windower.ffxi.get_info().zone].name
    local trackList = pathlog.trackList

    if #trackList <= 0 then return end

    for entry = 1, #trackList do
        local npcID = trackList[entry]
        local target = windower.ffxi.get_mob_by_id(npcID)

        if target and npcID == target.id then
            local playerName = player.name
            local targetName = target.name
            local id = target.id
            local index = target.index
            local logFile = files.new('data/'..playerName..'/'..zone..'/'..targetName..'/'..'['..index..']'..id..'.log')
            local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
            local openBracket = settings.tableEachPoint and '{ ' or ''
            local closeBracket = settings.tableEachPoint and ' }' or ''
            local defineX = settings.defineCoordinates and 'x = ' or ''
            local defineY = settings.defineCoordinates and 'y = ' or ''
            local defineZ = settings.defineCoordinates and 'z = ' or ''

            if not logFile:exists() then
                logFile:create()
            end

            if pathlog.shouldLogPoint(logFile, target.x, target.y, target.z) then
                logFile:append(string.format("%s%s%.3f, %s%.3f, %s%.3f%s,   %s\n", openBracket, defineX, target.x, defineY, target.y, defineZ, target.z, closeBracket, timestamp))
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
        local logFile = files.new('data/'..playerName..'/'..zone..'/'..targetName..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' }' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and 'y = ' or ''
        local defineZ = settings.defineCoordinates and 'z = ' or ''

        if not logFile:exists() then
            logFile:create()
        end

        if pathlog.shouldLogPoint(logFile, target.x, target.y, target.z) then
            logFile:append(string.format("%s%s%.3f, %s%.3f, %s%.3f%s,   %s\n", openBracket, defineX, target.x, defineY, target.y, defineZ, target.z, closeBracket, timestamp))
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
        local logFile = files.new('data/'..playerName..'/'..zone..'/'..targetName..'.log')
        local timestamp = settings.AddTimestamp and os.date(settings.TimestampFormat, os.time()) or ''
        local openBracket = settings.tableEachPoint and '{ ' or ''
        local closeBracket = settings.tableEachPoint and ' }' or ''
        local defineX = settings.defineCoordinates and 'x = ' or ''
        local defineY = settings.defineCoordinates and ' y = ' or ' '
        local defineZ = settings.defineCoordinates and ' z = ' or ' '

        if not comment then
            comment = ''
        else
            comment = table.sconcat(comment)
        end

        if not logFile:exists() then
            logFile:create()
        end

        logFile:append(string.format("%s%s%.3f,%s%.3f,%s%.3f%s,   %s    -- %s\n", openBracket, defineX, target.x, defineY, target.y, defineZ, target.z, closeBracket, timestamp, comment))
    end
end

function pathlog.shouldLogPoint(logFile, targetX, targetY, targetZ)
    local readLines = files.readlines(logFile)
    local lastLine = readLines[#readLines - 1]
    local chars = 'xyz= '

    if (not readLines or not lastLine or settings.all) and settings.logPath then
        return true
    end

    local lastX = lastLine:split(',')[1]:stripchars(chars)
    local lastY = lastLine:split(',')[2]:stripchars(chars)
    local lastZ = lastLine:split(',')[3]:stripchars(chars)
    local xDiff = math.abs(lastX - targetX)
    local yDiff = math.abs(lastY - targetY)
    local zDiff = math.abs(lastZ - targetZ)
    local cumulativeDiff = xDiff + yDiff + zDiff

    if settings.logPath then
        if cumulativeDiff >= settings.cumulativeDiff then
            return true
        elseif math.abs(lastX - targetX) >= settings.xDiff or math.abs(lastZ - targetZ) >= settings.zDiff then
            return true
        elseif math.abs(lastY - targetY) >= settings.yDiff then
            return true
        end
    end

    return false
end

function pathlog.willScan(look, polutils)
    if look == '00003400' or polutils == 'NPC' then
        return false
    end
    return true
end

commands = {}

commands.dsp = function()
    if settings.dsp == true then
        settings.dsp = false
        windower.add_to_chat(8, 'Darkstar = FALSE')
    elseif settings.dsp == false then
        settings.dsp = true
        windower.add_to_chat(8, 'Darkstar = TRUE')
    end
    settings:save()
end

commands.start = function()
    settings.logPath = true
    windower.add_to_chat(8, 'Path logging ON')
end

commands.stop = function()
    settings.logPath = false
    windower.add_to_chat(8, 'Path logging OFF')
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
        windower.add_to_chat(8, 'Pathlog mode: '..settings.mode)
    else
        commands.help()
    end

    settings:save()
end

commands.all = function()
    if settings.all == true then
        settings.all = false
        windower.add_to_chat(8, 'Log all = FALSE')
    elseif settings.all == false then
        settings.all = true
        windower.add_to_chat(8, 'Log all = TRUE')
    end
    settings:save()
end

commands.timestamp = function()
    if settings.AddTimestamp == true then
        settings.AddTimestamp = false
        windower.add_to_chat(8, 'Add timestamp to logs = FALSE')
    elseif settings.AddTimestamp == false then
        settings.AddTimestamp = true
        windower.add_to_chat(8, 'Add timestamp to logs = TRUE')
    end
    settings:save()
end

commands.tablepoints = function()
    if settings.tableEachPoint == true then
        settings.tableEachPoint = false
        windower.add_to_chat(8, 'Table each point = FALSE')
    elseif settings.tableEachPoint == false then
        settings.tableEachPoint = true
        windower.add_to_chat(8, 'Table each point = TRUE')
    end
    settings:save()
end

commands.definecoordinates = function()
    if settings.defineCoordinates == true then
        settings.defineCoordinates = false
        windower.add_to_chat(8, 'Define coordinates = FALSE')
    elseif settings.defineCoordinates == false then
        settings.defineCoordinates = true
        windower.add_to_chat(8, 'Define coordinates = TRUE')
    end
    settings:save()
end

commands.point = function(args)
    pathlog.logPointWithComment(args)
    windower.add_to_chat(8, 'Point added to logs')
end

commands.list = function(args)
    local option = args:remove(1)
    local id = tonumber(args:concat(' '))
    local target = windower.ffxi.get_mob_by_target('t')
    local player = windower.ffxi.get_mob_by_target('me')

    if option == 'show' or option == 's' then
        local trackList = pathlog.trackList

        if #trackList > 0 then
            windower.add_to_chat(8, 'Pathlog Tracklist:')

            for entry = 1, #trackList do
                windower.add_to_chat(8, ''..trackList[entry])
            end
        else
            windower.add_to_chat(8, 'Pathlog Tracklist is Empty')
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
                windower.add_to_chat(8, 'Cannot target player in list mode. Switch to target mode to log player path')
            else
                id = target.id
            end
        end
    else
        commands.help()
        return
    end

    if option == 'add' or option == 'a' then
        pathlog.trackList:append(id)
        windower.add_to_chat(8, 'Added '..id.. ' to tracking list. ')
    elseif option == 'remove' or option == 'r' then
        pathlog.trackList:remove(id)
        windower.add_to_chat(8, 'Removed '..id.. ' from tracking list. ')
    elseif option == 'clear' or option == 'c' then
        pathlog.trackList:clear()
        windower.add_to_chat(8, 'Cleared tracking list: ')
    end
end

commands.help = function()
    windower.add_to_chat(8, 'pathlog (or //pl)')
    windower.add_to_chat(8, '//pathlog start - Begin logging targeted entity\'s path')
    windower.add_to_chat(8, '//pathlog stop - Stop logging targeted entity\'s path')
    windower.add_to_chat(8, '//pathlog mode target(t)|list(l) - change tracking mode from cursor target to a set list')
    windower.add_to_chat(8, '//pathlog list add(a)|remove(r) ID - In list mode, add/remove targets from tracking list. If no ID, will attempt to use cursor target ID')
    windower.add_to_chat(8, '//pathlog list show(s) - Show tracking list in chat log')
    windower.add_to_chat(8, '//pathlog all - output all positions to log without any filtering (default FALSE)')
    windower.add_to_chat(8, '//pathlog timestamp - toggle timestamp in log on and off (default TRUE)')
    windower.add_to_chat(8, '//pathlog tablepoints - toggle table each path point on and off (default FALSE)')
    windower.add_to_chat(8, '//pathlog definecoordinates - toggle define coordinates on and off ( x = #, y = #, z = # ) (default FALSE)')
    windower.add_to_chat(8, '//pathlog point \'...\' - will add anything typed after point to a comment in the logs')
    windower.add_to_chat(8, '//pathlog help - displays help')
end

windower.register_event('addon command', function(command, ...)
    command = command and command:lower()

    if commands[command] then
        commands[command](L{...})
    else
        commands.help()
    end
end)

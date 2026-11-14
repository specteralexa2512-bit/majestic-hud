local tickets = {}
local nextTicketId = 1
local loggedIn = {}
local adminLevels = {}
local adminModes = {}
local adminByServerId = {}

local function getIds(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1,8) == 'license:' then ids.license = id end
        if id:sub(1,6) == 'fivem:' then ids.fivem = id end
    end
    return ids
end

local function levelForPlayer(src)
    if src == 0 then return 7 end
    local ids = getIds(src)
    local key = ids.license or ids.fivem
    if not key then return 0 end
    for bootstrapKey, level in pairs(Config.BootstrapAdmins or {}) do
        if bootstrapKey == key then return tonumber(level) or 0 end
    end
    return tonumber(adminLevels[key]) or 0
end

local function isAuthorized(src, required)
    return src > 0 and loggedIn[src] == true and levelForPlayer(src) >= required
end

local function notify(src, text)
    TriggerClientEvent('rlrp_admin:notice', src, text)
end

local function broadcastOnlineCount()
    TriggerClientEvent('rlrp_hud:setOnlineCount', -1, #GetPlayers())
end

local function countOpenTickets()
    local count = 0
    for _, ticket in ipairs(tickets) do
        if ticket.status == 'open' then count = count + 1 end
    end
    return count
end

local function serializeTicket(ticket)
    return {
        id = ticket.id,
        playerId = ticket.playerId,
        playerName = ticket.playerName,
        text = ticket.text,
        status = ticket.status,
        assigned = ticket.assigned,
        created = ticket.created,
        messages = ticket.messages or {}
    }
end

local function notifyAdmins(text, minLevel)
    for _, playerId in ipairs(GetPlayers()) do
        local sid = tonumber(playerId)
        if sid and loggedIn[sid] and levelForPlayer(sid) >= (minLevel or 1) then
            TriggerClientEvent('rlrp_admin:notice', sid, text)
        end
    end
end

local function pushTicketUpdate(ticket)
    for _, playerId in ipairs(GetPlayers()) do
        local sid = tonumber(playerId)
        if sid and loggedIn[sid] and levelForPlayer(sid) >= 1 then
            TriggerClientEvent('rlrp_admin:ticketUpdate', sid, serializeTicket(ticket))
        end
    end
    TriggerClientEvent('rlrp_admin:ticketCount', -1, countOpenTickets())
end

local function sendTicketSnapshot(src)
    local list = {}
    for _, ticket in ipairs(tickets) do
        if ticket.status == 'open' then
            list[#list + 1] = serializeTicket(ticket)
        end
    end
    TriggerClientEvent('rlrp_admin:ticketSnapshot', src, list)
end

RegisterNetEvent('rlrp_hud:requestOnlineCount', function()
    TriggerClientEvent('rlrp_hud:setOnlineCount', source, #GetPlayers())
end)

AddEventHandler('playerJoining', function()
    SetTimeout(1000, broadcastOnlineCount)
end)

AddEventHandler('playerDropped', function()
    local src = source
    loggedIn[src] = nil
    adminModes[src] = nil
    adminByServerId[src] = nil
    SetTimeout(1000, broadcastOnlineCount)
end)

CreateThread(function()
    while true do
        broadcastOnlineCount()
        for _, playerId in ipairs(GetPlayers()) do
            local sid = tonumber(playerId)
            if sid and loggedIn[sid] and levelForPlayer(sid) >= 1 then
                TriggerClientEvent('rlrp_admin:ticketCount', sid, countOpenTickets())
            end
        end
        Wait(15000)
    end
end)

RegisterNetEvent('rlrp_admin:login', function()
    local src = source
    local level = levelForPlayer(src)
    if level < 1 then
        TriggerClientEvent('rlrp_admin:loginResult', src, false, 0)
        notify(src, 'Du hast keine Adminrechte.')
        return
    end
    loggedIn[src] = true
    TriggerClientEvent('rlrp_admin:loginResult', src, true, level)
    TriggerClientEvent('rlrp_admin:ticketCount', src, countOpenTickets())
    sendTicketSnapshot(src)
end)

RegisterNetEvent('rlrp_admin:toggleMode', function()
    local src = source
    if not isAuthorized(src, 2) then
        notify(src, 'Mindestens Level 2 nötig. /adminlogin')
        return
    end
    adminModes[src] = not adminModes[src]
    TriggerClientEvent('rlrp_admin:mode', -1, adminModes[src], src, GetPlayerName(src))
end)

RegisterNetEvent('rlrp_admin:giveadmin', function(targetId, level)
    local src = source
    if not isAuthorized(src, 7) then
        notify(src, 'Nur Level 7 kann Adminrechte vergeben.')
        return
    end

    local target = tonumber(targetId)
    local newLevel = tonumber(level) or 1
    if not target or target == 0 or newLevel < 1 or newLevel > 7 then
        notify(src, 'Nutzung: /giveadmin <ID> [1-7]')
        return
    end

    local ids = getIds(target)
    local key = ids.license or ids.fivem
    if not key then
        notify(src, 'Dieser Spieler hat keine gültige ID.')
        return
    end

    adminLevels[key] = newLevel
    TriggerClientEvent('rlrp_admin:notice', target, ('Du hast Admin-Level %d erhalten. /adminlogin'):format(newLevel))
    notify(src, ('Spieler %s wurde auf Level %d gesetzt.'):format(GetPlayerName(target), newLevel))
end)

RegisterNetEvent('rlrp_admin:requestTickets', function()
    local src = source
    if not isAuthorized(src, 1) then
        notify(src, 'Bitte /adminlogin eingeben.')
        return
    end
    sendTicketSnapshot(src)
end)

RegisterNetEvent('rlrp_admin:report', function(text)
    local src = source
    if not text or text:trim() == '' then
        notify(src, 'Nutzung: /report <Anliegen>')
        return
    end

    local clean = text:sub(1, Config.MaxReportLength or 500)
    local ticket = {
        id = nextTicketId,
        playerId = src,
        playerName = GetPlayerName(src) or ('Spieler ' .. src),
        text = clean,
        status = 'open',
        assigned = nil,
        created = os.date('%d.%m.%Y %H:%M'),
        messages = {}
    }
    nextTicketId = nextTicketId + 1
    tickets[#tickets + 1] = ticket
    notify(src, ('Dein Report # %d wurde eingereicht.'):format(ticket.id))
    notifyAdmins(('Neues Ticket # %d von %s'):format(ticket.id, ticket.playerName), 1)
    pushTicketUpdate(ticket)
end)

RegisterNetEvent('rlrp_admin:replyPlayer', function(text)
    local src = source
    if not text or text:trim() == '' then
        notify(src, 'Nutzung: /reply <Nachricht>')
        return
    end
    local ticket = nil
    for i = #tickets, 1, -1 do
        if tickets[i].playerId == src and tickets[i].status == 'open' then
            ticket = tickets[i]
            break
        end
    end
    if not ticket then
        notify(src, 'Kein offenes Ticket gefunden.')
        return
    end

    local msg = text:sub(1, Config.MaxMessageLength or 500)
    ticket.messages[#ticket.messages + 1] = {
        sender = 'Spieler',
        text = msg,
        time = os.date('%H:%M')
    }
    pushTicketUpdate(ticket)
end)

RegisterNetEvent('rlrp_admin:replyTicket', function(ticketId, msg)
    local src = source
    if not isAuthorized(src, 2) then
        notify(src, 'Level 2 nötig.')
        return
    end

    local info = msg or ''
    local clean = info:sub(1, Config.MaxMessageLength or 500)
    if clean:trim() == '' then return end

    for _, ticket in ipairs(tickets) do
        if ticket.id == tonumber(ticketId) and ticket.status == 'open' then
            ticket.messages[#ticket.messages + 1] = {
                sender = 'Admin ' .. (GetPlayerName(src) or 'Staff'),
                text = clean,
                time = os.date('%H:%M')
            }
            TriggerClientEvent('rlrp_admin:notice', ticket.playerId, ('Admin antwortet auf dein Ticket # %d: %s'):format(ticket.id, clean))
            pushTicketUpdate(ticket)
            return
        end
    end

    notify(src, 'Ticket nicht gefunden.')
end)

RegisterNetEvent('rlrp_admin:claimTicket', function(ticketId)
    local src = source
    if not isAuthorized(src, 2) then return end
    for _, ticket in ipairs(tickets) do
        if ticket.id == tonumber(ticketId) and ticket.status == 'open' then
            ticket.assigned = GetPlayerName(src)
            pushTicketUpdate(ticket)
            return
        end
    end
end)

RegisterNetEvent('rlrp_admin:closeTicket', function(ticketId)
    local src = source
    if not isAuthorized(src, 2) then
        notify(src, 'Level 2 nötig.')
        return
    end

    for _, ticket in ipairs(tickets) do
        if ticket.id == tonumber(ticketId) and ticket.status == 'open' then
            ticket.status = 'closed'
            TriggerClientEvent('rlrp_admin:notice', ticket.playerId, ('Dein Report # %d wurde geschlossen.'):format(ticket.id))
            pushTicketUpdate(ticket)
            return
        end
    end
end)

RegisterNetEvent('rlrp_admin:mode', function(enabled, sid, name)
    local src = source
    if src ~= 0 then return end
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid and pid ~= sid then
            TriggerClientEvent('rlrp_admin:modeSync', pid, enabled, sid, name)
        end
    end
end)

RegisterCommand('rlrp_setadmin', function(source, args)
    if source ~= 0 then return end
    local key = args[1]
    local level = tonumber(args[2]) or 0
    if not key or not (key:sub(1,8) == 'license:' or key:sub(1,6) == 'fivem:') or level < 1 or level > 7 then
        print('Usage: rlrp_setadmin <license:...|fivem:...> <1-7>')
        return
    end
    Config.BootstrapAdmins[key] = level
    print(('Adminlevel %d für %s gesetzt.'):format(level, key))
end, true)

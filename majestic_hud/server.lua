local tickets = {}
local nextTicketId = 1
local loggedIn, adminModes, muted = {}, {}, {}

local function trim(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function identifiersFor(src)
    local found = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' or identifier:sub(1, 6) == 'fivem:' then
            found[#found + 1] = identifier
        end
    end
    return found
end

local function levelFor(src)
    if src == 0 then return 7 end
    for _, identifier in ipairs(identifiersFor(src)) do
        local configured = tonumber((Config.BootstrapAdmins or {})[identifier])
        if configured and configured >= 1 and configured <= 7 then return configured end
    end
    for _, identifier in ipairs(identifiersFor(src)) do
        local saved = GetResourceKvpInt('adminlevel:' .. identifier)
        if saved and saved >= 1 and saved <= 7 then return saved end
    end
    return 0
end

local function allowed(src, minimum)
    return src > 0 and loggedIn[src] == true and levelFor(src) >= minimum
end

local function notify(src, message)
    if src and src > 0 then
        TriggerClientEvent('rlrp_admin:notice', src, tostring(message))
    else
        print('[majestic_hud] ' .. tostring(message))
    end
end

local function openCount()
    local count = 0
    for _, ticket in ipairs(tickets) do
        if ticket.status == 'open' then count = count + 1 end
    end
    return count
end

local function serialize(ticket)
    return {
        id = ticket.id,
        playerId = ticket.playerId,
        playerName = ticket.playerName,
        text = ticket.text,
        status = ticket.status,
        assigned = ticket.assigned,
        created = ticket.created,
        messages = ticket.messages
    }
end

local function sendCount(target)
    TriggerClientEvent('rlrp_admin:ticketCount', target or -1, openCount())
end

local function sendSnapshot(src)
    local list = {}
    for _, ticket in ipairs(tickets) do
        if ticket.status == 'open' then list[#list + 1] = serialize(ticket) end
    end
    TriggerClientEvent('rlrp_admin:ticketSnapshot', src, list)
    sendCount(src)
end

local function pushTicket(ticket)
    local data = serialize(ticket)
    for _, raw in ipairs(GetPlayers()) do
        local player = tonumber(raw)
        if player and loggedIn[player] and levelFor(player) >= 1 then
            TriggerClientEvent('rlrp_admin:ticketUpdate', player, data)
            TriggerClientEvent('rlrp_admin:ticketCount', player, openCount())
        end
    end
end

local function notifyAdmins(message)
    for _, raw in ipairs(GetPlayers()) do
        local player = tonumber(raw)
        if player and loggedIn[player] and levelFor(player) >= 1 then notify(player, message) end
    end
end

local function createReport(src, text)
    if not src or src <= 0 or not GetPlayerName(src) then return end
    local clean = trim(text):sub(1, tonumber(Config.MaxReportLength) or 500)
    if clean == '' then
        notify(src, 'Nutzung: /report <Anliegen>')
        return
    end
    if openCount() >= (tonumber(Config.MaxOpenTickets) or 100) then
        notify(src, 'Es sind zu viele Reports offen. Bitte später erneut versuchen.')
        return
    end

    local ticket = {
        id = nextTicketId,
        playerId = src,
        playerName = GetPlayerName(src) or ('Spieler ' .. src),
        text = clean,
        status = 'open',
        created = os.date('%d.%m.%Y %H:%M'),
        messages = {}
    }
    nextTicketId = nextTicketId + 1
    tickets[#tickets + 1] = ticket

    notify(src, ('Dein Report #%d wurde gesendet.'):format(ticket.id))
    notifyAdmins(('Neuer Report #%d von %s (ID %d)'):format(ticket.id, ticket.playerName, src))
    pushTicket(ticket)
    sendCount(-1)
    print(('[majestic_hud] Report #%d von %s (ID %d): %s'):format(ticket.id, ticket.playerName, src, clean))
end

local function findOpenTicket(ticketId)
    for _, ticket in ipairs(tickets) do
        if ticket.id == tonumber(ticketId) and ticket.status == 'open' then return ticket end
    end
end

RegisterNetEvent('rlrp_hud:requestOnlineCount', function()
    TriggerClientEvent('rlrp_hud:setOnlineCount', source, #GetPlayers())
end)

local function broadcastOnlineCount()
    TriggerClientEvent('rlrp_hud:setOnlineCount', -1, #GetPlayers())
end

AddEventHandler('playerJoining', function()
    SetTimeout(1000, broadcastOnlineCount)
end)

AddEventHandler('playerDropped', function()
    local src = source
    loggedIn[src], adminModes[src], muted[src] = nil, nil, nil
    for _, ticket in ipairs(tickets) do
        if ticket.status == 'open' and ticket.playerId == src then
            ticket.playerOnline = false
            pushTicket(ticket)
        end
    end
    SetTimeout(1000, broadcastOnlineCount)
end)

AddEventHandler('chatMessage', function(src)
    if muted[src] then
        CancelEvent()
        notify(src, 'Chat gesperrt: Du bist stummgeschaltet.')
    end
end)

CreateThread(function()
    while true do
        broadcastOnlineCount()
        sendCount(-1)
        Wait(15000)
    end
end)

RegisterNetEvent('rlrp_admin:login', function()
    local src = source
    local level = levelFor(src)
    if level < 1 then
        loggedIn[src] = nil
        TriggerClientEvent('rlrp_admin:loginResult', src, false, 0, 'Keine Adminrechte erkannt. Prüfe die Identifier in config.lua.')
        return
    end
    loggedIn[src] = true
    TriggerClientEvent('rlrp_admin:loginResult', src, true, level, ('Admin-Login erfolgreich · Level %d'):format(level))
    sendSnapshot(src)
end)

RegisterNetEvent('rlrp_admin:requestTickets', function()
    local src = source
    if not allowed(src, 1) then
        notify(src, 'Bitte zuerst /adminlogin eingeben.')
        return
    end
    sendSnapshot(src)
end)

RegisterCommand('report', function(src, args)
    if src == 0 then return end
    createReport(src, table.concat(args, ' '))
end, false)

RegisterNetEvent('rlrp_admin:report', function(text)
    createReport(source, text)
end)

RegisterCommand('reply', function(src, args)
    if src == 0 then return end
    local message = trim(table.concat(args, ' ')):sub(1, tonumber(Config.MaxMessageLength) or 500)
    if message == '' then notify(src, 'Nutzung: /reply <Nachricht>'); return end
    for i = #tickets, 1, -1 do
        local ticket = tickets[i]
        if ticket.playerId == src and ticket.status == 'open' then
            ticket.messages[#ticket.messages + 1] = { sender = 'Spieler', text = message, time = os.date('%H:%M') }
            pushTicket(ticket)
            notifyAdmins(('Neue Nachricht in Report #%d von %s'):format(ticket.id, ticket.playerName))
            notify(src, ('Nachricht zu Report #%d gesendet.'):format(ticket.id))
            return
        end
    end
    notify(src, 'Du hast kein offenes Report-Ticket.')
end, false)

RegisterNetEvent('rlrp_admin:replyPlayer', function(text)
    local src = source
    local message = trim(text):sub(1, tonumber(Config.MaxMessageLength) or 500)
    if message == '' then notify(src, 'Nutzung: /reply <Nachricht>'); return end
    for i = #tickets, 1, -1 do
        local ticket = tickets[i]
        if ticket.playerId == src and ticket.status == 'open' then
            ticket.messages[#ticket.messages + 1] = { sender = 'Spieler', text = message, time = os.date('%H:%M') }
            pushTicket(ticket)
            notifyAdmins(('Neue Nachricht in Report #%d von %s'):format(ticket.id, ticket.playerName))
            notify(src, ('Nachricht zu Report #%d gesendet.'):format(ticket.id))
            return
        end
    end
    notify(src, 'Du hast kein offenes Report-Ticket.')
end)

RegisterNetEvent('rlrp_admin:replyTicket', function(ticketId, message)
    local src = source
    if not allowed(src, 2) then notify(src, 'Antworten benötigen Admin-Level 2.'); return end
    local clean = trim(message):sub(1, tonumber(Config.MaxMessageLength) or 500)
    local ticket = findOpenTicket(ticketId)
    if clean == '' or not ticket then notify(src, 'Ticket nicht gefunden oder Nachricht leer.'); return end
    ticket.messages[#ticket.messages + 1] = { sender = 'Admin ' .. (GetPlayerName(src) or tostring(src)), text = clean, time = os.date('%H:%M') }
    pushTicket(ticket)
    if GetPlayerName(ticket.playerId) then
        notify(ticket.playerId, ('Nachricht zu deinem Report #%d: %s'):format(ticket.id, clean))
    end
    notify(src, ('Antwort zu Report #%d gesendet.'):format(ticket.id))
end)

RegisterNetEvent('rlrp_admin:claimTicket', function(ticketId)
    local src = source
    if not allowed(src, 2) then notify(src, 'Tickets übernehmen benötigt Admin-Level 2.'); return end
    local ticket = findOpenTicket(ticketId)
    if not ticket then notify(src, 'Ticket nicht gefunden oder geschlossen.'); return end
    ticket.assigned = GetPlayerName(src) or ('ID ' .. src)
    pushTicket(ticket)
    notify(src, ('Report #%d übernommen.'):format(ticket.id))
end)

RegisterNetEvent('rlrp_admin:closeTicket', function(ticketId)
    local src = source
    if not allowed(src, 2) then notify(src, 'Schließen benötigt Admin-Level 2.'); return end
    local ticket = findOpenTicket(ticketId)
    if not ticket then notify(src, 'Ticket nicht gefunden oder bereits geschlossen.'); return end
    ticket.status = 'closed'
    pushTicket(ticket)
    if GetPlayerName(ticket.playerId) then notify(ticket.playerId, ('Dein Report #%d wurde geschlossen.'):format(ticket.id)) end
    notify(src, ('Report #%d geschlossen.'):format(ticket.id))
    sendCount(-1)
end)

RegisterNetEvent('rlrp_admin:toggleMode', function()
    local src = source
    if not allowed(src, 2) then notify(src, '/admin benötigt Admin-Level 2 und /adminlogin.'); return end
    adminModes[src] = not adminModes[src]
    local list = {}
    for id, enabled in pairs(adminModes) do
        if enabled and GetPlayerName(id) then list[id] = GetPlayerName(id) end
    end
    TriggerClientEvent('rlrp_admin:modeSnapshot', -1, list)
    notify(src, adminModes[src] and 'Adminmodus aktiviert.' or 'Adminmodus deaktiviert.')
end)

RegisterNetEvent('rlrp_admin:giveadmin', function(targetArg, levelArg)
    local src = source
    if not allowed(src, 7) then notify(src, '/giveadmin ist Level 7 vorbehalten.'); return end
    local target, level = tonumber(targetArg), tonumber(levelArg) or 1
    if not target or not GetPlayerName(target) or level % 1 ~= 0 or level < 1 or level > 7 then
        notify(src, 'Nutzung: /giveadmin ID [Level 1-7]')
        return
    end
    local identifiers = identifiersFor(target)
    if #identifiers == 0 then notify(src, 'Keine unterstützte Identifier-ID gefunden.'); return end
    for _, identifier in ipairs(identifiers) do SetResourceKvpInt('adminlevel:' .. identifier, level) end
    notify(src, ('Admin-Level %d an %s vergeben.'):format(level, GetPlayerName(target)))
    notify(target, ('Du hast Admin-Level %d erhalten. Verwende /adminlogin.'):format(level))
end)

RegisterNetEvent('rlrp_admin:moderate', function(action, targetArg, arg1, arg2, reason)
    local src = source
    if not allowed(src, 2) then notify(src, 'Dieser Befehl benötigt Admin-Level 2 und /adminlogin.'); return end
    local target = tonumber(targetArg)
    local targetName = target and GetPlayerName(target)

    if action == 'spawnwep' then
        local weapon = tostring(targetArg or ''):upper()
        if not weapon:match('^WEAPON_[A-Z0-9_]+$') then notify(src, 'Nutzung: /spawnwep WEAPON_NAME [ammo]'); return end
        TriggerClientEvent('rlrp_admin:spawnWeapon', src, weapon, tonumber(arg1) or 9999)
        return
    end
    if action == 'spawncar' then
        local model = tostring(targetArg or ''):lower()
        if not model:match('^[a-z0-9_]+$') then notify(src, 'Nutzung: /spawncar model [color1] [color2]'); return end
        TriggerClientEvent('rlrp_admin:spawnVehicle', src, model, tonumber(arg1) or 0, tonumber(arg2) or 0)
        return
    end
    if not targetName then notify(src, 'Spieler-ID nicht online.'); return end

    if action == 'mute' or action == 'unmute' then
        muted[target] = action == 'mute'
        TriggerClientEvent('rlrp_admin:muteState', target, muted[target])
        notify(src, ('%s (ID %d) %s.'):format(targetName, target, muted[target] and 'stummgeschaltet' or 'entstummgeschaltet'))
        return
    end
    if action == 'setkevlar' or action == 'sethealth' then
        local amount = tonumber(arg1)
        if not amount then notify(src, 'Menge muss eine Zahl sein.'); return end
        if action == 'setkevlar' then
            TriggerClientEvent('rlrp_admin:setVitals', target, nil, math.max(0, math.min(100, amount)))
        else
            TriggerClientEvent('rlrp_admin:setVitals', target, math.max(100, math.min(200, amount)), nil)
        end
        notify(src, ('%s für %s aktualisiert.'):format(action == 'setkevlar' and 'Rüstung' or 'Leben', targetName))
        return
    end
    if action == 'goto' or action == 'gethere' then
        local mover, destination = action == 'goto' and src or target, action == 'goto' and target or src
        local ped = GetPlayerPed(destination)
        if ped == 0 then notify(src, 'Spielerposition nicht verfügbar.'); return end
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('rlrp_admin:teleport', mover, coords.x, coords.y, coords.z, GetEntityHeading(ped))
        notify(src, action == 'goto' and ('Zu %s teleportiert.'):format(targetName) or (targetName .. ' zu dir geholt.'))
        return
    end
    if action == 'kick' or action == 'ban' then
        local why = trim(reason)
        if why == '' then why = 'Kein Grund angegeben' end
        if action == 'ban' then
            for _, identifier in ipairs(identifiersFor(target)) do SetResourceKvp('rlrpban:' .. identifier, why) end
        end
        DropPlayer(target, ('%s von %s. Grund: %s'):format(action == 'ban' and 'Gebannt' or 'Gekickt', GetPlayerName(src) or 'Administration', why))
        notify(src, ('%s (ID %d) wurde %s.'):format(targetName, target, action == 'ban' and 'gebannt' or 'gekickt'))
        return
    end
    notify(src, 'Unbekannte Adminaktion.')
end)

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    for _, identifier in ipairs(identifiersFor(src)) do
        local reason = GetResourceKvpString('rlrpban:' .. identifier)
        if reason then
            deferrals.done(('Du bist gebannt. Grund: %s'):format(reason))
            return
        end
    end
    deferrals.done()
end)

RegisterCommand('rlrp_setadmin', function(src, args)
    if src ~= 0 then return end
    local identifier, level = args[1], tonumber(args[2])
    if not identifier or not level or level < 1 or level > 7 then
        print('Nutzung: rlrp_setadmin license:IDENTIFIER 1-7')
        return
    end
    SetResourceKvpInt('adminlevel:' .. identifier, level)
    print(('Admin-Level %d für %s gespeichert.'):format(level, identifier))
end, true)

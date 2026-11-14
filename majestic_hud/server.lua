local tickets, nextTicketId, adminLevels, loggedIn, adminModes = {}, 1, {}, {}, {}
local function notify(src, text) TriggerClientEvent('rlrp_admin:ticketNotice', src, text) end
local function identifiers(src)
    local result = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1,8) == 'license:' then result.license = id elseif id:sub(1,7) == 'fivem:' then result.fivem = id end
    end
    return result
end
local function adminLevel(src)
    if src == 0 then return 7 end
    local ids = identifiers(src)
    for identifier, level in pairs(Config.BootstrapAdmins or {}) do
        if identifier == ids.license or identifier == ids.fivem then return tonumber(level) or 0 end
    end
    return adminLevels[ids.license or ids.fivem] or 0
end
local function authorized(src, level)
    return src > 0 and loggedIn[src] == true and adminLevel(src) >= level
end
local function publicTicket(ticket)
    return { id=ticket.id, playerId=ticket.playerId, playerName=ticket.playerName, text=ticket.text, status=ticket.status, assigned=ticket.assigned, created=ticket.created, messages=ticket.messages }
end
local function activeCount()
    local n=0; for _,ticket in ipairs(tickets) do if ticket.status == 'open' then n=n+1 end end; return n
end
local function notifyAdmins(text, minimum)
    for _, raw in ipairs(GetPlayers()) do local id=tonumber(raw); if loggedIn[id] and adminLevel(id) >= (minimum or 1) then notify(id, text) end end
end
local function sendTicketCounts()
    local count=activeCount()
    for _, raw in ipairs(GetPlayers()) do local id=tonumber(raw); if adminLevel(id) >= 1 then TriggerClientEvent('rlrp_admin:ticketCount', id, count) end end
end
local function sendTicketSnapshot(src)
    local list={}; for _,ticket in ipairs(tickets) do if ticket.status == 'open' then list[#list+1]=publicTicket(ticket) end end
    TriggerClientEvent('rlrp_admin:ticketSnapshot', src, list)
end

RegisterNetEvent('rlrp_hud:requestOnlineCount', function() TriggerClientEvent('rlrp_hud:setOnlineCount', source, #GetPlayers()) end)
local function broadcastOnlineCount() TriggerClientEvent('rlrp_hud:setOnlineCount', -1, #GetPlayers()) end
AddEventHandler('playerJoining', function() SetTimeout(1000, broadcastOnlineCount) end)
AddEventHandler('playerDropped', function()
    local src=source; loggedIn[src]=nil; adminModes[src]=nil
    SetTimeout(1000, function()
        broadcastOnlineCount()
        local modes={}; for id,name in pairs(adminModes) do modes[id]=name end
        TriggerClientEvent('rlrp_admin:modeSnapshot', -1, modes)
    end)
end)
CreateThread(function() while true do broadcastOnlineCount(); sendTicketCounts(); Wait(15000) end end)

RegisterCommand('report', function(src, args)
    if src == 0 then return end
    local text=table.concat(args, ' '):sub(1, Config.MaxReportLength or 500)
    if text:gsub('%s','') == '' then notify(src, 'Nutzung: /report <dein Anliegen>'); return end
    local open=activeCount(); if open >= (Config.MaxOpenTickets or 100) then notify(src, 'Aktuell sind zu viele offene Tickets. Bitte versuche es später erneut.'); return end
    local ticket={ id=nextTicketId, playerId=src, playerName=GetPlayerName(src) or ('Spieler '..src), text=text, status='open', assigned=nil, created=os.date('%d.%m.%Y %H:%M'), messages={} }
    nextTicketId=nextTicketId+1; tickets[#tickets+1]=ticket
    notify(src, ('Dein Report #%d wurde gesendet. Antworte mit /reply <Nachricht>.'):format(ticket.id))
    notifyAdmins(('Neuer Report #%d von %s (ID %d)'):format(ticket.id,ticket.playerName,src), 1)
    for _, raw in ipairs(GetPlayers()) do local id=tonumber(raw); if loggedIn[id] and adminLevel(id)>=1 then TriggerClientEvent('rlrp_admin:ticketUpdate',id,publicTicket(ticket)) end end
    sendTicketCounts()
end, false)

RegisterCommand('reply', function(src,args)
    if src==0 then return end
    local message=table.concat(args,' '):sub(1,Config.MaxMessageLength or 500)
    if message:gsub('%s','')=='' then notify(src,'Nutzung: /reply <Nachricht>'); return end
    local ticket
    for i=#tickets,1,-1 do if tickets[i].playerId==src and tickets[i].status=='open' then ticket=tickets[i]; break end end
    if not ticket then notify(src,'Du hast kein offenes Report-Ticket.'); return end
    ticket.messages[#ticket.messages+1]={sender='Spieler',text=message,time=os.date('%H:%M')}
    notifyAdmins(('Antwort zu Ticket #%d von %s'):format(ticket.id,GetPlayerName(src) or src),1)
    for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if loggedIn[id] and adminLevel(id)>=1 then TriggerClientEvent('rlrp_admin:ticketUpdate',id,publicTicket(ticket)) end end
end,false)

RegisterCommand('adminlogin', function(src)
    if src==0 then return end
    local level=adminLevel(src)
    if level<1 then loggedIn[src]=nil; TriggerClientEvent('rlrp_admin:loginResult',src,false,0,'Du hast keine Adminrechte.'); return end
    loggedIn[src]=true
    TriggerClientEvent('rlrp_admin:loginResult',src,true,level,('Admin-Login erfolgreich (Level %d). F3 öffnet das Admin-Menü.'):format(level))
    TriggerClientEvent('rlrp_admin:ticketCount',src,activeCount())
    sendTicketSnapshot(src)
end,false)

RegisterCommand('admin', function(src)
    if not authorized(src,2) then notify(src,'Zuerst /adminlogin eingeben; Adminmodus benötigt mindestens Level 2.'); return end
    adminModes[src]=not adminModes[src] and (GetPlayerName(src) or ('ID '..src)) or nil
    local enabled=adminModes[src]~=nil
    TriggerClientEvent('rlrp_admin:mode',-1,enabled,src,GetPlayerName(src) or ('ID '..src))
end,false)

RegisterCommand('giveadmin', function(src,args)
    if src==0 then print('Nutzung ingame: /giveadmin <ID> [Level 1-7]'); return end
    if not authorized(src,7) then notify(src,'Nur eingeloggte Level-7-Admins können Adminrechte vergeben.'); return end
    local target=tonumber(args[1]); local level=tonumber(args[2]) or 1
    if not target or not GetPlayerName(target) or level<1 or level>7 or level%1~=0 then notify(src,'Nutzung: /giveadmin <ID> [Level 1-7]'); return end
    local ids=identifiers(target); local key=ids.license or ids.fivem
    if not key then notify(src,'Für diesen Spieler wurde keine persistente FiveM-ID gefunden.'); return end
    adminLevels[key]=level; SetResourceKvpInt('admin:'..key,level)
    notify(src,('Spieler %s (ID %d) hat Admin-Level %d erhalten.'):format(GetPlayerName(target),target,level))
    TriggerClientEvent('rlrp_admin:ticketNotice',target,('Du hast Admin-Level %d erhalten. Nutze /adminlogin.'):format(level))
end,false)

RegisterNetEvent('rlrp_admin:login', function()
    local src=source; local level=adminLevel(src)
    if level<1 then TriggerClientEvent('rlrp_admin:loginResult',src,false,0,'Du hast keine Adminrechte.'); return end
    loggedIn[src]=true
    TriggerClientEvent('rlrp_admin:loginResult',src,true,level,('Admin-Login erfolgreich (Level %d). F3 öffnet das Admin-Menü.'):format(level))
    TriggerClientEvent('rlrp_admin:ticketCount',src,activeCount()); sendTicketSnapshot(src)
end)
RegisterNetEvent('rlrp_admin:toggleMode',function()
    local src=source; if not authorized(src,2) then notify(src,'Zuerst /adminlogin eingeben; Adminmodus benötigt mindestens Level 2.'); return end
    adminModes[src]=not adminModes[src] and (GetPlayerName(src) or ('ID '..src)) or nil
    TriggerClientEvent('rlrp_admin:mode',-1,adminModes[src]~=nil,src,GetPlayerName(src) or ('ID '..src))
end)
RegisterNetEvent('rlrp_admin:requestTickets',function()
    local src=source; if not authorized(src,1) then notify(src,'Bitte mit /adminlogin anmelden.'); return end; sendTicketSnapshot(src)
end)
RegisterNetEvent('rlrp_admin:reply',function(ticketId,message)
    local src=source; if not authorized(src,2) then notify(src,'Zum Antworten wird Admin-Level 2 benötigt.'); return end
    if type(message)~='string' then return end; message=message:sub(1,Config.MaxMessageLength or 500); if message:gsub('%s','')=='' then return end
    for _,ticket in ipairs(tickets) do if ticket.id==tonumber(ticketId) and ticket.status=='open' then
        ticket.messages[#ticket.messages+1]={sender='Admin '..(GetPlayerName(src) or src),text=message,time=os.date('%H:%M')}
        TriggerClientEvent('rlrp_admin:playerTicketMessage',ticket.playerId,ticket.id,message,GetPlayerName(src) or 'Admin')
        for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if loggedIn[id] and adminLevel(id)>=1 then TriggerClientEvent('rlrp_admin:ticketUpdate',id,publicTicket(ticket)) end end
        return
    end end
    notify(src,'Ticket nicht gefunden oder bereits geschlossen.')
end)
RegisterNetEvent('rlrp_admin:claimTicket',function(ticketId)
    local src=source; if not authorized(src,2) then return end
    for _,ticket in ipairs(tickets) do if ticket.id==tonumber(ticketId) and ticket.status=='open' then ticket.assigned=GetPlayerName(src) or tostring(src); sendTicketSnapshot(src); return end end
end)
RegisterNetEvent('rlrp_admin:closeTicket',function(ticketId)
    local src=source; if not authorized(src,2) then return end
    for _,ticket in ipairs(tickets) do if ticket.id==tonumber(ticketId) and ticket.status=='open' then
        ticket.status='closed'; notify(ticket.playerId,('Dein Report #%d wurde geschlossen.'):format(ticket.id))
        for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if loggedIn[id] and adminLevel(id)>=1 then sendTicketSnapshot(id) end end
        sendTicketCounts(); return
    end end
end)

-- Load saved admin levels and allow server console to bootstrap the first level-7 account.
CreateThread(function()
    for _,raw in ipairs(GetPlayers()) do local src=tonumber(raw); local ids=identifiers(src); local key=ids.license or ids.fivem; if key then adminLevels[key]=GetResourceKvpInt('admin:'..key) end end
    local index=0
    while true do
        local key=GetResourceKvpString(('admin_key_%d'):format(index)); if not key then break end
        adminLevels[key]=GetResourceKvpInt('admin:'..key); index=index+1
    end
end)
RegisterCommand('rlrp_setadmin',function(src,args)
    if src~=0 then print('Dieser Bootstrap-Befehl ist nur in der Serverkonsole erlaubt.'); return end
    local key=args[1]; local level=tonumber(args[2])
    if not key or not (key:sub(1,8)=='license:' or key:sub(1,7)=='fivem:') or not level or level<1 or level>7 or level%1~=0 then print('Nutzung: rlrp_setadmin license:IDENTIFIER 7'); return end
    adminLevels[key]=level; SetResourceKvpInt('admin:'..key,level)
    local index=0; while GetResourceKvpString(('admin_key_%d'):format(index)) do index=index+1 end; SetResourceKvp('admin_key_'..index,key)
    print(('Admin-Level %d für %s gespeichert.'):format(level,key))
end,true)

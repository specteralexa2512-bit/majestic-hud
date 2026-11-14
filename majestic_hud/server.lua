local tickets, nextTicketId = {}, 1
local loggedIn, adminLevels, adminModes, muted = {}, {}, {}, {}
local function trim(s) return (tostring(s or ''):gsub('^%s+',''):gsub('%s+$','')) end
local function getIds(src)
    local ids={}; for _,id in ipairs(GetPlayerIdentifiers(src)) do if id:sub(1,8)=='license:' then ids.license=id elseif id:sub(1,6)=='fivem:' then ids.fivem=id end end; return ids
end
local function playerLevel(src)
    if src==0 then return 7 end
    local ids=getIds(src)
    for _,id in pairs(ids) do local configured=tonumber((Config.BootstrapAdmins or {})[id]); if configured then return configured end end
    return tonumber(adminLevels[ids.license or ids.fivem]) or 0
end
local function allowed(src,level) return src>0 and loggedIn[src]==true and playerLevel(src)>=level end
local function notice(src,text) TriggerClientEvent('rlrp_admin:notice',src,text) end
local function countOpen() local n=0; for _,t in ipairs(tickets) do if t.status=='open' then n=n+1 end end; return n end
local function serial(t) return {id=t.id,playerId=t.playerId,playerName=t.playerName,text=t.text,status=t.status,assigned=t.assigned,created=t.created,messages=t.messages} end
local function snapshot(src) local out={}; for _,t in ipairs(tickets) do if t.status=='open' then out[#out+1]=serial(t) end end; TriggerClientEvent('rlrp_admin:ticketSnapshot',src,out) end
local function push(t)
    for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if id and loggedIn[id] and playerLevel(id)>=1 then TriggerClientEvent('rlrp_admin:ticketUpdate',id,serial(t)); TriggerClientEvent('rlrp_admin:ticketCount',id,countOpen()) end end
end
local function onlineAdmins(minimum, event, ...)
    for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if id and loggedIn[id] and playerLevel(id)>=(minimum or 1) then TriggerClientEvent(event,id,...) end end
end
local function broadcastOnline() TriggerClientEvent('rlrp_hud:setOnlineCount',-1,#GetPlayers()) end

RegisterNetEvent('rlrp_hud:requestOnlineCount',function() TriggerClientEvent('rlrp_hud:setOnlineCount',source,#GetPlayers()) end)
AddEventHandler('playerJoining',function() SetTimeout(1000,broadcastOnline) end)
AddEventHandler('playerDropped',function() local src=source; loggedIn[src]=nil; adminModes[src]=nil; muted[src]=nil; SetTimeout(1000,broadcastOnline) end)
AddEventHandler('chatMessage',function(src,_,message) if muted[src] then CancelEvent(); notice(src,'Du bist stummgeschaltet und kannst den Chat nicht benutzen.') end end)
CreateThread(function() while true do broadcastOnline(); for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if id and loggedIn[id] and playerLevel(id)>=1 then TriggerClientEvent('rlrp_admin:ticketCount',id,countOpen()) end end; Wait(10000) end end)

RegisterNetEvent('rlrp_admin:login',function()
    local src=source; local level=playerLevel(src)
    if level<1 then loggedIn[src]=nil; TriggerClientEvent('rlrp_admin:loginResult',src,false,0,'Keine Adminrechte erkannt. Prüfe server.cfg/Identifier und starte die Resource neu.'); return end
    loggedIn[src]=true; TriggerClientEvent('rlrp_admin:loginResult',src,true,level,('Admin-Login erfolgreich · Level %d'):format(level)); TriggerClientEvent('rlrp_admin:ticketCount',src,countOpen()); snapshot(src)
end)
RegisterNetEvent('rlrp_admin:requestTickets',function() local src=source; if not allowed(src,1) then notice(src,'Bitte /adminlogin eingeben.'); return end; snapshot(src) end)
RegisterNetEvent('rlrp_admin:report',function(text)
    local src=source; local clean=trim(text):sub(1,tonumber(Config.MaxReportLength) or 500)
    if clean=='' then notice(src,'Nutzung: /report <Anliegen>'); return end
    if countOpen()>=(tonumber(Config.MaxOpenTickets) or 100) then notice(src,'Zu viele offene Reports. Bitte später erneut versuchen.'); return end
    local t={id=nextTicketId,playerId=src,playerName=GetPlayerName(src) or ('Spieler '..src),text=clean,status='open',created=os.date('%d.%m.%Y %H:%M'),messages={}}
    nextTicketId=nextTicketId+1; tickets[#tickets+1]=t; notice(src,('Report #%d gesendet. Nutze /reply <Nachricht> für eine Antwort.'):format(t.id)); onlineAdmins(1,'rlrp_admin:notice',('Neuer Report #%d von %s (ID %d)'):format(t.id,t.playerName,src)); push(t)
end)
RegisterNetEvent('rlrp_admin:replyPlayer',function(text)
    local src=source; local clean=trim(text):sub(1,tonumber(Config.MaxMessageLength) or 500); if clean=='' then notice(src,'Nutzung: /reply <Nachricht>'); return end
    for i=#tickets,1,-1 do local t=tickets[i]; if t.playerId==src and t.status=='open' then t.messages[#t.messages+1]={sender='Spieler',text=clean,time=os.date('%H:%M')}; push(t); return end end
    notice(src,'Kein offenes Report-Ticket gefunden.')
end)
RegisterNetEvent('rlrp_admin:replyTicket',function(ticketId,message)
    local src=source; if not allowed(src,2) then notice(src,'Ticketantworten benötigen Admin-Level 2.'); return end
    local clean=trim(message):sub(1,tonumber(Config.MaxMessageLength) or 500); if clean=='' then return end
    for _,t in ipairs(tickets) do if t.id==tonumber(ticketId) and t.status=='open' then t.messages[#t.messages+1]={sender='Admin '..(GetPlayerName(src) or src),text=clean,time=os.date('%H:%M')}; notice(t.playerId,('Admin antwortet auf Report #%d: %s'):format(t.id,clean)); push(t); return end end
    notice(src,'Ticket nicht gefunden oder geschlossen.')
end)
RegisterNetEvent('rlrp_admin:claimTicket',function(ticketId) local src=source; if not allowed(src,2) then return end; for _,t in ipairs(tickets) do if t.id==tonumber(ticketId) and t.status=='open' then t.assigned=GetPlayerName(src); push(t); return end end end)
RegisterNetEvent('rlrp_admin:closeTicket',function(ticketId)
    local src=source; if not allowed(src,2) then notice(src,'Tickets schließen benötigt Admin-Level 2.'); return end
    for _,t in ipairs(tickets) do if t.id==tonumber(ticketId) and t.status=='open' then t.status='closed'; notice(t.playerId,('Report #%d wurde geschlossen.'):format(t.id)); push(t); return end end
end)
RegisterNetEvent('rlrp_admin:toggleMode',function()
    local src=source; if not allowed(src,2) then notice(src,'/admin benötigt Admin-Level 2 und /adminlogin.'); return end
    adminModes[src]=not adminModes[src]; local modes={}; for id,on in pairs(adminModes) do if on then modes[id]=GetPlayerName(id) or ('ID '..id) end end
    TriggerClientEvent('rlrp_admin:modeSnapshot',-1,modes); TriggerClientEvent('rlrp_admin:modeState',-1,adminModes[src],src,GetPlayerName(src))
end)

RegisterNetEvent('rlrp_admin:giveadmin',function(targetArg,levelArg)
    local src=source; if not allowed(src,7) then notice(src,'/giveadmin ist Level 7 vorbehalten.'); return end
    local target,level=tonumber(targetArg),tonumber(levelArg) or 1
    if not target or not GetPlayerName(target) or level%1~=0 or level<1 or level>7 then notice(src,'Nutzung: /giveadmin <Spieler-ID> [Level 1-7]'); return end
    local ids=getIds(target); local key=ids.license or ids.fivem; if not key then notice(src,'Keine license:/fivem:-Kennung gefunden.'); return end
    adminLevels[key]=level; SetResourceKvpInt('adminlevel:'..key,level); local known=GetResourceKvpString('adminkey:'..key); if not known then SetResourceKvp('adminkey:'..key,key) end
    notice(src,('%s (ID %d) erhielt Admin-Level %d.'):format(GetPlayerName(target),target,level)); notice(target,('Du hast Admin-Level %d erhalten. Bitte /adminlogin eingeben.'):format(level))
end)

RegisterNetEvent('rlrp_admin:moderate',function(action,targetArg,arg1,arg2,arg3)
    local src=source; if not allowed(src,2) then notice(src,'Dieser Befehl benötigt Admin-Level 2 und /adminlogin.'); return end
    local target=tonumber(targetArg); local targetOnline=target and GetPlayerName(target)
    local function invalid() notice(src,'Ungültige Spieler-ID oder Argumente.') end
    if action=='spawnwep' then
        local weapon=tostring(targetArg or ''):upper(); if not weapon:match('^WEAPON_[A-Z0-9_]+$') then notice(src,'Nutzung: /spawnwep WEAPON_NAME [ammo]'); return end
        local ammo=math.max(1,math.min(9999,tonumber(arg1) or 9999)); TriggerClientEvent('rlrp_admin:spawnWeapon',src,weapon,ammo); return
    elseif action=='spawncar' then
        local model=tostring(targetArg or ''):lower(); if not model:match('^[a-z0-9_]+$') then notice(src,'Nutzung: /spawncar [vehicleName] [color1] [color2]'); return end
        TriggerClientEvent('rlrp_admin:spawnVehicle',src,model,tonumber(arg1) or 0,tonumber(arg2) or 0); return
    end
    if action=='mute' or action=='unmute' then
        if not targetOnline then invalid(); return end
        muted[target]=action=='mute'; TriggerClientEvent('rlrp_admin:muteState',target,muted[target]); notice(src,('%s (ID %d) %s.'):format(GetPlayerName(target),target,muted[target] and 'stummgeschaltet' or 'entstummgeschaltet')); return
    elseif action=='setkevlar' or action=='sethealth' then
        if not targetOnline then invalid(); return end; local amount=tonumber(arg1); if not amount then notice(src,'Menge muss eine Zahl sein.'); return end
        if action=='setkevlar' then amount=math.max(0,math.min(100,amount)); TriggerClientEvent('rlrp_admin:setVitals',target,nil,amount) else amount=math.max(100,math.min(200,amount)); TriggerClientEvent('rlrp_admin:setVitals',target,amount,nil) end
        notice(src,'Spielerstatus aktualisiert.'); return
    elseif action=='goto' or action=='gethere' then
        if not targetOnline then invalid(); return end
        if action=='goto' then local ped=GetPlayerPed(target); if ped==0 then invalid(); return end; local c=GetEntityCoords(ped); TriggerClientEvent('rlrp_admin:teleport',src,c.x,c.y,c.z,GetEntityHeading(ped))
        else local ped=GetPlayerPed(src); if ped==0 then invalid(); return end; local c=GetEntityCoords(ped); TriggerClientEvent('rlrp_admin:teleport',target,c.x,c.y,c.z,GetEntityHeading(ped)) end; return
    elseif action=='kick' or action=='ban' then
        if not targetOnline then invalid(); return end; local reason=trim(arg1); if reason=='' then reason='Kein Grund angegeben' end
        if action=='ban' then
            local ids=getIds(target); local key=ids.license or ids.fivem; if key then SetResourceKvp('rlrpban:'..key,reason); local n=GetResourceKvpInt('rlrpban_count')+1; SetResourceKvpInt('rlrpban_count',n); SetResourceKvp(('rlrpban_key_%d'):format(n),key) end
            DropPlayer(target,('Gebannt: %s'):format(reason)); notice(src,('%s wurde gebannt: %s'):format(GetPlayerName(target),reason))
        else DropPlayer(target,('Vom Server gekickt: %s'):format(reason)); notice(src,('%s wurde gekickt: %s'):format(GetPlayerName(target),reason)) end
        return
    end
    notice(src,'Unbekannte Adminaktion.')
end)

AddEventHandler('playerConnecting',function(name,setKickReason,deferrals)
    local src=source; deferrals.defer(); Wait(0); local ids=getIds(src); local reason=(ids.license and GetResourceKvpString('rlrpban:'..ids.license)) or (ids.fivem and GetResourceKvpString('rlrpban:'..ids.fivem))
    if reason then deferrals.done(('Du bist gebannt. Grund: %s'):format(reason)) else deferrals.done() end
end)

AddEventHandler('onResourceStart',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for i=1,GetResourceKvpInt('rlrpban_count') do local key=GetResourceKvpString(('rlrpban_key_%d'):format(i)); if key then local reason=GetResourceKvpString('rlrpban:'..key); if reason then print(('[RLAdmin] Ban aktiv: %s (%s)'):format(key,reason)) end end end
    for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); local ids=getIds(id); local key=ids.license or ids.fivem; if key then local level=GetResourceKvpInt('adminlevel:'..key); if level>0 then adminLevels[key]=level end end end
end)

RegisterCommand('rlrp_setadmin',function(src,args)
    if src~=0 then return end; local key=args[1]; local level=tonumber(args[2]); if not key or not level or level<1 or level>7 then print('Nutzung: rlrp_setadmin license:...|fivem:... 1-7'); return end
    Config.BootstrapAdmins[key]=level; print(('Admin-Level %d für %s gesetzt; config.lua nach Neustart dauerhaft pflegen.'):format(level,key))
end,true)

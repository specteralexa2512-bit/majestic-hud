local tickets,nextTicketId={},1
local loggedIn,adminLevels,adminModes,muted={},{},{},{}
local function trim(s) return (tostring(s or ''):gsub('^%s+',''):gsub('%s+$','')) end
local function idsFor(src) local out={}; for _,v in ipairs(GetPlayerIdentifiers(src)) do if v:sub(1,8)=='license:' then out.license=v elseif v:sub(1,6)=='fivem:' then out.fivem=v end end; return out end
local function levelFor(src)
    if src==0 then return 7 end; local ids=idsFor(src)
    for _,id in pairs(ids) do local n=tonumber((Config.BootstrapAdmins or {})[id]); if n then return n end end
    for _,id in pairs(ids) do local n=GetResourceKvpInt('adminlevel:'..id); if n and n>0 then return n end end
    return 0
end
local function allowed(src,n) return src>0 and loggedIn[src]==true and levelFor(src)>=n end
local function notify(src,msg) TriggerClientEvent('rlrp_admin:notice',src,tostring(msg)) end
local function openCount() local n=0; for _,t in ipairs(tickets) do if t.status=='open' then n=n+1 end end; return n end
local function serialize(t) return {id=t.id,playerId=t.playerId,playerName=t.playerName,text=t.text,status=t.status,assigned=t.assigned,created=t.created,messages=t.messages} end
local function sendSnapshot(src) local list={}; for _,t in ipairs(tickets) do if t.status=='open' then list[#list+1]=serialize(t) end end; TriggerClientEvent('rlrp_admin:ticketSnapshot',src,list); TriggerClientEvent('rlrp_admin:ticketCount',src,openCount()) end
local function pushTicket(t)
    for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if id and loggedIn[id] and levelFor(id)>=1 then TriggerClientEvent('rlrp_admin:ticketUpdate',id,serialize(t)); TriggerClientEvent('rlrp_admin:ticketCount',id,openCount()) end end
end
local function notifyAdmins(message)
    for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if id and loggedIn[id] and levelFor(id)>=1 then notify(id,message) end end
end
local function onlineCount() TriggerClientEvent('rlrp_hud:setOnlineCount',-1,#GetPlayers()) end
RegisterNetEvent('rlrp_hud:requestOnlineCount',function() TriggerClientEvent('rlrp_hud:setOnlineCount',source,#GetPlayers()) end)
AddEventHandler('playerJoining',function() SetTimeout(1000,onlineCount) end)
AddEventHandler('playerDropped',function() local src=source; loggedIn[src]=nil; adminModes[src]=nil; muted[src]=nil; SetTimeout(1000,onlineCount) end)
AddEventHandler('chatMessage',function(src,_,message) if muted[src] then CancelEvent(); notify(src,'Chat gesperrt: Du bist stummgeschaltet.') end end)
CreateThread(function() while true do onlineCount(); for _,raw in ipairs(GetPlayers()) do local id=tonumber(raw); if id and loggedIn[id] and levelFor(id)>=1 then TriggerClientEvent('rlrp_admin:ticketCount',id,openCount()) end end; Wait(10000) end end)

RegisterNetEvent('rlrp_admin:login',function()
    local src=source; local lvl=levelFor(src)
    if lvl<1 then loggedIn[src]=nil; TriggerClientEvent('rlrp_admin:loginResult',src,false,0,'Keine Adminrechte erkannt.'); return end
    loggedIn[src]=true; TriggerClientEvent('rlrp_admin:loginResult',src,true,lvl,('Admin-Login erfolgreich · Level %d'):format(lvl)); sendSnapshot(src)
end)
RegisterNetEvent('rlrp_admin:requestTickets',function() if allowed(source,1) then sendSnapshot(source) else notify(source,'Bitte /adminlogin eingeben.') end end)
RegisterNetEvent('rlrp_admin:report',function(text)
    local src=source; local clean=trim(text):sub(1,tonumber(Config.MaxReportLength) or 500)
    if clean=='' then notify(src,'Nutzung: /report <Anliegen>'); return end
    if openCount()>=(tonumber(Config.MaxOpenTickets) or 100) then notify(src,'Zu viele offene Reports. Bitte später erneut versuchen.'); return end
    local ticket={id=nextTicketId,playerId=src,playerName=GetPlayerName(src) or ('Spieler '..src),text=clean,status='open',created=os.date('%d.%m.%Y %H:%M'),messages={}}
    nextTicketId=nextTicketId+1; tickets[#tickets+1]=ticket; notify(src,('Report #%d gesendet.'):format(ticket.id)); notifyAdmins(('Neuer Report #%d von %s (ID %d)'):format(ticket.id,ticket.playerName,src)); pushTicket(ticket)
end)
RegisterNetEvent('rlrp_admin:replyPlayer',function(text)
    local src=source; local clean=trim(text):sub(1,tonumber(Config.MaxMessageLength) or 500); if clean=='' then notify(src,'Nutzung: /reply <Nachricht>'); return end
    for i=#tickets,1,-1 do local t=tickets[i]; if t.playerId==src and t.status=='open' then t.messages[#t.messages+1]={sender='Spieler',text=clean,time=os.date('%H:%M')}; pushTicket(t); notifyAdmins(('Neue Nachricht zu Report #%d'):format(t.id)); return end end
    notify(src,'Du hast kein offenes Report-Ticket.')
end)
RegisterNetEvent('rlrp_admin:replyTicket',function(ticketId,message)
    local src=source; if not allowed(src,2) then notify(src,'Antworten benötigen Admin-Level 2.'); return end
    local clean=trim(message):sub(1,tonumber(Config.MaxMessageLength) or 500); if clean=='' then return end
    for _,t in ipairs(tickets) do if t.id==tonumber(ticketId) and t.status=='open' then t.messages[#t.messages+1]={sender='Admin '..(GetPlayerName(src) or src),text=clean,time=os.date('%H:%M')}; notify(t.playerId,('Admin antwortet auf Report #%d: %s'):format(t.id,clean)); pushTicket(t); return end end
    notify(src,'Ticket nicht gefunden oder geschlossen.')
end)
RegisterNetEvent('rlrp_admin:claimTicket',function(ticketId) local src=source; if not allowed(src,2) then return end; for _,t in ipairs(tickets) do if t.id==tonumber(ticketId) and t.status=='open' then t.assigned=GetPlayerName(src); pushTicket(t); return end end end)
RegisterNetEvent('rlrp_admin:closeTicket',function(ticketId)
    local src=source; if not allowed(src,2) then notify(src,'Schließen benötigt Level 2.'); return end
    for _,t in ipairs(tickets) do if t.id==tonumber(ticketId) and t.status=='open' then t.status='closed'; notify(t.playerId,('Report #%d geschlossen.'):format(t.id)); pushTicket(t); return end end
end)
RegisterNetEvent('rlrp_admin:toggleMode',function()
    local src=source; if not allowed(src,2) then notify(src,'/admin benötigt Level 2 und /adminlogin.'); return end
    adminModes[src]=not adminModes[src]; local list={}; for id,on in pairs(adminModes) do if on then list[id]=GetPlayerName(id) or ('ID '..id) end end; TriggerClientEvent('rlrp_admin:modeSnapshot',-1,list)
end)
RegisterNetEvent('rlrp_admin:giveadmin',function(targetArg,levelArg)
    local src=source; if not allowed(src,7) then notify(src,'/giveadmin ist Level 7 vorbehalten.'); return end
    local target,lvl=tonumber(targetArg),tonumber(levelArg) or 1; if not target or not GetPlayerName(target) or lvl%1~=0 or lvl<1 or lvl>7 then notify(src,'Nutzung: /giveadmin ID [Level 1-7]'); return end
    local found=false; for _,id in ipairs(GetPlayerIdentifiers(target)) do if id:sub(1,8)=='license:' or id:sub(1,6)=='fivem:' then SetResourceKvpInt('adminlevel:'..id,lvl); found=true end end
    if not found then notify(src,'Keine persistente Identifier-ID gefunden.'); return end; notify(src,('Admin-Level %d an %s vergeben.'):format(lvl,GetPlayerName(target))); notify(target,('Du hast Admin-Level %d. Nutze /adminlogin.'):format(lvl))
end)
RegisterNetEvent('rlrp_admin:moderate',function(action,targetArg,arg1,arg2,reason)
    local src=source; if not allowed(src,2) then notify(src,'Dieser Befehl benötigt Admin-Level 2 und /adminlogin.'); return end
    local target=tonumber(targetArg); local targetName=target and GetPlayerName(target)
    if action=='spawnwep' then local weapon=tostring(targetArg or ''):upper(); if not weapon:match('^WEAPON_[A-Z0-9_]+$') then notify(src,'Nutzung: /spawnwep WEAPON_NAME [ammo]'); return end; TriggerClientEvent('rlrp_admin:spawnWeapon',src,weapon,tonumber(arg1) or 9999); return end
    if action=='spawncar' then local model=tostring(targetArg or ''):lower(); if not model:match('^[a-z0-9_]+$') then notify(src,'Nutzung: /spawncar model [color1] [color2]'); return end; TriggerClientEvent('rlrp_admin:spawnVehicle',src,model,tonumber(arg1) or 0,tonumber(arg2) or 0); return end
    if not targetName then notify(src,'Spieler-ID nicht online.'); return end
    if action=='mute' or action=='unmute' then muted[target]=action=='mute'; TriggerClientEvent('rlrp_admin:muteState',target,muted[target]); notify(src,('%s (ID %d) %s.'):format(targetName,target,muted[target] and 'stummgeschaltet' or 'entstummgeschaltet')); return end
    if action=='setkevlar' or action=='sethealth' then local amount=tonumber(arg1); if not amount then notify(src,'Menge muss eine Zahl sein.'); return end; if action=='setkevlar' then TriggerClientEvent('rlrp_admin:setVitals',target,nil,math.max(0,math.min(100,amount))) else TriggerClientEvent('rlrp_admin:setVitals',target,math.max(100,math.min(200,amount)),nil) end; notify(src,'Spielerstatus aktualisiert.'); return end
    if action=='goto' or action=='gethere' then local who=action=='goto' and target or src; local ped=GetPlayerPed(who); if ped==0 then notify(src,'Spielerposition nicht verfügbar.'); return end; local c=GetEntityCoords(ped); local heading=GetEntityHeading(ped); local dest=action=='goto' and src or target; TriggerClientEvent('rlrp_admin:teleport',dest,c.x,c.y,c.z,heading); return end
    if action=='kick' or action=='ban' then local why=trim(reason); if why=='' then why='Kein Grund angegeben' end; if action=='ban' then for _,identifier in ipairs(GetPlayerIdentifiers(target)) do if identifier:sub(1,8)=='license:' or identifier:sub(1,6)=='fivem:' then SetResourceKvp('rlrpban:'..identifier,why) end end end; DropPlayer(target,(action=='ban' and 'Gebannt: ' or 'Vom Server gekickt: ')..why); notify(src,('%s (ID %d) wurde entfernt: %s'):format(targetName,target,why)); return end
    notify(src,'Unbekannte Adminaktion.')
end)
AddEventHandler('playerConnecting',function(_,setKickReason,deferrals)
    local src=source; deferrals.defer(); Wait(0); local reason
    for _,id in ipairs(GetPlayerIdentifiers(src)) do if id:sub(1,8)=='license:' or id:sub(1,6)=='fivem:' then reason=GetResourceKvpString('rlrpban:'..id); if reason then break end end end
    if reason then deferrals.done(('Du bist gebannt. Grund: %s'):format(reason)) else deferrals.done() end
end)
RegisterCommand('rlrp_setadmin',function(src,args) if src~=0 then return end; local id,lvl=args[1],tonumber(args[2]); if not id or not lvl or lvl<1 or lvl>7 then print('Nutzung: rlrp_setadmin license:...|fivem:... 1-7'); return end; SetResourceKvpInt('adminlevel:'..id,lvl); print(('Admin-Level %d für %s gespeichert.'):format(lvl,id)) end,true)

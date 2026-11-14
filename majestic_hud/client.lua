local ESX = exports['es_extended']:getSharedObject()
local playerData = ESX.GetPlayerData() or {}
local onlineCount, wasInVehicle, lastPlayerUpdate = 0, false, 0
local adminLevel, adminLoggedIn, adminMode, isMuted = 0, false, false, false
local visibleAdmins = {}

local weatherLabels = { EXTRASUNNY='Sonnig', CLEAR='Klar', NEUTRAL='Klar', CLOUDS='Bewölkt', OVERCAST='Stark bewölkt', SMOG='Dunstig', FOGGY='Neblig', CLEARING='Aufklarend', RAIN='Regen', THUNDER='Gewitter', SNOW='Schnee', SNOWLIGHT='Leichter Schnee', BLIZZARD='Schneesturm', XMAS='Schnee', HALLOWEEN='Nebel' }
local weatherTemps = { EXTRASUNNY=28, CLEAR=25, NEUTRAL=24, CLOUDS=21, OVERCAST=19, SMOG=22, FOGGY=17, CLEARING=20, RAIN=17, THUNDER=18, SNOW=1, SNOWLIGHT=3, BLIZZARD=-4, XMAS=0, HALLOWEEN=15 }

RegisterNetEvent('esx:playerLoaded', function(data) playerData = data or ESX.GetPlayerData() or {} end)
RegisterNetEvent('esx:setJob', function(job) playerData.job = job end)
RegisterNetEvent('esx:setAccountMoney', function(account)
    playerData.accounts = playerData.accounts or {}
    for i, current in pairs(playerData.accounts) do if current.name == account.name then playerData.accounts[i] = account; return end end
    table.insert(playerData.accounts, account)
end)
RegisterNetEvent('rlrp_hud:setOnlineCount', function(count) onlineCount = math.max(0, tonumber(count) or 0) end)

local function notify(text, kind)
    TriggerEvent('chat:addMessage', { color = kind == 'error' and {255,75,90} or {255,190,75}, args = {'Admin/Report', tostring(text)} })
end
RegisterNetEvent('rlrp_admin:notice', notify)
RegisterNetEvent('rlrp_admin:loginResult', function(ok, level, message)
    adminLoggedIn, adminLevel = ok == true, tonumber(level) or 0
    SendNUIMessage({ action='adminAccess', loggedIn=adminLoggedIn, level=adminLevel })
    if message then notify(message, not ok) end
end)
RegisterNetEvent('rlrp_admin:ticketCount', function(count) SendNUIMessage({action='ticketCount',count=tonumber(count) or 0}) end)
RegisterNetEvent('rlrp_admin:ticketSnapshot', function(list) SendNUIMessage({action='ticketSnapshot',tickets=list or {}}) end)
RegisterNetEvent('rlrp_admin:ticketUpdate', function(ticket) SendNUIMessage({action='ticketUpdate',ticket=ticket}) end)
RegisterNetEvent('rlrp_admin:muteState', function(value) isMuted = value == true; notify(isMuted and 'Du bist stummgeschaltet.' or 'Deine Stummschaltung wurde aufgehoben.', isMuted) end)
RegisterNetEvent('rlrp_admin:modeState', function(value, sid, name)
    sid = tonumber(sid)
    if sid == GetPlayerServerId(PlayerId()) then adminMode = value == true end
    if value then visibleAdmins[sid] = name or ('ID '..tostring(sid)) else visibleAdmins[sid] = nil end
end)
RegisterNetEvent('rlrp_admin:modeSnapshot', function(list) visibleAdmins = list or {} end)
RegisterNetEvent('rlrp_admin:teleport', function(x,y,z,heading)
    local ped=PlayerPedId(); RequestCollisionAtCoord(x+0.0,y+0.0,z+0.0); SetEntityCoords(ped,x+0.0,y+0.0,z+0.5,false,false,false,false); if heading then SetEntityHeading(ped,heading+0.0) end
end)
RegisterNetEvent('rlrp_admin:setVitals', function(health, armor)
    local ped=PlayerPedId(); if health then local value=math.max(100,math.min(200,tonumber(health) or 100)); if not IsEntityDead(ped) then SetEntityHealth(ped,value) end end; if armor then SetPedArmour(ped,math.max(0,math.min(100,tonumber(armor) or 0))) end
end)
RegisterNetEvent('rlrp_admin:spawnWeapon', function(name, ammo)
    local ped=PlayerPedId(); local hash=GetHashKey(name); if not IsWeaponValid(hash) then notify('Ungültiger Waffenname.',true); return end; GiveWeaponToPed(ped,hash,math.max(1,math.min(9999,tonumber(ammo) or 9999)),false,true)
end)
RegisterNetEvent('rlrp_admin:spawnVehicle', function(modelName,color1,color2)
    local hash=GetHashKey(modelName); if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then notify('Ungültiges Fahrzeugmodell.',true); return end
    RequestModel(hash); local timeout=GetGameTimer()+10000; while not HasModelLoaded(hash) and GetGameTimer()<timeout do Wait(0) end
    if not HasModelLoaded(hash) then notify('Fahrzeugmodell konnte nicht geladen werden.',true); return end
    local ped=PlayerPedId(); local coords=GetOffsetFromEntityInWorldCoords(ped,0.0,3.0,0.0); local vehicle=CreateVehicle(hash,coords.x,coords.y,coords.z,GetEntityHeading(ped),true,false)
    if vehicle and vehicle~=0 then SetVehicleColours(vehicle,tonumber(color1) or 0,tonumber(color2) or 0); SetPedIntoVehicle(ped,vehicle,-1); SetEntityAsMissionEntity(vehicle,true,true) end
    SetModelAsNoLongerNeeded(hash)
end)

local function getAccountMoney(name) for _,account in pairs(playerData.accounts or {}) do if account.name==name then return account.money or 0 end end; return 0 end
local function getGameWeather()
    local a,b=GetPrevWeatherTypeHashName(),GetNextWeatherTypeHashName(); local hash=GetWeatherTypeTransition()>=0.5 and b or a; local name='CLEAR'
    for key in pairs(weatherLabels) do if GetHashKey(key)==hash then name=key; break end end
    local hour,temp=GetClockHours(),weatherTemps[name] or 22; if hour<6 or hour>=21 then temp=temp-5 elseif hour<9 or hour>=17 then temp=temp-2 end
    return weatherLabels[name] or 'Wetter',math.floor(temp+0.5)
end
local function sendPlayerUpdate()
    local job,grade='Arbeitslos',''; if playerData.job then job=playerData.job.label or playerData.job.name or job; grade=playerData.job.grade_label or '' end
    local weather,temp=getGameWeather(); SendNUIMessage({action='playerUpdate',id=GetPlayerServerId(PlayerId()),online=onlineCount,job=job,grade=grade,cash=getAccountMoney('money'),bank=getAccountMoney('bank'),weather=weather,temperature=temp})
end

RegisterCommand('adminlogin',function() TriggerServerEvent('rlrp_admin:login') end,false)
RegisterCommand('admin',function() TriggerServerEvent('rlrp_admin:toggleMode') end,false)
RegisterCommand('giveadmin',function(_,args) TriggerServerEvent('rlrp_admin:giveadmin',args[1],args[2]) end,false)
RegisterCommand('report',function(_,args) local text=table.concat(args,' '); if text=='' then notify('Nutzung: /report <Anliegen>',true) else TriggerServerEvent('rlrp_admin:report',text) end end,false)
RegisterCommand('reply',function(_,args) local text=table.concat(args,' '); if text=='' then notify('Nutzung: /reply <Nachricht>',true) else TriggerServerEvent('rlrp_admin:replyPlayer',text) end end,false)
RegisterCommand('mute',function(_,args) TriggerServerEvent('rlrp_admin:moderate','mute',args[1]) end,false)
RegisterCommand('unmute',function(_,args) TriggerServerEvent('rlrp_admin:moderate','unmute',args[1]) end,false)
RegisterCommand('spawnwep',function(_,args) TriggerServerEvent('rlrp_admin:moderate','spawnwep',args[1],args[2]) end,false)
RegisterCommand('spawncar',function(_,args) TriggerServerEvent('rlrp_admin:moderate','spawncar',args[1],args[2],args[3]) end,false)
RegisterCommand('setkevlar',function(_,args) TriggerServerEvent('rlrp_admin:moderate','setkevlar',args[1],args[2]) end,false)
RegisterCommand('sethealth',function(_,args) TriggerServerEvent('rlrp_admin:moderate','sethealth',args[1],args[2]) end,false)
RegisterCommand('goto',function(_,args) TriggerServerEvent('rlrp_admin:moderate','goto',args[1]) end,false)
RegisterCommand('gethere',function(_,args) TriggerServerEvent('rlrp_admin:moderate','gethere',args[1]) end,false)
RegisterCommand('kick',function(_,args) TriggerServerEvent('rlrp_admin:moderate','kick',args[1],table.concat(args,' ',2)) end,false)
RegisterCommand('ban',function(_,args) TriggerServerEvent('rlrp_admin:moderate','ban',args[1],table.concat(args,' ',2)) end,false)

RegisterKeyMapping('rlrp_adminmenu','Admin-Menü öffnen','keyboard','F3')
RegisterCommand('rlrp_adminmenu',function()
    if not adminLoggedIn or adminLevel<1 then notify('Bitte zuerst /adminlogin eingeben.',true); return end
    SetNuiFocus(true,true); SendNUIMessage({action='openAdmin',level=adminLevel}); TriggerServerEvent('rlrp_admin:requestTickets')
end,false)
RegisterNUICallback('closeAdmin',function(_,cb) SetNuiFocus(false,false); cb({ok=true}) end)
RegisterNUICallback('requestTickets',function(_,cb) TriggerServerEvent('rlrp_admin:requestTickets'); cb({ok=true}) end)
RegisterNUICallback('ticketReply',function(data,cb) TriggerServerEvent('rlrp_admin:replyTicket',tonumber(data.ticketId),tostring(data.message or '')); cb({ok=true}) end)
RegisterNUICallback('ticketClose',function(data,cb) TriggerServerEvent('rlrp_admin:closeTicket',tonumber(data.ticketId)); cb({ok=true}) end)
RegisterNUICallback('ticketClaim',function(data,cb) TriggerServerEvent('rlrp_admin:claimTicket',tonumber(data.ticketId)); cb({ok=true}) end)

local function drawText3D(x,y,z,text)
    local onScreen,sx,sy=World3dToScreen2d(x,y,z); if not onScreen then return end
    SetTextScale(0.30,0.30); SetTextFont(4); SetTextProportional(1); SetTextCentre(true); SetTextColour(255,35,55,190); SetTextOutline(); BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(sx,sy)
end
CreateThread(function()
    TriggerServerEvent('rlrp_hud:requestOnlineCount')
    while true do
        local now,ped=GetGameTimer(),PlayerPedId(); if now-lastPlayerUpdate>=1000 then sendPlayerUpdate(); lastPlayerUpdate=now end
        local vehicle=GetVehiclePedIsIn(ped,false); local driver=vehicle~=0 and GetPedInVehicleSeat(vehicle,-1)==ped
        if driver then local speed=GetEntitySpeed(vehicle)*3.6; local gear=GetVehicleCurrentGear(vehicle); SendNUIMessage({action='vehicleUpdate',inVehicle=true,speed=speed,gear=gear==0 and (speed>1 and 'R' or 'N') or tostring(gear),fuel=GetVehicleFuelLevel(vehicle),rpm=GetVehicleCurrentRpm(vehicle)}); wasInVehicle=true elseif wasInVehicle then SendNUIMessage({action='vehicleUpdate',inVehicle=false}); wasInVehicle=false end
        for sid,name in pairs(visibleAdmins) do local player=GetPlayerFromServerId(tonumber(sid)); if player~=-1 then local target=GetPlayerPed(player); if DoesEntityExist(target) then local c=GetEntityCoords(target); drawText3D(c.x,c.y,c.z+1.15,('Administrator\n%s\nID: %s'):format(name,sid)) end end end
        Wait(driver and 50 or 200)
    end
end)

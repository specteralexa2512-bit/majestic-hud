local ESX = exports['es_extended']:getSharedObject()
local playerData = ESX.GetPlayerData() or {}
local onlineCount, wasInVehicle, lastPlayerUpdate = 0, false, 0
local adminLevel, adminLoggedIn, wasInAdminMode = 0, false, false
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

local function notify(text, error)
    TriggerEvent('chat:addMessage', { color = error and {255,75,90} or {255,190,75}, args = {'Admin/Report', tostring(text)} })
end
RegisterNetEvent('rlrp_admin:notice', function(text) notify(text) end)
RegisterNetEvent('rlrp_admin:loginResult', function(ok, level, message)
    adminLoggedIn, adminLevel = ok == true, tonumber(level) or 0
    SendNUIMessage({action='adminAccess', loggedIn=adminLoggedIn, level=adminLevel})
    if message then notify(message, not ok) end
end)
RegisterNetEvent('rlrp_admin:ticketCount', function(n) SendNUIMessage({action='ticketCount',count=tonumber(n) or 0}) end)
RegisterNetEvent('rlrp_admin:ticketSnapshot', function(list) SendNUIMessage({action='ticketSnapshot',tickets=list or {}}) end)
RegisterNetEvent('rlrp_admin:ticketUpdate', function(t) SendNUIMessage({action='ticketUpdate',ticket=t}) end)
RegisterNetEvent('rlrp_admin:muteState', function(muted) notify(muted and 'Du bist stummgeschaltet.' or 'Deine Stummschaltung wurde aufgehoben.', muted) end)
RegisterNetEvent('rlrp_admin:modeSnapshot', function(list) visibleAdmins=list or {} end)
RegisterNetEvent('rlrp_admin:teleport', function(x,y,z,heading)
    local ped=PlayerPedId(); RequestCollisionAtCoord(x+0.0,y+0.0,z+0.0); SetEntityCoords(ped,x+0.0,y+0.0,z+0.5,false,false,false,false); if heading then SetEntityHeading(ped,heading+0.0) end
end)
RegisterNetEvent('rlrp_admin:setVitals', function(health,armor)
    local ped=PlayerPedId(); if health and not IsEntityDead(ped) then SetEntityHealth(ped,math.max(100,math.min(200,tonumber(health) or 100))) end; if armor then SetPedArmour(ped,math.max(0,math.min(100,tonumber(armor) or 0))) end
end)
RegisterNetEvent('rlrp_admin:spawnWeapon', function(name,ammo)
    local hash=GetHashKey(name); if not IsWeaponValid(hash) then notify('Ungültiger Waffenname.',true); return end; GiveWeaponToPed(PlayerPedId(),hash,math.max(1,math.min(9999,tonumber(ammo) or 9999)),false,true)
end)
RegisterNetEvent('rlrp_admin:spawnVehicle', function(name,c1,c2)
    local hash=GetHashKey(name); if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then notify('Ungültiges Fahrzeugmodell.',true); return end
    RequestModel(hash); local deadline=GetGameTimer()+10000; while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(0) end
    if not HasModelLoaded(hash) then notify('Fahrzeugmodell konnte nicht geladen werden.',true); return end
    local ped=PlayerPedId(); local pos=GetOffsetFromEntityInWorldCoords(ped,0.0,3.0,0.0); local veh=CreateVehicle(hash,pos.x,pos.y,pos.z,GetEntityHeading(ped),true,false)
    if veh and veh~=0 then SetVehicleColours(veh,tonumber(c1) or 0,tonumber(c2) or 0); SetPedIntoVehicle(ped,veh,-1); SetEntityAsMissionEntity(veh,true,true) end; SetModelAsNoLongerNeeded(hash)
end)

local function getMoney(name) for _,a in pairs(playerData.accounts or {}) do if a.name==name then return a.money or 0 end end; return 0 end
local function weatherNow()
    local a,b=GetPrevWeatherTypeHashName(),GetNextWeatherTypeHashName(); local h=GetWeatherTypeTransition()>=0.5 and b or a; local key='CLEAR'
    for name in pairs(weatherLabels) do if GetHashKey(name)==h then key=name; break end end
    local hour,temp=GetClockHours(),weatherTemps[key] or 22; if hour<6 or hour>=21 then temp=temp-5 elseif hour<9 or hour>=17 then temp=temp-2 end
    return weatherLabels[key] or 'Wetter',math.floor(temp+0.5)
end
local function updateHud()
    local job,grade='Arbeitslos',''; if playerData.job then job=playerData.job.label or playerData.job.name or job; grade=playerData.job.grade_label or '' end
    local weather,temp=weatherNow(); SendNUIMessage({action='playerUpdate',id=GetPlayerServerId(PlayerId()),online=onlineCount,job=job,grade=grade,cash=getMoney('money'),bank=getMoney('bank'),weather=weather,temperature=temp})
end

RegisterCommand('adminlogin',function() TriggerServerEvent('rlrp_admin:login') end,false)
RegisterCommand('admin',function() TriggerServerEvent('rlrp_admin:toggleMode') end,false)
RegisterCommand('giveadmin',function(_,a) TriggerServerEvent('rlrp_admin:giveadmin',a[1],a[2]) end,false)
RegisterCommand('report',function(_,a) local text=table.concat(a,' '); if text=='' then notify('Nutzung: /report <Anliegen>',true) else TriggerServerEvent('rlrp_admin:report',text) end end,false)
RegisterCommand('reply',function(_,a) local text=table.concat(a,' '); if text=='' then notify('Nutzung: /reply <Nachricht>',true) else TriggerServerEvent('rlrp_admin:replyPlayer',text) end end,false)
local function moderate(action,args,reasonStart) TriggerServerEvent('rlrp_admin:moderate',action,args[1],args[2],args[3],reasonStart and table.concat(args,' ',reasonStart) or nil) end
RegisterCommand('mute',function(_,a) moderate('mute',a) end,false)
RegisterCommand('unmute',function(_,a) moderate('unmute',a) end,false)
RegisterCommand('spawnwep',function(_,a) moderate('spawnwep',a) end,false)
RegisterCommand('spawncar',function(_,a) moderate('spawncar',a) end,false)
RegisterCommand('setkevlar',function(_,a) moderate('setkevlar',a) end,false)
RegisterCommand('sethealth',function(_,a) moderate('sethealth',a) end,false)
RegisterCommand('goto',function(_,a) moderate('goto',a) end,false)
RegisterCommand('gethere',function(_,a) moderate('gethere',a) end,false)
RegisterCommand('kick',function(_,a) moderate('kick',a,2) end,false)
RegisterCommand('ban',function(_,a) moderate('ban',a,2) end,false)

RegisterKeyMapping('rlrp_adminmenu','Admin-Menü öffnen','keyboard','F3')
RegisterCommand('rlrp_adminmenu',function()
    if not adminLoggedIn or adminLevel<1 then notify('Bitte zuerst /adminlogin eingeben.',true); return end
    SetNuiFocus(true,true); SendNUIMessage({action='openAdmin',level=adminLevel}); TriggerServerEvent('rlrp_admin:requestTickets')
end,false)
RegisterNUICallback('closeAdmin',function(_,cb) SetNuiFocus(false,false); cb({ok=true}) end)
RegisterNUICallback('requestTickets',function(_,cb) TriggerServerEvent('rlrp_admin:requestTickets'); cb({ok=true}) end)
RegisterNUICallback('ticketReply',function(d,cb) TriggerServerEvent('rlrp_admin:replyTicket',tonumber(d.ticketId),tostring(d.message or '')); cb({ok=true}) end)
RegisterNUICallback('ticketClose',function(d,cb) TriggerServerEvent('rlrp_admin:closeTicket',tonumber(d.ticketId)); cb({ok=true}) end)
RegisterNUICallback('ticketClaim',function(d,cb) TriggerServerEvent('rlrp_admin:claimTicket',tonumber(d.ticketId)); cb({ok=true}) end)

local function drawAdminTag(x,y,z,text)
    local visible,sx,sy=World3dToScreen2d(x,y,z); if not visible then return end; SetTextScale(.30,.30); SetTextFont(4); SetTextCentre(true); SetTextColour(255,35,55,190); SetTextOutline(); BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(sx,sy)
end
CreateThread(function()
    TriggerServerEvent('rlrp_hud:requestOnlineCount')
    while true do
        local now,ped=GetGameTimer(),PlayerPedId(); if now-lastPlayerUpdate>=1000 then updateHud(); lastPlayerUpdate=now end
        local veh=GetVehiclePedIsIn(ped,false); local driver=veh~=0 and GetPedInVehicleSeat(veh,-1)==ped
        if driver then local sp=GetEntitySpeed(veh)*3.6; local gear=GetVehicleCurrentGear(veh); SendNUIMessage({action='vehicleUpdate',inVehicle=true,speed=sp,gear=gear==0 and (sp>1 and 'R' or 'N') or tostring(gear),fuel=GetVehicleFuelLevel(veh),rpm=GetVehicleCurrentRpm(veh)}); wasInVehicle=true elseif wasInVehicle then SendNUIMessage({action='vehicleUpdate',inVehicle=false}); wasInVehicle=false end
        for sid,name in pairs(visibleAdmins) do local player=GetPlayerFromServerId(tonumber(sid)); if player~=-1 then local target=GetPlayerPed(player); if DoesEntityExist(target) then local c=GetEntityCoords(target); drawAdminTag(c.x,c.y,c.z+1.15,('Administrator\n%s\nID: %s'):format(name,sid)) end end end
        Wait(driver and 50 or 200)
    end
end)

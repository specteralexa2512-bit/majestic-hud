local ESX = exports['es_extended']:getSharedObject()
local playerData = ESX.GetPlayerData() or {}
local onlineCount = 0
local wasInVehicle = false
local lastPlayerUpdate = 0
local adminLevel = 0
local adminLoggedIn = false
local adminMode = false
local ticketSnapshot = {}
local activeAdminModes = {}

local weatherLabels = {
    EXTRASUNNY = 'Sonnig', CLEAR = 'Klar', NEUTRAL = 'Klar', CLOUDS = 'Bewölkt',
    OVERCAST = 'Stark bewölkt', SMOG = 'Dunstig', FOGGY = 'Neblig', CLEARING = 'Aufklarend',
    RAIN = 'Regen', THUNDER = 'Gewitter', SNOW = 'Schnee', SNOWLIGHT = 'Leichter Schnee',
    BLIZZARD = 'Schneesturm', XMAS = 'Schnee', HALLOWEEN = 'Nebel'
}
local weatherTemps = { EXTRASUNNY=28, CLEAR=25, NEUTRAL=24, CLOUDS=21, OVERCAST=19, SMOG=22, FOGGY=17, CLEARING=20, RAIN=17, THUNDER=18, SNOW=1, SNOWLIGHT=3, BLIZZARD=-4, XMAS=0, HALLOWEEN=15 }

RegisterNetEvent('esx:playerLoaded', function(data) playerData = data or ESX.GetPlayerData() or {} end)
RegisterNetEvent('esx:setJob', function(job) playerData.job = job end)
RegisterNetEvent('esx:setAccountMoney', function(account)
    playerData.accounts = playerData.accounts or {}
    for i, current in pairs(playerData.accounts) do
        if current.name == account.name then playerData.accounts[i] = account; return end
    end
    table.insert(playerData.accounts, account)
end)
RegisterNetEvent('rlrp_hud:setOnlineCount', function(count) onlineCount = math.max(0, tonumber(count) or 0) end)

local function getAccountMoney(name)
    for _, account in pairs(playerData.accounts or {}) do if account.name == name then return account.money or 0 end end
    return 0
end

local function getGameWeather()
    local previousHash, nextHash = GetPrevWeatherTypeHashName(), GetNextWeatherTypeHashName()
    local weatherHash = GetWeatherTypeTransition() >= 0.5 and nextHash or previousHash
    local weatherName = 'CLEAR'
    for name in pairs(weatherLabels) do if GetHashKey(name) == weatherHash then weatherName = name; break end end
    local hour, temp = GetClockHours(), weatherTemps[weatherName] or 22
    if hour < 6 or hour >= 21 then temp = temp - 5 elseif hour < 9 or hour >= 17 then temp = temp - 2 end
    return weatherLabels[weatherName] or 'Wetter', math.floor(temp + 0.5)
end

local function sendPlayerUpdate()
    local jobName, jobGrade = 'Arbeitslos', ''
    if playerData.job then jobName = playerData.job.label or playerData.job.name or jobName; jobGrade = playerData.job.grade_label or '' end
    local weather, temperature = getGameWeather()
    SendNUIMessage({ action='playerUpdate', id=GetPlayerServerId(PlayerId()), online=onlineCount, job=jobName, grade=jobGrade, cash=getAccountMoney('money'), bank=getAccountMoney('bank'), weather=weather, temperature=temperature })
end

local function notify(text)
    TriggerEvent('chat:addMessage', { color={255,80,100}, args={'Admin/Report', text} })
end

RegisterNetEvent('rlrp_admin:loginResult', function(ok, level, message)
    adminLoggedIn, adminLevel = ok == true, tonumber(level) or 0
    notify(message or (ok and 'Admin-Anmeldung erfolgreich.' or 'Keine Adminrechte.'))
    SendNUIMessage({ action='adminAccess', loggedIn=adminLoggedIn, level=adminLevel })
end)
RegisterNetEvent('rlrp_admin:mode', function(enabled, sid, name)
    if tonumber(sid) == GetPlayerServerId(PlayerId()) then
        adminMode = enabled == true
        notify(adminMode and 'Adminmodus aktiviert.' or 'Adminmodus deaktiviert.')
    end
    if enabled then activeAdminModes[tonumber(sid)] = name or ('ID '..tostring(sid)) else activeAdminModes[tonumber(sid)] = nil end
end)
RegisterNetEvent('rlrp_admin:modeSnapshot', function(modes) activeAdminModes = modes or {} end)
RegisterNetEvent('rlrp_admin:ticketCount', function(count)
    SendNUIMessage({ action='ticketCount', count=tonumber(count) or 0 })
end)
RegisterNetEvent('rlrp_admin:ticketSnapshot', function(tickets)
    ticketSnapshot = tickets or {}
    SendNUIMessage({ action='ticketSnapshot', tickets=ticketSnapshot })
end)
RegisterNetEvent('rlrp_admin:ticketUpdate', function(ticket)
    SendNUIMessage({ action='ticketUpdate', ticket=ticket })
end)
RegisterNetEvent('rlrp_admin:ticketNotice', function(text)
    notify(text)
end)

RegisterCommand('adminlogin', function() TriggerServerEvent('rlrp_admin:login') end, false)
RegisterCommand('admin', function() TriggerServerEvent('rlrp_admin:toggleMode') end, false)
RegisterKeyMapping('rlrp_adminmenu', 'Admin-Menü öffnen (nach /adminlogin)', 'keyboard', 'F3')
RegisterCommand('rlrp_adminmenu', function()
    if not adminLoggedIn then notify('Bitte zuerst /adminlogin eingeben.'); return end
    if adminLevel < 1 then return end
    SetNuiFocus(true, true)
    SendNUIMessage({ action='openAdmin', level=adminLevel })
    TriggerServerEvent('rlrp_admin:requestTickets')
end, false)

RegisterNUICallback('closeAdmin', function(_, cb) SetNuiFocus(false, false); cb({ ok=true }) end)
RegisterNUICallback('requestTickets', function(_, cb) TriggerServerEvent('rlrp_admin:requestTickets'); cb({ ok=true }) end)
RegisterNUICallback('ticketReply', function(data, cb) TriggerServerEvent('rlrp_admin:reply', tonumber(data.ticketId), tostring(data.message or '')); cb({ ok=true }) end)
RegisterNUICallback('ticketClose', function(data, cb) TriggerServerEvent('rlrp_admin:closeTicket', tonumber(data.ticketId)); cb({ ok=true }) end)
RegisterNUICallback('ticketClaim', function(data, cb) TriggerServerEvent('rlrp_admin:claimTicket', tonumber(data.ticketId)); cb({ ok=true }) end)

RegisterNetEvent('rlrp_admin:playerTicketMessage', function(ticketId, message, senderName)
    notify(('Ticket #%s – %s: %s'):format(ticketId, senderName or 'Admin', message))
end)

CreateThread(function()
    TriggerServerEvent('rlrp_hud:requestOnlineCount')
    while true do
        local now, ped = GetGameTimer(), PlayerPedId()
        if now - lastPlayerUpdate >= 1000 then sendPlayerUpdate(); lastPlayerUpdate = now end
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
        if isDriver then
            local speed, gear = GetEntitySpeed(vehicle) * 3.6, GetVehicleCurrentGear(vehicle)
            SendNUIMessage({ action='vehicleUpdate', inVehicle=true, speed=speed, gear=gear == 0 and (speed > 1 and 'R' or 'N') or tostring(gear), fuel=GetVehicleFuelLevel(vehicle), rpm=GetVehicleCurrentRpm(vehicle) })
            wasInVehicle = true
        elseif wasInVehicle then SendNUIMessage({ action='vehicleUpdate', inVehicle=false }); wasInVehicle = false end
        Wait(isDriver and 50 or 200)
    end
end)

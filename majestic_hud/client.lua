local ESX = exports['es_extended']:getSharedObject()
local playerData = ESX.GetPlayerData() or {}
local onlineCount = 0
local wasInVehicle = false
local lastPlayerUpdate = 0

local weatherLabels = {
    EXTRASUNNY = 'Sonnig', CLEAR = 'Klar', NEUTRAL = 'Klar', CLOUDS = 'Bewölkt',
    OVERCAST = 'Stark bewölkt', SMOG = 'Dunstig', FOGGY = 'Neblig',
    CLEARING = 'Aufklarend', RAIN = 'Regen', THUNDER = 'Gewitter',
    SNOW = 'Schnee', SNOWLIGHT = 'Leichter Schnee', BLIZZARD = 'Schneesturm',
    XMAS = 'Schnee', HALLOWEEN = 'Nebel'
}

local weatherTemps = {
    EXTRASUNNY = 28, CLEAR = 25, NEUTRAL = 24, CLOUDS = 21,
    OVERCAST = 19, SMOG = 22, FOGGY = 17, CLEARING = 20,
    RAIN = 17, THUNDER = 18, SNOW = 1, SNOWLIGHT = 3,
    BLIZZARD = -4, XMAS = 0, HALLOWEEN = 15
}

RegisterNetEvent('esx:playerLoaded', function(data)
    playerData = data or ESX.GetPlayerData() or {}
end)

RegisterNetEvent('esx:setJob', function(job)
    playerData.job = job
end)

RegisterNetEvent('esx:setAccountMoney', function(account)
    playerData.accounts = playerData.accounts or {}
    for i, current in pairs(playerData.accounts) do
        if current.name == account.name then
            playerData.accounts[i] = account
            return
        end
    end
    table.insert(playerData.accounts, account)
end)

RegisterNetEvent('rlrp_hud:setOnlineCount', function(count)
    onlineCount = math.max(0, tonumber(count) or 0)
end)

local function getAccountMoney(name)
    for _, account in pairs(playerData.accounts or {}) do
        if account.name == name then return account.money or 0 end
    end
    return 0
end

local function getGameWeather()
    local previousHash = GetPrevWeatherTypeHashName()
    local nextHash = GetNextWeatherTypeHashName()
    local transition = GetWeatherTypeTransition()
    local weatherHash = transition >= 0.5 and nextHash or previousHash
    local weatherName = string.upper(GetNameOfZone(0, 0) or '') -- fallback only; replaced below by hash matching

    for name in pairs(weatherLabels) do
        if GetHashKey(name) == weatherHash then
            weatherName = name
            break
        end
    end

    local hour = GetClockHours()
    local temp = weatherTemps[weatherName] or 22
    -- GTA has no native ambient-temperature reading; estimate from the active game weather and game time.
    if hour < 6 or hour >= 21 then
        temp = temp - 5
    elseif hour < 9 then
        temp = temp - 2
    elseif hour >= 17 then
        temp = temp - 2
    end

    return weatherLabels[weatherName] or 'Wetter', math.floor(temp + 0.5)
end

local function sendPlayerUpdate()
    local jobName, jobGrade = 'Arbeitslos', ''
    if playerData.job then
        jobName = playerData.job.label or playerData.job.name or jobName
        jobGrade = playerData.job.grade_label or ''
    end

    local weather, temperature = getGameWeather()
    SendNUIMessage({
        action = 'playerUpdate',
        id = GetPlayerServerId(PlayerId()),
        online = onlineCount,
        job = jobName,
        grade = jobGrade,
        cash = getAccountMoney('money'),
        bank = getAccountMoney('bank'),
        weather = weather,
        temperature = temperature
    })
end

CreateThread(function()
    TriggerServerEvent('rlrp_hud:requestOnlineCount')

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
        local now = GetGameTimer()

        if now - lastPlayerUpdate >= 1000 then
            sendPlayerUpdate()
            lastPlayerUpdate = now
        end

        if isDriver then
            local speed = GetEntitySpeed(vehicle) * 3.6
            local gear = GetVehicleCurrentGear(vehicle)
            SendNUIMessage({
                action = 'vehicleUpdate', inVehicle = true, speed = speed,
                gear = gear == 0 and (speed > 1 and 'R' or 'N') or tostring(gear),
                fuel = GetVehicleFuelLevel(vehicle), rpm = GetVehicleCurrentRpm(vehicle)
            })
            wasInVehicle = true
            Wait(50)
        else
            if wasInVehicle then
                SendNUIMessage({ action = 'vehicleUpdate', inVehicle = false })
                wasInVehicle = false
            end
            Wait(200)
        end
    end
end)

local ESX = exports['es_extended']:getSharedObject()
local playerData = ESX.GetPlayerData() or {}
local hunger, thirst = 100, 100
local onlineCount = 1
local wasInVehicle = false
local lastPlayerUpdate = 0

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

RegisterNetEvent('esx_status:onTick', function(statuses)
    for _, status in pairs(statuses or {}) do
        local val = tonumber(status.val) or 0
        local percent = math.floor((val / 1000000) * 100)
        percent = math.max(0, math.min(100, percent))
        if status.name == 'hunger' then hunger = percent end
        if status.name == 'thirst' then thirst = percent end
    end
end)

RegisterNetEvent('rlrp_hud:setOnlineCount', function(count)
    onlineCount = math.max(0, tonumber(count) or 0)
end)

local function getAccountMoney(name)
    for _, account in pairs(playerData.accounts or {}) do
        if account.name == name then
            return account.money or 0
        end
    end
    return 0
end

local function sendPlayerUpdate(ped)
    local health = math.floor(((GetEntityHealth(ped) - 100) / 100) * 100)
    health = math.max(0, math.min(100, health))

    local jobName, jobGrade = 'Arbeitslos', ''
    if playerData.job then
        jobName = playerData.job.label or playerData.job.name or jobName
        jobGrade = playerData.job.grade_label or ''
    end

    SendNUIMessage({
        action = 'playerUpdate',
        id = GetPlayerServerId(PlayerId()),
        online = onlineCount,
        job = jobName,
        grade = jobGrade,
        cash = getAccountMoney('money'),
        bank = getAccountMoney('bank'),
        health = health,
        armor = GetPedArmour(ped),
        hunger = hunger,
        thirst = thirst,
        hour = GetClockHours(),
        minute = GetClockMinutes()
    })
end

local function sendVehicleUpdate(vehicle)
    local speed = GetEntitySpeed(vehicle) * 3.6
    local gear = GetVehicleCurrentGear(vehicle)
    local displayGear = gear == 0 and (speed > 1 and 'R' or 'N') or tostring(gear)

    SendNUIMessage({
        action = 'vehicleUpdate',
        inVehicle = true,
        speed = speed,
        gear = displayGear,
        fuel = GetVehicleFuelLevel(vehicle),
        rpm = GetVehicleCurrentRpm(vehicle)
    })
end

CreateThread(function()
    DisplayRadar(true)
    TriggerServerEvent('rlrp_hud:requestOnlineCount')

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
        local now = GetGameTimer()

        if now - lastPlayerUpdate >= 500 then
            sendPlayerUpdate(ped)
            lastPlayerUpdate = now
        end

        if isDriver then
            sendVehicleUpdate(vehicle)
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

local ESX = exports['es_extended']:getSharedObject()
local playerData = ESX.GetPlayerData() or {}
local hunger, thirst = 100, 100

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

-- Requires esx_status. Hunger and thirst stay at 100 if it is not installed.
RegisterNetEvent('esx_status:onTick', function(statuses)
    for _, status in pairs(statuses or {}) do
        local percent = math.floor(((tonumber(status.val) or 0) / 1000000) * 100)
        percent = math.max(0, math.min(100, percent))

        if status.name == 'hunger' then hunger = percent end
        if status.name == 'thirst' then thirst = percent end
    end
end)

local function getAccountMoney(name)
    for _, account in pairs(playerData.accounts or {}) do
        if account.name == name then
            return account.money or 0
        end
    end
    return 0
end

CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local inVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
        local health = math.floor(((GetEntityHealth(ped) - 100) / 100) * 100)
        health = math.max(0, math.min(100, health))

        local jobName, jobGrade = 'Arbeitslos', ''
        if playerData.job then
            jobName = playerData.job.label or playerData.job.name or jobName
            jobGrade = playerData.job.grade_label or ''
        end

        SendNUIMessage({
            action = 'update',
            id = GetPlayerServerId(PlayerId()),
            job = jobName,
            grade = jobGrade,
            cash = getAccountMoney('money'),
            bank = getAccountMoney('bank'),
            health = health,
            armor = GetPedArmour(ped),
            hunger = hunger,
            thirst = thirst,
            inVehicle = inVehicle,
            speed = inVehicle and math.floor(GetEntitySpeed(vehicle) * 3.6) or 0,
            fuel = inVehicle and math.floor(GetVehicleFuelLevel(vehicle)) or 0
        })
    end
end)

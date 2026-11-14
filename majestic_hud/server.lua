local function broadcastOnlineCount()
    TriggerClientEvent('rlrp_hud:setOnlineCount', -1, #GetPlayers())
end

RegisterNetEvent('rlrp_hud:requestOnlineCount', function()
    TriggerClientEvent('rlrp_hud:setOnlineCount', source, #GetPlayers())
end)

AddEventHandler('playerJoining', function()
    SetTimeout(1000, broadcastOnlineCount)
end)

AddEventHandler('playerDropped', function()
    SetTimeout(1000, broadcastOnlineCount)
end)

CreateThread(function()
    while true do
        broadcastOnlineCount()
        Wait(15000)
    end
end)

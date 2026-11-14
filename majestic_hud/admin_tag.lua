-- Overhead staff badge for the existing admin-mode snapshot.
-- This is a separate client script so it does not alter the regular HUD/NUI.
local activeAdmins = {}
local MAX_DISTANCE = 30.0

RegisterNetEvent('rlrp_admin:modeSnapshot', function(snapshot)
    activeAdmins = type(snapshot) == 'table' and snapshot or {}
end)

local function drawText(text, x, y, scale, r, g, b, a)
    SetTextFont(4)
    SetTextScale(0.0, scale)
    SetTextColour(r, g, b, a)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function drawAdminBadge(x, y, name, serverId)
    local width, height = 0.155, 0.050
    DrawRect(x, y, width, height, 12, 14, 18, 205)
    DrawRect(x, y - height / 2 + 0.002, width, 0.004, 230, 48, 62, 245)
    drawText('ADMIN', x, y - 0.019, 0.245, 255, 75, 86, 255)
    drawText(('%s  •  ID %s'):format(tostring(name or 'Team'), tostring(serverId)), x, y + 0.002, 0.225, 245, 247, 250, 255)
end

CreateThread(function()
    while true do
        local hasAdmins = next(activeAdmins) ~= nil
        if not hasAdmins then
            Wait(500)
        else
            local localPed = PlayerPedId()
            local localCoords = GetEntityCoords(localPed)
            for serverId, adminName in pairs(activeAdmins) do
                local sid = tonumber(serverId)
                local player = sid and GetPlayerFromServerId(sid) or -1
                if player and player ~= -1 and player ~= PlayerId() then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
                        local coords = GetEntityCoords(ped)
                        if #(localCoords - coords) <= MAX_DISTANCE then
                            local visible, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 1.28)
                            if visible then
                                drawAdminBadge(screenX, screenY, adminName, sid)
                            end
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)

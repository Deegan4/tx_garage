-- tx_garage — Client entry, blips, target/marker setup

local PlayerLoaded = false
local CachedConfig = nil

local function notify(msg, type)
    type = type or 'inform'
    if Config.Notify.style == 'ox' then
        lib.notify({ description = msg, type = type, duration = Config.Notify.duration })
    elseif Config.Notify.style == 'qb' then
        TriggerEvent('QBCore:Notify', msg, type, Config.Notify.duration)
    elseif Config.Notify.style == 'esx' then
        TriggerEvent('esx:showNotification', msg)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end
exports('Notify', notify)

RegisterNetEvent('tx_garage:notify', function(msg, type) notify(msg, type) end)

---Add map blips for every garage.
local function createBlips()
    for _, garage in ipairs(Config.Garages) do
        if garage.blip then
            local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
            SetBlipSprite(blip, garage.blip.sprite)
            SetBlipColour(blip, garage.blip.color)
            SetBlipScale(blip, garage.blip.scale or 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(garage.label)
            EndTextCommandSetBlipName(blip)
        end
    end

    if Config.Auction.enabled and Config.Auction.auctionBlip then
        local b = Config.Auction.auctionBlip
        local blip = AddBlipForCoord(Config.Auction.auctionLot.x, Config.Auction.auctionLot.y, Config.Auction.auctionLot.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.color)
        SetBlipScale(blip, b.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Locale('auction.title'))
        EndTextCommandSetBlipName(blip)
    end
end

---Add ox_target / qb-target zones for each garage.
local function createTargets()
    if Config.Interaction.method ~= 'target' then return end

    for _, garage in ipairs(Config.Garages) do
        local label, icon
        if garage.type == 'impound' then
            label = Locale('impound.title') .. ' — ' .. garage.label
            icon  = 'fa-solid fa-handcuffs'
        else
            label = garage.label
            icon  = 'fa-solid fa-warehouse'
        end

        if Config.Interaction.targetResource == 'ox_target' then
            exports.ox_target:addBoxZone({
                coords = garage.coords,
                size   = vec3(3.0, 3.0, 2.0),
                rotation = 0,
                debug = Config.Debug,
                options = {{
                    name  = 'tx_garage_' .. garage.name,
                    icon  = icon,
                    label = label,
                    onSelect = function()
                        OpenGarageUI(garage.name)
                    end,
                }},
            })
        end
    end

    if Config.Auction.enabled and Config.Interaction.targetResource == 'ox_target' then
        exports.ox_target:addBoxZone({
            coords = Config.Auction.auctionLot,
            size   = vec3(3.0, 3.0, 2.0),
            rotation = 0,
            debug = Config.Debug,
            options = {{
                name  = 'tx_garage_auction',
                icon  = 'fa-solid fa-gavel',
                label = Locale('auction.title'),
                onSelect = function() OpenAuctionUI() end,
            }},
        })
    end
end

CreateThread(function()
    -- Pull server-trimmed config for runtime UI rendering
    CachedConfig = lib.callback.await('tx_garage:getConfig', false)
    Wait(500)
    createBlips()
    createTargets()
    PlayerLoaded = true
    Utils.dbg('client ready')
end)

function GetClientConfig() return CachedConfig end

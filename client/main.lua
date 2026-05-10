-- tx_garage v2.0 — Client entry, blips, target zones, notifications
-- ────────────────────────────────────────────────────────────────────────────
-- M1 fix: blip & target cleanup on resource stop.
-- M3 fix: 'textui' interaction method now actually works (was stubbed in v1).

local CachedConfig  = nil
local createdBlips  = {}   -- list of blip handles
local createdZones  = {}   -- list of zone ids (ox_target / qb-target)
local nuiOpen       = false

-- ─────────────────────────────────────────────────────────────────────
-- Notifications (use lib.notify for QBox)
-- ─────────────────────────────────────────────────────────────────────

local function notify(msg, type_)
    type_ = type_ or 'inform'
    if Config.Notify.style == 'ox' then
        lib.notify({
            description = msg,
            type        = type_,
            duration    = Config.Notify.duration,
            position    = Config.Notify.position or 'top-right',
        })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end
exports('Notify', notify)
RegisterNetEvent('tx_garage:notify', function(msg, type_) notify(msg, type_) end)

function GetClientConfig() return CachedConfig end

local function setNuiFocus(b)
    SetNuiFocus(b, b)
    nuiOpen = b
end
function IsNuiOpen() return nuiOpen end
function SetNuiOpen(b) setNuiFocus(b) end

-- ─────────────────────────────────────────────────────────────────────
-- Blip helpers
-- ─────────────────────────────────────────────────────────────────────

local function createBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale or 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    createdBlips[#createdBlips+1] = blip
    return blip
end

local function createGarageBlip(garage)
    if garage.blip then
        createBlip(garage.coords, garage.blip.sprite, garage.blip.color,
                   garage.blip.scale, garage.label)
    end
end

local function createAllBlips()
    for _, garage in ipairs(CachedConfig.Garages) do
        createGarageBlip(garage)
    end
    if CachedConfig.Auction.enabled and CachedConfig.Auction.auctionBlip then
        local b = CachedConfig.Auction.auctionBlip
        createBlip(CachedConfig.Auction.auctionLot, b.sprite, b.color, b.scale,
                   Locale('auction.title'))
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- Target zones (ox_target / qb-target)
-- ─────────────────────────────────────────────────────────────────────

local function addTarget(name, coords, opts)
    local zone
    if CachedConfig.Interaction.targetResource == 'ox_target' then
        zone = exports.ox_target:addBoxZone({
            coords   = coords,
            size     = vec3(3.0, 3.0, 2.0),
            rotation = 0,
            debug    = Config.Debug,
            options  = opts,
        })
    elseif CachedConfig.Interaction.targetResource == 'qb-target' then
        zone = exports['qb-target']:AddBoxZone(name, coords, 3.0, 3.0, {
            name = name, heading = 0, debugPoly = Config.Debug,
            minZ = coords.z - 1.0, maxZ = coords.z + 1.0,
        }, { options = opts, distance = 2.5 })
    end
    if zone then createdZones[#createdZones+1] = { name = name, handle = zone } end
end

local function createGarageTarget(garage)
    if CachedConfig.Interaction.method ~= 'target' then return end

    local label, icon
    if garage.type == 'impound' then
        label = Locale('impound.title') .. ' — ' .. garage.label
        icon  = 'fa-solid fa-handcuffs'
    elseif garage.type == 'job' then
        label = garage.label
        icon  = 'fa-solid fa-briefcase'
    else
        label = garage.label
        icon  = 'fa-solid fa-warehouse'
    end

    addTarget('tx_garage_'..garage.name, garage.coords, {{
        name      = 'tx_garage_'..garage.name,
        icon      = icon,
        label     = label,
        distance  = 2.5,
        onSelect  = function() OpenGarageUI(garage.name) end,
    }})
end

local function createAllTargets()
    if CachedConfig.Interaction.method ~= 'target' then return end

    for _, garage in ipairs(CachedConfig.Garages) do
        createGarageTarget(garage)
    end

    if CachedConfig.Auction.enabled then
        addTarget('tx_garage_auction', CachedConfig.Auction.auctionLot, {{
            name     = 'tx_garage_auction',
            icon     = 'fa-solid fa-gavel',
            label    = Locale('auction.title'),
            distance = 2.5,
            onSelect = function() OpenAuctionUI() end,
        }})
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- TextUI fallback (M3 fix — actually works now)
-- ─────────────────────────────────────────────────────────────────────

local function startTextUiLoop()
    if CachedConfig.Interaction.method ~= 'textui' then return end

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local nearest, nearestDist, nearestType = nil, math.huge, nil

            for _, g in ipairs(CachedConfig.Garages) do
                local d = #(pos - vector3(g.coords.x, g.coords.y, g.coords.z))
                if d < (CachedConfig.Interaction.drawDistance or 6.0) and d < nearestDist then
                    nearest, nearestDist, nearestType = g, d, 'garage'
                end
            end
            if CachedConfig.Auction.enabled then
                local lot = CachedConfig.Auction.auctionLot
                local d = #(pos - vector3(lot.x, lot.y, lot.z))
                if d < (CachedConfig.Interaction.drawDistance or 6.0) and d < nearestDist then
                    nearest, nearestDist, nearestType = { name = '__auction', label = Locale('auction.title') }, d, 'auction'
                end
            end

            if nearest then
                sleep = 0
                lib.showTextUI(('[E] %s'):format(nearest.label), { position = 'right-center' })
                if IsControlJustPressed(0, 38) then  -- E
                    lib.hideTextUI()
                    if nearestType == 'auction' then OpenAuctionUI()
                    else OpenGarageUI(nearest.name) end
                    Wait(500)
                end
            else
                lib.hideTextUI()
            end
            Wait(sleep)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────
-- Marker mode (3D markers + E to interact)
-- ─────────────────────────────────────────────────────────────────────

local function startMarkerLoop()
    if CachedConfig.Interaction.method ~= 'marker' then return end

    local m = CachedConfig.Interaction.marker or {}
    local mType  = m.type or 1
    local mSize  = m.size or vec3(1.5, 1.5, 0.6)
    local mCol   = m.color or { r = 255, g = 64, b = 180, a = 120 }
    local mBob   = m.bobUpAndDown or false
    local mRot   = m.rotate or false
    local promptKey  = m.promptKey or 38
    local promptText = m.promptText or '[E] %s'
    local drawDist   = CachedConfig.Interaction.drawDistance or 6.0

    CreateThread(function()
        while true do
            local sleep = 1000
            local pos = GetEntityCoords(PlayerPedId())
            local nearest, nearestDist, nearestType

            for _, g in ipairs(CachedConfig.Garages) do
                local gc = vector3(g.coords.x, g.coords.y, g.coords.z)
                local d = #(pos - gc)
                if d < drawDist then
                    sleep = 0
                    DrawMarker(mType, gc.x, gc.y, gc.z - 0.95,
                        0,0,0, 0,0,0,
                        mSize.x, mSize.y, mSize.z,
                        mCol.r, mCol.g, mCol.b, mCol.a,
                        mBob, false, 2, mRot, nil, nil, false)
                    if d < 2.0 and (not nearest or d < nearestDist) then
                        nearest, nearestDist, nearestType = g, d, 'garage'
                    end
                end
            end

            if CachedConfig.Auction.enabled then
                local lot = CachedConfig.Auction.auctionLot
                local lc = vector3(lot.x, lot.y, lot.z)
                local d = #(pos - lc)
                if d < drawDist then
                    sleep = 0
                    DrawMarker(mType, lc.x, lc.y, lc.z - 0.95,
                        0,0,0, 0,0,0,
                        mSize.x, mSize.y, mSize.z,
                        mCol.r, mCol.g, mCol.b, mCol.a,
                        mBob, false, 2, mRot, nil, nil, false)
                    if d < 2.0 and (not nearest or d < nearestDist) then
                        nearest, nearestDist, nearestType = { name = '__auction', label = Locale('auction.title') }, d, 'auction'
                    end
                end
            end

            if nearest then
                lib.showTextUI(promptText:format(nearest.label), { position = 'right-center' })
                if IsControlJustPressed(0, promptKey) then
                    lib.hideTextUI()
                    if nearestType == 'auction' then OpenAuctionUI()
                    else OpenGarageUI(nearest.name) end
                    Wait(500)
                end
            else
                lib.hideTextUI()
            end
            Wait(sleep)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────
-- Dev: /tx_addgarage — print a Config.Garages entry for the current spot
-- ─────────────────────────────────────────────────────────────────────

RegisterCommand('tx_addgarage', function(_, args)
    if not CachedConfig or not CachedConfig.Debug then
        notify('tx_addgarage is dev-only — set Config.Debug = true', 'error') return
    end

    local name  = args[1] or ('garage_' .. tostring(math.random(1000, 9999)))
    local label = table.concat(args, ' ', 2)
    if label == '' then label = 'New Garage' end

    -- Reject duplicate name (collides with target zone id)
    for _, g in ipairs(CachedConfig.Garages) do
        if g.name == name then notify('Garage name already exists: '..name, 'error') return end
    end

    local pos     = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local newGarage = {
        name    = name,
        type    = 'public',
        label   = label,
        coords  = vec3(pos.x, pos.y, pos.z),
        heading = heading,
        blip    = { sprite = 357, color = 3, scale = 0.8 },
        allowedClasses = nil,
        storageLimit   = 20,
    }

    -- Live-add: marker mode picks this up automatically next tick
    CachedConfig.Garages[#CachedConfig.Garages + 1] = newGarage
    createGarageBlip(newGarage)
    createGarageTarget(newGarage)

    local snippet = string.format([[
{
    name    = '%s',
    type    = 'public',
    label   = '%s',
    coords  = vec3(%.2f, %.2f, %.2f),
    heading = %.2f,
    blip    = { sprite = 357, color = 3, scale = 0.8 },
    allowedClasses = nil,
    storageLimit   = 20,
},]], name, label, pos.x, pos.y, pos.z, heading)

    print('^5[tx_garage]^7 garage live-added — paste into Config.Garages to persist:')
    print(snippet)

    SendNUIMessage({ action = 'copyToClipboard', text = snippet })
    notify(('Garage "%s" added live — snippet copied'):format(label), 'success')
end, false)

-- ─────────────────────────────────────────────────────────────────────
-- Cleanup on resource stop (M1 fix)
-- ─────────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, b in ipairs(createdBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    for _, z in ipairs(createdZones) do
        if CachedConfig and CachedConfig.Interaction.targetResource == 'ox_target' then
            exports.ox_target:removeZone(z.handle)
        elseif CachedConfig and CachedConfig.Interaction.targetResource == 'qb-target' then
            exports['qb-target']:RemoveZone(z.name)
        end
    end
    if nuiOpen then setNuiFocus(false) end
    lib.hideTextUI()
end)

-- ─────────────────────────────────────────────────────────────────────
-- Boot
-- ─────────────────────────────────────────────────────────────────────

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(500) end
    CachedConfig = lib.callback.await('tx_garage:getConfig', false)
    if not CachedConfig then
        Utils.dbg('failed to load server config')
        return
    end
    Wait(250)
    createAllBlips()
    createAllTargets()
    startTextUiLoop()
    startMarkerLoop()
    Utils.dbg('client ready ('..CachedConfig.Interaction.method..')')
end)

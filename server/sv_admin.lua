-- tx_garage v2.0 — Admin commands
-- ────────────────────────────────────────────────────────────────────────────
-- All commands gated by ACE permissions (Config.Admin.aceAdmin).
-- Add to server.cfg:
--     add_ace group.admin tx_garage.admin allow

local function isAdmin(src)
    return Garage.HasAce(src, Config.Admin.aceAdmin)
end

local function isMod(src)
    return Garage.HasAce(src, Config.Admin.aceAdmin) or Garage.HasAce(src, Config.Admin.aceMod)
end

-- ─────────────────────────────────────────────────────────────────────
-- /tx_spawnveh <model>     spawn an admin vehicle (no DB row, despawn-on-store)
-- ─────────────────────────────────────────────────────────────────────
if Config.Admin.enableSpawnCommand then
    RegisterCommand('tx_spawnveh', function(src, args)
        if not isAdmin(src) then
            Garage.Notify(src, Locale('admin.no_perm'), 'error'); return
        end
        local model = args[1]
        if not model or #model == 0 then
            Garage.Notify(src, '/tx_spawnveh <model>', 'error'); return
        end
        TriggerClientEvent('tx_garage:adminSpawnVehicle', src, model)
        Garage.Notify(src, Locale('admin.spawned', model), 'success')
    end, false)
    TriggerEvent('chat:addSuggestion', '/tx_spawnveh', 'Admin: spawn a vehicle by model name', {
        { name = 'model', help = 'Vehicle model spawn name (e.g. adder)' }
    })
end

-- ─────────────────────────────────────────────────────────────────────
-- /tx_delveh   delete the vehicle the admin is in or aiming at
-- ─────────────────────────────────────────────────────────────────────
if Config.Admin.enableDeleteCommand then
    RegisterCommand('tx_delveh', function(src)
        if not isAdmin(src) then
            Garage.Notify(src, Locale('admin.no_perm'), 'error'); return
        end
        TriggerClientEvent('tx_garage:adminDeleteCurrent', src)
    end, false)
    TriggerEvent('chat:addSuggestion', '/tx_delveh', 'Admin: delete the vehicle you are in')
end

-- ─────────────────────────────────────────────────────────────────────
-- /tx_tpveh <plate>   teleport to a player's vehicle by plate
-- ─────────────────────────────────────────────────────────────────────
if Config.Admin.enableTeleportCommand then
    RegisterCommand('tx_tpveh', function(src, args)
        if not isAdmin(src) then
            Garage.Notify(src, Locale('admin.no_perm'), 'error'); return
        end
        local plate = Utils.normalizePlate(args[1])
        if not plate then
            Garage.Notify(src, '/tx_tpveh <plate>', 'error'); return
        end
        TriggerClientEvent('tx_garage:adminTeleportToPlate', src, plate)
    end, false)
    TriggerEvent('chat:addSuggestion', '/tx_tpveh', 'Admin: teleport to a vehicle by plate', {
        { name = 'plate', help = 'Vehicle plate' }
    })
end

-- ─────────────────────────────────────────────────────────────────────
-- /tx_impound <plate>   force a vehicle to impound (DB row must exist)
-- ─────────────────────────────────────────────────────────────────────
if Config.Admin.enableImpoundCommand then
    RegisterCommand('tx_impound', function(src, args)
        if not isAdmin(src) then
            Garage.Notify(src, Locale('admin.no_perm'), 'error'); return
        end
        local plate = Utils.normalizePlate(args[1])
        if not plate then
            Garage.Notify(src, '/tx_impound <plate>', 'error'); return
        end

        local upd = MySQL.update.await([[
            UPDATE player_vehicles
            SET tx_garage_state = 'impound', tx_garage_impounded_at = NOW(),
                tx_garage_name = 'mrpd_impound'
            WHERE plate = ? AND tx_garage_state IN ('out', 'stored')
        ]], { plate })
        if not upd or upd == 0 then
            Garage.Notify(src, Locale('admin.not_found'), 'error'); return
        end
        Garage.Notify(src, Locale('success.vehicle_stored'), 'success')
    end, false)
    TriggerEvent('chat:addSuggestion', '/tx_impound', 'Admin: force vehicle to impound', {
        { name = 'plate', help = 'Vehicle plate' }
    })
end

-- ─────────────────────────────────────────────────────────────────────
-- /tx_release <plate>   release a vehicle from impound to stored
-- ─────────────────────────────────────────────────────────────────────
if Config.Admin.enableReleaseCommand then
    RegisterCommand('tx_release', function(src, args)
        if not isAdmin(src) then
            Garage.Notify(src, Locale('admin.no_perm'), 'error'); return
        end
        local plate = Utils.normalizePlate(args[1])
        if not plate then
            Garage.Notify(src, '/tx_release <plate>', 'error'); return
        end
        local upd = MySQL.update.await([[
            UPDATE player_vehicles
            SET tx_garage_state = 'stored', tx_garage_impounded_at = NULL,
                tx_garage_name = NULL
            WHERE plate = ? AND tx_garage_state IN ('impound', 'auction')
        ]], { plate })
        if not upd or upd == 0 then
            Garage.Notify(src, Locale('admin.not_found'), 'error'); return
        end
        Garage.Notify(src, Locale('impound.released'), 'success')
    end, false)
    TriggerEvent('chat:addSuggestion', '/tx_release', 'Admin: release vehicle from impound', {
        { name = 'plate', help = 'Vehicle plate' }
    })
end

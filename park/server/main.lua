ESX = nil
Parks = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
Parks = Config.Parks

ESX.RegisterServerCallback('server:checkOwner',function(source, cb, plate)
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND plate = @plate', {
        ['@owner'] = xPlayer.identifier,
        ['@plate'] = plate,
    }, function(data)
        if data[1] == nil then
            print('NPC Vehicle')
        elseif data[1].plate == plate then
            cb(true)
        else
            cb(false)
        end
    end)
end)

RegisterServerEvent('server:retrievalDone')
AddEventHandler('server:retrievalDone', function(park, data, baseCoords)
    TriggerClientEvent('pw_carpark:client:retrievalDone', -1, park, data, baseCoords)
end)

RegisterServerEvent('server:retrievalVehicle')
AddEventHandler('server:retrievalVehicle', function(type, plate)
    local _src = source
    MySQL.Async.fetchAll("SELECT * FROM `owned_vehicles` WHERE `plate` = @plate", {['@plate'] = plate}, function(vehicle)
        if vehicle[1] ~= nil then
            TriggerClientEvent('pw_carpark:client:spawnVehicle', _src, type, json.decode(vehicle[1].vehicle), 1)
        end
        MySQL.Async.execute("UPDATE `owned_vehicles` SET `stored` = 0 WHERE `plate` = @plate", {['@plate'] = plate}, function() end)
    end)
end)

RegisterServerEvent('server:parkVeh')
AddEventHandler('server:parkVeh', function(park, props, dmg)
    local _src = source
    if not Parks[park].parking then
        Parks[park].parking = _src
        TriggerClientEvent('pw_carpark:client:setParkState', -1, park, 'parking', _src)
        TriggerClientEvent('pw_carpark:client:parkVeh', -1, park, props, dmg)
        TriggerEvent('server:SaveVehicleProps', props)
        MySQL.Async.execute("UPDATE `owned_vehicles` SET `stored` = 1 WHERE `plate` = @vin", {['@vin'] = props.plate}, function() end)
    end
end)

RegisterServerEvent('server:SaveVehicleProps')
AddEventHandler('server:SaveVehicleProps', function(props)
    MySQL.Async.execute('UPDATE owned_vehicles SET vehicle = @props WHERE plate = @plate', {
        ['@plate'] = props.plate,
        ['@props'] = json.encode(props),
    })
end)

RegisterServerEvent('server:setParkState')
AddEventHandler('server:setParkState', function(park, var, state)
    Parks[park][var] = state
    TriggerClientEvent('pw_carpark:client:setParkState', -1, park, var, state)
end)

RegisterServerEvent('server:retrieveVehicle')
AddEventHandler('server:retrieveVehicle', function(park, props, ins, dmg)
    local _src = source
    TriggerEvent('pw_carpark:server:setParkState', park, 'parking', _src)
    TriggerClientEvent('pw_carpark:client:retrieveVehicle', -1, park, props, _src, ins, dmg)
end)

ESX.RegisterServerCallback('server:getParkStates', function(source, cb)
    cb(Parks)
end)

ESX.RegisterServerCallback('server:getParkedVehicles', function(source, cb)
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND stored = 1', {
        ['@owner'] = xPlayer.identifier,
    }, function(vehicles)
        cb(#vehicles > 0 and vehicles or false)
    end)
end)
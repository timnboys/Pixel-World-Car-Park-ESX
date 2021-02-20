ESX = nil
playerLoaded, playerData = false, nil
GLOBAL_PED, GLOBAL_COORDS = nil, nil
local nearPark, attached, retrieving, spawnedProps, Parks, blips = false, false, false, {}, {}, {}

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(1)
    end

    ESX.TriggerServerCallback('server:getParkStates', function(parks)
        Parks = parks
        playerLoaded = true

        GLOBAL_PED = PlayerPedId()
        GLOBAL_COORDS = GetEntityCoords(GLOBAL_PED)
        CreateBlips()
    end)
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(data)
    ESX.TriggerServerCallback('server:getParkStates', function(parks)
        Parks = parks
        GLOBAL_PED = PlayerPedId()
        GLOBAL_COORDS = GetEntityCoords(GLOBAL_PED)
        playerLoaded = true
        CreateBlips()
        playerData = data
    end)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        if playerLoaded then
            GLOBAL_PED = GLOBAL_PED
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200)
        if playerLoaded then
            GLOBAL_COORDS = GetEntityCoords(GLOBAL_PED)
        end
    end
end)

function CreateBlips()
    while not playerLoaded or not playerData == nil do Wait(10); end
    for i = 1, #Config.Parks do
        DrawBlip(i)
    end
end

function DeleteBlips()
    for k,v in pairs(blips) do
        RemoveBlip(v)
    end

    blips = {}
end

function DrawBlip(id)
    if blips[id] ~= nil and DoesBlipExist(id) then RemoveBlip(blips[id]); end
    local blip = AddBlipForCoord(Config.Parks[id].screen.x, Config.Parks[id].screen.y, Config.Parks[id].screen.z)
    SetBlipSprite(blip, Config.Blips.blipSprite)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, Config.Blips.color)
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Auto-Park")
    EndTextCommandSetBlipName(blip)

    blips[id] = blip
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        if playerLoaded and playerData then
            GLOBAL_PED = PlayerPedId()
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200)
        if playerLoaded and playerData and GLOBAL_PED then
            GLOBAL_COORDS = GetEntityCoords(GLOBAL_PED)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() == res then
        if spawnedProps and (spawnedProps['fence'] or spawnedProps['base']) then
            DeleteProps()
        end

        if attached then DeleteVehicle(attached); end
    end
end)

RegisterNetEvent('pw_carpark:client:setParkState')
AddEventHandler('pw_carpark:client:setParkState', function(park, var, state)
    Parks[park][var] = state
end)

function GetRetrieveHeading(park)
    if (Parks[park].h.base - 180.0) < 0 then
        return (Parks[park].h.base + 180.0)
    else
        return (Parks[park].h.base - 180.0)
    end
end

SpawnLocalVehicle = function(modelName, coords, heading, cb)
	local model = (type(modelName) == 'number' and modelName or GetHashKey(modelName))

	Citizen.CreateThread(function()
		ESX.Streaming.RequestModel(model)

		local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, false, false)

		SetEntityAsMissionEntity(vehicle, true, false)
		SetVehicleHasBeenOwnedByPlayer(vehicle, true)
		SetVehicleNeedsToBeHotwired(vehicle, false)
		SetModelAsNoLongerNeeded(model)
		SetVehicleAutoRepairDisabled(vehicle, true)
		RequestCollisionAtCoord(coords.x, coords.y, coords.z)

		while not HasCollisionLoadedAroundEntity(vehicle) do
			RequestCollisionAtCoord(coords.x, coords.y, coords.z)
			Citizen.Wait(0)
		end

		SetVehRadioStation(vehicle, 'OFF')
		DecorSetBool(vehicle, "player_owned_veh", false)                
		if cb then
			cb(vehicle)
		end
	end)
end

function Park(type)
    if nearPark then
        local yOff
        local newCoords
        if type == 'park' then
            yOff = 0.0
            while yOff < 8.0 do
                yOff = yOff + 0.15
                newCoords = GetOffsetFromEntityInWorldCoords(spawnedProps['base'], 0.0, 0.15, 0.0)
                SetEntityCoordsNoOffset(spawnedProps['base'], newCoords)
                Wait(10)
            end
            if not retrieving and attached then
                DeleteVehicle(attached)
                attached = false
            end
            Wait(5000)
            Park('back')
        else
            if retrieving then
                local baseCoords = GetEntityCoords(spawnedProps['base'])
                local useH = GetRetrieveHeading(nearPark)

                SpawnLocalVehicle(retrieving.props.model, baseCoords, useH, function(vehicle)
                    ESX.Game.SetVehicleProperties(vehicle, retrieving.props)
                    attached = vehicle
                    AttachEntityToEntity(vehicle, spawnedProps['base'], -1, 0.0, 0.0, 0.5, 0.0, 0.0, useH, false, true, true, false, 2, false)
                end)

                while not attached do Wait(10); end
            end
            Wait(1000)
            yOff = 0.0
            while yOff > -8.0 do
                yOff = yOff - 0.15
                newCoords = GetOffsetFromEntityInWorldCoords(spawnedProps['base'], 0.0, -0.15, 0.0)
                SetEntityCoordsNoOffset(spawnedProps['base'], newCoords)
                Wait(10)
            end
            SetEntityCoordsNoOffset(spawnedProps['base'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z - 5.099)
            Wait(1000)
            Elevator('up')
        end
    end
end

function Elevator(type)
    if nearPark then
        if type == 'down' then
            local zOff = 0.0
            while zOff > -5.0 do
                zOff = zOff - 0.025
                SetEntityCoordsNoOffset(spawnedProps['base'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z + zOff)
                Wait(10)
            end
            zOff = -5.099
            SetEntityCoordsNoOffset(spawnedProps['base'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z + zOff)
            Wait(1000)
            Park('park')
        else
            local zOff = -5.0
            while zOff < 0.0 do
                zOff = zOff + 0.025
                SetEntityCoordsNoOffset(spawnedProps['base'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z + zOff)
                Wait(10)
            end
            SetEntityCoordsNoOffset(spawnedProps['base'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z)
            Wait(1000)
            Fences('down')
        end
    end
end

function Fences(type)
    if nearPark then
        if type == 'up' then
            local zOff = 0.0
            while zOff < 2.63281 do
                zOff = zOff + 0.025
                SetEntityCoordsNoOffset(spawnedProps['fence'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z + zOff)
                Wait(10)
            end
            zOff = 2.63281
            SetEntityCoordsNoOffset(spawnedProps['fence'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z + zOff)
            Wait(1000)
            Elevator('down')
        else
            local zOff = 2.63281
            while zOff > 0.0 do
                zOff = zOff - 0.025
                SetEntityCoordsNoOffset(spawnedProps['fence'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z + zOff)
                Wait(10)
            end
            SetEntityCoordsNoOffset(spawnedProps['fence'], Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z)
            if Parks[nearPark].parking == GetPlayerServerId(PlayerId()) then
                TriggerServerEvent('server:setParkState', nearPark, 'parking', false)
            end
            if retrieving and retrieving.owner == GetPlayerServerId(PlayerId()) then
                TriggerServerEvent('server:retrievalDone', nearPark, retrieving, GetEntityCoords(spawnedProps['base']))
            end
        end
    end
end

SpawnOwnedVehicle = function(modelName, coords, heading, cb)
	local model = (type(modelName) == 'number' and modelName or GetHashKey(modelName))

	Citizen.CreateThread(function()
		ESX.Streaming.RequestModel(model)

		if coords == nil then
			local playerPed = PlayerPedId()
			coords = GetEntityCoords(playerPed) -- get the position of the local player ped
			heading = GetEntityHeading(playerPed)
		end

		local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
		local id      = NetworkGetNetworkIdFromEntity(vehicle)

		SetNetworkIdCanMigrate(id, true)
		SetEntityAsMissionEntity(vehicle, true, false)
		SetVehicleHasBeenOwnedByPlayer(vehicle, true)
		SetVehicleNeedsToBeHotwired(vehicle, false)
		SetVehicleAutoRepairDisabled(vehicle, true)
		SetModelAsNoLongerNeeded(model)
		

		RequestCollisionAtCoord(coords.x, coords.y, coords.z)

		while not HasCollisionLoadedAroundEntity(vehicle) do
			RequestCollisionAtCoord(coords.x, coords.y, coords.z)
			Citizen.Wait(0)
		end

		SetVehRadioStation(vehicle, 'OFF')
		DecorSetBool(vehicle, "player_owned_veh", true)                
		if cb then
			cb(vehicle)
		end
	end)
end

local spawnedVehicles = {}

RegisterNetEvent('pw_carpark:client:spawnAuto')
AddEventHandler('pw_carpark:client:spawnAuto', function(vehicle, ins, plate)
    local vehNet = VehToNet(vehicle)
    table.insert(spawnedVehicles, { ['veh'] = vehNet, ['insurance'] = ins, ['plate'] = plate })
end)

RegisterNetEvent('pw_carpark:client:retrievalDone')
AddEventHandler('pw_carpark:client:retrievalDone', function(park, data, baseCoords)
    if nearPark == park and attached then
        DeleteVehicle(attached)
        attached = false
        SetEntityCoordsNoOffset(spawnedProps['base'], baseCoords)
        SetEntityHeading(spawnedProps['base'], Config.Parks[park].h.base)

        if data.owner == GetPlayerServerId(PlayerId()) then
            SpawnOwnedVehicle(data.props.model, GetEntityCoords(spawnedProps['base']), (Config.Parks[nearPark].h.base - 180.0), function(vehicle)
                ESX.Game.SetVehicleProperties(vehicle, data.props)
                SetVehicleEngineHealth(vehicle, data.props.engineHealth + 0.0)
                SetVehicleBodyHealth(vehicle, data.props.bodyHealth + 0.0)
                TriggerEvent('pw_carpark:client:spawnAuto', vehicle, data.ins, data.props.plate)
            end)
        end
        retrieving = false
    end
end)

RegisterNetEvent('pw_carpark:client:parkVeh')
AddEventHandler('pw_carpark:client:parkVeh', function(park, props, dmg)
    if nearPark == park then
        SpawnLocalVehicle(props.model, {x = 0.0, y = 0.0, z = 0.0}, 0.0, function(vehicle)
            ESX.Game.SetVehicleProperties(vehicle, props)
            AttachEntityToEntity(vehicle, spawnedProps['base'], -1, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            attached = vehicle
            Fences('up')
        end)
    end
end)

function AttachVehicle()
    if nearPark and not attached and not Parks[nearPark].parking then
        local rayHandle = StartShapeTestBox(Config.Parks[nearPark].pos.x, Config.Parks[nearPark].pos.y, Config.Parks[nearPark].pos.z-1.0, 5.0, 10.0, 4.0, 0.0, 0.0, 0.0, true, 2, 0)
        local _, hit, _, _, veh = GetShapeTestResult(rayHandle)
        if hit and hit ~= 0 then
            if DoesEntityExist(veh) and IsEntityAVehicle(veh) then
                if GetVehicleNumberOfPassengers(veh) == 0 and IsVehicleSeatFree(veh, -1) then
                    local vehicleProps = ESX.Game.GetVehicleProperties(veh)
                    ESX.TriggerServerCallback('server:checkOwner', function(owner)
                        if owner then
                            Wait(300)
                            while not NetworkHasControlOfEntity(veh) do
                                NetworkRequestControlOfEntity(veh)
                                Wait(10)
                            end
                            DeleteVehicle(veh)
                            TriggerServerEvent('server:parkVeh', nearPark, vehicleProps)
                        else
                            ESX.ShowNotification('This Vehicle Doesn\'t Belong To You')
                        end
                    end, vehicleProps.plate)
                end
            end
        else
            ESX.ShowNotification('There\'s No Vehicle Nearby')
        end
    end
end

SpawnLocalObjectNoOffset = function(model, coords, cb)
	local model = (type(model) == 'number' and model or GetHashKey(model))
	Citizen.CreateThread(function()
		ESX.Streaming.RequestModel(model)
		local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, true)
		if cb ~= nil then
			cb(obj)
		end
	end)
end

function SpawnProps(k, type)
    if type == 'all' then
        DeleteProps()
    end
    local spawned = 0

    if type == 'all' or type == 'fence' then
        SpawnLocalObjectNoOffset(Config.Props.fence, { x = Config.Parks[k].pos.x, y = Config.Parks[k].pos.y, z = Config.Parks[k].pos.z }, function(fenceObject)
            SetEntityHeading(fenceObject, Config.Parks[k].h.fence)
            spawnedProps['fence'] = fenceObject
            FreezeEntityPosition(spawnedProps['fence'], true)
            SetEntityCollision(spawnedProps['fence'], true, true)
            spawned = spawned + 1
        end)
    end

    if type == 'all' or type == 'base' then
        SpawnLocalObjectNoOffset(Config.Props.base, { x = Config.Parks[k].pos.x, y = Config.Parks[k].pos.y, z = Config.Parks[k].pos.z }, function(baseObject)
            SetEntityHeading(baseObject, Config.Parks[k].h.base)
            spawnedProps['base'] = baseObject
            FreezeEntityPosition(spawnedProps['base'], true)
            SetEntityCollision(spawnedProps['base'], true, true)
            spawned = spawned + 1
        end)
    end

    if type == 'all' then
        repeat Wait(10) until spawned == 2
    end
end

function DeleteProps()
    if spawnedProps['fence'] ~= nil and DoesEntityExist(spawnedProps['fence']) then
        DeleteObject(spawnedProps['fence'])
        while DoesEntityExist(spawnedProps['fence']) do Wait(10); end
        spawnedProps['fence'] = nil
    else
    
    end

    if spawnedProps['base'] ~= nil and DoesEntityExist(spawnedProps['base']) then
        DeleteObject(spawnedProps['base'])
        while DoesEntityExist(spawnedProps['base']) do Wait(10); end
        spawnedProps['base'] = nil
    end
end

RegisterNetEvent('pw_carpark:client:spawnVehicle')
AddEventHandler('pw_carpark:client:spawnVehicle', function(type, props, id, insurance)
    TriggerServerEvent('server:retrieveVehicle', id, props, insurance, props.bodyHealth)
end)

RegisterNetEvent('pw_carpark:client:retrieveVehicle')
AddEventHandler('pw_carpark:client:retrieveVehicle', function(park, props, owner, ins, dmg)
    if nearPark == park  then
        if not attached then
            retrieving = { ['props'] = props, ['ins'] = ins, ['dmg'] = dmg, ['owner'] = owner }
            Fences('up')
        end
    end
end)

RegisterNetEvent('pw_carpark:client:getParked')
AddEventHandler('pw_carpark:client:getParked', function(park)
    local menu = {}

    ESX.TriggerServerCallback('server:getParkedVehicles', function(vehs)
        if vehs then
            for k,v in pairs(vehs) do
                local props = json.decode(v.vehicle)

                local model = GetDisplayNameFromVehicleModel(props.model)
                local text = GetLabelText(model)

                table.insert(menu, {label = text..' - '..props.plate, plate = props.plate, value = 'garage_vehicle'})

                ESX.UI.Menu.CloseAll()

                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'parked_vehicles', {
                    title    = 'Automatic Car Park',
                    align    = 'center',
                    elements = menu
                }, function(data, menu)
                    if data.current.value == 'garage_vehicle' then
                        TriggerServerEvent('server:retrievalVehicle', park, data.current.plate)
                        ESX.UI.Menu.CloseAll()
                    end
                end, function(data, menu)
                    menu.close()
                end) 
            end
        else
            ESX.ShowNotification('You don\'t Have Vehicles Parked In This Car Park')
        end 
    end)
end)

RegisterNetEvent('pw_carpark:client:checkPark')
AddEventHandler('pw_carpark:client:checkPark', function()
    if not IsPedInAnyVehicle(GLOBAL_PED) then AttachVehicle(); end
end)

function DisplayHelpText(str)
	SetTextComponentFormat("STRING")
	AddTextComponentString(str)
	DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

RegisterNetEvent('OpenGarageMenu')
AddEventHandler('OpenGarageMenu', function(k, t)
    local e = {}
    table.insert(e, {label = 'Park Closet Vehicle', value = 'parkvehicle'})
    table.insert(e, {label = 'Retrieve Vehicle', value = 'getvehicle'})

    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'garage_menu', {
        title    = t,
        align    = 'center',
        elements = e
    }, function(data, menu)
        if data.current.value == 'parkvehicle' then
            TriggerEvent('pw_carpark:client:checkPark')
            ESX.UI.Menu.CloseAll()
        elseif data.current.value == 'getvehicle' then
            TriggerEvent('pw_carpark:client:getParked', k)
        end
    end, function(data, menu)
        menu.close()
    end)
end)

function HandleScreen(var)
    local title, msg, icon

    title = Config.Parks[var].name .. " | Auto-Parking"

    Citizen.CreateThread(function()
        while (playerLoaded and nearScreen == var) do
            Citizen.Wait(1)
            DisplayHelpText('Press ~INPUT_PICKUP~ To Open The Menu ~b~')
            if IsControlJustPressed(0, 38) then
                TriggerEvent('OpenGarageMenu', var, title)
            end
        end
    end)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if playerLoaded then
            for k,v in pairs(Config.Parks) do
                local dist = #(GLOBAL_COORDS - vector3(v.pos.x, v.pos.y, v.pos.z))
                if dist < Config.DrawObjects then
                    if not nearPark or (nearPark and nearPark ~= k) then
                        if nearPark and nearPark ~= k then
                            nearScreen = false
                        end
                        nearPark = k
                        SpawnProps(nearPark, 'all')
                    end

                    local screenDist = #(GLOBAL_COORDS - vector3(v.screen.x, v.screen.y, v.screen.z))
                    if screenDist < 1.2 and not Parks[k].parking then
                        if not nearScreen then
                            nearScreen = k
                            HandleScreen(nearScreen)
                        elseif nearScreen == k and Parks[k].parking then
                            nearScreen = false
                        end
                    elseif nearScreen == k then
                        nearScreen = false
                    end
                elseif nearPark == k then
                    nearPark = false
                    DeleteProps()
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1)
        if playerLoaded then
            for k,v in pairs(Config.Parks) do
                RemoveVehiclesFromGeneratorsInArea(v.screen.x - 10.0, v.screen.y - 10.0, v.screen.z - 10.0, v.screen.x + 10.0, v.screen.y + 10.0, v.screen.z + 10.0)
            end
        end
    end
end)
-- ========================================
-- PVP GUNFIGHT - ZONES DE COMBAT (VERSION ULTRA-OPTIMISÉE)
-- Dôme simplifié 16 segments + distance check
-- ========================================

DebugZones('Module chargé (version OPTIMISÉE)')

-- ========================================
-- CACHE DES NATIVES
-- ========================================
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetEntityHealth = GetEntityHealth
local SetEntityHealth = SetEntityHealth
local Wait = Wait
local GetGameTimer = GetGameTimer
local DrawLine = DrawLine

-- ========================================
-- VARIABLES
-- ========================================
local currentArenaZone = nil
local isInMatch = false
local lastDamageTime = 0

-- Configuration des dégâts hors zone
local DAMAGE_CONFIG = {
    damagePerTick = 10,
    tickInterval = 4000,
    warningDistance = 2.0,
    maxHealth = 200
}

-- ⚡ OPTIMISATION: Segments réduits pour performances
local DOME_CONFIG = {
    verticalSegments = 6,    -- Réduit de 12 à 6
    horizontalSegments = 16, -- Réduit de 32 à 16
    groundCircles = 2,       -- Réduit de 3 à 2
    maxDrawDistance = 50.0   -- Ne dessiner que si proche
}

-- ========================================
-- FONCTIONS UTILITAIRES
-- ========================================

local function IsPlayerInZone(playerPos, center, radius)
    if not center or not radius then
        DebugError('Zone invalide')
        return true
    end
    
    -- Calcul 2D optimisé
    local dx = playerPos.x - center.x
    local dy = playerPos.y - center.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    return distance <= radius
end

local function DrawGroundCircle(center, radius, r, g, b, a)
    local segments = DOME_CONFIG.horizontalSegments
    local angleStep = 360.0 / segments
    
    for i = 0, segments - 1 do
        local angle1 = math.rad(i * angleStep)
        local angle2 = math.rad((i + 1) * angleStep)
        
        local x1 = center.x + math.cos(angle1) * radius
        local y1 = center.y + math.sin(angle1) * radius
        local x2 = center.x + math.cos(angle2) * radius
        local y2 = center.y + math.sin(angle2) * radius
        
        local z1 = center.z
        local z2 = center.z
        
        DrawLine(x1, y1, z1, x2, y2, z2, r, g, b, a)
    end
end

local function DrawDome(center, radius, r, g, b, a)
    local verticalSegments = DOME_CONFIG.verticalSegments
    local horizontalSegments = DOME_CONFIG.horizontalSegments
    
    -- Cercles horizontaux
    for v = 0, verticalSegments do
        local heightRatio = v / verticalSegments
        local angle = math.rad(heightRatio * 90)
        
        local currentRadius = math.cos(angle) * radius
        local currentHeight = math.sin(angle) * radius
        
        DrawGroundCircle(
            vector3(center.x, center.y, center.z + currentHeight),
            currentRadius,
            r, g, b, a
        )
    end
    
    -- Lignes verticales
    local angleStep = 360.0 / horizontalSegments
    for i = 0, horizontalSegments - 1 do
        local baseAngle = math.rad(i * angleStep)
        
        for v = 0, verticalSegments - 1 do
            local heightRatio1 = v / verticalSegments
            local heightRatio2 = (v + 1) / verticalSegments
            
            local angle1 = math.rad(heightRatio1 * 90)
            local angle2 = math.rad(heightRatio2 * 90)
            
            local r1 = math.cos(angle1) * radius
            local h1 = math.sin(angle1) * radius
            local r2 = math.cos(angle2) * radius
            local h2 = math.sin(angle2) * radius
            
            local x1 = center.x + math.cos(baseAngle) * r1
            local y1 = center.y + math.sin(baseAngle) * r1
            local z1 = center.z + h1
            
            local x2 = center.x + math.cos(baseAngle) * r2
            local y2 = center.y + math.sin(baseAngle) * r2
            local z2 = center.z + h2
            
            DrawLine(x1, y1, z1, x2, y2, z2, r, g, b, a)
        end
    end
end

-- ========================================
-- THREAD DE DESSIN DU DOME (ULTRA-OPTIMISÉ)
-- ========================================

CreateThread(function()
    DebugZones('Thread de dessin du dome démarré (OPTIMISÉ)')
    
    while true do
        local sleep = 1000 -- Sleep par défaut
        
        if isInMatch and currentArenaZone then
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            local center = currentArenaZone.center
            local radius = currentArenaZone.radius
            
            -- ⚡ OPTIMISATION CRITIQUE: Calculer distance 2D
            local dx = playerPos.x - center.x
            local dy = playerPos.y - center.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- ⚡ NE DESSINER QUE SI LE JOUEUR EST PROCHE
            if distance < DOME_CONFIG.maxDrawDistance then
                sleep = 0 -- Dessiner chaque frame
                
                -- Cercles au sol (réduit de 3 à 2)
                for i = 1, DOME_CONFIG.groundCircles do
                    DrawGroundCircle(
                        vector3(center.x, center.y, center.z + (i * 0.1)),
                        radius,
                        0, 255, 0, 150
                    )
                end
                
                -- Dôme simplifié
                DrawDome(center, radius, 0, 255, 0, 100)
            else
                -- Très loin: ne rien dessiner, sleep long
                sleep = 500
            end
        end
        
        Wait(sleep)
    end
end)

-- ========================================
-- THREAD DE VÉRIFICATION HORS ZONE (OPTIMISÉ)
-- ========================================

CreateThread(function()
    DebugZones('Thread de vérification hors zone démarré (OPTIMISÉ)')
    
    while true do
        -- ⚡ OPTIMISATION: Sleep long si pas en match
        if not isInMatch or not currentArenaZone then
            Wait(1000)
            goto continue
        end
        
        Wait(250) -- Augmenté de 100ms à 250ms
        
        local playerPed = PlayerPedId()
        local playerPos = GetEntityCoords(playerPed)
        local center = currentArenaZone.center
        local radius = currentArenaZone.radius
        
        local isInZone = IsPlayerInZone(playerPos, center, radius)
        
        -- Calcul distance 2D optimisé
        local dx = playerPos.x - center.x
        local dy = playerPos.y - center.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if not isInZone then
            DebugWarn('Joueur hors zone! Distance: %.2fm / Rayon: %.2fm', distance, radius)
            
            local currentTime = GetGameTimer()
            
            if currentTime - lastDamageTime >= DAMAGE_CONFIG.tickInterval then
                local currentHealth = GetEntityHealth(playerPed)
                local newHealth = currentHealth - DAMAGE_CONFIG.damagePerTick
                
                DebugZones('Dégâts infligés: -%d HP (Santé: %d -> %d)', 
                    DAMAGE_CONFIG.damagePerTick, currentHealth, newHealth)
                
                SetEntityHealth(playerPed, newHealth)
                
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
                PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
                ESX.ShowNotification('~r~⚠ Vous êtes hors de la zone de combat! (' .. DAMAGE_CONFIG.damagePerTick .. ' HP)')
                
                lastDamageTime = currentTime
                
                if newHealth <= 0 then
                    DebugError('Joueur mort à cause de la zone!')
                    TriggerServerEvent('pvp:playerDiedOutsideZone')
                end
            end
            
            -- Texte hors zone
            SetTextScale(0.5, 0.5)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 0, 0, 255)
            SetTextEntry("STRING")
            AddTextComponentString(string.format("⚠ HORS ZONE! Retournez dans la zone! (%.1fm)", distance - radius))
            DrawText(0.5, 0.15)
            
        elseif distance >= (radius - DAMAGE_CONFIG.warningDistance) then
            -- Avertissement proche du bord
            local distanceToEdge = radius - distance
            
            SetTextScale(0.4, 0.4)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 165, 0, 255)
            SetTextEntry("STRING")
            AddTextComponentString(string.format("⚠ Attention! Limite de zone à %.1fm", distanceToEdge))
            DrawText(0.5, 0.15)
        end
        
        ::continue::
    end
end)

-- ========================================
-- EVENTS
-- ========================================

RegisterNetEvent('pvp:setArenaZone', function(arenaKey)
    DebugZones('Définition de la zone pour l\'arène: %s', arenaKey)
    
    local arena = Config.Arenas[arenaKey]
    
    if not arena then
        DebugError('Arène %s introuvable!', arenaKey)
        return
    end
    
    if not arena.zone then
        DebugError('L\'arène %s n\'a pas de zone définie!', arenaKey)
        return
    end
    
    currentArenaZone = {
        center = arena.zone.center,
        radius = arena.zone.radius
    }
    
    DebugZones('Zone activée - Centre: %.2f, %.2f, %.2f | Rayon: %.2f', 
        currentArenaZone.center.x, 
        currentArenaZone.center.y, 
        currentArenaZone.center.z, 
        currentArenaZone.radius)
end)

RegisterNetEvent('pvp:enableZones', function()
    DebugSuccess('Activation du système de zones')
    isInMatch = true
    lastDamageTime = GetGameTimer()
end)

RegisterNetEvent('pvp:disableZones', function()
    DebugSuccess('Désactivation du système de zones')
    isInMatch = false
    currentArenaZone = nil
    lastDamageTime = 0
end)

-- ========================================
-- CLEANUP
-- ========================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    DebugZones('Nettoyage du module zones')
    isInMatch = false
    currentArenaZone = nil
end)

DebugSuccess('Module zones initialisé (ULTRA-OPTIMISÉ: 16 segments + distance check)')

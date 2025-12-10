-- ========================================
-- PVP GUNFIGHT - MODULE DISCORD
-- Récupération des avatars Discord des joueurs
-- Version: 2.4.1 - FIX AVATAR PERSONNALISÉ
-- ========================================

DebugServer('🔵 Module Discord chargé')

-- ========================================
-- CACHE DES AVATARS
-- ========================================
local avatarCache = {}
local pendingRequests = {} -- Pour éviter les requêtes multiples simultanées
local CACHE_DURATION = 300000 -- 5 minutes en millisecondes

-- ========================================
-- CONFIGURATION
-- ========================================
local DISCORD_CONFIG = {
    defaultAvatar = Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png',
    avatarSize = Config.Discord.avatarSize or 128,
    avatarFormat = Config.Discord.avatarFormat or 'png'
}

-- ========================================
-- FONCTIONS UTILITAIRES
-- ========================================

---Récupère l'identifiant Discord d'un joueur
---@param playerId number ID du joueur
---@return string|nil discordId ID Discord (sans le préfixe "discord:") ou nil
local function GetPlayerDiscordId(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    
    if not identifiers then
        DebugWarn('❌ Aucun identifiant trouvé pour le joueur %d', playerId)
        return nil
    end
    
    -- Parcourir tous les identifiants pour trouver celui de Discord
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, 'discord:') then
            local discordId = string.gsub(identifier, 'discord:', '')
            DebugSuccess('✅ Discord ID trouvé pour joueur %d: %s', playerId, discordId)
            return discordId
        end
    end
    
    DebugWarn('⚠️ Pas de Discord lié pour le joueur %d', playerId)
    return nil
end

---Récupère l'avatar par défaut Discord basé sur l'ID
---@param discordId string ID Discord du joueur
---@return string avatarUrl URL de l'avatar par défaut
local function GetDefaultDiscordAvatar(discordId)
    -- Discord a 5 avatars par défaut (0-4) basés sur l'ID modulo 5
    local avatarIndex = tonumber(discordId) % 5
    return string.format('https://cdn.discordapp.com/embed/avatars/%d.png', avatarIndex)
end

---Récupère l'avatar Discord personnalisé via l'API Discord
---⚠️ FONCTION ASYNCHRONE - Utilise un callback
---@param playerId number ID du joueur FiveM
---@param discordId string ID Discord du joueur
---@param callback function Fonction appelée avec l'URL de l'avatar
local function FetchCustomDiscordAvatar(playerId, discordId, callback)
    -- Vérifier si le token est configuré
    if not Config.Discord.botToken or Config.Discord.botToken == '' then
        DebugWarn('⚠️ Token Discord non configuré - Impossible de récupérer l\'avatar personnalisé')
        callback(GetDefaultDiscordAvatar(discordId))
        return
    end
    
    -- Vérifier si une requête est déjà en cours pour ce joueur
    if pendingRequests[playerId] then
        DebugServer('⏳ Requête déjà en cours pour le joueur %d, ajout à la file d\'attente', playerId)
        table.insert(pendingRequests[playerId], callback)
        return
    end
    
    -- Initialiser la file d'attente des callbacks pour ce joueur
    pendingRequests[playerId] = {callback}
    
    DebugServer('🌐 Appel API Discord pour récupérer l\'avatar du joueur %d (Discord ID: %s)', playerId, discordId)
    
    -- Appel à l'API Discord
    PerformHttpRequest(
        'https://discord.com/api/v10/users/' .. discordId,
        function(statusCode, responseBody, headers)
            local callbacks = pendingRequests[playerId]
            pendingRequests[playerId] = nil
            
            if statusCode == 200 then
                -- Succès - Parse la réponse JSON
                local success, data = pcall(json.decode, responseBody)
                
                if success and data and data.avatar then
                    -- Le joueur a un avatar personnalisé
                    local avatarUrl = string.format(
                        'https://cdn.discordapp.com/avatars/%s/%s.%s?size=%d',
                        discordId,
                        data.avatar,
                        DISCORD_CONFIG.avatarFormat,
                        DISCORD_CONFIG.avatarSize
                    )
                    
                    DebugSuccess('✅ Avatar personnalisé récupéré pour le joueur %d: %s', playerId, avatarUrl)
                    
                    -- Mettre à jour le cache
                    avatarCache[playerId] = {
                        url = avatarUrl,
                        discordId = discordId,
                        timestamp = GetGameTimer()
                    }
                    
                    -- Appeler tous les callbacks en attente
                    for _, cb in ipairs(callbacks) do
                        cb(avatarUrl)
                    end
                else
                    -- Le joueur n'a pas d'avatar personnalisé (utilise l'avatar par défaut Discord)
                    local defaultUrl = GetDefaultDiscordAvatar(discordId)
                    DebugServer('📋 Pas d\'avatar personnalisé pour le joueur %d, utilisation de l\'avatar par défaut', playerId)
                    
                    avatarCache[playerId] = {
                        url = defaultUrl,
                        discordId = discordId,
                        timestamp = GetGameTimer()
                    }
                    
                    for _, cb in ipairs(callbacks) do
                        cb(defaultUrl)
                    end
                end
            elseif statusCode == 401 then
                -- Token invalide
                DebugError('❌ ERREUR: Token Discord invalide (401 Unauthorized)')
                DebugError('Vérifiez votre token dans config.lua')
                
                local defaultUrl = GetDefaultDiscordAvatar(discordId)
                for _, cb in ipairs(callbacks) do
                    cb(defaultUrl)
                end
            elseif statusCode == 429 then
                -- Rate limit atteint
                DebugError('❌ ERREUR: Rate limit Discord atteint (429 Too Many Requests)')
                DebugError('Attendez quelques secondes avant de réessayer')
                
                local defaultUrl = GetDefaultDiscordAvatar(discordId)
                for _, cb in ipairs(callbacks) do
                    cb(defaultUrl)
                end
            else
                -- Autre erreur
                DebugError('❌ Erreur API Discord (Status: %d) pour le joueur %d', statusCode, playerId)
                DebugError('Réponse: %s', responseBody or 'Aucune réponse')
                
                local defaultUrl = GetDefaultDiscordAvatar(discordId)
                for _, cb in ipairs(callbacks) do
                    cb(defaultUrl)
                end
            end
        end,
        'GET',
        '',
        {
            ['Authorization'] = 'Bot ' .. Config.Discord.botToken,
            ['Content-Type'] = 'application/json'
        }
    )
end

---Récupère l'URL de l'avatar Discord d'un joueur (VERSION ASYNCHRONE)
---⚠️ CETTE FONCTION EST ASYNCHRONE - Elle utilise un callback
---@param playerId number ID du joueur FiveM
---@param callback function Fonction appelée avec l'URL de l'avatar
function GetPlayerDiscordAvatarAsync(playerId, callback)
    -- Vérifier le cache
    local cached = avatarCache[playerId]
    if cached and (GetGameTimer() - cached.timestamp) < CACHE_DURATION then
        DebugServer('📦 Avatar en cache pour le joueur %d', playerId)
        callback(cached.url)
        return
    end
    
    -- Récupérer l'ID Discord
    local discordId = GetPlayerDiscordId(playerId)
    
    if not discordId then
        DebugWarn('⚠️ Pas de Discord lié pour le joueur %d - Utilisation de l\'avatar par défaut', playerId)
        callback(DISCORD_CONFIG.defaultAvatar)
        return
    end
    
    -- Appeler l'API Discord de manière asynchrone
    FetchCustomDiscordAvatar(playerId, discordId, callback)
end

---Récupère l'URL de l'avatar Discord d'un joueur (VERSION SYNCHRONE - MOINS FIABLE)
---⚠️ Cette version retourne immédiatement l'avatar en cache ou par défaut
---Pour les avatars personnalisés, utilisez GetPlayerDiscordAvatarAsync avec un callback
---@param playerId number ID du joueur FiveM
---@return string avatarUrl URL de l'avatar (cache ou défaut)
function GetPlayerDiscordAvatar(playerId)
    -- Vérifier le cache
    local cached = avatarCache[playerId]
    if cached then
        return cached.url
    end
    
    -- Récupérer l'ID Discord
    local discordId = GetPlayerDiscordId(playerId)
    
    if not discordId then
        return DISCORD_CONFIG.defaultAvatar
    end
    
    -- Si pas en cache, lancer une requête async et retourner l'avatar par défaut en attendant
    CreateThread(function()
        GetPlayerDiscordAvatarAsync(playerId, function(avatarUrl)
            -- L'avatar sera disponible au prochain appel grâce au cache
            DebugServer('🔄 Avatar récupéré et mis en cache pour le joueur %d', playerId)
        end)
    end)
    
    -- Retourner temporairement l'avatar par défaut
    return GetDefaultDiscordAvatar(discordId)
end

---Récupère les informations Discord complètes d'un joueur
---@param playerId number ID du joueur
---@return table discordInfo Informations Discord
function GetPlayerDiscordInfo(playerId)
    local discordId = GetPlayerDiscordId(playerId)
    
    -- Vérifier le cache pour l'avatar
    local avatarUrl = DISCORD_CONFIG.defaultAvatar
    local cached = avatarCache[playerId]
    if cached then
        avatarUrl = cached.url
    elseif discordId then
        avatarUrl = GetDefaultDiscordAvatar(discordId)
    end
    
    return {
        discordId = discordId,
        avatarUrl = avatarUrl,
        hasDiscord = discordId ~= nil
    }
end

---Précharge les avatars pour une liste de joueurs de manière asynchrone
---@param playerIds table Liste des IDs de joueurs
---@param callback function Fonction appelée une fois tous les avatars chargés
function PreloadAvatarsAsync(playerIds, callback)
    DebugServer('📥 Préchargement des avatars pour %d joueurs', #playerIds)
    
    local completed = 0
    local total = #playerIds
    
    if total == 0 then
        callback()
        return
    end
    
    for _, playerId in ipairs(playerIds) do
        GetPlayerDiscordAvatarAsync(playerId, function(avatarUrl)
            completed = completed + 1
            DebugServer('✅ Avatar chargé pour joueur %d (%d/%d)', playerId, completed, total)
            
            if completed == total then
                DebugSuccess('✅ Tous les avatars ont été préchargés!')
                callback()
            end
        end)
    end
end

---Nettoie le cache des avatars expirés
local function CleanAvatarCache()
    local currentTime = GetGameTimer()
    local cleaned = 0
    
    for playerId, cached in pairs(avatarCache) do
        if (currentTime - cached.timestamp) > CACHE_DURATION then
            avatarCache[playerId] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        DebugServer('🧹 Cache avatars nettoyé: %d entrées supprimées', cleaned)
    end
end

-- Nettoyage périodique du cache (toutes les 10 minutes)
CreateThread(function()
    while true do
        Wait(600000) -- 10 minutes
        CleanAvatarCache()
    end
end)

-- ========================================
-- ÉVÉNEMENT DE DÉCONNEXION
-- ========================================
AddEventHandler('playerDropped', function()
    local src = source
    avatarCache[src] = nil
    pendingRequests[src] = nil
end)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetPlayerDiscordId', GetPlayerDiscordId)
exports('GetPlayerDiscordAvatar', GetPlayerDiscordAvatar)
exports('GetPlayerDiscordAvatarAsync', GetPlayerDiscordAvatarAsync)
exports('GetPlayerDiscordInfo', GetPlayerDiscordInfo)
exports('PreloadAvatarsAsync', PreloadAvatarsAsync)

-- ========================================
-- VÉRIFICATION DU TOKEN AU DÉMARRAGE
-- ========================================
CreateThread(function()
    Wait(2000) -- Attendre que tout soit chargé
    
    if not Config.Discord.enabled then
        DebugWarn('⚠️ Système d\'avatars Discord DÉSACTIVÉ dans config.lua')
        return
    end
    
    if not Config.Discord.botToken or Config.Discord.botToken == '' then
        DebugError('═══════════════════════════════════════════════════════')
        DebugError('❌ ATTENTION: Token Discord NON CONFIGURÉ!')
        DebugError('Les avatars personnalisés NE FONCTIONNERONT PAS')
        DebugError('═══════════════════════════════════════════════════════')
        DebugError('📋 Pour configurer le token:')
        DebugError('1. Va sur https://discord.com/developers/applications')
        DebugError('2. Crée une application et un bot')
        DebugError('3. Active "Server Members Intent" dans Bot > Privileged Gateway Intents')
        DebugError('4. Copie le token et colle-le dans config.lua')
        DebugError('═══════════════════════════════════════════════════════')
    else
        DebugSuccess('═══════════════════════════════════════════════════════')
        DebugSuccess('✅ Token Discord configuré - Test de connexion...')
        DebugSuccess('═══════════════════════════════════════════════════════')
        
        -- Test rapide du token (utilise l'endpoint /users/@me qui retourne les infos du bot)
        PerformHttpRequest(
            'https://discord.com/api/v10/users/@me',
            function(statusCode, responseBody, headers)
                if statusCode == 200 then
                    local success, data = pcall(json.decode, responseBody)
                    if success and data then
                        DebugSuccess('═══════════════════════════════════════════════════════')
                        DebugSuccess('✅ Connexion à l\'API Discord réussie!')
                        DebugSuccess('Bot connecté: %s#%s', data.username or 'Unknown', data.discriminator or '0000')
                        DebugSuccess('Les avatars personnalisés fonctionneront correctement!')
                        DebugSuccess('═══════════════════════════════════════════════════════')
                    end
                elseif statusCode == 401 then
                    DebugError('═══════════════════════════════════════════════════════')
                    DebugError('❌ TOKEN DISCORD INVALIDE (401 Unauthorized)')
                    DebugError('Vérifiez que vous avez copié le token correctement')
                    DebugError('═══════════════════════════════════════════════════════')
                else
                    DebugError('═══════════════════════════════════════════════════════')
                    DebugError('❌ Erreur lors du test de connexion Discord (Status: %d)', statusCode)
                    DebugError('Réponse: %s', responseBody or 'Aucune réponse')
                    DebugError('═══════════════════════════════════════════════════════')
                end
            end,
            'GET',
            '',
            {
                ['Authorization'] = 'Bot ' .. Config.Discord.botToken,
                ['Content-Type'] = 'application/json'
            }
        )
    end
end)

DebugSuccess('✅ Module Discord initialisé (Version 2.4.1 - Fix avatar personnalisé)')

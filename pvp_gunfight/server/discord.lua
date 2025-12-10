-- ========================================
-- PVP GUNFIGHT - MODULE DISCORD
-- Récupération des avatars Discord des joueurs
-- Version: 2.4.0
-- ========================================

DebugServer('🔵 Module Discord chargé')

-- ========================================
-- CACHE DES AVATARS
-- ========================================
local avatarCache = {}
local CACHE_DURATION = 300000 -- 5 minutes en millisecondes

-- ========================================
-- CONFIGURATION
-- ========================================
local DISCORD_CONFIG = {
    defaultAvatar = 'https://cdn.discordapp.com/embed/avatars/0.png',
    avatarSize = 128, -- Taille de l'avatar (64, 128, 256, 512, 1024)
    avatarFormat = 'png' -- png, jpg, webp, gif
}

-- ========================================
-- FONCTIONS UTILITAIRES
-- ========================================

---Récupère l'identifiant Discord d'un joueur
---@param playerId number ID du joueur
---@return string|nil discordId ID Discord ou nil
local function GetPlayerDiscordId(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    
    if not identifiers then
        DebugWarn('Aucun identifiant trouvé pour le joueur %d', playerId)
        return nil
    end
    
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, 'discord:') then
            local discordId = string.gsub(identifier, 'discord:', '')
            DebugServer('Discord ID trouvé pour joueur %d: %s', playerId, discordId)
            return discordId
        end
    end
    
    DebugWarn('Pas de Discord lié pour le joueur %d', playerId)
    return nil
end

---Récupère l'URL de l'avatar Discord d'un joueur
---@param playerId number ID du joueur
---@return string avatarUrl URL de l'avatar
function GetPlayerDiscordAvatar(playerId)
    -- Vérifier le cache
    local cached = avatarCache[playerId]
    if cached and (GetGameTimer() - cached.timestamp) < CACHE_DURATION then
        DebugServer('Avatar en cache pour joueur %d', playerId)
        return cached.url
    end
    
    local discordId = GetPlayerDiscordId(playerId)
    
    if not discordId then
        return DISCORD_CONFIG.defaultAvatar
    end
    
    -- Construire l'URL de l'avatar Discord
    -- Format: https://cdn.discordapp.com/avatars/{user_id}/{avatar_hash}.{format}?size={size}
    -- Note: Sans le hash d'avatar, on utilise l'API embed pour un avatar par défaut basé sur l'ID
    local avatarUrl = string.format(
        'https://cdn.discordapp.com/embed/avatars/%d.png',
        tonumber(discordId) % 5 -- Discord a 5 avatars par défaut (0-4)
    )
    
    -- Mettre en cache
    avatarCache[playerId] = {
        url = avatarUrl,
        discordId = discordId,
        timestamp = GetGameTimer()
    }
    
    DebugSuccess('Avatar Discord généré pour joueur %d: %s', playerId, avatarUrl)
    
    return avatarUrl
end

---Récupère les informations Discord complètes d'un joueur
---@param playerId number ID du joueur
---@return table discordInfo Informations Discord
function GetPlayerDiscordInfo(playerId)
    local discordId = GetPlayerDiscordId(playerId)
    local avatarUrl = GetPlayerDiscordAvatar(playerId)
    
    return {
        discordId = discordId,
        avatarUrl = avatarUrl,
        hasDiscord = discordId ~= nil
    }
end

---Récupère l'avatar avec l'API Discord (nécessite un token bot)
---Cette fonction est optionnelle et nécessite une configuration supplémentaire
---@param discordId string ID Discord du joueur
---@param callback function Callback avec l'URL de l'avatar
function FetchDiscordAvatarFromAPI(discordId, callback)
    -- Cette fonction nécessite un bot Discord configuré
    -- Elle est fournie pour une utilisation future avec discord_perms ou badger_discord_api
    
    if Config.Discord and Config.Discord.botToken and Config.Discord.botToken ~= '' then
        PerformHttpRequest(
            'https://discord.com/api/v10/users/' .. discordId,
            function(statusCode, response, headers)
                if statusCode == 200 then
                    local data = json.decode(response)
                    if data and data.avatar then
                        local avatarUrl = string.format(
                            'https://cdn.discordapp.com/avatars/%s/%s.%s?size=%d',
                            discordId,
                            data.avatar,
                            DISCORD_CONFIG.avatarFormat,
                            DISCORD_CONFIG.avatarSize
                        )
                        
                        -- Mettre en cache avec le vrai avatar
                        for playerId, cached in pairs(avatarCache) do
                            if cached.discordId == discordId then
                                avatarCache[playerId].url = avatarUrl
                                avatarCache[playerId].timestamp = GetGameTimer()
                                break
                            end
                        end
                        
                        callback(avatarUrl)
                        return
                    end
                end
                
                -- Fallback sur l'avatar par défaut
                callback(string.format(
                    'https://cdn.discordapp.com/embed/avatars/%d.png',
                    tonumber(discordId) % 5
                ))
            end,
            'GET',
            '',
            {
                ['Authorization'] = 'Bot ' .. Config.Discord.botToken,
                ['Content-Type'] = 'application/json'
            }
        )
    else
        -- Sans bot token, utiliser l'avatar par défaut
        callback(string.format(
            'https://cdn.discordapp.com/embed/avatars/%d.png',
            tonumber(discordId) % 5
        ))
    end
end

---Précharge les avatars pour une liste de joueurs
---@param playerIds table Liste des IDs de joueurs
function PreloadAvatars(playerIds)
    DebugServer('Préchargement des avatars pour %d joueurs', #playerIds)
    
    for _, playerId in ipairs(playerIds) do
        GetPlayerDiscordAvatar(playerId)
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
        DebugServer('Cache avatars nettoyé: %d entrées supprimées', cleaned)
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
end)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetPlayerDiscordId', GetPlayerDiscordId)
exports('GetPlayerDiscordAvatar', GetPlayerDiscordAvatar)
exports('GetPlayerDiscordInfo', GetPlayerDiscordInfo)
exports('PreloadAvatars', PreloadAvatars)

DebugSuccess('✅ Module Discord initialisé')
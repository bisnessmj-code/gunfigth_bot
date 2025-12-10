-- ========================================
-- PVP GUNFIGHT - SYSTÈME DE DEBUG
-- Fonctions helper pour logs conditionnels
-- ========================================

-- Codes couleurs ANSI pour la console
local COLORS = {
    reset = '^7',
    white = '^0',
    red = '^1',
    green = '^2',
    yellow = '^3',
    blue = '^4',
    cyan = '^5',
    pink = '^6',
    orange = '^9'
}

-- ========================================
-- FONCTION PRINCIPALE DE DEBUG
-- ========================================

---Affiche un message de debug si activé
---@param category string Catégorie du log (info, success, warning, error, client, server, ui, bucket, elo, zones, groups, matchmaking)
---@param message string Message à afficher
---@param ... any Arguments supplémentaires (optionnels)
function DebugPrint(category, message, ...)
    -- Vérifier si le debug est activé globalement
    if not Config.Debug or not Config.Debug.enabled then
        return
    end
    
    -- Vérifier si la catégorie est activée
    if not Config.Debug.levels[category] then
        return
    end
    
    -- Construire le préfixe avec couleur selon la catégorie
    local prefix = ''
    local color = COLORS.white
    
    if category == 'success' then
        color = COLORS.green
        prefix = '[PVP SUCCESS]'
    elseif category == 'warning' then
        color = COLORS.yellow
        prefix = '[PVP WARNING]'
    elseif category == 'error' then
        color = COLORS.red
        prefix = '[PVP ERROR]'
    elseif category == 'client' then
        color = COLORS.cyan
        prefix = '[PVP CLIENT]'
    elseif category == 'server' then
        color = COLORS.blue
        prefix = '[PVP SERVER]'
    elseif category == 'ui' then
        color = COLORS.pink
        prefix = '[PVP UI]'
    elseif category == 'bucket' then
        color = COLORS.orange
        prefix = '[PVP BUCKET]'
    elseif category == 'elo' then
        color = COLORS.green
        prefix = '[PVP ELO]'
    elseif category == 'zones' then
        color = COLORS.yellow
        prefix = '[PVP ZONES]'
    elseif category == 'groups' then
        color = COLORS.cyan
        prefix = '[PVP GROUPS]'
    elseif category == 'matchmaking' then
        color = COLORS.blue
        prefix = '[PVP MATCHMAKING]'
    else
        color = COLORS.white
        prefix = '[PVP INFO]'
    end
    
    -- Formater le message avec arguments supplémentaires si fournis
    local formattedMessage = message
    if ... then
        formattedMessage = string.format(message, ...)
    end
    
    -- Afficher le log avec couleur
    print(color .. prefix .. COLORS.reset .. ' ' .. formattedMessage)
end

-- ========================================
-- FONCTIONS RACCOURCIES
-- ========================================

-- Log d'information générale
function DebugInfo(message, ...)
    DebugPrint('info', message, ...)
end

-- Log de succès
function DebugSuccess(message, ...)
    DebugPrint('success', message, ...)
end

-- Log d'avertissement
function DebugWarn(message, ...)
    DebugPrint('warning', message, ...)
end

-- Log d'erreur
function DebugError(message, ...)
    DebugPrint('error', message, ...)
end

-- Log client
function DebugClient(message, ...)
    DebugPrint('client', message, ...)
end

-- Log server
function DebugServer(message, ...)
    DebugPrint('server', message, ...)
end

-- Log UI/NUI
function DebugUI(message, ...)
    DebugPrint('ui', message, ...)
end

-- Log routing buckets
function DebugBucket(message, ...)
    DebugPrint('bucket', message, ...)
end

-- Log système ELO
function DebugElo(message, ...)
    DebugPrint('elo', message, ...)
end

-- Log système de zones
function DebugZones(message, ...)
    DebugPrint('zones', message, ...)
end

-- Log système de groupes
function DebugGroups(message, ...)
    DebugPrint('groups', message, ...)
end

-- Log matchmaking
function DebugMatchmaking(message, ...)
    DebugPrint('matchmaking', message, ...)
end

-- ========================================
-- FONCTIONS POUR DÉBOGAGE AVANCÉ
-- ========================================

-- Affiche une table de manière formatée (avec debug activé)
function DebugTable(category, tableName, tbl)
    if not Config.Debug or not Config.Debug.enabled then
        return
    end
    
    if not Config.Debug.levels[category] then
        return
    end
    
    DebugPrint(category, '========== TABLE: %s ==========', tableName)
    
    if type(tbl) ~= 'table' then
        DebugPrint(category, 'Valeur: %s (type: %s)', tostring(tbl), type(tbl))
        return
    end
    
    for key, value in pairs(tbl) do
        if type(value) == 'table' then
            DebugPrint(category, '  %s = [TABLE]', tostring(key))
        else
            DebugPrint(category, '  %s = %s', tostring(key), tostring(value))
        end
    end
    
    DebugPrint(category, '========================================')
end

-- Mesure et affiche le temps d'exécution d'une fonction
function DebugPerformance(category, label, func)
    if not Config.Debug or not Config.Debug.enabled then
        return func()
    end
    
    if not Config.Debug.levels[category] then
        return func()
    end
    
    local startTime = GetGameTimer()
    local result = func()
    local endTime = GetGameTimer()
    local duration = endTime - startTime
    
    DebugPrint(category, '[PERFORMANCE] %s: %dms', label, duration)
    
    return result
end

-- Log uniquement si une condition est vraie
function DebugIf(condition, category, message, ...)
    if condition then
        DebugPrint(category, message, ...)
    end
end

-- ========================================
-- EXPORTS
-- ========================================

-- Permet d'utiliser ces fonctions dans d'autres ressources
if IsDuplicityVersion() then
    -- Côté serveur
    exports('DebugPrint', DebugPrint)
    exports('DebugInfo', DebugInfo)
    exports('DebugSuccess', DebugSuccess)
    exports('DebugWarn', DebugWarn)
    exports('DebugError', DebugError)
    exports('DebugServer', DebugServer)
    exports('DebugTable', DebugTable)
    exports('DebugPerformance', DebugPerformance)
else
    -- Côté client
    exports('DebugPrint', DebugPrint)
    exports('DebugInfo', DebugInfo)
    exports('DebugSuccess', DebugSuccess)
    exports('DebugWarn', DebugWarn)
    exports('DebugError', DebugError)
    exports('DebugClient', DebugClient)
    exports('DebugUI', DebugUI)
    exports('DebugZones', DebugZones)
    exports('DebugTable', DebugTable)
    exports('DebugPerformance', DebugPerformance)
end

DebugSuccess('Système de debug chargé - Debug %s', Config.Debug.enabled and 'ACTIVÉ' or 'DÉSACTIVÉ')

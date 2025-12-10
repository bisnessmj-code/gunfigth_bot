-- ========================================
-- PVP GUNFIGHT - SERVER MAIN  
-- Version: 2.4.1 - Fix avatars Discord asynchrones
-- ========================================

DebugServer('Chargement du système PVP avec instances et ELO...')

local queues = {
    ['1v1'] = {},
    ['2v2'] = {},
    ['3v3'] = {},
    ['4v4'] = {}
}

local activeMatches = {}
local playersInQueue = {}
local playerCurrentMatch = {}
local playerCurrentBucket = {}

local nextBucketId = 100

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pvp_stats (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(50) UNIQUE,
            name VARCHAR(50),
            elo INT DEFAULT 1000,
            kills INT DEFAULT 0,
            deaths INT DEFAULT 0,
            matches_played INT DEFAULT 0,
            wins INT DEFAULT 0,
            losses INT DEFAULT 0,
            best_elo INT DEFAULT 1000,
            rank_id INT DEFAULT 1,
            discord_id VARCHAR(50) DEFAULT NULL,
            discord_avatar VARCHAR(255) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
    
    -- Migration pour ajouter les colonnes Discord si elles n'existent pas
    MySQL.query([[
        ALTER TABLE pvp_stats 
        ADD COLUMN IF NOT EXISTS discord_id VARCHAR(50) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS discord_avatar VARCHAR(255) DEFAULT NULL
    ]])
    
    DebugSuccess('Base de données initialisée')
end)

-- ========================================
-- GESTION ROUTING BUCKETS (CORRIGÉE)
-- ========================================

local function CreateMatchBucket()
    local bucketId = nextBucketId
    nextBucketId = nextBucketId + 1
    
    DebugBucket('✅ Création du bucket %d', bucketId)
    
    -- Configuration du bucket pour permettre la synchronisation
    SetRoutingBucketPopulationEnabled(bucketId, true)
    SetRoutingBucketEntityLockdownMode(bucketId, 'strict') -- Mode strict pour empêcher les entités externes
    
    return bucketId
end

local function SetPlayerBucket(playerId, bucketId)
    if playerId <= 0 then return end
    
    SetPlayerRoutingBucket(playerId, bucketId)
    playerCurrentBucket[playerId] = bucketId
    
    DebugBucket('🔵 Joueur %d assigné au bucket %d', playerId, bucketId)
    
    -- Petit délai pour s'assurer que le bucket est bien appliqué
    Wait(100)
end

local function ResetPlayerBucket(playerId)
    if playerId <= 0 then return end
    
    SetPlayerRoutingBucket(playerId, 0)
    playerCurrentBucket[playerId] = nil
    
    DebugBucket('🟢 Joueur %d remis dans le bucket public (0)', playerId)
end

-- ========================================
-- FONCTIONS UTILITAIRES
-- ========================================

local function SyncAllPlayersInMatch(matchId)
    local match = activeMatches[matchId]
    if not match then return end
    
    DebugBucket('🔄 Synchronisation de tous les joueurs du match %d dans le bucket %d', matchId, match.bucketId)
    
    -- S'assurer que TOUS les joueurs sont dans le même bucket
    for _, playerId in ipairs(match.players) do
        if playerId > 0 then
            local currentBucket = GetPlayerRoutingBucket(playerId)
            if currentBucket ~= match.bucketId then
                DebugWarn('⚠️ Joueur %d pas dans le bon bucket (%d vs %d), correction...', playerId, currentBucket, match.bucketId)
                SetPlayerBucket(playerId, match.bucketId)
            end
        end
    end
end

-- ========================================
-- MATCHMAKING
-- ========================================

RegisterNetEvent('pvp:joinQueue', function(mode)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    DebugMatchmaking('%s (%d) veut rejoindre la queue %s', xPlayer.getName(), src, mode)
    
    if playersInQueue[src] then
        DebugWarn('Joueur déjà en queue')
        TriggerClientEvent('esx:showNotification', src, '~r~Vous êtes déjà en file d\'attente!')
        return
    end
    
    local group = exports['pvp_gunfight']:GetPlayerGroup(src)
    
    local playersToQueue = {}
    
    if group then
        DebugMatchmaking('Joueur dans un groupe avec %d membres', #group.members)
        
        if group.leaderId ~= src then
            DebugWarn('N\'est pas le leader')
            TriggerClientEvent('esx:showNotification', src, '~r~Seul le leader peut lancer la recherche!')
            return
        end
        
        local playersNeededPerTeam = tonumber(mode:sub(1, 1))
        
        if #group.members ~= playersNeededPerTeam then
            DebugWarn('Mauvaise taille de groupe : %d au lieu de %d', #group.members, playersNeededPerTeam)
            TriggerClientEvent('esx:showNotification', src, string.format('~r~Il faut exactement %d joueur(s) dans le groupe pour le mode %s!', playersNeededPerTeam, mode))
            return
        end
        
        local allReady = true
        for memberId, isReady in pairs(group.ready) do
            if not isReady then
                allReady = false
                break
            end
        end
        
        if not allReady then
            DebugWarn('Tous les membres ne sont pas prêts')
            TriggerClientEvent('esx:showNotification', src, '~r~Tous les membres doivent être prêts!')
            return
        end
        
        for _, memberId in ipairs(group.members) do
            table.insert(playersToQueue, memberId)
        end
        
        DebugMatchmaking('Ajout de %d joueurs du groupe à la queue', #playersToQueue)
        
    else
        DebugMatchmaking('Joueur solo')
        
        if mode ~= '1v1' then
            TriggerClientEvent('esx:showNotification', src, '~r~Vous devez être dans un groupe pour les modes 2v2, 3v3 et 4v4!')
            return
        end
        
        table.insert(playersToQueue, src)
    end
    
    for _, playerId in ipairs(playersToQueue) do
        table.insert(queues[mode], playerId)
        playersInQueue[playerId] = {
            mode = mode,
            startTime = os.time(),
            groupMembers = playersToQueue
        }
        
        TriggerClientEvent('pvp:searchStarted', playerId, mode)
        TriggerClientEvent('esx:showNotification', playerId, '~b~Recherche de partie en cours...')
    end
    
    DebugMatchmaking('Queue %s: %d joueurs (ajout de %d)', mode, #queues[mode], #playersToQueue)
    
    CheckAndCreateMatch(mode)
end)

function CheckAndCreateMatch(mode)
    local playersNeeded = tonumber(mode:sub(1, 1)) * 2
    
    DebugMatchmaking('Check queue %s : %d/%d joueurs', mode, #queues[mode], playersNeeded)
    
    if #queues[mode] >= playersNeeded then
        local matchPlayers = {}
        
        for i = 1, playersNeeded do
            local playerId = table.remove(queues[mode], 1)
            table.insert(matchPlayers, playerId)
            DebugMatchmaking('Joueur %d ajouté au match', playerId)
        end
        
        CreateMatch(mode, matchPlayers)
    else
        DebugMatchmaking('Pas assez de joueurs (%d/%d)', #queues[mode], playersNeeded)
    end
end

local function GetRandomArena()
    local arenaKeys = {}
    for key, _ in pairs(Config.Arenas) do
        table.insert(arenaKeys, key)
    end
    
    local randomIndex = math.random(1, #arenaKeys)
    local arenaKey = arenaKeys[randomIndex]
    
    DebugServer('Arène sélectionnée: %s (%s)', arenaKey, Config.Arenas[arenaKey].name)
    
    return arenaKey, Config.Arenas[arenaKey]
end

function CreateMatch(mode, players)
    local matchId = #activeMatches + 1
    
    DebugServer('========== CRÉATION MATCH %d ==========', matchId)
    DebugServer('Mode: %s avec %d joueurs', mode, #players)
    
    local bucketId = CreateMatchBucket()
    
    local arenaKey, arena = GetRandomArena()
    
    activeMatches[matchId] = {
        mode = mode,
        players = players,
        arena = arenaKey,
        bucketId = bucketId,
        team1 = {},
        team2 = {},
        playerTeams = {},
        score = {team1 = 0, team2 = 0},
        currentRound = 1,
        status = 'starting',
        startTime = os.time()
    }
    
    local halfSize = #players / 2
    for i, playerId in ipairs(players) do
        local team = nil
        
        if i <= halfSize then
            table.insert(activeMatches[matchId].team1, playerId)
            team = 'team1'
        else
            table.insert(activeMatches[matchId].team2, playerId)
            team = 'team2'
        end
        
        activeMatches[matchId].playerTeams[playerId] = team
        
        DebugServer('Joueur %d assigné à %s', playerId, team)
        
        playersInQueue[playerId] = nil
        playerCurrentMatch[playerId] = matchId
        
        if playerId > 0 then
            exports['pvp_gunfight']:RemovePlayerFromGroup(playerId)
        end
    end
    
    DebugServer('Match %d - Bucket: %d', matchId, bucketId)
    DebugServer('Team 1: %d joueurs, Team 2: %d joueurs', 
        #activeMatches[matchId].team1, #activeMatches[matchId].team2)
    
    -- 🔥 IMPORTANT: Assigner TOUS les joueurs au bucket AVANT la téléportation
    DebugBucket('📌 Attribution des buckets à tous les joueurs...')
    for _, playerId in ipairs(players) do
        SetPlayerBucket(playerId, bucketId)
    end
    
    -- Petit délai pour s'assurer que les buckets sont appliqués
    Wait(200)
    
    -- Vérifier que tous les joueurs sont bien dans le bucket
    SyncAllPlayersInMatch(matchId)
    
    -- Notification match trouvé
    for _, playerId in ipairs(players) do
        TriggerClientEvent('pvp:matchFound', playerId)
        TriggerClientEvent('esx:showNotification', playerId, '~g~Match trouvé! ~w~Arène: ~b~' .. arena.name)
        TriggerClientEvent('pvp:showScoreHUD', playerId, activeMatches[matchId].score, activeMatches[matchId].currentRound)
    end
    
    -- Téléportation des joueurs
    TeleportPlayersToArena(matchId, activeMatches[matchId], arena, arenaKey)
    
    Wait(3000)
    
    -- Re-vérifier la synchronisation avant le freeze
    SyncAllPlayersInMatch(matchId)
    
    for _, playerId in ipairs(players) do
        if playerId > 0 then
            TriggerClientEvent('pvp:freezePlayer', playerId)
        end
    end
    
    Wait(1000)
    
    StartRound(matchId, activeMatches[matchId], arena)
    
    DebugSuccess('✅ Match %d créé: %s sur %s (Bucket: %d)', matchId, mode, arena.name, bucketId)
end

function TeleportPlayersToArena(matchId, match, arena, arenaKey)
    DebugServer('Téléportation des joueurs pour le match %d', matchId)
    
    for i, playerId in ipairs(match.team1) do
        if arena.teamA[i] then
            local spawn = arena.teamA[i]
            
            if playerId > 0 then
                DebugServer('Team 1 - Joueur %d -> Spawn A%d', playerId, i)
                TriggerClientEvent('pvp:teleportToSpawn', playerId, spawn, 'team1', matchId, arenaKey)
            end
        end
    end
    
    for i, playerId in ipairs(match.team2) do
        if arena.teamB[i] then
            local spawn = arena.teamB[i]
            
            if playerId > 0 then
                DebugServer('Team 2 - Joueur %d -> Spawn B%d', playerId, i)
                TriggerClientEvent('pvp:teleportToSpawn', playerId, spawn, 'team2', matchId, arenaKey)
            end
        end
    end
end

-- ========================================
-- ⚡ CALLBACK STATS AVEC AVATARS ASYNCHRONES
-- ========================================

ESX.RegisterServerCallback('pvp:getPlayerStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then 
        cb(nil)
        return 
    end
    
    DebugServer('Récupération stats pour %s (%s)', xPlayer.getName(), xPlayer.identifier)
    
    MySQL.single('SELECT * FROM pvp_stats WHERE identifier = ?', {
        xPlayer.identifier
    }, function(result)
        if result then
            DebugServer('Stats trouvées: ELO %d, Kills %d, Deaths %d', result.elo, result.kills or 0, result.deaths or 0)
            
            result.name = result.name or xPlayer.getName()
            result.kills = result.kills or 0
            result.deaths = result.deaths or 0
            
            -- ⚡ CHANGEMENT: Récupérer l'avatar de manière asynchrone
            if Config.Discord and Config.Discord.enabled then
                exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(source, function(avatarUrl)
                    result.avatar = avatarUrl
                    cb(result)
                end)
            else
                result.avatar = Config.Discord and Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png'
                cb(result)
            end
        else
            DebugServer('Aucune stats trouvée, création...')
            
            -- ⚡ CHANGEMENT: Récupérer l'avatar pour le nouveau joueur
            if Config.Discord and Config.Discord.enabled then
                exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(source, function(avatarUrl)
                    MySQL.insert('INSERT INTO pvp_stats (identifier, name, kills, deaths) VALUES (?, ?, 0, 0)', {
                        xPlayer.identifier,
                        xPlayer.getName()
                    }, function(id)
                        cb({
                            identifier = xPlayer.identifier,
                            name = xPlayer.getName(),
                            elo = Config.StartingELO,
                            kills = 0,
                            deaths = 0,
                            matches_played = 0,
                            wins = 0,
                            losses = 0,
                            avatar = avatarUrl
                        })
                    end)
                end)
            else
                MySQL.insert('INSERT INTO pvp_stats (identifier, name, kills, deaths) VALUES (?, ?, 0, 0)', {
                    xPlayer.identifier,
                    xPlayer.getName()
                }, function(id)
                    cb({
                        identifier = xPlayer.identifier,
                        name = xPlayer.getName(),
                        elo = Config.StartingELO,
                        kills = 0,
                        deaths = 0,
                        matches_played = 0,
                        wins = 0,
                        losses = 0,
                        avatar = Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png'
                    })
                end)
            end
        end
    end)
end)

ESX.RegisterServerCallback('pvp:getLeaderboard', function(source, cb)
    DebugServer('Récupération du leaderboard')
    
    MySQL.query('SELECT * FROM pvp_stats ORDER BY elo DESC LIMIT 50', {}, function(results)
        DebugServer('Leaderboard: %d entrées', #results)
        
        for i, player in ipairs(results) do
            player.kills = player.kills or 0
            player.deaths = player.deaths or 0
            player.name = player.name or 'Joueur ' .. i
            
            -- Note: Pour le leaderboard, on ne peut pas récupérer les avatars 
            -- car les joueurs ne sont pas forcément connectés
            -- On utilise l'avatar par défaut ou celui en cache DB
            player.avatar = player.discord_avatar or Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png'
        end
        
        cb(results)
    end)
end)

RegisterNetEvent('pvp:cancelSearch', function()
    local src = source
    
    DebugServer('%d annule la recherche', src)
    
    if not playersInQueue[src] then
        return
    end
    
    local queueData = playersInQueue[src]
    local groupMembers = queueData.groupMembers or {src}
    
    for _, memberId in ipairs(groupMembers) do
        for i, playerId in ipairs(queues[queueData.mode]) do
            if playerId == memberId then
                table.remove(queues[queueData.mode], i)
                break
            end
        end
        
        playersInQueue[memberId] = nil
        
        TriggerClientEvent('pvp:searchCancelled', memberId)
        TriggerClientEvent('esx:showNotification', memberId, '~y~Recherche annulée')
    end
end)

RegisterNetEvent('pvp:playerDied', function(killerId)
    local victimId = source
    
    DebugServer('💀 Joueur %d tué par %s', victimId, killerId or 'suicide/zone')
    
    local matchId = playerCurrentMatch[victimId]
    
    if matchId and activeMatches[matchId] then
        local match = activeMatches[matchId]
        DebugServer('Mort dans le match %d', matchId)
        
        -- Vérifier la synchronisation bucket
        SyncAllPlayersInMatch(matchId)
        
        HandlePlayerDeath(matchId, match, victimId, killerId)
    end
end)

function HandlePlayerDeath(matchId, match, victimId, killerId)
    if match.status ~= 'playing' then return end
    
    if not match.roundStats then
        match.roundStats = {}
    end
    
    table.insert(match.roundStats, {
        victim = victimId,
        killer = killerId,
        time = os.time()
    })
    
    if killerId and killerId ~= victimId then
        UpdatePlayerKills(killerId, 1)
        TriggerClientEvent('esx:showNotification', killerId, '~g~+1 Kill!')
    end
    
    UpdatePlayerDeaths(victimId, 1)
    
    CheckRoundEnd(matchId, match)
end

function CheckRoundEnd(matchId, match)
    local team1Alive = CountAlivePlayers(match.team1)
    local team2Alive = CountAlivePlayers(match.team2)
    
    DebugServer('Team1 vivants: %d, Team2 vivants: %d', team1Alive, team2Alive)
    
    if team1Alive == 0 then
        DebugServer('Team 2 gagne le round!')
        match.score.team2 = match.score.team2 + 1
        EndRound(matchId, match, 'team2')
    elseif team2Alive == 0 then
        DebugServer('Team 1 gagne le round!')
        match.score.team1 = match.score.team1 + 1
        EndRound(matchId, match, 'team1')
    end
end

function CountAlivePlayers(team)
    local count = 0
    for _, playerId in ipairs(team) do
        if playerId < 0 then
            count = count + 0
        else
            local playerPed = GetPlayerPed(playerId)
            if playerPed and playerPed > 0 then
                local health = GetEntityHealth(playerPed)
                if health > 0 then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function EndRound(matchId, match, winningTeam)
    match.status = 'round_end'
    
    local arena = Config.Arenas[match.arena]
    
    -- 🔥 IMPORTANT: Re-synchroniser les buckets avant d'envoyer les events
    SyncAllPlayersInMatch(matchId)
    
    for _, playerId in ipairs(match.players) do
        if playerId > 0 then
            local playerTeam = match.playerTeams[playerId]
            local didWin = (playerTeam == winningTeam)
            
            TriggerClientEvent('pvp:roundEnd', playerId, winningTeam, match.score, playerTeam, didWin)
            TriggerClientEvent('pvp:updateScore', playerId, match.score, match.currentRound)
        end
    end
    
    DebugServer('Score - Team1: %d, Team2: %d', match.score.team1, match.score.team2)
    
    if match.score.team1 >= Config.MaxRounds or match.score.team2 >= Config.MaxRounds then
        EndMatch(matchId, match)
    else
        Wait(3000)
        
        match.currentRound = match.currentRound + 1
        
        -- Re-synchroniser avant le freeze
        SyncAllPlayersInMatch(matchId)
        
        for _, playerId in ipairs(match.players) do
            if playerId > 0 then
                TriggerClientEvent('pvp:freezePlayer', playerId)
            end
        end
        
        Wait(500)
        
        RespawnPlayers(matchId, match, arena)
        
        Wait(2000)
        
        -- Re-synchroniser avant le démarrage du round
        SyncAllPlayersInMatch(matchId)
        
        StartRound(matchId, match, arena)
    end
end

function RespawnPlayers(matchId, match, arena)
    DebugServer('Respawn des joueurs pour le round %d', match.currentRound)
    
    for i, playerId in ipairs(match.team1) do
        if arena.teamA[i] and playerId > 0 then
            local spawn = arena.teamA[i]
            TriggerClientEvent('pvp:respawnPlayer', playerId, spawn)
        end
    end
    
    for i, playerId in ipairs(match.team2) do
        if arena.teamB[i] and playerId > 0 then
            local spawn = arena.teamB[i]
            TriggerClientEvent('pvp:respawnPlayer', playerId, spawn)
        end
    end
end

function StartRound(matchId, match, arena)
    DebugServer('🎮 Début du round %d', match.currentRound)
    
    match.status = 'playing'
    match.roundStats = {}
    
    -- 🔥 Synchronisation finale avant le début du round
    SyncAllPlayersInMatch(matchId)
    
    for _, playerId in ipairs(match.players) do
        if playerId > 0 then
            TriggerClientEvent('pvp:roundStart', playerId, match.currentRound)
            TriggerClientEvent('pvp:updateScore', playerId, match.score, match.currentRound)
        end
    end
end

function EndMatch(matchId, match)
    DebugServer('========== FIN DU MATCH %d ==========', matchId)
    
    match.status = 'finished'
    
    local winningTeam = match.score.team1 > match.score.team2 and 'team1' or 'team2'
    local winners = winningTeam == 'team1' and match.team1 or match.team2
    local losers = winningTeam == 'team1' and match.team2 or match.team1
    
    DebugServer('Équipe gagnante: %s', winningTeam)
    DebugServer('Gagnants: %d joueurs | Perdants: %d joueurs', #winners, #losers)
    
    if match.mode == '1v1' then
        DebugElo('Mode 1v1 détecté - Calcul ELO individuel')
        
        local winnerId = winners[1]
        local loserId = losers[1]
        
        exports['pvp_gunfight']:UpdatePlayerElo1v1(winnerId, loserId, match.score)
        
    else
        DebugElo('Mode %s détecté - Calcul ELO d\'équipe', match.mode)
        
        exports['pvp_gunfight']:UpdateTeamElo(winners, losers, match.score)
    end
    
    for _, playerId in ipairs(winners) do
        if playerId > 0 then
            local playerTeam = match.playerTeams[playerId]
            local didWin = (playerTeam == winningTeam)
            
            DebugServer('Joueur %d (Team: %s) - Victoire: %s', playerId, playerTeam, tostring(didWin))
            
            UpdatePlayerWin(playerId)
            
            TriggerClientEvent('pvp:matchEnd', playerId, didWin, match.score)
            TriggerClientEvent('pvp:hideScoreHUD', playerId)
            
            playerCurrentMatch[playerId] = nil
        end
    end
    
    for _, playerId in ipairs(losers) do
        if playerId > 0 then
            local playerTeam = match.playerTeams[playerId]
            local didWin = (playerTeam == winningTeam)
            
            UpdatePlayerLoss(playerId)
            
            TriggerClientEvent('pvp:matchEnd', playerId, didWin, match.score)
            TriggerClientEvent('pvp:hideScoreHUD', playerId)
            
            playerCurrentMatch[playerId] = nil
        end
    end
    
    Wait(8000)
    
    DebugBucket('🔴 Remise des joueurs du match %d dans le bucket 0', matchId)
    for _, playerId in ipairs(match.players) do
        ResetPlayerBucket(playerId)
    end
    
    Wait(2000)
    activeMatches[matchId] = nil
    
    DebugSuccess('✅ Match %d terminé et nettoyé - Stats et ELO mis à jour!', matchId)
end

function UpdatePlayerKills(playerId, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    MySQL.query('UPDATE pvp_stats SET kills = kills + ? WHERE identifier = ?', {
        amount,
        xPlayer.identifier
    }, function()
        DebugSuccess('Kills mis à jour pour %s (+%d)', xPlayer.getName(), amount)
    end)
end

function UpdatePlayerDeaths(playerId, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    MySQL.query('UPDATE pvp_stats SET deaths = deaths + ? WHERE identifier = ?', {
        amount,
        xPlayer.identifier
    }, function()
        DebugSuccess('Deaths mis à jour pour %s (+%d)', xPlayer.getName(), amount)
    end)
end

function UpdatePlayerWin(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    MySQL.query('UPDATE pvp_stats SET wins = wins + 1, matches_played = matches_played + 1 WHERE identifier = ?', {
        xPlayer.identifier
    }, function()
        DebugSuccess('Win enregistré pour %s', xPlayer.getName())
    end)
end

function UpdatePlayerLoss(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    MySQL.query('UPDATE pvp_stats SET losses = losses + 1, matches_played = matches_played + 1 WHERE identifier = ?', {
        xPlayer.identifier
    }, function()
        DebugSuccess('Loss enregistré pour %s', xPlayer.getName())
    end)
end

local function HandlePlayerDisconnect(playerId)
    DebugServer('🔴 Gestion de la déconnexion du joueur %d', playerId)
    
    ResetPlayerBucket(playerId)
    
    local matchId = playerCurrentMatch[playerId]
    
    if not matchId or not activeMatches[matchId] then
        DebugWarn('Joueur pas en match ou match inexistant')
        return
    end
    
    local match = activeMatches[matchId]
    
    DebugError('Joueur %d déconnecté pendant le match %d', playerId, matchId)
    
    UpdatePlayerLoss(playerId)
    
    local playerTeam = match.playerTeams[playerId]
    
    if not playerTeam then
        DebugError('Impossible de trouver la team du joueur')
        return
    end
    
    for _, otherPlayerId in ipairs(match.players) do
        if otherPlayerId ~= playerId and otherPlayerId > 0 then
            TriggerClientEvent('esx:showNotification', otherPlayerId, '~y~Un joueur s\'est déconnecté')
        end
    end
    
    local team1Count = 0
    local team2Count = 0
    
    for _, pid in ipairs(match.team1) do
        if pid > 0 and GetPlayerPing(pid) > 0 and pid ~= playerId then
            team1Count = team1Count + 1
        end
    end
    
    for _, pid in ipairs(match.team2) do
        if pid > 0 and GetPlayerPing(pid) > 0 and pid ~= playerId then
            team2Count = team2Count + 1
        end
    end
    
    DebugServer('Joueurs restants - Team1: %d, Team2: %d', team1Count, team2Count)
    
    if team1Count == 0 or team2Count == 0 then
        DebugError('Une équipe est vide - Fin immédiate du match')
        
        local winningTeam = team1Count > 0 and 'team1' or 'team2'
        local winners = winningTeam == 'team1' and match.team1 or match.team2
        
        if winningTeam == 'team1' then
            match.score.team1 = Config.MaxRounds
        else
            match.score.team2 = Config.MaxRounds
        end
        
        for _, winnerId in ipairs(winners) do
            if winnerId > 0 and GetPlayerPing(winnerId) > 0 and winnerId ~= playerId then
                DebugServer('Téléportation du gagnant %d au lobby', winnerId)
                
                TriggerClientEvent('pvp:hideScoreHUD', winnerId)
                TriggerClientEvent('pvp:forceReturnToLobby', winnerId)
                TriggerClientEvent('esx:showNotification', winnerId, '~g~Victoire par abandon adverse!')
                
                UpdatePlayerWin(winnerId)
                
                playerCurrentMatch[winnerId] = nil
                
                ResetPlayerBucket(winnerId)
            end
        end
        
        activeMatches[matchId] = nil
        DebugServer('Match supprimé')
    end
    
    playerCurrentMatch[playerId] = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    
    DebugServer('Joueur %d déconnecté, nettoyage...', src)
    
    if playersInQueue[src] then
        local queueData = playersInQueue[src]
        local groupMembers = queueData.groupMembers or {src}
        
        for _, memberId in ipairs(groupMembers) do
            for i, playerId in ipairs(queues[queueData.mode]) do
                if playerId == memberId then
                    table.remove(queues[queueData.mode], i)
                    DebugServer('Retiré de la queue %s', queueData.mode)
                    break
                end
            end
            playersInQueue[memberId] = nil
        end
    end
    
    HandlePlayerDisconnect(src)
end)

DebugSuccess('✅ Système PVP avec instances et ELO chargé (VERSION 2.4.1 - Fix avatars Discord asynchrones)!')

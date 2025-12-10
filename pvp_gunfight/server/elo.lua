-- ========================================
-- PVP GUNFIGHT - SYSTÈME ELO
-- Gestion du classement et progression des joueurs
-- Version: 2.3.1
-- ========================================

DebugElo('Module de classement ELO chargé')

local ELO_CONFIG = {
    kFactors = {
        [1] = 32,  [2] = 28,  [3] = 24,  [4] = 20,  [5] = 18,  [6] = 15
    },
    
    performanceMultiplier = {
        domination = 1.2,
        close = 1.0,
        upset = 1.3
    },
    
    minimumElo = 0,
    
    rankThresholds = {
        {id = 1, name = "Bronze", min = 0, max = 999},
        {id = 2, name = "Argent", min = 1000, max = 1499},
        {id = 3, name = "Or", min = 1500, max = 1999},
        {id = 4, name = "Platine", min = 2000, max = 2499},
        {id = 5, name = "Émeraude", min = 2500, max = 2999},
        {id = 6, name = "Diamant", min = 3000, max = 9999}
    }
}

local function GetRankByElo(elo)
    for _, rank in ipairs(ELO_CONFIG.rankThresholds) do
        if elo >= rank.min and elo <= rank.max then
            return rank
        end
    end
    return ELO_CONFIG.rankThresholds[6]
end

local function GetKFactor(rankId)
    return ELO_CONFIG.kFactors[rankId] or 32
end

local function CalculateExpectedScore(eloA, eloB)
    return 1 / (1 + 10 ^ ((eloB - eloA) / 400))
end

function CalculateEloChange(winnerElo, loserElo, winnerRankId, loserRankId, scoreRatio)
    local winnerK = GetKFactor(winnerRankId)
    local loserK = GetKFactor(loserRankId)
    
    local winnerExpected = CalculateExpectedScore(winnerElo, loserElo)
    local loserExpected = CalculateExpectedScore(loserElo, winnerElo)
    
    local winnerActual = 1
    local loserActual = 0
    
    local winnerChange = math.floor(winnerK * (winnerActual - winnerExpected))
    local loserChange = math.floor(loserK * (loserActual - loserExpected))
    
    if scoreRatio then
        if scoreRatio >= 0.9 then
            winnerChange = math.floor(winnerChange * ELO_CONFIG.performanceMultiplier.domination)
            loserChange = math.floor(loserChange * ELO_CONFIG.performanceMultiplier.domination)
        end
        
        if loserElo - winnerElo >= 500 then
            winnerChange = math.floor(winnerChange * ELO_CONFIG.performanceMultiplier.upset)
        end
    end
    
    local winnerNewElo = winnerElo + winnerChange
    local loserNewElo = math.max(ELO_CONFIG.minimumElo, loserElo + loserChange)
    
    DebugElo('Calcul ELO - Gagnant: %d -> %d (%+d) | Perdant: %d -> %d (%d)',
        winnerElo, winnerNewElo, winnerChange,
        loserElo, loserNewElo, loserChange)
    
    return {
        winnerNewElo = winnerNewElo,
        loserNewElo = loserNewElo,
        winnerChange = winnerChange,
        loserChange = loserChange,
        winnerExpected = math.floor(winnerExpected * 100),
        loserExpected = math.floor(loserExpected * 100)
    }
end

function UpdatePlayerElo1v1(winnerId, loserId, finalScore)
    local xWinner = ESX.GetPlayerFromId(winnerId)
    local xLoser = ESX.GetPlayerFromId(loserId)
    
    if not xWinner or not xLoser then
        DebugError('Joueur introuvable')
        return
    end
    
    DebugElo('========== MISE À JOUR ELO 1V1 ==========')
    DebugElo('Gagnant: %s (ID: %d)', xWinner.getName(), winnerId)
    DebugElo('Perdant: %s (ID: %d)', xLoser.getName(), loserId)
    
    MySQL.query('SELECT elo, rank_id, best_elo FROM pvp_stats WHERE identifier = ?', {
        xWinner.identifier
    }, function(winnerResult)
        
        MySQL.query('SELECT elo, rank_id, best_elo FROM pvp_stats WHERE identifier = ?', {
            xLoser.identifier
        }, function(loserResult)
            
            local winnerElo = (winnerResult and winnerResult[1]) and winnerResult[1].elo or 1000
            local loserElo = (loserResult and loserResult[1]) and loserResult[1].elo or 1000
            
            local winnerRankId = (winnerResult and winnerResult[1]) and winnerResult[1].rank_id or 1
            local loserRankId = (loserResult and loserResult[1]) and loserResult[1].rank_id or 1
            
            local winnerBestElo = (winnerResult and winnerResult[1]) and winnerResult[1].best_elo or 1000
            local loserBestElo = (loserResult and loserResult[1]) and loserResult[1].best_elo or 1000
            
            DebugElo('ELO actuel - Gagnant: %d (Rank %d) | Perdant: %d (Rank %d)', 
                winnerElo, winnerRankId, loserElo, loserRankId)
            
            local winnerScore = math.max(finalScore.team1, finalScore.team2)
            local loserScore = math.min(finalScore.team1, finalScore.team2)
            local scoreRatio = loserScore / winnerScore
            
            local eloResult = CalculateEloChange(winnerElo, loserElo, winnerRankId, loserRankId, scoreRatio)
            
            local winnerNewRank = GetRankByElo(eloResult.winnerNewElo)
            local loserNewRank = GetRankByElo(eloResult.loserNewElo)
            
            local newWinnerBestElo = math.max(winnerBestElo, eloResult.winnerNewElo)
            local newLoserBestElo = math.max(loserBestElo, eloResult.loserNewElo)
            
            MySQL.update('UPDATE pvp_stats SET elo = ?, rank_id = ?, best_elo = ? WHERE identifier = ?', {
                eloResult.winnerNewElo,
                winnerNewRank.id,
                newWinnerBestElo,
                xWinner.identifier
            }, function(affectedRows)
                DebugSuccess('Gagnant mis à jour: %d ELO (%+d)', 
                    eloResult.winnerNewElo, eloResult.winnerChange)
            end)
            
            MySQL.update('UPDATE pvp_stats SET elo = ?, rank_id = ?, best_elo = ? WHERE identifier = ?', {
                eloResult.loserNewElo,
                loserNewRank.id,
                newLoserBestElo,
                xLoser.identifier
            }, function(affectedRows)
                DebugSuccess('Perdant mis à jour: %d ELO (%d)', 
                    eloResult.loserNewElo, eloResult.loserChange)
            end)
            
            TriggerClientEvent('esx:showNotification', winnerId, 
                string.format('~g~+%d ELO~w~ (%d)', eloResult.winnerChange, eloResult.winnerNewElo))
            
            TriggerClientEvent('esx:showNotification', loserId, 
                string.format('~r~%d ELO~w~ (%d)', eloResult.loserChange, eloResult.loserNewElo))
            
            if winnerNewRank.id > winnerRankId then
                TriggerClientEvent('esx:showNotification', winnerId, 
                    string.format('~g~🎉 PROMOTION!~w~ Vous êtes maintenant ~b~%s~w~!', winnerNewRank.name))
            end
            
            if loserNewRank.id < loserRankId then
                TriggerClientEvent('esx:showNotification', loserId, 
                    string.format('~r~⚠️ RÉTROGRADATION~w~ Vous êtes maintenant ~y~%s~w~', loserNewRank.name))
            end
            
            DebugElo('========== FIN MISE À JOUR ELO ==========')
        end)
    end)
end

function UpdateTeamElo(winners, losers, finalScore)
    DebugElo('========== MISE À JOUR ELO ÉQUIPE ==========')
    DebugElo('Gagnants: %d joueurs | Perdants: %d joueurs', #winners, #losers)
    
    local winnersElo = {}
    local losersElo = {}
    local winnersProcessed = 0
    local losersProcessed = 0
    
    for _, winnerId in ipairs(winners) do
        local xWinner = ESX.GetPlayerFromId(winnerId)
        if xWinner then
            MySQL.query('SELECT elo, rank_id, best_elo FROM pvp_stats WHERE identifier = ?', {
                xWinner.identifier
            }, function(result)
                local elo = (result and result[1]) and result[1].elo or 1000
                local rankId = (result and result[1]) and result[1].rank_id or 1
                local bestElo = (result and result[1]) and result[1].best_elo or 1000
                
                table.insert(winnersElo, {
                    playerId = winnerId,
                    identifier = xWinner.identifier,
                    elo = elo,
                    rankId = rankId,
                    bestElo = bestElo
                })
                
                winnersProcessed = winnersProcessed + 1
                
                if winnersProcessed == #winners and losersProcessed == #losers then
                    ProcessTeamEloUpdate(winnersElo, losersElo, finalScore)
                end
            end)
        end
    end
    
    for _, loserId in ipairs(losers) do
        local xLoser = ESX.GetPlayerFromId(loserId)
        if xLoser then
            MySQL.query('SELECT elo, rank_id, best_elo FROM pvp_stats WHERE identifier = ?', {
                xLoser.identifier
            }, function(result)
                local elo = (result and result[1]) and result[1].elo or 1000
                local rankId = (result and result[1]) and result[1].rank_id or 1
                local bestElo = (result and result[1]) and result[1].best_elo or 1000
                
                table.insert(losersElo, {
                    playerId = loserId,
                    identifier = xLoser.identifier,
                    elo = elo,
                    rankId = rankId,
                    bestElo = bestElo
                })
                
                losersProcessed = losersProcessed + 1
                
                if winnersProcessed == #winners and losersProcessed == #losers then
                    ProcessTeamEloUpdate(winnersElo, losersElo, finalScore)
                end
            end)
        end
    end
end

function ProcessTeamEloUpdate(winnersData, losersData, finalScore)
    local avgWinnerElo = 0
    local avgLoserElo = 0
    local avgWinnerRank = 0
    local avgLoserRank = 0
    
    for _, data in ipairs(winnersData) do
        avgWinnerElo = avgWinnerElo + data.elo
        avgWinnerRank = avgWinnerRank + data.rankId
    end
    avgWinnerElo = math.floor(avgWinnerElo / #winnersData)
    avgWinnerRank = math.floor(avgWinnerRank / #winnersData)
    
    for _, data in ipairs(losersData) do
        avgLoserElo = avgLoserElo + data.elo
        avgLoserRank = avgLoserRank + data.rankId
    end
    avgLoserElo = math.floor(avgLoserElo / #losersData)
    avgLoserRank = math.floor(avgLoserRank / #losersData)
    
    DebugElo('ELO moyen - Gagnants: %d (Rank %d) | Perdants: %d (Rank %d)', 
        avgWinnerElo, avgWinnerRank, avgLoserElo, avgLoserRank)
    
    local winnerScore = math.max(finalScore.team1, finalScore.team2)
    local loserScore = math.min(finalScore.team1, finalScore.team2)
    local scoreRatio = loserScore / winnerScore
    
    local eloResult = CalculateEloChange(avgWinnerElo, avgLoserElo, avgWinnerRank, avgLoserRank, scoreRatio)
    
    for _, winnerData in ipairs(winnersData) do
        local newElo = winnerData.elo + eloResult.winnerChange
        local newRank = GetRankByElo(newElo)
        local newBestElo = math.max(winnerData.bestElo, newElo)
        
        MySQL.update('UPDATE pvp_stats SET elo = ?, rank_id = ?, best_elo = ? WHERE identifier = ?', {
            newElo,
            newRank.id,
            newBestElo,
            winnerData.identifier
        }, function()
            DebugSuccess('Gagnant (ID: %d) mis à jour: %d ELO (%+d)', 
                winnerData.playerId, newElo, eloResult.winnerChange)
            
            TriggerClientEvent('esx:showNotification', winnerData.playerId, 
                string.format('~g~+%d ELO~w~ (%d)', eloResult.winnerChange, newElo))
            
            if newRank.id > winnerData.rankId then
                TriggerClientEvent('esx:showNotification', winnerData.playerId, 
                    string.format('~g~🎉 PROMOTION!~w~ Vous êtes maintenant ~b~%s~w~!', newRank.name))
            end
        end)
    end
    
    for _, loserData in ipairs(losersData) do
        local newElo = math.max(ELO_CONFIG.minimumElo, loserData.elo + eloResult.loserChange)
        local newRank = GetRankByElo(newElo)
        local newBestElo = math.max(loserData.bestElo, newElo)
        
        MySQL.update('UPDATE pvp_stats SET elo = ?, rank_id = ?, best_elo = ? WHERE identifier = ?', {
            newElo,
            newRank.id,
            newBestElo,
            loserData.identifier
        }, function()
            DebugSuccess('Perdant (ID: %d) mis à jour: %d ELO (%d)', 
                loserData.playerId, newElo, eloResult.loserChange)
            
            TriggerClientEvent('esx:showNotification', loserData.playerId, 
                string.format('~r~%d ELO~w~ (%d)', eloResult.loserChange, newElo))
            
            if newRank.id < loserData.rankId then
                TriggerClientEvent('esx:showNotification', loserData.playerId, 
                    string.format('~r~⚠️ RÉTROGRADATION~w~ Vous êtes maintenant ~y~%s~w~', newRank.name))
            end
        end)
    end
    
    DebugElo('========== FIN MISE À JOUR ELO ÉQUIPE ==========')
end

exports('UpdatePlayerElo1v1', UpdatePlayerElo1v1)
exports('UpdateTeamElo', UpdateTeamElo)
exports('GetRankByElo', GetRankByElo)
exports('CalculateEloChange', CalculateEloChange)

DebugSuccess('Système ELO opérationnel')

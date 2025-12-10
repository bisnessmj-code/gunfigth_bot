-- ========================================
-- PVP GUNFIGHT - SYSTÈME DE GROUPES
-- Version: 2.4.0 - Avec avatars Discord
-- ========================================

DebugGroups('Module chargé')

local groups = {}
local playerGroups = {}
local pendingInvites = {}

local function CreateGroup(leaderId)
    local groupId = #groups + 1
    groups[groupId] = {
        id = groupId,
        leaderId = leaderId,
        members = {leaderId},
        ready = {[leaderId] = false}
    }
    playerGroups[leaderId] = groupId
    return groupId
end

function GetPlayerGroup(playerId)
    local groupId = playerGroups[playerId]
    if groupId then
        return groups[groupId]
    end
    return nil
end

local function BroadcastToGroup(groupId)
    local group = groups[groupId]
    if not group then return end
    DebugGroups('Broadcast au groupe %d avec %d membres', groupId, #group.members)
    for _, memberId in ipairs(group.members) do
        local groupData = GetGroupData(memberId)
        DebugGroups('Envoi données groupe à %d', memberId)
        TriggerClientEvent('pvp:updateGroupUI', memberId, groupData)
    end
end

function GetGroupData(playerId)
    local group = GetPlayerGroup(playerId)
    if not group then return nil end
    local members = {}
    for _, memberId in ipairs(group.members) do
        local xPlayer = ESX.GetPlayerFromId(memberId)
        if xPlayer then
            -- Récupérer l'avatar Discord
            local avatarUrl = nil
            if Config.Discord and Config.Discord.enabled then
                avatarUrl = exports['pvp_gunfight']:GetPlayerDiscordAvatar(memberId)
            end
            
            table.insert(members, {
                id = memberId,
                name = xPlayer.getName(),
                isLeader = memberId == group.leaderId,
                isReady = group.ready[memberId] or false,
                isYou = memberId == playerId,
                yourId = playerId,
                avatar = avatarUrl or Config.Discord.defaultAvatar or 'https://i.imgur.com/6VBx3io.png'
            })
        end
    end
    return {
        id = group.id,
        leaderId = group.leaderId,
        members = members
    }
end

function RemovePlayerFromGroup(playerId)
    local group = GetPlayerGroup(playerId)
    if not group then 
        DebugWarn('Joueur %d n\'est dans aucun groupe', playerId)
        return 
    end
    DebugGroups('Retrait du joueur %d du groupe %d', playerId, group.id)
    for i, memberId in ipairs(group.members) do
        if memberId == playerId then
            table.remove(group.members, i)
            break
        end
    end
    group.ready[playerId] = nil
    playerGroups[playerId] = nil
    TriggerClientEvent('pvp:updateGroupUI', playerId, nil)
    if #group.members == 0 then
        groups[group.id] = nil
        DebugGroups('Groupe %d supprimé (vide)', group.id)
    else
        if group.leaderId == playerId and #group.members > 0 then
            group.leaderId = group.members[1]
            TriggerClientEvent('esx:showNotification', group.leaderId, '~b~Vous êtes maintenant le leader du groupe')
        end
        BroadcastToGroup(group.id)
    end
end

RegisterNetEvent('pvp:inviteToGroup', function(targetId)
    local src = source
    DebugGroups('%d invite le joueur %d', src, targetId)
    local xPlayer = ESX.GetPlayerFromId(src)
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xPlayer then DebugError('Source invalide') return end
    if not xTarget then
        DebugError('Joueur cible introuvable')
        TriggerClientEvent('esx:showNotification', src, '~r~Joueur introuvable - ID ' .. targetId .. ' n\'est pas sur le serveur')
        return
    end
    if GetPlayerGroup(targetId) then
        DebugGroups('Le joueur %d est déjà dans un groupe, retrait automatique', targetId)
        RemovePlayerFromGroup(targetId)
        TriggerClientEvent('esx:showNotification', targetId, '~y~Vous avez été retiré de votre groupe précédent')
    end
    local group = GetPlayerGroup(src)
    if not group then
        CreateGroup(src)
        group = GetPlayerGroup(src)
    end
    if group.leaderId ~= src then
        TriggerClientEvent('esx:showNotification', src, '~r~Seul le leader peut inviter')
        return
    end
    if #group.members >= 4 then
        TriggerClientEvent('esx:showNotification', src, '~r~Groupe complet (4 joueurs max)')
        return
    end
    pendingInvites[targetId] = src
    
    -- Récupérer l'avatar de l'inviteur
    local inviterAvatar = nil
    if Config.Discord and Config.Discord.enabled then
        inviterAvatar = exports['pvp_gunfight']:GetPlayerDiscordAvatar(src)
    end
    
    TriggerClientEvent('pvp:receiveInvite', targetId, xPlayer.getName(), src, inviterAvatar)
    TriggerClientEvent('esx:showNotification', src, '~b~Invitation envoyée à ' .. xTarget.getName())
end)

RegisterNetEvent('pvp:acceptInvite', function(inviterId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    DebugGroups('%d accepte l\'invitation de %d', src, inviterId)
    if not pendingInvites[src] or pendingInvites[src] ~= inviterId then
        TriggerClientEvent('esx:showNotification', src, '~r~Invitation expirée')
        return
    end
    pendingInvites[src] = nil
    if GetPlayerGroup(src) then
        DebugWarn('Joueur %d déjà dans un groupe lors de l\'acceptation, retrait', src)
        RemovePlayerFromGroup(src)
    end
    local group = GetPlayerGroup(inviterId)
    if not group then
        TriggerClientEvent('esx:showNotification', src, '~r~Le groupe n\'existe plus')
        return
    end
    if #group.members >= 4 then
        TriggerClientEvent('esx:showNotification', src, '~r~Groupe complet')
        return
    end
    table.insert(group.members, src)
    group.ready[src] = false
    playerGroups[src] = group.id
    DebugSuccess('%d ajouté au groupe %d', src, group.id)
    TriggerClientEvent('esx:showNotification', src, '~g~Vous avez rejoint le groupe')
    local xInviter = ESX.GetPlayerFromId(inviterId)
    if xInviter then
        TriggerClientEvent('esx:showNotification', inviterId, '~g~' .. xPlayer.getName() .. ' a rejoint le groupe')
    end
    Wait(200)
    BroadcastToGroup(group.id)
    Wait(100)
    local groupData = GetGroupData(src)
    TriggerClientEvent('pvp:updateGroupUI', src, groupData)
end)

RegisterNetEvent('pvp:leaveGroup', function()
    local src = source
    local group = GetPlayerGroup(src)
    if not group then
        TriggerClientEvent('esx:showNotification', src, '~r~Vous n\'êtes dans aucun groupe')
        return
    end
    for i, memberId in ipairs(group.members) do
        if memberId == src then
            table.remove(group.members, i)
            break
        end
    end
    group.ready[src] = nil
    playerGroups[src] = nil
    if group.leaderId == src and #group.members > 0 then
        group.leaderId = group.members[1]
        TriggerClientEvent('esx:showNotification', group.leaderId, '~b~Vous êtes maintenant le leader du groupe')
    end
    if #group.members == 0 then
        groups[group.id] = nil
    else
        BroadcastToGroup(group.id)
    end
    TriggerClientEvent('esx:showNotification', src, '~y~Vous avez quitté le groupe')
    TriggerClientEvent('pvp:updateGroupUI', src, nil)
end)

RegisterNetEvent('pvp:kickFromGroup', function(targetId)
    local src = source
    local group = GetPlayerGroup(src)
    if not group or group.leaderId ~= src then
        TriggerClientEvent('esx:showNotification', src, '~r~Vous n\'êtes pas le leader')
        return
    end
    local found = false
    for i, memberId in ipairs(group.members) do
        if memberId == targetId then
            table.remove(group.members, i)
            found = true
            break
        end
    end
    if not found then
        TriggerClientEvent('esx:showNotification', src, '~r~Joueur introuvable dans le groupe')
        return
    end
    group.ready[targetId] = nil
    playerGroups[targetId] = nil
    local xTarget = ESX.GetPlayerFromId(targetId)
    if xTarget then
        TriggerClientEvent('esx:showNotification', targetId, '~r~Vous avez été exclu du groupe')
        TriggerClientEvent('pvp:updateGroupUI', targetId, nil)
    end
    TriggerClientEvent('esx:showNotification', src, '~y~Joueur exclu du groupe')
    BroadcastToGroup(group.id)
end)

RegisterNetEvent('pvp:toggleReady', function()
    local src = source
    DebugGroups('%d toggle ready', src)
    local group = GetPlayerGroup(src)
    if not group then
        DebugGroups('Pas de groupe, création auto')
        CreateGroup(src)
        group = GetPlayerGroup(src)
    end
    group.ready[src] = not group.ready[src]
    local status = group.ready[src] and '~g~Prêt' or '~r~Pas prêt'
    DebugGroups('Nouveau statut de %d: %s', src, group.ready[src] and 'READY' or 'NOT READY')
    TriggerClientEvent('esx:showNotification', src, 'Statut: ' .. status)
    BroadcastToGroup(group.id)
end)

ESX.RegisterServerCallback('pvp:getGroupInfo', function(source, cb)
    local groupData = GetGroupData(source)
    cb(groupData)
end)

-- Callback pour récupérer l'avatar d'un joueur
ESX.RegisterServerCallback('pvp:getPlayerAvatar', function(source, cb, targetId)
    local playerId = targetId or source
    local avatarUrl = nil
    
    if Config.Discord and Config.Discord.enabled then
        avatarUrl = exports['pvp_gunfight']:GetPlayerDiscordAvatar(playerId)
    end
    
    cb(avatarUrl or Config.Discord.defaultAvatar or 'https://i.imgur.com/6VBx3io.png')
end)

-- Callback pour récupérer les avatars de plusieurs joueurs
ESX.RegisterServerCallback('pvp:getPlayersAvatars', function(source, cb, playerIds)
    local avatars = {}
    
    for _, playerId in ipairs(playerIds) do
        local avatarUrl = nil
        
        if Config.Discord and Config.Discord.enabled then
            avatarUrl = exports['pvp_gunfight']:GetPlayerDiscordAvatar(playerId)
        end
        
        avatars[playerId] = avatarUrl or Config.Discord.defaultAvatar or 'https://i.imgur.com/6VBx3io.png'
    end
    
    cb(avatars)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local group = GetPlayerGroup(src)
    if group then
        for i, memberId in ipairs(group.members) do
            if memberId == src then
                table.remove(group.members, i)
                break
            end
        end
        group.ready[src] = nil
        playerGroups[src] = nil
        if group.leaderId == src and #group.members > 0 then
            group.leaderId = group.members[1]
        end
        if #group.members == 0 then
            groups[group.id] = nil
        else
            BroadcastToGroup(group.id)
        end
    end
    pendingInvites[src] = nil
end)

exports('GetPlayerGroup', GetPlayerGroup)
exports('RemovePlayerFromGroup', RemovePlayerFromGroup)
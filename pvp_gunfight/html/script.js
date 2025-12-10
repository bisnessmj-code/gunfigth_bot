console.log('[PVP UI] Script chargé - Version 2.4.0 avec Avatars Discord');

// ========================================
// VARIABLES GLOBALES
// ========================================
let currentGroup = null;
let selectedMode = null;
let selectedPlayers = 1;
let isReady = false;
let currentSlotToInvite = null;
let isSearching = false;
let searchStartTime = 0;
let pendingInvitations = [];
let isInMatch = false;
let myAvatar = 'https://cdn.discordapp.com/embed/avatars/0.png'; // Avatar par défaut

// ========================================
// AVATAR PAR DÉFAUT
// ========================================
const DEFAULT_AVATAR = 'https://cdn.discordapp.com/embed/avatars/0.png';

// Fonction pour gérer les erreurs de chargement d'avatar
function handleAvatarError(imgElement) {
    imgElement.onerror = function() {
        this.src = DEFAULT_AVATAR;
        console.log('[PVP UI] Erreur chargement avatar, fallback sur défaut');
    };
}

// ========================================
// GESTION DES MESSAGES DEPUIS LUA
// ========================================
window.addEventListener('message', function(event) {
    console.log('[PVP UI] Message reçu:', event.data);
    const data = event.data;
    
    if (data.action === 'openUI') {
        console.log('[PVP UI] Ouverture de l\'interface');
        openUI();
    } else if (data.action === 'closeUI') {
        console.log('[PVP UI] Fermeture de l\'interface (depuis Lua)');
        closeUIVisual();
    } else if (data.action === 'updateGroup') {
        console.log('[PVP UI] Mise à jour du groupe:', data.group);
        updateGroupDisplay(data.group);
    } else if (data.action === 'showInvite') {
        console.log('[PVP UI] Invitation reçue de:', data.inviterName);
        addInvitationToQueue(data.inviterName, data.inviterId, data.inviterAvatar);
    } else if (data.action === 'searchStarted') {
        console.log('[PVP UI] Recherche démarrée:', data.mode);
        showSearchStatus(data.mode);
    } else if (data.action === 'updateSearchTimer') {
        updateSearchTimer(data.elapsed);
    } else if (data.action === 'matchFound') {
        console.log('[PVP UI] Match trouvé!');
        hideSearchStatus();
        isInMatch = true;
    } else if (data.action === 'searchCancelled') {
        console.log('[PVP UI] Recherche annulée');
        hideSearchStatus();
    } else if (data.action === 'showRoundStart') {
        console.log('[PVP UI] Début du round:', data.round);
        showRoundStart(data.round);
    } else if (data.action === 'showCountdown') {
        console.log('[PVP UI] Countdown:', data.number);
        showCountdown(data.number);
    } else if (data.action === 'showGo') {
        console.log('[PVP UI] GO!');
        showGo();
    } else if (data.action === 'showRoundEnd') {
        console.log('[PVP UI] 🎯 Fin du round - Gagnant:', data.winner, '- Mon équipe:', data.playerTeam, '- Victoire:', data.isVictory);
        showRoundEnd(data.winner, data.score, data.playerTeam, data.isVictory);
    } else if (data.action === 'showMatchEnd') {
        console.log('[PVP UI] 🏆 Fin du match - Victoire:', data.victory, '- Mon équipe:', data.playerTeam);
        showMatchEnd(data.victory, data.score, data.playerTeam);
        isInMatch = false;
    } else if (data.action === 'updateScore') {
        console.log('[PVP UI] Mise à jour du score:', data.score);
        updateScoreHUD(data.score, data.round);
    } else if (data.action === 'showScoreHUD') {
        console.log('[PVP UI] Affichage du HUD de score');
        showScoreHUD(data.score, data.round);
    } else if (data.action === 'hideScoreHUD') {
        console.log('[PVP UI] Masquage du HUD de score');
        hideScoreHUD();
    }
});

// ========================================
// FONCTIONS D'INTERFACE
// ========================================

function openUI() {
    console.log('[PVP UI] openUI() appelée');
    document.getElementById('container').classList.remove('hidden');
    loadStats();
    loadGroupInfo();
    console.log('[PVP UI] Interface ouverte');
}

function closeUIVisual() {
    console.log('[PVP UI] closeUIVisual() appelée');
    document.getElementById('container').classList.add('hidden');
    console.log('[PVP UI] Interface cachée');
}

function closeUI() {
    console.log('[PVP UI] closeUI() appelée - envoi de la requête à Lua');
    
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(() => {
        console.log('[PVP UI] Requête closeUI envoyée avec succès');
    }).catch(err => {
        console.error('[PVP UI] Erreur lors de l\'envoi closeUI:', err);
    });
}

// ========================================
// SYSTÈME D'INVITATIONS AVEC AVATARS DISCORD
// ========================================

function addInvitationToQueue(inviterName, inviterId, inviterAvatar) {
    console.log('[PVP UI] Ajout invitation à la queue:', inviterName, inviterId, inviterAvatar);
    
    const exists = pendingInvitations.find(inv => inv.inviterId === inviterId);
    if (exists) {
        console.log('[PVP UI] Invitation déjà présente');
        return;
    }
    
    pendingInvitations.push({
        inviterName: inviterName,
        inviterId: inviterId,
        inviterAvatar: inviterAvatar || DEFAULT_AVATAR,
        timestamp: Date.now()
    });
    
    updateNotificationBadge();
    
    setTimeout(() => {
        removeInvitation(inviterId);
    }, 30000);
}

function updateNotificationBadge() {
    const badge = document.getElementById('notification-count');
    const count = pendingInvitations.length;
    
    if (count > 0) {
        badge.textContent = count;
        badge.classList.remove('hidden');
    } else {
        badge.classList.add('hidden');
    }
}

function removeInvitation(inviterId) {
    pendingInvitations = pendingInvitations.filter(inv => inv.inviterId !== inviterId);
    updateNotificationBadge();
    
    if (!document.getElementById('invitations-panel').classList.contains('hidden')) {
        renderInvitationsPanel();
    }
}

function showInvitationsPanel() {
    console.log('[PVP UI] Ouverture du panel d\'invitations');
    document.getElementById('invitations-panel').classList.remove('hidden');
    renderInvitationsPanel();
}

function hideInvitationsPanel() {
    console.log('[PVP UI] Fermeture du panel d\'invitations');
    document.getElementById('invitations-panel').classList.add('hidden');
}

function renderInvitationsPanel() {
    const list = document.getElementById('invitations-list');
    const noInvitations = document.getElementById('no-invitations');
    
    list.innerHTML = '';
    
    if (pendingInvitations.length === 0) {
        noInvitations.classList.remove('hidden');
        return;
    }
    
    noInvitations.classList.add('hidden');
    
    pendingInvitations.forEach(invitation => {
        const item = document.createElement('div');
        item.className = 'invitation-item';
        item.innerHTML = `
            <div class="invitation-avatar">
                <img src="${invitation.inviterAvatar}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
            </div>
            <div class="invitation-info">
                <div class="invitation-from">${invitation.inviterName}</div>
                <div class="invitation-message">Vous invite à rejoindre son groupe</div>
            </div>
            <div class="invitation-actions">
                <button class="btn-accept-inv" data-inviter-id="${invitation.inviterId}">✓ Accepter</button>
                <button class="btn-decline-inv" data-inviter-id="${invitation.inviterId}">✕ Refuser</button>
            </div>
        `;
        list.appendChild(item);
    });
    
    document.querySelectorAll('.btn-accept-inv').forEach(btn => {
        btn.addEventListener('click', function() {
            const inviterId = parseInt(this.getAttribute('data-inviter-id'));
            acceptInvitation(inviterId);
        });
    });
    
    document.querySelectorAll('.btn-decline-inv').forEach(btn => {
        btn.addEventListener('click', function() {
            const inviterId = parseInt(this.getAttribute('data-inviter-id'));
            declineInvitation(inviterId);
        });
    });
}

function acceptInvitation(inviterId) {
    console.log('[PVP UI] Acceptation invitation de:', inviterId);
    
    fetch(`https://${GetParentResourceName()}/acceptInvite`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            inviterId: inviterId
        })
    }).then(() => {
        console.log('[PVP UI] Invitation acceptée');
    }).catch(err => {
        console.error('[PVP UI] Erreur acceptation:', err);
    });
    
    removeInvitation(inviterId);
    renderInvitationsPanel();
}

function declineInvitation(inviterId) {
    console.log('[PVP UI] Refus invitation de:', inviterId);
    
    fetch(`https://${GetParentResourceName()}/declineInvite`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).catch(err => {});
    
    removeInvitation(inviterId);
    renderInvitationsPanel();
}

// ========================================
// EVENT LISTENERS
// ========================================

document.getElementById('notification-bell').addEventListener('click', function() {
    console.log('[PVP UI] Clic sur notification bell');
    const panel = document.getElementById('invitations-panel');
    
    if (panel.classList.contains('hidden')) {
        showInvitationsPanel();
    } else {
        hideInvitationsPanel();
    }
});

document.getElementById('close-invitations').addEventListener('click', function() {
    hideInvitationsPanel();
});

document.getElementById('close-button').addEventListener('click', function() {
    console.log('[PVP UI] Clic sur le bouton de fermeture');
    closeUI();
});

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        console.log('[PVP UI] Touche ESC pressée');
        const container = document.getElementById('container');
        const invitationsPanel = document.getElementById('invitations-panel');
        
        if (!invitationsPanel.classList.contains('hidden')) {
            hideInvitationsPanel();
            return;
        }
        
        if (!container.classList.contains('hidden')) {
            closeUI();
        }
    }
});

// ========================================
// GESTION DES ONGLETS
// ========================================

document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        const tabName = this.getAttribute('data-tab');
        console.log('[PVP UI] Changement d\'onglet:', tabName);
        
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        
        this.classList.add('active');
        document.getElementById(tabName + '-tab').classList.add('active');
        
        if (tabName === 'stats') {
            loadStats();
        } else if (tabName === 'leaderboard') {
            loadLeaderboard();
        } else if (tabName === 'lobby') {
            loadGroupInfo();
        }
    });
});

// ========================================
// SÉLECTION DU MODE
// ========================================

document.querySelectorAll('.mode-card').forEach(card => {
    card.addEventListener('click', function() {
        const mode = this.getAttribute('data-mode');
        const players = parseInt(this.getAttribute('data-players'));
        
        console.log('[PVP UI] Mode sélectionné:', mode, '- Joueurs nécessaires:', players);
        
        document.querySelectorAll('.mode-card').forEach(c => c.classList.remove('selected'));
        this.classList.add('selected');
        
        selectedMode = mode;
        selectedPlayers = players;
        
        document.getElementById('mode-display').textContent = mode.toUpperCase();
        
        updatePlayerSlots();
        updateSearchButton();
    });
});

// ========================================
// GESTION DES SLOTS JOUEURS
// ========================================

function updatePlayerSlots() {
    console.log('[PVP UI] Mise à jour des slots pour', selectedPlayers, 'joueur(s)');
    
    const slots = document.querySelectorAll('.player-slot');
    
    slots.forEach((slot, index) => {
        if (index === 0) return;
        
        if (index < selectedPlayers) {
            console.log('[PVP UI] Slot', index, 'activé');
            slot.classList.remove('locked');
            
            if (slot.classList.contains('empty-slot')) {
                const slotText = slot.querySelector('.slot-text');
                if (slotText) {
                    slotText.textContent = 'Cliquez pour inviter';
                }
                
                slot.onclick = function() {
                    console.log('[PVP UI] Clic sur slot', index, 'pour inviter');
                    openInvitePopup(index);
                };
            }
        } else {
            console.log('[PVP UI] Slot', index, 'verrouillé');
            slot.classList.add('locked');
            
            if (slot.classList.contains('empty-slot')) {
                const slotText = slot.querySelector('.slot-text');
                if (slotText) {
                    slotText.textContent = 'Non disponible';
                }
                slot.onclick = null;
            }
        }
    });
}

function openInvitePopup(slotIndex) {
    console.log('[PVP UI] Ouverture popup invitation pour slot:', slotIndex);
    currentSlotToInvite = slotIndex;
    document.getElementById('invite-player-popup').classList.remove('hidden');
}

document.getElementById('confirm-invite-btn').addEventListener('click', function() {
    const input = document.getElementById('invite-input');
    const targetId = parseInt(input.value);
    
    console.log('[PVP UI] Confirmation invitation - ID:', targetId);
    
    if (!targetId || targetId < 1) {
        console.warn('[PVP UI] ID invalide');
        return;
    }
    
    console.log('[PVP UI] Envoi requête invitePlayer');
    fetch(`https://${GetParentResourceName()}/invitePlayer`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            targetId: targetId
        })
    }).then(() => {
        console.log('[PVP UI] Invitation envoyée avec succès');
    }).catch(err => {
        console.error('[PVP UI] Erreur lors de l\'invitation:', err);
    });
    
    input.value = '';
    document.getElementById('invite-player-popup').classList.add('hidden');
});

document.getElementById('cancel-invite-btn').addEventListener('click', function() {
    console.log('[PVP UI] Annulation invitation');
    document.getElementById('invite-input').value = '';
    document.getElementById('invite-player-popup').classList.add('hidden');
});

// ========================================
// BOUTONS READY ET GROUPE
// ========================================

document.getElementById('ready-btn').addEventListener('click', function() {
    console.log('[PVP UI] Clic sur bouton Ready - État actuel:', isReady);
    
    fetch(`https://${GetParentResourceName()}/toggleReady`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(() => {
        console.log('[PVP UI] Toggle ready envoyé');
    }).catch(err => {
        console.error('[PVP UI] Erreur toggle ready:', err);
    });
});

document.getElementById('leave-group-btn').addEventListener('click', function() {
    console.log('[PVP UI] Clic sur bouton Quitter le groupe');
    
    fetch(`https://${GetParentResourceName()}/leaveGroup`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(() => {
        console.log('[PVP UI] Requête leaveGroup envoyée');
    }).catch(err => {
        console.error('[PVP UI] Erreur leaveGroup:', err);
    });
});

// ========================================
// CHARGEMENT DES INFOS DE GROUPE
// ========================================

function loadGroupInfo() {
    console.log('[PVP UI] Chargement des infos du groupe');
    
    fetch(`https://${GetParentResourceName()}/getGroupInfo`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(groupInfo => {
        console.log('[PVP UI] Infos groupe reçues:', groupInfo);
        updateGroupDisplay(groupInfo);
    }).catch(err => {
        console.log('[PVP UI] Pas de groupe actif ou erreur:', err);
        updateGroupDisplay(null);
    });
}

// ========================================
// MISE À JOUR DE L'AFFICHAGE DU GROUPE AVEC AVATARS DISCORD
// ========================================

function updateGroupDisplay(group) {
    console.log('[PVP UI] updateGroupDisplay() appelée avec:', group);
    currentGroup = group;
    
    const slots = document.querySelectorAll('.player-slot');
    const readyBtn = document.getElementById('ready-btn');
    const leaveGroupBtn = document.getElementById('leave-group-btn');
    
    // Réinitialiser tous les slots
    for (let i = 0; i < slots.length; i++) {
        const slot = slots[i];
        slot.className = 'player-slot empty-slot';
        
        if (selectedMode && i < selectedPlayers) {
            slot.classList.remove('locked');
            slot.innerHTML = `
                <div class="empty-content">
                    <div class="add-icon">+</div>
                    <div class="slot-text">Cliquez pour inviter</div>
                </div>
            `;
            slot.onclick = function() {
                openInvitePopup(i);
            };
        } else if (i > 0) {
            slot.classList.add('locked');
            slot.innerHTML = `
                <div class="empty-content">
                    <div class="add-icon">+</div>
                    <div class="slot-text">${selectedMode ? 'Non disponible' : 'Sélectionnez un mode'}</div>
                </div>
            `;
            slot.onclick = null;
        }
    }
    
    // Si pas de groupe, afficher "Vous" dans le premier slot
    if (!group || !group.members || group.members.length === 0) {
        console.log('[PVP UI] Aucun groupe actif');
        
        const firstSlot = slots[0];
        firstSlot.className = 'player-slot host-slot';
        firstSlot.innerHTML = `
            <div class="slot-content">
                <div class="player-avatar">
                    <img src="${myAvatar}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
                </div>
                <div class="player-info">
                    <div class="player-name">Vous</div>
                    <div class="player-status">
                        <span class="host-badge">👑 Hôte</span>
                    </div>
                </div>
                <div class="player-ready">
                    <div class="ready-indicator"></div>
                </div>
            </div>
        `;
        
        isReady = false;
        readyBtn.classList.remove('ready');
        document.getElementById('ready-text').textContent = 'SE METTRE PRÊT';
        leaveGroupBtn.classList.add('hidden');
        updateSearchButton();
        return;
    }
    
    console.log('[PVP UI] Mise à jour des membres du groupe - Total:', group.members.length);
    
    let currentPlayerIndex = -1;
    let isLeader = false;
    
    for (let i = 0; i < group.members.length; i++) {
        if (group.members[i].isYou) {
            currentPlayerIndex = i;
            isLeader = group.members[i].isLeader;
            isReady = group.members[i].isReady;
            myAvatar = group.members[i].avatar || DEFAULT_AVATAR;
            break;
        }
    }
    
    console.log('[PVP UI] Joueur actuel - Index:', currentPlayerIndex, 'Leader:', isLeader, 'Ready:', isReady, 'Avatar:', myAvatar);
    
    // Afficher tous les membres dans l'ordre avec leurs avatars Discord
    group.members.forEach((member, index) => {
        if (index >= slots.length) return;
        
        console.log('[PVP UI] Affichage membre', index, ':', member.name, '(Avatar:', member.avatar, ')');
        
        const slot = slots[index];
        slot.className = 'player-slot';
        
        if (member.isLeader) {
            slot.classList.add('host-slot');
        }
        
        if (member.isReady) {
            slot.classList.add('ready');
        }
        
        const canKick = isLeader && !member.isLeader && !member.isYou;
        const avatarUrl = member.avatar || DEFAULT_AVATAR;
        
        slot.innerHTML = `
            <div class="slot-content">
                <div class="player-avatar">
                    <img src="${avatarUrl}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
                </div>
                <div class="player-info">
                    <div class="player-name">${member.name}${member.isYou ? ' (Vous)' : ''}</div>
                    <div class="player-status">
                        ${member.isLeader ? '<span class="host-badge">👑 Hôte</span>' : '<span class="player-id">ID: ' + member.id + '</span>'}
                    </div>
                </div>
                <div class="player-ready">
                    <div class="ready-indicator ${member.isReady ? 'ready' : ''}"></div>
                    ${canKick ? '<button class="btn-kick" onclick="kickPlayer(' + member.id + ')">KICK</button>' : ''}
                </div>
            </div>
        `;
        slot.onclick = null;
    });
    
    // Mettre à jour le bouton Ready
    if (isReady) {
        readyBtn.classList.add('ready');
        document.getElementById('ready-text').textContent = '✓ PRÊT';
    } else {
        readyBtn.classList.remove('ready');
        document.getElementById('ready-text').textContent = 'SE METTRE PRÊT';
    }
    
    // Afficher le bouton Quitter si on est dans un groupe ET qu'on n'est PAS seul
    if (group.members.length > 1) {
        leaveGroupBtn.classList.remove('hidden');
    } else {
        leaveGroupBtn.classList.add('hidden');
    }
    
    updateSearchButton();
}

// ========================================
// KICK UN JOUEUR
// ========================================

function kickPlayer(targetId) {
    console.log('[PVP UI] Kick du joueur:', targetId);
    
    fetch(`https://${GetParentResourceName()}/kickPlayer`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            targetId: targetId
        })
    }).then(() => {
        console.log('[PVP UI] Kick envoyé');
    }).catch(err => {
        console.error('[PVP UI] Erreur kick:', err);
    });
}

// ========================================
// MISE À JOUR DU BOUTON DE RECHERCHE
// ========================================

function updateSearchButton() {
    console.log('[PVP UI] Mise à jour du bouton de recherche');
    const searchBtn = document.getElementById('search-btn');
    const searchText = document.getElementById('search-text');
    
    if (!selectedMode) {
        console.log('[PVP UI] Aucun mode sélectionné');
        searchBtn.disabled = true;
        searchText.textContent = 'SÉLECTIONNEZ UN MODE';
        return;
    }
    
    if (!currentGroup || !currentGroup.members) {
        console.log('[PVP UI] Pas assez de joueurs dans le groupe');
        searchBtn.disabled = true;
        searchText.textContent = `IL FAUT ${selectedPlayers} JOUEUR(S)`;
        return;
    }
    
    let isLeader = false;
    for (let i = 0; i < currentGroup.members.length; i++) {
        if (currentGroup.members[i].isYou && currentGroup.members[i].isLeader) {
            isLeader = true;
            break;
        }
    }
    
    if (!isLeader) {
        console.log('[PVP UI] Vous n\'êtes pas le leader');
        searchBtn.disabled = true;
        searchText.textContent = 'SEUL L\'HÔTE PEUT LANCER';
        return;
    }
    
    const allReady = currentGroup.members.every(m => m.isReady);
    const correctSize = currentGroup.members.length === selectedPlayers;
    
    console.log('[PVP UI] Vérifications - Tous prêts:', allReady, '- Bonne taille:', correctSize, '- Leader:', isLeader);
    
    if (!correctSize) {
        searchBtn.disabled = true;
        searchText.textContent = `IL FAUT ${selectedPlayers} JOUEUR(S)`;
    } else if (!allReady) {
        searchBtn.disabled = true;
        searchText.textContent = 'TOUS LES JOUEURS DOIVENT ÊTRE PRÊTS';
    } else {
        console.log('[PVP UI] Bouton de recherche activé !');
        searchBtn.disabled = false;
        searchText.textContent = 'RECHERCHER UNE PARTIE';
    }
}

// ========================================
// RECHERCHE DE PARTIE
// ========================================

document.getElementById('search-btn').addEventListener('click', function() {
    if (this.disabled) return;
    
    console.log('[PVP UI] Lancement de la recherche de partie - Mode:', selectedMode);
    
    fetch(`https://${GetParentResourceName()}/joinQueue`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            mode: selectedMode
        })
    }).then(() => {
        console.log('[PVP UI] Requête joinQueue envoyée');
    }).catch(err => {
        console.error('[PVP UI] Erreur joinQueue:', err);
    });
});

function showSearchStatus(mode) {
    console.log('[PVP UI] Affichage statut recherche');
    isSearching = true;
    searchStartTime = Date.now();
    
    document.getElementById('search-btn').style.display = 'none';
    document.getElementById('search-status').classList.remove('hidden');
    document.getElementById('search-mode-display').textContent = mode.toUpperCase();
}

function hideSearchStatus() {
    console.log('[PVP UI] Masquage statut recherche');
    isSearching = false;
    
    document.getElementById('search-status').classList.add('hidden');
    document.getElementById('search-btn').style.display = 'flex';
}

function updateSearchTimer(elapsed) {
    const minutes = Math.floor(elapsed / 60);
    const seconds = elapsed % 60;
    const formatted = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    
    document.getElementById('search-timer').textContent = formatted;
}

document.getElementById('cancel-search-btn').addEventListener('click', function() {
    console.log('[PVP UI] Annulation de la recherche');
    
    fetch(`https://${GetParentResourceName()}/cancelSearch`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(() => {
        console.log('[PVP UI] Annulation envoyée');
    }).catch(err => {
        console.error('[PVP UI] Erreur annulation:', err);
    });
});

// ========================================
// ANIMATIONS DE COMBAT
// ========================================

function showRoundStart(roundNumber) {
    const overlay = document.getElementById('combat-overlay');
    const message = document.getElementById('combat-message');
    const subtitle = document.getElementById('combat-subtitle');
    
    overlay.classList.remove('hidden');
    message.textContent = `ROUND ${roundNumber}`;
    subtitle.textContent = 'Préparez-vous';
    
    setTimeout(() => {
        overlay.classList.add('hidden');
    }, 2000);
}

function showCountdown(number) {
    const overlay = document.getElementById('combat-overlay');
    const message = document.getElementById('combat-message');
    const subtitle = document.getElementById('combat-subtitle');
    
    overlay.classList.remove('hidden');
    message.textContent = number;
    subtitle.textContent = '';
    
    setTimeout(() => {
        overlay.classList.add('hidden');
    }, 1000);
}

function showGo() {
    const overlay = document.getElementById('combat-overlay');
    const message = document.getElementById('combat-message');
    const subtitle = document.getElementById('combat-subtitle');
    
    overlay.classList.remove('hidden');
    message.textContent = 'GO!';
    subtitle.textContent = 'Combattez !';
    
    setTimeout(() => {
        overlay.classList.add('hidden');
    }, 1000);
}

// ========================================
// ANIMATIONS FIN DE ROUND & MATCH
// ========================================

function showRoundEnd(winningTeam, score, playerTeam, isVictory) {
    console.log('[PVP UI] ✨ Animation fin de round - Équipe gagnante:', winningTeam, '- Mon équipe:', playerTeam, '- Victoire:', isVictory);
    
    const overlay = document.getElementById('round-end-overlay');
    const title = document.getElementById('round-end-title');
    const subtitle = document.getElementById('round-end-subtitle');
    const team1Score = document.getElementById('round-score-team1');
    const team2Score = document.getElementById('round-score-team2');
    
    if (isVictory) {
        title.textContent = 'VICTOIRE';
        title.className = 'round-end-title victory';
        subtitle.textContent = 'Manche remportée !';
        console.log('[PVP UI] 🎉 Affichage VICTOIRE pour le joueur');
    } else {
        title.textContent = 'DÉFAITE';
        title.className = 'round-end-title defeat';
        subtitle.textContent = 'Manche perdue';
        console.log('[PVP UI] 💀 Affichage DÉFAITE pour le joueur');
    }
    
    team1Score.textContent = score.team1;
    team2Score.textContent = score.team2;
    
    overlay.classList.remove('hidden');
    
    setTimeout(() => {
        overlay.classList.add('hidden');
    }, 3000);
}

function showMatchEnd(victory, score, playerTeam) {
    console.log('[PVP UI] ✨ Animation fin de match - Victoire:', victory, '- Mon équipe:', playerTeam);
    
    const overlay = document.getElementById('match-end-overlay');
    const result = document.getElementById('match-end-result');
    const message = document.getElementById('match-end-message');
    const team1Score = document.getElementById('final-score-team1');
    const team2Score = document.getElementById('final-score-team2');
    
    if (victory) {
        result.textContent = 'VICTOIRE';
        result.className = 'match-end-result victory';
        message.textContent = 'Félicitations ! Vous avez gagné le match ! 🎉';
        console.log('[PVP UI] 🏆 Affichage VICTOIRE FINALE pour le joueur');
    } else {
        result.textContent = 'DÉFAITE';
        result.className = 'match-end-result defeat';
        message.textContent = 'Dommage... Vous avez perdu le match. Réessayez !';
        console.log('[PVP UI] 😢 Affichage DÉFAITE FINALE pour le joueur');
    }
    
    team1Score.textContent = score.team1;
    team2Score.textContent = score.team2;
    
    overlay.classList.remove('hidden');
    
    setTimeout(() => {
        overlay.classList.add('hidden');
    }, 8000);
}

// ========================================
// HUD DE SCORE IN-GAME
// ========================================

function showScoreHUD(score, round) {
    console.log('[PVP UI] Affichage HUD de score');
    const hud = document.getElementById('score-hud');
    
    updateScoreHUD(score, round);
    hud.classList.remove('hidden');
}

function hideScoreHUD() {
    console.log('[PVP UI] Masquage HUD de score');
    document.getElementById('score-hud').classList.add('hidden');
}

function updateScoreHUD(score, round) {
    document.getElementById('team1-score').textContent = score.team1;
    document.getElementById('team2-score').textContent = score.team2;
    document.getElementById('current-round-display').textContent = `Round ${round}`;
}

// ========================================
// STATS & LEADERBOARD AVEC AVATARS DISCORD
// ========================================

function loadStats() {
    console.log('[PVP UI] Chargement des statistiques');
    
    fetch(`https://${GetParentResourceName()}/getStats`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(stats => {
        console.log('[PVP UI] Stats reçues:', stats);
        
        if (stats) {
            // Mettre à jour l'avatar dans les stats
            if (stats.avatar) {
                myAvatar = stats.avatar;
                const statsAvatarEl = document.getElementById('stats-avatar');
                if (statsAvatarEl) {
                    statsAvatarEl.src = stats.avatar;
                    statsAvatarEl.onerror = function() {
                        this.src = DEFAULT_AVATAR;
                    };
                }
            }
            
            // ELO
            const eloEl = document.getElementById('stat-elo');
            const elo = stats.elo || 1000;
            if (eloEl) {
                eloEl.innerHTML = elo;
                console.log('[PVP UI] ELO affiché:', elo);
            }
            
            // Kills
            const killsEl = document.getElementById('stat-kills');
            const kills = stats.kills || 0;
            if (killsEl) {
                killsEl.innerHTML = kills;
                console.log('[PVP UI] Kills affichés:', kills);
            }
            
            // Deaths
            const deathsEl = document.getElementById('stat-deaths');
            const deaths = stats.deaths || 0;
            if (deathsEl) {
                deathsEl.innerHTML = deaths;
                console.log('[PVP UI] Deaths affichés:', deaths);
            }
            
            // Ratio K/D
            const ratioEl = document.getElementById('stat-ratio');
            const ratio = deaths > 0 ? (kills / deaths).toFixed(2) : (kills).toFixed(2);
            if (ratioEl) {
                ratioEl.innerHTML = ratio;
                console.log('[PVP UI] Ratio affiché:', ratio);
            }
            
            // Matches
            const matchesEl = document.getElementById('stat-matches');
            const matches = stats.matches_played || stats.matches || 0;
            if (matchesEl) {
                matchesEl.innerHTML = matches;
                console.log('[PVP UI] Matches affichés:', matches);
            }
            
            // Wins
            const winsEl = document.getElementById('stat-wins');
            const wins = stats.wins || 0;
            if (winsEl) {
                winsEl.innerHTML = wins;
                console.log('[PVP UI] Wins affichés:', wins);
            }
            
            console.log('[PVP UI] Toutes les stats affichées avec succès');
        } else {
            console.error('[PVP UI] Stats est null ou undefined');
        }
    }).catch(err => {
        console.error('[PVP UI] Erreur chargement stats:', err);
    });
}

function loadLeaderboard() {
    console.log('[PVP UI] Chargement du leaderboard');
    
    fetch(`https://${GetParentResourceName()}/getLeaderboard`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(leaderboard => {
        console.log('[PVP UI] Leaderboard reçu:', leaderboard);
        
        const tbody = document.getElementById('leaderboard-body');
        tbody.innerHTML = '';
        
        if (leaderboard && leaderboard.length > 0) {
            leaderboard.forEach((player, index) => {
                const row = document.createElement('tr');
                const ratio = player.deaths > 0 ? (player.kills / player.deaths).toFixed(2) : player.kills.toFixed(2);
                const avatarUrl = player.avatar || DEFAULT_AVATAR;
                
                row.innerHTML = `
                    <td class="rank">#${index + 1}</td>
                    <td class="player-cell">
                        <img class="leaderboard-avatar" src="${avatarUrl}" alt="avatar" onerror="this.src='${DEFAULT_AVATAR}'">
                        <span class="player-name-lb">${player.name}</span>
                    </td>
                    <td>${player.elo}</td>
                    <td>${ratio}</td>
                    <td>${player.wins}</td>
                `;
                
                tbody.appendChild(row);
            });
        } else {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align: center; color: #5B5A56;">Aucune donnée disponible</td></tr>';
        }
    }).catch(err => {
        console.log('[PVP UI] Erreur chargement leaderboard:', err);
        const tbody = document.getElementById('leaderboard-body');
        tbody.innerHTML = '<tr><td colspan="5" style="text-align: center; color: #5B5A56;">Aucune donnée disponible</td></tr>';
    });
}

// ========================================
// HELPER - NOM DE LA RESSOURCE
// ========================================

function GetParentResourceName() {
    if (window.location.protocol === 'file:') {
        return 'pvp_gunfight';
    }
    
    let url = window.location.href;
    
    const nuiMatch = url.match(/nui:\/\/([^\/]+)\//);
    if (nuiMatch) {
        const name = nuiMatch[1];
        console.log('[PVP UI] Nom de la ressource (NUI):', name);
        return name;
    }
    
    const name = 'pvp_gunfight';
    console.log('[PVP UI] Nom de la ressource (fallback):', name);
    return name;
}

console.log('[PVP UI] ✅ Script initialisé - Version 2.4.0 avec Avatars Discord');
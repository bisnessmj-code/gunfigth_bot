# PVP GunFight - Version 2.3.0 avec Système de Debug

## 🎯 Nouveautés de la version 2.3

### ✨ Système de Debug Centralisé

Cette version introduit un **système de debug professionnel** qui vous permet d'activer/désactiver tous les logs de manière granulaire.

### 📋 Configuration du Debug

Tous les paramètres de debug se trouvent dans `config.lua` :

```lua
Config.Debug = {
    enabled = true,  -- Master switch: Active/désactive TOUS les logs
    
    levels = {
        info = true,         -- Logs d'information généraux
        success = true,      -- Logs de succès (vert)
        warning = true,      -- Logs d'avertissement (jaune)
        error = true,        -- Logs d'erreur (rouge)
        client = true,       -- Logs client spécifiques
        server = true,       -- Logs server spécifiques
        ui = true,           -- Logs UI/NUI
        bucket = true,       -- Logs routing buckets
        elo = true,          -- Logs système ELO
        zones = true,        -- Logs système de zones
        groups = true,       -- Logs système de groupes
        matchmaking = true   -- Logs matchmaking
    }
}
```

### 🎮 Utilisation

#### Pour DÉSACTIVER tous les logs :
```lua
Config.Debug = {
    enabled = false,  -- ⚠️ Mettre à false ici
    levels = { ... }  -- Peu importe les valeurs
}
```

#### Pour filtrer par catégorie :
```lua
Config.Debug = {
    enabled = true,
    levels = {
        info = false,        -- ❌ Désactivé
        success = true,      -- ✅ Activé
        warning = true,      -- ✅ Activé
        error = true,        -- ✅ Activé
        client = false,      -- ❌ Désactivé
        server = true,       -- ✅ Activé
        ui = false,          -- ❌ Désactivé
        bucket = false,      -- ❌ Désactivé
        elo = true,          -- ✅ Activé
        zones = false,       -- ❌ Désactivé
        groups = false,      -- ❌ Désactivé
        matchmaking = true   -- ✅ Activé
    }
}
```

### 🎨 Codes Couleurs

Le système utilise des couleurs distinctes pour faciliter le debug :

- 🟢 **Vert** (`^2`) : Succès, système ELO
- 🔵 **Bleu** (`^4`) : Serveur, matchmaking
- 🟡 **Jaune** (`^3`) : Avertissements, zones
- 🔴 **Rouge** (`^1`) : Erreurs
- 🔷 **Cyan** (`^5`) : Client, groupes
- 🟠 **Orange** (`^9`) : Routing buckets
- 🟣 **Rose** (`^6`) : UI/NUI

### 🛠️ Fonctions Disponibles

Le système offre plusieurs fonctions helper dans `shared/debug.lua` :

```lua
-- Logs de base
DebugInfo(message, ...)        -- Log d'information
DebugSuccess(message, ...)     -- Log de succès (vert)
DebugWarn(message, ...)        -- Log d'avertissement (jaune)
DebugError(message, ...)       -- Log d'erreur (rouge)

-- Logs spécialisés
DebugClient(message, ...)      -- Log client
DebugServer(message, ...)      -- Log serveur
DebugUI(message, ...)          -- Log UI/NUI
DebugBucket(message, ...)      -- Log routing buckets
DebugElo(message, ...)         -- Log système ELO
DebugZones(message, ...)       -- Log système de zones
DebugGroups(message, ...)      -- Log système de groupes
DebugMatchmaking(message, ...) -- Log matchmaking

-- Fonctions avancées
DebugTable(category, tableName, table)  -- Affiche une table formatée
DebugPerformance(category, label, func) -- Mesure le temps d'exécution
```

### 📝 Exemples d'Utilisation

#### Dans le Code

```lua
-- Avant (ancienne méthode)
print('^2[PVP CLIENT]^7 Joueur téléporté')

-- Maintenant (avec système de debug)
DebugClient('Joueur téléporté')
```

```lua
-- Avec formatage de string
DebugMatchmaking('Queue %s: %d/%d joueurs', mode, current, needed)
```

```lua
-- Afficher une table
DebugTable('server', 'Match Data', matchData)
```

### 🚀 Cas d'Usage Recommandés

#### En Production
```lua
Config.Debug = {
    enabled = false,  -- Désactiver complètement
    -- ...
}
```

#### Pour Debugger les Matchs
```lua
Config.Debug = {
    enabled = true,
    levels = {
        matchmaking = true,
        bucket = true,
        elo = true,
        -- Tout le reste à false
    }
}
```

#### Pour Debugger les Zones
```lua
Config.Debug = {
    enabled = true,
    levels = {
        zones = true,
        client = true,
        -- Tout le reste à false
    }
}
```

### ⚡ Performance

Le système de debug est **très optimisé** :
- Si `Config.Debug.enabled = false`, **aucune** opération n'est effectuée
- Les logs sont filtrés **avant** le formatage de string
- Impact sur les performances : **négligeable** (<0.01ms par appel)

### 📦 Structure des Fichiers

```
pvp_gunfight/
├── config.lua              ⚙️ Configuration (incl. debug)
├── fxmanifest.lua          
├── shared/
│   └── debug.lua           🔧 Système de debug centralisé
├── client/
│   ├── main.lua            ✅ Convertis avec debug
│   └── zones.lua           ✅ Convertis avec debug
├── server/
│   ├── elo.lua             ✅ Convertis avec debug
│   ├── groups.lua          ✅ Convertis avec debug
│   └── main.lua            ✅ Convertis avec debug
└── html/
    ├── index.html
    ├── style.css
    └── script.js           ✅ Convertis avec debug (console.log conditionnels)
```

### 🎓 Guide de Conversion

Si vous ajoutez du nouveau code, voici comment l'adapter :

**Avant:**
```lua
print('^2[PVP]^7 Message')
```

**Après:**
```lua
DebugSuccess('Message')  -- ou DebugClient(), DebugServer(), etc.
```

**Avant:**
```lua
print(string.format('^2[PVP]^7 Valeur: %d', value))
```

**Après:**
```lua
DebugSuccess('Valeur: %d', value)  -- Formatage automatique
```

### ⚠️ Notes Importantes

1. **Rechargement du Script**: Après modification de `Config.Debug`, vous devez **restart la ressource** pour appliquer les changements
2. **Console F8**: Les logs apparaissent dans la console F8 (client) et dans la console serveur
3. **UI/NUI**: Les logs UI utilisent `console.log` JavaScript (visible dans F8 DevTools)

### 🔗 Compatibilité

- ✅ Compatible avec ESX Legacy
- ✅ Compatible avec oxmysql
- ✅ Optimisé pour FiveM build 2802+
- ✅ Supporte Lua 5.4

---

## 🎮 Installation

1. Placer le dossier `pvp_gunfight` dans votre dossier `resources`
2. Ajouter `ensure pvp_gunfight` dans votre `server.cfg`
3. Configurer le debug dans `config.lua` selon vos besoins
4. Restart le serveur

## 📞 Support

Pour toute question sur le système de debug ou le script en général, consultez la documentation FiveM ou contactez le développeur.

---

**Version**: 2.3.0  
**Date**: Décembre 2024  
**Auteur**: PVP GunFight Team

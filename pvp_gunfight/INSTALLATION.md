# 🚀 Installation Rapide

## Étape 1: Copier les fichiers HTML/CSS/JS originaux

Les fichiers HTML n'ont PAS besoin d'être modifiés pour le système de debug.

**Copiez simplement vos fichiers originaux :**
- `html/index.html` (depuis votre version originale)
- `html/style.css` (depuis votre version originale)  
- `html/script.js` (depuis votre version originale)

## Étape 2: Configuration

Ouvrez `config.lua` et ajustez les paramètres de debug selon vos besoins :

```lua
Config.Debug = {
    enabled = true,  -- false pour désactiver complètement
    levels = {
        -- Activez uniquement ce dont vous avez besoin
    }
}
```

## Étape 3: Installation

1. Placez le dossier dans `resources/`
2. Ajoutez `ensure pvp_gunfight` dans `server.cfg`
3. Restart le serveur

## ✅ C'est tout !

Le système de debug est maintenant actif. Consultez `README.md` pour plus de détails.

## 📝 Note sur les fichiers HTML

Les fichiers `html/` fournis dans ce ZIP sont des versions minimales.  
**Recommandation**: Utilisez vos fichiers HTML/CSS/JS originaux (ils fonctionneront parfaitement avec le nouveau système de debug Lua).

Le système de debug est entièrement côté **Lua** (client + server), donc vos fichiers HTML existants n'ont pas besoin d'être modifiés.

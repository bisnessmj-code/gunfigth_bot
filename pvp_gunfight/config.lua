Config = {}

-- ========================================
-- SYSTÈME DE DEBUG
-- ========================================
Config.Debug = {
    enabled = true,       -- ⚡ DÉSACTIVÉ PAR DÉFAUT pour les performances
    
    -- Niveaux de debug (si enabled = true)
    levels = {
        info = true,      -- ❌ Désactivé
        success = true,   -- ❌ Désactivé
        warning = true,    -- ✅ Uniquement les warnings
        error = true,      -- ✅ Uniquement les erreurs
        client = true,    -- ❌ Désactivé
        server = true,    -- ❌ Désactivé
        ui = true,        -- ❌ Désactivé
        bucket = true,    -- ❌ Désactivé
        elo = true,       -- ❌ Désactivé
        zones = true,     -- ❌ Désactivé
        groups = true,    -- ❌ Désactivé
        matchmaking = true -- ❌ Désactivé
    }
}

-- ========================================
-- CONFIGURATION DISCORD
-- ========================================
Config.Discord = {
    -- Active/Désactive les avatars Discord
    enabled = true,
    
    -- ⚠️ TOKEN DU BOT DISCORD (OBLIGATOIRE POUR LES AVATARS PERSONNALISÉS) ⚠️
    -- 
    -- COMMENT OBTENIR LE TOKEN :
    -- 1. Va sur https://discord.com/developers/applications
    -- 2. Clique "New Application" → Donne un nom (ex: "PVP Avatar Bot")
    -- 3. Va dans l'onglet "Bot" → Clique "Add Bot"
    -- 4. ACTIVE CES INTENTS OBLIGATOIRES :
    --    ✅ Server Members Intent
    --    ✅ Message Content Intent (optionnel)
    -- 5. Copie le TOKEN (clique "Reset Token" si besoin)
    -- 6. Colle-le ci-dessous entre les guillemets
    --
    -- ⚠️ NE PARTAGE JAMAIS TON TOKEN PUBLIQUEMENT ⚠️
    --
    botToken = '', 
    
    -- Taille des avatars (64, 128, 256, 512, 1024)
    avatarSize = 128,
    
    -- Format des avatars (png, jpg, webp, gif)
    avatarFormat = 'png',
    
    -- Avatar par défaut si pas de Discord lié OU si le token est invalide
    defaultAvatar = 'https://cdn.discordapp.com/embed/avatars/0.png',
    
    -- Durée du cache en secondes (5 minutes par défaut)
    cacheDuration = 300
}

-- ========================================
-- CONFIGURATION DU PED
-- ========================================
Config.PedLocation = {
    coords = vector4(-2649.454834, -767.221984, 4.746582, 102.047248),
    model = 's_m_y_dealer_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

Config.InteractionDistance = 2.5
Config.DrawMarker = true

-- ========================================
-- CONFIGURATION DES ARÈNES
-- ========================================
Config.Arenas = {
    -- Arènes originales
    ['arena_industrial_1'] = {
        name = "Zone Industrielle #1",
        zone = {
            center = vector3(474.5, -1677.5, 29.2),
            radius = 35.0
        },
        teamA = {
            vector4(463.107696, -1668.487916, 29.313598, 240.944886),
            vector4(464.597808, -1667.208740, 29.313598, 294.803162),
            vector4(462.224182, -1670.769288, 29.313598, 138.897628),
            vector4(460.918670, -1666.180176, 29.161866, 325.984252)
        },
        teamB = {
            vector4(486.013184, -1686.421998, 29.161866, 300.472442),
            vector4(483.969238, -1688.386840, 29.178710, 136.062988),
            vector4(486.896698, -1683.837402, 29.229248, 323.149598),
            vector4(487.450562, -1688.254882, 29.128174, 243.779526)
        }
    },
    ['arena_industrial_2'] = {
        name = "Zone Industrielle #2",
        zone = {
            center = vector3(563.0, -1778.5, 29.2),
            radius = 35.0
        },
        teamA = {
            vector4(560.202210, -1788.725220, 29.195556, 306.141724),
            vector4(558.408814, -1788.039550, 29.195556, 79.370080),
            vector4(556.417602, -1786.654908, 29.195556, 14.173228),
            vector4(556.707702, -1791.679078, 29.195556, 8.503936)
        },
        teamB = {
            vector4(565.885742, -1769.960450, 29.330444, 144.566926),
            vector4(562.799988, -1771.173584, 29.347290, 130.393708),
            vector4(564.791198, -1766.901124, 29.145020, 192.755906),
            vector4(567.758240, -1768.720826, 29.145020, 212.598420)
        }
    },
    ['arena_skatepark'] = {
        name = "Skatepark",
        zone = {
            center = vector3(-941.0, -792.0, 15.9),
            radius = 35.0
        },
        teamA = {
            vector4(-950.953858, -800.123046, 15.917968, 320.314972),
            vector4(-949.318664, -801.626342, 15.917968, 320.314972),
            vector4(-946.457154, -802.549438, 15.917968, 320.314972),
            vector4(-949.714294, -803.274720, 15.917968, 323.149598)
        },
        teamB = {
            vector4(-931.081298, -783.626342, 15.917968, 130.393708),
            vector4(-933.718688, -783.309876, 15.917968, 136.062988),
            vector4(-935.182434, -780.738464, 15.917968, 136.062988),
            vector4(-932.531860, -779.709900, 15.917968, 138.897628)
        }
    },
    ['arena_restaurant'] = {
        name = "Restaurant",
        zone = {
            center = vector3(2581.0, 475.0, 108.5),
            radius = 35.0
        },
        teamA = {
            vector4(2579.815430, 494.940674, 108.474000, 187.086608),
            vector4(2580.171386, 491.920868, 108.507690, 189.921264),
            vector4(2577.059326, 491.525268, 108.524536, 170.078736),
            vector4(2584.364746, 492.619782, 108.507690, 198.425202)
        },
        teamB = {
            vector4(2581.991210, 456.237366, 108.440308, 8.503936),
            vector4(2581.556152, 459.178040, 108.440308, 5.669292),
            vector4(2578.377930, 458.861542, 108.440308, 31.181102),
            vector4(2584.997802, 459.006592, 108.440308, 348.661408)
        }
    },
    ['arena_mazebank'] = {
        name = "Maze Bank",
        zone = {
            center = vector3(-247.5, -1900.0, 27.7),
            radius = 45.0
        },
        teamA = {
            vector4(-259.608796, -1914.580200, 27.746460, 323.149598),
            vector4(-258.356048, -1915.556030, 27.746460, 308.976380),
            vector4(-261.032958, -1913.617554, 27.746460, 320.314972),
            vector4(-261.230774, -1916.334106, 27.746460, 314.645660)
        },
        teamB = {
            vector4(-235.371430, -1886.083496, 27.746460, 138.897628),
            vector4(-236.703292, -1884.791260, 27.746460, 116.220474),
            vector4(-233.960434, -1887.019776, 27.746460, 175.748032),
            vector4(-234.131866, -1883.604370, 27.746460, 141.732284)
        }
    },
    ['arena_sandy'] = {
        name = "Sandy Shores",
        zone = {
            center = vector3(236.5, 3103.0, 42.4),
            radius = 35.0
        },
        teamA = {
            vector4(236.413192, 3103.925292, 42.405884, 277.795288),
            vector4(238.602204, 3104.162598, 42.422730, 277.795288),
            vector4(238.734070, 3101.854980, 42.405884, 252.283462),
            vector4(238.865936, 3105.639648, 42.439576, 306.141724)
        },
        teamB = {
            vector4(261.771424, 3106.641846, 42.405884, 85.03936),
            vector4(260.373626, 3103.305420, 42.405884, 96.377944),
            vector4(258.738464, 3106.457032, 42.473266, 82.20472),
            vector4(260.360444, 3110.228516, 42.490112, 93.543304)
        }
    },
    ['arena_lucky'] = {
        name = "Lucky Street",
        zone = {
            center = vector3(142.0, -1471.0, 29.2),
            radius = 35.0
        },
        teamA = {
            vector4(132.487916, -1461.995606, 29.347290, 232.440948),
            vector4(130.536270, -1462.971436, 29.347290, 229.606292),
            vector4(132.804398, -1460.281372, 29.347290, 272.125976),
            vector4(130.061538, -1459.898926, 29.330444, 229.606292)
        },
        teamB = {
            vector4(152.334076, -1482.778076, 29.128174, 48.188972),
            vector4(154.167038, -1480.839600, 29.128174, 31.181102),
            vector4(155.973632, -1478.360474, 29.128174, 53.858268),
            vector4(155.986816, -1481.894532, 29.111328, 51.023624)
        }
    },
    ['arena_chiotes'] = {
        name = "Chiotes",
        zone = {
            center = vector3(-1389.5, -1326.0, 4.15),
            radius = 35.0
        },
        teamA = {
            vector4(-1392.224122, -1335.507690, 4.139892, 348.661408),
            vector4(-1390.232910, -1335.982422, 4.156738, 320.314972),
            vector4(-1387.582398, -1336.496704, 4.156738, 286.299194),
            vector4(-1389.692260, -1338.685668, 4.257934, 17.007874)
        },
        teamB = {
            vector4(-1386.250488, -1316.268188, 4.156738, 170.078736),
            vector4(-1386.698852, -1318.931884, 4.139892, 170.078736),
            vector4(-1384.615356, -1319.327514, 4.139892, 195.590546),
            vector4(-1388.479126, -1318.694458, 4.139892, 161.574798)
        }
    },
    ['arena_toit'] = {
        name = "Toit Maze",
        zone = {
            center = vector3(103.0, -872.0, 134.75),
            radius = 35.0
        },
        teamA = {
            vector4(86.465934, -866.307678, 134.759766, 255.118104),
            vector4(87.059342, -864.171448, 134.759766, 255.118104),
            vector4(85.424180, -868.734070, 134.759766, 252.283462),
            vector4(83.947250, -865.661560, 134.759766, 252.283462)
        },
        teamB = {
            vector4(119.432968, -878.017578, 134.759766, 62.362206),
            vector4(118.430770, -880.140686, 134.759766, 65.196854),
            vector4(119.762634, -876.131836, 134.759766, 62.362206),
            vector4(121.424180, -878.228576, 134.759766, 65.196854)
        }
    },
    ['arena_maison'] = {
        name = "Maison de Luxe",
        zone = {
            center = vector3(-130.0, 1012.5, 235.85),
            radius = 35.0
        },
        teamA = {
            vector4(-119.960434, 1015.832946, 235.808106, 113.385826),
            vector4(-120.791206, 1017.824158, 235.824952, 110.551186),
            vector4(-121.582412, 1019.802186, 235.824952, 110.551186),
            vector4(-118.589012, 1018.734070, 235.892334, 110.551186)
        },
        teamB = {
            vector4(-140.545060, 1012.813172, 235.808106, 291.968506),
            vector4(-139.740662, 1010.967042, 235.858642, 291.968506),
            vector4(-138.843964, 1008.791198, 235.909180, 289.133850),
            vector4(-141.586808, 1009.503296, 235.926026, 291.968506)
        }
    }
}

-- ========================================
-- CONFIGURATION DES LOADOUTS
-- ========================================
Config.Loadouts = {
    ['classic'] = {
        name = "Classique",
        weapons = {
            {name = 'WEAPON_PISTOL', ammo = 50},
            {name = 'WEAPON_KNIFE', ammo = 1}
        }
    },
    ['assault'] = {
        name = "Assaut",
        weapons = {
            {name = 'WEAPON_ASSAULTRIFLE', ammo = 100},
            {name = 'WEAPON_PISTOL', ammo = 30}
        }
    }
}

-- ========================================
-- CONFIGURATION DES ROUNDS
-- ========================================
Config.RoundTime = 180
Config.MaxRounds = 5
Config.RespawnDelay = 5

-- ========================================
-- CONFIGURATION ELO
-- ========================================
Config.StartingELO = 1000
Config.KFactor = 32

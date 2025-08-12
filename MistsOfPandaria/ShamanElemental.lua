-- ShamanElemental.lua
-- August 2025 - MoP Structure based on Retail
-- Created by Smufrik


-- MoP: Use UnitClass instead of UnitClassBase
if select(2, UnitClass('player')) ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
    
-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
local class = Hekili.Class
local state = Hekili.State


local strformat = string.format
    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local spec = Hekili:NewSpecialization( 262, true )

-- Enhanced Mana resource system for Elemental Shaman
-- Mana resource registration for Elemental Shaman (simplified for MoP compatibility)
spec:RegisterResource( 0 ) -- Mana = 0 in MoP (use simple registration like other specs)

-- Talents (MoP Elemental Shaman talents)
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    nature_guardian = { 1, 1, 30884 }, -- When you are below 30% health, all damage taken is reduced by 30% and your movement speed is increased by 30%.
    stone_bulwark_totem = { 1, 2, 108270 }, -- Summons a Stone Bulwark Totem with 5 health at your feet for 30 sec. When damaged, the totem absorbs the damage instead of the player.
    astral_shift = { 1, 3, 108271 }, -- You shift into the astral plane, reducing all damage taken by 40% for 6 sec.
    
    -- Tier 2 (Level 30)
    frozen_power = { 2, 1, 63374 }, -- Reduces the cooldown of your Frost Shock by 1 sec and your Frost Shock also reduces the target's movement speed by an additional 30%.
    earthgrab_totem = { 2, 2, 51485 }, -- Summons an Earthgrab Totem that grasps the legs of enemies within 8 yards, preventing movement for 8 sec.
    windwalk_totem = { 2, 3, 108273 }, -- Summons a Windwalk Totem that removes all movement impairing effects from party and raid members within 30 yards.
    
    -- Tier 3 (Level 45)  
    call_of_the_elements = { 3, 1, 108285 }, -- Reduces the cooldown of your totems by 4 sec.
    totemic_restoration = { 3, 2, 108284 }, -- You may have 1 additional totem of each element active at one time.
    totemic_projection = { 3, 3, 108287 }, -- Relocates your active totems to the target location.
    
    -- Tier 4 (Level 60)
    lashing_lava = { 4, 1, 108291 }, -- Your Lava Lash ability will spread Flame Shock from your target to up to 4 nearby enemies.
    conductivity = { 4, 2, 108282 }, -- When you cast Lightning Bolt or Chain Lightning on a target affected by your Flame Shock, it triggers a Lightning Blast at that target.
    unleashed_fury = { 4, 3, 117012 }, -- Unleash Elements enhances your next spell cast.
    
    -- Tier 5 (Level 75)
    unleash_life = { 5, 1, 73685 }, -- Unleashes elemental forces of Life, healing the Shaman and nearby allies for 30% of the Shaman's maximum health.
    ancestral_swiftness = { 5, 2, 16188 }, -- Your next spell with a base casting time less than 10 sec becomes an instant cast spell.
    echo_of_the_elements = { 5, 3, 108283 }, -- When you cast Earth Shock, Fire Nova, Lightning Bolt, or Chain Lightning, there is a 6% chance to not trigger the global cooldown.
    
    -- Tier 6 (Level 90)
    primal_elementalist = { 6, 1, 117013 }, -- Your Fire and Earth Elementals are infused with raw primal essence, granting them additional abilities.
    elemental_blast = { 6, 2, 117014 }, -- Harnesses the raw power of the elements, dealing elemental damage and increasing your critical strike, haste, or mastery by 5% for 8 sec.
} )

-- Glyphs (Enhanced System - authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs - Elemental Combat
    [54825] = "lightning_bolt",       -- Lightning Bolt now has a 50% chance to not trigger a cooldown
    [54760] = "chain_lightning",      -- Chain Lightning now affects 2 additional targets
    [54821] = "earth_shock",          -- Earth Shock now has a 50% chance to not trigger a cooldown
    [54832] = "flame_shock",          -- Flame Shock now has a 50% chance to not trigger a cooldown
    [54743] = "frost_shock",          -- Frost Shock now has a 50% chance to not trigger a cooldown
    [54829] = "lava_burst",           -- Lava Burst now has a 50% chance to not trigger a cooldown
    [54754] = "earthquake",           -- Earthquake now affects 2 additional targets
    [54755] = "thunderstorm",         -- Thunderstorm now affects 2 additional targets
    [116218] = "elemental_mastery",   -- Elemental Mastery now also increases your movement speed by 50%
    [125390] = "ancestral_swiftness", -- Ancestral Swiftness now also increases your movement speed by 30%
    [125391] = "echo_of_the_elements", -- Echo of the Elements now also increases your damage by 20%
    [125392] = "unleash_life",        -- Unleash Life now also increases your healing done by 20%
    [125393] = "ancestral_guidance",  -- Ancestral Guidance now also increases your healing done by 20%
    [125394] = "primal_elementalist", -- Primal Elementalist now also increases your damage by 20%
    [125395] = "elemental_focus",     -- Elemental Focus now also increases your critical strike chance by 10%
    
    -- Major glyphs - Utility/Defensive
    [94388] = "hex",                  -- Hex now affects all enemies within 5 yards
    [59219] = "wind_shear",           -- Wind Shear now has a 50% chance to not trigger a cooldown
    [114235] = "purge",               -- Purge now affects all enemies within 5 yards
    [125396] = "cleanse_spirit",      -- Cleanse Spirit now affects all allies within 5 yards
    [125397] = "healing_stream_totem", -- Healing Stream Totem now affects 2 additional allies
    [125398] = "healing_rain",        -- Healing Rain now affects 2 additional allies
    [125399] = "chain_heal",          -- Chain Heal now affects 2 additional allies
    [125400] = "healing_wave",        -- Healing Wave now has a 50% chance to not trigger a cooldown
    [125401] = "lesser_healing_wave", -- Lesser Healing Wave now has a 50% chance to not trigger a cooldown
    [54828] = "healing_surge",        -- Healing Surge now has a 50% chance to not trigger a cooldown
    
    -- Major glyphs - Defensive/Survivability
    [125402] = "shamanistic_rage",    -- Shamanistic Rage now also increases your dodge chance by 20%
    [125403] = "astral_shift",        -- Astral Shift now also increases your movement speed by 30%
    [125404] = "stone_bulwark_totem", -- Stone Bulwark Totem now also increases your armor by 20%
    [125405] = "healing_tide_totem",  -- Healing Tide Totem now affects 2 additional allies
    [125406] = "mana_tide_totem",     -- Mana Tide Totem now affects 2 additional allies
    [125407] = "tremor_totem",        -- Tremor Totem now affects all allies within 10 yards
    [125408] = "grounding_totem",     -- Grounding Totem now affects all allies within 10 yards
    [125409] = "earthbind_totem",     -- Earthbind Totem now affects all enemies within 10 yards
    [125410] = "searing_totem",       -- Searing Totem now affects 2 additional enemies
    [125411] = "magma_totem",         -- Magma Totem now affects 2 additional enemies
    
    -- Major glyphs - Control/CC
    [125412] = "hex",                 -- Hex now affects all enemies within 5 yards
    [125413] = "wind_shear",          -- Wind Shear now affects all enemies within 5 yards
    [125414] = "purge",               -- Purge now affects all enemies within 5 yards
    [125415] = "cleanse_spirit",      -- Cleanse Spirit now affects all allies within 5 yards
    [125416] = "healing_stream_totem", -- Healing Stream Totem now affects all allies within 10 yards
    [125417] = "healing_rain",        -- Healing Rain now affects all allies within 10 yards
    
    -- Minor glyphs - Visual/Convenience
    [57856] = "ghost_wolf",           -- Your ghost wolf has enhanced visual effects
    [57862] = "water_walking",        -- Your water walking has enhanced visual effects
    [57863] = "water_breathing",      -- Your water breathing has enhanced visual effects
    [57855] = "unburdening",          -- Your unburdening has enhanced visual effects
    [57861] = "astral_recall",        -- Your astral recall has enhanced visual effects
    [57857] = "the_prismatic_eye",    -- Your the prismatic eye has enhanced visual effects
    [57858] = "far_sight",            -- Your far sight has enhanced visual effects
    [57860] = "deluge",               -- Your deluge has enhanced visual effects
    [121840] = "lightning_shield",    -- Your lightning shield has enhanced visual effects
    [125418] = "blooming",            -- Your abilities cause flowers to bloom around the target
    [125419] = "floating",            -- Your spells cause you to hover slightly above the ground
    [125420] = "glow",                -- Your abilities cause you to glow with elemental energy
} )

-- Auras
spec:RegisterAuras( {
    -- Forms and Stances
    ghost_wolf = {
        id = 2645,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Weapon Imbues (MoP Classic IDs)
    flametongue = {
        id = 8024,
        duration = 3600,
        max_stack = 1,
    },
    
    frostbrand = {
        id = 8033,
        duration = 3600,
        max_stack = 1,
    },
    
    windfury = {
        id = 8232,
        duration = 3600,
        max_stack = 1,
    },
    
    rockbiter = {
        id = 8017,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Shields
    lightning_shield = {
        id = 324,
        duration = 600,
        max_stack = 3,
    },
    
    earth_shield = {
        id = 974,
        duration = 600,
        max_stack = 9,
    },
    
    water_shield = {
        id = 52127,
        duration = 600,
        max_stack = 3,
    },
    
    -- Buffs
    lava_surge = {
        id = 77756,
        duration = 10,
        max_stack = 1,
    },
    
    clearcasting = {
        id = 16246,
        duration = 15,
        max_stack = 1,
    },
    
    -- Talent Buffs
    elemental_mastery = {
        id = 16166,
        duration = 30,
        max_stack = 1,
    },
    
    ancestral_swiftness = {
        id = 16188,
        duration = 10,
        max_stack = 1,
    },
    
    echo_of_the_elements = {
        id = 108283,
        duration = 10,
        max_stack = 1,
    },
    
    -- Debuffs
    flame_shock = {
        id = 8050,
        duration = 30,
        tick_time = 3,
        type = "Magic",
        max_stack = 1,
    },
    
    frost_shock = {
        id = 8056,
        duration = 8,
        type = "Magic",
        max_stack = 1,
    },
    
    -- Totem auras with proper tracking
    searing_totem = {
        duration = 50,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 1 )
            
            if up and texture == 135825 then -- Searing Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    fire_elemental = {
        duration = 120,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 1 )
            
            if up and texture == 135790 then -- Fire Elemental texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    earth_elemental = {
        duration = 120,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 2 )
            
            if up and texture == 136024 then -- Earth Elemental texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    magma_totem = {
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 1 )
            
            if up and texture == 135826 then -- Magma Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    healing_stream_totem = {
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 3 )
            
            if up and texture == 135127 then -- Healing Stream Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    mana_tide_totem = {
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 3 )
            
            if up and texture == 135861 then -- Mana Tide Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Cooldown Buffs
    ascendance = {
        id = 114050,
        duration = 15,
        max_stack = 1,
    },
    
    thunderstorm = {
        id = 51490,
        duration = 10,
        max_stack = 1,
    },
    
    spiritwalkers_grace = {
        id = 79206,
        duration = 15,
        max_stack = 1,
    },
    
    astral_shift = {
        id = 108271,
        duration = 6,
        max_stack = 1,
    },

    stone_bulwark_totem = {
        id = 108270,
        duration = 30,
        max_stack = 1,
    },
} )

-- Register totem models for icon-based detection
spec:RegisterTotems( {
    searing_totem = { id = 135825 },
    magma_totem = { id = 135826 },
    fire_elemental = { id = 135790 },
    earth_elemental = { id = 136024 },
    healing_stream_totem = { id = 135127 },
    mana_tide_totem = { id = 135861 },
    stormlash_totem = { id = 237579 },
    earthbind_totem = { id = 136102 },
    grounding_totem = { id = 136039 },
    stoneclaw_totem = { id = 136097 },
    stoneskin_totem = { id = 136098 },
    tremor_totem = { id = 136108 },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Basic Abilities
    lightning_bolt = {
        id = 403,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.06 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136048,
        
        handler = function()
            removeBuff( "clearcasting" )
            if state.talent.rolling_thunder and state.buff.lightning_shield.up and state.buff.lightning_shield.stack >= 7 then
                state:QueueAuraEvent( "lava_surge", "AURA_APPLIED" )
            end
        end,
    },
    
    chain_lightning = {
        id = 421,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.12 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136015,
        
        handler = function()
            removeBuff( "clearcasting" )
            if state.talent.rolling_thunder and state.buff.lightning_shield.up and state.buff.lightning_shield.stack >= 7 then
                state:QueueAuraEvent( "lava_surge", "AURA_APPLIED" )
            end
        end,
    },
    
    lava_burst = {
        id = 51505,
        cast = function() return state.buff.lava_surge.up and 0 or 2.0 end,
        cooldown = 8,
        gcd = "spell",
        
        spend = function() return state.buff.lava_surge.up and 0 or 0.10 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 237582,
        
        handler = function()
            removeBuff( "lava_surge" )
            if state.debuff.flame_shock.up then
                -- Guaranteed crit on flame shocked targets
            end
        end,
    },
    
    earth_shock = {
        id = 8042,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136026,
        
        handler = function()
            -- Can proc Lava Surge
            if math.random() < 0.15 and state.buff.lightning_shield.up then
                state:QueueAuraEvent( "lava_surge", "AURA_APPLIED" )
            end
        end,
    },
    
    flame_shock = {
        id = 8050,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135813,
        
        handler = function()
            applyDebuff( "target", "flame_shock" )
        end,
    },
    
    frost_shock = {
        id = 8056,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135849,
        
        handler = function()
            applyDebuff( "target", "frost_shock" )
        end,
    },

    -- Ascendance (major cooldown)
    ascendance = {
    id = 114050, -- Correct Elemental Ascendance spell ID
        cast = 0,
        cooldown = 180,
        gcd = "spell",
    toggle = "cooldowns",
        
        startsCombat = false,
        texture = 237577,
        
        handler = function()
            applyBuff( "ascendance" )
        end,
    },

    -- Thunderstorm (mana restore, knockback)
    thunderstorm = {
        id = 51490,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        startsCombat = true,
        texture = 237588,
        
        handler = function()
            -- Mana restore and knockback handled elsewhere if needed
            -- Could set a flag or update state if needed
        end,
    },
    
    -- Shields
    lightning_shield = {
        id = 324,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.lightning_shield.up and "lightning_shield" or ( state.buff.earth_shield.up and "earth_shield" ) or ( state.buff.water_shield.up and "water_shield" ) end,
        
        handler = function()
            removeBuff( "earth_shield" )
            removeBuff( "water_shield" )
            applyBuff( "lightning_shield", nil, 3 )
        end,
        
        copy = { 324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281 }
    },
    
    earth_shield = {
        id = 974,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.earth_shield.up and "earth_shield" or ( state.buff.lightning_shield.up and "lightning_shield" ) or ( state.buff.water_shield.up and "water_shield" ) end,
        
        handler = function()
            removeBuff( "lightning_shield" )
            removeBuff( "water_shield" )
            applyBuff( "earth_shield", nil, 9 )
        end,
        
        copy = { 974, 32593, 32594, 49283, 49284 }
    },
    
    water_shield = {
        id = 52127,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.water_shield.up and "water_shield" or ( state.buff.lightning_shield.up and "lightning_shield" ) or ( state.buff.earth_shield.up and "earth_shield" ) end,
        
        handler = function()
            removeBuff( "lightning_shield" )
            removeBuff( "earth_shield" )
            applyBuff( "water_shield", nil, 3 )
        end,
        
        copy = { 52127, 52129, 52131, 52134, 52136, 52138 }
    },
    
    -- Weapon Imbues
    flametongue_weapon = {
        id = 8024,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "flametongue",
        
        handler = function()
            applyBuff( "flametongue" )
        end,
    },
    
    frostbrand_weapon = {
        id = 8033,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "frostbrand",
        
        handler = function()
            applyBuff( "frostbrand" )
        end,
    },
    
    windfury_weapon = {
        id = 8232,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "windfury",
        
        handler = function()
            applyBuff( "windfury" )
        end,
    },
    
    rockbiter_weapon = {
        id = 8017,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "rockbiter",
        
        handler = function()
            applyBuff( "rockbiter" )
        end,
    },
    
    -- Talent Abilities
    elemental_blast = {
        id = 117014,
        cast = 2.0,
        cooldown = 12,
        gcd = "spell",
        
        talent = "elemental_blast",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = true,
        texture = 651244,
        
        handler = function()
            -- Buffs a random stat
        end,
    },
    
    elemental_mastery = {
        id = 16166,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        talent = "elemental_mastery",
    toggle = "cooldowns",
        
        handler = function()
            applyBuff( "elemental_mastery" )
        end,
    },
    
    ancestral_swiftness = {
        id = 16188,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        talent = "ancestral_swiftness",
    toggle = "cooldowns",
        
        handler = function()
            applyBuff( "ancestral_swiftness" )
        end,
    },
    
    -- Utility
    purge = {
        id = 370,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136075,
        
        usable = function() return buff.dispellable_magic.up end,
        
        handler = function()
            removeBuff( "dispellable_magic" )
        end,
    },
    
    wind_shear = {
        id = 57994,
        cast = 0,
        cooldown = 12,
        gcd = "off",
        
        startsCombat = true,
        texture = 136018,
        
        toggle = "interrupts",
        interrupt = true,
        
        usable = function() return target.casting end,
        
        handler = function()
            -- Interrupt spell (actual interruption handled by Hekili core)
        end,
    },
    
    ghost_wolf = {
        id = 2645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136095,
        
        handler = function()
            applyBuff( "ghost_wolf" )
        end,
    },
    
    -- Totems
    searing_totem = {
        id = 3599,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135825,
        
        usable = function()
            -- Don't suggest if Searing Totem already active
            return not buff.searing_totem.up, "searing totem already active"
        end,
        
        handler = function()
            -- Searing Totem provides continuous damage
        end,
    },
    
    magma_totem = {
        id = 8190,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.35,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135826,
        
        handler = function()
            -- Magma Totem provides AoE damage pulses
        end,
    },
    
    fire_elemental_totem = {
        id = 2894,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
    toggle = "cooldowns",
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135790,
        
        handler = function()
            -- Summons Fire Elemental for 120 seconds
        end,
    },
    
    earth_elemental_totem = {
        id = 2062,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
    toggle = "cooldowns", -- treat as major CD so hidden when CDs disabled
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136024,
        
        handler = function()
            -- Summons Earth Elemental for 120 seconds
        end,
    },
    
    stormlash_totem = {
        id = 120668,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
    toggle = "cooldowns",
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = false,
        texture = 839977,
        
        handler = function()
            -- Stormlash Totem buffs raid damage
        end,
    },
    
    -- Other Abilities
    unleash_elements = {
        id = 73680,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = 0.17,
        spendType = "mana",
        startsCombat = true,
        handler = function()
            if state.buff.flametongue.up then
                -- Flame damage and movement bonus
            elseif state.buff.frostbrand.up then
                -- Frost damage and slow
            elseif state.buff.windfury.up then
                -- Lightning damage and speed
            elseif state.buff.rockbiter.up then
                -- Earth damage and damage reduction
            end
        end,
    },
    
    spiritwalkers_grace = {
        id = 79206,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        toggle = "defensives",
        startsCombat = false,
        handler = function()
            applyBuff( "spiritwalkers_grace" )
        end,
    },
    
    earthquake = {
        id = 61882,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        channeled = true,
        
        spend = 0.44,
        spendType = "mana",
        
        startsCombat = true,
        texture = 451165,
        
        handler = function()
            -- Earthquake channeled AoE
        end,
    },
    
    call_of_the_elements = {
        id = 108285,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
    toggle = "cooldowns",
        
        talent = "call_of_the_elements",
        
        startsCombat = false,
        texture = 136792,
        
        handler = function()
            -- Reduces totem cooldowns
        end,
    },

    -- Defensives (Talents Tier 1)
    astral_shift = {
        id = 108271,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        talent = "astral_shift",
        toggle = "defensives",
        startsCombat = false,
        texture = 538565,
        handler = function()
            applyBuff( "astral_shift" )
        end,
    },

    stone_bulwark_totem = {
        id = 108270,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        talent = "stone_bulwark_totem",
        toggle = "defensives",
        startsCombat = false,
        texture = 538576,
        handler = function()
            applyBuff( "stone_bulwark_totem" )
        end,
    },
    
    -- Ascendance abilities
    lava_beam = {
        id = 114074,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.12 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 451165,
        
        usable = function() return buff.ascendance.up end,
        
        handler = function()
            state:RemoveBuff( "clearcasting" )
            if state.talent.rolling_thunder and state.buff.lightning_shield.up and state.buff.lightning_shield.stack >= 7 then
                state:QueueAuraEvent( "lava_surge", "AURA_APPLIED" )
            end
        end,
    },
} )

-- State Variables and Expressions
spec:RegisterStateExpr( "lightning_shield_max_stack", function()
    return 3 -- Lightning Shield has max 3 stacks in MoP
end )

spec:RegisterStateExpr( "time_to_bloodlust", function()
    -- Simple implementation - return a large number if no bloodlust planned
    return buff.bloodlust.up and 0 or 999
end )

-- Enchant tracking (weapon imbues) - using MoP Classic weapon enchant detection
local _GetWeaponEnchantInfo = _G.GetWeaponEnchantInfo -- may be nil on some clients/builds.
spec:RegisterStateTable( "enchant", setmetatable( {}, {
    __index = function( t, k )
        -- Fallback: if API not present just use self-buff presence.
        if k == "flametongue" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 5 ) ) or state.buff.flametongue.up }
            end
            return { weapon = state.buff.flametongue.up }
        elseif k == "frostbrand" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 2 ) ) or state.buff.frostbrand.up }
            end
            return { weapon = state.buff.frostbrand.up }
        elseif k == "windfury" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 283 ) ) or state.buff.windfury.up }
            end
            return { weapon = state.buff.windfury.up }
        elseif k == "rockbiter" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 1 ) ) or state.buff.rockbiter.up }
            end
            return { weapon = state.buff.rockbiter.up }
        end
        return { weapon = false }
    end
} ) )

-- Earthquake tracking (for ticking/remains)
spec:RegisterStateExpr( "ticking", function()
    return false -- Would need to track if earthquake is currently channeling
end )

spec:RegisterStateExpr( "remains", function()
    return 0 -- Earthquake remaining time - would need proper implementation
end )

-- Priority List
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    cycle = false,
    
    nameplates = false,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "volcanic_potion",
    
    package = "Elemental",
} )

spec:RegisterPack( "Elemental", 202508011, [[Hekili:DNvFVTTnt8plfdWibn112X2nTl2aRdfyTaTR4rDy)XqLfTeTnHLe1ePIxgm0N9NJK6Drs7SxskgkARSoY7DE3VJYDS7xCDcqCS7NMmAYSr3mE8WXxpB0Kx76WVpb76KG83J2cpeJIG)9DH4iCmhfkOCFiffi4aJML6duDDwNrc5Vp2DTg2o9MPVY1bLX3rtDDCIY2Ks276SJeeGv7aZ8DD(Yocl3t8xuUxH4Z9OBGF7Zj04CVqcJdK3qtZ9(j8EsiziOoP0nKqqj(UCpNDOiu8BY9Qu3CVxK79r6NZ9MnC2Wr5E)pkhj52hG1)wedhaYa49VspSdJGFSnJeaYffdpl0zGne)cEKKsOPeobZY)GKbFof7tJwJ4cA4euAbVvAmBysj9NV4LHKT74XK4TRy7i4WGRiBw8S1zB2mSlLHzj6zXMqiyWPXBZWRoGrj0yjtWX(7qX8HnipurwpByyuQqACkhhj5G8PHTEpOedkE)gskEfU0L2GqeABeQA56fwcTYDFXpNiEwevOj4yCQ4)5KiYFkDBVr6eFrswiSG2YujJIOs9BxhIy8xgIUdTADwkdIcer6syi9ao47Z9IXBboFheofsjEl8gkSiwwscnLlc97WP4Hxwen)iIazcPvzifMJWJLqG4(bu4ECkB12uKpw43IO3jvLHbqMjk2hVCuZD5dAYk1pxjYDVsCwAHpLggqpeZo9sruPyeV)oWBeJJGuVLlU(07KbwBiEfhLUfZlmVFSsWYts1HRknQkCjKQm1eX8XXbctdcWhpkFxT)pcC)407LKuIAi4ObXsxfqW3Uy6i9czDiLgSAtw69pybzGHqybNUhm6)HyOU0VgNu6FI4I(2)YXZgP1VC9SJhlfwt9mfhbzGSLJNm6s9QfCaLVZIE1H(JOI11ZkukBS6g7I62PfHSwHr9YMXPPrqLGD1Ud5wLzzHzmUP8ZjgspfsJXtbJHDGSHhJzmdzjIcUqrBQ)EHudOf1GvVQYwgpzGntDUvQgyQbnVA)w0NLlgpPOKGJSmbuEuvNOrTVA(3QuIgJglD2nLJqBoEudHsBc6OUFLisaR6jXN11MYIdXIeOI0yMWWGKzrP9csyv9QH4y06qOZHrwv3nQkru(kwgSGw5WD35)6TL7kWVPQM0v5o7u56mHAxFf9rNBGQRaePOWggCHUMjLsCvkg4UfJOduLgPvDOC68kvWO6yNEGJake)9lxmFWf2C8Z1vB1IvulM10Ws0e)a9DnQx4DX1pVSmcRbRaemFB1nvPqnoHOdG1u9NKmEWRN9(01xyqBB52gGfluUZ(G1jSQEcAWf6oeXwPy5IXABjimVEHN2hn7liBvvvCOZPftS4FNZpnuHFpdTxlg(P6Tzmkspc2UlhM4Jia8xyaUo3bqGb6LtEpcg5(akvqJvoBDXOYQHSJimMCKOIPHkMRERyUmXaVCONZE4W8WCVCV3ZvBsoxhK2hiMDIVtm3lge89vJgdprI9dZGr6bsey8503afmetH)B)cdl4eoI91RY9oSJ4VR5QrX3xl1Ij1W)rsiXNWdR5BG4jHWX1cfg1d09cX8fflY9g)1IbgRF1Kgs(armNzLfvWsE5sLEd5RIZIG5lecMfcj45F49rLJpoRZLtaeDDyjyFimmFIRJ8LYBkPzjv4fFsEdmff9DFRRJInUonoBOUyKusIIIjSAUoWAai3eKydApGL7D8yUNzaz5E3kgrUauwXQnGHsSuO2G3GCplNrKlB(zTkdcYLd(WooPAd1k4SAVzxCDcMETrM2VSsnNQljj4XuJ84zGJulQnPVOIA)wiTi3UVtTw0IPcfz2PvK(O4KY6IYmPMntZ9wcr3zJuPa6OdbSRNPiBnWk4dmFL3L1kVw4McJyUrJWys4Yf9Zc7d)tQgJQ1GAfvi2xD2ITamyPFtt15woefSWw2E70NBovETb0Hn8LTxGGPV(e51A71P8KZlTStfsNRmuDoGEbAvnmqXgpsOzvEIwGjBQXcRaQGTbLfATePMlJRtPYh3lA8QhWfn25ogBgL6DzIfzVAQdw6j6E3FQgoRuxzF19cyVOxBGjQ8HRptraqr0vn8S2B7oIYyF11gBl63npUBxYhWNa4VZ9)B4Q)7ub2017BV5gSrZxPFhOcT(Aa2J0pYTMM28uV6AL7DAxKazdmKMZMDI32gdvRXR38E06gAnWR7S4uBU)te5Q9Kn2M9KKNAyFY921pCB7AsnXiBfm2jGpycyGzqvAvSYeiBt)M7jKOrC4kq6xA0enJqYSgD(Oznde6uC)jdtHzeuApd1HpYPYpdmtTuNUEpyu9(OB6nwENcE1nLTu2RSyzRcDD(6D211gUuTFZlZf0eElTyo(BiUAlR(d)DgtI9xuevFkWZCqTN4gc2B29F)r8oLiU5CuLBL9j1xgXvZqtfjo2l(17JiA1LnPXCMD(IKvfSQA3e37dm2UsHLctp1nOn2Jsvi8HPZw7dx(h3))]] )


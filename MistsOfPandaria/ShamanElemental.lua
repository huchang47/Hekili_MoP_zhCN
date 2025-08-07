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
        id = 114051,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
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
        texture = 462650,
        
        handler = function()
            -- Unleash weapon imbue effects
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
        
        startsCombat = false,
        texture = 451169,
        
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
        
        talent = "call_of_the_elements",
        
        startsCombat = false,
        texture = 136792,
        
        handler = function()
            -- Reduces totem cooldowns
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
spec:RegisterStateTable( "enchant", setmetatable( {}, {
    __index = function( t, k )
        if k == "flametongue" then
            -- Check main hand weapon enchant
            local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID = GetWeaponEnchantInfo()
            return { weapon = hasMainHandEnchant and (mainHandEnchantID == 5 or state.buff.flametongue.up) }
        elseif k == "frostbrand" then
            local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID = GetWeaponEnchantInfo()
            return { weapon = hasMainHandEnchant and (mainHandEnchantID == 2 or state.buff.frostbrand.up) }
        elseif k == "windfury" then
            local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID = GetWeaponEnchantInfo()
            return { weapon = hasMainHandEnchant and (mainHandEnchantID == 283 or state.buff.windfury.up) }
        elseif k == "rockbiter" then
            local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID = GetWeaponEnchantInfo()
            return { weapon = hasMainHandEnchant and (mainHandEnchantID == 1 or state.buff.rockbiter.up) }
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

spec:RegisterPack( "Elemental", 20250807, [[Hekili:9IvBlYTnq4FlHchxiPU7D3EVK0Ch0uc0eiHqDk9dL4vAT1URyLTCLKVThCOF7DK87YsEVqkLqo8Aj9mspZmpZyLCwYxsIZWksYNoFX5xU4Mf3eTyX5lp)vjXQhkjjXL4094TWdf4C4VVJrYjfkmZmYdmooZGGKxjsHrtIxxrzQ3xKS2pS3aZTKKcV(QZtI3rZYi1ZLittI)YoQuJm)hRrngwJ4BGFNQO8cnIrLky4nCHg9BK9ugnc2ic(gkdm)pOrX7W54IxRrDBun6h1OpY)SgDz0YOB0OFNRWw0(am)3ILKmWga2)j)Wocg(X2kAgyxCb8mUsTdGHM2GrPGYfufLi1FWcWNfKuE(ASYmgPelAWUEhlJkBh)f3(tm62DQcAX2vYDucl7L0n3(S1vB2e5osuvPFi2Wa3GIxSTIS6abxYlSGqks3HlurdgoQEy)WijyHXAkUIKBrWmR7j1ViA0W(rOK)uoNR5mvdr9rmfizrh53SqZMPKcu6bmBprixTvGtjMTuo)ERlmkdC64IuYDlgUQumJTQ(NRmHfV0eGEBkNZY4hkKhFQyU1mnhCsbjh8Q3D7fhFLs4OXaUcl2sApE)ANHTbP9et3oQJ0mw161xZ48mwLubU7hFSgUifn34gwLrjV52Ll8dKDLR2ujEOdmSmLuKz4jlA23rAtcwLJLkI4HrXvJaeOEIypCW(pcWnubqQDt3nqZ)IGWo1Uzw1jt5O7U9QaC0K9Q)PjvCrodl31BTjoh)R0qnsLamG8aDJQGiLbMyht2eSeBdG0OMiOPzfrJcXAZ7bXbE6ElFaksgN1Jpki5qIL8ndIBNS4QcgXCaByePbbGxm5wndrQdMIif41mqqmium894vRReqQqlrzFLScMWiMYDLHKCcVIV7Obxa79dguA9qr9NPOg28UzazmdKXBeDR9nrn(Lto1xkuRfxjia6pFMtE3zEnezQg4VCg54omxF)XO7Uqm)1LaL409alpd)4t8)x4VBquo60lErBWVCanakYFlkh1tphVnh3plx58LNeyDdtkD2aJZ1gJiKODYP(s)MCoghOmfL5sEQrWXJecIa(OR9c3FxH37TU3s)7Fco3Ffb3PdnGqnfjB2mjX3dLuGX7Ab86K4dyHzmzBREnDUv3ZxovAIL0izvzjxOAAZBlSdfM(VuG8XEiGjsJ0O3RQxKTRdisjZ0fNANPnmY9gT(2o1GNOfPSkOdtyik0nN41qqPPPW)6pKedsKC5xFPgDyhnD3WzJlEO3QAub3a()uYOPufRh3mZtgJt6n6pdTukAnZxQHqJo7RnDv2)QZhy5dugBWjQbsv7uTSH9vfv5q9AJHLmq)r)H3NBimZlU0PxzyWKyttSCrsCCE1gbDFsSDiBJ7dtEHx8j7he0iQK8wyPwWsIhKtu3TUGwwpsOAzjXWCGYUuCs8ZGHRZy0OhF0CgTznA0BUvJUirbXio2TFTZwOQFd6QZza9IGGon3RhP(8wdgldIXZQP67j9lDunoZQV84RwJoPL8gwjtJUd4MRw0dU3YHgJCvqJmtjoaFnAa6952giVoiKbk4zpfNQrE0jSE8XL(0ONhIVV5ybcbQaoGNgpbdOVYaAWiLbMdM7zlosuJx52g3LR3QoHXG6zd3cJRroEdOm5xBWvSzZh98nto5LJ)ERHhJjFyvtSGN0WwZ5(Dq1siRQVtGUwDNpNBCbNAc7INOjGsm(sgFsRDSgNLG7(y15OyxhTRU33Wnn89CndbUHbhTKq3IW8ARWcdFZboI)JU0H590DAB(UoHzulxomhP(BLDsoV8BilYeZmxfnpTz64INRRv)vcMLT9LaS0kC6PuYG2A7iBpA1JPNWfRCTTTWBRO98LNhjwpSpGzRVf2Gp9AVHlSDm0NrJ(6GA0Hl651Z5GJTX65RGnT4O7jh62Es9Qjnw7eN3l)ot0EB20O4BN7SAYwD0vGyJm81NIH7x6T6XCN8A8cEPs978(R6AErNVht0D5xZNe5jn1RkY)Rn(1nl3JOJ2q4O7j(6bs0JVCSUW7oLOPxbMJzF1tr4Q9Fj)l]] )


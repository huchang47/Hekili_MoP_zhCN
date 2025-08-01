-- ShamanElemental.lua
-- January 2025 - MoP Structure based on Retail

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local strformat = string.format

local function InitializeSpec()
    if not Hekili or not Hekili.NewSpecialization then return end
    
    local spec = Hekili:NewSpecialization( 262 )

-- Enhanced Mana resource system for Elemental Shaman
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Water Shield mana restoration (Elemental gets better benefit than Enhancement)
    water_shield = {
        aura = "water_shield",
        last = function ()
            local app = state.buff.water_shield.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3
        end,
        interval = 3, -- Water Shield orb consumption
        value = function ()
            if not state.buff.water_shield.up then return 0 end
            -- Elemental gets 5% max mana per orb (higher than Enhancement)
            local base_restoration = state.mana.max * 0.05
            
            -- Glyph of Water Shield enhancement
            if state.glyph.water_shield.enabled then
                base_restoration = base_restoration * 1.2 -- 20% bonus
            end
            
            return base_restoration
        end,
    },
    
    -- Thunderstorm mana restoration (Elemental signature ability)
    thunderstorm_regen = {
        last = function ()
            return state.last_cast_time.thunderstorm or 0
        end,
        interval = 45, -- Thunderstorm cooldown
        value = function()
            -- Thunderstorm restores 8% mana in MoP for Elemental
            return (state.last_ability and state.last_ability == "thunderstorm") and state.mana.max * 0.08 or 0
        end,
    },
    
    -- Elemental Focus mana efficiency (when clearcasting)
    elemental_focus = {
        aura = "clearcasting",
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Clearcasting makes next spell cost no mana (effective restoration)
            return state.buff.clearcasting.up and state.mana.max * 0.06 or 0 -- Avg spell cost
        end,
    },
    
    -- Telluric Currents mana return from Lightning Bolt on low health targets
    telluric_currents = {
        last = function ()
            return state.last_cast_time.lightning_bolt or 0
        end,
        interval = 1,
        value = function()
            if state.talent.telluric_currents.enabled and (state.last_ability and state.last_ability == "lightning_bolt") and state.target.health.pct < 25 then
                -- Telluric Currents returns 40% of Lightning Bolt cost as mana
                return state.mana.max * 0.024 -- 6% spell cost * 40% return
            end
            return 0
        end,
    },
}, {
    -- Enhanced base mana regeneration for Elemental
    base_regen = function ()
        local base = state.mana.max * 0.02 -- 2% max mana per 5 seconds base
        local spirit_bonus = (state.stat.spirit or 0) * 0.5 -- Spirit contribution
        local meditation_bonus = 1.0
        
        -- Meditation allows 50% regen while casting
        if state.talent.meditation.enabled and state.casting then
            meditation_bonus = 0.5
        end
        
        -- Mana Spring Totem bonus (if active)
        if state.buff.mana_spring_totem.up then
            base = base * 1.25 -- 25% bonus
        end
        
        return (base + spirit_bonus) * meditation_bonus / 5 -- Convert to per-second
    end,
    
    -- Unrelenting Storm mana bonus from critical strikes
    unrelenting_storm = function ()
        return state.talent.unrelenting_storm.enabled and 1 or 0 -- Random mana bonus from crits
    end,
} )

-- Talents (MoP Elemental Shaman talents)
spec:RegisterTalents( {
    -- Tier 15
    nature_guardian = { 1, 1, 30884 },
    stone_bulwark_totem = { 1, 2, 108270 },
    astral_shift = { 1, 3, 108271 },
    
    -- Tier 30
    frozen_power = { 2, 1, 63374 },
    earthgrab_totem = { 2, 2, 51485 },
    windwalk_totem = { 2, 3, 108273 },
    
    -- Tier 45  
    call_of_the_elements = { 3, 1, 108285 },
    totemic_restoration = { 3, 2, 108284 },
    totemic_projection = { 3, 3, 108287 },
    
    -- Tier 60
    lashing_lava = { 4, 1, 108291 },
    conductivity = { 4, 2, 108282 },
    unleashed_fury = { 4, 3, 117012 },
    
    -- Tier 75
    unleash_life = { 5, 1, 73685 },
    ancestral_swiftness = { 5, 2, 16188 },
    echo_of_the_elements = { 5, 3, 108283 },
    
    -- Tier 90
    unleashed_fury = { 6, 1, 117012 },
    primal_elementalist = { 6, 2, 117013 },
    elemental_blast = { 6, 3, 117014 },
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
    
    -- Weapon Imbues
    flametongue = {
        id = 318038,
        duration = 3600,
        max_stack = 1,
    },
    
    frostbrand = {
        id = 318039,
        duration = 3600,
        max_stack = 1,
    },
    
    windfury = {
        id = 319773,
        duration = 3600,
        max_stack = 1,
    },
    
    rockbiter = {
        id = 318037,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Shields
    lightning_shield = {
        id = 324,
        duration = 600,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(324)
            
            if name then
                t.name = name
                t.count = count or 3
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    earth_shield = {
        id = 974,
        duration = 600,
        max_stack = 9,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(974)
            
            if name then
                t.name = name
                t.count = count or 9
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    water_shield = {
        id = 52127,
        duration = 600,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(52127)
            
            if name then
                t.name = name
                t.count = count or 3
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    -- Buffs
    lava_surge = {
        id = 77756,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(77756)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    clearcasting = {
        id = 16246,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(16246)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    -- Talent Buffs
    elemental_mastery = {
        id = 16166,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(16166)
            
            if name and state.talent.elemental_mastery.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    ancestral_swiftness = {
        id = 16188,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(16188)
            
            if name and state.talent.ancestral_swiftness.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    echo_of_the_elements = {
        id = 108283,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(108283)
            
            if name and state.talent.echo_of_the_elements.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    -- Debuffs on Target
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
                addBuff( "lava_surge" )
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
                addBuff( "lava_surge" )
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
                addBuff( "lava_surge" )
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
            interrupt()
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
} )

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

spec:RegisterPack( "Elemental", 20250108, [[Hekili:T3tAZTnor4FlCsKKvpbAb1fXssBACKOyN0fzSR9r1vvJ5sCnZGG)2VKf4vEvevHpNfDqjhhhV7rjjzgooSVF5L99oSN7V)1ND3N46)Ec33NX)M)M6)sC(5H3VF4VJp(6BZ(9J)(L9Op(6J)QJ)y4VpEjpWF8jpoF8Kx(aE8R)(jF(xyXJN4VFEVP)M6)C99AZ9LN4VN4r(VF(eo(1F8zH)AwqCJp(15(m)(y1YZpF(f3FET5U2Qf)T4qCrWPJGOsOl(5Vp)YJpIJNr4MFQX)(RNVx(VFpk)VFa9tpH)HFFd)xh)YJ)(VFa(VFC()yx6FqEI8Jd)rE(V)VE)V)8F(pE(ZJ)7bwxaVw(fpj)(VV4LgVE4zp5rxo5p9r8jOKZp(VpBE)MN)M9pqLKdE)V)6tFs9LMK3qUx4zxV)p(YJFa(XZ8JFEbp8apo(Rd8lp(0Jp5HrNzElpDr39b)JN4r4NX)5NJ)(3F)69Y)v3N9pOxoyUxgDx0F8B9V)KM(8N7)) ]])

-- Single Target
spec:RegisterPack( "Elemental ST", 20250108, [[Hekili:T3tAZTnor4FlCsKKvpbAb1fXssBACKOyN0fzSR9r1vvJ5sCnZGG)2VKf4vEvevHpNfDqjhhhV7rjjzgooSVF5L99oSN7V)1ND3N46)Ec33NX)M)M6)sC(5H3VF4VJp(6BZ(9J)(L9Op(6J)QJ)y4VpEjpWF8jpoF8Kx(aE8R)(jF(xyXJN4VFEVP)M6)C99AZ9LN4VN4r(VF(eo(1F8zH)AwqCJp(15(m)(y1YZpF(f3FET5U2Qf)T4qCrWPJGOsOl(5Vp)YJpIJNr4MFQX)(RNVx(VFpk)VFa9tpH)HFFd)xh)YJ)(VFa(VFC()yx6FqEI8Jd)rE(V)VE)V)8F(pE(ZJ)7bwxaVw(fpj)(VV4LgVE4zp5rxo5p9r8jOKZp(VpBE)MN)M9pqLKdE)V)6tFs9LMK3qUx4zxV)p(YJFa(XZ8JFEbp8apo(Rd8lp(0Jp5HrNzElpDr39b)JN4r4NX)5NJ)(3F)69Y)v3N9pOxoyUxgDx0F8B9V)KM(8N7)) ]])

-- AOE
spec:RegisterPack( "Elemental AOE", 20250108, [[Hekili:T3tAZTnor4FlCsKKvpbAb1fXssBACKOyN0fzSR9r1vvJ5sCnZGG)2VKf4vEvevHpNfDqjhhhV7rjjzgooSVF5L99oSN7V)1ND3N46)Ec33NX)M)M6)sC(5H3VF4VJp(6BZ(9J)(L9Op(6J)QJ)y4VpEjpWF8jpoF8Kx(aE8R)(jF(xyXJN4VFEVP)M6)C99AZ9LN4VN4r(VF(eo(1F8zH)AwqCJp(15(m)(y1YZpF(f3FET5U2Qf)T4qCrWPJGOsOl(5Vp)YJpIJNr4MFQX)(RNVx(VFpk)VFa9tpH)HFFd)xh)YJ)(VFa(VFC()yx6FqEI8Jd)rE(V)VE)V)8F(pE(ZJ)7bwxaVw(fpj)(VV4LgVE4zp5rxo5p9r8jOKZp(VpBE)MN)M9pqLKdE)V)6tFs9LMK3qUx4zxV)p(YJFa(XZ8JFEbp8apo(Rd8lp(0Jp5HrNzElpDr39b)JN4r4NX)5NJ)(3F)69Y)v3N9pOxoyUxgDx0F8B9V)KM(8N7)) ]])

end

-- Lazy initialization
if Hekili and Hekili.NewSpecialization then
    InitializeSpec()
else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" then
            InitializeSpec()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

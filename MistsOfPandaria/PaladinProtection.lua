-- PaladinProtection.lua
-- Updated Sep 28, 2025 - Modern Structure
-- Mists of Pandaria module for Paladin: Protection spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'PALADIN' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State
local spec = Hekili:NewSpecialization( 66 )
-- Local aliases for core state helpers and tables (improves static checks and readability).
local applyBuff, removeBuff, applyDebuff, removeDebuff = state.applyBuff, state.removeBuff, state.applyDebuff, state.removeDebuff
local removeDebuffStack = state.removeDebuffStack
local summonPet, dismissPet, setDistance, interrupt = state.summonPet, state.dismissPet, state.setDistance, state.interrupt
local buff, debuff, cooldown, active_dot, pet, totem, action =state.buff, state.debuff, state.cooldown, state.active_dot, state.pet, state.totem, state.action
local setCooldown = state.setCooldown
local addStack, removeStack = state.addStack, state.removeStack
local gain,rawGain, spend,rawSpend = state.gain, state.rawGain, state.spend, state.rawSpend
local talent = state.talent
local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local function UA_GetPlayerAuraBySpellID(spellID)
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitBuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitDebuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    return nil
end

-- MoP Seal detection system for Protection Paladin
local function GetActiveSeal()
    -- In MoP, check for active seal through stance/shapeshift detection
    local numForms = GetNumShapeshiftForms()
    for i = 1, numForms do
        local _, active, castable, spellID = GetShapeshiftFormInfo(i)
        if active then
            if spellID == 31801 then -- Seal of Truth
                return "seal_of_truth", spellID
            elseif spellID == 20164 then -- Seal of Justice
                return "seal_of_justice", spellID
            elseif spellID == 20165 then -- Seal of Insight
                return "seal_of_insight", spellID
            elseif spellID == 20154 then -- Seal of Righteousness
                return "seal_of_righteousness", spellID
            end
        end
    end
    return nil, nil
end

-- Planned seals within a single recommendation build (prevents duplicate seal spam in queue)
spec:RegisterStateTable( "planned_seal", setmetatable( {}, { __index = function() return false end } ) )

-- Clear planned seals at the beginning of each recommendation build
spec:RegisterHook( "reset_precast", function ()
    if state.planned_seal then
        for k in pairs( state.planned_seal ) do
            state.planned_seal[ k ] = nil
        end
    end
end )

-- Register Mana resource (0) so costs like spendType = "mana" work in emulation
spec:RegisterResource( 0 )

spec:RegisterResource( 9, { -- Holy Power with Protection-specific mechanics
    -- Grand Crusader reset proc (Protection signature)
    grand_crusader = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Grand Crusader doesn't generate Holy Power directly, but resets Avenger's Shield
            return 0 -- No direct HP generation, but tracks proc for ability resets
        end,
    },
    
    -- Bastion of Glory stack building (Protection mastery interaction)
    bastion_of_glory = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Tracks Bastion of Glory stacks for defensive benefit calculation
            local stacks = state.buff.bastion_of_glory.stack or 0
            return stacks * 0.1 -- Each stack provides defensive value
        end,
    },
    
    -- Shield of Vengeance proc (Protection talent)
    shield_of_vengeance = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            if state.talent.shield_of_vengeance.enabled and (state.last_ability and state.last_ability == "word_of_glory") then
                return 0 -- Shield of Vengeance procs from Holy Power consumption
            end
            return 0
        end,
    },
    
    -- Eternal Flame synergy (if talented)
    eternal_flame_protection = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            if state.talent.eternal_flame.enabled and (state.last_ability and state.last_ability == "word_of_glory") then
                return 0 -- Eternal Flame effectiveness scales with Holy Power spent
            end
            return 0
        end,
    },
}, {
    -- Base Holy Power mechanics for Protection
    max_holy_power = function ()
        return 3 -- Maximum 3 Holy Power in MoP
    end,
    
    -- Protection's enhanced Holy Power generation
    protection_generation = function ()
        return 1.0 -- Standard HP generation rate
    end,
    
    -- Divine Purpose proc effects for Protection
    divine_purpose_efficiency = function ()
        return state.talent.divine_purpose.enabled and (state.buff.divine_purpose.up and 1.5 or 1.0) or 1.0
    end,
} )

-- Tier sets
spec:RegisterGear( "tier14", 85345, 85346, 85347, 85348, 85349 ) -- T14 Protection Paladin Set
spec:RegisterGear( "tier15", 95268, 95270, 95266, 95269, 95267 ) -- T15 Protection Paladin Set

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Movement
    speed_of_light            = { 1, 1, 85499  }, -- +70% movement speed for 8 sec
    long_arm_of_the_law       = { 1, 2, 87172  }, -- Judgments increase movement speed by 45% for 3 sec
    pursuit_of_justice        = { 1, 3, 26023  }, -- +15% movement speed per Holy Power charge

    -- Tier 2 (Level 30) - Control
    fist_of_justice           = { 2, 1, 105593 }, -- Reduces Hammer of Justice cooldown by 50%
    repentance                = { 2, 2, 20066  }, -- Puts the enemy target in a state of meditation, incapacitating them for up to 1 min.
    blinding_light            = { 2, 3, 115750 }, -- Emits dazzling light in all directions, blinding enemies within 10 yards for 6 sec.

    -- Tier 3 (Level 45) - Healing/Defense
    selfless_healer           = { 3, 1, 85804  }, -- Your Holy power spending abilities reduce the cast time and mana cost of your next Flash of Light.
    eternal_flame             = { 3, 2, 114163 }, -- Consumes all Holy Power to place a protective Holy flame on a friendly target, which heals over 30 sec.
    sacred_shield             = { 3, 3, 20925  }, -- Places a Sacred Shield on a friendly target, absorbing damage every 6 sec for 30 sec.

    -- Tier 4 (Level 60) - Utility/CC
    hand_of_purity            = { 4, 1, 114039 }, -- Protects a party or raid member, reducing harmful periodic effects by 70% for 6 sec.
    unbreakable_spirit        = { 4, 2, 114154 }, -- Reduces the cooldown of your Divine Shield, Divine Protection, and Lay on Hands by 50%.
    clemency                  = { 4, 3, 105622 }, -- Increases the number of charges on your Hand spells by 1.

    -- Tier 5 (Level 75) - Holy Power
    divine_purpose            = { 5, 1, 86172  }, -- Your Holy Power abilities have a 15% chance to make your next Holy Power ability free and more effective.
    holy_avenger              = { 5, 2, 105809 }, -- Your Holy power generating abilities generate 3 charges of Holy Power for 18 sec.
    sanctified_wrath          = { 5, 3, 53376  }, -- Increases the duration of Avenging Wrath by 5 sec. While Avenging Wrath is active, your abilities generate 1 additional Holy Power.

    -- Tier 6 (Level 90) - Tanking
    holy_prism                = { 6, 1, 114165 }, -- Fires a beam of light that hits a target for Holy damage or healing.
    lights_hammer             = { 6, 2, 114158 }, -- Hurls a Light-infused hammer to the ground, dealing Holy damage to enemies and healing allies.
    execution_sentence        = { 6, 3, 114157 }  -- A hammer slowly falls from the sky, dealing Holy damage to an enemy or healing an ally.
} )

-- Protection-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [56414] = "alabaster_shield",   -- When your Avenger's Shield hits a target, the shield has a 100% chance to instantly bounce to 1 additional nearby target.
    [56420] = "focused_shield",     -- Your Avenger's Shield hits 1 fewer target, but deals 30% increased damage.
    [57937] = "divine_protection",  -- Divine Protection reduces magical damage taken by an additional 20%, but no longer reduces physical damage taken.
    [56416] = "word_of_glory",      -- Increases the effectiveness of your Word of Glory by 20% when used on yourself.
    [54935] = "battle_healer",      -- Your successful melee attacks heal a nearby injured friendly target within 30 yards for 10% of the damage done.
    [63219] = "final_wrath",        -- Avenging Wrath increases the damage of Hammer of Wrath by 50%.
    
    -- Minor Glyphs
    [57954] = "dazing_shield",      -- Your Avenger's Shield now also dazes targets for 10 sec.
    [57947] = "blessed_life",       -- You have a 50% chance to generate 1 charge of Holy Power when you take damage.
    [43367] = "righteous_retreat",  -- When you use Divine Shield, you also become immune to disarm effects, but the cooldown of Divine Shield is increased by 50%.
} )

-- Protection Paladin specific auras
spec:RegisterAuras( {
    -- Vengeance buff for Protection Paladin
    vengeance = {
        id = 132365,
        duration = 20,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 132365)
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
blessing_of_kings = {
    id = 20217,
    duration = 3600,
    max_stack = 1,
    texture = GetSpellTexture(20217),

generate = function( t )
    local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 20217 )
    if name then
        t.name = name
        t.count = count and count > 0 and count or 1
        t.expires = expirationTime
        t.applied = expirationTime - (duration or 3600)
        t.caster = caster or "any"
        return
    end
    t.count = 0
    t.expires = 0
    t.applied = 0
    t.caster = "nobody"
end,
},

blessing_of_might = {
    id = 19740,
    duration = 3600,
    max_stack = 1,
    texture = GetSpellTexture(19740),
},

    -- Alias aura that represents any blessing being active
    blessing = {
        alias = { "blessing_of_kings", "blessing_of_might" },
        aliasMode = "first",
        aliasType = "buff",
    },

-- Grand Crusader: Chance for free Avenger's Shield after Crusader Strike or Hammer of the Righteous
    grand_crusader = {
        id = 85416,
            texture = GetSpellTexture(85416),
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 85416 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Shield of the Righteous: Active mitigation ability
    shield_of_the_righteous = {
        id = 132403,
            texture = GetSpellTexture(132403),
        duration = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 132403 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Bastion of Glory: Increases healing of Word of Glory on self
    bastion_of_glory = {
        id = 114637,
            texture = GetSpellTexture(114637),
        duration = 20,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114637 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Divine Plea: Restore mana over time, but reduce healing done
    divine_plea = {
        id = 54428,
            texture = GetSpellTexture(54428),
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 54428 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Sacred Shield: Absorbs damage periodically
    sacred_shield = {
        id = 65148,
            texture = GetSpellTexture(65148),
        duration = 30,
        tick_time = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 65148 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Consecration tracker so APL keys like 'ticking'/'remains' resolve in emulator
    consecration = {
        id = 26573,
            texture = GetSpellTexture(26573),
        duration = 9,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            -- Emulate a ground effect that we just cast b  treat as up briefly for planning
            local now = state.query_time or GetTime()
            t.name = GetSpellInfo(26573) or "Consecration"
            t.count = 1
            t.expires = now + 9
            t.applied = now
            t.caster = "player"
        end
    },
    
    -- Holy Avenger: Holy Power abilities more effective
    holy_avenger = {
        id = 105809,
            texture = GetSpellTexture(105809),
        duration = 18,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105809 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Avenging Wrath: Increased damage and healing
    avenging_wrath = {
        id = 31884,
            texture = GetSpellTexture(31884),
        duration = function() 
            return state.talent.sanctified_wrath.enabled and 25 or 20
        end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 31884 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Divine Protection: Reduces damage taken
    divine_protection = {
        id = 498,
            texture = GetSpellTexture(498),
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 498 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Divine Shield: Complete immunity
    divine_shield = {
        id = 642,
            texture = GetSpellTexture(642),
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 642 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Forbearance: Cannot receive certain immunities again
    forbearance = {
        id = 25771,
            texture = GetSpellTexture(25771),
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "player", 25771 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Speed of Light: Increased movement speed
    speed_of_light = {
        id = 85499,
            texture = GetSpellTexture(85499),
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 85499 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Long Arm of the Law: Increased movement speed after Judgment
    long_arm_of_the_law = {
        id = 114158,
            texture = GetSpellTexture(114158),
        duration = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114158 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Pursuit of Justice: Increased movement speed from Holy Power
    pursuit_of_justice = {
        id = 26023,
            texture = GetSpellTexture(26023),
        duration = 3600,
        max_stack = 3,
        generate = function( t )
            t.count = state.holy_power.current
            t.expires = 3600
            t.applied = 0
            t.caster = "player"
        end
    },
    
    -- Divine Purpose: Free and enhanced Holy Power ability
    divine_purpose = {
        id = 86172,
            texture = GetSpellTexture(86172),
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 86172 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Eternal Flame: HoT from talent
    eternal_flame = {
        id = 114163,
            texture = GetSpellTexture(114163),
        duration = function() return 30 + (3 * state.holy_power.current) end,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114163, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Guardian of Ancient Kings: Major defensive cooldown
    guardian_of_ancient_kings = {
        id = 86659,
            texture = GetSpellTexture(86659),
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 86659 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Ardent Defender: Emergency defensive cooldown
    ardent_defender = {
        id = 31850,
            texture = GetSpellTexture(31850),
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 31850 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Hand of Freedom: Immunity to movement impairing effects
    hand_of_freedom = {
        id = 1044,
            texture = GetSpellTexture(1044),
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1044, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Hand of Protection: Immunity to physical damage
    hand_of_protection = {
        id = 1022,
            texture = GetSpellTexture(1022),
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1022, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Hand of Sacrifice: Redirects damage to Paladin
    hand_of_sacrifice = {
        id = 6940,
            texture = GetSpellTexture(6940),
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 6940, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Seals for Protection Paladin
    seal_of_truth = {
        id = 31801,
        duration = 1800,
        max_stack = 1,
        texture = GetSpellTexture(31801),
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_truth" then
                t.name = GetSpellInfo(31801) or "Seal of Truth"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    seal_of_righteousness = {
        id = 20154,
        duration = 1800,
        max_stack = 1,
        texture = GetSpellTexture(20154),
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_righteousness" then
                t.name = GetSpellInfo(20154) or "Seal of Righteousness"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    seal_of_insight = {
        id = 20165,
        duration = 1800,
        max_stack = 1,
        texture = GetSpellTexture(20165),
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_insight" then
                t.name = GetSpellInfo(20165) or "Seal of Insight"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    seal_of_justice = {
        id = 20164,
        duration = 1800,
        max_stack = 1,
        texture = GetSpellTexture(20164),
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_justice" then
                t.name = GetSpellInfo(20164) or "Seal of Justice"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },
} )

-- Protection Paladin abilities
spec:RegisterAbilities( {
    
    blessing_of_might_cast = {
        id = 19740,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
        texture = GetSpellTexture(19740),
        usable = function()
            return state.buff.blessing_of_might.down and state.buff.blessing_of_kings.down
        end,
        handler = function() end
    },

    blessing_of_kings_cast = {
        id = 20217,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
        texture = GetSpellTexture(20217),
        usable = function()
            return state.buff.blessing_of_kings.down and state.buff.blessing_of_might.down
        end,
        handler = function() end
    },

-- Core Protection abilities
    shield_of_the_righteous = {
        id = 53600,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        
        spend = function() 
            if state.buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = true,
            texture = GetSpellTexture(53600),
        
        handler = function()
            -- Shield of the Righteous mechanic
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            end
            
            applyBuff("shield_of_the_righteous")
            
            -- Divine Purpose talent proc chance
            if state.talent.divine_purpose.enabled and not state.buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    avengers_shield = {
        id = 31935,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.10,
        spendType = "mana",
        
        startsCombat = true,
            texture = GetSpellTexture(31935),
        
        usable = function()
            if state.buff.grand_crusader.up then return true end
            return not (cooldown.avengers_shield.remains > 0)
        end,
        
        handler = function()
            if state.buff.grand_crusader.up then
                removeBuff("grand_crusader")
            end
        end
    },
    
    guardian_of_ancient_kings = {
        id = 86659,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
            texture = GetSpellTexture(86659),
        
        handler = function()
            applyBuff("guardian_of_ancient_kings")
        end
    },
    
    ardent_defender = {
        id = 31850,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
            texture = GetSpellTexture(31850),
        
        handler = function()
            applyBuff("ardent_defender")
        end
    },
    
    word_of_glory = {
        id = 85673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if state.buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = false,
            texture = GetSpellTexture(85673),
        
        handler = function()
            -- Word of Glory mechanic - consumes all Holy Power and Bastion of Glory
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            else
                -- Modify healing based on Holy Power consumed
                -- Word of Glory's base healing amount is multiplied per Holy Power
                
                -- Bastion of Glory effect - increases healing of Word of Glory on self
                if state.buff.bastion_of_glory.up then
                    -- Increased healing based on Bastion of Glory stacks (30% per stack)
                    removeBuff("bastion_of_glory")
                end
            end
            
            -- Selfless Healer reductions for next Flash of Light if talented
            if state.talent.selfless_healer.enabled then
                applyBuff("selfless_healer", nil, 3)
            end
            
            -- Eternal Flame talent application instead of direct heal
            if state.talent.eternal_flame.enabled then
                applyBuff("eternal_flame")
            end
            
            -- Divine Purpose talent proc chance
            if state.talent.divine_purpose.enabled and not state.buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    hammer_of_the_righteous = {
        id = 53595,
        cast = 0,
        cooldown = 4.5,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
            texture = GetSpellTexture(53595),
        
        range = 8,
        
        handler = function()
            gain(1, "holy_power")
            
            -- Grand Crusader proc chance (12%)
            if math.random() < 0.12 then
                applyBuff("grand_crusader")
                setCooldown("avengers_shield", 0)
            end
            
            -- Bastion of Glory proc - 1 stack per target hit
            applyBuff("bastion_of_glory", nil, 1)
        end
    },
    
    holy_prism = {
        id = 114165,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.35,
        spendType = "mana",
        
        talent = "holy_prism",
        
        startsCombat = function() return not (state.settings and state.settings.holy_prism_heal) end,
            texture = GetSpellTexture(114165),
        
        handler = function()
            -- Holy Prism mechanic
            -- If cast on enemy, damages target and heals 5 nearby friendlies
            -- If cast on friendly, heals target and damages 5 nearby enemies
        end
    },
    
    lights_hammer = {
        id = 114158,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.38,
        spendType = "mana",
        
        talent = "lights_hammer",
        
        startsCombat = true,
            texture = GetSpellTexture(114158),
        
        handler = function()
            -- Light's Hammer mechanic - ground target AoE that heals allies and damages enemies
        end
    },
    
    execution_sentence = {
        id = 114157,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.38,
        spendType = "mana",
        
        talent = "execution_sentence",
        
        startsCombat = function() return not (state.settings and state.settings.execution_sentence_heal) end,
            texture = GetSpellTexture(114157),
        
        handler = function()
            -- Execution Sentence mechanic
            -- If cast on enemy, damages after 10 seconds
            -- If cast on friendly, heals after 10 seconds
        end
    },
    
    divine_plea = {
        id = 54428,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
            texture = GetSpellTexture(54428),
        
        handler = function()
            applyBuff("divine_plea")
        end
    },
    
    avenging_wrath = {
        id = 31884,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        --texture = 135875,  my test on getspelltexture below. better solution than using static id in case of typo
            texture = GetSpellTexture(31884),
        handler = function()
            applyBuff("avenging_wrath")
        end
    },
    
    holy_avenger = {
        id = 105809,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        talent = "holy_avenger",
        
        startsCombat = false,
            texture = GetSpellTexture(105809),
        
        handler = function()
            applyBuff("holy_avenger")
        end
    },
    
    divine_shield = {
        id = 642,
        cast = 0,
        cooldown = function()
            return state.talent.unbreakable_spirit.enabled and 150 or 300
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
            texture = GetSpellTexture(642),
        
        handler = function()
            applyBuff("divine_shield")
            applyDebuff("player", "forbearance")
        end
    },
    
    divine_protection = {
        id = 498,
        cast = 0,
        cooldown = function()
            return state.talent.unbreakable_spirit.enabled and 30 or 60
        end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
            texture = GetSpellTexture(498),
        
        handler = function()
            applyBuff("divine_protection")
        end
    },
    
    lay_on_hands = {
        id = 633,
        cast = 0,
        cooldown = function() 
            return state.talent.unbreakable_spirit.enabled and 360 or 600
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
            texture = GetSpellTexture(633),
        
        handler = function()
            -- Heals target for Paladin's maximum health
            -- Applies Forbearance
            applyDebuff("target", "forbearance")
        end
    },
    
    hand_of_freedom = {
        id = 1044,
        cast = 0,
        cooldown = function() 
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 25 }
            end
            return 25
        end,
        gcd = "spell",
        
        startsCombat = false,
            texture = GetSpellTexture(1044),
        
        handler = function()
            applyBuff("hand_of_freedom")
        end
    },
    
    hand_of_protection = {
        id = 1022,
        cast = 0,
        cooldown = function() 
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 300 }
            end
            return 300
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
            texture = GetSpellTexture(1022),
        
        handler = function()
            applyBuff("hand_of_protection")
            applyDebuff("player", "forbearance")
        end
    },
    
    hand_of_sacrifice = {
        id = 6940,
        cast = 0,
        cooldown = function() 
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 120 }
            end
            return 120
        end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
            texture = GetSpellTexture(6940),
        
        handler = function()
            applyBuff("hand_of_sacrifice", "target")
        end
    },
    
    hand_of_purity = {
        id = 114039,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        talent = "hand_of_purity",
        
        startsCombat = false,
            texture = GetSpellTexture(114039),
        
        handler = function()
            -- Applies Hand of Purity effect
        end
    },
    
    -- Shared Paladin abilities
    crusader_strike = {
        id = 35395,
        cast = 0,
        cooldown = 4.5,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
            texture = GetSpellTexture(35395),
        
        handler = function()
            gain(1, "holy_power")
            
            -- Grand Crusader proc chance (12%)
            if math.random() < 0.12 then
                applyBuff("grand_crusader")
                setCooldown("avengers_shield", 0)
            end
            
            -- Bastion of Glory proc
            applyBuff("bastion_of_glory", nil, 1)
        end
    },
    
    judgment = {
        id = 20271,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
            texture = GetSpellTexture(20271),
        
        handler = function()
            gain(1, "holy_power")
            
            -- Long Arm of the Law movement speed
            if state.talent.long_arm_of_the_law.enabled then
                applyBuff("long_arm_of_the_law")
            end
        end
    },
    
    cleanse = {
        id = 4987,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.14,
        spendType = "mana",
        
        startsCombat = false,
            texture = GetSpellTexture(4987),
        
        handler = function()
            -- Removes 1 Poison effect, 1 Disease effect, and 1 Magic effect from a friendly target
        end
    },
    
    hammer_of_justice = {
        id = 853,
        cast = 0,
        cooldown = function() 
            if state.talent.fist_of_justice.enabled then
                return 30
            end
            return 60
        end,
        gcd = "spell",
        
        startsCombat = true,
            texture = GetSpellTexture(853),
        
        handler = function()
            -- Stuns target for 6 seconds
        end
    },
    
    hammer_of_wrath = {
        id = 24275,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        usable = function()
            return target.health_pct < 20
        end,
        
        startsCombat = true,
            texture = GetSpellTexture(24275),
        
        handler = function()
            gain(1, "holy_power")
        end
    },
    
    consecration = {
        id = 26573,
        cast = 0,
        cooldown = 9,
        gcd = "spell",
        
        spend = 0.24,
        spendType = "mana",
        
        startsCombat = true,
            texture = GetSpellTexture(26573),
        
        handler = function()
            -- Creates consecrated ground that deals Holy damage over time
        end
    },

    holy_wrath = {
        -- MoP Holy Wrath (AoE burst; stuns Demons/Undead). 
        id = 119072,
            texture = GetSpellTexture(119072),
        cast = 0,
        cooldown = 15,
        gcd = "spell",

        spend = 0.12,
        spendType = "mana",

        startsCombat = true,
        range = 10,

        usable = function()
            -- Add any b donb t break CC / donb t use in single-targetb  guards here if you want.
            return true
        end,

        handler = function()
            -- No special states to track for Prot; damage/CC handled by the game.
        end
    },

    
    repentance = {
        id = 20066,
        cast = 1.5,
        cooldown = 15,
        gcd = "spell",
        
        talent = "repentance",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = false,
            texture = GetSpellTexture(20066),
        
        handler = function()
            -- Incapacitates target for up to 1 minute
        end
    },
    
    blinding_light = {
        id = 115750,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        talent = "blinding_light",
        
        spend = 0.18,
        spendType = "mana",
        
        startsCombat = true,
            texture = GetSpellTexture(115750),
        
        handler = function()
            -- Disorients all nearby enemies
        end
    },
    
    speed_of_light = {
        id = 85499,
        cast = 0,
        cooldown = 45,
        gcd = "off",
        
        talent = "speed_of_light",
        
        startsCombat = false,
            texture = GetSpellTexture(85499),
        
        handler = function()
            applyBuff("speed_of_light")
        end
    },
    
    sacred_shield = {
        id = 20925,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        talent = "sacred_shield",
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = false,
            texture = GetSpellTexture(20925),
        
        handler = function()
            applyBuff("sacred_shield")
        end
    },

    -- Seal abilities for Protection Paladin
    seal_of_truth = {
        id = 31801,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = GetSpellTexture(31801),

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_truth then return false, "seal_of_truth already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_righteousness")
            removeBuff("seal_of_justice")
            removeBuff("seal_of_insight")
            applyBuff("seal_of_truth")
            if state.planned_seal then state.planned_seal.seal_of_truth = true end
        end
    },

    seal_of_righteousness = {
        id = 20154,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = GetSpellTexture(20154),

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_righteousness then return false, "seal_of_righteousness already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_truth")
            removeBuff("seal_of_justice")
            removeBuff("seal_of_insight")
            applyBuff("seal_of_righteousness")
            if state.planned_seal then state.planned_seal.seal_of_righteousness = true end
        end
    },

    seal_of_insight = {
        id = 20165,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = GetSpellTexture(20165),

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_insight then return false, "seal_of_insight already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_truth")
            removeBuff("seal_of_righteousness")
            removeBuff("seal_of_justice")
            applyBuff("seal_of_insight")
            if state.planned_seal then state.planned_seal.seal_of_insight = true end
        end
    },

    seal_of_justice = {
        id = 20164,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = GetSpellTexture(20164),

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_justice then return false, "seal_of_justice already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_truth")
            removeBuff("seal_of_righteousness")
            removeBuff("seal_of_insight")
            applyBuff("seal_of_justice")
            if state.planned_seal then state.planned_seal.seal_of_justice = true end
        end
    },
} )

-- States and calculations for Protection specific mechanics
local function trackBastion()
    if buff.bastion_of_glory.stack > 0 then
        -- Each stack of Bastion of Glory increases Word of Glory healing by 10% when used on self
        local modifier = 1 + (0.1 * buff.bastion_of_glory.stack)
        -- Apply the healing modifier
    end
end

-- state.RegisterFunctions( {
--     ['trackBastion'] = function()
--         return trackBastion()
--     end
-- } )

-- local function checkGrandCrusader()
--     -- 12% chance to proc Grand Crusader on Crusader Strike or Hammer of the Righteous
--     return buff.grand_crusader.up
-- end

-- state.RegisterExpressions( {
--     ['grandCrusaderActive'] = function()
--         return checkGrandCrusader()
--     end
-- } )

-- Range
spec:RegisterRanges( "judgment", "avengers_shield", "hammer_of_justice", "rebuke", "crusader_strike", "hammer_of_the_righteous", "holy_wrath" )

spec:RegisterAbilities({
    rebuke = {
        id = 96231,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        toggle = "interrupts",
        startsCombat = true,

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function() interrupt() end,
    },
})

-- Vengeance state expressions
spec:RegisterStateExpr("vengeance_stacks", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_stacks()
end)

spec:RegisterStateExpr("vengeance_attack_power", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_attack_power()
end)

spec:RegisterStateExpr("vengeance_value", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_stacks()
end)

spec:RegisterStateExpr("high_vengeance", function()
    if not state.vengeance or not state.settings then
        return false
    end
    return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end)

spec:RegisterStateExpr("should_prioritize_damage", function()
    if not state.vengeance or not state.settings or not state.settings.vengeance_optimization or not state.settings.vengeance_stack_threshold then
        return false
    end
    return state.settings.vengeance_optimization and state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end)

-- Seal management state expressions
spec:RegisterStateExpr( "recommend_seals", function()
    return state.settings and state.settings.recommend_seals or false
end )

spec:RegisterStateExpr( "seal_of_righteousness_threshold", function()
    return ( state.settings and state.settings.seal_of_righteousness_threshold ) or 4
end )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent_potion",
    
    package = "i2i*Simc",
    
    holy_prism_heal = false,
    execution_sentence_heal = false,
} )

-- Vengeance system variables and settings (Lua-based calculations)
spec:RegisterVariable( "vengeance_stacks", function()
    return state.vengeance:get_stacks()
end )

spec:RegisterVariable( "vengeance_attack_power", function()
    return state.vengeance:get_attack_power()
end )

spec:RegisterVariable( "high_vengeance", function()
    return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end )

spec:RegisterVariable( "vengeance_active", function()
    return state.vengeance:is_active()
end )

-- Vengeance-based ability conditions (using RegisterStateExpr instead of RegisterVariable)

spec:RegisterSetting( "vengeance_optimization", true, {
    name = strformat( "启用%s优化", Hekili:GetSpellLinkWithTexture( 132365 ) ),
    desc = "启用基于复仇层数的伤害优化轮换。当复仇层数较高时，优先使用伤害技能。",
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "vengeance_stack_threshold", 5, {
    name = "复仇层数阈值",
    desc = "当复仇层数达到此阈值时启用伤害优化轮换。建议设置为5-8层。",
    type = "range",
    min = 1,
    max = 10,
    step = 1,
    width = "full",
} )

-- Seal management settings
spec:RegisterSetting("recommend_seals", true, {
    name = "推荐圣印",
    desc = "启用自动圣印推荐系统。根据敌人数量自动推荐合适的圣印。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting("seal_of_righteousness_threshold", 4, {
    name = "正义圣印阈值",
    desc = "当敌人数量达到此值时推荐正义圣印，否则推荐真理圣印。" ..
        "对于防护圣骑士，通常建议设置为3-4个敌人。",
    type = "range", min = 1, max = 6, step = 1,
    width = "full"
} )

-- Register default pack for MoP Protection Paladin
spec:RegisterPack( "防骑Simc", 20250916, [[Hekili:fJ16UTTnu4NLIbeK0146lrzTdXbyRnTiDizfvfO)tI0s02SrwuGKkPbWGype7jCpj7qkllsQlUTBd7pX2IhEoF87CHFkrtI(yuykwsIUD64PbJF54Zhnz2zZMeefkFSGefwGtUdVc(soEd833ZzssIKYY1l9ygdNQDHGvYtGLdV(MxPqbN9ItFru4IsAM868OfTdX0GZcMgfIlLRz8OWFBng83AAAkPYCIijk82F)Jx9ZkuibNjuiWK0mIc9iekbjB5if66CbD1APcrH1tjlXLzWpwY4kubGtaHC2sAgGRFqHUH9EfQb(W3Xz4uk8L)6p(tfsdbDSkKGJpxUwH0OvHuVd27TWU(NGe17mU59CscBZcm8BSbeIrf1p6hN)8fzeHGMVkMTm(o4trCcw0JTFUmD1gsETNNp38XR3f56hz(YBj5eonrHKCA(De5UdaeG9UgCyPGetLKnINrxoFr5YLJW3tYxPHZdCSC9OYITBL0nKlMmENJ)aoHQjelVSiJXsJxwYF05PeGN435frmpbNtILmoV5GCd(ZAs7vVwOPElJDaJ9kRzzpgBwMW1yxIZa3nY(XJi5yGCt3fJxX4etwIazT7johGu69uaufn1jwlUQeZtP4CDccNNqH4uLO2ZzornL9q(rMhlwtjzP6TjxtI56sfcRuyzrR4AwZLUs1XZa70QJ6)fHSATEpP7GLHhVss454mf6nzWSbfQuadkuOJV6nkeNuKHtaUf9j2BpXnx(aJBa2Qmg)rRugPYFXl1URoND0Xga5UgNSbtZfxmTcTlG2eW3795iHeMAD50Jo2qofShi8lNpB7wNZDjVGjiqD9jN89JUHI)8GDevit(H90JzAdq66iEp8BD5ozdHVIKN4010tgudj7JvqFhRTBP5W8cDttkEde74jbJhVrC581WCmOJEd(lpD8Oz1GeYZs6sk0MG(KPjdjEeMCSYbu1ZDSigX(nUBsHd30AkIdxJPYNjijZtySmDL1OA)xNI)AItVB(YX9V2fZhpkWEcjggebLRhlkYO1ZU)f2vo1gjCijcnFXcyw6Den4QsJXGh2qjIlM5mAcVbsSDMbD3guComT4fyB25q2ytc9yInxCJz44klg55azqZYGz4Dvi8TNo)(txhD8HojN2Rdo5YQdP3vkWPkUQrR1Dk7UPzxZrcx3yewzkQS4ocPqxTa3)FQUq3PorymFNJDkHTEUBFI7s1N66SYhn7xJGfLsjee7Or(cjP0masOnkpHyp2Q1In3g24ImDTPiUQG1A3opVRn2uIBtxVLZkZtn9pUJ(tGpijGLWV1H5jsAsLUGw0FbNk24FHU5H14ik8Ei9b7Pwz5KZJcFaZZ1xuffE9Mcg3WztvOkNRqzuHums9UOqZ3mYFRenbF9wJC4AV)RrHjCqseNI1Az7CwgA7wqxfvF73fk0KXGKwtGIc3RNQsnlNwu9Cqw2EzAAnAdiplschmpe54RDcWAcAJ8l9ENP37(L2RbZ2FGvNzBLRMmpldgcl2c3S8NdJPDY59sXdiCRXH2RQD3pneM8f614MwAF0(6fdN9Bj0sHos3pEaXwnw1TGRgq1ROln4E5)lGRz9HveAxb5itvdDOT4a58o1wzI9X7cFN6)mnDtBWy36WuOlRTc8wJ0j45q73SQE4ULqPqG01tAoCoAd9k2(wudByL(h2Cqwz4tlCQc6dZ6a7ptPjW(KtWWKJETU1ywT9gDMk0tviqRzdS6PQ0Ju)6voBozZoeL2NgYgwT1m(gixlPWhJ9kC2GPZ8WeC)haS(KPyL3aXuFRNGEDRPhy8HS5I56KuGb2(d7BaIR0vtpOvE1tyMhxnOsBtC7)(b)4A6ETUzOBX2gN6FlHBoOhTK9Nko0o7IT71uBs3)gi3ByhqzEhfPA)5FPX3BT3)o1v1JGpmNC6GU7KQC)osB6yhbmUI69uWmDITTnQ89nR)jKdjK36k3UeZB6uSgm7yuRzkh89nma9Gd86x(FdqABJhAA92hMy7pyRvS78LhAcRZYgpg4KDCFZc)uu)ZjEIwrEsLs39tLSEVd)rs2VRIX1(tl6wIQ3RI4uuzwls3dgU)FABxVFrJU9U(p)Ux)F7lGS5ctyefqR9TNFU5xr)9d]] )

spec:RegisterPack( "防骑(黑科研)", 20251105, [[Hekili:fN1)VTTXv8)wggGHDxJQKCKB2GLb2stZAgIrAvb6pmmkEM8K8vtrkCK0UgWGWRljwXiXZUndlijioFRlPzTXaDbEPojo)V0kkQ8t5FH9UJIK3rrk5eSHHeyBDF59(8(Y9EFE2kLu(uLA6ihSY8LlwUsPsfNPqXILE)khxPMZQTXk1AJ0wc1e(btul4RV6A)WRE0ot(QNTtWd2j42xDk2jw1WcPZKKTLlvdoLsTfCjgoFKPYcPeFfLAixNfTOk1(JXc5p5)174V9DuQTirxhhEjSTMsTEF)97(8R5FHobh8a)DpO7bB97XlrmiEQN16CXxV7lFS)9VsWL643z)UV4M)86FP3z8odtHfkvQqXkEQ(39w(BE7GBUBW2x0)RUCVV)ED)Xl1FJh5V5d97SrVRCxp1qH09Gl29Pxj4QpS)9(Z(x8FbN9v3BREx)jGvsTAqmaB7x6PgQz)nVbO8GVD)ExA9x)8l37A719PRhC497DZlfUEWpCyW3Clqg(DUy3d(NHFm46NpyRV1)X7h8SZ3RZ2WhH72FJNasdmV(h(1(BCqVB8eWSdEW6WUHgC46X(cMqEg8)n42kGi))Xx27w3S7lUT)E)ynslxdKdXY8KuudhaoGv1)b3d0dSBO88p8rbBTxVZVR)fEs)9zB177UB)xUf4L8VW30RZoDF23bl(XFmypV(5xVuXJxP80tFItuKRT(79V79x3U7H3O3M)n)TVsWM7dNbm(Up9r9)lVW)(7co4G784(VC7(35YX2qm6heGabDokwZQ1cihVZG0yi2Uq7OL(vvFVfmW22eZM1TAuFj47211q25C2p3vVzlSPZajxTk)BFaUbY1WjEj(pCASjMs08uDOeZLWoEQlIm1nafelAqGU246ehCl73L0O6cUnAuaTm2SjdoRqrolwWT9AR5qAHNTuXbc(tqAeKHTOuwWWYsVEdx6QsRIP2y6sP0iIQHmX1DSO0ed5SOp3I6PEYpW2tv6WsGrCNfTmwToFBmLHDhKbiUcIlxaBIaNR(aDCslk2tvh3aBAtwglza6KLjaOG0FhmFrXnB6IO6eKjlaHm1iGEcduX(mjTQBTI5e8LTxKGn0zxZzrCDkP5IoylxBHtmKE57j7U0z6JdB9qt9)fQmCVCT0bWI7hpLdMAIm8u)qdOyPNQRnu50tDYt9HEQuCBdKg4Bv)mRtpLCSCflkhynnSORkeYWHYREdM4IIztmjhqY7rXTqet7zlhI2fGNjGSJLzbBhOm(CLNysUZPT1ky6CvNET1KSBxABlBmKxp1uV9OBu6VALboQAwoFsS75Nw)QEQGtNPXLHpZs3XTW0MytnPxn5ebzqs0SQKNzT2AetOEb7rJoQfO76LQuSyl75QUigzaVOBH(I3PyHPJajeNDiniWZe1pJ)it1EvOYrtjqfv3rWXyhFXbvkK8ndvfrYxJioVRnwRQMLLblZQqK8JcXhf9K7LNRy(7nB1IfQiwHebfIG01jTBBqGAKnyXLFR1PKYn0OqqeE8v3gQLUeMbUWWyDqcTiy7zNwQ0eQfeyZmckFni5C0ULukw07mUZi6eY5iI(IZYlo2uWJ8EGZGyya1WZkr4npC(2hUMyYXzjhlxbm1CHgzQwkGvvp8H2q9ug0PzWJdnk7HrTWJQ62EjmUnlBbB04ySeDP8eB(XhiyPuyH1LFNiVvKvhfv(u(9ziybxhhqjIAd)fynxEbiB2Hm1WILTgAZKUHjIWGLBAxpmHv42sRN1ftsXfDxNMA5AQZF)ix6xd(gwJYPRXuZVWHOfYlyi3FBkXUv6g68fJWHsTLHWhChr62RGOMSgvaB6oB7V5U(79CGIhqjSmqxR3MRZyS15V3)opKtld4W3gRPm)mZOuZGy7yZhqiKff8JZxk6lok1I06Vd40ZHkCzOqk)5nfi5RutJcmOOeeBEawivC3WgNQt4Pk)03tD2QEQL474GGUaSqgdjGJJTgNZhKidPgygzl1QmICUyarZx(OHU4cpMa)YCrP0PYhTZb6VmFNbuzZa4Jb2tZCYc4nfGgUJH6ARb3MW4yml4RkMyIXSwdhHIsAhUoq(nMmmJj8iibZq0XtHijznGMBIsti5YUBf2DJ3kMPRO8GtntU28O4RY8KdAw3wZjmv5evsuN4LyA59hLDKM2BIygIjOi(sR)zkY00jgDmCisPCtzSettovo8HZYHmJq(qU8wzy(x))pmFuivNzWwW2snaaZIGNcJjTktwRCvn5auLjZA(dTYjqpBgUq1GOtbslHuAyvIPdF3Mn5up1P4)pN4PuI7BYCgjUljE8CNvP3EN1ODcHg7ysnhgpLZfpVHUs2EzZ1p86j899uFhpvGZVqtIStTtfco6tWWTS8RWpgU8jo7H6cKa5iQDPXyUdWWXu6A8apeay5rxuiUbKAFtTGCfl)ftXXDgwQdqwLd7k56khIhbKNKa7ueKt5Rg5epC9MFdRSyeiO4Cg6Hl009Ne9QCge6abcWXId9bIMJaXX02IiztUAs3CsouNZOd5hXh3nZkOM7rfJTPBijzwJAqSmElWOdMUBWBBk()DsFJ6lmEFYXgP4MkmfBGtRCjr(wPMHlfPRYLfpBYqDPp2rOCvgZTjqpiRz34pif4QjDOHkDn2Xl5anDnSH7GL70Ejaz4ZKcndnSjx35xiAuZkMOwPT5sCgPOJ8GKPdrJQYrUJhkf557PWEOul(xKE08tJ4r45y)A7J)LbREoKbsNyoOj4FagIaIA42ofGM9SooSbrztUnpCLFdBl(Wp8znGxZRA5szHu40FeqchCiqJBBoP8Wrv41Gzeif(Jfio4rw)bcIMemJ(JI(WO)P8Fc]] )
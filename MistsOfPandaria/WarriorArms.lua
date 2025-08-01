-- WarriorArms.lua
-- Updated May 30, 2025 - Enhanced Structure from Hunter Survival
-- Mists of Pandaria module for Warrior: Arms spec


    local _, playerClass = UnitClass('player')
    if playerClass ~= 'WARRIOR' then return end

    local addon, ns = ...
    local Hekili = _G[ addon ]
    
    if not Hekili then return end
    
    local class, state = Hekili.Class, Hekili.State

    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local strformat = string.format

    local spec = Hekili:NewSpecialization( 71 )

-- Combat Log Event Tracking System (following Hunter Survival structure)
local combatLogFrame = CreateFrame("Frame")
local combatLogEvents = {}

local function RegisterCombatLogEvent(event, handler)
    if not combatLogEvents[event] then
        combatLogEvents[event] = {}
    end
    table.insert(combatLogEvents[event], handler)
end

combatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            local handlers = combatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Colossus Smash debuff tracking
RegisterCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 86346 then -- Colossus Smash
        -- Track Colossus Smash debuff for optimal damage window
    elseif spellID == 85288 then -- Raging Blow (berserker stance proc)
        -- Track Raging Blow availability
    elseif spellID == 12292 then -- Bloodbath
        -- Track Bloodbath DoT application
    end
end)

-- Overpower proc tracking
RegisterCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 60503 then -- Taste for Blood (Overpower proc)
        -- Track Overpower proc availability
    elseif spellID == 46916 then -- Slam! proc
        -- Track Slam instant cast proc
    end
end)

-- Critical strike tracking for Deep Wounds
RegisterCombatLogEvent("SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical)
    if critical and (spellID == 12294 or spellID == 1464 or spellID == 78 or spellID == 845) then -- Mortal Strike, Slam, Heroic Strike, Cleave
        -- Apply Deep Wounds DoT on critical strikes
    end
end)

-- Target death tracking for DoT effects
RegisterCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    -- Handle target death for DoT effect optimization (Deep Wounds, Rend)
end)


spec:RegisterResource( 1, {
    -- MoP Stance-based rage generation with improved mechanics
    battle_stance_regen = {
        aura = "battle_stance",
        last = function ()
            local app = state.buff.battle_stance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Battle Stance: Enhanced rage from auto-attacking, no rage from taking damage
            if not state.buff.battle_stance.up or not state.combat then return 0 end
            
            local weapon_speed = state.main_hand.speed or 2.6
            local base_rage = (3.5 / weapon_speed) * 2.5 -- Weapon speed formula
            
            -- Weapon specialization bonus
            local spec_bonus = 1.0
            if state.main_hand.type == "sword" and state.talent.sword_specialization.enabled then
                spec_bonus = spec_bonus + 0.05 -- 5% more rage from swords
            elseif state.main_hand.type == "mace" and state.talent.mace_specialization.enabled then
                spec_bonus = spec_bonus + 0.05 -- 5% more rage from maces
            elseif state.main_hand.type == "axe" and state.talent.axe_specialization.enabled then
                spec_bonus = spec_bonus + 0.05 -- 5% more rage from axes
            end
            
            return base_rage * spec_bonus
        end,
    },
    
    berserker_stance_regen = {
        aura = "berserker_stance",
        last = function ()
            local app = state.buff.berserker_stance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Berserker Stance: Reduced rage from auto-attacking but gets rage from taking damage
            if not state.buff.berserker_stance.up or not state.combat then return 0 end
            
            local weapon_speed = state.main_hand.speed or 2.6
            local auto_rage = (3.5 / weapon_speed) * 1.5 -- 60% of Battle Stance auto rage
            
            -- Damage taken rage (simulated - in real game this would be event-driven)
            local damage_rage = state.incoming_damage_rate and (state.incoming_damage_rate * 0.1) or 2
            
            return auto_rage + damage_rage
        end,
    },
    
    defensive_stance_regen = {
        aura = "defensive_stance",
        last = function ()
            local app = state.buff.defensive_stance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3
        end,
        interval = 3,
        value = function()
            -- Defensive Stance: Minimal rage generation, only from taking damage
            if not state.buff.defensive_stance.up or not state.combat then return 0 end
            
            -- Damage taken rage (reduced compared to Berserker)
            local damage_rage = state.incoming_damage_rate and (state.incoming_damage_rate * 0.05) or 1
            
            return damage_rage
        end,
    },
    
    -- Mortal Strike rage generation (MoP: generates 10 rage instead of costing rage)
    mortal_strike_regen = {
        last = function ()
            return state.last_cast_time.mortal_strike or 0
        end,
        interval = 6, -- Mortal Strike cooldown
        value = function()
            return (state.last_ability and state.last_ability == "mortal_strike") and 10 or 0
        end,
    },
    
    -- Berserker Rage rage generation (improved)
    berserker_rage = {
        aura = "berserker_rage",
        last = function ()
            local app = state.buff.berserker_rage.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.berserker_rage.up and 5 or 0 -- 5 rage per second during Berserker Rage
        end,
    },
    
    -- Deadly Calm rage efficiency (effectively rage generation)
    deadly_calm = {
        aura = "deadly_calm",
        last = function ()
            local app = state.buff.deadly_calm.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Abilities cost no rage during Deadly Calm (effective rage generation)
            return state.buff.deadly_calm.up and 15 or 0
        end,
    },
    
    -- Charge rage generation (MoP: Juggernaut talent gives 15 rage per charge)
    charge_rage = {
        last = function ()
            return state.last_cast_time.charge or 0
        end,
        interval = 20, -- Charge cooldown
        value = function()
            return (state.last_ability and state.last_ability == "charge") and state.talent.juggernaut.enabled and 15 or 0
        end,
    },
    
    -- Victory Rush/Impending Victory rage generation
    victory_rush_rage = {
        last = function ()
            return state.last_cast_time.victory_rush or state.last_cast_time.impending_victory or 0
        end,
        interval = 1,
        value = function()
            local last_victory = (state.last_ability and state.last_ability == "victory_rush") or (state.last_ability and state.last_ability == "impending_victory")
            return last_victory and 5 or 0 -- 5 rage from Victory Rush abilities
        end,
    },
} )

-- Tier sets
spec:RegisterGear( 13, 1, { -- Tier 14 (Heart of Fear)
    { 85316, head = 85316, shoulder = 85319, chest = 85317, hands = 85318, legs = 85320 }, -- LFR
    { 85329, head = 85329, shoulder = 85332, chest = 85330, hands = 85331, legs = 85333 }, -- Normal
    { 86590, head = 86590, shoulder = 86593, chest = 86591, hands = 86592, legs = 86594 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_arms", {
    id = 105771,
    duration = 30,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_arms", {
    id = 105785,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterGear( 14, 1, { -- Tier 15 (Throne of Thunder)
    { 95298, head = 95298, shoulder = 95301, chest = 95299, hands = 95300, legs = 95302 }, -- LFR
    { 95705, head = 95705, shoulder = 95708, chest = 95706, hands = 95707, legs = 95709 }, -- Normal
    { 96101, head = 96101, shoulder = 96104, chest = 96102, hands = 96103, legs = 96105 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_arms", {
    id = 138165,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_arms", {
    id = 138173,
    duration = 12,
    max_stack = 1,
} )

spec:RegisterGear( 15, 1, { -- Tier 16 (Siege of Orgrimmar)
    { 99691, head = 99691, shoulder = 99694, chest = 99692, hands = 99693, legs = 99695 }, -- LFR
    { 98342, head = 98342, shoulder = 98345, chest = 98343, hands = 98344, legs = 98346 }, -- Normal
    { 99236, head = 99236, shoulder = 99239, chest = 99237, hands = 99238, legs = 99240 }, -- Heroic
    { 99926, head = 99926, shoulder = 99929, chest = 99927, hands = 99928, legs = 99930 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_arms", {
    id = 144438,
    duration = 30,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_arms", {
    id = 144440,
    duration = 15,
    max_stack = 5,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Oxheart, Fearbreaker of Garrosh
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148010,
    duration = 4,
    max_stack = 1,
} )

spec:RegisterGear( "thoks_tail_tip", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "sigil_of_rampage", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

spec:RegisterGear( "ticking_ebon_detonator", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

spec:RegisterGear( "gorehowl", 105531, {
    main_hand = 105531,
} )

-- Comprehensive Talent System (MoP Talent Trees)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    juggernaut                 = { 1, 1, 103826 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and generates 15 Rage.
    double_time                = { 1, 2, 103827 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and no longer generates Rage.
    warbringer                 = { 1, 3, 103828 }, -- Charge also roots the target for 4 sec, and Hamstring generates more Rage.

    -- Tier 2 (Level 30) - Healing/Survival
    second_wind                = { 2, 1, 29838 },  -- While below 35% health, you regenerate 3% of your maximum health every 1 sec.
    enraged_regeneration       = { 2, 2, 55694 },  -- Instantly heals you for 10% of your total health and regenerates an additional 10% over 5 sec.
    impending_victory          = { 2, 3, 103840 }, -- Instantly attack the target causing damage and healing you for 10% of your maximum health.

    -- Tier 3 (Level 45) - Utility
    staggering_shout           = { 3, 1, 107566 }, -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec.
    piercing_howl              = { 3, 2, 12323 },  -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec.
    disrupting_shout           = { 3, 3, 102060 }, -- Interrupts all enemy spell casts and prevents any spell in that school from being cast for 4 sec.

    -- Tier 4 (Level 60) - Survivability
    bladestorm                 = { 4, 1, 46924 },  -- Become a whirling maelstrom of steel, striking all nearby enemies for weapon damage over 6 sec.
    shockwave                  = { 4, 2, 46968 },  -- Sends a wave through the ground, causing damage and stunning all enemies within 10 yards for 4 sec.
    dragon_roar                = { 4, 3, 118000 }, -- Roar with the fury of a dragon, dealing damage to all enemies within 8 yards.

    -- Tier 5 (Level 75) - Berserker Powers
    mass_spell_reflection      = { 5, 1, 114028 }, -- Reflects the next spell cast on you or your party members back at its caster.
    safeguard                  = { 5, 2, 114029 }, -- Intervene now removes all movement impairing effects and provides 30% damage reduction.
    vigilance                  = { 5, 3, 114030 }, -- Focus your protective instincts on a party member, reducing their damage taken by 30%.

    -- Tier 6 (Level 90) - Ultimate Abilities
    avatar                     = { 6, 1, 107574 }, -- Transform into a colossus for 24 sec, becoming immune to movement effects and increasing damage by 20%.
    bloodbath                  = { 6, 2, 12292 },  -- Your attacks trigger a bleeding DoT that lasts 1 min and stacks up to 3
} )


spec:RegisterGlyphs( {
    -- Major Glyphs (affecting DPS and mechanics)
    [58095] = "Glyph of Berserker Rage",      -- Berserker Rage increases movement speed by 50% for its duration.
    [58096] = "Glyph of Bloodthirst",         -- Your Bloodthirst ability heals you for an additional 1% of your maximum health.
    [58097] = "Glyph of Bloody Healing",      -- Increases the healing received from Bloodthirst by 40%.
    [58098] = "Glyph of Bull Rush",           -- Charge now moves you a greater distance and through enemies.
    [58099] = "Glyph of Cleaving",            -- Your Cleave ability affects 1 additional target.
    [58100] = "Glyph of Colossus Smash",      -- Your Colossus Smash generates 10 additional Rage when it critically strikes.
    [58101] = "Glyph of Demoralizing Shout",  -- Reduces the rage cost of Demoralizing Shout by 50%.
    [58102] = "Glyph of Die by the Sword",    -- Die by the Sword also reflects damage back to attackers.
    [58103] = "Glyph of Enraged Speed",       -- Enrage increases your movement speed by 30%.
    [58104] = "Glyph of Execute",             -- Your Execute hits up to 2 additional enemies for 50% damage.
    [58105] = "Glyph of Hamstring",           -- Your Hamstring ability also reduces the target's damage by 10%.
    [58106] = "Glyph of Heroic Strike",       -- Your Heroic Strike increases the damage of your next ability by 15%.
    [58107] = "Glyph of Hindering Strikes",   -- Your auto attacks have a chance to reduce enemy movement speed by 50%.
    [58108] = "Glyph of Intimidating Shout",  -- Reduces the cooldown on Intimidating Shout by 15 sec.
    [58109] = "Glyph of Long Charge",         -- Increases the range of your Charge ability by 5 yards.
    [58110] = "Glyph of Mortal Strike",       -- Your Mortal Strike ability spreads its healing absorption to 1 nearby enemy.
    [58111] = "Glyph of Overpower",           -- Overpower has a 25% chance to reset the cooldown on Mortal Strike.
    [58112] = "Glyph of Raging Blow",         -- Raging Blow has no cooldown, but the rage cost is increased by 100%.
    [58113] = "Glyph of Rallying Cry",        -- Rallying Cry grants an additional 10% maximum health.
    [58114] = "Glyph of Rend",                -- Your Rend ability affects all enemies within 5 yards of your target.
    [58115] = "Glyph of Revenge",             -- Revenge also increases your movement speed by 30% for 6 sec.
    [58116] = "Glyph of Shield Slam",         -- Shield Slam silences the target for 3 sec.
    [58117] = "Glyph of Shield Wall",         -- Shield Wall reflects 20% of damage back to attackers.
    [58118] = "Glyph of Slam",                -- Slam has a 25% chance to reset the cooldown on Overpower.
    [58119] = "Glyph of Spell Reflection",    -- Spell Reflection lasts 50% longer.
    [58120] = "Glyph of Sweeping Strikes",    -- Increases the duration of Sweeping Strikes by 4 sec.
    [58121] = "Glyph of Thunder Clap",        -- Thunder Clap also reduces attack speed by an additional 10%.
    [58122] = "Glyph of Victory Rush",        -- Victory Rush increases your movement speed by 50% for 6 sec.
    [58123] = "Glyph of Whirlwind",           -- Whirlwind generates 5 rage for each target hit.
    [58124] = "Glyph of Wind and Thunder",    -- Reduces the rage cost of Thunder Clap by 10.
    
    -- Minor Glyphs (convenience and visual)
    [58125] = "Glyph of Battle",              -- You appear to be in a battle stance even when you're not.
    [58126] = "Glyph of Berserker Stance",    -- You appear to be in berserker stance even when you're not.
    [58127] = "Glyph of Bloodcurdling Shout", -- Your shouts have enhanced visual and sound effects.
    [58128] = "Glyph of Burning Anger",       -- Your character glows with inner fire when enraged.
    [58129] = "Glyph of Defensive Stance",    -- You appear to be in defensive stance even when you're not.
    [58130] = "Glyph of Gushing Wound",       -- Your critical strikes cause more dramatic bleeding effects.    [58131] = "Glyph of the Savage Beast",    -- Your weapons appear to drip with blood.
    [58132] = "Glyph of Thunder Strike",      -- Your weapon attacks create lightning effects.
    [58133] = "Glyph of the Weaponmaster",    -- Your weapons appear to be of exceptional quality.
    [58134] = "Glyph of Intimidation",        -- Your character appears more menacing.
} )--]]

-- Arms Warrior specific auras
spec:RegisterAuras( {
    -- Core buffs/debuffs
    battle_shout = {
        id = 6673,
        duration = 3600,
        max_stack = 1,
    },
    commanding_shout = {
        id = 469,
        duration = 3600,
        max_stack = 1,
    },    colossus_smash = {
        id = 86346,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 86346 )
            
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
        end
    },
    mortal_strike_debuff = {
        id = 12294,
        duration = 10,
        max_stack = 1,
    },
    sudden_death = {
        id = 52437,
        duration = 10,
        max_stack = 1,
    },
    taste_for_blood = {
        id = 60503,
        duration = 10,
        max_stack = 3,
    },
    sweeping_strikes = {
        id = 12328,
        duration = 10,
        max_stack = 1,
    },    overpower = {
        id = 7384,
        duration = 5,  -- WoW Sims: 5 second window to use Overpower after dodge
        max_stack = 1,
    },
    deadly_calm = {
        id = 85730,
        duration = 10,
        max_stack = 1,
    },
    enrage = {
        id = 12880,
        duration = 8,
        max_stack = 1,
    },
    berserker_rage = {
        id = 18499,
        duration = function() return glyph.unending_rage.enabled and 8 or 6 end,
        max_stack = 1,
    },
    
    -- Talent-specific buffs/debuffs
    avatar = {
        id = 107574,
        duration = 24,
        max_stack = 1,
    },
    bladestorm = {
        id = 46924,
        duration = 6,
        max_stack = 1,
    },
    bloodbath = {
        id = 12292,
        duration = 12,
        max_stack = 1,
    },
    bloodbath_dot = {
        id = 113344,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
    },
    dragon_roar = {
        id = 118000,
        duration = 4,
        max_stack = 1,
    },
    second_wind = {
        id = 29838,
        duration = 3600,
        max_stack = 1,
    },
    vigilance = {
        id = 114030,
        duration = 12,
        max_stack = 1,
    },
    
    -- Defensives
    die_by_the_sword = {
        id = 118038,
        duration = function() return glyph.die_by_the_sword.enabled and 4 or 8 end,
        max_stack = 1,
    },
    shield_wall = {
        id = 871,
        duration = 12,
        max_stack = 1,
    },
    spell_reflection = {
        id = 23920,
        duration = function() return glyph.spell_reflection.enabled and 4 or 5 end,
        max_stack = 1,
    },
    mass_spell_reflection = {
        id = 114028,
        duration = 5,
        max_stack = 1,
    },
    enraged_regeneration = {
        id = 55694,
        duration = 5,
        tick_time = 1,
        max_stack = 1,
    },
    
    -- Crowd control / utility
    hamstring = {
        id = 1715,
        duration = 15,
        max_stack = 1,
    },
    piercing_howl = {
        id = 12323,
        duration = 15,
        max_stack = 1,
    },
    staggering_shout = {
        id = 107566,
        duration = 15,
        max_stack = 1,
    },
    shockwave = {
        id = 46968,
        duration = 4,
        max_stack = 1,
    },
    storm_bolt = {
        id = 107570,
        duration = 3,
        max_stack = 1,
    },
    war_banner = {
        id = 114207,
        duration = 15,
        max_stack = 1,
    },
    rallying_cry = {
        id = 97462,
        duration = 10,
        max_stack = 1,
    },
    demoralizing_shout = {
        id = 1160,
        duration = 10,
        max_stack = 1,
    },
    disrupting_shout = {
        id = 102060,
        duration = 4,
        max_stack = 1,
    },
    intimidating_shout = {
        id = 5246,
        duration = 8,
        max_stack = 1,
    },    charge_root = {
        id = 105771,
        duration = function() 
            if talent.warbringer.enabled then
                return 4
            elseif glyph.bull_rush.enabled then
                return 1
            end
            return 0
        end,
        max_stack = 1,
    },
      -- DoTs and debuffs
    rend = {
        id = 772,
        duration = 15,  -- WoW Sims: 5 ticks over 15 seconds
        tick_time = 3,  -- WoW Sims: 3 second intervals
        max_stack = 1,
    },
    -- Arms signature: Colossus Smash damage window
    colossus_smash_window = {
        id = 86346, -- Same spell ID, but this is the player buff for damage calculations
        duration = 6,
        max_stack = 1,
    },
} )

-- Advanced Aura System with Generate Functions (following Hunter Survival pattern)
spec:RegisterAuras( {
    -- Arms-specific Auras
    mortal_strike = {
        id = 12294,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 12294 )
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
        end
    },
    
    rend = {
        id = 94009,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 94009 )
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
        end
    },
    
    deep_wounds = {
        id = 115767,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115767 )
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
        end
    },
    
    -- Missing auras referenced in action lists
    mortal_wound = {
        id = 12294,
        duration = 10,
        max_stack = 1,
    },
    
    sudden_execute = {
        id = 52437,
        duration = 10,
        max_stack = 1,
    },
    
    charge = {
        id = 100,
        duration = 1,
        max_stack = 1,
    },
    
    fear = {
        id = 5246,
        duration = 8,
        max_stack = 1,
    },
    
    victory_rush = {
        id = 34428,
        duration = 0,
        max_stack = 1,
    },
    
    blood_pact = {
        id = 6307,
        duration = 3600,
        max_stack = 1,
    },
    
    expose_armor = {
        id = 8647,
        duration = 30,
        max_stack = 5,
    },
    
    horn_of_winter = {
        id = 57330,
        duration = 300,
        max_stack = 1,
    },
    
    sunder_armor = {
        id = 7386,
        duration = 30,
        max_stack = 5,
    },
    
    -- Casting buff for spell reflection
    casting = {
        duration = function () return haste end,
        max_stack = 1,
        generate = function ()
            -- This is handled by the game's casting system
            return nil
        end,
    },
    
    taste_for_blood = {
        id = 60503,
        duration = 9,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 60503 )
            
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
        end
    },
    
    slam_proc = {
        id = 46916,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 46916 )
            
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
        end
    },
    
    sudden_death = {
        id = 52437,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 52437 )
            
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
        end
    },
    
    bloodbath = {
        id = 113344,
        duration = 60,
        tick_time = 3,
        max_stack = 3,
        generate = function( t )
            local debuff = GetTargetDebuffByID(113344, "PLAYER")
            if debuff then
                t.name = debuff.name
                t.count = debuff.count
                t.expires = debuff.expires
                t.applied = debuff.applied
                t.caster = debuff.caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Shared Warrior Auras
    battle_stance = {
        id = 2457,
        duration = 3600,
        max_stack = 1
    },
    
    defensive_stance = {
        id = 71,
        duration = 3600,
        max_stack = 1
    },
    
    berserker_stance = {
        id = 2458,
        duration = 3600,
        max_stack = 1
    },
    
    berserker_rage = {
        id = 18499,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 18499 )
            
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
        end
    },
    
    deadly_calm = {
        id = 85730,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 85730 )
            
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
        end
    },
    
    avatar = {
        id = 107574,
        duration = 24,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 107574 )
            
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
        end
    },
    
    sweeping_strikes = {
        id = 12328,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12328 )
            
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
        end
    },
    
    recklessness = {
        id = 1719,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1719 )
            
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
        end
    },
    
    shield_wall = {
        id = 871,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 871 )
            
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
        end
    },
    
    die_by_the_sword = {
        id = 118038,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118038 )
            
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
        end
    },
    
    spell_reflection = {
        id = 23920,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 23920 )
            
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
        end
    },
    
    rallying_cry = {
        id = 97462,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 97462 )
            
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
        end
    },
    
    commanding_shout = {
        id = 469,
        duration = 300,
        max_stack = 1
    },
    
    battle_shout = {
        id = 6673,
        duration = 300,
        max_stack = 1
    },
    
} )

-- MoP Stance System - Abilities no longer require specific stances
spec:RegisterAbilities( {
    -- Core rotational abilities
    mortal_strike = {
        id = 12294,
        cast = 0,
        cooldown = 6,  -- MoP: 6 second cooldown
        gcd = "spell",
        
        spend = function()
            -- MoP: Mortal Strike generates 10 rage instead of costing rage
            return -10
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132355,
        
        handler = function()
            -- Apply 50% healing reduction debuff for 10 seconds
            applyDebuff( "target", "mortal_strike_debuff", 10 )
            
            -- MoP: Each cast gives 2 charges of Overpower
            if not buff.taste_for_blood.up then
                applyBuff( "taste_for_blood" )
                buff.taste_for_blood.stack = 2
            else
                addStack( "taste_for_blood", nil, 2 )
                if buff.taste_for_blood.stack > 3 then
                    buff.taste_for_blood.stack = 3
                end
            end
        end,
    },
      overpower = {
        id = 7384,
        cast = 0,
        cooldown = 0,
        gcd = function() return 1.0 end,  -- MoP: Reduced global cooldown
        
        spend = 10,  -- MoP: 10 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 132223,
        
        charges = function()
            -- MoP: Works off a charge system
            return buff.taste_for_blood.stack or 0
        end,
        
        usable = function()
            return buff.taste_for_blood.up, "requires taste for blood charges (from mortal strike)"
        end,
        
        handler = function()
            removeStack( "taste_for_blood", 1 )
            
            -- Glyph of Overpower: 25% chance to reset Mortal Strike cooldown
            if glyph.overpower.enabled and math.random() < 0.25 then
                setCooldown( "mortal_strike", 0 )
            end
        end,
    },
      colossus_smash = {
        id = 86346,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 20,  -- MoP: 20 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 464973,
        
        handler = function()
            -- Apply the signature Colossus Smash debuff (6 seconds, ignores armor)
            applyDebuff( "target", "colossus_smash", 6 )
            
            -- MoP: Colossus Smash provides a damage window
            if glyph.colossus_smash.enabled then
                applyBuff( "berserker_stance", 15 ) -- Glyph grants Berserker Stance benefits
            end
            
            -- Arms signature: Enhanced damage during Colossus Smash window
            applyBuff( "colossus_smash_window", 6 ) -- Player buff for damage calculations
        end,
    },    execute = {
        id = 5308,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.sudden_death.up then return 0 end
            -- MoP: Execute costs 30 rage base, consumes up to 70 extra rage for more damage
            return 30
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 135358,
        
        usable = function()
            return target.health_pct < 20 or buff.sudden_death.up, "requires target below 20% health or sudden_death buff"
        end,
        
        handler = function()
            if buff.sudden_death.up then
                removeBuff( "sudden_death" )
            else
                -- MoP: Consume extra rage for additional damage (up to 70 rage total)
                local current_rage = rage.current
                local extra_rage = math.min( current_rage, 70 )
                if extra_rage > 0 then
                    spend( extra_rage, "rage" )
                end
            end
            
            -- MoP: Execute grants Sudden Execute buff
            applyBuff( "sudden_execute" )
        end,
    },slam = {
        id = 1464,
        cast = 0,  -- MoP: Slam is now instant cast
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,  -- MoP: 25 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 132340,
        
        handler = function()
            -- MoP: Slam deals 275% weapon damage + 10% more during Colossus Smash
            -- Glyph of Slam: 25% chance to reset Overpower cooldown
            if glyph.slam.enabled and math.random() < 0.25 then
                if not buff.taste_for_blood.up then
                    applyBuff( "taste_for_blood" )
                    buff.taste_for_blood.stack = 1
                else
                    addStack( "taste_for_blood", nil, 1 )
                end
            end
            
            -- MoP: While Sweeping Strikes is active, 35% of Slam damage hits all enemies within 2 yards
            if buff.sweeping_strikes.up then
                -- This is handled by the game engine
            end
        end,
    },
      rend = {
        id = 772,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 10,  -- WoW Sims: 10 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 132155,
        
        handler = function()
            applyDebuff( "target", "rend" )
            
            -- Trigger Taste for Blood (Arms passive that builds stacks on Rend/auto crit)
            if not buff.taste_for_blood.up then
                applyBuff( "taste_for_blood" )
                buff.taste_for_blood.stack = 1
            elseif buff.taste_for_blood.stack < 3 then
                addStack( "taste_for_blood", nil, 1 )
            end
        end,
    },
    
    -- Defensive / utility
    battle_shout = {
        id = 6673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            -- MoP: Battle Shout generates rage when used
            return -10 
        end,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132333,
        
        handler = function()
            -- Apply Battle Shout buff (increases attack power)
            applyBuff( "battle_shout", 300 ) -- 5 minute duration in MoP
            
            -- MoP: Battle Shout generates rage
            gain( 10, "rage" )
            
            -- Glyph of Battle: Additional health bonus
            if glyph.battle.enabled then
                applyBuff( "battle_shout_health", 3600 ) -- 1 hour health bonus
            end
            
            -- Improved shouts from talents would affect party/raid here
            if talent.commanding_presence.enabled then
                -- Enhanced buff duration and effects
                buff.battle_shout.duration = 450 -- 7.5 minutes with talent
            end
        end,
    },
    
    commanding_shout = {
        id = 469,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            -- MoP: Commanding Shout also generates rage when used
            return -10
        end,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            -- Apply Commanding Shout buff (increases stamina)
            applyBuff( "commanding_shout", 300 ) -- 5 minute duration in MoP
            
            -- MoP: Commanding Shout generates rage
            gain( 10, "rage" )
            
            -- Enhanced effects with talents
            if talent.commanding_presence.enabled then
                buff.commanding_shout.duration = 450 -- 7.5 minutes with talent
            end
            
            -- Glyph of Rallying Cry synergy
            if glyph.rallying_cry.enabled then
                -- Commanding Shout provides additional health benefit
                applyBuff( "commanding_shout_health", 300 )
            end
        end,
    },
      sweeping_strikes = {
        id = 12328,
        cast = 0,
        cooldown = 10,  -- MoP: 10-second cooldown, can always maintain if you have rage
        gcd = "spell",
        
        spend = 20,  -- Rage cost to maintain
        spendType = "rage",
        
        startsCombat = false,
        texture = 132306,
        
        handler = function()
            applyBuff( "sweeping_strikes" )
            -- MoP: Sweeping Strikes now deals 50% damage to targets (down from 100%)
            -- MoP: While active, 35% of Slam damage hits all enemies within 2 yards
        end,
    },
    
    charge = {
        id = 100,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 20 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = 20,
        gcd = "off",
        
        spend = function()
            if talent.juggernaut.enabled then return -15 end
            return 0
        end,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = true,
        texture = 132337,
        
        handler = function()
            if talent.warbringer.enabled or glyph.bull_rush.enabled then
                applyDebuff( "target", "charge_root" )
            end
        end,
    },
    
    hamstring = {
        id = 1715,
        cast = 0,
        cooldown = 0,
        gcd = function() return glyph.hamstring.enabled and 0.5 or 1.5 end,
        
        spend = function() 
            if talent.warbringer.enabled then return 5 end
            return 10 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132316,
        
        handler = function()
            applyDebuff( "target", "hamstring" )
        end,
    },
      deadly_calm = {
        id = 85730,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 464593,
        
        handler = function()
            applyBuff( "deadly_calm" )
        end,
    },
    
    berserker_rage = {
        id = 18499,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 136009,
        
        handler = function()
            applyBuff( "berserker_rage" )
        end,
    },
    
    heroic_leap = {
        id = 6544,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 236171,
        
        handler = function()
            -- No specific effect, just the leap
        end,
    },
    
    rallying_cry = {
        id = 97462,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            applyBuff( "rallying_cry" )
        end,
    },
    
    die_by_the_sword = {
        id = 118038,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132336,
        
        handler = function()
            applyBuff( "die_by_the_sword" )
        end,
    },
    
    intervene = {
        id = 3411,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = false,
        texture = 132365,
        
        handler = function()
            if talent.safeguard.enabled then
                -- Apply damage reduction to the target (handled by the game)
            end
        end,
    },
    
    -- Talent abilities
    avatar = {
        id = 107574,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 613534,
        
        handler = function()
            applyBuff( "avatar" )
        end,
    },
    
    bloodbath = {
        id = 12292,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236304,
        
        handler = function()
            applyBuff( "bloodbath" )
        end,
    },
    
    bladestorm = {
        id = 46924,
        cast = 0,
        cooldown = function() return glyph.bladestorm.enabled and 75 or 90 end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236303,
        
        handler = function()
            applyBuff( "bladestorm" )
        end,
    },
    
    dragon_roar = {
        id = 118000,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 642418,
        
        handler = function()
            applyDebuff( "target", "dragon_roar" )
        end,
    },
    
    shockwave = {
        id = 46968,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = function() 
            if glyph.burning_anger.enabled then return 20 end
            return 0 
        end,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236312,
        
        handler = function()
            applyDebuff( "target", "shockwave" )
        end,
    },
    
    storm_bolt = {
        id = 107570,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 613535,
        
        handler = function()
            applyDebuff( "target", "storm_bolt" )
        end,
    },
    
    vigilance = {
        id = 114030,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236331,
        
        handler = function()
            applyBuff( "vigilance" )
        end,
    },
    
    impending_victory = {
        id = 103840,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 10,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589768,
        
        handler = function()
            local heal_amount = health.max * (glyph.bloody_healing.enabled and 0.2 or 0.1)
            gain( heal_amount, "health" )
        end,
    },
    
    staggering_shout = {
        id = 107566,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132346,
        
        handler = function()
            applyDebuff( "target", "staggering_shout" )
        end,
    },
    
    piercing_howl = {
        id = 12323,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132117,
        
        handler = function()
            applyDebuff( "target", "piercing_howl" )
        end,
    },
    
    disrupting_shout = {
        id = 102060,
        cast = 0,
        cooldown = function() 
            -- MoP: Shares cooldown with Pummel
            return cooldown.pummel.remains > 0 and cooldown.pummel.remains or 15
        end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "interrupts",
        
        startsCombat = true,
        texture = 613534,
        
        handler = function()
            applyDebuff( "target", "disrupting_shout" )
            setCooldown( "pummel", 15 )
        end,
    },
    
    pummel = {
        id = 6552,
        cast = 0,
        cooldown = function() 
            -- MoP: Shares cooldown with Disrupting Shout
            return cooldown.disrupting_shout.remains > 0 and cooldown.disrupting_shout.remains or 15
        end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "interrupts",
        
        startsCombat = true,
        texture = 132938,
        
        handler = function()
            interrupt()
            setCooldown( "disrupting_shout", 15 )
        end,
    },
    
    -- MoP-specific abilities
    thunder_clap = {
        id = 6343,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = function() 
            if glyph.wind_and_thunder.enabled then return 10 end
            return 20 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 136105,
        
        handler = function()
            -- MoP: With Blood and Thunder talent, applies Deep Wounds to all targets hit
            if talent.blood_and_thunder.enabled then
                applyDebuff( "target", "deep_wounds" )
            end
            
            -- Base Thunder Clap slow effect
            applyDebuff( "target", "thunder_clap_slow" )
        end,
    },
    
    deep_wounds = {
        id = 115767,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132090,
        
        -- Passive ability triggered by critical strikes
        handler = function()
            applyDebuff( "target", "deep_wounds" )
        end,
    },
    
    -- Missing abilities referenced in action lists
    heroic_throw = {
        id = 57755,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        startsCombat = true,
        handler = function()
            -- Ranged attack
        end,
    },
    
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",
        startsCombat = true,
        handler = function()
            -- Auto attack handled by game
        end,
    },
    
    -- Stance switching abilities (core MoP mechanic)
    battle_stance = {
        id = 2457,
        cast = 0,
        cooldown = 1.5, -- MoP: 1.5 second GCD for stance switching
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132349,
        
        usable = function() return not buff.battle_stance.up end,
        
        handler = function()
            -- Remove other stances
            removeBuff( "defensive_stance" )
            removeBuff( "berserker_stance" )
            
            -- Apply Battle Stance
            applyBuff( "battle_stance" )
            
            -- MoP: Stance switching incurs rage loss
            local rage_loss = rage.current * 0.25 -- Lose 25% of current rage
            spend( rage_loss, "rage" )
        end,
    },
    
    defensive_stance = {
        id = 71,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132341,
        
        usable = function() return not buff.defensive_stance.up end,
        
        handler = function()
            -- Remove other stances
            removeBuff( "battle_stance" )
            removeBuff( "berserker_stance" )
            
            -- Apply Defensive Stance
            applyBuff( "defensive_stance" )
            
            -- MoP: Stance switching incurs rage loss
            local rage_loss = rage.current * 0.25
            spend( rage_loss, "rage" )
        end,
    },
    
    berserker_stance = {
        id = 2458,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132275,
        
        usable = function() return not buff.berserker_stance.up end,
        
        handler = function()
            -- Remove other stances
            removeBuff( "battle_stance" )
            removeBuff( "defensive_stance" )
            
            -- Apply Berserker Stance
            applyBuff( "berserker_stance" )
            
            -- MoP: Stance switching incurs rage loss
            local rage_loss = rage.current * 0.25
            spend( rage_loss, "rage" )
        end,
    },
    
} )

-- Range
spec:RegisterRanges( "mortal_strike", "charge", "heroic_throw" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "golemblood",
    
    package = "Arms",
} )

local NewFeature = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0|t"

spec:RegisterSetting( "spell_reflection_filter", true, {
    name = format( "%s Filter M+ |T132361:0|t Spell Reflection", NewFeature ),
    desc = "If checked, then the addon will only suggest |T132361:0|t Spell Reflection on reflectable spells that target the player.",
    type = "toggle",
    width = "full",
} )

-- State Expressions for MoP Arms Warrior
spec:RegisterStateExpr( "rage_deficit", function()
    return (rage.max or 100) - (rage.current or 0)
end )

spec:RegisterStateExpr( "current_rage", function()
    return rage.current or 0
end )

spec:RegisterStateExpr( "rage_time_to_max", function()
    return rage.time_to_max
end )

spec:RegisterStateExpr( "rage_per_second", function()
    return rage.per_second
end )

spec:RegisterStateExpr( "should_use_execute", function()
    return target.health_pct <= 20
end )

spec:RegisterStateExpr( "colossus_smash_remains", function()
    return debuff.colossus_smash.remains
end )

spec:RegisterStateExpr( "mortal_strike_remains", function()
    return cooldown.mortal_strike.remains
end )

spec:RegisterStateExpr( "overpower_charges", function()
    return buff.taste_for_blood.stack or 0
end )

spec:RegisterStateExpr( "sweeping_strikes_active", function()
    return buff.sweeping_strikes.up
end )

spec:RegisterStateExpr( "deep_wounds_remains", function()
    return debuff.deep_wounds.remains
end )

spec:RegisterStateExpr( "active_enemies", function()
    return active_enemies or 1
end )

spec:RegisterStateExpr( "incoming_damage_3s", function()
    return damage.incoming_damage_3s or 0
end )

spec:RegisterStateExpr( "movement_distance", function()
    return movement.distance or 0
end )

spec:RegisterStateExpr( "movement_moving", function()
    return movement.moving or false
end )

spec:RegisterStateExpr( "target_time_to_die", function()
    return target.time_to_die or 0
end )

spec:RegisterStateExpr( "target_health_pct", function()
    return target.health_pct or 100
end )

spec:RegisterStateExpr( "health_pct", function()
    return health.pct or 100
end )

spec:RegisterStateExpr( "target_casting", function()
    return target.casting or false
end )

spec:RegisterStateExpr( "target_cast_interruptible", function()
    return target.cast_interruptible or false
end )

spec:RegisterStateExpr( "tank", function()
    -- Return tank information for group scenarios
    return {
        health = {
            pct = function()
                -- Find the tank in the group/raid
                local tank = nil
                if IsInGroup() then
                    for i = 1, GetNumGroupMembers() do
                        local unit = IsInRaid() and "raid" .. i or "party" .. i
                        if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
                            tank = unit
                            break
                        end
                    end
                end
                
                if tank then
                    return UnitHealth(tank) / UnitHealthMax(tank) * 100
                end
                return 100 -- Default if no tank found
            end
        }
    }
end )

spec:RegisterPack( "Arms", 20250721, [[Hekili:vZXFZPnY1plEUPKKR(OagC8DJXZqCijKgdEmK7A7FGqGwmQwiPkjmN74Hp7992vR0UR2vsKKj31RZ1dK299E773V3(mZBpF28Po2jK5J70QtVwVUt7MD60d(N5ttEkKmFAO9QhSVh(GV9w4)pHeNGp8jVaBhCZXb7IwbVy(0L7C9sg5pFPEi2bwBiz18XVU98PBCDCiSLsIxnF6SnUXhwG)R9HfPO8WIG1W3xL4g4FyHNBCc861brhw8bYdUEUnNpL(qKkSdiwrbj24AHVpMEUi(2l9ioZFd8EkuakypHe66FVvCsK7dKyg(JCdzVUFX)5WIbV9xhm(6HVf(0KHhwC3KzdMnAY4dl(TrZ(WHfVD4WBHpp5ZJF70dlU9UrtUB0S)5HfAG18PaQsirU2ZNEYHfl3TEDtvkQ5UWdlAWo3psSi(KTUe4GFfqjDMNaCvLJMeiDcsA6aa0AFWoFN4MjUREaaUriEg9nj2Ee)KMl9ccCSS9DSs2a7Me1KJMm(x6lSw5zhIeZzgjghc94TkWlioExSv8w74nnJiBTD9bKFjCA0svxcu155iuE)ik7AeLhf)eXt3C8Snic4cPBcrtpdAql9SbvMKGOTk6odcaLJ3AVLQ5oyjOGM4Iky50Nobqxzbah2zCEGso34bUsjQtK99b(GLHTgzPWlr086Jcnm6wvDtu821SwZf1gvxMHktcxbvfpI9Juz3pBY63ZwRuBk88dl27MSb(CkkGpXWXHfXp5tIU)PVyvnQPl9nruLd637HeA7whP9tjy4SIyq(GJ4ZKFrYVtwTd8zRH58oxF34nKO4IN)DOtClhIDIrkdfGNrrTz)wMf6StdOmDrRCAn4rsuyWEcvRTTzpq6ys9uysNja39BCJ8276tn6AB2ntgrHFO5w7F)WIFcHKzjJG3d7KepIv8MGDjZX)hNZBfUXoMuwOlfpH1iW1W)XWR)8mqeE7hgmf(ptUD2OBg9VsJE9YoT(la967a2weVG9VQYqw1WLE1bOyWi1Dl1Tbv155N1)orOFwjURp2arPQR61e4wd1iAdZeiDdCOQ7vgoicOsnIJQghsLTBPNmnhJOMh)o9Kn4Kqe39H5qeuCKzy2mobsHlZXhkBR2s2CqbrHKr(RtWEFTSg1GbAmKfL9GNUa3vqgqrb7zwOoK1278s0zBwTn4ndgnUyoJdh)H0ukVzcK84NM8(rxBW8Jtx27scSaVhaJTCJSe3TWPcqDlgNFlWL3stgasw22FfYkbXGGJLn2r3R1iIVIWDB3s8uoUJ8begTleZkN6fz4wikjXF1tq6p0nkfXibrcMTatD0oobICcwfaosZyr37D5iXfOPYTh)gGa66aNuRcc8q9PMSdoceNNKYRYnMUhm2p6kxtYvkROCd8VmApIS2JSkbHNGTAiXZZk9v4t04DqsoonvP4gBFWEa1usRY6oQ5X7Hqzr2PAksMoa5S2DLBcvFQBloZJsIlH8firpa58X054oCorqFe(aCkq9VGai0xASrHtcDN687OScb6AdX2dsgje5BGH9RzuLR)QGTOOWHMEU1zXuAoDX0i4)iyV0SJaXWpa6CnvB8RWvaggXpgZpiJRKJXSxQZPLKeBiZ5gKHAqiu3muJhuUTd3QdCNqRkoJkJ25BX(SfwVSi5Q33qpwH1wSk(5RrB(Qz(qSbLojKiabU5uS2uqlyfOWd70QKJIawKtK64Y4eJSwpSedQrqcCms9lib0o1dns9Zqx6O1IXNPsfZIKLjkljnZ04FqTuH1k(2K3m6t0(Dmymeo72jthHb6gn(9vMoj3PMOQx7kYGu3EUqYgJfntUWqJb4QGyywV3hfK79kgYJkhY0Ohpcc46fAQivNgpHwZV1YapnrsYFx9IHizjlML3HfNxAEoHreWnj4fUm1dPcyQH(XVn4oSJy)cOFC3ntPvkDZOPZGpn5DG6cO0m4UrdeZikpxP3agYGBn0LwYg4eer2haUKHhXpIXpfNq2MM)HnTNlqCAqE7FpAW93jW3UM9TFHxMp2Kr)G9yubemjP7omYDRDeSEN0w4KcUtbcMwSbVHaGcblKiIbK1cRGtryQqrK04Nm2(9zXppvBZfaVvOMwCEwhAnCm8WBVB41tU5ndMbqC4SpFlpbZPZqUPAjFAaHs5zSmRtISSV31c0UfIBZIRli(rBSQk3lfE2q0xBvybkBBbwFEsus2SkVuR1BLjoOysQX(H1K79ud5yRLU6lNITQLEqY3wHKWqiVMi3LX0ELgVb0Cc1LMIhjzJnnTzBhVNesLpm07jRWa3y8B(b(8fI2sHEysrudY84MLyqcgTp4rIJ9H)TogKtNC7hadWrxpygATD9KjF6Tt(TXyLkJh8(H3mC8SkvuQOraONgwThVml1vSQelOcghxwjxP1BAU60xvUU13hsixK9ODcRnPLfcjVl6lXwILUkkwEPje9nMKLO6msP8WtuGr8z50tDazQ1B5P1JVU84rcrDQGOfQRIAPybj1Svtjv5VuNnkFzGJv)hijTX2weKi(9CAZO0G3kQSkal)(lEfx2sHLOPyrij9wrPENwuHMKP7mgrZlT(AOy6DBXJACz1dLEu78N9JQKGPJUkSuuo1IoJ2i5mKWaEc0MUsa2DETEx0tksG7Sx5Ib91EtoM4OARrQgBt1aJfcOSAL03e6Uc2Q2rRS9rotueV6TJ1DAMZGmjRuFx5I2CC65E)MKyR)9oN7Zkz8y7m7rJ0L23BfS2cE7Qhsl0rUkTVTnvplr1PqroFcYXA2G7E)WzIjUQzJvFU)(1h9YU2ttTauZvNXsN(2i3GiAA3tttg)L3YtLw(2qF6vvZe00x6YJDLVYlY61s1Mz8gAB6sE1FDyz9DH6tEcV51IToRGNlD3rwXxiF5aAcUPav9DApN(LASU5U2N5e5CH(QRf2TnaBZDglROvfLgOgtFhQ2Xr5zTIQL14H)4G5XCt5FbE4Li)nbREyV9Jen16ZFLwV)LylY6v7B2565arqs1qFNRNNY92MBUK2AsDbrXC2QiEr1xNtj(9Z2CpL2JkidKckkFPPvF3SxjtxAVshEJXkj4aWmSw(eSpa37dICQt4H8Hf6TdF3WXth9R4idnC6TtgpD40kdnO2P6EM6unRqaLwLEERYJBOc9UgGExDaVN4fcUXL45yT32ZR8AIuGXzhD)4ZYSWooH21CNYJhO284Ev1cVi4m8eslRGualTGM6kBAZWjIGs6(RdbI9A75(FLAXHz)(6VzbTiHFqLV1O1efZkxFWQ31Xw(sQmhTqvw2tY4Lv)OJvejVJxsOt3ckp1)csTupw(pOEhb9Aj6G9r37D9O3VsbhSzVQ8igfuBfDMGVccbXA6BjXc0FxuuM1JURGyypzfTtjXeXxWCvTlHM7uz(PIztxLDeOrvhFuFEMyl7N(5BVDYDq(RdUgZETAFu5zyjIyHU7L(wYVhgetKFRHWnT7v3eElA20S0bMSc7nZEUKu(sdQxOFLsVNvkziGWk7KPz)xfrRslxLE3MGiFS2hw)lllOjvxAVDKpqhX482cmE3THq6)PDR(fs1m9cSB7)NDUr0UThGtuaoacBzx0yAd2BE4JFY1hEv7U)cOv5hVlebiUcgvaqvm27lGnqr86apVG90(GBVlcBaoK0a88D0(97Y73phi4nAHh4e(68dOu9oFPv74Glg8NzV0oM8lh(iTKyXQGGh9rnNCPBo84o5)8)3CWXhjpYmg4gPJ7YXXhABKpim3kViB59mUC1XxiFpNBEp0(9NVYxx7vErnwPwMe)MupoUK5J9F4AlS7i1WPn7MbpUJ7z1G7wLet8UsmknYUOKJJ(mR0k2VXCQSDhJBqPXxc7XmtqQVvgpBItcWXD8mRCZMu6ArKzdfRrcmVwQJJ8mZmfQU4f1qzkV0G64GPyEa1XftXCLRJYRUuEf46TmUrX0a)dXDawSq6hfPfdQaP5OECYFZwFIPv(IAOVOxK(DNNLN)x6detao9rYjSLfwo)8IC4rB5hXFwM0qM3CCsq3Gj6pD7U1rUpGdUrWAx8cW)b9tjWh)HVQ5Wa3(x7OyGW4730yGy7B5az8rtmwZV5hoYzZWiGyY)4MzXG)R9)BI52FQ76(NWQgtASnACI2Qh0cp1sueHjF0nsHNUIG0ctg))u2mA0NrggwPVDialQp8Ky9Rzn4K)HtXXWOV4SAyyXGDiBTLnXg63Ry(gNYMlJ(SlE(0Sb1O)k(CAuHgWrm83vj)rslptAXhZYCdfzyv19B98ZfMQZRUiLqRXmBlcA24ptbT5buUrDgSAbGQoz0FdaFJt0oX2nQyATfPk16o(YOkHjYoLJx7PRwIy0y7GeK4uxFv3wCt8IZADJtuMY6sGoF3icYBz1LVUvJITP9Q8MD(JTA2XmuZskubQzeTMrHoLJvRPBweZkZr7P4SV2NF(r8x0EONKbKYi0YaqwnfvIkP2hiO3iCS70QsOi1(fek4kY7Nv)2vcbXkfkcGR63P6dDEU8v4zRotrwvU0AMXIXtKqfxiXx6DKF15p)8ll2kXl70RHPlG7v6rlBUU(oIWSrYIPOOFIXA8YV5uJjYrAGUqAsOz(0rXOb(PlVOL(9lmtwChuxDElJKrdZZ5vQcN5bFspbajYBbjcS9uCMI6ZN1lKwmWd3f(8ZvmYtx25vnEjDVkZDKWo1nItx1PLb2SwQSZF2Os20sLPeuaSAv5sLBfgxQsu)PJBLzBoXmk1ORc(jp(9kpmuCv1l5dp1p11G(TsFDmJyQPs5tSKHtLyxG(kHFPUSp2)AGR09TuCpmKIefxPp1l7ygusNpA1i6N3PNFUKzD6YZmJG0VxMIe1X3v9pRvTGcRAj1)AGBO7Xhh5XOI2TkHmW5bPgNei8avPVuyLndhzhkL5bcGZZpxiMqLhGZAPLxWkV2eue7kEMnlkqkxrV6j0RsDBPSX(60Tvb13gD7U86lo6HWZmLvB9OQbbBLxaz7B2pTC2(MNPoZyZG9hFy7Au8HAS9ubADSaQ5UP6RNNQ5xakT5IqnJexjC4SHFRurLXrLZmKfg)Q6aAntmxjunFW2QdKlmGCz5yyEi3QRkjuaAX0yU68JrGk63tD1QDMJUHEzf9knGBMHIo)ExDrv(9(Y(DQQsxHILvIStLF0BOEWygAf)5WPbce91GQcxXFJGyEf1)tzvbqEwJKk(5RYiopAV6ki)Y(NBe2fCZxtE0L95U21)dkLreM)JhfInvUu3CUK6VXugHOIdbJm(s9euHyUiDA43ukmINjXi96mlcnGv2WexxKhxVF(NmBrK6GPMcyWiqtGudW0ORYIcJCyMFYY(TBYiIQkeQkh9mJqsYrzrbrbxNkBp7IM1Pv0ttY4QQ)688MvFhK(zbowvnV38Fz7v6ZK3XXCF54Fp9izX7BmVtKT7ODxcn1xzdxWVig(FN7A3F2Fy6AXzRg0XmRXj0HQu3(LZYOinuJ0lkYdYINPcVuX751pcN2HRUsXsE7nrVBkt3nsyfhXxLoE3RHqxDpVLbqlmad6GAxfO2veO9mb08XCaHPWoo7y6uVmmfh(zfOchvTkjY8Wc38ED4IT7vwEbsiO4CxOqMDlAy3PXjY3ot6KpBaf6gsdvoCVuJodd5SbiNnSXi4eyMnugHzmbrtJUSbqlmfYf0gmsn5ZXHYEEDAjkkJLCfwJvmgXvAnMo1iO9IWaqWY9JKgmsA(IZkMuzYI1LrF7E6qKE9voy1oBXLPQMdyD3GEQepnaEHRnNF7DItnSoqRgyteSk3UF6tlovW40)o))b]] )


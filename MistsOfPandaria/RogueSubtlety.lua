-- RogueSubtlety.lua
-- Mists of Pandaria (5.4.8) - Modified Version - BOSS Fight Fixed

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class, state = Hekili.Class, Hekili.State
-- Local aliases for core state helpers and tables (improves static checks and readability).
local applyBuff, removeBuff, applyDebuff, removeDebuff = state.applyBuff, state.removeBuff, state.applyDebuff, state.removeDebuff
local removeDebuffStack = state.removeDebuffStack
local summonPet, dismissPet, setDistance, interrupt = state.summonPet, state.dismissPet, state.setDistance, state.interrupt
local buff, debuff, cooldown, active_dot, pet, totem, action = state.buff, state.debuff, state.cooldown, state.active_dot, state.pet, state.totem, state.action
local setCooldown = state.setCooldown
local addStack, removeStack = state.addStack, state.removeStack
local gain, rawGain, spend, rawSpend = state.gain, state.rawGain, state.spend, state.rawSpend
local talent = state.talent
local insert, wipe = table.insert, table.wipe
local strformat = string.format
local GetSpellInfo = ns.GetUnpackedSpellInfo
local floor = math.floor

local spec = Hekili:NewSpecialization( 261 )

spec.name = "Subtlety"
spec.role = "DAMAGER"
spec.primaryStat = 2 -- Agility

-- Enhanced resource registration for Subtlety Rogue with Shadow mechanics
spec:RegisterResource( 3, { -- Energy with Subtlety-specific enhancements
    -- Shadow Techniques energy bonus (Subtlety passive)
    shadow_techniques = {
        last = function () 
            return state.query_time -- Continuous tracking
        end,
        interval = 2, -- Shadow Techniques procs roughly every 2 seconds
        value = 7, -- Shadow Techniques grants 7 energy per proc
        stop = function () 
            return combat == 0 -- Only active in combat
        end,
    },
    
    -- Shadow Focus talent energy efficiency (enhanced for Subtlety)
    shadow_focus = {
        aura = "stealth",
        last = function ()
            return state.buff.stealth.applied or state.buff.vanish.applied or state.buff.shadow_dance.applied or 0
        end,
        interval = 1,
        value = function()
            -- Shadow Focus is more powerful for Subtlety (stealth specialists)
            local stealth_bonus = (state.buff.stealth.up or state.buff.vanish.up or state.buff.shadow_dance.up) and 4 or 0
            return stealth_bonus -- +4 energy per second while stealthed (more than other specs)
        end,
    },
    
    -- Shadow Dance energy efficiency (Subtlety signature)
    shadow_dance = {
        aura = "shadow_dance",
        last = function ()
            local app = state.buff.shadow_dance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Enhanced energy efficiency during Shadow Dance
            return state.buff.shadow_dance.up and 3 or 0 -- +3 energy per second during Shadow Dance
        end,
    },
    
    -- Shadowstep energy efficiency
    shadowstep = {
        aura = "shadowstep",
        last = function ()
            local app = state.buff.shadowstep.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Brief energy boost after Shadowstep
            return state.buff.shadowstep.up and 2 or 0 -- +2 energy per second for short duration
        end,
    },
    
    -- NOTE: Relentless Strikes energy is not modeled as random regen to keep the engine deterministic.

    find_weakness_energy = {
        aura = "find_weakness",
        last = function ()
            return state.buff.find_weakness.applied or 0
        end,
        interval = 1,
        value = function()
            -- Find Weakness provides energy efficiency bonus
            return state.buff.find_weakness.up and 3 or 0 -- +3 energy per second with Find Weakness
        end,
    },
}, {
    -- Enhanced base energy regeneration for Subtlety with Shadow mechanics
    base_regen = function ()
        local base = 10 -- Base energy regeneration in MoP (10 energy per second)
        
        -- Haste scaling for energy regeneration (minor in MoP) with safety checks
        local haste_rating = (state.stat and state.stat.haste_rating) or 0
        local haste_bonus = 1.0 + (haste_rating / 42500) -- Approximate haste scaling
        
        -- Subtlety gets enhanced energy efficiency in stealth with safety checks
        local stealth_bonus = 1.0
        if state.talent and state.talent.shadow_focus and state.talent.shadow_focus.enabled and 
           ((state.buff and state.buff.stealth and state.buff.stealth.up) or 
            (state.buff and state.buff.vanish and state.buff.vanish.up) or 
            (state.buff and state.buff.shadow_dance and state.buff.shadow_dance.up)) then
            stealth_bonus = 1.75 -- 75% bonus energy efficiency while stealthed (stronger than other specs)
        end
        
        -- Master of Subtlety energy efficiency with safety checks
        local subtlety_bonus = 1.0
        if state.buff and state.buff.master_of_subtlety and state.buff.master_of_subtlety.up then
            subtlety_bonus = 1.10 -- 10% energy efficiency bonus
        end
        
        -- Ensure we never return nil or invalid values
        local result = base * haste_bonus * stealth_bonus * subtlety_bonus
        return math.max(result or 10, 1) -- Fallback to minimum 1 energy per second if something goes wrong
    end,
    
    -- Preparation energy burst
    preparation_energy = function ()
        return state.talent.preparation.enabled and 3 or 0 -- Enhanced energy burst from preparation resets for Subtlety
    end,
    
    -- Shadow Clone energy efficiency (if available)
    shadow_clone_efficiency = function ()
        return state.buff.shadow_clone.up and 1.15 or 1.0 -- 15% energy efficiency during Shadow Clone
    end,
} )

-- Combo Points resource registration with Subtlety-specific mechanics
spec:RegisterResource( 4, { -- Combo Points = 4 in MoP
    -- Honor Among Thieves combo point generation (Subtlety signature)
    honor_among_thieves = {
        last = function ()
            return state.query_time
        end,
        interval = 1, -- HAT has higher proc chance for Subtlety
        value = function()
            if state.talent.honor_among_thieves.enabled and state.group_members > 1 then
                -- Subtlety gets enhanced HAT generation in groups
                return state.group_members >= 3 and 1 or 0 -- Better in larger groups
            end
            return 0
        end,
    },
    
    -- Premeditation combo point generation (Subtlety opener)
    premeditation = {
        last = function ()
            return state.query_time -- Simplified for Hekili compatibility
        end,
        interval = 1,
        value = function()
            -- Premeditation generates 2 combo points when opening from stealth
            -- Simplified: check if premeditation buff is active and we're stealthed
            if state.buff.premeditation.up and (state.buff.stealth.up or state.buff.vanish.up) then
                return 2
            end
            return 0
        end,
    },
    
    -- Initiative bonus combo points (Subtlety talent)
    initiative_bonus = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Initiative: Stealth abilities generate additional combo points
            if state.talent.initiative.enabled and state.last_stealth_ability then
                return state.talent.initiative.rank or 1 -- Variable rank in MoP
            end
            return 0
        end,
    },
    
    -- Shadow Clone combo point generation (from Shadow Dance)
    shadow_dance_generation = {
        aura = "shadow_dance",
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Shadow Dance enhances combo point generation efficiency
            if state.buff.shadow_dance.up and state.last_stealth_ability then
                return 1 -- Extra combo point generation during Shadow Dance
            end
            return 0
        end,
    },
}, {
    -- Base combo point mechanics for Subtlety
    max_combo_points = function ()
        return 5 -- Maximum 5 combo points in MoP
    end,
    
    -- Subtlety's enhanced stealth combo point efficiency
    stealth_efficiency = function ()
        -- Stealth abilities are more efficient for Subtlety
        return (state.buff.stealth.up or state.buff.vanish.up or state.buff.shadow_dance.up) and 1.25 or 1.0
    end,
    
    -- Master of Subtlety damage bonus affects combo point value
    master_of_subtlety_value = function ()
        return state.buff.master_of_subtlety.up and 1.1 or 1.0 -- 10% effective combo point value bonus
    end,
} )

-- Talents
spec:RegisterTalents( {
  -- Tier 1
  nightstalker          = { 1, 1, 14062 }, -- While Stealth or Vanish is active, your abilities deal 25% more damage.
  subterfuge            = { 1, 2, 108208 }, -- Your abilities requiring Stealth can still be used for 3 sec after Stealth breaks.
  shadow_focus          = { 1, 3, 108209 }, -- Abilities used while in Stealth cost 75% less energy.
  
  -- Tier 2
  deadly_throw          = { 2, 1, 26679 }, -- Finishing move that throws a deadly blade at the target, dealing damage and reducing movement speed by 70% for 6 sec. 1 point: 12 damage 2 points: 24 damage 3 points: 36 damage 4 points: 48 damage 5 points: 60 damage
  nerve_strike          = { 2, 2, 108210 }, -- Kidney Shot and Cheap Shot also reduce the damage dealt by the target by 50% for 6 sec after the effect ends.
  combat_readiness      = { 2, 3, 74001 }, -- Reduces all damage taken by 50% for 10 sec. Each time you are struck while Combat Readiness is active, the damage reduction decreases by 10%.
  
  -- Tier 3
  cheat_death           = { 3, 1, 31230 }, -- Fatal attacks instead bring you to 10% of your maximum health. For 3 sec afterward, you take 90% reduced damage. Cannot occur more than once per 90 sec.
  leeching_poison       = { 3, 2, 108211 }, -- Your Deadly Poison also causes your Poison abilities to heal you for 10% of the damage they deal.
  elusiveness           = { 3, 3, 79008 }, -- Feint also reduces all damage you take by 30% for 5 sec.
  
  -- Tier 4
  prep                  = { 4, 1, 14185 }, -- When activated, the cooldown on your Vanish, Sprint, and Shadowstep abilities are reset.
  shadowstep            = { 4, 2, 36554 }, -- Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec. Cooldown reset by Preparation.
  burst_of_speed        = { 4, 3, 108212 }, -- Increases your movement speed by 70% for 4 sec. Usable while stealthed. Removes all snare and root effects.
  
  -- Tier 5
  prey_on_the_weak      = { 5, 1, 51685 }, -- Targets you disable with Cheap Shot, Kidney Shot, Sap, or Gouge take 10% additional damage for 6 sec.
  paralytic_poison      = { 5, 2, 108215 }, -- Your Crippling Poison has a 4% chance to paralyze the target for 4 sec. Only one poison per weapon.
  dirty_tricks          = { 5, 3, 108216 }, -- Cheap Shot, Gouge, and Blind no longer cost energy.
  
  -- Tier 6
  shuriken_toss         = { 6, 1, 114014 }, -- Throws a shuriken at an enemy target, dealing 400% weapon damage (based on weapon damage) as Physical damage. Awards 1 combo point.
  versatility           = { 6, 2, 108214 }, -- You can apply both Wound Poison and Deadly Poison to your weapons.
  anticipation          = { 6, 3, 114015 }, -- You can build combo points beyond the normal 5. Combo points generated beyond 5 are stored (up to 5) and applied when your combo points reset to 0.
  
  -- Tier 7
  premeditation         = { 7, 1, 14183 }, -- When you use Stealth, you also gain 2 combo points.
  hemorrhage            = { 7, 2, 16511 }, -- An instant strike that causes 110% weapon damage and causes the target to bleed for 40% weapon damage over 24 sec. Awards 1 combo point.
  shadow_blades         = { 7, 3, 121471 }, -- Your melee attacks have a chance to strike with shadow damage, and your Combo Point-generating abilities generate 1 additional Combo Point.
  
} )

-- Auras
spec:RegisterAuras( {
  -- Abilities
  kidney_shot = {
    id = 408,
    duration = function() return 1 + math.min(5, combo_points.current or 0) end, -- MoP Classic: 1s base + 1s per combo point (correct)
    max_stack = 1
  },
  preparation = {
    id = 14185,
    duration = 3600,
    max_stack = 1
  },
  premeditation = {
    id = 14183,
    duration = 20,
    max_stack = 1
  },
  sap = {
    id = 6770,
    duration = 60,
    max_stack = 1
  },
  shadow_dance = {
    id = 51713,
    duration = 8,
    max_stack = 1
  },
  shadowstep = {
    id = 36554, -- Use same ID as ability for consistency
    duration = 2,
    max_stack = 1
  },
  slice_and_dice = {
    id = 5171,
    duration = function() return 6 + (6 * math.min(5, combo_points.current or 0)) end, -- MoP: 6s base + 6s per combo point.
    max_stack = 1
  },
  sprint = {
    id = 2983,
    duration = 8,
    max_stack = 1
  },
  stealth = {
    id = 1784,
    duration = 3600,
    max_stack = 1
  },
  vanish = {
    id = 1856, -- Standardized to match other specs
    duration = 10,
    max_stack = 1
  },
  
  -- Bleeds/Poisons
  garrote = {
    id = 703,
    duration = 18,
    max_stack = 1
  },
  rupture = {
    id = 1943,
    duration = function() return 4 + (4 * math.min(5, combo_points.current or 0)) end, -- MoP: 4s base + 4s per combo point
    max_stack = 1,
    tick_time = 2
  },
  -- Poison Debuffs on targets
  deadly_poison_dot = {
    id = 2818,
    duration = 12,
    max_stack = 5,
    copy = "deadly_poison_debuff"
  },
  crippling_poison_debuff = {
    id = 3409,
    duration = 12,
    max_stack = 1,
    copy = "crippling_poison_slow"
  },
  mind_numbing_poison_debuff = {
    id = 5760,
    duration = 10,
    max_stack = 1,
    copy = "mind_numbing_poison_slow"
  },
  instant_poison_debuff = {
    id = 8681,
    duration = 8,
    max_stack = 1
  },
  wound_poison_debuff = {
    id = 8680,
    duration = 12,
    max_stack = 1
  },
  
  -- Weapon Poison Buffs (applied to weapons)
  deadly_poison = {
    id = 2823,
    duration = 3600,
    max_stack = 1
  },
  instant_poison = {
    id = 8680,
    duration = 3600,
    max_stack = 1
  },
  wound_poison = {
    id = 8679,
    duration = 3600,
    max_stack = 1
  },
  crippling_poison = {
    id = 3408,
    duration = 3600,
    max_stack = 1
  },
  mind_numbing_poison = {
    id = 5761,
    duration = 3600,
    max_stack = 1
  },
  
  -- Find Weakness - Subtlety signature debuff/buff
  find_weakness = {
    id = 91023,
    duration = 10,
    max_stack = 1
  },
  
  -- Master of Subtlety - damage bonus after stealth breaks
  master_of_subtlety = {
    id = 31223,
    duration = 6,
    max_stack = 1
  },
  
  -- Sanguinary Vein - bleed damage bonus
  sanguinary_vein = {
    id = 91023,
    duration = 30,
    max_stack = 1,
    debuff = true
  },
  
  -- Defensive and Utility Buffs
  cloak_of_shadows = {
    id = 31224,
    duration = 5,
    max_stack = 1
  },
  evasion = {
    id = 5277,
    duration = 5,
    max_stack = 1
  },
  feint = {
    id = 1966,
    duration = 6,
    max_stack = 1
  },
  recuperate = {
    id = 73651,
    duration = function() return 6 * math.min(5, combo_points.current or 0) end,
    max_stack = 1
  },
  tricks_of_the_trade = {
    id = 57934,
    duration = 30,
    max_stack = 1
  },
  
  -- Debuffs on Targets
  blind = {
    id = 2094,
    duration = 10,
    max_stack = 1
  },
  gouge = {
    id = 1776,
    duration = 4,
    max_stack = 1
  },
  crimson_tempest = {
    id = 121411,
    duration = function() return 4 + (2 * math.min(5, combo_points.current or 0)) end,
    max_stack = 1
  },
  expose_armor = {
    id = 8647,
    duration = 30,
    max_stack = 1
  },
  
  -- Missing buffs/debuffs for abilities
  shadow_blades = {
    id = 121471,
    duration = 12,
    max_stack = 1
  },
  smoke_bomb = {
    id = 76577,
    duration = 10,
    max_stack = 1
  },
  distract = {
    id = 1725,
    duration = 10,
    max_stack = 1
  },
  
  -- Additional missing debuffs and effects
  sunder_armor = {
    id = 7386,
    duration = 30,
    max_stack = 5
  },
  stun = {
    id = 408, -- Generic stun effect
    duration = 4,
    max_stack = 1
  },
  magic = {
    id = 1,
    duration = 30,
    max_stack = 1
  },
  
  -- Missing ability buffs
  burst_of_speed = {
    id = 108212,
    duration = 4,
    max_stack = 1
  },
  
  -- Stealth state tracking for SimC compatibility
  stealthed = {
    id = 115191,
    duration = 3600,
    max_stack = 1,
    copy = "stealthed_all",
    generate = function()
      local stealth_up = buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up
      return {
        all = stealth_up,
        rogue = buff.stealth.up,
        mantle = false,
        normal = buff.stealth.up
      }
    end
  },

  -- Hemorrhage DoT (target debuff)
  hemorrhage = {
    id = 89775,
    duration = 24,
    max_stack = 1,
    tick_time = 3
  },
  
  -- Honor Among Thieves - combo point generation from party crits
  honor_among_thieves = {
    id = 51701,
    duration = 2,
    max_stack = 1
  },
  subterfuge = {
    id = 115192,
    duration = 3,
    max_stack = 1
  },
  anticipation = {
    id = 115189,
    duration = 3600,
    max_stack = 5
  },
  
  -- Cross-spec auras to prevent validation errors
  blindside = {
    id = 121153,
    duration = 10,
    max_stack = 1
  },
  deep_insight = {
    id = 84747,
    duration = 15,
    max_stack = 1,
    debuff = true
  },
  revealing_strike = {
    id = 84617,
    duration = 15,
    max_stack = 1,
    debuff = true
  },
  vendetta = {
    id = 79140,
    duration = 30,
    max_stack = 1
  },
} )

local true_stealth_change, emu_stealth_change = 0, 0
local last_mh, last_oh, last_shadow_techniques, swings_since_sht, sht = 0, 0, 0, 0, {} -- Shadow Techniques

spec:RegisterEvent( "UPDATE_STEALTH", function ()
  true_stealth_change = GetTime()
end )

spec:RegisterStateExpr( "cp_max_spend", function ()
  return 5
end )

spec:RegisterStateExpr( "effective_combo_points", function ()
  local c = combo_points.current or 0
  return c
end )


spec:RegisterStateExpr( "hemorrhage_refresh_needed", function()
    local pandemic_time = settings.hemorrhage_pandemic_time or 6
    return debuff.hemorrhage.remains < pandemic_time or not debuff.hemorrhage.up
end )

spec:RegisterStateExpr( "behind_target", function()
   
    if buff.stealth.up or buff.vanish.up or buff.shadow_dance.up then
        return true
    end
    
   
    if settings.strict_positioning then
   
        if target.is_player then
            return false 
        end
        

        return false
    end
    
    return true
end )

spec:RegisterStateExpr( "combo_generator_priority", function()
  
    if hemorrhage_refresh_needed and talent.hemorrhage.enabled then
        return "hemorrhage"
    end
    
   
    if settings.prefer_backstab and behind_target then
        return "backstab"
    end
    
    
    if talent.hemorrhage.enabled and not behind_target then
        return "hemorrhage"
    end
    
  
    return "backstab"
end )

spec:RegisterStateExpr( "bleed_value", function()
    
    return talent.sanguinary_vein and talent.sanguinary_vein.enabled
end )

-- Advanced Stealth State Expressions for MoP Subtlety
spec:RegisterStateExpr( "stealthed", function()
    return {
        all = buff.stealth.up or buff.vanish.up or buff.shadow_dance.up,
        normal = buff.stealth.up,
        vanish = buff.vanish.up,
        shadow_dance = buff.shadow_dance.up
    }
end )

-- Proper stealthed state expressions for MoP compatibility
spec:RegisterStateExpr( "stealthed_rogue", function() return buff.stealth.up end )
spec:RegisterStateExpr( "stealthed_mantle", function() return false end ) -- Not available in MoP
spec:RegisterStateExpr( "stealthed_all", function() return buff.stealth.up or buff.vanish.up or buff.shadow_dance.up end )

-- Additional state expressions for WoWSims compatibility
spec:RegisterStateExpr( "sanguinary_vein_active", function()
    return debuff.sanguinary_vein.up or false
end )

spec:RegisterStateExpr( "find_weakness_active", function()
    return debuff.find_weakness.up or false
end )

spec:RegisterStateExpr( "master_of_subtlety_active", function()
    return buff.master_of_subtlety.up or false
end )

spec:RegisterStateExpr( "honor_among_thieves_active", function()
    return buff.honor_among_thieves.up or false
end )

spec:RegisterStateExpr( "shadow_blades_active", function()
    return buff.shadow_blades.up or false
end )

spec:RegisterStateExpr( "shadow_dance_active", function()
    return buff.shadow_dance.up or false
end )

spec:RegisterStateExpr( "premeditation_active", function()
    return buff.premeditation.up or false
end )

spec:RegisterStateExpr( "anticipation_stacks", function()
    return buff.anticipation.stack or 0
end )

-- T16H compatibility: anticipation_charges alias
spec:RegisterStateExpr( "anticipation_charges", function()
    return buff.anticipation.stack or 0
end )

-- Bleed tracking for Sanguinary Vein
spec:RegisterStateExpr( "bleed_active", function()
    return debuff.rupture.up or debuff.garrote.up or debuff.hemorrhage.up or debuff.crimson_tempest.up
end )

-- Stealth state for opener logic
spec:RegisterStateExpr( "opener_ready", function()
    return (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up) and 
           (not debuff.garrote.up or debuff.garrote.remains < 3) and
           (not debuff.rupture.up or debuff.rupture.remains < 3)
end )

-- Energy pooling for Shadow Dance
spec:RegisterStateExpr( "energy_for_shadow_dance", function()
    return energy.current >= 75 and not buff.shadow_dance.up and 
           buff.slice_and_dice.up and debuff.rupture.up and debuff.hemorrhage.up
end )

-- Combo point efficiency for finishers
spec:RegisterStateExpr( "finisher_ready", function()
    return combo_points.current >= 5 or 
           (combo_points.current >= 3 and buff.slice_and_dice.remains < 6)
end )

spec:RegisterStateExpr( "boss", function()
    return target.boss or false
end )

-- Additional state expressions for SimC compatibility
spec:RegisterStateExpr( "poison", function()
    return {
        lethal = {
            up = buff.deadly_poison.up or buff.instant_poison.up or buff.wound_poison.up,
            down = not (buff.deadly_poison.up or buff.instant_poison.up or buff.wound_poison.up)
        },
        nonlethal = {
            up = buff.crippling_poison.up or buff.mind_numbing_poison.up,
            down = not (buff.crippling_poison.up or buff.mind_numbing_poison.up)
        }
    }
end )

spec:RegisterStateExpr( "enemies", function()
    return active_enemies or 1
end )

-- Magic debuff state for SimC compatibility
spec:RegisterStateExpr( "magic_debuff_active", function()
    return false -- Simplified - no magic debuffs active by default
end )

-- Settings access for abilities and state expressions
spec:RegisterStateExpr( "should_use_shadowstep", function()
    return settings.allow_shadowstep and talent.shadowstep.enabled
end )

-- Stealth-breaking hook for proper MoP mechanics
spec:RegisterHook( "runHandler", function( action, pool )
    -- Handle stealth-breaking for non-stealth abilities
    local stealth_abilities = {
        "stealth", "vanish", "garrote", "ambush", "cheap_shot", "sap", "pick_pocket", "distract"
    }
    
    local breaks_stealth = true
    for _, ability in ipairs(stealth_abilities) do
        if action == ability then
            breaks_stealth = false
            break
        end
    end
    
    if breaks_stealth then
        if buff.stealth.up and not talent.subterfuge.enabled then
            removeBuff("stealth")
        elseif buff.stealth.up and talent.subterfuge.enabled then
            -- Subterfuge extends stealth abilities for 3 seconds
            removeBuff("stealth")
            applyBuff("subterfuge", 3)
        end
        
        if buff.vanish.up and not talent.subterfuge.enabled then
            removeBuff("vanish")
        elseif buff.vanish.up and talent.subterfuge.enabled then
            removeBuff("vanish")
            applyBuff("subterfuge", 3)
        end
        
        if buff.shadow_dance.up then
            -- Shadow Dance doesn't get broken by abilities in Subtlety
        end
    end
    
    -- Handle Master of Subtlety and other stealth-related buffs
    if action == "ambush" or action == "garrote" or action == "cheap_shot" then
        if (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up) then
            -- Subtlety gets enhanced benefits from stealth openers
            if talent.master_of_subtlety.enabled then
                applyBuff("master_of_subtlety", 6) -- 6-second damage bonus
            end
        end
    end
end )

-- Abilities
spec:RegisterAbilities( {
  -- Core Rogue Abilities
  
  -- Basic combo point generator for when other abilities aren't available
  sinister_strike = {
    id = 1752,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = 40,
    spendType = "energy",

    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
    end
  },

  -- Instantly attack with your off-hand weapon for 280% weapon damage and causes the target to bleed, dealing damage over 18 sec. Must be stealthed. Awards 1 combo point.
  garrote = {
    id = 703,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 45 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    
    usable = function () return (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up), "requires stealth" end,

    handler = function ()
      gain( 1, "combo_points" )
      applyDebuff( "target", "garrote", 18 )
      
      -- Apply poisons from stealth
      if buff.deadly_poison.up then
        applyDebuff("target", "deadly_poison_dot", 12, math.min(5, (debuff.deadly_poison_dot.stack or 0) + 1))
      end
      
      -- Remove stealth (unless Subterfuge talent extends it)
      if not talent.subterfuge.enabled then
        removeBuff("stealth")
        removeBuff("vanish")
      else
        -- Subterfuge extends stealth abilities for 3 seconds
        removeBuff("stealth")
        removeBuff("vanish")
        applyBuff("subterfuge", 3)
      end
    end
  },

  -- Allows the caster to vanish from sight, enabling the use of stealth for 10 sec.
  vanish = {
    id = 1856,
    cast = 0,
    cooldown = 180,
    gcd = "off",
    school = "physical",

    startsCombat = false,
    
    

    handler = function ()
      applyBuff( "vanish", 10 )
      applyBuff( "stealth", 10 ) -- Vanish grants stealth
    end
  },

  -- Kick the target, interrupting spellcasting and preventing any spell in that school from being cast for 5 sec.
  kick = {
    id = 1766,
    cast = 0,
    cooldown = 10,
    gcd = "off",
    school = "physical",

    startsCombat = true,
    toggle = "interrupts",

    

    debuff = "casting",
    readyTime = state.timeToInterrupt,

    handler = function ()
      interrupt()
    end
  },

  -- Conceals you in the shadows until cancelled or upon attacking.
  stealth = {
    id = 1784,
    cast = 0,
    cooldown = 10,
    gcd = "off",
    school = "physical",

    startsCombat = false,
    
    usable = function() return not buff.stealth.up and combat == 0, "cannot stealth in combat or while already stealthed" end,

    handler = function ()
      applyBuff( "stealth", 3600 ) -- Long duration until broken
    end
  },

  -- When used, adds 2 combo points to your target. You must add the finishing move within 20 sec, or the combo points are lost.
  premeditation = {
    id = 14183,
    cast = 0,
    cooldown = 20,
    gcd = "off",
    school = "physical",

    talent = "premeditation",
    startsCombat = false,
    
    usable = function () return (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up) and combo_points.current < 4, "requires stealth and less than 4 combo points" end,

    handler = function ()
      gain( 2, "combo_points" )
      applyBuff( "premeditation", 20 )
    end
  },


  backstab = {
    id = 53,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    -- MoP: Backstab costs 35 energy (reduced by Shadow Focus while stealthed).
    spend = function () return 35 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    

    usable = function () 
      
        return behind_target, "not behind target"
    end,

    handler = function ()
      gain( 1, "combo_points" )
      
      -- Apply/refresh poisons
      if buff.deadly_poison.up then
        applyDebuff("target", "deadly_poison_dot", 12, math.min(5, (debuff.deadly_poison_dot.stack or 0) + 1))
      end
      if buff.instant_poison.up then
        applyDebuff("target", "instant_poison_debuff", 8)
      end
      if buff.wound_poison.up then
        applyDebuff("target", "wound_poison_debuff", 12)
      end
      if buff.crippling_poison.up then
        applyDebuff("target", "crippling_poison_debuff", 12)
      end
      if buff.mind_numbing_poison.up then
        applyDebuff("target", "mind_numbing_poison_debuff", 10)
      end
    end
  },

  -- Finishing move that disembowels the target, causing damage per combo point. 1 point : 273 damage 2 points: 546 damage 3 points: 818 damage 4 points: 1,091 damage 5 points: 1,363 damage
  eviscerate = {
    id = 2098,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 35 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return combo_points.current >= ( settings.combo_point_threshold or 4 ), "need finisher CP threshold" end,

    handler = function ()
      local cp = combo_points.current
      
      if buff.slice_and_dice.up then
        buff.slice_and_dice.expires = buff.slice_and_dice.expires + cp * 3
      end
      
      spend( cp, "combo_points" )
      -- Track for Relentless Strikes
      state.last_finisher_cp = cp
    end
  },


  hemorrhage = {
    id = 16511,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    -- MoP: Hemorrhage costs 30 energy (reduced by Shadow Focus while stealthed).
    spend = function () return 30 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    talent = "hemorrhage",
    startsCombat = true,
    
  
    usable = function () 
    
        return talent.hemorrhage.enabled, "hemorrhage talent not learned"
    end,

    handler = function ()
      gain( 1, "combo_points" )
      applyDebuff( "target", "hemorrhage", 24 )
      
      -- Apply/refresh poisons
      if buff.deadly_poison.up then
        applyDebuff("target", "deadly_poison_dot", 12, math.min(5, (debuff.deadly_poison_dot.stack or 0) + 1))
      end
      if buff.instant_poison.up then
        applyDebuff("target", "instant_poison_debuff", 8)
      end
      if buff.wound_poison.up then
        applyDebuff("target", "wound_poison_debuff", 12)
      end
      if buff.crippling_poison.up then
        applyDebuff("target", "crippling_poison_debuff", 12)
      end
      if buff.mind_numbing_poison.up then
        applyDebuff("target", "mind_numbing_poison_debuff", 10)
      end
    end
  },

  -- Finishing move that tears open the target, dealing damage over time. Lasts longer per combo point. 1 point : 8 sec 2 points: 12 sec 3 points: 16 sec 4 points: 20 sec 5 points: 24 sec
  rupture = {
    id = 1943,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      local cp = combo_points.current
      -- MoP Classic: 8 seconds base + 4 seconds per combo point
      applyDebuff( "target", "rupture", 8 + (4 * cp) )
      spend( cp, "combo_points" )
      -- Track for Relentless Strikes
      state.last_finisher_cp = cp
    end
  },

  -- Finishing move that cuts your target, dealing instant damage and increasing your attack speed by 40%. Lasts longer per combo point. 1 point : 12 sec 2 points: 18 sec 3 points: 24 sec 4 points: 30 sec 5 points: 36 sec
  slice_and_dice = {
    id = 5171,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = false,
    usable = function ()
      -- Keep SnD rolling; refresh early when it is down or about to expire (<3s) with any CP.
      if buff.slice_and_dice.remains < 3 and combo_points.current >= 1 then return true end
      -- Or use at threshold CP if it's down.
      if not buff.slice_and_dice.up and combo_points.current >= 1 then return true end
      return false, "slice_and_dice ok"
    end,

    handler = function ()
      local cp = combo_points.current
      applyBuff( "slice_and_dice", 6 + (6 * cp) )
      spend( cp, "combo_points" )
      -- Track for Relentless Strikes
      state.last_finisher_cp = cp
    end
  },

  -- Ambush the target, causing 275% weapon damage plus 348. Must be stealthed. Awards 2 combo points.
  ambush = {
    id = 8676,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 60 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) * ( talent.slaughter_from_shadows.enabled and (1 - 0.05 * talent.slaughter_from_shadows.rank) or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up), "requires stealth" end,

    handler = function ()
      gain( 2 + ( talent.initiative.enabled and talent.initiative.rank or 0 ), "combo_points" )
      
      if talent.find_weakness.enabled then
        applyDebuff( "target", "find_weakness" )
      end
      
      if talent.premeditation.enabled then
        applyBuff( "premeditation", 20 )
      end
    end
  },

  -- Talent: Allows use of abilities that require Stealth for 8 sec, and increases damage by 20%. Does not break Stealth if already active.
  shadow_dance = {
    id = 51713,
    cast = 0,
    cooldown = 60,
    gcd = "off",
    startsCombat = false,

    toggle = "cooldowns",

    handler = function ()
      -- Shadow Dance: Subtlety signature ability
      applyBuff( "shadow_dance", 8 ) -- 8 second duration
      
      -- Shadow Dance grants stealth-like benefits without breaking existing stealth
      -- Apply enhanced energy regeneration during Shadow Dance
      if not buff.stealth.up then
        -- Only apply if not already stealthed
        applyBuff( "stealth", 8 ) -- Grants stealth-like benefits
      end
      
      -- Apply Find Weakness buff for enhanced damage
      applyBuff( "find_weakness", 10 ) -- Slightly longer than Shadow Dance for overlap
    end
  },

  -- Talent: Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec.
  shadowstep = {
    id = 36554,
    cast = 0,
    cooldown = 24,
    gcd = "off",
    school = "physical",

    talent = "shadowstep",
    startsCombat = false,

    handler = function ()
      applyBuff( "shadowstep" )
      if buff.preparation.up then removeBuff( "preparation" ) end
    end
  },

  -- Throws a shuriken at an enemy target, dealing 400% weapon damage (based on weapon damage) as Physical damage. Awards 1 combo point.
  shuriken_toss = {
    id = 114014,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 40 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    talent = "shuriken_toss",
    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
    end
  },


  cheap_shot = {
    id = 1833,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function ()
      if talent.dirty_tricks.enabled then return 0 end
      return 40 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 )
    end,
    spendType = "energy",

    startsCombat = true,
    nodebuff = "cheap_shot",

    usable = function ()
  
      if settings.disable_stuns_on_boss and target.boss then 
        return false, "stuns disabled on boss fights (check settings)" 
      end
      return (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up), "not stealthed"
    end,

    handler = function ()
      applyDebuff( "target", "cheap_shot", 4 )
      gain( 2 + ( talent.initiative.enabled and talent.initiative.rank or 0 ), "combo_points" )
      
      if talent.find_weakness.enabled then
        applyDebuff( "target", "find_weakness" )
      end
    end
  },

  -- Finishing move that strikes the target, causing damage. If used during Shadow Dance, Cheap Shot is also performed on the target for no energy or combo points. 1 point : 12 damage 2 points: 24 damage 3 points: 36 damage 4 points: 48 damage 5 points: 60 damage
  deadly_throw = {
    id = 26679,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    talent = "deadly_throw",
    startsCombat = true,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      spend( combo_points.current, "combo_points" )
      
      if buff.shadow_dance.up then
        applyDebuff( "target", "cheap_shot", 4 )
      end
    end
  },

 -- Finishing move that causes bleeding damage to up to 4 nearby targets. Lasts longer per combo point.
  crimson_tempest = {
    id = 121411,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 35 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      local cp = combo_points.current
      applyDebuff( "target", "crimson_tempest", 4 + (2 * cp) )
      spend( cp, "combo_points" )
      state.last_finisher_cp = cp
    end
  },

  -- Instantly restores health based on your combo points and causes you to heal over time.
  recuperate = {
    id = 73651,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 30 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = false,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      local cp = combo_points.current
      applyBuff( "recuperate", 6 * cp )
      spend( cp, "combo_points" )
    end
  },

  -- Defensive and Utility Abilities
  
  -- You become 90% resistant to all spells for 5 sec.
  cloak_of_shadows = {
    id = 31224,
    cast = 0,
    cooldown = 60,
    gcd = "off",
    school = "physical",

    startsCombat = false,
    toggle = "defensives",

    handler = function ()
      applyBuff( "cloak_of_shadows", 5 )
    end
  },

  -- Increases your dodge chance by 50% and reduces damage taken by 50% for 5 sec.
  evasion = {
    id = 5277,
    cast = 0,
    cooldown = 90,
    gcd = "off",
    school = "physical",

    startsCombat = false,
    toggle = "defensives",

    handler = function ()
      applyBuff( "evasion", 5 )
    end
  },

  -- Reduces the damage you take from area of effect attacks by 40% for 6 sec.
  feint = {
    id = 1966,
    cast = 0,
    cooldown = 10,
    gcd = "totem",
    school = "physical",

    spend = 20,
    spendType = "energy",

    startsCombat = false,

    handler = function ()
      applyBuff( "feint", 6 )
    end
  },

  -- Causes the target to wander around for up to 10 sec.
  blind = {
    id = 2094,
    cast = 0,
    cooldown = 180,
    gcd = "spell",
    school = "physical",

    spend = 40,
    spendType = "energy",

    startsCombat = true,

    usable = function () return not debuff.blind.up, "target already blinded" end,

    handler = function ()
      applyDebuff( "target", "blind", 10 )
    end
  },

  -- Causes the target to face you for 3 sec.
  gouge = {
    id = 1776,
    cast = 0,
    cooldown = 10,
    gcd = "totem",
    school = "physical",

    spend = 45,
    spendType = "energy",

    startsCombat = true,

    usable = function () return not debuff.gouge.up, "target already gouged" end,

    handler = function ()
      applyDebuff( "target", "gouge", 4 )
    end
  },

  -- The next party or raid member to attack the target becomes the target's primary threat target.
  tricks_of_the_trade = {
    id = 57934,
    cast = 0,
    cooldown = 30,
    gcd = "off",
    school = "physical",

    startsCombat = false,

    handler = function ()
      applyBuff( "tricks_of_the_trade", 30 )
    end
  },

  -- Throws knives at all enemies within 10 yards, dealing damage and applying poison. Awards 1 combo point.
  fan_of_knives = {
    id = 51723,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 50 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
      
      -- Apply poisons to all targets hit
      if buff.deadly_poison.up then
        applyDebuff("target", "deadly_poison_dot", 12, math.min(5, (debuff.deadly_poison_dot.stack or 0) + 1))
      end
    end
  },

  -- Instantly kill the target with 35% or less health. If target is not killed, adds 5 combo points.
  marked_for_death = {
    id = 137619,
    cast = 0,
    cooldown = 60,
    gcd = "off",
    school = "physical",

    talent = "marked_for_death",
    startsCombat = true,

    handler = function ()
      if target.health.pct <= 35 then
        -- Instant kill (simulated by massive damage)
      else
        gain( 5, "combo_points" )
      end
    end
  },

  -- Increases damage and critical strike chance for 12 seconds.
  shadow_blades = {
    id = 121471,
    cast = 0,
    cooldown = 180,
    gcd = "off",
    school = "physical",

    startsCombat = false,
    toggle = "cooldowns",

    handler = function ()
      applyBuff( "shadow_blades", 12 )
    end
  },

  -- Utility and misc abilities
  
  -- Allows you to pick the target's pocket.
  pick_pocket = {
    id = 921,
    cast = 0,
    cooldown = 0.5,
    gcd = "off",
    school = "physical",

    startsCombat = false,
    
    usable = function () return (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up), "requires stealth" end,

    handler = function ()
      -- Pick pocket implementation
    end
  },

  -- Reduces the target's armor by 20% for 30 sec.
  expose_armor = {
    id = 8647,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      local cp = combo_points.current
      applyDebuff( "target", "expose_armor", 30 )
      spend( cp, "combo_points" )
    end
  },

  -- Creates a cloud of thick smoke in a 10 yard radius around the caster for 10 sec.
  smoke_bomb = {
    id = 76577,
    cast = 0,
    cooldown = 180,
    gcd = "spell",
    school = "physical",

    spend = 40,
    spendType = "energy",

    startsCombat = false,
    toggle = "defensives",

    handler = function ()
      applyBuff( "smoke_bomb", 10 )
    end
  },

  -- Distracts the target, reducing threat for 10 sec.
  distract = {
    id = 1725,
    cast = 0,
    cooldown = 30,
    gcd = "spell",
    school = "physical",

    spend = 30,
    spendType = "energy",

    startsCombat = false,

    handler = function ()
      applyDebuff( "target", "distract", 10 )
    end
  },

  -- Readies you for combat, increasing your chance to dodge by 100% for next 5 attacks.
  combat_readiness = {
    id = 74001,
    cast = 0,
    cooldown = 180,
    gcd = "off",
    school = "physical",

    talent = "combat_readiness",
    startsCombat = false,
    toggle = "defensives",

    handler = function ()
      applyBuff( "combat_readiness", 20 )
    end
  },

  -- Increases your movement speed by 70% for 4 sec.
  burst_of_speed = {
    id = 108212,
    cast = 0,
    cooldown = 30,
    gcd = "off",
    school = "physical",

    spend = 30,
    spendType = "energy",

    talent = "burst_of_speed",
    startsCombat = false,

    handler = function ()
      applyBuff( "burst_of_speed", 4 )
    end
  },

  -- When activated, the cooldown on your Vanish, Sprint, and Shadowstep abilities are reset.
  preparation = {
    id = 14185,
    cast = 0,
    cooldown = 300,
    gcd = "off",
    school = "physical",

    talent = "prep",
    startsCombat = false,

    toggle = "cooldowns",

    handler = function ()
      applyBuff( "preparation" )
      setCooldown( "vanish", 0 )
      setCooldown( "sprint", 0 )
      if talent.shadowstep.enabled then setCooldown( "shadowstep", 0 ) end
    end
  },

    -- Poison Application Abilities
  deadly_poison = {
    id = 2823,
    cast = 3,
    cooldown = 0,
    gcd = "spell",
    school = "nature",
    
    startsCombat = false,
    
    usable = function() 
      return not buff.deadly_poison.up, "deadly poison already applied" 
    end,
    
    handler = function()
      applyBuff("deadly_poison", 3600) -- Apply to weapon for 1 hour
    end,
  },
  
  instant_poison = {
    id = 8680,
    cast = 3,
    cooldown = 0,
    gcd = "spell",
    school = "nature",
    
    startsCombat = false,
    
    usable = function() 
      return not buff.instant_poison.up, "instant poison already applied" 
    end,
    
    handler = function()
      applyBuff("instant_poison", 3600) -- Apply to weapon for 1 hour
    end,
  },
  
  wound_poison = {
    id = 8679,
    cast = 3,
    cooldown = 0,
    gcd = "spell",
    school = "nature",
    
    startsCombat = false,
    
    usable = function() 
      return not buff.wound_poison.up, "wound poison already applied" 
    end,
    
    handler = function()
      applyBuff("wound_poison", 3600) -- Apply to weapon for 1 hour
    end,
  },
  
  crippling_poison = {
    id = 3408,
    cast = 3,
    cooldown = 0,
    gcd = "spell",
    school = "nature",
    
    startsCombat = false,
    
    usable = function() 
      return not buff.crippling_poison.up, "crippling poison already applied" 
    end,
    
    handler = function()
      applyBuff("crippling_poison", 3600) -- Apply to weapon for 1 hour
    end,
  },
  
  mind_numbing_poison = {
    id = 5761,
    cast = 3,
    cooldown = 0,
    gcd = "spell",
    school = "nature",
    
    startsCombat = false,
    
    usable = function() 
      return not buff.mind_numbing_poison.up, "mind numbing poison already applied" 
    end,
    
    handler = function()
      applyBuff("mind_numbing_poison", 3600) -- Apply to weapon for 1 hour
    end,
  },
  
  -- Apply Poison (generic poison application)
  apply_poison = {
    id = 2823, -- Deadly Poison spell ID (updated for MoP)
    cast = 0,
    cooldown = 0,
    gcd = "spell",
    
    startsCombat = false,
    
    usable = function()
      -- Check if deadly poison is missing (for SimC lethal=deadly,nonlethal=crippling)
      return not buff.deadly_poison.up, "deadly poison already applied"
    end,
    
    handler = function()
      -- Apply deadly poison as lethal and crippling poison as nonlethal
      -- This matches the SimC priority: apply_poison,lethal=deadly,nonlethal=crippling
      applyBuff("deadly_poison", 3600)
      applyBuff("crippling_poison", 3600)
    end,
  },
  
  -- 添加冲刺技能（之前可能遗漏了）
  sprint = {
    id = 2983,
    cast = 0,
    cooldown = 180,
    gcd = "off",
    school = "physical",
    
    startsCombat = false,
    
    handler = function()
      applyBuff("sprint", 8)
    end,
  },
  
  -- 添加肾击技能（终结技）
  kidney_shot = {
    id = 408,
    cast = 0,
    cooldown = 20,
    gcd = "totem",
    school = "physical",
    
    spend = function () 
      return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) 
    end,
    spendType = "energy",
    
    startsCombat = true,
    usable = function () 
      return combo_points.current > 0, "requires combo points" 
    end,
    
    handler = function ()
      local cp = combo_points.current
      applyDebuff( "target", "kidney_shot", 1 + cp )
      spend( cp, "combo_points" )
      state.last_finisher_cp = cp
    end
  },
  
  -- 添加闷棍技能
  sap = {
    id = 6770,
    cast = 0,
    cooldown = 0,
    gcd = "spell",
    school = "physical",
    
    spend = function ()
      if talent.dirty_tricks.enabled then return 0 end
      return 40 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 )
    end,
    spendType = "energy",
    
    startsCombat = false,
    
    usable = function () 
      return (buff.stealth.up or buff.vanish.up or buff.shadow_dance.up), "requires stealth" 
    end,
    
    handler = function ()
      applyDebuff( "target", "sap", 60 )
    end
  }
} )

spec:RegisterOptions( {
  enabled = true,

  aoe = 3,
  cycle = false,

  nameplates = true,
  nameplateRange = 10,
  rangeFilter = false,

  canFunnel = true,
  funnel = false,

  damage = true,
  damageExpiration = 6,

  potion = "virmen_bite_potion",

  package = "敏锐Simc",
} )


spec:RegisterSetting( "use_shadow_dance", true, {
    name = strformat( "使用%s", Hekili:GetSpellLinkWithTexture( 51713 ) ), -- Shadow Dance
    desc = "如果勾选，将根据敏锐Simc优先级推荐使用暗影之舞。未勾选，则不会自动推荐该技能。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "use_shadow_blades", true, {
    name = strformat( "使用%s", Hekili:GetSpellLinkWithTexture( 121471 ) ), -- Shadow Blades
    desc = "如果勾选，将根据敏锐Simc优先级推荐使用暗影之刃。未勾选，则不会自动推荐该技能。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "dance_min_rupture", 10, {
  name = "暗影之舞的最低割裂持续时间",
  desc = "推荐使用暗影之舞前所需的割裂剩余持续时间（秒）。",
  type = "range",
  min = 0,
  max = 18,
  step = 1,
  width = 1.5
} )

spec:RegisterSetting( "allow_shadowstep", true, {
  name = strformat( "允许使用%s", Hekili:GetSpellLinkWithTexture( 36554 ) ), -- Shadowstep
  desc = "如果勾选，当条件满足时，插件将推荐使用暗影步。若未勾选，则不会自动推荐该技能。",
  type = "toggle",
  width = "full"
} )

spec:RegisterSetting( "energy_threshold", 75, {
    name = strformat( "爆发能量阈值" ),
    desc = "使用暗影之舞等主要爆发技能前所需的最低能量值（范围50-100）。",
    type = "range",
    min = 50,
    max = 100,
    step = 5,
    width = 1.5
} )

spec:RegisterSetting( "auto_poison_apply", true, {
    name = strformat( "自动应用毒药" ),
    desc = "如果勾选，当缺少毒药时，插件将推荐应用毒药。若未勾选，则必须手动管理毒药应用。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "use_tricks_of_the_trade", true, {
    name = strformat( "使用%s", Hekili:GetSpellLinkWithTexture( 57934 ) ), -- Tricks of the Trade
    desc = "如果勾选，将根据敏锐Simc优先级推荐使用嫁祸诀窍。未勾选，则不会自动推荐该技能。",
    type = "toggle",
    width = "full"
} )

-- 新增设置选项
spec:RegisterSetting( "hemorrhage_pandemic_time", 6, {
    name = "出血DoT刷新时间阈值",
    desc = "当出血DoT剩余时间少于此值（秒）时开始刷新。建议6-9秒以利用pandemic机制。",
    type = "range",
    min = 3,
    max = 12,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "prefer_backstab", true, {
    name = "优先使用背刺获取连击点",
    desc = "如果勾选，在能够使用背刺时优先使用背刺而不是出血来获取连击点。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "combo_point_threshold", 4, {
    name = "终结技连击点阈值",
    desc = "使用终结技所需的最低连击点数量。建议4-5点以获得最佳效率。",
    type = "range",
    min = 1,
    max = 5,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "maintain_slice_and_dice", true, {
    name = "自动维持切割",
    desc = "如果勾选，插件将自动推荐维持切割buff。这对于DPS输出非常重要。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "maintain_rupture", true, {
    name = "自动维持割裂",
    desc = "如果勾选，插件将自动推荐维持割裂DoT。这是敏锐贼的重要伤害来源。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "stealth_opener_priority", true, {
    name = "潜行开场优先级",
    desc = "如果勾选，在潜行状态下将优先推荐开场技能（如伏击、绞喉等）。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "energy_pooling", true, {
    name = "能量储备管理",
    desc = "如果勾选，插件将在某些情况下建议储备能量以便使用重要技能。",
    type = "toggle",
    width = "full"
} )


spec:RegisterSetting( "strict_positioning", false, {
    name = "严格位置检查",
    desc = "如果勾选，将严格检查背刺位置要求。未勾选时，假设玩家能够正确定位（推荐用于BOSS战斗）。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "disable_stuns_on_boss", false, {
    name = "BOSS战斗中禁用眩晕技能",
    desc = "如果勾选，在BOSS战斗中将不推荐使用偷袭等眩晕技能。未勾选时，正常推荐所有技能。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "boss_fight_mode", false, {
    name = "BOSS战斗模式",
    desc = "如果勾选，将启用专门针对BOSS战斗优化的技能循环。这会调整某些技能的使用优先级。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "allow_all_generators", true, {
    name = "允许所有连击点生成器",
    desc = "如果勾选，将允许使用所有可用的连击点生成器（背刺、出血等），不进行严格的优先级限制。推荐用于BOSS战斗。",
    type = "toggle",
    width = "full"
} )


spec:RegisterPack( "敏锐Simc", 2025100, [[Hekili:9Iv)RXnot4)wchSKWf87UoR30EKnq7XlxBHwkNl0FZ2AT1M1S2wgl5uwi4)2Vrs(djBjNnT5UFOLn6JN5XZ8mJgPGvbFlWpbXWbFXDPR3QLlFRJR7A3v3e4ZovId8lrXhrpa)OaLd)VF9owgMDIpXPmckHdaLuxfdtg4VRonJ9XIGDgq9M34DlS2sCmm8Mvb(hstsWY1IPXb(F7qkTjI)putuRDBIi7H)oMLskAIYsPmy69KQMOpGpMML6aePISpndm)V1e93KhQX)rtuhnBIU8ZKV2e5545S6QMOMpbl69ikobaga87KV7NMdqkw1WUe40eLJJpGksJ5uQa2Y3wT5dCQXy4QcAZNa4a8(AfoMKVdXAIENGOWmsgtDk7M733()2NHOhVM7w3slRslEiCxgHsj52wpHK0UCmkmh(2dRsJXHfW4zylBcvwMDkSKKsjfxdFmhqzBtWOKStxxqkAhiUkfwgWaZyuseUBZZvHZXjPmeFQRt3VLHYWfmhTXDWfODzGt2ieuggLXoyEYCu1rCsieIdbAZoOyIXt9mwjJ7RGWwyc8dom8PiCxtbJE)2vDHVpJslMg5aeoMgFuA(QhWmNyeLP6Y6Du81SRE)EhiCcrMAkZPcdl6PNA3jlnhhYiarW3TEPka1uCykdNFnnJW2cATeApA0dOeYpctqfXyN6sJO5odAmqIDeZwzhq1r3LHGSWFb74(6BhH)mCFD1jByRTACffxDecrNZQrvXOcUDRQaTfFh4cC1dNUBJgfafvjQQxSFHa2hHAc0daGlIjKmWcfDdbjbGAIE)MLlgYl6ayqVcQU)KubfyQiYegvtwvxek)RqE9UR5fE3IicjmF8hXHavZtXGi(g1ngJYYMUZokQjTNMCi9xAd391C3MftsDuPBjRUYqcM3IlViHa5cYfaX5yEW5PNuhSZeRVAXu5W9R0IfhW5q06aCQGsrHHb7CVTMvzcnlRm(GXvnd(XuAmgczg)Muj)ifv(UA6bBApnx4DEAcx4OokdTBS5UZBHutcXzpr1kUSzC00PpaZJRkgLdhfZ41SG8niLvDYEKV1BXfTfKXjoGcAHjLaWFdrnqjS0mpKPddzv3VDTNUhyR7y72NlP556mLnlPvwrrxOxUPtAyYFixYIlTu0fKJqzjl1YVAosbFELAbb4ReWEyYfACLpsprBTwcKgZPc4PDBvaVJ8)hmkuw4vmBUfoO7GCO7HqOcFjMYMMfSEX46qRxiY5gTZUeVXgy2mSXl(NlTQDZ7rfHK9Hhla2snKFzOEQWj)xCzlcoCqjp7H(X(5AtrJQBxAb4ZTi3OpKFLAE6e4mRgzCV0d1vPhXGaa6RvlzuzCBFcTN)UEzG)JWr5a69xFaUnYpqvf8KOa)pMxsQy8o49gDZaNMpf4l(L4An49O6mg8ZViUMtRzdEFGpOtHo4trWLC06TlWxIxGpV3VagqaR70uhFnrp9ut00kfnr31eX)W6Gx24i3a3mYaDRq0l4e7nUHM5SNlypEdADybgBTfJ11Q45zpJTZDMuP3saB8MNnU)NXgxoB2mFKEKThy7qtQCuU9NfL(Mx5O8gROitseFgBu0t6DZYH4TwH4IwFwFxSnrlAIS0jBt09CljwI9oAve2dtYzXQLJOb)M(WLpLlwVh4bqg1bSk51lydSBBt0nYK(q5luaf(fwECoFh4J7swBZ9hIlG4zs(nF(Qm206thkWjP6QbEOVBH9gxlyWEtrYtyHlBIGWPHUSLjag6ztwkQj6Q2q60meiGVAPAWqSFbbhx)qToQLdQgrZPNqnW0PNs1twL6I9lsWOX1qEExMEd8dap0uIa4xw5adHBG5EkjOIUyeiBVeXuae42LZl06ky2DsDapH3V)TpmDGN8DF4PF8xcsHwkVwuGF)dejiL8fI6peC0rxkOB4uSjcdJppKwzJHP7pPQpvrEpHr20EO)zAeBa4XRy(ZbEzPZmzPidbdlBrV2i0M)RtbNzBIz6gwlaYuzw5mT5Xw60xPmR(cMxKyix1wIP9sq)I5LNBLK(0slhf1HS2vpK6HHELNtwmruQlmgUAYlqYBWpaSD58IJ5RPBXR8VwP(Zv98skBoJAAUBUm33VsdAQn8RHJunm0RXC1iu0Zt6EQB)k026d(mXLCRxx(S2ZWig08tan54ZHEe3k6zyw1KQTx7zYfct4ANtZ(8qt6Ar2f7zD0KXxksys7VwuNuFMlLbTu1EBJN5wHAAEnRmVc16ZkP2S(0NwsTVVUNxQnc6oMh89jeR8dZQzhivb((517bPSyWG)5d]] )

spec:RegisterPack( "敏锐(黑科研)", 202511171, [[Hekili:fJv3QXTru4NLLcl2uZ2vRxzhx8AiTeAAGecvbYfHiPzLM1Ry1QzrZihmyeHwAjKBAkTLEzjxuO0B6TLs7ttJdPVf9mJ(BgPzKTJn0lsW7mJoNV5873zCTCFKRtiIHDFWKXtSTSS2FK1UJpWAIRd70nyxNnOGvOJH)ibTg()3(JF7)(dVARZ)(V78x96T5BFAmbfYfdLKLgahX1zEwum7ZtCN3w2WH2GdGFVNLRZYOWqCXHW0axNhTmIM7Z)hk3VuT5(KfWVdyrKKC)4ikd2Ebjn3)U4vrXrJaeKswefd69dY9)cYXz4po33jBolgZon3FR7tEyUV9i7rwBN7NFp4qFcIIdbbdc8XKh7eTgeP4unFLqo5(RXblrjrbCiLaFYJS27UCOXy40eA(9aXbY7HP4aY65iwU)Tfaf2PaX0rBQ27dN9rlIr0v7WTQZOBsJso2BEmHsjRnDEcjS84yK3A4U7LgfG9sG1JXg(i0MnXN6THerjj7axMLO4zHyuy8P7KqskxiincogGa9YydryU1VxkEnomIH4BTt0IzmumoHnsz9r4e08yWiRveuggfZwQFZ1O0v4qpWf7bWMTusfT36c0sm3wbUnVq4p4IHVfHBAsy0JMzv5(UpkkPRNdKWQOGvfQp9ymBuaIYKnz1gk(zMNTyXiWDcEMmkBukgo0zNv(LSO1ypgbac(WPJLfqgf7fXWR3HgtyZGyTqAT0OlrHKN5fIscWJY2OvAt6rAmieBfMzzwGYRopgbzHxd9m5Mxpc7P3IS0tnjBLtJtP40vGl6YCAuAakHR30ui2I)f4eC6XNE4EkqaIO2GsRd2hie7jqnb6sqGddiKyqdjvlbjbq0e9O9gpSjVOsanXRqu3NssHcmPKIegzvMML4v8lpE9UD41DNHiIqy(6NG9aOUocdbX7k)HbO44UFzfevcT7MCuyVuwU62C4Ed7K6id3nSSunjy2d3AqibYfkoa4Nd4oNZotEXkvmD7HDdhoYsXxSeVg8wlHUcsffAwSY8wQwPnu0S06nkxwn4tIObyWLP9ojd(wruRNNrxAk2tXeEOTsGl0QJYqZBRUdThwetc(zBr1kEytBV5OAhm3VkPuU4OygVMfKVbPSYBwl59ThoOSGmoCeebnuxKaGFnEnisySECuKo0KvD0SP2QwGztAR36CjflxLQmPjLYksXfQLBQcn0zpkoYWTmu0fchHYsgQLVDFGcUEBuCcWTeKDZMdvWkFLAGwQTqinMdfWspPmc42K70OuOSWny2CP4a2bRb2dEqf(nykRBwW0HTRdnDOiNR1xwL41wb9MH1(WVFPvLF8cuIhzH3QeaTun5xAQNkmYFgpSfbnhKYZoUET3pAkkqD2ydc(YwKR1f56uZtfaxYQrA)w6YS0Ovyiaa41QKmkTUPRqz)3PJDDobALdsxEUHNHst4jrWeiV4vN)YF(8F)Vo)R)L38NFJ9B(JF7TV85V7R(7ZFXp9Ux)R)ZZ)Y8756igvqmCdEbklMb)5ded7uQD3pX1bcxbI8riyuhfkEUof3oxhofqxgGdJFPoIF5(NDwUF3cg5(hM7ZVFvIVG)ixb7kRG5DuqBIm9PGjskqWOeg6c4Pv9dqztBDBQoDBceYWqntbu0mqtfMzVIjdRlaYvHDL9MPvtfj1DVMfnee3WH5(dQQcI57(KBDW(7B)uytUc2RFfCmkf4wHL1GOa)tSS2DY(pT2gwS2(3AkFPT1O1rLsQuT73FGqh)eip5WCHdYUJDae8TUIcUc8D4vFPJnQMpOk8O(3aAo4)l0mPfAMWrJ14ReCAeAZaecXyo))cet9KfcXyUyqrjmXDBpP7M6SgczSRrzmO0swpKrzqK2bnY9pIRkXrmpWHubNMnfWODLa(dXKgTP4WQJO0iKwdO0xvIJGQe7QuLa6ll0S9f4l0YDPWYQjRIRhly9bQ54nywvEceSNre0v22cDUfuCi3xZmnfr5AyixuXp3F7spu30GJ4Pbf1DmH9szkaT56pAbDFMKgwycjBUau3cyY3g1IZn37z7k1gQM)HqvMRUOtv6moI1m0sQoRTKiJlpJZP(PH0reO4Lo1(kBsDhRE0SYxxthVG6mEPxHdc)fV6gp7I)oCUo1peNKqRjb0IBGK0105wMbJ5NHtj)Vz7Q(06UaLDIR602Ronr4TrATpr)DsVUP2G3UHv6fX7R)xwSBLganJ75IPwbTzmI(jrAiS)6f0)aZ9y6JwUbolILL6VjtJvrovHP9qoRgK3afzUsMjrSrdp1sqEL5Pkffw6wVAmr1G3EjDA2rA89DuCxWu1fTy02HQP)2G227dSgpXQgJgBFjhj0aHoSjKgpWCDSgmZJX0fmY9KvWv5fKGf79nKeO1A8n0vTGiMUAOAYZ08wuc9y(9OQiC0Z4Fa4kPrFbdCc8p64Ik0s)13n(WvY8n7(4vkjULpGvzD8jTXb)7ksl5edV5siV8087RE3adXiDWtVjPV3eAn2JtnZ62K70FoLj(SAzRxLE0Z75PWjs(a9NnObgMyJEbt3lXN8gSfI0ZpCviOCyVMZgqR8wKIyEEuFgBjj11XzD2cOhQyr3)7]] )



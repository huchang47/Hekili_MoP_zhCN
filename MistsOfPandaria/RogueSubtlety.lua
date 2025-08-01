-- RogueSubtlety.lua
-- Mists of Pandaria (5.4.8)

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class, state = Hekili.Class, Hekili.State

local insert, wipe = table.insert, table.wipe
local strformat = string.format
local GetSpellInfo = ns.GetUnpackedSpellInfo

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
            return not state.combat -- Only active in combat
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
    
    -- Relentless Strikes energy return (enhanced for Subtlety)
    relentless_strikes_energy = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Relentless Strikes: Enhanced for Subtlety with stealth bonuses
            if state.talent.relentless_strikes.enabled and state.last_finisher_cp then
                local energy_chance = state.last_finisher_cp * 0.05 -- 5% chance per combo point (enhanced for Subtlety)
                local stealth_bonus = (state.buff.stealth.up or state.buff.vanish.up or state.buff.shadow_dance.up) and 1.5 or 1.0
                return math.random() < energy_chance and (25 * stealth_bonus) or 0
            end
            return 0
        end,
    },
    
    -- Find Weakness energy efficiency bonus
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
        
        -- Haste scaling for energy regeneration (minor in MoP)
        local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
        
        -- Subtlety gets enhanced energy efficiency in stealth
        local stealth_bonus = 1.0
        if state.talent.shadow_focus.enabled and (state.buff.stealth.up or state.buff.vanish.up or state.buff.shadow_dance.up) then
            stealth_bonus = 1.75 -- 75% bonus energy efficiency while stealthed (stronger than other specs)
        end
        
        -- Master of Subtlety energy efficiency
        local subtlety_bonus = 1.0
        if state.buff.master_of_subtlety.up then
            subtlety_bonus = 1.10 -- 10% energy efficiency bonus
        end
        
        return base * haste_bonus * stealth_bonus * subtlety_bonus
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
            return (state.last_cast_time and state.last_cast_time.premeditation) or 0
        end,
        interval = 1,
        value = function()
            -- Premeditation generates 2 combo points when opening from stealth
            if (state.last_ability and state.last_ability == "premeditation") and (state.buff.stealth.up or state.buff.vanish.up) then
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
  
} )

-- Auras
spec:RegisterAuras( {
  -- Abilities
  blind = {
    id = 2094,
    duration = 60,
    max_stack = 1
  },
  combat_readiness = {
    id = 74001,
    duration = 10,
    max_stack = 5
  },
  evasion = {
    id = 5277,
    duration = 10,
    max_stack = 1
  },
  feint = {
    id = 1966,
    duration = 5,
    max_stack = 1
  },
  kidney_shot = {
    id = 408,
    duration = function() return 1 + min(5, effective_combo_points) end, -- MoP Classic: 1s base + 1s per combo point (correct)
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
    duration = function() return 6 + (6 * min(5, effective_combo_points)) end, -- MoP: 6s base + 6s per combo point.
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
    duration = function() return 8 + (4 * min(5, effective_combo_points)) end, -- MoP Classic: 8s base + 4s per combo point
    max_stack = 1
  },
  deadly_poison = {
    id = 2818,
    duration = 12,
    max_stack = 5
  },
  crippling_poison = {
    id = 3409,
    duration = 12,
    max_stack = 1
  },
  mind_numbing_poison = {
    id = 5760,
    duration = 10,
    max_stack = 1
  },
  
  -- Find Weakness - Subtlety signature debuff/buff
  find_weakness = {
    id = 91021,
    duration = 10,
    max_stack = 1
  },
  
  -- Shadow Clone - enhanced Shadow Dance effect
  shadow_clone = {
    id = 159621,
    duration = 8,
    max_stack = 1
  },
  
  -- Talents
  master_of_subtlety = {
    id = 31665,
    duration = 6,
    max_stack = 1
  },
  find_weakness = {
    id = 91021,
    duration = 10,
    max_stack = 1
  },
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

-- Abilities
spec:RegisterAbilities( {
  -- Stab the target, causing 632 Physical damage. Damage increased by 20% when you are behind your target. Awards 1 combo point.
  backstab = {
    id = 53,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 60 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) * ( talent.slaughter_from_shadows.enabled and (1 - 0.04 * talent.slaughter_from_shadows.rank) or 1 ) end,
    spendType = "energy",

    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
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
    usable = function () return combo_points.current > 0, "requires combo points" end,

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

  -- An instant strike that damages the target and causes the target to hemorrhage, dealing additional damage over time. Awards 1 combo point.
  hemorrhage = {
    id = 16511,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 35 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) * ( talent.slaughter_from_shadows.enabled and (1 - 0.03 * talent.slaughter_from_shadows.rank) or 1 ) end,
    spendType = "energy",

    talent = "hemorrhage",
    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
      applyDebuff( "target", "hemorrhage", 24 )
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
    usable = function () return combo_points.current > 0, "requires combo points" end,

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
    usable = function () return stealthed_all, "requires stealth" end,

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

    talent = "shadow_dance",
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
      
      -- Shadow Clone effects if talented (MoP mechanic)
      if talent.shadow_clone and talent.shadow_clone.enabled then
        applyBuff( "shadow_clone", 8 )
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

  -- Stuns the target for 4 sec. Awards 2 combo points.
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
      if boss then return false, "cheap_shot assumed unusable in boss fights" end
      return stealthed_all, "not stealthed"
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
  }
} )

-- Proper stealthed state expressions for MoP compatibility
spec:RegisterStateExpr("stealthed_rogue", function() return buff.stealth.up end)
spec:RegisterStateExpr("stealthed_mantle", function() return false end) -- Not available in MoP
spec:RegisterStateExpr("stealthed_all", function() return buff.stealth.up or buff.vanish.up or buff.shadow_dance.up end)

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

  potion = "draenic_agility",

  package = "Subtlety",
} )

spec:RegisterPack( "Subtlety", 20250406, [[Hekili:TZv3Unom4FPB4dQDKQ(ovYLlr9QKCe4rnCvzUCBkQu8zJV3xRy3o2oKf1TojBwKC0AuXCTY)NUo8dZFcvz9Pih73(zAA94b7nzJn69Gzxi9Xh3FjGFAT)gU1Y0oF7n8XW)IbcEJEw8nC5PtEJd57w4G8CkUhF99I3Mx4u(BVN6LNMwbJ)fmolp3rj)YMZYj97X67mRZO8L7o(Z88Yy)xhxEhgpN(Cl4uGOWEZlxpJVCgDjwEgCXgqG92UqV4ooFJRmGR0MpFOTU)NsZm21z94Pco2f8UdcCrlUYXZhf76QKKYZtmUvxP6nrZwB1YEMTYFGtgYYYfGQK66yIwKEK8A51dT9Ys4HsPNKDPpGZyWEJpbMwLyBU3(yPG2Ev0NVl3aAUTJCUTPZ(UGxKG5W9)DdkGOMk4u4HZ)2bGEF6OFQ04g(NdzR9jgBf)M6vZ6JoswmQUPOmk1cMnjPeUjG7s9NKOMC)mjj9KuY1)Gu(OZ9FbWQIJf(gblB(sgpXmLW0vkwW03EsKbxlEYGhVdw98rTm)gKP(LLuEBjB(0gVs)4acUd)xbxvKfTm3LsGdUkygkxqyeQa0GqhZx9)uJHrwb(gMJyWVyXJBiIdTIVOl4FeN2YZAJJyGQ30ZKBu8MYHmcI3N(WGTfNcgTl2jy2Y28YUX65CjmMBZYlPiMmYlPdZS3WKSlYE)1Nck3SL0rqLkYc87gFIdPi1o0JKE9LsyWENzOBzILEXzMnBglZZR4G30Lh4r)YjMgwJEPz4cNbS7kMqZZZIKYoXqwFJspjRnzQ8h9kRHsv68iUPsQGiokI09Wj6vePRBzZsYm2)cKprgqoqaUEVkLyvPJuDLBXb8J5OXCVZSGZyWGbcMTrg9Qai4vDrE(CcK)P4uj3wFd27Ij5bfUG9HuqZdQ6vr1sbCfaFHLu4rL8d90yJxeNVHKSbUdPPNuoZEPsV9i3YyQFHFgCsB6h9wqwUZ7bCbeBJ4EXP9eDUvdvCFimVCYAZCFZVP1(iMpYtb1UfhcQVW16y1sJJN)bOBTwTJCc4Y4bYVhOGPeIjDUfFk(x)X0Gw3lFqvbw9Q0DWl7z5kNjSCszh2MwY9E1nUZIWZU(ByEFGK1qN4vwJVGX7Z5Tz9b28mPQFUTlm(3UD)qOsGgPZW2LrLAO1S9UPFqDgPo7qVvzixAHqcDd2sSvEuQaHBvJZTr6dCkr(lQpbq)SkOBHFQpZqkNWl0(h9MsDg0KCcYKjX7EqVVA9UFAvqZ9GXIBnP9(Q5J6kkFZkBbxHzXZgF(xFMbgIHyHMM(IfnW9oVtq5UEA0iOGcuaXNyYvXUQ2TpZOcuLJxJF6GQQFHEMklHhESRvmtGsQNMIxwgbQlGXSsjE)9zQWYErbmJpqK9sQOzDnxC5bLe0Lv5MxQK7sOEiEXI6lvb3bFw7fYSyI)yiPdFjHPIlFzIc8YMSXaFb01jrFzC4(hq10yNK21yiWdL0c7wK)7YW9I9(PjnF6WVrAZ2HdgYiKSA1kXIXOlIVAl2XuUonjlPB67yqp1gXA53DWBRCJAzDsUG7cwI87dDH(HdUXaAJ9wNbI8Vir4X6QfYgYVuQsGcjEXbgw)BO9Fh9fQGvS3JqEptLFwkwjwk(XpRvPFwSAX0NRFy(VCixF9PuDZZ89V5vbRK6I83GfDXkbV35Io0qfDGMZsCg83k07X3i1T1E2LLnVNn)FbKfYyMJj8uRZs6X7r3W9lzSa)y1WgmxrPMTmFZMVz)mGCEHxvwjG(hERUxTnR2lxiKlZgb29sBwQu1x53d8Vy7OQfr(dqupD6Wvx8GVyYcmIJ(pTtqKvnR91a3HoEZj)1LFaQyqpb5nz5ZZ4VtQI9gCUY9ztTY1s9fEUkRx8X1xVljZgpG4hL0VZMEKFLSk(t3I0VlnZVLt)2nKhE4U2kn09C35EpGlfP1HNVvlnm1)KORMmRcDVb5dQRVlGOblCXt9x3z1mWVS2uynKMdW1FJKr0Fo8OXWUKIFZlk90kvjLwVlkffN)XjPo2V0uAJnmDyf8kB3DpVh2Kju09Zs2GU1sBLuOIQFvT11klkjOVkd2H8N9Og5WtlpbFFxZ)2Xf3eMLaLPAuF7O2XVEJ9m0FU4Vo4Cf6pQi4xmOWQdLh24MFoxoW6S)5TFvxWVpR2lKGlZ33uSR1bCLFzvL)UVFQL)WL5MdRxlsGH)6q9D)XaH)hCEWap8v3QWrGHdaY)Wbm4z9)]] )





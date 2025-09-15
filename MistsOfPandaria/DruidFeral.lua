-- DruidFeral.lua
--july 2025 by smufrik
-- DruidFeral.lua loading

-- MoP: Use UnitClass instead of UnitClassBase

local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then 
    -- Not a druid, exiting DruidFeral.lua
    return 
end
-- Druid detected, continuing DruidFeral.lua loading

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization(103, true)

spec.name = "Feral"
spec.role = "DAMAGER"
spec.primaryStat = 2 -- Agility

-- Use MoP power type numbers instead of Enum
-- Energy = 3, ComboPoints = 4, Rage = 1, Mana = 0 in MoP Classic
spec:RegisterResource( 3 ) -- Energy
spec:RegisterResource( 4 ) -- ComboPoints 
spec:RegisterResource( 1 ) -- Rage
spec:RegisterResource( 0 ) -- Mana


-- Add reset_precast hook for state management and form checking
spec:RegisterHook( "reset_precast", function()
    -- Set safe default values to avoid errors
    local current_form = GetShapeshiftForm() or 0
    local current_energy = -1
    local current_cp = -1
    
    -- Safely access resource values using the correct state access pattern
    if state.energy then
        current_energy = state.energy.current or -1
    end
    if state.combo_points then
        current_cp = state.combo_points.current or -1
    end
    
    -- Fallback to direct API calls if state resources are not available
    if current_energy == -1 then
        current_energy = UnitPower("player", 3) or 0 -- Energy = power type 3
    end
    if current_cp == -1 then
        current_cp = UnitPower("player", 4) or 0 -- ComboPoints = power type 4
    end
    
    local cat_form_up = "nej"

    -- Hantera form-buffen
    if current_form == 3 then -- Cat Form
        applyBuff( "cat_form" )
        cat_form_up = "JA"
    else
        removeBuff( "cat_form" )
    end
    
    -- Removed workaround sync - testing core issue
end )

-- Additional debugging hook for when recommendations are generated
spec:RegisterHook( "runHandler", function( ability )
    -- Only log critical issues
    if not ability then
        -- Nil ability passed to runHandler
        return
    end
end )

-- Debug hook to check state at the beginning of each update cycle
spec:RegisterHook( "reset", function()
    -- Minimal essential verification
    if not state or not state.spec or state.spec.id ~= 103 then
        return
    end
    
    -- Basic state verification - level check
    if level and level < 10 then
        return
    end
end )

-- Talents - MoP compatible talent structure
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    feline_swiftness               = { 1, 1, 131768 }, -- Increases movement speed by 15%.
    displacer_beast                = { 1, 2, 102280 }, -- Teleports you forward and shifts you into Cat Form, removing all snares.
    wild_charge                    = { 1, 3, 102401 }, -- Grants a movement ability based on your form.

    -- Tier 2 (Level 30) - Healing/Utility
    yseras_gift                    = { 2, 1, 145108 }, -- Heals you for 5% of your maximum health every 5 seconds.
    renewal                        = { 2, 2, 108238 }, -- Instantly heals you for 30% of your maximum health.
    cenarion_ward                  = { 2, 3, 102351 }, -- Protects a friendly target, healing them when they take damage.

    -- Tier 3 (Level 45) - Crowd Control
    faerie_swarm                   = { 3, 1, 102355 }, -- Reduces the target's movement speed and prevents stealth.
    mass_entanglement              = { 3, 2, 102359 }, -- Roots all enemies within 12 yards of the target in place for 20 seconds.
    typhoon                        = { 3, 3, 132469 }, -- Strikes targets in front of you, knocking them back and dazing them.

    -- Tier 4 (Level 60) - Specialization Enhancement
    soul_of_the_forest             = { 4, 1, 102543 }, -- Finishing moves grant 4 Energy per combo point spent and increase damage.
    incarnation_king_of_the_jungle = { 4, 2, 114107 }, -- Improved Cat Form for 30 sec, allowing all abilities and reducing energy cost.
    force_of_nature                = { 4, 3, 106737 }, -- Summons treants to attack your enemy.

    -- Tier 5 (Level 75) - Disruption
    disorienting_roar              = { 5, 1, 99 },      -- Causes all enemies within 10 yards to become disoriented for 3 seconds.
    ursols_vortex                  = { 5, 2, 108292 },  -- Creates a vortex that pulls and roots enemies.
    mighty_bash                    = { 5, 3, 5211 },    -- Stuns the target for 5 seconds.

    -- Tier 6 (Level 90) - Major Enhancement
    heart_of_the_wild              = { 6, 1, 102793 }, -- Dramatically improves your ability to tank, heal, or deal spell damage for 45 sec.
    dream_of_cenarius              = { 6, 2, 108373 }, -- Increases healing or causes your next healing spell to increase damage.
    natures_vigil                  = { 6, 3, 124974 }, -- Increases all damage and healing done, and causes all single-target healing and damage spells to also heal a nearby friendly target.
} )



-- Ticks gained on refresh (MoP version).
local tick_calculator = setfenv( function( t, action, pmult )
    local state = _G["Hekili"] and _G["Hekili"].State or {}
    local remaining_ticks = 0
    local potential_ticks = 0
    local remains = t.remains
    local tick_time = t.tick_time
    local ttd = min( state.fight_remains or 300, state.target and state.target.time_to_die or 300 )

    local aura = action
    if action == "primal_wrath" then aura = "rip" end

    local class = _G["Hekili"] and _G["Hekili"].Class or {}
    local duration_field = class.auras and class.auras[ aura ] and class.auras[ aura ].duration or 0
    local duration = type( duration_field ) == "function" and duration_field() or duration_field
    local app_duration = min( ttd, duration )
    local app_ticks = app_duration / tick_time

    remaining_ticks = min( remains, ttd ) / tick_time
    duration = max( 0, min( remains + duration, 1.3 * duration, ttd ) )
    potential_ticks = min( duration, ttd ) / tick_time

    if action == "thrash" then aura = "thrash" end

    return max( 0, potential_ticks - remaining_ticks )
end, {} )

-- Auras
spec:RegisterAuras( {
    faerie_fire = {
        id = 770, -- Faerie Fire (unified in MoP)
        duration = 300, 
        max_stack = 1,
        name = "Faerie Fire",
    },

    jungle_stalker = {
        id = 0, -- Dummy ID for Jungle Stalker tracking
        duration = 15,
        max_stack = 1,
    },
    bs_inc = {
        id = 0, -- Dummy ID for Berserk/Incarnation tracking
        duration = 15,
        max_stack = 1,
    },

    savage_roar = {
        id = 52610,
        copy = { 127568, 127538, 127539, 127540, 127541 },
        duration = function() return 12 + (combo_points.current * 6) end, -- MoP: 12s + 6s per combo point
        max_stack = 1,
    },
    rejuvenation = {
        id = 774,
        duration = 12,
        type = "Magic",
        max_stack = 1,
    },
    -- Engineering: Synapse Springs (Agi tinker) for FoN alignment
    synapse_springs = {
        id = 96228,
        duration = 10,
        max_stack = 1,
    },
    -- Dream of Cenarius damage bonus (used by APL sequences)
    dream_of_cenarius_damage = {
        id = 145152,
        duration = 30,
        max_stack = 1,
    },
    armor = {
        alias = { "faerie_fire" },
        aliasMode = "first",
        aliasType = "debuff",
        duration = 300,
        max_stack = 1,
    },
    mark_of_the_wild = {
        id = 1126,

        duration = 3600,
        max_stack = 1,
    },
    leader_of_the_pack = {
        id = 24932,

        duration = 3600,
        max_stack = 1,
    },
    champion_of_the_guardians_of_hyjal = {
        id = 93341,

        duration = 3600,
        max_stack = 1,
    },
    -- MoP/Classic aura IDs and durations

    aquatic_form = {
        id = 1066,

        duration = 3600,
        max_stack = 1,
    },
    bear_form = {
        id = 5487,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    berserk = {
        id = 106951,
        duration = 15,
        max_stack = 1,
        copy = { 106951, "berserk_cat" },
        multiplier = 1.5,
    },

    incarnation_king_of_the_jungle = {
        id = 114107,
        duration = 30,
        max_stack = 1,
        copy = { "incarnation" },
    },
    -- Bloodtalons removed (not in MoP)
    cat_form = {
        id = 768,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1
    },
    clearcasting = {
        id = 135700,

        duration = 15,
        type = "Magic",
        max_stack = 1,
        multiplier = 1,
    },
    dash = {
        id = 1850,

        duration = 15,
        type = "Magic",
        max_stack = 1
    },
    entangling_roots = {
        id = 339,
        duration = 30,
        mechanic = "root",
        type = "Magic",
        max_stack = 1
    },
    frenzied_regeneration = {
        id = 22842,
        duration = 6,
        max_stack = 1,
    },
    growl = {
        id = 6795,
        duration = 3,
        mechanic = "taunt",
        max_stack = 1
    },
    heart_of_the_wild = {
        id = 108292,
        duration = 45,
        type = "Magic",
        max_stack = 1,
    },
    hibernate = {
        id = 2637,
        duration = 40,
        mechanic = "sleep",
        type = "Magic",
        max_stack = 1
    },
    incapacitating_roar = {
        id = 99,
        duration = 3,
        mechanic = "incapacitate",
        max_stack = 1
    },
    infected_wounds = {
        id = 58180,
        duration = 12,
        type = "Disease",
        max_stack = 1,
    },
    innervate = {
        id = 29166,
        duration = 10,
        type = "Magic",
        max_stack = 1
    },
    ironfur = {
        id = 192081,
        duration = 7,
        type = "Magic",
        max_stack = 1
    },
    maim = {
        id = 22570,
        duration = function() return 1 + combo_points.current end,
        max_stack = 1,
    },
    mass_entanglement = {
        id = 102359,
        duration = 20,
        tick_time = 2.0,
        mechanic = "root",
        type = "Magic",
        max_stack = 1
    },
    mighty_bash = {
        id = 5211,
        duration = 5,
        mechanic = "stun",
        max_stack = 1
    },
    moonfire = {
        id = 8921,

        duration = 16,
        tick_time = 2,
        type = "Magic",
        max_stack = 1
    },
    moonkin_form = {
        id = 24858,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    predatory_swiftness = {
        id = 69369,
        duration = 8,
        type = "Magic",
        max_stack = 1,
    },
    natures_swiftness = {
        id = 132158,
        duration = 10,
        type = "Magic",
        max_stack = 1,
    },
    prowl_base = {
        id = 5215,

        duration = 3600,
        max_stack = 1,
        multiplier = 1.6,
    },
    prowl = {
        alias = { "prowl_base" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3600,
        max_stack = 1
    },
    rake = {
        id = 1822, -- Correct Rake ID for MoP
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
        copy = "rake_debuff",
    },
    regrowth = {
        id = 8936,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    rejuvenation_germination = {
        id = 155777,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    rip = {
        id = 1079,

        duration = function () return 4 + ( combo_points.current * 4 ) end,
        tick_time = 2,
        mechanic = "bleed",
        max_stack = 1,
    },
    shadowmeld = {
        id = 58984,
        duration = 10,
        max_stack = 1,
    },
    sunfire = {
        id = 93402,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1
    },
    thrash_bear = {
        id = 77758,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
    },
    thrash_cat = {
        id = 106830,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
    },
    thrash = {
        alias = { "thrash_cat", "thrash_bear" },
        aliasType = "debuff",
        aliasMode = "first",
    },
    tiger_dash = {
        id = 252216,
        duration = 5,
        type = "Magic",
        max_stack = 1
    },
    tigers_fury = {
        id = 5217,

        duration = 8, -- MoP: 8s duration
        multiplier = 1.15,
    },
    travel_form = {
        id = 783,

        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    stag_form = {
        id = 165962, -- Stag Form spell ID (MoP)
        duration = 3600,
        type = "Magic",
        max_stack = 1,
    },
    typhoon = {
        id = 61391,
        duration = 6,
        type = "Magic",
        max_stack = 1
    },
    ursols_vortex = {
        id = 102793,
        duration = 10,
        type = "Magic",
        max_stack = 1
    },
    wild_charge = {
        id = 102401,
        duration = 0.5,
        max_stack = 1
    },
    wild_growth = {
        id = 48438,
        duration = 7,
        type = "Magic",
        max_stack = 1
    },
    challenging_roar = {
        id = 5209,
        duration = 6,
        name = "Challenging Roar",
        max_stack = 1,
    },

    -- Bear-Weaving and Wrath-Weaving auras
    lacerate = {
        id = 33745,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 3,
    },

    -- Bear Form specific auras
    bear_form_weaving = {
        id = 0, -- Dummy ID for tracking
        duration = 3600,
        max_stack = 1,
    },
} )

-- Move the spell ID mapping to after all registrations are complete

-- Tweaking for new Feral APL.
local rip_applied = false

spec:RegisterEvent( "PLAYER_REGEN_ENABLED", function ()
    rip_applied = false
end )

-- Event handler to ensure Feral spec is enabled  
spec:RegisterEvent( "PLAYER_ENTERING_WORLD", function ()
    if state.spec.id == 103 then
        -- Ensure the spec is enabled in the profile
        if Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.specs then
            if not Hekili.DB.profile.specs[103] then
                Hekili.DB.profile.specs[103] = {}
            end
            Hekili.DB.profile.specs[103].enabled = true
            
            -- Set default package if none exists
            if not Hekili.DB.profile.specs[103].package then
                Hekili.DB.profile.specs[103].package = "Feral"
            end
        end
    end
end )

--[[spec:RegisterStateExpr( "opener_done", function ()
    return rip_applied
end )--]]

-- Bloodtalons combat log and state tracking removed for MoP

spec:RegisterStateFunction( "break_stealth", function ()
    removeBuff( "shadowmeld" )
    if buff.prowl.up then
        setCooldown( "prowl", 6 )
        removeBuff( "prowl" )
    end
end )

-- Function to remove any form currently active.
spec:RegisterStateFunction( "unshift", function()
    if conduit.tireless_pursuit and conduit.tireless_pursuit.enabled and ( buff.cat_form.up or buff.travel_form.up ) then applyBuff( "tireless_pursuit" ) end

    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "travel_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )

    -- MoP: No Oath of the Elder Druid legendary or Restoration Affinity in MoP.
end )

local affinities = {
    bear_form = "guardian_affinity",
    cat_form = "feral_affinity",
    moonkin_form = "balance_affinity",
}

-- Function to apply form that is passed into it via string.
spec:RegisterStateFunction( "shift", function( form )
    -- MoP: No tireless_pursuit or wildshape_mastery in MoP.
    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )
    applyBuff( form )
    -- MoP: No Oath of the Elder Druid legendary or Restoration Affinity in MoP.
end )



spec:RegisterHook( "runHandler", function( ability )
    local a = class.abilities[ ability ]

    if not a or a.startsCombat then
        break_stealth()
    end
end )

spec:RegisterHook( "gain", function( amt, resource, overflow )
    if overflow == nil then overflow = true end
    if amt > 0 and resource == "combo_points" then
    end

end )





local combo_generators = {
    rake              = true,
    shred             = true,
    swipe_cat         = true,
    thrash_cat        = true
}



spec:RegisterStateTable( "druid", setmetatable( {},{
    __index = function( t, k )
        if k == "catweave_bear" then return false
        elseif k == "owlweave_bear" then return false
        elseif k == "owlweave_cat" then
            return false -- MoP: No Balance Affinity
        elseif k == "no_cds" then return not toggle.cooldowns
        -- MoP: No Primal Wrath or Lunar Inspiration
        elseif k == "primal_wrath" then return false
        elseif k == "lunar_inspiration" then return false
        elseif k == "delay_berserking" then return state.settings.delay_berserking
        elseif debuff[ k ] ~= nil then return debuff[ k ]
        end
    end
} ) )

-- MoP: Bleeding only considers Rake, Rip, and Thrash Cat (no Thrash Bear for Feral).
spec:RegisterStateExpr( "bleeding", function ()
    return debuff.rake.up or debuff.rip.up or debuff.thrash_cat.up
end )

-- MoP: Effective stealth is only Prowl or Incarnation (no Shadowmeld for snapshotting in MoP).
spec:RegisterStateExpr( "effective_stealth", function ()
    return buff.prowl.up or ( buff.incarnation and buff.incarnation.up )
end )

-- Essential state expressions for APL functionality
spec:RegisterStateExpr( "time_to_die", function ()
    return target.time_to_die or 300
end )

spec:RegisterStateExpr( "spell_targets", function ()
    return active_enemies or 1
end )



spec:RegisterStateExpr( "energy_deficit", function ()
    return energy.max - energy.current
end )

spec:RegisterStateExpr( "energy_time_to_max", function ()
    return energy.deficit / energy.regen
end )

spec:RegisterStateExpr( "cp_max_spend", function ()
    return combo_points.current >= 5 or ( combo_points.current >= 4 and buff.savage_roar.remains < 2 )
end )

spec:RegisterStateExpr( "time_to_pool", function ()
    local deficit = energy.max - energy.current
    if deficit <= 0 then return 0 end
    return deficit / energy.regen
end )

-- State expression to check if we can make recommendations
spec:RegisterStateExpr( "can_recommend", function ()
    return state.spec and state.spec.id == 103 and level >= 10
end )

-- Essential state expressions for APL functionality
spec:RegisterStateExpr( "current_energy", function ()
    return energy.current or 0
end )

spec:RegisterStateExpr( "current_combo_points", function ()
    return combo_points.current or 0
end )

spec:RegisterStateExpr( "max_energy", function ()
    return energy.max or 100
end )

spec:RegisterStateExpr( "energy_regen", function ()
    return energy.regen or 10
end )

spec:RegisterStateExpr( "in_combat", function ()
    return combat > 0
end )

spec:RegisterStateExpr( "player_level", function ()
    return level or 85
end )

-- Additional essential state expressions for APL compatibility
spec:RegisterStateExpr( "cat_form", function ()
    return buff.cat_form.up
end )

spec:RegisterStateExpr( "bear_form", function ()
    return buff.bear_form.up
end )

spec:RegisterStateExpr( "health_pct", function ()
    return health.percent or 100
end )

spec:RegisterStateExpr( "target_health_pct", function ()
    return target.health.percent or 100
end )

spec:RegisterStateExpr( "behind_target", function ()
    return UnitExists("target") and UnitExists("targettarget") and UnitGUID("targettarget") ~= UnitGUID("player")
end )


-- MoP Tier Sets

-- Tier 15 (MoP - Throne of Thunder)
spec:RegisterGear( "tier15", 95841, 95842, 95843, 95844, 95845 )
-- 2-piece: Increases the duration of Savage Roar by 6 sec.
spec:RegisterAura( "t15_2pc", {
    id = 138123, -- Custom ID for tracking
    duration = 3600,
    max_stack = 1
} )
-- 4-piece: Your finishing moves have a 10% chance per combo point to grant Tiger's Fury for 3 sec.
spec:RegisterAura( "t15_4pc", {
    id = 138124, -- Custom ID for tracking
    duration = 3,
    max_stack = 1
} )

-- Tier 16 (MoP - Siege of Orgrimmar)
spec:RegisterGear( "tier16", 99155, 99156, 99157, 99158, 99159 )
-- 2-piece: When you use Tiger's Fury, you gain 1 combo point.
spec:RegisterAura( "t16_2pc", {
    id = 145164, -- Custom ID for tracking
    duration = 3600,
    max_stack = 1
} )
-- 4-piece: Finishing moves increase the damage of your next Mangle, Shred, or Ravage by 40%.
spec:RegisterAura( "t16_4pc", {
    id = 145165, -- Custom ID for tracking
    duration = 15,
    max_stack = 1
} )



-- MoP: Update calculate_damage for MoP snapshotting and stat scaling.
local function calculate_damage( coefficient, masteryFlag, armorFlag, critChanceMult )
    local hekili = _G["Hekili"]
    local state = hekili and hekili.State or {}
    local class = hekili and hekili.Class or {}
    
    local feralAura = 1
    local armor = armorFlag and 0.7 or 1
    local crit = 1 + ( (state.stat and state.stat.crit or 0) * 0.01 * ( critChanceMult or 1 ) )
    local mastery = masteryFlag and ( 1 + ((state.stat and state.stat.mastery_value or 0) * 0.01) ) or 1
    local tf = (state.buff and state.buff.tigers_fury and state.buff.tigers_fury.up) and 
               ((class.auras and class.auras.tigers_fury and class.auras.tigers_fury.multiplier) or 1.15) or 1

    return coefficient * (state.stat and state.stat.attack_power or 1000) * crit * mastery * feralAura * armor * tf
end

-- Force reset when Combo Points change, even if recommendations are in progress.
spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( _, _, powerType )
    if powerType == "COMBO_POINTS" then
        Hekili:ForceUpdate( powerType, true )
    end
end )

-- Removed duplicate debuff registration - auras should be sufficient

-- Abilities (MoP version, updated)
spec:RegisterAbilities( {
    -- Maintain armor debuff (controlled by maintain_ff toggle)
    faerie_fire= {
        id = 16857,
        copy = { 770 },
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        texture = 136033,
        startsCombat = true,
        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },
    -- Debug ability that should always be available for testing
    savage_roar = {
        -- Use dynamic ID so keybinds match action bar (glyphed vs base)
        id = function()
            if IsSpellKnown and IsSpellKnown(127568) then return 127568 end
            return 52610
        end,
        copy = { 52610, 127568, 127538, 127539, 127540, 127541 },
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        texture = 236167,
        spend = 25,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function()
            applyBuff("savage_roar")
            -- Spend combo points only if we actually have some (glyph allows 0 CP pre-pull)
            if combo_points.current and combo_points.current > 0 then
                spend(combo_points.current, "combo_points")
            end
        end,
    },
    mangle_cat = {
        id = 33876,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function()
            gain(1, "combo_points")
        end,
    },
    faerie_fire_feral = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        startsCombat = true,

        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },
    -- Alias for SimC import token
    faerie_fire = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        startsCombat = true,
        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        startsCombat = false,
        handler = function()
            applyBuff("mark_of_the_wild")
        end,
    },
    healing_touch = {
        id = 5185,
        cast = function()
            if buff.natures_swiftness.up or buff.predatory_swiftness.up then return 0 end
            return 2.5 * haste
        end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = function() return buff.natures_swiftness.up and 0 or 0.1 end,
        spendType = "mana",
        startsCombat = false,
        usable = function()
            -- Disallow hardcasting in Cat; require an instant proc (NS or PS)
            return (talent.dream_of_cenarius and talent.dream_of_cenarius.enabled) and (buff.natures_swiftness.up or buff.predatory_swiftness.up)
        end,
        handler = function()
            if buff.natures_swiftness.up then removeBuff("natures_swiftness") end
            -- no HoT; just consume NS on CD and return to cat
            if talent.dream_of_cenarius and talent.dream_of_cenarius.enabled then
                applyBuff( "dream_of_cenarius_damage" )
            end
        end,
    },
    frenzied_regeneration = {
        id = 22842,
        cast = 0,
        cooldown = 36,
        gcd = "off",
        school = "physical",
        spend = 10,
        spendType = "rage",
        startsCombat = false,
        form = "bear_form",
        handler = function()
            applyBuff("frenzied_regeneration")
        end,
    },
    -- Barkskin: Reduces all damage taken by 20% for 12 sec. Usable in all forms.
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "nature",
        startsCombat = false,
        handler = function ()
            applyBuff( "barkskin" )
        end
    },

    -- Bear Form: Shapeshift into Bear Form.
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        essential = true,
        noform = "bear_form",
        handler = function ()
            -- Only allow form swap if we'll actually weave in bear.
            if opt_bear_weave and should_bear_weave then
                shift( "bear_form" )
            end
        end,
    },

    -- Berserk: Reduces the cost of all Cat Form abilities by 50% for 15 sec.
    berserk = {
        id = 106951,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "cooldowns",
        handler = function ()
            if buff.cat_form.down then shift( "cat_form" ) end
            applyBuff( "berserk" )
        end,
        copy = { "berserk_cat" }
    },

    -- Cat Form: Shapeshift into Cat Form.
    cat_form = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        essential = true,
        noform = "cat_form",
        handler = function ()
            -- Do not recommend Cat swap unless we are not weaving or bear form is active.
            if buff.bear_form.up or not opt_bear_weave then
                shift( "cat_form" )
            end
        end,
    },

    -- Dash: Increases movement speed by 70% for 15 sec.
    dash = {
        id = 1850,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        handler = function ()
            shift( "cat_form" )
            applyBuff( "dash" )
        end,
    },

    -- Disorienting Roar (MoP talent): Disorients all enemies within 10 yards for 3 sec.
    disorienting_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        talent = "disorienting_roar",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "incapacitating_roar" )
        end,
    },

    -- Entangling Roots: Roots the target in place for 30 sec.
    entangling_roots = {
        id = 339,
        cast = 1.7,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.1,
        spendType = "mana",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "entangling_roots" )
        end,
    },

    -- Faerie Swarm (MoP talent): Reduces target's movement speed and prevents stealth.
    faerie_swarm = {
        id = 102355,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        talent = "faerie_swarm",
        startsCombat = true,
        handler = function ()
            -- Debuff application handled elsewhere if needed
        end,
    },

    -- Ferocious Bite: Finishing move that causes Physical damage per combo point.
    ferocious_bite = {
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function ()
            return max( 25, min( 35, energy.current ) )
        end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function () return combo_points.current > 0 end,
        handler = function ()
            spend( min( 5, combo_points.current ), "combo_points" )
        end,
    },

    -- Growl: Taunts the target to attack you.
    growl = {
        id = 6795,
        cast = 0,
        cooldown = 8,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        form = "bear_form",
        handler = function ()
            applyDebuff( "target", "growl" )
        end,
    },

    -- Incarnation: King of the Jungle (MoP talent): Improved Cat Form for 30 sec.
    incarnation_king_of_the_jungle = {
        id = 102543,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        talent = "incarnation_king_of_the_jungle",
        startsCombat = false,
        toggle = "cooldowns",
        handler = function ()
            if buff.cat_form.down then shift( "cat_form" ) end
            applyBuff( "incarnation_king_of_the_jungle" )
        end,
        copy = { "incarnation" }
    },

    -- Maim: Finishing move that causes damage and stuns the target.
    maim = {
        id = 22570,
        cast = 0,
        cooldown = 20,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        talent = "maim",
        startsCombat = false,
        form = "cat_form",
        usable = function () return combo_points.current > 0 end,
        handler = function ()
            applyDebuff( "target", "maim", combo_points.current )
            spend( combo_points.current, "combo_points" )
        end,
    },

    -- Mass Entanglement (MoP talent): Roots the target and nearby enemies.
    mass_entanglement = {
        id = 102359,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "mass_entanglement",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "mass_entanglement" )
        end,
    },

    -- Mighty Bash: Stuns the target for 5 sec.
    mighty_bash = {
        id = 5211,
        cast = 0,
        cooldown = 50,
        gcd = "spell",
        school = "physical",
        talent = "mighty_bash",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "mighty_bash" )
        end,
    },

    -- Moonfire: Applies a DoT to the target.
    moonfire = {
        id = 8921,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        spend = 0.06,
        spendType = "mana",
        startsCombat = false,
        form = "moonkin_form",
        handler = function ()
            if not buff.moonkin_form.up then unshift() end
            applyDebuff( "target", "moonfire" )
        end,
    },

    -- Prowl: Enter stealth.
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        nobuff = "prowl",
        handler = function ()
            shift( "cat_form" )
            applyBuff( "prowl_base" )
        end,
    },

    -- Rake: Bleed damage and awards 1 combo point.
    rake = {
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",

        handler = function ()
            applyDebuff( "target", "rake" )
            gain( 1, "combo_points" )
            local snap = bleed_snapshot[ target.unit ]
            snap.rake_mult = current_bleed_multiplier()
            snap.rake_time = query_time
        end,
    },

    -- Regrowth: Heals a friendly target.
    regrowth = {
        id = 8936,
        cast = function ()
            if buff.predatory_swiftness.up then return 0 end
            return 1.5 * haste
        end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.10,
        spendType = "mana",
        startsCombat = false,
        handler = function ()
            if buff.predatory_swiftness.down then
                unshift()
            end
            removeBuff( "predatory_swiftness" )
            applyBuff( "regrowth" )
        end,
    },

    -- Nature's Swiftness (for SimC import compatibility)
    natures_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "nature",
        startsCombat = false,
        handler = function()
            applyBuff( "natures_swiftness" )
        end,
    },

    -- Rejuvenation: Heals the target over time.
    rejuvenation = {
        id = 774,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.08,
        spendType = "mana",
        startsCombat = false,
        handler = function ()
            if buff.cat_form.up or buff.bear_form.up then
                unshift()
            end
            applyBuff( "rejuvenation" )
        end,
    },

    -- Rip: Finishing move that causes Bleed damage over time.
    rip = {
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 20,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function ()
            return combo_points.current > 0
        end,
        handler = function ()
            applyDebuff( "target", "rip" )
            spend( combo_points.current, "combo_points" )
            local snap = bleed_snapshot[ target.unit ]
            snap.rip_mult = current_bleed_multiplier()
            snap.rip_time = query_time
        end,
    },

    -- Shred: Deals damage and awards 1 combo point.
    shred = {
        id = 5221,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Skull Bash: Interrupts spellcasting.
    skull_bash = {
        id = 80965,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "interrupts",
        interrupt = true,
        form = function ()
            return buff.bear_form.up and "bear_form" or "cat_form"
        end,
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        handler = function ()
            interrupt()
        end,
    },

    -- Survival Instincts: Reduces all damage taken by 50% for 6 sec.
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        handler = function ()
            applyBuff( "survival_instincts" )
        end,
    },

    -- Thrash (Cat): Deals damage and applies a bleed to all nearby enemies.
    thrash_cat = {
        id = 106830,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = 40,
        spendType = "energy",
        startsCombat = false,
        form = "cat_form",
        handler = function ()
            applyDebuff( "target", "thrash_cat" )
            gain( 1, "combo_points" )
        end,
    },

    -- Tiger's Fury: Instantly restores 60 Energy and increases damage done by 15% for 6 sec.
    tigers_fury = {
        id = 5217,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",
        spend = -60,
        spendType = "energy",
        startsCombat = false,
        
        usable = function()
            return not buff.berserk.up, "cannot use while Berserk is active"
        end,
        
        handler = function ()
            shift( "cat_form" )
            applyBuff( "tigers_fury" )
        end,
    },

    -- Swipe (Cat): Swipe nearby enemies, dealing damage and awarding 1 combo point.
    swipe_cat = {
        id = 62078,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 45,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Wild Charge (MoP talent): Movement ability that varies by shapeshift form.
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",
        talent = "wild_charge",
        startsCombat = false,
        handler = function ()
            applyBuff( "wild_charge" )
        end,
    },

    -- Cenarion Ward (MoP talent): Protects a friendly target, healing them when they take damage.
    cenarion_ward = {
        id = 102351,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "cenarion_ward",
        startsCombat = false,
        handler = function ()
            applyBuff( "cenarion_ward" )
        end,
    },

    -- Typhoon (MoP talent): Knocks back enemies and dazes them.
    typhoon = {
        id = 132469,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "typhoon",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "typhoon" )
        end,
    },

    -- Heart of the Wild (MoP talent): Temporarily improves abilities not associated with your specialization.
    heart_of_the_wild = {
        id = 108292,
        cast = 0,
        cooldown = 360,
        gcd = "off",
        school = "nature",
        talent = "heart_of_the_wild",
        startsCombat = false,
        handler = function ()
            applyBuff( "heart_of_the_wild" )
        end,
    },

    -- Renewal (MoP talent): Instantly heals you for 30% of max health.
    renewal = {
        id = 108238,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "nature",
        talent = "renewal",
        startsCombat = false,
        handler = function ()
            -- Healing handled by game
        end,
    },

    -- Force of Nature (MoP talent): Summons treants to assist in combat.
    force_of_nature = {
        id = 102703,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",
        talent = "force_of_nature",
        startsCombat = true,
        handler = function ()
            -- Summon handled by game
        end,
    },

    -- Shadowmeld: Night Elf racial ability
    shadowmeld = {
        id = 58984,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        handler = function ()
            applyBuff( "shadowmeld" )
        end,
    },

    -- Wrath (for Wrath-Weaving during Heart of the Wild)
    wrath = {
        id = 5176,
        cast = function() return 2 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.06,
        spendType = "mana",
        startsCombat = true,
        handler = function()
            -- Wrath damage during Heart of the Wild
        end,
    },

    -- Mangle (Bear) for Bear-Weaving
    mangle_bear = {
        id = 33878,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 20,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function()
            -- Mangle damage in Bear Form
        end,
    },

    -- Thrash: Single action, aura alias resolves form-specific debuff
    thrash = {
        id = 106830,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = function()
            if buff.bear_form.up then return 25 end
            return 40
        end,
        spendType = function()
            if buff.bear_form.up then return "rage" end
            return "energy"
        end,
        startsCombat = true,
        form = function()
            return buff.bear_form.up and "bear_form" or "cat_form"
        end,
        handler = function()
            if buff.bear_form.up then
                applyDebuff( "target", "thrash_bear" )
            else
                applyDebuff( "target", "thrash_cat" )
            end
        end,
    },

    -- Maul (Bear): Off-GCD rage dump
    maul = {
        id = 6807,
        cast = 0,
        cooldown = 3,
        gcd = "off",
        school = "physical",
        spend = 30,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function()
        end,
    },

    -- Lacerate for Bear-Weaving (if talented)
    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 15,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function()
            applyDebuff("target", "lacerate")
        end,
    },
} )

-- Feral Druid Advanced Techniques
-- Simple toggle system for Bear-Weaving and Wrath-Weaving

-- Additional auras for advanced techniques
spec:RegisterAuras( {
    lacerate = {
        id = 33745,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 3,
    },

    -- Bear Form specific auras
    bear_form_weaving = {
        id = 0, -- Dummy ID for tracking
        duration = 3600,
        max_stack = 1,
    },
} )

-- Auras for advanced techniques
spec:RegisterAuras( {
    lacerate = {
        id = 33745,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 3,
    },

    -- Bear Form specific auras
    bear_form_weaving = {
        id = 0, -- Dummy ID for tracking
        duration = 3600,
        max_stack = 1,
    },
} )

-- State expressions for advanced techniques
spec:RegisterStateExpr( "should_bear_weave", function()
    if not state.settings.bear_weaving_enabled then return false end
    
    -- Bear-weave when energy is high and we're not in immediate danger
    return energy.current >= 80 and 
           not buff.berserk.up and 
           not buff.incarnation_king_of_the_jungle.up and
           target.time_to_die > 10
end )

spec:RegisterStateExpr( "should_wrath_weave", function()
    if not state.settings.wrath_weaving_enabled then return false end
    
    -- Wrath-weave during Heart of the Wild when not in combat forms
    return buff.heart_of_the_wild.up and 
           not buff.cat_form.up and 
           not buff.bear_form.up and
           mana.current >= 0.06 * mana.max
end )

-- Settings for advanced techniques
spec:RegisterSetting( "bear_weaving_enabled", false, {
    name = "Enable Bear-Weaving",
    desc = "If checked, Bear-Weaving will be recommended when appropriate. This involves shifting to Bear Form to pool energy and deal damage.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "wrath_weaving_enabled", false, {
    name = "Enable Wrath-Weaving", 
    desc = "If checked, Wrath-Weaving will be recommended during Heart of the Wild when not in combat forms.",
    type = "toggle",
    width = "full"
} )

-- SimC-style toggles for parity with Feral_SimC_APL.simc
spec:RegisterSetting( "maintain_ff", true, {
    name = "Maintain Faerie Fire",
    desc = "If checked, maintain Faerie Fire (armor) on the target.",
    type = "toggle",
    width = "full"
} )

-- Consolidated: Use base flags; variables in APL map to these via state expressions below.

spec:RegisterSetting( "opt_snek_weave", true, {
    name = "Enable Snek-Weave ",
    desc = "Use Predatory Swiftness/Nature's Swiftness for Regrowth snapshots.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "opt_use_ns", false, {
    name = "Use Nature's Swiftness ",
    desc = "Use Nature's Swiftness to enable snapshot Regrowths.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "opt_melee_weave", true, {
    name = "Melee-Weave Focus ",
    desc = "Prefer Cat Form melee time; monocat keeps this on while other weaves are off.",
    type = "toggle",
    width = "full"
} )

spec:RegisterRanges( "rake", "shred", "skull_bash", "growl", "moonfire" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageDots = false,
    damageExpiration = 3,

    potion = "tempered_potion",

    package = "Feral"
} )

-- Solo/positioning toggle
spec:RegisterSetting( "disable_shred_when_solo", false, {
    type = "toggle",
    name = "Disable Shred when Solo",
    desc = "If checked, Shred will not be recommended when not in a group/raid and on single targets.",
    width = "full",
} )

-- Feature toggles
spec:RegisterSetting( "use_trees", false, {
    type = "toggle",
    name = "Use Force of Nature",
    desc = "If checked, Force of Nature will be used on cooldown.",
    width = "full",
} )

spec:RegisterSetting( "use_hotw", false, {
    type = "toggle",
    name = "Use Heart of the Wild",
    desc = "If checked, Heart of the Wild will be used on cooldown.",
    width = "full",
} )


spec:RegisterSetting( "rip_duration", 9, {
    name = strformat( "%s Duration", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    desc = strformat( "If set above |cFFFFD1000|r, %s will not be recommended if the target will die within the specified timeframe.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    type = "range",
    min = 0,
    max = 18,
    step = 0.1,
    width = 1.5
} )

spec:RegisterSetting( "regrowth", true, {
    name = strformat( "Filler %s", Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    desc = strformat( "If checked, %s may be recommended as a filler when higher priority abilities are not available. This is generally only at very low energy.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterVariable( "regrowth", function()
    return state.settings.regrowth ~= false
end )

spec:RegisterStateExpr( "filler_regrowth", function()
    return state.settings.regrowth ~= false
end )

spec:RegisterSetting( "solo_prowl", false, {
    name = strformat( "Allow %s in Combat When Solo", Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    desc = strformat( "If checked, %s can be recommended in combat when you are solo. This is off by default because it may drop combat outside of a group/encounter.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "allow_shadowmeld", nil, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    desc = strformat( "If checked, %s can be recommended for Night Elf players if its conditions for use are met. Only recommended in boss fights or groups to avoid resetting combat.",
        Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    type = "toggle",
    width = "full",
    get = function () return not Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled end,
    set = function ( _, val )
        Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled = not val
    end,
} )

spec:RegisterSetting( "lazy_swipe", false, {
    name = strformat( "Minimize %s in AOE", Hekili:GetSpellLinkWithTexture( spec.abilities.shred.id ) ),
    desc = "If checked, Shred will be minimized in multi-target situations. This is a DPS loss but can be easier to execute.",
    type = "toggle",
    width = "full"
} )

spec:RegisterVariable( "use_thrash", function()
    return active_enemies >= 4
end )

spec:RegisterVariable( "aoe", function()
    return active_enemies >= 3
end )

spec:RegisterVariable( "use_rake", function()
    return true
end )

spec:RegisterVariable( "pool_energy", function()
    return energy.current < 50 and not buff.omen_of_clarity.up and not buff.berserk.up
end )

spec:RegisterVariable( "lazy_swipe", function()
    return state.settings.lazy_swipe ~= false
end )

-- Bleed snapshot tracking (minimal: Tiger's Fury multiplier)
spec:RegisterStateTable( "bleed_snapshot", setmetatable( {
    cache = {},
    reset = function( t )
        table.wipe( t.cache )
    end
}, {
    __index = function( t, k )
        if not t.cache[ k ] then
            t.cache[ k ] = {
                rake_mult = 0,
                rip_mult = 0,
                rake_time = 0,
                rip_time = 0,
            }
        end
        return t.cache[ k ]
    end
} ) )

spec:RegisterStateFunction( "current_bleed_multiplier", function()
    -- Primary MoP snapshot driver is Tiger's Fury (1.15)
    local tf = ( buff.tigers_fury and buff.tigers_fury.up ) and 1.15 or 1
    return tf
end )

spec:RegisterStateExpr( "rake_stronger", function()
    local snap = bleed_snapshot[ target.unit ]
    local now_mult = current_bleed_multiplier()
    return now_mult > ( snap.rake_mult or 0 ) + 0.001
end )

spec:RegisterStateExpr( "rip_stronger", function()
    local snap = bleed_snapshot[ target.unit ]
    local now_mult = current_bleed_multiplier()
    return now_mult > ( snap.rip_mult or 0 ) + 0.001
end )

-- Percent increase if we were to reapply the bleed now (0.05 = 5%).
spec:RegisterStateExpr( "rake_damage_increase_pct", function()
    local snap = bleed_snapshot[ target.unit ]
    local last = snap.rake_mult or 0
    local now = current_bleed_multiplier()
    if last <= 0 then return 0 end
    return max( 0, ( now / last ) - 1 )
end )

spec:RegisterStateExpr( "rip_damage_increase_pct", function()
    local snap = bleed_snapshot[ target.unit ]
    local last = snap.rip_mult or 0
    local now = current_bleed_multiplier()
    if last <= 0 then return 0 end
    return max( 0, ( now / last ) - 1 )
end )

-- Bear-weave trigger logic mirroring the provided APL conditions.
spec:RegisterStateExpr( "bearweave_trigger_ok", function()
    if not buff.cat_form.up then return false end
    if active_enemies ~= 1 then return false end
    if energy.current >= 15 then return false end
    if debuff.rake.remains < 8 or debuff.rip.remains < 8 then return false end
    if cooldown.tigers_fury.remains < 7 then return false end
    if buff.berserk.up then return false end

    -- Predatory Swiftness window OR minimal expected rake snapshot gain
    if buff.predatory_swiftness.up and buff.predatory_swiftness.remains >= 5 then return true end
    if buff.predatory_swiftness.down and rake_damage_increase_pct <= 0.05 then return true end

    return false
end )

-- State expressions for advanced techniques
spec:RegisterStateExpr( "should_bear_weave", function()
    if not opt_bear_weave then return false end
    -- Avoid immediate flip-flop right after swapping to Cat
    if query_time <= ( action.cat_form.lastCast + gcd.max ) then return false end
    -- Don't start a weave if any core timers need attention soon
    local urgent_refresh = ( (debuff.rip.remains > 0 and debuff.rip.remains <= 3)
        or (debuff.rake.remains > 0 and debuff.rake.remains <= 3)
        or (buff.savage_roar.up and buff.savage_roar.remains <= 4)
        or cooldown.tigers_fury.remains <= 2 )
    if urgent_refresh then return false end
    -- Trigger bear-weave when energy is LOW to pool (e.g., <= 35)
    return energy.current <= 35 and not buff.berserk.up and not buff.incarnation_king_of_the_jungle.up and target.time_to_die > 10
end )

spec:RegisterStateExpr( "should_wrath_weave", function()
    if not opt_wrath_weave then return false end
    
    -- Wrath-weave during Heart of the Wild when not in combat forms
    return buff.heart_of_the_wild.up and 
           not buff.cat_form.up and 
           not buff.bear_form.up and
           mana.current >= 0.06 * mana.max
end )

-- Expose SimC-style toggles directly in state for APL expressions
spec:RegisterStateExpr( "maintain_ff", function() return state.settings.maintain_ff ~= false end )
-- Map APL variables to consolidated settings.
spec:RegisterStateExpr( "opt_bear_weave", function() return state.settings.bear_weaving_enabled ~= false end )
spec:RegisterStateExpr( "opt_wrath_weave", function() return state.settings.wrath_weaving_enabled ~= false end )
spec:RegisterStateExpr( "opt_snek_weave", function() return state.settings.opt_snek_weave ~= false end )
spec:RegisterStateExpr( "opt_use_ns", function() return state.settings.opt_use_ns ~= false end )
spec:RegisterStateExpr( "opt_melee_weave", function() return state.settings.opt_melee_weave ~= false end )
spec:RegisterStateExpr( "use_trees", function() return state.settings.use_trees ~= false end )
spec:RegisterStateExpr( "use_hotw", function() return state.settings.use_hotw ~= false end )
spec:RegisterStateExpr( "disable_shred_when_solo", function()
    return state.settings.disable_shred_when_solo ~= false
end )


-- Provide in_group for APL compatibility in emulated environment
spec:RegisterStateExpr( "in_group", function()
    -- Avoid calling globals in the sandbox; treat as solo in emulation
    return false
end )

-- Expose solo_prowl toggle to SimC as a state expression
spec:RegisterStateExpr( "solo_prowl", function()
    return state.settings.solo_prowl ~= false
end )


spec:RegisterPack( "Feral", 20250915, [[Hekili:nZr7YTTrUNfpDoDstDuLSTsVKA5zsCsU2oxs6e5B6)efn5kloMIKh)WoEgn6z)a2Dj3LlXss5pUEtN2AXDbwaSaybWcYLtxE1Yf(U5SLF5KjNmBYBMoB8jtM9ZN(6LlYFiHTCrIR3TU3a)rK7w4)(jwQBi(0hcJD9rOZIls9GrwU46IGW8FlA510O8SLlClY3eNUCXITfRtdUD5Inb((mbeSmVLlUAtq2(v4)6UFLCP3VkEn8BV8G4O9RcdYYHHxhNUF1VYUnimy8Yf8hIeZvF8lF4RFb(RVW5mwK71Hm)LVF5I4eGuz5anWr0Yf35MgGJI)vyb8)MkiI0GeXeUIf5JRyskdaC)Q84KxfYUJfYH1rip26geLd)RZ61lZbo(XSQkSfNK7Cnd(59m37yicp9Gr4eteEFQB(gfgp7GX40z6OmFTZ1XrfziUMzGRsu45gg6i(HdU3i2HkraxUIG)6hd4EU5oaBfSf0dZH)rSfqTLxIU1US0aMZ6GuMXw8)oh0FYFa0UI83VIJia(ipqN7tFc07IcHXwC1(vdpF(jJG1onihWLRsinwtby)Qb7x5ZUUy96XAR5y)47J4JHe0DmhweBBaduIpF((vNWhHddYzGE92Xfju6sQfp3n9gwom)S8GOBumA2TfGG7A3SncjdO56fV9A3wLoBDtV1jETt(gMZ9bH(gIO)OchAeWrsk2ewDkxTzk4k9fNqXMq0Mfhg7KKgFF4(v72bUfICeKY(vGGBIAj4ZHs3UjfN5Eh4sXjn2nfjwLOt9CHSZp2RnP2gMBii7DYJl82yiYweXU9N(vqRHBZjvU(qkZDRWv2La(sdkafGSIKK4uGFgMhFZnWsmcDQXX8(vxHOE)QImU7x9D)qwu(yFeHOW3tIUXsYKRqnC)Qk5i6eidOjhj9GYYAdwKXCIaYzujOGgA6npm2RinfwkHI6zt0MWqP4e0Wax9XPp4KDFW68iwwgiwvQ0uJNYqBgL6)ibf1dSItJpHi38cWRSXWJ0mLcbVOs7dL9NyjqDiqVkgSBZuS4filwol)48XW2PesCzlFII43V6u(sQiF(CCVLzcg(is4gvNMB38VuZRbVBO99f(4)DyPwuodqrJLJA7hOsePsYaBsqqaotoCCikci2MQedObmFYh16w6b7000TsPud3emeuFi(suW8FkyGdFaXdDtahjFhoyjhmsYYtd8Y1MaStD5Fiw(tF7(vFdqietWggSt)z3OBcRzJYjTgcxhF3TGXCjNrlg5lanNxoafJB313)JPfTdwqPIdmwBHkqSXGIz0A0qk)TGKNj2QYuV)Cfr0k)vrkkrxaNU(zBswuErjyN9wUWSsUY3bEU4Mzhi3amW)4fsWEOKsDDsGWEJfjl4JkrOyt4r5DXF8TCFVjvAUxTjfIjdif(5mW(TiaUSdMvn5f1HwuY1PtEAc2dy1Qen5CwvA0NxpA9hvwztmKXVlmlg3ZJYc8zqoGGt7Wh4XlHrSheX3akdDpynM2gpYkm0R1hJXNV2Tie2icfbdfJXTxb2)okyDao5lX9QVkiCWejo3TI(iYdY2z1TMiJiVLwoZQ90GKhYM1UZ)AhHRNjy)wfoeuUVTScAjV2VfabOk1u7Ey7kCLEUAyq9eEmvRdPkFprUBmJYBwVGntAU8UV(XNjZKV(rIkxab54hKHaIMlhJb6l(bUniZxz0FLL3OxcRgvaqzl0wgBqAyGh3SW48QFO24RIzn7Hi3eiu3SKuWRcgXQR)dMNJQB7zZ2hIFm6ww(0YLS63TW2Y5CIbmNuzJxoXRdJJ9DwxK(GrA1ZQnlwAgl9wEncQnlBfEjjwk(RFqHepv5GjR)aSdWGeGD8dyYWYFDzzcVliDllkZ5AaposS2QHN0apiYZnnI7RTwMiCYip4gGq4CDTZC0aQndqjxySx(EXtHJS3eCZMYuFbtJRGJtksG)ikgmH0tOeE2IVjh885NuDC(XIdsUSETsmZL(I9REZeBmL2PRKzWsudJhrss2IRbMIhdDVksgZqs9jCurfme5ychMwKkkvbYeykNFcydWjtwW2Kq(jPGmX9U4ayxeYJIhZPWHtqKp77CydYYkGSRipsbZ5mpLXePDk1rmOYo1tOIeQYPaiKZBP6x)koUGNHzSF1FctPmKcRu8M4871j4gls1PwI6xghf7rxJUU9VA63)ZcK9wUZ)1yasj8DkpmEgLZF0bmi9h1U35d3DFxfF(zOC2QkzjeFYYjti9iRM)1fPW)D4TSeqGCdACg4ns)Ghz1kjyFVhz1efCDLpEL2PHx5Zi8Dt5ExJKS7T10NEPx)YhlY7UgYT7D2EjZMPHXGoYMRxyb0zJ9cIleCJylwgZ(JZcrpegdhA4DzHvMTa9pn8ZX)XiWZEW2Iq(zjxM6UgOV39h)R9R(NHXxJZfwk0HCgEzbjjOtN1PXB3V6Fv4ILmIx5OHEUOEg6Q8owAk)gUGF)qz8yzpVryzg29HeUv)WET0gEMVBjdl62S1BO83pSlQBPjMLpLiwO(H1TSqgJMO1hIWQQB8xDQNoMvpKWgRF4epxYeL8Nresq3yuEwIt2MuMVZ9Byro4f2OVa2Mc1jYDVGQRdsFn0EkI2wpd4Zq4u8AgWxcXDjd2RFOSKac7Zrp20qu5Y2sAiCdsX9HzehkMb2FIGdhEdb(FdEmH8YJ0Qs9vIrKvO4vq0Kcih6dQD3WDa5Zyj4mcJVjWdJwPU)P7cCfj8XPvh5s5eFlDmy19IiIYIa42pWuMgHK1lJAnfl2KQyZqiRAheilFmceLRRdd34Hm6ixuMkkxwhoEpDsxrTFex16oieW1o345pElOUPZOfHuU36IsAUGYbW1ASKdjdSPJkzRVsw3pShSql4i01doZnVJ6KKtzF8XVhGr1(nwopaouPMBbCpVcRUxhxKlEQNBszwCWjWGzagF9R4ZftyfTPIy4j3U5qOJY1SdrD1vI6uMZ7w3VlYYc3pzFN5vKZSELFIBrH(Aef1ufhRQee65V04YsfUAWAn1ItMAXy2SUqEXykbd1lf9O2szLZaZukDL1dOEAPTKXAV7Sbu(OkHS9oNWOu06XHxjXW5m9qkxDl(yEPwF1njq4kQAsAztuF38BS1WrwBe1Jqwe7wj7A39bjvFEzHdShTUfMIRykkyClQMIjuNn(t8zvTlrc6LydylGNHnKxFEm4zzsa2pKslwufb2m3BPj9rn5GApVMdmoRL1AB0y3KBra648vcdTsJpZkMCoAFjS7gzPMt8NvLw4FDwRDRwUGpcETjUPVf9iJHzH3fZ2GSmErFq)YNpFkW)cfp(dhI(LZWRzV2M8qc1vvhw0IMSqvD0JvB2AvAT3pzFIpcSPgiR5c2ap3VjquXlbvWleJEzdF69vgEOe34EcPZY2lgOnVonV(4peFfFdt6Z5(GCPNhUymRNP6xEGAV7XgCi4XYlN0jiYlL5cPUK4jQM6KXtMvRrA6WBmL4X(LtBpQmlTmHjl2Jgc6SXZKSjmYFf8PAtxEZ32UGaIU1q0IgUz8w2fBbyUFBryzGHDEGB4R2eK)tz49QSb9HHT37A37Itr0FSqrIh(gwVK7b5l3BapHL04iEYoM9OqhY(NxXd)HTV1qfrmrmggLKu2waydMkmMUuZPmObjSTMIxSaVFnUy(m(FZL4q0BzM(jjdFQuTtBGMDJg5Xc6jA0H0SHTRYwVPkVk6P(Vj0wkdg1mSrv(edczkdJcNhvfUo6gE2FR0rCnHP8kUW28mFZy((m3n6SACBEG3T8TkBsGt74WNxc1vQY58iLuXqutP8UTWpaNdmYWBsJlsy(MQEdnI2qQ7qC7xNmRxcfs55RBxJYOxmnH(N7T0MEfoHMLM3pEsrCK3FA3XDFQwhJ2H6WHMqcvf5ms8VP)R3lC2dy(3wltbjdfDOthEzRUh4Rn8WXNGr1DS88byEB3Y8dCZzHp0i57MH5zvOmVmIhs(XwK68QrAgXk(m88QSCMRV4c)eD1jg46BXMdfK7FDlRK1e(UhEPB(i57RcFdbyXHxdpXnK33aIw(AMOZrh6xSnbdUhd(DO3i11N((Mb1Rzrr5s2WFELFiLowFufByW2lDlImM072Clf9LeZvkKhX7UFURfrno(YuBPDyvDSQmUYGqERAluenY1SW47LBhhAWensIQ)cjr2JF(RF5Rx(UROsHK6cC7O5DK3FlOmDlJLGnZtFRAD5Tn)OURPgDZJXDD8S0opWOqCGziGLVbzNTCX9UPywIqwg)2w8DManxNoRET8ZgV)3bwiH5HUZoL)IHSoaP)Faer9(2((99)(p8CFLF7)DbHM9JZ)PsX6Xi)pxlrVJ5Iz9NyhS6LLxcPrT6BfyTYLObTEruAfC1vZPbT2BzsRalU9nnaLVCbTcKMUMgKAp1o4vxEMeqvFL0ki4LJPbbVVoScGf)Es4T5v0k6u3RLedAVnucf0Q3mRkKmU6f(cqN57M1XbRNFe33eXBTfnkkDIrpQG4aSw56xrI72v9YAnFcn4ANZRinJwBsWOvTBNcrvD8hGiCRbCLV9ySN5MZ7SpeHT3rF9bvLDS3bm3tONRQD9SmEvJ6rpUOhoekgen7bYUgNLVBxZGmHSDEnn(16Goex2BgVb8LXON1W9OxK2ORvHfsO1df)I3mHI(g0mkkevdiu4gu)uDGQg0iKhKBFuTc3V03wHJMTnA7TAgEv(Zg0EpYzD7RT(CJMCAuy9gee6UCqxTaN0e3(lIlxC38DXvru8jJYhvLrRrkANMoWsru712U56PEzBfMm6VsUsU6j9IGk3wA(UGQif)ypXoH6vrvZ81AZYpyyT7nrDO9UD1gqCO8ObdRBMD(8ZMapCixer)QAoW6yYKrXTWD7Afh72XhK69cCKnt6HdPIL)I5NnyOE5M3TZO8aNF6iKCQvVw5K0kcaoRrJO9iy)TU0C7Qbd1RTmInMbu868zd6(1VC(Kbhzv42lJbGJp4xFs(r5T(guAkQqHF1zBT82krkjoF(PMSYPTywlwrvYLV0RRuymN89C8zvqaA)9GEmwWGKx41tX)eVoIpRKZS(qopNY7ETGLwqhWRlOjvw18a9IuRttOpXUKcQcm9STaYyf7vRUHt9LSB3uSB1W8OlL37FTGiQNy9ak8rJoTUMslkDvRfmqVFYo)Kz0yrSt0ncUyUnmGnzwFG)0j2oB9OgTWg9kvUFtVAnro8qTgw7XjfPHQSBZSacOE9c2uzpgHJmql9Mm785AnygrijZpTzWmZpB3U2AMmr8ZCbWb15nkwIxLiGD4))ggkA1qsSFt1eoYiq08oiFs9njrC0eDqd37WtRjAu8tggqVMKQzULGGE2aj9PQeCRPwA6U)P3vmgeSrfuebtBE9jYWOjUqiyLgrEa2fZNAjT3hv7Tyq1pL80qdJlM0)iuBTFvmOlzmg0cKzDMaXUDw6rLlW(2yuZQniHef2M8tBbOiOvz8jKXFwsRTKiZzJNb0RLoA4zIG)HYOA)FqRHCyINNgNnWUCt4u6P3vhMoMQfh2qIM8qSf3SbpGmwPpXTnrGHQnQ8BQaDrZy8TPd0)2VW0prTwvqRglQEYaHFGrVy0K8p1ItUNQIGf2RTEMOtwuwrevDChyuIZtMzLBAW4VMAFRQoh6Z8N7wHOgwoXKSMBNUWfKOw0Nyz(NoAKnzVfYJCFPQ3eWF8eApbJDmI6dyEGlDoHtSetW)p03bMHvG0KMYOPVd6Epa3MTRbyOvBDlUw4Gd7QNcmWcOlCuzxeik30b1saTUv32rj1IiSBgtguR13edfD4gZEPJl1yPQDsdXbn2sYV3MM1xVAvW4PIAmGdI3hIgRz9OMnwv7UAS6XYcT8K(qf9lD8HksERjT)1ksX5iTjBXIF08IMl)ogjVM5j2GYSho06EHddepIRZThG1zUMhg6QYkVL68Cyy0p2teLshFzfpiKc6SK2ghgwGmnfAmh4Nhc1QiBBOgApKTHYK(bxZoqPNa2O3tMizVw)ipOWT4tgXps1Gdvd1R2tObuA(QjgTrDhQgPJl4NaI0AP9OECRzXsaqZyqTcRqdQFVd1vRKD3ak9w9te74Bw1Vq)nRsXyasAOZOvAHMkAuaqQvp1eM(Yxp6w6tTGYUh0UBy5sqaqFAKQP9FLAYEw)oPRqQ4ZYEp2xM2jmDT10cyT6VXcCgNooDgbe0ckHfwVNUMCL3dKl)V)]] )


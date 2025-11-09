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
-- Local aliases for core state helpers and tables (improves static checks and readability).
local applyBuff, removeBuff, applyDebuff, removeDebuff = state.applyBuff, state.removeBuff, state.applyDebuff, state.removeDebuff
local removeDebuffStack = state.removeDebuffStack
local summonPet, dismissPet, setDistance, interrupt = state.summonPet, state.dismissPet, state.setDistance, state.interrupt
local buff, debuff, cooldown, active_dot, pet, totem, action =state.buff, state.debuff, state.cooldown, state.active_dot, state.pet, state.totem, state.action
local setCooldown = state.setCooldown
local addStack, removeStack = state.addStack, state.removeStack
local gain,rawGain, spend,rawSpend = state.gain, state.rawGain, state.spend, state.rawSpend
local talent = state.talent
local floor = math.floor
local min, max = math.min, math.max
local strformat = string.format
local ipairs = ipairs

local spec = Hekili:NewSpecialization(103, true)

spec.name = "Feral"
spec.role = "DAMAGER"
spec.primaryStat = 2 -- Agility

local function getSpecConfig()
    local profile = Hekili.DB and Hekili.DB.profile
    if not profile or not profile.specs then return nil end
    profile.specs[ 103 ] = profile.specs[ 103 ] or {}
    local specConfig = profile.specs[ 103 ]
    specConfig.settings = specConfig.settings or {}
    return specConfig
end

local function getSpecSettingRaw( key )
    local specConfig = getSpecConfig()
    if not specConfig then return nil end

    local settings = specConfig.settings
    if settings and settings[ key ] ~= nil then
        return settings[ key ]
    end

    if specConfig[ key ] ~= nil then
        return specConfig[ key ]
    end

    return nil
end

local function getSetting( key, default )
    local value = getSpecSettingRaw( key )
    if value == nil then
        return default
    end
    return value
end

local function settingEnabled( key, default )
    local value = getSpecSettingRaw( key )
    if value == nil then
        if default ~= nil then
            return default ~= false
        end
        return true
    end
    return value ~= false
end

local function isSpellKnown( spellID )
    if not spellID then return false end

    if type( spellID ) == "table" then
        for _, id in ipairs( spellID ) do
            if isSpellKnown( id ) then
                return true
            end
        end
        return false
    end

    if IsPlayerSpell and IsPlayerSpell( spellID ) then
        return true
    end

    if IsSpellKnown and IsSpellKnown( spellID, false ) then
        return true
    end

    return false
end

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

    local eclipse = state.balance_eclipse
    if eclipse then
        eclipse.power = eclipse.power or 0
        eclipse.direction = eclipse.direction or "solar"
    end
    
    -- Removed workaround sync - testing core issue
end )

-- Additional debugging hook for when recommendations are generated
spec:RegisterHook( "runHandler", function( ability )
    if not ability then return end

    local action = ability
    if type( ability ) == "table" then
        action = ability.key or ability.action or ability[1]
    end

    local eclipse = state.balance_eclipse
    if not eclipse then return end

    local function clamp_power( power )
        if power > 100 then return 100 end
        if power < -100 then return -100 end
        return power
    end

    if action == "wrath" then
        eclipse.power = clamp_power( ( eclipse.power or 0 ) - 15 )
        eclipse.direction = "solar"
    elseif action == "starfire" then
        eclipse.power = clamp_power( ( eclipse.power or 0 ) + 20 )
        eclipse.direction = "lunar"
    elseif action == "starsurge" then
        if eclipse.direction == "lunar" then
            eclipse.power = clamp_power( ( eclipse.power or 0 ) + 20 )
        else
            eclipse.power = clamp_power( ( eclipse.power or 0 ) - 20 )
        end
    elseif action == "celestial_alignment" then
        eclipse.power = 0
        eclipse.direction = "solar"
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
        id = 770,
        duration = 300,
        max_stack = 1,
        name = "Faerie Fire",
    },

--[[
    mangle = {
        id = 33876, -- Mangle (Cat) debuff
        duration = 60,
        max_stack = 1,
        name = "Mangle",
    },
]]

    jungle_stalker = {
        duration = 15,
        max_stack = 1,
    },

    savage_roar = { --野蛮咆哮
        id = 127538,
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
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
    },
    savage_defense = {
        id = 62606,
        duration = 6,
        max_stack = 3,
    },
    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
    },
    -- Persistent display-only aura to indicate Nature's Swiftness availability.
    -- IMPORTANT: Uses a distinct fake ID to avoid colliding with the real 10s buff (132158).
    -- The APL only checks buff.natures_swiftness (10s) and remains unaffected by this.
    natures_swiftness_passive = {
        id = 1321580, -- fake ID to avoid state collisions
        duration = 3600,
        max_stack = 1,
        name = "Nature's Swiftness (Passive)",
    },
    dream_of_cenarius_healing = {
        id = 108374,
        duration = 15,
        max_stack = 2,
    },
    tooth_and_claw = {
        id = 135286,
        duration = 6,
        max_stack = 2,
    },
    tooth_and_claw_debuff = {
        id = 135601,
        duration = 15,
        max_stack = 1,
    },
    pulverize = {
        id = 80313,
        duration = 20,
        max_stack = 1,
    },
    celestial_alignment = {
        id = 112071,
        duration = 15,
        max_stack = 1,
    },
    incarnation_chosen_of_elune = {
        id = 102560,
        duration = 30,
        max_stack = 1,
    },
    lunar_eclipse = {
        id = 48518,
        duration = 15,
        max_stack = 1,
    },
    solar_eclipse = {
        id = 48517,
        duration = 15,
        max_stack = 1,
    },
    shooting_stars = {
        id = 93400,
        duration = 12,
        max_stack = 3,
    },
    lunar_shower = {
        id = 81192,
        duration = 6,
        max_stack = 3,
    },
    wild_mushroom_stacks = {
        id = 138094,
        duration = 20,
        max_stack = 3,
    },
    dream_of_cenarius = {
        id = 145152,
        duration = 30,
        max_stack = 1,
        copy = "dream_of_cenarius_damage",
    },

    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
        type = "Magic",
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
    clearcasting = { --节能施法
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
    prowl = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
        multiplier = 1.6,
    },
    rake = { --斜掠
        id = 1822, -- Correct Rake ID for MoP
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
        copy = "rake_debuff",
        meta = {
            tick_dmg = function( t )
                -- Return the snapshotted tick damage for the current Rake DoT
                if not t.up then return 0 end
                if get_bleed_snapshot_value then
                    local stored = get_bleed_snapshot_value( "rake", t.unit )
                    if stored and stored > 0 then
                        return stored
                    end
                end
                if predict_bleed_value then
                    return predict_bleed_value( "rake", nil, t.unit )
                end
                return 0
            end,
            tick_damage = function( t )
                -- Alias for consistency with SimC
                return t.tick_dmg
            end,
            last_snapshot_contains_tigers_fury = function( t )
                if not t.up then return false end
                local snap = get_bleed_snapshot_record( t.unit )
                if not snap then return false end
                return snap.rake_has_tf or false
            end,
        },
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
    rip = { --割裂
        id = 1079,
        duration = function () return 4 + ( combo_points.current * 4 ) end,
        tick_time = 2,
        mechanic = "bleed",
        max_stack = 1,
        meta = {
            tick_dmg = function( t )
                -- Return the snapshotted tick damage for the current Rip DoT
                if not t.up then return 0 end
                if get_bleed_snapshot_value then
                    local stored = get_bleed_snapshot_value( "rip", t.unit )
                    if stored and stored > 0 then
                        return stored
                    end
                end
                if predict_bleed_value then
                    return predict_bleed_value( "rip", nil, t.unit )
                end
                return 0
            end,
            tick_damage = function( t )
                -- Alias for consistency with SimC
                return t.tick_dmg
            end,
            last_snapshot_contains_tigers_fury = function( t )
                if not t.up then return false end
                local snap = get_bleed_snapshot_record( t.unit )
                if not snap then return false end
                return snap.rip_has_tf or false
            end,
        },
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
    thrash = {
        id = 106830,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
        -- Cat-form Thrash only; bear-form Thrash tracked separately as 'thrash_bear'.
    },

    thrash_cat = { --痛击(猫)
        id = 106830,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
    },
    -- Bear-form Thrash (separate aura so we can gate bear exit reliably).
    thrash_bear = { --痛击(熊)
        id = 77758,
        duration = 16,
        tick_time = 2,
        mechanic = "bleed",
        max_stack = 1,
    },
    tiger_dash = {
        id = 252216,
        duration = 5,
        type = "Magic",
        max_stack = 1
    },
    tigers_fury = { --猛虎之怒
        id = 5217,
        duration = 6,
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
    weakened_blows = {
        id = 115767,
        duration = 30,
        max_stack = 1,
        type = "debuff",
        unit = "target",
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
        duration = 3600,
        max_stack = 1,
    },

    -- Racial ability auras
    blood_fury = {
        id = 20572,
        duration = 15,
        max_stack = 1,
        type = "Magic",
    },

    berserking = {
        id = 26297,
        duration = 10,
        max_stack = 1,
        type = "Magic",
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
            Hekili.DB.profile.specs[103].settings = Hekili.DB.profile.specs[103].settings or {}
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
    if conduit and conduit.tireless_pursuit and conduit.tireless_pursuit.enabled and ( buff.cat_form.up or buff.travel_form.up ) then
        applyBuff( "tireless_pursuit" )
    end

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
        state.break_stealth()
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
    ravage            = true,
    swipe_cat         = true,
    thrash_cat        = true,
    mangle_cat        = true,
    lacerate          = true,
    maul              = true,
    thrash_bear       = true,
    mangle_bear       = true,
    lacerate_bear     = true,
    maul_bear         = true
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
        elseif k == "delay_berserking" then return getSetting( "delay_berserking", nil )
        elseif debuff[ k ] ~= nil then return debuff[ k ]
        end
    end
} ) )

-- MoP: Bleeding considers Rake, Rip, Thrash (Cat), and Thrash (Bear) for gating decisions.
spec:RegisterStateExpr( "bleeding", function ()
    return debuff.rake.up or debuff.rip.up or debuff.thrash.up or ( debuff.thrash_bear and debuff.thrash_bear.up )
end )

-- MoP: Effective stealth is only Prowl or Incarnation (no Shadowmeld for snapshotting in MoP).
spec:RegisterStateExpr( "stealthed_all", function ()
    if buff.stealthed and buff.stealthed.all ~= nil then
        return buff.stealthed.all
    end
    return buff.prowl.up or ( buff.incarnation and buff.incarnation.up )
end )

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

-- Advanced energy pooling system based on WoWSims pooling_actions.go
-- Calculate floating energy needed for upcoming ability refreshes
spec:RegisterStateExpr( "floating_energy", function()
    local floatingEnergy = 0
    local currentTime = query_time or 0
    local regenRate = energy.regen or 10
    
    -- Pooling actions that need energy in the near future
    local poolingActions = {}
    
    -- Add Rake refresh (35 energy, refresh when < 4.5s remaining)
    if debuff.rake.up and debuff.rake.remains < 8 then
        local refreshTime = debuff.rake.remains
        table.insert(poolingActions, {refreshTime = refreshTime, cost = 35})
    end
    
    -- Add Rip refresh (20 energy, refresh when < 4s remaining) 
    if debuff.rip.up and debuff.rip.remains < 6 then
        local refreshTime = debuff.rip.remains
        table.insert(poolingActions, {refreshTime = refreshTime, cost = 20})
    end
    
    -- Add Savage Roar refresh (25 energy, refresh when < 1s remaining)
    if buff.savage_roar.up and buff.savage_roar.remains < 3 then
        local refreshTime = buff.savage_roar.remains
        table.insert(poolingActions, {refreshTime = refreshTime, cost = 25})
    end
    
    -- Sort actions by refresh time
    table.sort(poolingActions, function(a, b) return a.refreshTime < b.refreshTime end)
    
    -- Calculate floating energy needed
    local previousTime = 0
    local tfPending = false
    
    for _, action in ipairs(poolingActions) do
        local elapsedTime = action.refreshTime - previousTime
        local energyGain = elapsedTime * regenRate
        
        -- Check if Tiger's Fury will be available before this refresh
        if not tfPending and cooldown.tigers_fury.remains <= action.refreshTime then
            tfPending = true
            action.cost = action.cost - 60 -- Tiger's Fury gives 60 energy
        end
        
        if energyGain < action.cost then
            floatingEnergy = floatingEnergy + (action.cost - energyGain)
            previousTime = action.refreshTime
        else
            previousTime = previousTime + (action.cost / regenRate)
        end
    end
    
    return floatingEnergy
end )

-- Check if we should pool energy for upcoming refreshes (based on SimC pool input)
spec:RegisterStateExpr( "should_pool_energy", function()
    local poolLevel = getSetting( "pool", 0 ) or 0 -- 0=no pooling, 1=light, 2=heavy
    
    if poolLevel == 0 then
        return false -- No pooling
    end
    
    -- Never pool when we have combo points to spend
    if combo_points.current >= 1 then
        return false
    end
    
    -- Simple pooling logic - let pool_resource handle the actual pooling
    return true
end )

-- Next refresh time for energy pooling decisions
spec:RegisterStateExpr( "next_refresh_time", function()
    local nextTime = 999
    
    -- Find the earliest refresh time
    if debuff.rake.up and debuff.rake.remains < 8 and debuff.rake.remains < nextTime then
        nextTime = debuff.rake.remains
    end
    if debuff.rip.up and debuff.rip.remains < 6 and debuff.rip.remains < nextTime then
        nextTime = debuff.rip.remains
    end
    if buff.savage_roar.up and buff.savage_roar.remains < 3 and buff.savage_roar.remains < nextTime then
        nextTime = buff.savage_roar.remains
    end
    
    return nextTime < 999 and nextTime or 0
end )

-- Energy efficiency calculations for pooling decisions
spec:RegisterStateExpr( "energy_efficiency", function()
    -- Calculate how efficiently we're using energy
    local currentEfficiency = energy.current / energy.max
    local poolingThreshold = floating_energy / energy.max
    
    -- Return efficiency score (0-1, higher is better)
    if floating_energy == 0 then return 1 end
    return math.min(1, currentEfficiency / poolingThreshold)
end )

-- Check if we're in a pooling phase (holding energy for upcoming refreshes)
spec:RegisterStateExpr( "in_pooling_phase", function()
    return should_pool_energy and next_refresh_time > 0 and next_refresh_time < 8
end )

-- Advanced Ferocious Bite conditions based on WoWSims canBite() logic
spec:RegisterStateExpr( "can_bite", function()
    local isExecutePhase = target.health.pct <= 25
    local biteTime = buff.berserk.up and 6 or 11 -- BerserkBiteTime vs BiteTime
    
    -- Must have enough Savage Roar duration
    if buff.savage_roar.remains < biteTime then
        return false
    end
    
    -- In execute phase: allow if we have a better snapshot or during berserk
    if isExecutePhase then
        return (rip_damage_increase_pct > 0.001) or buff.berserk.up
    end
    
    -- Normal phase: ensure Rip has enough duration
    return debuff.rip.remains >= biteTime
end )

-- Rip break-even threshold calculation (based on WoWSims calcRipEndThresh)
spec:RegisterStateExpr( "rip_end_threshold", function()
    if combo_points.current < 5 then
        return 0 -- Can't cast Rip without 5 CPs
    end
    
    -- Calculate break-even point between Rip and Ferocious Bite
    local expectedBiteDPE = 1.0 -- Simplified - would need actual damage calculations
    local expectedRipTickDPE = 0.3 -- Simplified - would need actual damage calculations
    local numTicksToBreakEven = 1 + math.ceil(expectedBiteDPE / expectedRipTickDPE)
    
    -- Return minimum Rip duration needed to be worth casting
    return numTicksToBreakEven * 2 -- Assuming 2s tick time
end )

-- Savage Roar clipping logic (based on WoWSims clipRoar)
spec:RegisterStateExpr( "should_clip_roar", function()
    local isExecutePhase = target.health.pct <= 25
    local ripRemaining = debuff.rip.remains or 0
    local simTimeRemaining = target.time_to_die or 300
    
    -- Don't clip if no Rip or fight ending soon
    if not debuff.rip.up or (simTimeRemaining - ripRemaining < rip_end_threshold) then
        return false
    end
    
    -- Project Rip end time with Shred extensions
    local remainingExtensions = 12 - 6 -- maxRipTicks - currentTickCount (simplified)
    local ripDur = ripRemaining + (remainingExtensions * 2) -- Assuming 2s tick time
    local roarDur = buff.savage_roar.remains or 0
    
    -- Don't clip if Roar already covers Rip duration + leeway
    if roarDur > (ripDur + 1) then -- 1s leeway
        return false
    end
    
    -- Don't clip if roar covers rest of fight
    if roarDur >= simTimeRemaining then
        return false
    end
    
    -- Calculate new Roar duration with current CPs
    local newRoarDur = combo_points.current * 6 + 6 -- Simplified calculation
    
    -- If new roar covers rest of fight, clip now for CP efficiency
    if newRoarDur >= simTimeRemaining then
        return true
    end
    
    -- Don't clip if waiting one more GCD would be more efficient
    if newRoarDur + 1.5 + (combo_points.current < 5 and 5 or 0) >= simTimeRemaining then
        return false
    end
    
    -- Execute phase: optimize for minimal Roar casts
    if isExecutePhase then
        if combo_points.current < 5 then return false end
        local minRoarsPossible = math.ceil((simTimeRemaining - roarDur) / newRoarDur)
        local projectedRoarCasts = math.ceil(simTimeRemaining / newRoarDur)
        return projectedRoarCasts == minRoarsPossible
    end
    
    -- Normal phase: clip if new roar expires well after current rip
    return newRoarDur >= (ripDur + 30) -- 30s offset
end )

-- Tiger's Fury timing prediction (based on WoWSims tfExpectedBefore)
-- Removed duplicate - using StateFunction version below

-- Builder DPE calculation (based on WoWSims calcBuilderDpe)
spec:RegisterStateExpr( "rake_vs_shred_dpe", function()
    -- Simplified DPE comparison - in real implementation would need actual damage calculations
    local rakeDPE = 1.0 -- Would calculate: (initial_damage + tick_damage * potential_ticks) / energy_cost
    local shredDPE = 0.8 -- Would calculate: expected_damage / energy_cost
    
    return rakeDPE > shredDPE
end )

-- Energy threshold with latency consideration (based on WoWSims calcTfEnergyThresh)
spec:RegisterStateExpr( "tf_energy_threshold", function()
    local reaction_time = 0.1
    local delay_time = reaction_time
    if buff.clearcasting.up then
        delay_time = delay_time + 1.0
    end
    return 40 - ( delay_time * energy.regen )
end )

-- Cat Excess Energy calculation (based on WoWSims APLValueCatExcessEnergy)
spec:RegisterStateExpr( "cat_excess_energy", function()
    local floatingEnergy = 0
    local simTimeRemain = target.time_to_die or 300
    local regenRate = energy.regen or 10
    local currentTime = query_time or 0
    
    -- Create pooling actions array (enhanced version of WoWSims PoolingActions)
    local poolingActions = {}
    
    -- Rip refresh (if active and will expire before fight end, and we have 5 CPs)
    if debuff.rip.up and debuff.rip.remains < (simTimeRemain - 10) and combo_points.current == 5 then
        local ripCost = tf_expected_before( debuff.rip.remains ) and 10 or 20 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = debuff.rip.remains, cost = ripCost})
    end
    
    -- Rake refresh (if active and will expire before fight end)
    if debuff.rake.up and debuff.rake.remains < (simTimeRemain - 9) then -- Rake duration is ~9s
        local rakeCost = tf_expected_before( debuff.rake.remains ) and 17.5 or 35 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = debuff.rake.remains, cost = rakeCost})
    end
    
    -- Mangle refresh (if bleed aura will expire - represented by Rake being down/expiring)
    if not debuff.rake.up or debuff.rake.remains < (simTimeRemain - 1) then
        local mangleCost = tf_expected_before( debuff.rake.remains or 0 ) and 20 or 40 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = (debuff.rake.remains or 0), cost = mangleCost})
    end
    
    -- Savage Roar refresh (if active)
    if buff.savage_roar.up then
        local roarCost = tf_expected_before( buff.savage_roar.remains ) and 12.5 or 25 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = buff.savage_roar.remains, cost = roarCost})
    end
    
    -- Sort actions by refresh time (earliest first)
    table.sort(poolingActions, function(a, b) return a.refreshTime < b.refreshTime end)
    
    -- Calculate floating energy needed (enhanced algorithm from WoWSims)
    local previousTime = currentTime
    local tfPending = false
    
    for _, action in ipairs(poolingActions) do
        local elapsedTime = action.refreshTime - previousTime
        local energyGain = elapsedTime * regenRate
        
        -- Check if Tiger's Fury will be available before this refresh
        if not tfPending and tf_expected_before( action.refreshTime ) then
            tfPending = true
            action.cost = action.cost - 60 -- Tiger's Fury gives 60 energy
        end
        
        if energyGain < action.cost then
            floatingEnergy = floatingEnergy + (action.cost - energyGain)
            previousTime = action.refreshTime
        else
            previousTime = previousTime + (action.cost / regenRate)
        end
    end
    
    return energy.current - floatingEnergy
end )

-- New Savage Roar Duration based on combo points (based on WoWSims SavageRoarDurationTable)
spec:RegisterStateExpr( "new_savage_roar_duration", function()
    -- Savage Roar duration table from WoWSims: [0, 18, 24, 30, 36, 42] seconds
    -- Glyphed: [12, 18, 24, 30, 36, 42] seconds
    local isGlyphed = false -- Would need to check for glyph in real implementation
    local durationTable = {0, 18, 24, 30, 36, 42}
    if isGlyphed then
        durationTable = {12, 18, 24, 30, 36, 42}
    end
    
    local cp = math.min(combo_points.current, 5)
    return durationTable[cp + 1] or 42
end )

-- Savage Roar pandemic effect calculation (based on WoWSims tick tracking)
spec:RegisterStateExpr( "savage_roar_pandemic_duration", function()
    if not buff.savage_roar.up then
        return new_savage_roar_duration
    end
    
    local currentRemaining = buff.savage_roar.remains or 0
    local newDuration = new_savage_roar_duration
    
    -- Pandemic effect: can extend duration up to 130% of base duration
    local maxExtension = newDuration * 1.3
    local pandemicDuration = math.min(currentRemaining + newDuration, maxExtension)
    
    return pandemicDuration
end )

-- Check if we should clip Savage Roar for pandemic optimization
spec:RegisterStateExpr( "should_clip_roar_pandemic", function()
    if not buff.savage_roar.up then return true end
    
    local currentRemaining = buff.savage_roar.remains or 0
    local newDuration = new_savage_roar_duration
    
    -- Clip if we're within 1 tick (3 seconds) of pandemic threshold
    local pandemicThreshold = newDuration * 0.3
    return currentRemaining <= pandemicThreshold + 3
end )

-- Expected Swipe Damage calculation (based on WoWSims calcExpectedSwipeDamage)
spec:RegisterStateExpr( "expected_swipe_damage", function()
    -- Simplified calculation - would need actual damage formulas
    local baseSwipeDamage = 100 -- Base damage per target
    local swipeDamage = baseSwipeDamage * active_enemies
    local swipeDPE = swipeDamage / 45 -- Assuming 45 energy cost
    
    return swipeDamage
end )

-- Expected Swipe DPE calculation (separate for cleaner access)
spec:RegisterStateExpr( "expected_swipe_dpe", function()
    local baseSwipeDamage = 100 -- Base damage per target
    local swipeDamage = baseSwipeDamage * active_enemies
    local swipeDPE = swipeDamage / 45 -- Assuming 45 energy cost
    
    return swipeDPE
end )

-- Roar vs Swipe DPE comparison (based on WoWSims AoE rotation logic)
spec:RegisterStateExpr( "roar_vs_swipe_dpe", function()
    if combo_points.current < 1 then return false end
    
    -- Calculate Roar DPE
    local baseAutoDamage = 50 -- Simplified auto attack damage
    local buffEnd = math.min(target.time_to_die or 300, new_savage_roar_duration)
    local numBuffedAutos = 1 + math.floor(buffEnd / 2) -- Assuming 2s auto attack speed
    local roarMultiplier = 1.4 -- Savage Roar multiplier
    local roarDPE = ((roarMultiplier - 1) * baseAutoDamage * numBuffedAutos) / 25 -- Assuming 25 energy cost
    
    -- Get Swipe DPE
    local swipeDPE = expected_swipe_dpe
    
    return roarDPE >= swipeDPE
end )

-- Multi-target Rake target selection (based on WoWSims AoE rotation)
spec:RegisterStateExpr( "best_rake_target", function()
    -- Simplified - would need to track multiple targets
    -- For now, just return current target if Rake is down or expiring
    if not debuff.rake.up or debuff.rake.remains < 4.5 then
        return true
    end
    
    return false
end )

-- AoE bear weave energy threshold
spec:RegisterStateExpr( "aoe_bear_weave_energy", function()
    local swipeCost = 45 -- Swipe Cat cost
    local bearShiftCost = 0 -- No energy cost to shift forms
    local totalCost = swipeCost + bearShiftCost
    
    -- Pool energy for bear weave if we have excess
    return energy.current > totalCost + 20 -- 20 energy buffer
end )

-- Thrash AoE efficiency (based on WoWSims bear AoE rotation)
spec:RegisterStateExpr( "thrash_aoe_efficient", function()
    -- Thrash is more efficient than other bear abilities for AoE
    -- In bear form, Thrash is the primary AoE ability
    return active_enemies >= 3 and buff.bear_form.up
end )

-- WoWSims calcBleedRefreshTime with DPE clipping logic
spec:RegisterStateExpr( "rake_refresh_time", function()
    if not debuff.rake.up then return 0 end
    
    local currentRemaining = debuff.rake.remains or 0
    local tickLength = 3
    local standardRefreshTime = currentRemaining - tickLength
    
    if buff.dream_of_cenarius_damage.up and (rake_damage_increase_pct > 0.001) then
        return 0
    end
    
    if not buff.tigers_fury.up and not buff.synapse_springs.up then
        return math.max(0, standardRefreshTime)
    end
    
    local tempBuffRemains = buff.tigers_fury.up and buff.tigers_fury.remains or buff.synapse_springs.remains
    
    if tempBuffRemains > standardRefreshTime + 0.5 then
        return math.max(0, standardRefreshTime)
    end
    
    local latestPossibleSnapshot = tempBuffRemains - 0.2
    if latestPossibleSnapshot <= 0 then return 0 end
    
    local numClippedTicks = math.floor((currentRemaining - latestPossibleSnapshot) / tickLength)
    local targetClipTime = math.max(0, standardRefreshTime - (numClippedTicks * tickLength))
    local fightRemaining = target.time_to_die or 300
    local buffedTickCount = math.min(5, math.floor((fightRemaining - targetClipTime) / tickLength))
    
    local expectedDamageGain = rake_damage_increase_pct * (buffedTickCount + 1)
    local shredDamagePerEnergy = 0.025
    local energyEquivalent = expectedDamageGain / shredDamagePerEnergy
    local discountedRefreshCost = 35 * (1.0 - (numClippedTicks / 5.0))
    
    if buff.berserk.up and buff.berserk.remains > targetClipTime + 0.5 then
        return (expectedDamageGain > 0) and targetClipTime or math.max(0, standardRefreshTime)
    else
        return (energyEquivalent > discountedRefreshCost) and targetClipTime or math.max(0, standardRefreshTime)
    end
end )

spec:RegisterStateExpr( "rip_refresh_time", function()
    if not debuff.rip.up then return 0 end
    
    local currentRemaining = debuff.rip.remains or 0
    local tickLength = 2
    local standardRefreshTime = currentRemaining - tickLength
    
    if buff.dream_of_cenarius_damage.up and (rip_damage_increase_pct > 0.001) then
        return 0
    end
    
    if not buff.tigers_fury.up and not buff.synapse_springs.up then
        return math.max(0, standardRefreshTime)
    end
    
    if combo_points.current < 5 then
        return math.max(0, standardRefreshTime)
    end
    
    local tempBuffRemains = buff.tigers_fury.up and buff.tigers_fury.remains or buff.synapse_springs.remains
    
    if tempBuffRemains > standardRefreshTime + 0.5 then
        return math.max(0, standardRefreshTime)
    end
    
    local latestPossibleSnapshot = tempBuffRemains - 0.2
    if latestPossibleSnapshot <= 0 then return 0 end
    
    local numClippedTicks = math.floor((currentRemaining - latestPossibleSnapshot) / tickLength)
    local targetClipTime = math.max(0, standardRefreshTime - (numClippedTicks * tickLength))
    local fightRemaining = target.time_to_die or 300
    local maxRipTicks = 12
    local buffedTickCount = math.min(maxRipTicks, math.floor((fightRemaining - targetClipTime) / tickLength))
    
    local expectedDamageGain = rip_damage_increase_pct * buffedTickCount
    local shredDamagePerEnergy = 0.025
    local energyEquivalent = expectedDamageGain / shredDamagePerEnergy
    local discountedRefreshCost = 20 * (numClippedTicks / maxRipTicks)
    
    if buff.berserk.up and buff.berserk.remains > targetClipTime + 0.5 then
        return (expectedDamageGain > 0) and targetClipTime or math.max(0, standardRefreshTime)
    else
        return (energyEquivalent > discountedRefreshCost) and targetClipTime or math.max(0, standardRefreshTime)
    end
end )

-- WoWSims calcTfEnergyThresh
spec:RegisterStateExpr( "tf_energy_threshold_advanced", function()
    local reactionTime = 0.1
    local clearcastingDelay = buff.clearcasting.up and 1.0 or 0.0
    local totalDelay = reactionTime + clearcastingDelay
    local threshold = math.max( 0, 40 - (totalDelay * (energy.regen or 0)) )

    if settingEnabled( "use_healing_touch", true ) and buff.dream_of_cenarius_damage.up and ( combo_points.current == 5 ) then
        return 100
    end

    return threshold
end )

spec:RegisterStateExpr( "tf_timing", function()
    if cooldown.tigers_fury.ready then
        return energy.current <= tf_energy_threshold_advanced
    end
    return energy.current <= 20 and cooldown.tigers_fury.remains <= 3
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


spec:RegisterStateExpr( "shred_position_ok", function ()
    if behind_target then return true end

    local stealthed = buff.stealthed.up or buff.prowl.up or buff.shadowmeld.up
    if stealthed then return true end

    local incarnation = buff.incarnation_king_of_the_jungle or buff.incarnation
    if incarnation and incarnation.up then
        return true
    end

    if debuff.mighty_bash.up or debuff.maim.up or debuff.incapacitating_roar.up or debuff.pulverize.up then
        return true
    end

    return false
end )

-- Missing state expressions for APL functionality
spec:RegisterStateExpr( "combo_points_for_rip", function ()
    return combo_points.current >= 5
end )

spec:RegisterStateExpr( "rake_stronger", function ()
    if not debuff.rake.up then return true end
    -- Check if new Rake would be stronger (TF buff active)
    return buff.tigers_fury.up and not debuff.rake.last_snapshot_contains_tigers_fury
end )

spec:RegisterStateExpr( "rip_stronger", function ()
    if not debuff.rip.up then return true end
    -- Check if new Rip would be stronger (TF buff active)
    return buff.tigers_fury.up and not debuff.rip.last_snapshot_contains_tigers_fury
end )

spec:RegisterStateExpr( "delay_rip_for_tf", function ()
    -- Don't delay if TF is on cooldown or already up
    if cooldown.tigers_fury.remains > 3 or buff.tigers_fury.up then return false end
    -- Delay if TF is coming up soon
    return cooldown.tigers_fury.remains < 1.5
end )

spec:RegisterStateExpr( "delay_rake_for_tf", function ()
    -- Don't delay if TF is on cooldown or already up
    if cooldown.tigers_fury.remains > 3 or buff.tigers_fury.up then return false end
    -- Delay if TF is coming up soon
    return cooldown.tigers_fury.remains < 1.5
end )

spec:RegisterStateExpr( "clip_rip_with_snapshot", function ()
    -- Allow clipping Rip if we have a better snapshot (Dream of Cenarius, etc)
    return buff.dream_of_cenarius_damage.up and (rip_damage_increase_pct > 0.001)
end )

spec:RegisterStateExpr( "clip_rake_with_snapshot", function ()
    -- Allow clipping Rake if we have a better snapshot
    return buff.dream_of_cenarius_damage.up and (rake_damage_increase_pct > 0.001)
end )

spec:RegisterStateExpr( "disable_shred_when_solo", function ()
    return getSetting( "disable_shred_when_solo", false )
end )

spec:RegisterStateExpr( "should_wrath_weave", function ()
    -- Check if we should wrath weave (Heart of the Wild active)
    return buff.heart_of_the_wild.up and getSetting( "wrath_weaving_enabled", false )
end )

-- Removed simplistic bear weave expression (energy.current > 80). Advanced logic defined later at bottom of file.
-- This placeholder prevents duplicate registration from creating conflicting behavior.
-- See the later spec:RegisterStateExpr("should_bear_weave") near bearweave_trigger_ok for actual conditions.


spec:RegisterStateExpr( "berserk_clip_for_hotw", function ()
    -- Allow Berserk clipping for Heart of the Wild alignment
    if not talent.heart_of_the_wild.enabled then return false end
    return cooldown.heart_of_the_wild.remains < 5 and buff.berserk.remains < 5
end )

-- Setting-based state expressions
spec:RegisterStateExpr( "maintain_ff", function ()
    return getSetting( "maintain_ff", false )
end )

spec:RegisterStateExpr( "opt_bear_weave", function ()
    return getSetting( "opt_bear_weave", true )
end )

spec:RegisterStateExpr( "opt_wrath_weave", function ()
    return getSetting( "opt_wrath_weave", false )
end )

spec:RegisterStateExpr( "opt_snek_weave", function ()
    return getSetting( "opt_snek_weave", false )
end )

spec:RegisterStateExpr( "opt_use_ns", function ()
    return getSetting( "opt_use_ns", true )
end )

spec:RegisterStateExpr( "opt_melee_weave", function ()
    return getSetting( "opt_melee_weave", false )
end )

spec:RegisterStateExpr( "use_trees", function ()
    return getSetting( "use_trees", true )
end )

spec:RegisterStateExpr( "use_hotw", function ()
    return getSetting( "use_hotw", true )
end )

-- Damage increase calculations for snapshot comparisons
spec:RegisterStateExpr( "rake_damage_increase_pct", function ()
    if not debuff.rake.up then return 1.0 end
    local current_tf = debuff.rake.last_snapshot_contains_tigers_fury and 1.15 or 1.0
    local new_tf = buff.tigers_fury.up and 1.15 or 1.0
    return (new_tf - current_tf) / current_tf
end )

spec:RegisterStateExpr( "rip_damage_increase_pct", function ()
    if not debuff.rip.up then return 1.0 end
    local current_tf = debuff.rip.last_snapshot_contains_tigers_fury and 1.15 or 1.0
    local new_tf = buff.tigers_fury.up and 1.15 or 1.0
    return (new_tf - current_tf) / current_tf
end )

-- Tiger's Fury prediction (based on WoWSims)
spec:RegisterStateFunction( "tf_expected_before", function( seconds )
    if seconds == nil then seconds = 0 end
    if buff.tigers_fury.up then return true end
    if cooldown.tigers_fury.remains > seconds then return false end
    
    -- Simple prediction: TF is expected if it's off cooldown or will be within the window
    return cooldown.tigers_fury.remains <= seconds
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

-- Abilities (MoP version, updated)
spec:RegisterAbilities( {
    -- Maintain armor debuff (controlled by maintain_ff toggle)
    faerie_fire= { --精灵之火
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        texture = 136033,
        startsCombat = true,
        usable = function()
            if not settingEnabled( "maintain_ff", true ) then
                return false, "maintain_ff disabled"
            end
            return true
        end,
        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },

    savage_roar = { --野蛮咆哮
        id = 127538,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        texture = 236167,
        spend = function() return buff.berserk.up and 12.5 or 25 end,
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
    mangle_cat = { --裂伤(豹)
        id = 33876,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function() return buff.clearcasting.up and 0 or (buff.berserk.up and 17.5 or 35) end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        known = function()
            return isSpellKnown( { 33876, 33917 } )
        end,
        handler = function()
            gain(1, "combo_points")
        end,
    },
    -- Alias for SimC import token
    mark_of_the_wild = { --野性印记
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
    berserk = { --狂暴(猫)
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
    ferocious_bite = { --凶猛撕咬
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function ()           
            return (buff.clearcasting.up and 0 or (buff.berserk.up and 12.5 or 25)) + min( 25, energy.current -25 )
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
            applyBuff( "prowl" )
        end,
    },

    -- Rake: Bleed damage and awards 1 combo point.
    rake = { --斜掠
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function() return buff.clearcasting.up and 0 or (buff.berserk.up and 17.5 or 35) end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        -- Prevent unnecessary reapplications: only recommend when we're refreshing or have a stronger snapshot.
        usable = function ()
            -- If Rake is already up, only allow if it's time to refresh or our new snapshot would be stronger.
            if debuff.rake.up then
                -- Allow early clip if the calculated refresh time is now or sooner.
                if rake_refresh_time <= 0 then return true end
                -- Allow explicit snapshot clipping (e.g., DoC snapshot logic).
                if clip_rake_with_snapshot then return true end
                -- Otherwise, block the reapplication.
                return false, "rake not ready to refresh"
            end
            return true
        end,

        handler = function ()
            applyDebuff( "target", "rake" )
            gain( 1, "combo_points" )
            store_bleed_snapshot( "rake" )
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
    rip = { --割裂
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function() return buff.clearcasting.up and 0 or (buff.berserk.up and 15 or 30) end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function ()
            return combo_points.current > 0
        end,
        handler = function ()
            local cp = combo_points.current or 0
            local snapshot_cp = max( cp, 1 )
            applyDebuff( "target", "rip" )
            if cp > 0 then
                spend( cp, "combo_points" )
            end
            store_bleed_snapshot( "rip", snapshot_cp )
        end,
    },

    -- Shred: Deals damage and awards 1 combo point.
    -- Handles both normal Shred (5221) and glyph-enhanced Shred! (114236)
    shred = { --撕碎
        id = 5221,
        copy = { 114236 }, -- Glyph of Shred enhanced version
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function() return buff.clearcasting.up and 0 or (buff.berserk.up and 20 or 40) end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function ()
            if shred_position_ok then
                return true
            end

            return false, "requires position or control"
        end,
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Ravage: High-damage opener used from stealth or Incarnation.
    ravage = {
        id = 6785,
        copy = { 102545 }, -- Ravage! free-cast variant
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 60,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Skull Bash: Interrupts spellcasting.
    skull_bash = {
        id = 106839,
        copy = { 80965, 80964 },
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
        known = function()
            return isSpellKnown( { 106839, 80965, 80964 } )
        end,
        handler = function ()
            interrupt()
        end,
    },

    skull_bash_cat = {
        copy = "skull_bash",
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
    thrash_cat = { --痛击(猫)
        id = 106830,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        spend = function() return buff.clearcasting.up and 0 or (buff.berserk.up and 25 or 50) end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            -- Apply the cat-specific Thrash aura so dot.thrash_cat.* tracking works.
            applyDebuff( "target", "thrash_cat" )
            applyDebuff( "target", "weakened_blows" )
            gain( 1, "combo_points" )
            store_bleed_snapshot( "thrash_cat" )
        end,
    },
    thrash_bear = { --痛击(熊)
        id = 77758,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = 0,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function ()
            applyDebuff( "target", "thrash_bear" )
            applyDebuff( "target", "weakened_blows" )
            -- Snapshot the bear Thrash separately for weave timing logic.
            store_bleed_snapshot( "thrash_bear" )
            state.last_bear_thrash_time = query_time
            state.bear_thrash_casted = true
        end,
    },
    -- Tiger's Fury: Instantly restores 60 Energy and increases damage done by 15% for 6 sec.
    tigers_fury = { --猛虎之怒
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
    swipe_cat = { --横扫(猫)
        id = 62078,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function() return buff.clearcasting.up and 0 or (buff.berserk.up and 22.5 or 45) end,
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
        toggle = "cooldowns",
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
        id = 106737,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",
        talent = "force_of_nature",
        toggle = "cooldowns",
        startsCombat = true,
        handler = function ()
            -- Summon handled by game
        end,
        copy = 102703, -- Alternative spell ID for MoP Classic
    },

    -- Shadowmeld: Night Elf racial ability
    shadowmeld = {
        id = 58984,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        known = function()
            return isSpellKnown( 58984 )
        end,
        handler = function ()
            applyBuff( "shadowmeld" )
        end,
    },

    -- Blood Fury: Orc racial ability
    blood_fury = {
        id = 20572,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        toggle = "cooldowns",
        startsCombat = false,
        known = function()
            return IsSpellKnown( 20572, false )
        end,
        handler = function ()
            applyBuff( "blood_fury" )
        end,
    },

    -- Berserking: Troll racial ability
    berserking = {
        id = 26297,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        toggle = "cooldowns",
        startsCombat = false,
        known = function()
            return IsSpellKnown( 26297, false )
        end,
        handler = function ()
            applyBuff( "berserking" )
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
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = -5, -- generates rage in Bear
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function()
            -- Mangle damage in Bear Form
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
        gcd = "spell",
        school = "physical",
        spend = 0,
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
        duration = 3600,
        max_stack = 1,
    },
} )

-- Settings for advanced techniques
spec:RegisterSetting( "bear_weaving_enabled", false, {
    name = "启用熊舞",
    desc = "如果勾选，将在适当的时机切换到熊形态。这涉及切换到熊形态以汇集能量并造成伤害。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "wrath_weaving_enabled", false, {
    name = "启用鸟舞", 
    desc = "如果勾选，将在野性之心激活且未处于战斗中时，切换到枭兽形态使用愤怒造成伤害。",
    type = "toggle",
    width = "full"
} )

-- Consolidated: Use base flags; variables in APL map to these via state expressions below.
spec:RegisterSetting( "opt_snek_weave", true, {
    name = "启用蛇舞",
    desc = "利用 掠食者的迅捷/自然迅捷 来进行 愈合 的快照机制。",
    type = "toggle",
    width = "full"
} )

-- SimC-style toggles for parity with Feral_SimC_APL.simc
spec:RegisterSetting( "maintain_ff", true, {
    name = "保持精灵之火",
    desc = "如果勾选，将在目标身上维持精灵之火（护甲）效果。",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "opt_use_ns", false, {
    name = "使用自然迅捷",
    desc = "使用 自然迅捷 来实现快速的 愈合。",
    type = "toggle",
    width = "full"
} )

spec:RegisterRanges( "rake", "shred", "ravage", "skull_bash", "growl", "moonfire" )

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

    package = "野性(黑科研)"
} )

-- Solo/positioning toggle
spec:RegisterSetting( "disable_shred_when_solo", false, {
    type = "toggle",
    name = "单人时禁用撕碎",
    desc = "如果勾选，在单人游戏时，将不会推荐撕碎。",
    width = "full",
} )

-- Feature toggles
spec:RegisterSetting( "use_trees", true, {
    type = "toggle",
    name = "使用自然之力",
    desc = "如果勾选，自然之力将在满足条件时推荐使用。",
    width = "full",
} )

spec:RegisterSetting( "use_hotw", false, {
    type = "toggle",
    name = "使用野性之魂",
    desc = "如果勾选，野性之魂将在满足条件时推荐使用。",
    width = "full",
} )

spec:RegisterSetting( "pool", 1, {
    name = "积蓄能量",
    desc = "控制循环中为优化时机，而积蓄能量的基金程度。\n0 = 不积蓄(立即施法)\n1 = 轻度积蓄(保证主要技能)\n2 = 重度积蓄(最优时机)",
    type = "select",
    values = { [0] = "不积蓄", [1] = "轻度积蓄", [2] = "重度积蓄" },
    width = "full",
} )

-- Use Healing Touch (WoWSims parity)
spec:RegisterSetting( "use_healing_touch", true, {
    name = "使用治疗之触",
    desc = "如果勾选，治疗之触将在满足条件时推荐使用。",
    type = "toggle",
    width = "full",
} )


spec:RegisterSetting( "rip_duration", 9, {
    name = strformat( "%s 持续时间", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    desc = strformat( "如果设置为 |cFFFFD1000|r 以上，%s将在目标死亡前指定时间内不被推荐。",
        Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    type = "range",
    min = 0,
    max = 18,
    step = 0.1,
    width = 1.5
} )

spec:RegisterSetting( "regrowth", true, {
    name = strformat( "填充%s", Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    desc = strformat( "如果勾选，%s 可能在较高优先级技能不可用时被推荐作为填充技能。这通常只在非常低的能量下才会发生。",
        Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    type = "toggle",
    width = "full",
} )

-- Enable/disable Ferocious Bite in rotation (mapped to user's setting key)
spec:RegisterSetting( "ferociousbite_enabled", true, {
    name = "启用凶猛撕咬",
    desc = "如果勾选，凶猛撕咬将在满足条件时推荐使用。",
    type = "toggle",
    width = "full",
} )

-- Expose Ferocious Bite enable flag and bite thresholds for APL expressions
spec:RegisterStateExpr( "ferociousbite_enabled", function()
    return settingEnabled( "ferociousbite_enabled", true )
end )

spec:RegisterStateExpr( "min_bite_rip_remains", function()
    return getSetting( "min_bite_rip_remains", 11 ) or 11
end )

spec:RegisterStateExpr( "min_bite_sr_remains", function()
    return getSetting( "min_bite_sr_remains", 11 ) or 11
end )

spec:RegisterVariable( "regrowth", function()
    return settingEnabled( "regrowth", true )
end )

spec:RegisterStateExpr( "filler_regrowth", function()
    return settingEnabled( "regrowth", true )
end )

spec:RegisterSetting( "solo_prowl", false, {
    name = strformat( "允许单人时使用%s", Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    desc = strformat( "如果勾选，%s 可以在单人游戏时推荐使用。默认关闭，因为它可能会导致脱离战斗。",
        Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "allow_shadowmeld", nil, {
    name = strformat( "使用 %s", Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    desc = strformat( "如果勾选，当暗夜精灵角色满足 %s 的使用条件时，将可能推荐使用该技能。建议仅在首领战或队伍中使用，避免脱离战斗。",
        Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    type = "toggle",
    width = "full",
    get = function () return not Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled end,
    set = function ( _, val )
        Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled = not val
    end,
} )

spec:RegisterSetting( "lazy_swipe", false, {
    name = strformat( "在AOE中最少使用%s", Hekili:GetSpellLinkWithTexture( spec.abilities.shred.id ) ),
    desc = "如果勾选，在多目标情况下，%s将被尽可能少的使用。这会损失DPS，但执行起来更简单。",
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
    return settingEnabled( "lazy_swipe", false )
end )

spec:RegisterVariable( "solo_prowl", function()
    return settingEnabled( "solo_prowl", false )
end )

-- Bleed snapshot tracking (minimal: Tiger's Fury multiplier)
spec:RegisterStateTable( "balance_eclipse", {
    power = 0,
    direction = "solar",
    reset = function( t )
        t.power = 0
        t.direction = "solar"
    end
} )

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
                rake_value = 0,
                rake_ap = 0,
                rip_mult = 0,
                rip_value = 0,
                rip_ap = 0,
                rip_cp = 0,
                rake_time = 0,
                rip_time = 0,
                thrash_mult = 0,
                thrash_value = 0,
                thrash_ap = 0,
                thrash_time = 0,
            }
        end
        return t.cache[ k ]
    end
} ) )

local function resolve_bleed_snapshot_unit( unit )
    if unit ~= nil then
        return unit
    end
    if state.target and state.target.unit then
        return state.target.unit
    end
    return "target"
end

local function get_bleed_snapshot_record( unit )
    unit = resolve_bleed_snapshot_unit( unit )
    local container = state and state.bleed_snapshot
    if not container then return nil, unit end
    return container[ unit ], unit
end

spec:RegisterStateFunction( "current_bleed_multiplier", function()
    local mult = 1.0
    
    if buff.tigers_fury and buff.tigers_fury.up then
        mult = mult * 1.15
    end
    
    if buff.savage_roar and buff.savage_roar.up then
        mult = mult * 1.45
    end
    
    if buff.dream_of_cenarius_damage and buff.dream_of_cenarius_damage.up then
        mult = mult * 1.30
    end

    if buff.synapse_springs and buff.synapse_springs.up then
        mult = mult * 1.065
    end

    if buff.natures_vigil and buff.natures_vigil.up then
        mult = mult * 1.12
    end
    
    return mult
end )

local function resolve_attack_power()
    if state.stat and state.stat.attack_power and state.stat.attack_power > 0 then
        return state.stat.attack_power
    end

    if UnitAttackPower then
        local base, pos, neg = UnitAttackPower( "player" )
        if base then
            return ( base or 0 ) + ( pos or 0 ) - ( neg or 0 )
        end
    end

    return 0
end

-- MoP coefficients derived from wowsims/mop feral implementation.
local CLASS_SPELL_SCALING = 112.7582 / 0.10300000012
local RAKE_BASE_TICK = 0.09000000358 * CLASS_SPELL_SCALING
local RAKE_AP_COEFF = 0.30000001192
local RIP_BASE_TICK = 0.10300000012 * CLASS_SPELL_SCALING
local RIP_CP_BASE = 0.29199999571 * CLASS_SPELL_SCALING
local RIP_AP_COEFF = 0.0484
local RIP_DAMAGE_MULT = 1.2
local THRASH_BASE_TICK = 0.62699997425 * CLASS_SPELL_SCALING
local THRASH_AP_COEFF = 0.141

spec:RegisterStateFunction( "predict_bleed_value", function( kind, cp, unit )
    kind = kind or "rake"
    local ap = max( resolve_attack_power(), 0 )
    local mastery_bonus = 1 + ( ( state.stat and state.stat.mastery_value or 0 ) * 0.01 )
    local multiplier = current_bleed_multiplier()

    if kind == "rake" then
        return ( RAKE_BASE_TICK + RAKE_AP_COEFF * ap ) * mastery_bonus * multiplier
    elseif kind == "rip" then
        cp = cp or combo_points.current or 0
        local points = max( cp, 1 )
        local tick = RIP_BASE_TICK + RIP_CP_BASE * points + RIP_AP_COEFF * points * ap
        return tick * mastery_bonus * multiplier * RIP_DAMAGE_MULT
    elseif kind == "thrash" or kind == "thrash_cat" or kind == "thrash_bear" then
        return ( THRASH_BASE_TICK + THRASH_AP_COEFF * ap ) * mastery_bonus * multiplier
    end

    return 0
end )

spec:RegisterStateFunction( "store_bleed_snapshot", function( kind, cp, unit )
    kind = kind or "rake"
    local snap, resolved = get_bleed_snapshot_record( unit )
    if not snap then return end

    local value = predict_bleed_value( kind, cp, resolved )
    local mult = current_bleed_multiplier()
    local ap = resolve_attack_power()
    local now = query_time or state.now or 0
    local tf_active = buff.tigers_fury.up

    if kind == "rake" then
        snap.rake_mult = mult
        snap.rake_value = value
        snap.rake_ap = ap
        snap.rake_time = now
        snap.rake_has_tf = tf_active
    elseif kind == "rip" then
        snap.rip_mult = mult
        snap.rip_value = value
        snap.rip_ap = ap
        snap.rip_cp = cp or combo_points.current or 0
        snap.rip_time = now
        snap.rip_has_tf = tf_active
    elseif kind == "thrash" or kind == "thrash_cat" then
        snap.thrash_mult = mult
        snap.thrash_value = value
        snap.thrash_ap = ap
        snap.thrash_time = now
        snap.thrash_has_tf = tf_active
    elseif kind == "thrash_bear" then
        snap.thrash_bear_mult = mult
        snap.thrash_bear_value = value
        snap.thrash_bear_ap = ap
        snap.thrash_bear_time = now
        snap.thrash_bear_has_tf = tf_active
    end
end )

spec:RegisterStateFunction( "get_bleed_snapshot_value", function( kind, unit )
    local snap = get_bleed_snapshot_record( unit )
    if not snap then return 0 end
    kind = kind or "rake"

    if kind == "rake" then
        return snap.rake_value or 0
    elseif kind == "rip" then
        return snap.rip_value or 0
    elseif kind == "thrash" or kind == "thrash_cat" then
        return snap.thrash_value or 0
    elseif kind == "thrash_bear" then
        return snap.thrash_bear_value or 0
    end

    return 0
end )

spec:RegisterStateExpr( "rake_stronger", function()
    local predicted = predict_bleed_value and predict_bleed_value( "rake" ) or 0
    local stored = get_bleed_snapshot_value and get_bleed_snapshot_value( "rake" ) or 0

    if stored <= 0 then
        return predicted > 0
    end

    return predicted > stored * 1.001
end )

spec:RegisterStateExpr( "rip_stronger", function()
    local predicted = predict_bleed_value and predict_bleed_value( "rip" ) or 0
    local stored = get_bleed_snapshot_value and get_bleed_snapshot_value( "rip" ) or 0

    if stored <= 0 then
        return predicted > 0
    end

    return predicted > stored * 1.001
end )

spec:RegisterStateExpr( "rake_damage_increase_pct", function()
    local predicted = predict_bleed_value and predict_bleed_value( "rake" ) or 0
    local stored = get_bleed_snapshot_value and get_bleed_snapshot_value( "rake" ) or 0

    if stored <= 0 or predicted <= 0 then
        return 0
    end

    return max( 0, ( predicted / stored ) - 1 )
end )

spec:RegisterStateExpr( "rip_damage_increase_pct", function()
    local predicted = predict_bleed_value and predict_bleed_value( "rip" ) or 0
    local stored = get_bleed_snapshot_value and get_bleed_snapshot_value( "rip" ) or 0

    if stored <= 0 or predicted <= 0 then
        return 0
    end

    return max( 0, ( predicted / stored ) - 1 )
end )

-- Prevent bad bleed clipping with weaker snapshots when substantial duration remains.
-- These are simple, conservative heuristics to support APL flags used by WoWSims imports.
-- If the new snapshot isn't stronger, and the DoT has more than ~2 ticks left, we avoid clipping.
spec:RegisterStateExpr( "clip_rake_with_snapshot", function()
    -- If the new Rake would be stronger, don't block.
    if rake_stronger then return false end
    local rem = (debuff.rake and debuff.rake.remains) or 0
    local tick = (debuff.rake and debuff.rake.tick_time) or 3
    -- Block clipping when plenty of duration remains and we're not gaining a stronger snapshot.
    return rem > (2 * tick)
end )

spec:RegisterStateExpr( "clip_rip_with_snapshot", function()
    -- If the new Rip would be stronger, don't block.
    if rip_stronger then return false end
    local rem = (debuff.rip and debuff.rip.remains) or 0
    local tick = (debuff.rip and debuff.rip.tick_time) or 2
    -- Block clipping when plenty of duration remains and we're not gaining a stronger snapshot.
    return rem > (2 * tick)
end )

-- Provide SimC-style action.<spell>.tick_damage hooks without replacing the core state.action table.
do
    local function rake_tick_damage()
        return predict_bleed_value and predict_bleed_value( "rake" ) or 0
    end
    setfenv( rake_tick_damage, state )

    local function rip_tick_damage()
        return predict_bleed_value and predict_bleed_value( "rip" ) or 0
    end
    setfenv( rip_tick_damage, state )

    if spec.abilities and spec.abilities.rake then
        spec.abilities.rake.tick_damage = rake_tick_damage
    end

    if spec.abilities and spec.abilities.rip then
        spec.abilities.rip.tick_damage = rip_tick_damage
    end
end

spec:RegisterStateExpr( "bearweave_trigger_ok", function()
    -- Enter Bear if energy is low, no urgent bleed refresh, TF not imminent, and Thrash needed.
    if not buff.cat_form.up then return false end
    if active_enemies > 1 then return false end
    if energy.current > 60 then return false end
    if buff.berserk.up or buff.incarnation_king_of_the_jungle.up then return false end
    if cooldown.tigers_fury.remains < 3 and not buff.tigers_fury.up then return false end
    local urgent_bleed = ( debuff.rake.up and debuff.rake.remains < 4 ) or ( debuff.rip.up and debuff.rip.remains < 5 and combo_points.current == 5 )
    if urgent_bleed then return false end
    local need_thrash = not debuff.thrash_bear.up or debuff.thrash_bear.remains < 4
    return need_thrash and ( cooldown.thrash_bear and cooldown.thrash_bear.ready )
end )

spec:RegisterStateExpr( "should_bear_weave", function()
    if not opt_bear_weave then return false end
    if buff.bear_form.up then return true end
    if not buff.cat_form.up then return false end
    if query_time <= ( ( action.cat_form.lastCast or -math.huge ) + gcd.max ) then return false end
    if buff.berserk.up or buff.incarnation_king_of_the_jungle.up then return false end
    if energy.current > 60 then return false end
    if cooldown.tigers_fury.remains < 3 and not buff.tigers_fury.up then return false end
    if ( debuff.rake.up and debuff.rake.remains < 4 ) or ( debuff.rip.up and debuff.rip.remains < 5 and combo_points.current == 5 ) then return false end
    local thrashReady = cooldown.thrash_bear and cooldown.thrash_bear.ready
    local needThrash = not debuff.thrash_bear.up or debuff.thrash_bear.remains < 4
    return thrashReady and needThrash
end )

spec:RegisterStateExpr( "should_wrath_weave", function()
    if not opt_wrath_weave then return false end
    if buff.cat_form.up or buff.bear_form.up then return false end
    if not buff.heart_of_the_wild.up then return false end
    if buff.clearcasting.up then return false end

    local cast_time = 2 / haste
    local remaining_gcd = gcd.max

    if buff.heart_of_the_wild.remains <= ( cast_time + remaining_gcd ) then return false end

    local regen_rate = energy.regen
    local furor_cap = 100 - ( 1.5 * regen_rate )
    local starting_energy = energy.current + ( remaining_gcd * regen_rate )

    if combo_points.current < 3 and ( starting_energy + ( cast_time * regen_rate * 2 ) > furor_cap ) then
        return false
    end

    local reaction_time = 0.1
    local time_to_next_cat_special = remaining_gcd + cast_time + reaction_time + gcd.max

    if not debuff.rip.up or debuff.rip.remains <= time_to_next_cat_special then return false end
    if not debuff.rake.up or debuff.rake.remains <= time_to_next_cat_special then return false end

    if should_delay_bleed_for_tf( debuff.rip, 2, true ) or should_delay_bleed_for_tf( debuff.rake, 3, false ) then return false end

    return mana.current >= 0.06 * mana.max
end )

spec:RegisterStateExpr( "bear_thrash_pending", function()
    if buff.bear_form.down then return false end

    local lastBear = action.bear_form and action.bear_form.lastCast or -math.huge
    if lastBear <= 0 then
        return debuff.thrash_bear.down
    end

    local lastThrash = action.thrash_bear and action.thrash_bear.lastCast or -math.huge

    return lastThrash < lastBear
end )

-- Used to gate cat_form recommendation until Thrash has landed and at least 1 GCD has passed.
spec:RegisterStateExpr( "bear_thrash_done", function()
    if buff.bear_form.down then return false end
    if not debuff.thrash_bear.up then return false end
    local lastThrash = action.thrash_bear and action.thrash_bear.lastCast or -math.huge
    return ( query_time - lastThrash ) >= gcd.max * 0.8
end )

spec:RegisterStateFunction( "tf_expected_before", function( future_time )
    local ft = future_time or gcd.max
    if ft <= 0 then ft = gcd.max end
    if cooldown.tigers_fury.ready then
        if buff.berserk.up then
            return buff.berserk.remains < ft
        end
        return true
    end
    return cooldown.tigers_fury.remains < ft
end )

spec:RegisterStateFunction( "should_delay_bleed_for_tf", function( dot, tick_length, is_rip )
    if not dot or not dot.up then return false end
    if buff.tigers_fury.up or buff.berserk.up or buff.dream_of_cenarius_damage.up then return false end

    local tickTime = ( dot.tick_time and dot.tick_time > 0 ) and dot.tick_time or tick_length
    local fight_remains = target.time_to_die or 300
    local future_ticks = math.min( is_rip and 12 or 3, math.floor( fight_remains / tickTime ) )
    if future_ticks <= 0 then return false end

    local delay_breakpoint = tickTime + ( 0.15 * future_ticks * tickTime )
    if not tf_expected_before( delay_breakpoint ) then return false end

    if is_rip and buff.dream_of_cenarius_damage.up and buff.dream_of_cenarius_damage.remains <= delay_breakpoint then
        return false
    end

    local reaction_time = 0.1 + ( buff.clearcasting.up and 1.0 or 0.0 )
    local tf_threshold = 40 - ( reaction_time * energy.regen )
    local energy_after_delay = energy.current + ( delay_breakpoint * energy.regen ) - tf_threshold
    local casts_to_dump = math.ceil( energy_after_delay / 40 )

    return casts_to_dump < delay_breakpoint
end )

spec:RegisterStateExpr( "delay_rip_for_tf", function()
    return should_delay_bleed_for_tf( debuff.rip, 2, true )
end )

spec:RegisterStateExpr( "delay_rake_for_tf", function()
    return should_delay_bleed_for_tf( debuff.rake, 3, false )
end )

spec:RegisterStateExpr( "berserk_clip_for_hotw", function()
    if not buff.berserk.up then return false end
    if buff.heart_of_the_wild.up then return false end
    if cooldown.heart_of_the_wild.remains > 8 then return false end
    return buff.berserk.remains <= 4
end )

-- Expose SimC-style toggles directly in state for APL expressions
spec:RegisterStateExpr( "maintain_ff", function()
    return settingEnabled( "maintain_ff", true )
end )
spec:RegisterStateExpr( "faerie_fire_auto", function()
    local value = getSetting( "faerie_fire_auto", nil )
    if value ~= nil then
        return value
    end
    return settingEnabled( "maintain_ff", true )
end )
spec:RegisterStateExpr( "auto_pulverize", function()
    local value = getSetting( "auto_pulverize", nil )
    if value ~= nil then
        return value
    end
    return settingEnabled( "bear_weaving_enabled", false )
end )
spec:RegisterStateExpr( "should_spend_rage", function()
    local threshold = getSetting( "rage_dump_threshold", 80 ) or 80
    return rage.current >= threshold
end )
spec:RegisterStateExpr( "can_spend_rage_on_maul", function()
    local floor_threshold = getSetting( "maul_rage_floor", 30 ) or 30
    local rage_after = rage.current - 30
    return rage_after >= floor_threshold and rage.current >= 30
end )
spec:RegisterStateExpr( "eclipse_power", function()
    local eclipse = state.balance_eclipse
    return eclipse and eclipse.power or 0
end )
spec:RegisterStateExpr( "eclipse_direction", function()
    local eclipse = state.balance_eclipse
    return eclipse and eclipse.direction or "solar"
end )
spec:RegisterStateExpr( "lunar", function() return "lunar" end )
spec:RegisterStateExpr( "solar", function() return "solar" end )
-- Map APL variables to consolidated settings.
spec:RegisterStateExpr( "opt_bear_weave", function() return settingEnabled( "bear_weaving_enabled", false ) end )
spec:RegisterStateExpr( "opt_wrath_weave", function() return settingEnabled( "wrath_weaving_enabled", false ) end )
spec:RegisterStateExpr( "opt_snek_weave", function() return settingEnabled( "opt_snek_weave", true ) end )
spec:RegisterStateExpr( "opt_use_ns", function() return settingEnabled( "opt_use_ns", false ) end )
spec:RegisterStateExpr( "opt_melee_weave", function()
    local bear = settingEnabled( "bear_weaving_enabled", false )
    local wrath = settingEnabled( "wrath_weaving_enabled", false )
    return not bear and not wrath
end )
spec:RegisterStateExpr( "use_trees", function() return settingEnabled( "use_trees", true ) end )
spec:RegisterStateExpr( "use_hotw", function() return settingEnabled( "use_hotw", false ) end )
spec:RegisterStateExpr( "disable_shred_when_solo", function()
    return settingEnabled( "disable_shred_when_solo", false )
end )
-- Provide in_group for APL compatibility in emulated environment
spec:RegisterStateExpr( "in_group", function()
    -- Avoid calling globals in the sandbox; treat as solo in emulation
    return false
end )

spec:RegisterStateExpr( "combo_points_for_rip", function()
    return combo_points.current >= ( target.health.pct <= 25 and 1 or 5 )
end )

spec:RegisterStateExpr( "should_bite_emergency", function()
    if target.health.pct > 25 then return false end
    if not debuff.rip.up then return false end
    if debuff.rip.remains >= debuff.rip.tick_time then return false end
    return combo_points.current >= 1
end )

spec:RegisterStateExpr( "bear_weave_energy_cap", function()
    local regen = energy.regen or 10
    return 100 - ( 1.5 * regen )
end )

spec:RegisterStateExpr( "bear_weave_ready", function()
    if not opt_bear_weave then return false end
    if buff.clearcasting.up or buff.berserk.up then return false end
    local furor_cap = bear_weave_energy_cap
    if energy.current - floating_energy > furor_cap then return false end
    if delay_rip_for_tf or delay_rake_for_tf then return false end
    if not tf_expected_before( gcd.max ) then return false end
    return true
end )

spec:RegisterStateExpr( "should_bite", function()
    if not ferociousbite_enabled then return false end
    if combo_points.current < 5 then return false end
    if not debuff.rip.up or buff.savage_roar.down then return false end

    -- Execute phase: always okay to bite if Rip and Roar are maintained.
    if target.health.pct <= 25 then
        return true
    end

    -- Non-execute: respect user-configurable minimum remaining times.
    local rip_ok = (debuff.rip.remains or 0) >= (min_bite_rip_remains or 11)
    local roar_ok = (buff.savage_roar.remains or 0) >= (min_bite_sr_remains or 11)
    return rip_ok and roar_ok
end )

spec:RegisterPack( "野性Simc", 20251106, [[Hekili:TZX2UnoU1VLGc4AJzGRDCCMUaXdWEf7oaDMI6PVAzfj6y1ilzijN0uyi036B93O)zfO)f9qsrXBhsj5jdAFyXUZoju8CHhEUtYDZ8nFEZ64WkYMpE9SRxoF(SVz68BUzXnZ3SU6LJKnRpgg9y4dWpKfEa(V)N)X)8F)3)xRtoer)0lP5HXuuuMFQic(8M13FkjT6xY2CVbEVDZ6Wtv7Zl2SE9Ht7ksECZ69jXXe(ujLac)8(KY6T0)ewVTHW1BZ3b)EuvsEw920KYk4Z7YlQ3(ZKhtstMc8rr(UKuG68zv(Mv)UNclscVpL8wkxV6qyswf8NGD7E7tHPN0gP(dUal)yvW9KWIGNjHprAGuFq)a)Cry1ElOvg1p4LzKhTGwoOFGpvscYkvaKpGFGoqsjelsQmQBWPOVQGqeKS939dY(8QNvGG(RUbioPK(lbL7liXbpVNKfuMNM3aVJV6gD0VgakppN2Gb5a1FOfSPhlir5hUpScqWHWIhdY3fuTheijPXVnz3QRU)0UDtn)Y0thR)WVPE7FSipQE7puqcpWvL)EsgWfNaT47jGEmOGZXE92XFE(T)8eCcVNeMMK9qqv(PO9sQgtXlLSrnyfi7OQWuswfY3G)gw8X4uikSka4NdsKlgHItWuHpZvZWbVm8jWAnOipSqIbLbzYdma5BaaiJf7otL7dNpRq4jJ4yL9fN4JQgLuro82Y08Qv7dZIl7ZeRksYEKunFaZ9AhlOC6yCvSNskoqYkdUhaoG)bvvRO88048Nz6ME5B3t0MV7CUxJp37tZZJd2DQ4f6UbtsxL8aPOKnMM8wdmygKIhbLZbbwhsPwC1GEapNpxfw8aPcq)bW3sEqCc5UvxFlo(tYIclYcf4QXMqzuH1WOEZYnSIJL55ZnFpikn5i1WPXBg4e4pxcM5)uoeIK7d4JHvNOw(0qAckuV95KQ91B)mfR)wW9Wpb4fMceP774iMhguXjSg3TJIEQ5Egd5uUS1GQ1zSW3GXKBLfJXxy6BetWzaWfvrLPZrnwGkpeCG1Sn4bb5Oy3HODIQPelIovmesksib7smebkr8hftyKqzQmYmY0RNn2lF8uAAW9HL75kvm9XOWYkq9hbCjcOHTb45I7YGYNt2vLrklv0nD6VEu7IqghFKqYp1cLtliu2TC1Sg)L2ZaCOJ4FEex9kGKroKqkbBlRLKdfKwMr9dnSXDRwmXsoyfoRtzWynHGmlOZNrKotqxEJh3e(GazMMx8IUaH6)gI6KdB0GE9PIcGFUB5KZNh7wiEzsJjt8OP1iGkso26NXsOeehEawyU46vl7ZU7c7nxGObfKDWYCFa1j7DQb7fmw4JKlMZU7I5mGQDYAv7ladZaaUEXG6u99RUbrBpohc30I2gNrgd2UZEZ0L2A6G(YrYRipP6uHwhclUeuoIi1nnRbzHkJgxUp)uASYquVQHfSFecoK8aORgK)4ePNLM1iDwWImm(flkRmdLa2nCdD9CfyS9KkIEBjqQOQvZTWLA(N2iASjI02gySyvsenlKjJgBRhV48zevOfnH2uvhB3nxozeSnu8WlcL33VAXslU(q4PuCoUGULkbDwZozkmNMag8GomreOoSl4HO4Pu8zzpGq1ShGkDCl37edPHreOouYfc(R4MLTyH6d9QERVc7SwB3xJUDFTVT7B0YMGvJoSoz)TLzLsf8JAytSI6NwstzqjiaRkNQDu2bwNqGcqks(RrqWKaUQ27NVSj2GA6p(Iw0ZsVq9g)(zDH5MOqQaZY(cgN7Be(HgNIiXoSdZn6QysA4lu4z4PANjbBIUWro8lcSJ4)3d6PZgf)6HigM79fEdBBJDmf7bgrzOK0m8bwcCdKbmO3osrEus(jEXAuAkStP1UroaAXKSOx6IT9IMUaM1Gh2(NMPsBLkDjZ55OHypa(8ruQgFpzFswCapB)gAOuiza1rMOsM)YjQNzjVOwWz7GLvq6VWSJvgAFiStCGKYhRPcLdjpSV6fw9gAdhMCq93Pe5yyusviDjlS5B)8XtPpbv683OS1KrxjZK2rhZmC)VA(ORG6MEOixR0VYkzGOg1pFP8H4qZkuyV33Bcmht2LaR67wnFgnIHWHuR2RFh(CTEMtg1KZ)vfGHOa81PC7sEF0YtbF(8JwqXfbBCUgaE5pyH1K4omNyW3rVaQIn7UWI9vCDWPLrga6zvc6ClFtl5GKdUpp7u5GscGtfJSamdfSOjtlvBbUVF7XfMdlCK2G3cyBwZAXLCeEbkyYeowcaiBigzKU62rwgVyydYFPhi7MrOz4y6p5DtV2xcmnBdI6906ZliOGehtoeM(gZtHqSL3CgeZKnm8pX2sQ3sTlR326ZO5GcQ3MFKQknXfzkyG3MjIQphxGefMMgW)ua9O2uo(mjBz0GsWjEk8xjzcgQEBygWKXNkaFr1BlYRyE)CrZVQ5h3NLxBpmhgy067Pm8RCNRggt8LvFsFOGOgZb1xb(oKSIWbUQaljuxyddlLAMGhYZYJyNptpoK3z9do7Z3TNaADYUZuz1kswCE2BKvzJ8PEuZhcuk2AiFTXMc5lDEKwwqq9mJnSDbLkzFJaGDHcoHTfA3w6sTgv593(PF0AxY(kdmZpaO6rZ7gglvblyg0A5p8Pp(PV)B)SBF5CTsma6Z1byE)PKdg8Z)4h)Hp9XEiVN3jmDjY9aMxlxhWzeOE(seiWffCT5EpDfj3M1qI7LWNvVhnpdfuaXhl3S(xoCmVOIMsaWn6xsMP1FyZA2prVFoCkc)0hz34NMqtB(UnRZpUzDjPsC5zac2SOP)eSo3SEoBSakRTzTY(0MkGP(YWM(oifHlgmcNzIqL9wkgVzWyC(svuk22P4APbUeOWCFKl5fiGT7tb)2lbCvTHk4F4BbyBLrfGlsyTixsQLVuVDeKugEjmSVzMfLK)uMo2MUKUnOx27LoqS84u5lnQUqpxz6Qom6mgss2mzK6TNptVPn2noUE7eguUpUdjF2Mld2YNFIguMwHpTsbIrRRQ3A2ACjruheXsOlCp2g38fVJwVlw)aCM9UTE7DRQ3UGdUvRx1(QRAh5tAPGi618wV99umSu1cOQv(AAW21cx9GwAW8mf9oZUmPUrODSlSpqzizoNWQaWMKnPtdZpqxSyxyT90CW8s8LHCXb9qX87giM)cuPSL9uCsH9QlYqLPjIQMETx10R7JA6najq1fbxsqoyxwyZz))DytlektefZi8YcvPoWxUqunsSPeuGbEtp4xOyqFHp4q6MILvHAFtWe19sYWJz7rUQuzggZFH9CrDXagDTTwHBuy1EfW7jptYjs)NQnAbpA(LMxuBFxgwQrYvuxDEr4l6j8(VWfcpz3dgM3afgLccM7Z(WJp5OVmmEZU3mA0LnoLW)(Vuc3)eLSJdOllebP(MlGLmduXcvRH9WCMZN5Z6n2v3MQ4oDyBxEtISxkoOkgQ5l68I3vVfwyZe5zWePy3EmP1KrFBqdQZJLHy)PfX14ASYnZ9CD0AZLtj(NfV6pN)EjmVmRqVsOXYvn(n6Rz3YUBrSuKw2MwX4U2J(YfUI)1BXqA3jYEubGN7rMNLopR8HO5XwcUu8WZjBMsa5KJ9iP(lBTC3R8Abpfs1fdmJEK)FxRgmhH3414g5sByLjEK8K1AsRD6sndB586rzgVERbLY9fNnwt2HTjaG4TU1QG(qiaqtZRe)IN0)eVgcbaT)UNe3eVkcdyUUhQT6Eeu6xq7tPOhAlorcr8Wk8LGeVd8i1YjUumC9e7NortmLBfVSpK(67VMr3pPcPAGR1Mcqyj44vcjQue5fbyj88LQYo93abwA3VApzd0mZKproQ8Y)lZOZarw76tqZKYbBWEPkkCHZxNHgFOxBGZDfnNqwyM7lO5CjEfQs0U44HxTDx9uE4LBBHrTYTRA7sSy9lZ4TPzekKZB6yxHgnuXhSC82vsRNq1Iq1O3nQttyBPpftVCU9Qy67s4DtlkRoYD7fcpZaA0OLwjH42ntVWI(zrY32Ij7cpLEH6TQDf61SzrgMaVYDoY0EWVPYWp(fdRdVTPYuPRFyNxGHjMBgfjwB)WQYPLAIA1pHOn3n(BdvOIz5Gi629dN8GM6OKngsCZUXOJRtOkbCnfSyvDtq5dfwLgkJsrRRmlhwRmBFHVyM62UFrEo4skB(rmRCL4LkvfQNJYGFB5yCk2tixnvaNf2J59Wg9MfZ0(EU5DjbjsN30Uhy4n3PER2rcL39pllgdEuu6(vTTBG)(ZvcKju2CLLoEvmUAOOVQyC1lqFvXyAjpKqZuZVCIFL(wb5R)XnVw76BszcVz)yEoJSgWavb)gLDBXXii5IU7XnAksE1)Pay1StTSNnVjU6DJc)WQe4Wr(kcL1UA1KHvIBZnNTxG1DbfXIwRfCB1zkvO7p3YvvmUoV20GNwiM(G7wzGrVBSKGIB8RKrK36xgF8UPxl8ayE)F1tYeL9ENAYTYEGOLHBLOD)9ZqRVNMGGQIJsOI1MCV04R25e5YgAO1Y0PbWqu9DBa7ubzSuhrA26OpOUmf7N2KxtZXk2mk8HJEy2tgr(W5mS76kw6f1GYfD7PAq9S06(gm6YBE6G5n3LOIfkW)z5CXCSlMZDLVOpFVUcqBwiSvggO4FWy1t3RmBbLwBW6NEG8iCCw7VNGPTHYvFByk8qNVpm85Q)bT3SHYWQVvSgfdS3lM(N4VzmTXWF3yAtr9TJPKiSA6ZU(F8w0PAQ7ds15cCiEtzA6TmKGw3wxDRr)0GCepc92G5wNu((gzSK7qvJBVJBnpkrUn58zCH5vAHn0mB77nusy(BKKK6jm(RQP)pqn1DgeFfllIsy3Pgy)qj9KZ0QUZzs7LyYZIS52)JLkPak)xiQM(9JK)x3T9X6URz0FTl6kAfz0XhAQYhjr0Oqly)6M)l]] )

spec:RegisterPack( "野性(黑科研)", 20251110, [[Hekili:TZZ(ZTXX593IKhdsArDehabiygECMyNKoHDQRhZ0FPDcoSeybWvE4om3Dq0SdhmYjv2Yos(r8Ju7QPXU1o2X1puDN6Oizf)htiaP(P8Vq)(29Ud3JDV7aiLTCNoAej4D7(9A)EV7IMQn)zn3TdXJ28PRuUsnvv1YkLlxTr5nBUR3HdPn3DiP9(KEWhSidGF(Gx8vME1pA5hCVx)Kp61p59EZvWrCOPnPdcjx7roTHr1C39gzy69tTAUxCWxEdyqdPTB(0QLR2C3(gD6q5dI62U5UN(nVZX35tM(Yx90F59p(R)xMCTRFYD)OhCTBEY9)8j)27E8DFLFmX9WNXXE6)1ln5gV9jV01NC9V647FR)8v)fn310W1ZfjIUgMMuh4tpTAWp8AUl1ISNjTtZNS5UK2Eg2waH7yFGzZDB7y4rDmin39c7nQBxL2ep9U2odugnCCRsJBDbdl922d2J4bW5PRGOqaWCixHjMMbngWy4aGeo1QrN6ErhQhXPh1tXZyav3ZwVJbDCRlpUvhBpfhY(ufh6aIHL74wBpUvvgrXrl)TEgT3xVdzaG)XTEIXTwoYmX35QZN)4wxACl1XTwjoW5tFqp2CLmXTdX4aIvptQoiKu6B45J2OIH9P8vthJH8h9SWJg3YOl8FVXTGjb8rFIthQZ4wE9ja0)ByWeqHvNXToa(Wb2wlbJLmCO5HWVWhcabgpi6OWy8SXPcd0xWHs31tSWmt6cYd(cRjL40M46zy1JT4E0r(VzpQJl1z)WhsTOo9oee79OiZRbITAm5wj)jyy1M4yrqguFFaC62D1bcs)FCeYjkDSpWAMmXTVdqsajwtkjo)aD26qt8FGiVlzKPxs1(qAy)rMM67rC7hLc81NfyJmhgfH4iymb66jb7EP44uqf0rsdxUDQGLyUljGPmAhrdCKLo)Z6OlHekJ)4NJ2EKhQdrVc1buUqBoFLjyw2GoMbOFcgZgMiEug36jHr5lD9hORXGrMS1jqZe82mU1i3aG8Ki1eyTmUfscRY1(p0EeQzpYSd(y0MavJbZApkPtuq8d7CfIvBKgJcf02eqn8)(uhQc3HNoxeq8NbxvyOd1xe6VgizH1xxEaXz)avnGB6GERIOMf)LICbMgKDCOKb40AddZXyKBWcShXKA5j49bGleX9Pet0gWZEu7(HEptPQfxzoPcsO2pZ5SUJnXjMJbgXg5LmBmUlaFoj6ld9cVf4fM7mO9ihhGHyQS26dTnS84EPlZxki2urlc8vTatw5QUZiv8XxHQdoMgyq5KqnzQazSa1HY4kM7ulAhDIZaBhfxpiipNTMrmDjWuO6DnCWOAhcop15EBDr(jz4SN8Bn5QWf1m9)ZqONrpWjVE3rohgtbhca1XfaMPTxWFKVNAzaBptB7oShJaP(cceEWiq5hbYglgqWaDwyYem5icOgsbepAhi(H4CvRf4iMbE7bulMDQjyM6HrebemdlrWoIInxmA1NHriOwobiaJCDl6ZHVksabBBti1KGSnpGya0uzfMwPQChEyUnE9DGyGS0xIP2XvodYuioLYKizm5nHudIitcheJCKBlMPDWMzzgOXm(LyhOk3USqGdcvYaJC7jb(IAekJINV6wb5RkkdxEEvjZDuKRg1CShflftiMoWyinCzzUSnfMPOmil3GTnO2IocJb9yIkzWuUTBrSsJdl5gP(z9gSgnG8CCHOQyq5fK6L0aCy0Vfj4MVgz0OBaKYoWgQ6zmKv2c45CM6i8SyAeXuhXKm86RmSTh)LvIOV0L6y32WEKR(EassKg5FnLcAfpRb8JUo2dGFsmnz41UlKQxNroS)GYZ2CClhiBDQs2rnfhBwI(r0OZzg8lVmUMvtdK2iuQUTZH6WQCxplQByABssQJhvV0m)MIarugqvPg3wsUNO1J5mnEwGXxdEgy9zCRFesvOyFCRNYNUG8MH1Z1HIDFQNbEdKs)b9X64EMD9tUFp7rE8SVPp3qdh(cZc5IjUnBChXYDXCUfWDbtoisa3C8SmFznTOX)JL1uQuakkuIL2ugPbmN5nLre8mINMTxMyTWX3RvyhCwBMNRzTMHfRurnrC64ge)TqfThGeNVNjXEHcAfZs(2jMucwCPAThhQU0ZXggsyJzyLJ6ZLklEYffqyKW)Tu3WzNzsE0q6icabKo1NCCfi0gnVKeRkndXK(jYjDi5nxBP4(2Wqs(XJy(aXLsCrDwx1MTCJGrjv8ubPYHoVduCt17XTf0vrH5evGS6ZoTNStLV0SEGgDXg1dAmlEMqp6m7Skz0AWmvXKxgGCxJ5PZEbgZin3S4fUeLAlfmlo0QW7G5kzBULO0Q4bCH3XvTSOeNl3DeQFfGI9OWIktfJ1F1XT(jbgUJB9KaVYCFurUV98edf1brCsobrWTuqlb0MTpM9Jaw5adV(mRi3HuRo8S6g54NnHf2dUbuV(CxRMU(CwY4nXiJNYgGd(rGogzX689b9nA3NtlU95nfm0pnHJREibHPtPuOSOZk)HiPs7V9iinlDVmKJKLLzbSvw(yRQuMP55RQkgcWsD5CSor31mRmX8tYGtfGFevxkAx1qPMmSiRjJ5T0uOAkfJYKbKkakZPytnwejXytAaj5ytQ7jLYIXcMtBqhlFOu)yvP1pkiTZiO2lrNMJKwz8rTE0rLiTX4JmN0jc3IWir(z7LyM1q89McELxJYc2m6KvTKyNu))l3TqL7MtTAjBEFtzv5Mr5AckZLb7y7dBCGNO(25RkUW4lcDQdlh8K)Y2ZiKdB9yRjr7oDonZD(QwoJAPslMYVl0z3N16sZmnRwhjo2OAo9MUAMvVTq9zj0pM8ngsQBU4E5sQ(k3dBEzKYH4Cw)U8fjGdJS5w5xD)zPk(m6r95zv8PQFXhsLN7IwMNcuqWhaJUO7qrvIKrTL5jceXKZF41ZwrHsnZL3MJyrUswvBQzGNuiLn5Cr2omxPzY(NKrvENdM4YbXLyC52P4gPg)PkAROeA9C8awRqukcPuc(Sk1nj5Vq7TOgVbhfG(ZONdzxLMi(6sjvoZK7IBxVl7nGFp4vbLWVe2SHOP24BX3Mm0)GKHN2m(PZzFwYRSA4JKbllziMbmXXEeod(H7HWoqqSJfebi8Oixj7YmNVg2LBd54jZLxV9y8ABtJHdz8cJhmzbdqjC4zP7a4riFzdZEWiS1d84vk5fXp7ZH4YZz7ad98NXEflfGRjeGOcBzLncIuiQe9c0VrrrsIffHjNrs1JGNiYFgllkfHLNNTanUF6hf7Iz22PXZFmv3ckEqS)pvNnx8uQEuVZMjZu67OoBMOCiznVkzovfa8pk3tZQjZLQa8Z83tZQjteQay5m2tZQlqZNx8EAwDbAn8c0tty(qvAUiKJCHhoG4ybkTqEON(z)UjV(l)x(63DYx81tU2hUeFQln56)MtF)p(b36QN(7E(JVZvp(U)RN(IFYKx(Jp(B(8PV5F8pF1FX4Do(EF4X35xn9TU(0)TBn5p8LtU1hZVLe8PE8D(SJV)3CYB(X)LV(ghF)xy6V59M(F)w4yE1F9X37RM(w3E6n)8j39nGHn9L(ttU(Tbky8oSq7j2Va4P7KKi9pMQfHkp5t)u1tF)BaZ947CZPV5xm9gp)jV7)8034MhF)Bn9gV4X37dwY9aYWOs8LytmnwdpeZfeVBKhE9y1MTuW43mNXFfdhq0WD9cMZi9kJuj20csKlMW57W1E2b86HkZbtSXIUuGiTgFYNE)pD6n)3)bq4fBlWeKDc)ThIbz4XMWu2wsKp6T1Qvkv17BPvPwjX935Xt2BNT1W(6Sep9HZfuSMeuO8DQQqW218WwBqTYzrDyZZb1H5AHVu6OTBxTCEQdZ1cVeuOW44k1NdoonGUCY6W2UAPLLua22Pk(6OJwo583QAjjt)Xtn9T1W62wzLaP13PK3AYjVVDn8M(zFa)kpo9Tb99V6KV(UtU9Rp5l(Jp4QVlGHh8H3EYBWSjyghGI)K7D3t)8pF6x8QhFNpz2LM8xEFUf6KBCTP)QpDgc)h4e6jV0VhaZphOxyatET)ZJV39o((V10V89NERxI)eG8dHgq4ag5OgMY0R)2NE1Rfaq(Jv)5t(13W)Zvq4E638otFV)WKN)DNC7xy6R8XNEZxd4Hj39n5d50)JRn5dEXPV3Rgf0mR4Px)1M8Y)wUtNJV7lup8cHYf1SXa5VncQKXP5UN87V7PVZ7EYx(No55)Fy3umiLkSujNrgD0U4pc)LouQeXu)zCOplXOZfhVJTJrpdlTloYAFliBs4jM0Rqn12S84DCiTPAEo2qvt7a)KQr8y7h5odTDz15OTh)pbmrDXm9C1iMqbxdouRE5YRrTaqtPyFLW)E8o8nK0vRVN3WFWARnYvbYPXZKQyr9w7a7dGzSMhKx7A8bE52a0WlxMTZJ9393FbLYW)uhVtpZdh23vJxaHZHRfC)NgVdEBA16ICiQ78yyJjWn9l8cRX12h3AOJHntdZ)YKX2zWrE2daheaoXgq1gkDK53aI6ZCFyXU0AqjDT7tabdKxScdf)0G5J79GhDWq)UsbcLRy0HgCv3GIn5JXNe4i2RpXF67zJdW1yWWWl)5qena9aPPVkdvqXKMSIADbUHvyk6ida6akbtQgQV1FQ9ST7e9Q5PWPZbeGZSS9cGbha8773EU2MqzPiV33OxFksEW6SRXEio7m0LZU)ek1eBAiL63QrOI3vHP3HGmoVxJdqENYB6iogUCJTHXG6qhFiTBi19uoKUbsrZdihc)202MVFcS2nnAiEVPDJd)buwvLHx)1uRYOigXfdBZURJHTWGLrn(3GwkmUw)W2TPdrqAzBDzyrEaxE22pOHTL5HmO5)eLWSY16AsC3Fv8oIR5oev313ZeeD2dCfm6lPTwxy5XF4uI(aS8jhJ2uDl45Mujtk5TpCvJUAxGmYHO465Ot6zOdbuXcpfo7y7MoBQs2y)rdlL75gqigMzgk6Trk3xYa41KWvnSidD7Z0tbVu8QOXLoxpcU(iEfm0QHEziriF7d0632IQibN(4rNdyHJrqgwPuPk61NLpV57o0Er2LO9IJpt3I2lgCnAVyspqXUhTHsaTKzKUkwEVgRcOOMaShizWqLGOEg(8zNhjiFVeZgeXORx9GyljF5SlRn2LvMaCXo)nPbD8EkIeBI2pwkrVU2sRQ4Ixea7zhshgGLF8E2QkJPohpslPPMuw)5zIxkJJfuPmosqLwoVdd0wQk1o6iX1cS(kcw)N54ajCz9oeLIjNQatxeelNEjSA5sj6u3khDu6mW3sB9YPrtKgWHGN3QmqvPwjUpwXhr(uGXh3HmzI2jMA8G1ToWydwfpknAStstHN7SJ7xXNs4z)RWtj(bbu60aL)hY3wJ0KgyuJ0Z5rhkKulCrC3mFOpHZP5MPs6mRIav5WTZkC1sO2BjX7wNVRSZZ7HHaUeE8QX2yzn1qF3XQU9OJcwXYT640Oj2wKTAWMMQPMNqtMKP0YjK)BR1OKmVzGkuLJokHljzEnRTcpaYzAF7YtaKHE1fwo9UdSLM6rhTCcgOeFCBdkZRSsA15hlfv9WzJ8olwMIi6Z62(jqfp(gXWZNIV)izBxo3GAzrm6wP9vuvPmeru4O1klvnERkccONdfjkQBdfbUtlIqkEOMuwuZnqZAt3Gi(Zn8eA4OuoAk2bTAEHZYoaaYs0oY7tMRTGHmlZbXVomlbXeqSmceoe(59FwQE8YcPDcsv4SM8Feu9Wi))OG)rIsaIqqFpSkGOkN5uia7gjiAIpKldicMoJvcK2osQJSLfqvQnkLL)PTRlwUUi1reLNpRPmkAhD0QxqdwrloQLeRxvDHuRIy6leSLf4raDiiOQMZC1lrDtMDU(8zuWsveVNArsQm3trUqsSWjqwOYDctZeMr5CYTSGkpfmjV5WLFXkRmUME66YkLK5o6OeJ5sQkBUvMzJSy(qZxzx2uUuLTtqJNncOUeJ4AzqbBPLGeeMU(JohG6ZMesTIurKW0kLNLEsX2LQluW9i3P1ws(JIBpW3P7NU8T7pIx2cCcRlGFwrDQqA4A5oK(2Ufgc14oVAPXIeu67VD148iM35CJnIAFwGY2lEEYp60EJItu52HJIdQ5RjhfhUfUphfhKfOvh8bRX7aqQoj)q6Rl7KOpiesHdziXL)tSCmF(bF9HFj1vUCQGbpHWHUTpKf(TmUaYM9vRntRxUrKapY(lmSVFVbN2GRy2qkWxa3cOHz0AO6zHauenkBQKwD5VN5iGX3nRDxBvl20VKSgDXEv0UYiAxeYUlnXHvE5QH8wqadH7zPKSSxjjIwOA0zZCo2Pp)ju895ZxwxSD5l(KoRDkjkPwqugpYp(9KlKcMQ48L40yH2xNG134ixwouBMAPnpDOWzklB)Kam7AqtnAjPlNWcRrjbj7kk7r1uyi8Rj1SlNPaZR4b6sdGmJOL2WofUlKczSPjmGh6PRpL0rJ0Zae5oui1vIj3lZQgD02yJAvxF1E0bU(JyOJXaya1lxEawgKZH4hHIn1vBuggX4DSOT3xZTTTdMjPUl4R1K6PVp9qeCnuRvF9vDWmL7r1WOh(qz8o803arHg2d3oqYN69mjDmWm3C174q6zB13Odv3DiHpqgaxVAdvo9XWVUA9ieg8GvPwTb)tEAvkZFF5Y4TiAgnGdEgvGhGuHeau5nfL34xiqu3aCVE9q4d8F)OWf4nqSmEN24rxuRNd9q3(eyfxN9GEJGSgyaPwJkvLWaPEGALySe8EtZqmISfhLh4GN0qHSbSWEGdzOlYkK2GnjPnFHz91RRgLxq8edYHIiM3(Omupt7RqDdygFTfvM0hwdys7qaVraVSkPthBln3dXJ8gUOInRWvNDOcnsGAqwcmfbykH8e7n7bufZEWze10lGNQvpHOfxwcjTu8it6zs7LRoimg2kyGEWgBgJRvtO61Og)P1Ys1RlLc8h4GgZjX1ZXyFWofjdosuR3OrHu0vxxcJ11aBiIQqEZXprO46evRvjTcnhmv0gcLhcw4GIGfbejdnS40P6MQcqoWpw7t9u1COMgTru9CJOSzSXMvR0iCav0(NahB8tTnEouD9STOSHvRYgRpEh0bPoQcQbokbWVhqcmxO4zMSBxFaUE1qXrhOEaUeLsfzSWYR)VII9EB3rda9VdzpPh8eCvGA1ZRpiYN9q0pi4XvtvTH66rhlza47utTA9Q1N9yimhfKtT9IbdxS5CXFeqmuhpdWwaVwiw90QS(MrEnk(9FHA1gBo7fmojykBOwnYuy6x(VQw5iVjqXX)D1RulcJW89JAYnuN9qipfGRbzAiavRVEeYB4vgcX0pG6m75dOEeDqHnwGd2BWbxzyB9buOeinowK5vjt3eSzMLIdNqYrLbYTEiId8p0RQuTS7qOYm9n3yZYWkQU661BSbeTuSgf7IL28)n]] )
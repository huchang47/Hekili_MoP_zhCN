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
        id = 770, -- Faerie Fire (unified in MoP)
        duration = 300, 
        max_stack = 1,
        name = "Faerie Fire",
    },

    mangle = {
        id = 33876, -- Mangle (Cat) debuff
        duration = 60,
        max_stack = 1,
        name = "Mangle",
    },

    jungle_stalker = {
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
    stealthed = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local prowl_buff = buff.prowl
            local incarnation_buff = buff.incarnation or buff.incarnation_king_of_the_jungle
            local stealth_up = ( prowl_buff and prowl_buff.up ) or ( incarnation_buff and incarnation_buff.up )

            t.up = stealth_up or false
            t.down = not stealth_up
            t.count = stealth_up and 1 or 0
            t.caster = "player"

            if prowl_buff and prowl_buff.up then
                t.remains = prowl_buff.remains or 0
                t.expires = prowl_buff.expires or 0
                t.applied = prowl_buff.applied or 0
            elseif incarnation_buff and incarnation_buff.up then
                t.remains = incarnation_buff.remains or 0
                t.expires = incarnation_buff.expires or 0
                t.applied = incarnation_buff.applied or 0
            else
                t.remains = 0
                t.expires = 0
                t.applied = 0
            end

            t.all = stealth_up or false
            t.prowl = prowl_buff and prowl_buff.up or false
            t.incarnation = incarnation_buff and incarnation_buff.up or false
            t.value = t.count
        end,
    },
    rake = {
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
    rip = {
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
        copy = {77758},
    },

    thrash_cat = {
        id = 106830,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
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

-- MoP: Bleeding only considers Rake, Rip, and Thrash (no Thrash Bear for Feral).
spec:RegisterStateExpr( "bleeding", function ()
    return debuff.rake.up or debuff.rip.up or debuff.thrash.up
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
    -- Debug ability that should always be available for testing
    savage_roar = {
        -- Use dynamic ID so keybinds match action bar (glyphed vs base)
        id = function()
            if IsSpellKnown and IsSpellKnown(127568, false) then return 127568 end
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
        known = function()
            return isSpellKnown( { 33876, 33917 } )
        end,
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
    -- Alias for SimC import token
    faerie_fire = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
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
    shred = {
        id = 5221,
        copy = { 114236 }, -- Glyph of Shred enhanced version
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 40,
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
    thrash_cat = {
        id = 106830,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            applyDebuff( "target", "thrash" )
            applyDebuff( "target", "weakened_blows" )
            gain( 1, "combo_points" )
            store_bleed_snapshot( "thrash" )
        end,
    },
    thrash_bear = {
        id = 77758,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = 25,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function ()
            applyDebuff( "target", "thrash" )
            applyDebuff( "target", "weakened_blows" )
            gain( 1, "combo_points" )
            store_bleed_snapshot( "thrash" )
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
        duration = 3600,
        max_stack = 1,
    },
} )

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
spec:RegisterSetting( "use_trees", true, {
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

spec:RegisterSetting( "pool", 1, {
    name = "Energy Pooling",
    desc = "Controls how aggressively the rotation pools energy for optimal timing.\n0 = No pooling (cast immediately)\n1 = Light pooling (pool for major abilities)\n2 = Heavy pooling (optimal rotation timing)",
    type = "select",
    values = { [0] = "No Pooling", [1] = "Light Pooling", [2] = "Heavy Pooling" },
    width = "full",
} )

-- Use Healing Touch (WoWSims parity)
spec:RegisterSetting( "use_healing_touch", true, {
    name = "Use Healing Touch (DoC)",
    desc = "Enable Healing Touch usage for Dream of Cenarius snapshotting logic.",
    type = "toggle",
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

-- Enable/disable Ferocious Bite in rotation (mapped to user's setting key)
spec:RegisterSetting( "ferociousbite_enabled", true, {
    name = "Enable Ferocious Bite",
    desc = "If checked, Ferocious Bite can be recommended when conditions are met.",
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
    elseif kind == "thrash" then
        return ( THRASH_BASE_TICK + THRASH_AP_COEFF * ap ) * mastery_bonus * multiplier
    end

    local points = max( cp or 1, 1 )
    return ap * points * mastery_bonus * multiplier
end )

spec:RegisterStateFunction( "store_bleed_snapshot", function( kind, cp, unit )
    kind = kind or "rake"
    local snap, resolved = get_bleed_snapshot_record( unit )
    if not snap then return end

    local value = predict_bleed_value( kind, cp, resolved )
    local mult = current_bleed_multiplier()
    local ap = resolve_attack_power()
    local now = query_time or state.now or 0

    if kind == "rake" then
        snap.rake_mult = mult
        snap.rake_value = value
        snap.rake_ap = ap
        snap.rake_time = now
    elseif kind == "rip" then
        snap.rip_mult = mult
        snap.rip_value = value
        snap.rip_ap = ap
        snap.rip_cp = cp or combo_points.current or 0
        snap.rip_time = now
    elseif kind == "thrash" then
        snap.thrash_mult = mult
        snap.thrash_value = value
        snap.thrash_ap = ap
        snap.thrash_time = now
    else
        local prefix = string.lower( tostring( kind ) )
        snap[ prefix .. "_mult" ] = mult
        snap[ prefix .. "_value" ] = value
        snap[ prefix .. "_ap" ] = ap
        snap[ prefix .. "_time" ] = now
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
    elseif kind == "thrash" then
        return snap.thrash_value or 0
    end

    local prefix = string.lower( tostring( kind ) )
    return snap[ prefix .. "_value" ] or 0
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
    if not buff.cat_form.up then return false end
    if active_enemies > 1 then return false end
    if energy.current >= 15 then return false end
    if debuff.rake.remains < 8 or debuff.rip.remains < 8 then return false end
    if cooldown.tigers_fury.remains < 7 then return false end
    if buff.berserk.up then return false end

    if buff.predatory_swiftness.up and buff.predatory_swiftness.remains >= 5 then return true end
    if buff.predatory_swiftness.down and rake_damage_increase_pct <= 0.05 then return true end

    return false
end )

spec:RegisterStateExpr( "should_bear_weave", function()
    if not opt_bear_weave then return false end
    if query_time <= ( action.cat_form.lastCast + gcd.max ) then return false end
    local thrash_cd = cooldown.thrash_bear
    if not thrash_cd or not thrash_cd.ready then return false end
    
    local urgent_refresh = ( (debuff.rip.remains > 0 and debuff.rip.remains <= 3)
        or (debuff.rake.remains > 0 and debuff.rake.remains <= 3)
        or (buff.savage_roar.up and buff.savage_roar.remains <= 4)
        or cooldown.tigers_fury.remains <= 2 )
    if urgent_refresh then return false end
    
    return energy.current <= 35 and not buff.berserk.up and not buff.incarnation_king_of_the_jungle.up and target.time_to_die > 10
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
        return debuff.thrash.down
    end

    local lastThrash = action.thrash_bear and action.thrash_bear.lastCast or -math.huge

    return lastThrash < lastBear
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

spec:RegisterPack( "野性Simc", 20251026, [[Hekili:DV1EVnoUr8plbhGHnYg)kpU29IxG9ES9UfDrrrZE4Ck2)ZwYY02crw0vIkUbiqF27mKus8LEy3Cff9pUBte5mCgY5XVziZIjlECX81(mYIhMoE6Ttgp9UHtVEY13mDXC2lhilMFWp4j)TWpe7Vh()FIK4hHF9LiQ)AK6uAwsamYI5RYcJy)w8IvMSeM0bsWIhMm(6fZ3fUEnrmjsAWI5pUlmn3d)p)Cp5QL7r3a)EalKgN7ffMYGH3qtY9(vYtHrHdxmN)rC9PhiXKe4NEGRmKy)vrK1l(XfZf0Vy(gFssiz5MWeIyrtcpig5RCAZ9sj)ZmsCaSU93MfUMSEW7Z9(0NY9U6d5E)H)teXp94NU8hjjPKKNGjE)SRhN7H0V9LbIXXnG1WeK0fEaM2JaxoggVMEuoPh3L4NUtFKfZbzIbsP)I5p7d)dOcd37hgZG)B5gyVOxU3AYQSnBgQOndbAJxWGnAuZlu3eqEv3hGXV2yNPA1eY)WGSKesml37(z5ExpUIzSWTGcTCtwYliJUPwgXLnLzpm7qfxwj21qoCBTCiGUFfD5bkO1PkcuU3TC1NVasgbmN)TlGTryJjmfz3Y0DjK1lpUJeVmLgr5ZaLGNjlb1CFiboya1BsU3GkrJteky39Miy8tKsMV3pEliyb(mCf((tCf(WmTLOUnxWAg5(F58oAyCZrPiYa3XF5HF(Rp4YDIcuLsyvKwyPI)uug8ptmCVEKaw3Gd8HecqyUhJE4QiYZKiW7kDhnb(ev6bYGtnWf3pkc0wiiao5CpqQwsbMT3p6DOVgUAWzkoPJe)NjPCHyPi0KI)sPpXPk(vCdw2LRiWVYxixorNbdtJjpvXqtNP2z4ytgEmXNTRIJMoxTZXj3QYs2MLROXzPU8hkyraS9Vu8llXGWIqXfmGFI7YyVtKRCElSg5NPNxS9)bdsuWEbmxIxN7XzeqFmMQ6niyRthnMFYwcByGFklmERsmMNYaLEf4Nj0k0UQuPmCe5JPh9U(fKlJbrajY1uZ1g3nHKM7BodGm8fydGZTiYA)IuBdxt2egektnmbs596RIOUu2qmvZWecU5LkZDigNpy4b9XMkglGsJW9sTqsMtCGwqAvnP(uqxiduASHW1NeavHEKv1SC79ZIk9FmcE74aP(ufL2t6HpuZtySrJ7ur(baSkM5wzLOumbH5tAJEeQzS19iMhIk0vcRu8CiH0kuai)ZL5ELQvraIAs81OXAXXtQ)ZWHXYeQFsXMqn5)Y9uoJuiRzdAvMHB1ltclTPlSlrPTDlv47ltzj04TykQbfqowtI8Fb5kN7SnfFpic(e(5JHqq50y)dqsoMvI66nGv9QmKW6C0WbAqgXrDjK43Rtkr4JncuRwNmP8lIKzObYpAQddQbjsd(y9DGfexLokwftVrmxdu2kFZqyEQ4)QhHz1x103MaFwp8Wwc1FHMJJl3elVATjDtlwX)zSvZ0HsCwGzhBINioCtibGs8t(Wo0xfSgQYJY8XjacplXpons(BybSFJ(T5H7t54yLeum9pYx2b1b(YmkANqpjal5i2yNOUiTCQRyuDIdi62MJCOLEub7k)0fcdLfTwdsB3wxofNFE5(LlT6aLg26zSh0rzIJAOrFEtJ5pONYVrU7tjU8P7eTPYc9(4x)L3ghdGrokXd2xLUYyNuuQEd3zUenvK1Wn4)RQHRthbwL5u571aWUDqHmqbVPry2A5VOMcrIQo9fmLoea9qcKtifI36V2ej4pP6RxxSggq)te2KILS83BicJCotnOzA5wvXexfrPRLGu1WwRbbxMZJxmvJiWli4avU9BwEJoubzHAWjazjJUCDirMq7UI(C(CyYEsC6YvaFwk5AJUZm)iiP9WW4a)KyEi(HY51EhCuiQ5u1o4ImsLqbxYr3Ha(aiDhT2hrM)xBpgzgy9WsiebkFPIbmnGSKUbmHzzq1WfSOCnmMaUwtg3Tfdfw11Ah4ZYqwX2HWuJwRTvAI)RcNPZDbTy2wCw4)TNgtrCsVjXd)IGzVNhuCdIk)aSFWbbOguedHag2dAoG1PhbSTEeD6HaT4OwiqwzxFCS75SDGRYsIFp2gVWTXvTdaS2al7DSOxuJIwv3)PwyPcQqhvowgWsTAzTqm34iqKRyvkIu9HomdqvecR4Zo6z)PwTaVYffo2wxH7exaZxAqintOnItBOkb)SOZ0zrnbVU1b)MLY9(5KSqWpV)xO)(Gse0xXTvq))p(7)9CV58RCck(fDVW7TbSM2XyhsF)OrBHQAZwne0UrhPhtbIhTNEyegpB0EOojsYOSWrRXvz0gCjh5FicS9EGYiPaFUk37lHjju8wCGGe5E8(gYma0lDEX(xJsp8L(OF7i0Zye3HBegylof0HSu(mbjApA9dkggziKcNeaWVH8LCUSm8CV4mShL4THHXma5)qKSUdSH4RqTMUklLHc2vBbdoGb)Ti6kCVtEYuCxzczdhyfzhiVCDQFGFSGp0Njjj8lJd(9xkGWHs8FaqgaEKq3dsauVcmzY)chovQRW8WcotVADcGHnEW7kPgzDe9i2W1xkxcYBkepJGKVX49mJy2CW0tVf(gXpBeC5P3oFKhcdptol)QdStDJR7jreIBHwDihbUAN)Laou5C1hDegRB8uacsNL8V5ahKEkCEGc9BGgm7)zH)vHXEJ1cQGmeqzYBMZKPAvbiV4Ax4KQNTnvfbivyqD34yky5EFaGKkaiDn)3l5HJeSM0Izzzg3(CzkB9Sz13U2tm7TPh3PKZfTxGkNpRMNZRY9)2TmVQTLyB8uADwU3ndvstR36unaoPhdpiAcOd4no2beirQVnfOkEx5nxy0rpPyf8sqe48YlYkf3SDeltfNsll3nw3rGwB9TBnzU33pC652TEhcpROhtny5iMGUnZ3WVjBZbiizjCGa)kwdIapbhGX34EHNFtYe3je27TgeprrzPlbZHnSyitU5Ddv1qgm)EjCKF9Xr)bzBc9iBN7xPsvULIIZKfXToH4VhJweaItsywAvrCdQ8fGywR9z0KxQKSQoCxeAWs4vd840XPbXRwoQ0ZpxsLr3)GkjJGJZLmAwWUMJWPjmvz4BEtqE3fUIWCJYTILipCewbF5Rp81F6Jp6YqWvjQT02ojixaC3teYbSnEDT7Nf1tFw47S64Mb(IZR72gjlHrbSPiEw1NP2r)Kyex7I5)2(d0egASo5oJxI2W8pJ5APBcrH(7G9Lox5YN)U)ukEbzRS(f8h)VFjmYv9)OQy(mNlVXLYGS8KRM5hAPAM8plShsVC2OcR33HMzZuQT5DCRz1Vupz61TiP04MkAKyL0bkuRM7OrYRIjPqTsGQgjwyKOqOmCBJeP4sRqPYxRN8Y6cKew1TYgjbX9RqbVZGctUsiVLmyyjsAGvMGEFx4MzxuhCy3SOatS7rva4wXBJhjHtcf4AfQOdaWs1RSx)vmPSLBatWndGM9VdBy)m(1kGsrZxNqxyvX1fCcZDQ75wDxb1mE5Te4E8w2Nq114wcE9v7Bi4(ztVZn)vAFpYR6VjGEU6FFtQuPOPtZRV6Ut3ozLrF5rw(SvN(71Cx(DZzRMPBXBuQ61wt9713QQOAuWbst6AFAFvYj)JO2x9a(0KoL4Y9Q5T(zZSQ3XN4Cw91(jfTUGJUIXymwGVwOr1e1QyQ963g26b9AevDVlQh9RPqPbWTwbQw(bhH1dT1ElOahR1cvLgQEvl7qpDCY3p7MX4bsXIWVZ5zJuEILwJveJU0LZ8Le1kbQpuGE91Fsn3pBY4xFTVzjZ3p76xF1O(vioZRV20BKeMWGbwId(egRsFyi89uF(JFa)dxWM8Yh7O1yfV(qRZMk4j9S3bC9Wgb9L7L09cJRegoAgqA4)RLOOG1PNDnYfoN2pasfdr0dxz7gxctRQRV9sR(60Z(Yi15zhYV3Z1LX8HXgmcmsePMTBesV(QVSr32uQVMXb9UWSVi9UWDhrmfcW8fLI(AVur5kAAAR96eRwZQxLyXIA9EenpxkBWvD(NIDaLNEOqK0F2HGqnW80bFYyCfYcdqRldojNNCZUDaOT9R5TS1dfGQMCnBIPmv9Y9mpVlnfV12SRNT86YASuFDfH6I(USCSSylh8gNh8NQYZDolBWALa7tjV9(KsMQzq5UpR3FZWBnPRSDQMdW9l06D4SjiR1v37NDxpRnmhld6Q3bMDtpNbdmpd)(Htpf)DbgR)mEUJk4iR6hZLMLRvCkklxBCDuz2WhLAWpnscCuIuhiJ)i2ojkoVCxNYkGPGBkpDFRN6O09wn3DTNtUxtWK1248dyQ(tHlPfwEN47NrbMUGql7jNTxzC3OZUZkDKqREQmwQED9vWuTmINxZLU6Jq5qDaKHdQucT6yuz8thJ0ANhSOad456Z2qAusI6Ga9hKsJ0kmM62n5wUs1AEkUTwEDFH7j3pzA7KOy1lLM)x5V34QnwHAD5BuHYLCt)4U8ZTLkFSdAAUvioiOeHtxaobi6ojOkwR25HvZ1wwJUcn36OQnyBCYM0ub2QL3S9p0WB2UAPbozf)ZUn4JBMaNrON0onwbzTOPREMN9nIvTGYlFREGjYLWbbDPb5t6(kzREVL)Ly)do)lXUs6e)fK3bJIjTstB2fnqwtMgnqwJ57RHod8QtU1bfUpOeP1680vVeZ5(zm4GBX857Z2KYVrZf)7]] )

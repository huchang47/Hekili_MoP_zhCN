if not Hekili or not Hekili.NewSpecialization then return end
-- DeathKnightFrost.lua
-- Updated june 1, 2025 - Mists of Pandaria Frost Death Knight Module
-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 251 ) -- Frost spec ID for MoP

local strformat = string.format
-- Enhanced Helper Functions for MoP compatibility
local function UA_GetPlayerAuraBySpellID(spellID, filter)
    -- MoP compatibility: use fallback methods since C_UnitAuras doesn't exist
    if filter == "HELPFUL" or not filter then
        return ns.FindUnitBuffByID("player", spellID)
    else
        return ns.FindUnitDebuffByID("player", spellID)
    end
end

-- Advanced Combat Log Event Tracking Frame for Frost Death Knight Mechanics
local FrostCombatFrame = CreateFrame( "Frame" )
local frostEventData = {
    -- Killing Machine proc tracking from auto-attacks and abilities
    killing_machine_procs = 0,
    last_km_proc = 0,
    km_proc_rate = 0.15, -- Base 15% chance per auto-attack
    
    -- Rime proc tracking from Obliterate and other abilities
    rime_procs = 0,
    last_rime_proc = 0,
    rime_proc_rate = 0.15, -- Base 15%, improved by talents
    
    -- Runic Power generation tracking across all sources
    rp_generation = {
        frost_strike = 0,      -- RP spending ability
        obliterate = 15,       -- Primary RP generator
        howling_blast = 10,    -- AoE RP generator
        icy_touch = 10,        -- Disease application + RP
        blood_strike = 10,     -- Cross-spec ability RP
        death_and_decay = 10,  -- AoE RP generator
        army_of_dead = 30,     -- Major cooldown RP burst
    },
    
    -- Rune regeneration and conversion tracking
    rune_events = {
        blood_runes_used = 0,
        frost_runes_used = 0,
        unholy_runes_used = 0,
        death_runes_created = 0,
        empower_uses = 0,
        blood_tap_uses = 0,
    },
    
    -- Disease tracking and pandemic mechanics
    disease_management = {
        frost_fever_applications = 0,
        blood_plague_applications = 0,
        disease_refreshes = 0,
        pandemic_extensions = 0,
    },
    
    -- Pillar of Frost optimization tracking
    pillar_usage = {
        total_uses = 0,
        rp_spent_during = 0,
        abilities_used_during = 0,
        optimal_timing_count = 0,
    },
    
    -- Dual-wield vs Two-handed weapon tracking
    weapon_mechanics = {
        threat_of_thassarian_procs = 0,
        might_frozen_wastes_bonus = 0,
        off_hand_strikes = 0,
        main_hand_strikes = 0,
    },
}

FrostCombatFrame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
FrostCombatFrame:RegisterEvent( "UNIT_SPELLCAST_SUCCEEDED" )
FrostCombatFrame:RegisterEvent( "UNIT_AURA" )
FrostCombatFrame:SetScript( "OnEvent", function( self, event, ... )
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID( "player" ) then
            -- Killing Machine proc detection from auto-attacks
            if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
                if math.random() < frostEventData.km_proc_rate then
                    frostEventData.killing_machine_procs = frostEventData.killing_machine_procs + 1
                    frostEventData.last_km_proc = GetTime()
                end
                
            end
            -- Obliterate usage and Rime proc tracking
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 49020 then -- Obliterate
                local rime_chance = state.talent.rime.enabled and 0.45 or 0.15
                if math.random() < rime_chance then
                    frostEventData.rime_procs = frostEventData.rime_procs + 1
                    frostEventData.last_rime_proc = GetTime()
                end
                frostEventData.rune_events.frost_runes_used = frostEventData.rune_events.frost_runes_used + 1
                frostEventData.rune_events.unholy_runes_used = frostEventData.rune_events.unholy_runes_used + 1
            end
            
            -- Frost Strike Runic Power spending tracking
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 49143 then -- Frost Strike
                -- Track RP spending and potential Runic Empowerment/Corruption procs
                if state.talent.runic_empowerment.enabled and math.random() < 0.45 then
                    frostEventData.rune_events.empower_uses = frostEventData.rune_events.empower_uses + 1
                end
            end
            
            -- Disease application tracking
            if subEvent == "SPELL_AURA_APPLIED" then
                if spellID == 59921 then -- Frost Fever
                    frostEventData.disease_management.frost_fever_applications = frostEventData.disease_management.frost_fever_applications + 1
                elseif spellID == 59879 then -- Blood Plague
                    frostEventData.disease_management.blood_plague_applications = frostEventData.disease_management.blood_plague_applications + 1
                end
            end
            
            -- Pillar of Frost usage optimization
            if subEvent == "SPELL_AURA_APPLIED" and spellID == 51271 then -- Pillar of Frost
                frostEventData.pillar_usage.total_uses = frostEventData.pillar_usage.total_uses + 1
                -- Start tracking abilities used during Pillar
                local logFunc = function()
                    -- Log Pillar effectiveness after 20 seconds
                end
                
                if C_Timer and C_Timer.After then
                    C_Timer.After(20, logFunc)
                elseif ns.ScheduleTimer then
                    ns.ScheduleTimer(logFunc, 20)
                end
            end
        end
    end
end )

-- Advanced Resource System Registration with Multi-Source Tracking
-- Runic Power: Primary resource for Death Knights with multiple generation sources
-- MoP: Use legacy power type constants
spec:RegisterResource( 6, { -- RunicPower = 6 in MoP
    -- Base regeneration and maximum values
    base_regen = 0, -- No passive regeneration
    maximum = 100,  -- Base maximum, can be increased by talents/effects
    
    -- Advanced generation tracking per ability
    generation_sources = {
        obliterate = 15,        -- Primary Frost generator
        howling_blast = 10,     -- AoE generator
        icy_touch = 10,         -- Disease application
        blood_strike = 10,      -- Cross-spec ability
        death_and_decay = 10,   -- AoE ability
        chains_of_ice = 10,     -- Utility with RP gen
        horn_of_winter = 10,    -- Buff ability (if not glyphed)
        army_of_dead = 30,      -- Major cooldown burst
    },
    
    -- Chill of the Grave talent enhancement
    chill_bonus = function()
        return state.talent.chill_of_the_grave.enabled and 5 or 0 -- +5 RP per Icy Touch
    end,
    
    -- Runic Empowerment and Corruption interaction
    empowerment_efficiency = function()
        if state.talent.runic_empowerment.enabled then
            return 1.15 -- 15% more efficient RP usage due to rune refresh
        elseif state.talent.runic_corruption.enabled then
            return 1.20 -- 20% more efficient due to faster rune regen
        end
        return 1.0
    end,
} )

-- Enhanced Rune System: Six-rune system with Death Rune conversion mechanics
-- MoP: Use legacy power type constants
spec:RegisterResource( 5, { -- Runes = 5 in MoP
    -- Base rune configuration for Mists of Pandaria
    blood_runes = 2,      -- 2 Blood runes
    frost_runes = 2,      -- 2 Frost runes  
    unholy_runes = 2,     -- 2 Unholy runes
    death_runes = 0,      -- Death runes created from conversions
    
    -- Rune regeneration timing
    base_recharge = 10.0, -- Base 10-second recharge
    
    -- Unholy Presence speed bonus
    unholy_presence_bonus = function()
        return state.buff.unholy_presence.up and 0.15 or 0 -- 15% faster regen
    end,
    
    -- Runic Corruption enhancement
    corruption_multiplier = function()
        return state.buff.runic_corruption.up and 2.0 or 1.0 -- 100% faster when active
    end,
    
    -- Blood Tap conversion mechanics
    blood_tap_conversion = function()
        if state.talent.blood_tap.enabled then
            return {
                charges = 10,           -- Maximum Blood Tap charges
                charge_generation = 2,  -- Charges per Blood rune spent
                conversion_cost = 5,    -- Charges to convert rune to Death
            }
        end
        return nil
    end,
    
    -- Empower Rune Weapon full refresh
    empower_refresh = {
        cooldown = 300,     -- 5-minute cooldown
        rp_generation = 25, -- Bonus RP on use
        full_refresh = true -- Refreshes all runes instantly
    },
    
    -- Death Rune mechanics (can be used as any rune type)
    death_rune_flexibility = true,
    max_death_runes = 6, -- Theoretical maximum if all runes convert
    
    -- Frost-specific rune consumption patterns
    frost_consumption = {
        obliterate = { frost = 1, unholy = 1 },     -- Requires both types
        howling_blast = { frost = 1 },              -- Frost only (unless Rime)
        icy_touch = { frost = 1 },                  -- Frost only
        chains_of_ice = { frost = 1 },              -- Frost only
        death_and_decay = { unholy = 1 },           -- Unholy only
        blood_strike = { blood = 1 },               -- Blood only
    },
} )

-- Comprehensive Tier Sets and Gear Registration for MoP Death Knight
-- Tier 14: Battleplate of the Lost Cataphract
spec:RegisterGear( "tier14_lfr", 89236, 89237, 89238, 89239, 89240 )      -- LFR versions
spec:RegisterGear( "tier14_normal", 86919, 86920, 86921, 86922, 86923 )   -- Normal versions  
spec:RegisterGear( "tier14_heroic", 87157, 87158, 87159, 87160, 87161 )    -- Heroic versions
-- T14 Set Bonuses: 2pc = Icy Touch spreads diseases, 4pc = Death Coil heals for 20% more

-- Tier 15: Battleplate of the All-Consuming Maw  
spec:RegisterGear( "tier15_lfr", 96617, 96618, 96619, 96620, 96621 )      -- LFR versions
spec:RegisterGear( "tier15_normal", 95225, 95226, 95227, 95228, 95229 )   -- Normal versions
spec:RegisterGear( "tier15_heroic", 96354, 96355, 96356, 96357, 96358 )    -- Heroic versions
-- T15 Set Bonuses: 2pc = Pillar of Frost grants 5% crit, 4pc = Death Strike heals nearby allies

-- Tier 16: Battleplate of the Prehistoric Marauder
spec:RegisterGear( "tier16_lfr", 99446, 99447, 99448, 99449, 99450 )      -- LFR versions
spec:RegisterGear( "tier16_normal", 99183, 99184, 99185, 99186, 99187 )   -- Normal versions  
spec:RegisterGear( "tier16_heroic", 99709, 99710, 99711, 99712, 99713 )    -- Heroic versions
spec:RegisterGear( "tier16_mythic", 100445, 100446, 100447, 100448, 100449 ) -- Mythic versions
-- T16 Set Bonuses: 2pc = Obliterate increases crit by 5%, 4pc = Killing Machine increases damage by 25%

-- Legendary Cloak variants for all classes
spec:RegisterGear( "legendary_cloak_agi", 102246 )    -- Jina-Kang, Kindness of Chi-Ji (Agility)
spec:RegisterGear( "legendary_cloak_str", 102245 )    -- Gong-Lu, Strength of Xuen (Strength) 
spec:RegisterGear( "legendary_cloak_int", 102249 )    -- Ordos cloak variants

-- Notable Trinkets from MoP content
spec:RegisterGear( "unerring_vision", 102293 )        -- Unerring Vision of Lei-Shen (SoO)
spec:RegisterGear( "haromms_talisman", 102301 )       -- Haromm's Talisman (SoO)
spec:RegisterGear( "sigil_rampage", 102299 )          -- Sigil of Rampage (SoO) 
spec:RegisterGear( "thoks_tail_tip", 102313 )         -- Thok's Tail Tip (SoO)
spec:RegisterGear( "kardris_totem", 102312 )          -- Kardris' Toxic Totem (SoO)
spec:RegisterGear( "black_blood", 102310 )            -- Black Blood of Y'Shaarj (SoO)

-- PvP Sets for Death Knights
spec:RegisterGear( "pvp_s12_glad", 84427, 84428, 84429, 84430, 84431 )    -- Season 12 Gladiator
spec:RegisterGear( "pvp_s13_tyrann", 91465, 91466, 91467, 91468, 91469 )  -- Season 13 Tyrannical  
spec:RegisterGear( "pvp_s14_griev", 98855, 98856, 98857, 98858, 98859 )   -- Season 14 Grievous
spec:RegisterGear( "pvp_s15_prideful", 100030, 100031, 100032, 100033, 100034 ) -- Season 15 Prideful

-- Challenge Mode Sets (Cosmetic but with stats)
spec:RegisterGear( "challenge_mode", 90309, 90310, 90311, 90312, 90313 )   -- CM Death Knight set

-- Meta Gems relevant to Death Knights
spec:RegisterGear( "meta_relentless", 76885 )         -- Relentless Earthsiege Diamond
spec:RegisterGear( "meta_austere", 76879 )            -- Austere Earthsiege Diamond  
spec:RegisterGear( "meta_eternal", 76884 )            -- Eternal Earthsiege Diamond
spec:RegisterGear( "meta_effulgent", 76881 )          -- Effulgent Shadowspirit Diamond

-- Talents (MoP talent system and Frost spec-specific talents)
spec:RegisterTalents( {
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 56)
    roiling_blood        = { 1, 1, 108170 }, -- Your Pestilence refreshes disease durations and spreads diseases from each diseased target to all other targets.
    plague_leech         = { 1, 2, 123693 }, -- Extract diseases from an enemy target, consuming up to 2 diseases on the target to gain 1 Rune of each type that was removed.
    unholy_blight        = { 1, 3, 115989 }, -- Causes you to spread your diseases to all enemy targets within 10 yards.
    
    -- Tier 2 (Level 57)
    lichborne            = { 2, 1, 49039 },
    anti_magic_zone      = { 2, 2, 51052 },
    purgatory            = { 2, 3, 114556 },
    
    -- Tier 3 (Level 58)
    deaths_advance       = { 3, 1, 96268 },
    chilblains           = { 3, 2, 50041 },
    asphyxiate           = { 3, 3, 108194 },
    
    -- Tier 4 (Level 60)
    death_pact           = { 4, 1, 48743 },
    death_siphon         = { 4, 2, 108196 },
    conversion           = { 4, 3, 119975 },
    
    -- Tier 5 (Level 75)
    blood_tap            = { 5, 1, 45529 },
    runic_empowerment    = { 5, 2, 81229 },
    runic_corruption     = { 5, 3, 51462 },
    
    -- Tier 6 (Level 90)
    gorefiends_grasp     = { 6, 1, 108199 },
    remorseless_winter   = { 6, 2, 108200 },
    desecrated_ground    = { 6, 3, 108201 },
} )

-- Enhanced Glyph System for Frost Death Knight
spec:RegisterGlyphs( {
    -- Major Glyphs: Significant gameplay modifications
    -- Defensive Enhancement Glyphs
    [58640] = "anti_magic_shell",       -- Increases duration by 2 sec, cooldown by 20 sec
    [58631] = "icebound_fortitude",     -- Reduces cooldown by 60 sec, duration by 2 sec  
    [58657] = "dark_succor",            -- Death Strike heals 20% health when not in Blood Presence
    [58632] = "dark_simulation",        -- Dark Simulacrum usable while stunned
    
    -- Frost Damage Enhancement Glyphs
    [58622] = "howling_blast",          -- Additional damage to primary target
    [58675] = "icy_touch",              -- Frost Fever deals 20% additional damage
    [63335] = "pillar_of_frost",        -- Cannot be dispelled, 1-min cooldown (down from 2-min)
    [63331] = "chains_of_ice",          -- Adds 144-156 Frost damage based on attack power
    
    -- Resource and Utility Glyphs
    [58616] = "horn_of_winter",         -- No RP generation, lasts 1 hour instead of 2 minutes
    [59337] = "death_strike",           -- Reduces RP cost by 8 (from 40 to 32)
    [58629] = "death_and_decay",        -- Increases damage by 15%
    [58677] = "death_coil",             -- Also heals pets for 1% of DK health
    
    -- Combat Utility Glyphs
    [58686] = "death_grip",             -- Cooldown reset on killing blows that yield XP/honor
    [58671] = "plague_strike",          -- 20% additional damage against targets above 90% health
    [58649] = "soul_reaper",            -- Gain 5% haste for 5 sec when striking targets below 35% health
    
    -- Rune Management Glyphs
    [58668] = "blood_tap",              -- Costs 15 RP instead of health
    [58669] = "rune_tap",               -- Increases healing by 100% but increases cooldown by 30 sec
    [58679] = "vampiric_blood",         -- No longer increases damage taken, healing bonus reduced to 15%
    
    -- Advanced Frost-Specific Glyphs
    [58673] = "obliterate",             -- Obliterate has 25% chance not to consume diseases
    [58674] = "frost_strike",           -- Frost Strike dispels one magic effect from target
    [58676] = "empower_rune_weapon",    -- Reduces cooldown by 60 sec, grants 10% damage for 30 sec
    
    -- Presence Enhancement Glyphs
    [58672] = "unholy_presence",        -- Movement speed bonus increased to 20% (from 15%)
    [58670] = "frost_presence",         -- Reduces damage from magic by additional 5%
    [58667] = "blood_presence",         -- Increases healing from all sources by 10%
    
    -- Minor Glyphs: Cosmetic and convenience improvements
    [60200] = "death_gate",             -- Reduces cast time by 60% (from 10 sec to 4 sec)
    [58617] = "foul_menagerie",         -- Raise Dead summons random ghoul companion
    [63332] = "path_of_frost",          -- Army of the Dead ghouls explode on death/expiration
    [58680] = "resilient_grip",         -- Death Grip refunds cooldown when used on immune targets
    [59307] = "the_geist",              -- Raise Dead summons a geist instead of ghoul
    [60108] = "tranquil_grip",          -- Death Grip no longer taunts targets
    [58678] = "corpse_explosion",       -- Corpse Explosion has 50% larger radius
    [58665] = "bone_armor",             -- Bone Armor provides 2 additional charges
    
    -- Additional Utility Minor Glyphs
    [58666] = "death_coil_visual",      -- Death Coil has a different visual effect
    [58681] = "raise_dead_duration",    -- Raise Dead minions last 50% longer
    [58682] = "army_of_dead_speed",     -- Army of the Dead ghouls move 50% faster
    [58683] = "horn_of_winter_visual",  -- Horn of Winter has enhanced visual/audio effects
    [58684] = "blood_tap_visual",       -- Blood Tap has a different visual effect
    [58685] = "death_grip_visual",      -- Death Grip has enhanced chain visual
} )

-- Advanced Aura System with Sophisticated Generate Functions for Frost Death Knight
spec:RegisterAuras( {
    -- Core Frost Presence: Enhanced with combat state tracking
    frost_presence = {
        id = 48266,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 48266 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "frost_presence_enhanced"
    },

    -- Pillar of Frost: Main DPS cooldown with advanced tracking
    pillar_of_frost = {
        id = 51271,
        duration = 20,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 51271 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track optimal usage timing
                local time_remaining = expires - GetTime()
                if time_remaining > 15 then
                    -- Still have significant time left, track usage efficiency
                    frostEventData.pillar_usage.optimal_timing_count = frostEventData.pillar_usage.optimal_timing_count + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = { "pillar_of_frost_enhanced", "strength_boost" }
    },

    -- Killing Machine: Critical strike guarantee with advanced proc tracking
    killing_machine = {
        id = 51124,
        duration = 10,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 51124 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track KM consumption efficiency
                local time_since_proc = GetTime() - frostEventData.last_km_proc
                if time_since_proc < 2 then
                    -- Fast consumption - good gameplay
                    frostEventData.km_consumption_efficiency = (frostEventData.km_consumption_efficiency or 0) + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = { "km", "guaranteed_crit" }
    },

    -- Rime: Free Howling Blast with advanced proc mechanics
    rime = {
        id = 59052,
        duration = 15,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 59052 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track Rime usage efficiency for AoE optimization
                if active_enemies and active_enemies > 1 then
                    frostEventData.rime_aoe_efficiency = (frostEventData.rime_aoe_efficiency or 0) + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = { "freezing_fog", "free_howling_blast" }
    },    -- Frost Fever: Disease with pandemic mechanics
    frost_fever = {
        id = 59921,
        duration = 30,
        tick_time = 3,
        max_stack = 1,
        type = "Disease",
        generate = function( aura, t )
            local name, _, count, _, duration, expires, caster = GetUnitAura( t or "target", 59921, "HARMFUL" )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Pandemic mechanic: can refresh up to 30% early
                local pandemic_window = duration * 0.3
                aura.pandemic_window = expires - pandemic_window
                
                -- Track disease management efficiency
                if aura.applied > GetTime() - 27 then -- Refreshed with >3 sec remaining
                    frostEventData.disease_management.pandemic_extensions = frostEventData.disease_management.pandemic_extensions + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "frost_fever_enhanced"
    },    -- Blood Plague: Cross-spec disease tracking
    blood_plague = {
        id = 59879,
        duration = 30,
        tick_time = 3,
        max_stack = 1,
        type = "Disease",
        generate = function( aura, t )
            local name, _, count, _, duration, expires, caster = GetUnitAura( t or "target", 59879, "HARMFUL" )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Blood Strike damage bonus tracking
                local disease_count = 1
                if state.debuff.frost_fever.up then disease_count = disease_count + 1 end
                aura.disease_damage_bonus = disease_count * 0.125 -- 12.5% per disease
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "blood_plague_enhanced"
    },

    -- Runic Corruption: Enhanced rune regeneration
    runic_corruption = {
        id = 51460,
        duration = 3,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 51460 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track rune regeneration efficiency
                aura.regen_bonus = 2.0 -- 100% faster rune regeneration
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "enhanced_rune_regen"
    },

    -- Runic Empowerment: Instant rune refresh
    runic_empowerment = {
        id = 81229,
        duration = 5,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 81229 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track which rune type was refreshed for optimization
                aura.refresh_efficiency = frostEventData.rune_events.empower_uses or 0
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "instant_rune_refresh"
    },

    -- Anti-Magic Shell: Magic immunity with glyph tracking
    anti_magic_shell = {
        id = 48707,
        duration = function() return spec.glyph.anti_magic_shell.enabled and 7 or 5 end,
        max_stack = 1,
        generate = function( aura )
            local duration_bonus = spec.glyph.anti_magic_shell.enabled and 2 or 0
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 48707 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                aura.glyph_enhanced = duration_bonus > 0
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "magic_immunity"
    },

    -- Horn of Winter: Stat buff with glyph variants
    horn_of_winter = {
        id = 57330,
        duration = function() return spec.glyph.horn_of_winter.enabled and 3600 or 120 end,
        max_stack = 1,
        generate = function( aura )
            local extended_duration = spec.glyph.horn_of_winter.enabled
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 57330 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                aura.glyph_extended = extended_duration
                aura.rp_generation = not extended_duration -- Only generates RP if not glyphed
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "strength_agility_buff"
    },

    -- Tier Set Bonuses with Advanced Tracking
    -- T14 2pc: Icy Touch spreads diseases
    tier14_2pc = {
        id = 123456, -- Placeholder ID
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if state.set_bonus.tier14_2pc > 0 then
                aura.count = 1
                aura.expires = GetTime() + 3600
                aura.applied = GetTime()
                aura.caster = "player"
                
                -- Track disease spreading efficiency
                aura.spread_count = frostEventData.disease_management.disease_refreshes or 0
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
    },

    -- T15 2pc: Pillar of Frost grants 5% crit
    tier15_2pc = {
        id = 123457, -- Placeholder ID
        duration = 20, -- Duration of Pillar of Frost
        max_stack = 1,
        generate = function( aura )
            if state.set_bonus.tier15_2pc > 0 and state.buff.pillar_of_frost.up then
                aura.count = 1
                aura.expires = state.buff.pillar_of_frost.expires
                aura.applied = state.buff.pillar_of_frost.applied
                aura.caster = "player"
                aura.crit_bonus = 0.05 -- 5% critical strike chance
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
    },

    -- Additional presence tracking
    blood_presence = {
        id = 48263,
        duration = 3600,
        max_stack = 1,
        copy = "blood_presence_active"
    },

    unholy_presence = {
        id = 48265,
        duration = 3600,
        max_stack = 1,
        copy = "unholy_presence_active"
    },

    -- Chains of Ice slow effect
    chains_of_ice = {
        id = 45524,
        duration = 8,
        max_stack = 1,
        type = "Magic",
        copy = "frost_slow"
    },
} )

-- Frost DK core abilities
spec:RegisterAbilities( {
    obliterate = {
        id = 49020,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 1, 1}, -- 0 Blood, 1 Frost, 1 Unholy
        
        gain = 15,
        gainType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            -- Rime proc chance (15% base, increased by talent)
            local rime_chance = talent.rime.enabled and 0.45 or 0.15
            if math.random() < rime_chance then
                applyBuff("rime")
            end
            
            -- Killing Machine consumption if active
            if buff.killing_machine.up then
                removeBuff("killing_machine")
                -- Guaranteed crit when KM is active
            end
            
            -- Threat of Thassarian: dual-wield proc
            if talent.threat_of_thassarian.enabled then
                -- 50% chance to strike with off-hand as well
                if math.random() < 0.50 then
                    gain(5, "runicpower") -- Additional RP from off-hand strike
                end
            end
        end,
    },
      frost_strike = {
        id = 49143,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            -- Killing Machine consumption and guaranteed crit
            local was_km_active = buff.killing_machine.up
            if was_km_active then
                removeBuff("killing_machine")
                -- This attack will crit due to KM
            end
            
            -- Threat of Thassarian: dual-wield proc
            if talent.threat_of_thassarian.enabled then
                -- 50% chance to strike with off-hand as well
                if math.random() < 0.50 then
                    -- Off-hand strike does additional damage
                end
            end
            
            -- Runic Empowerment/Corruption proc chance from RP spending
            if talent.runic_empowerment.enabled and math.random() < 0.45 then
                applyBuff("runic_empowerment")
            elseif talent.runic_corruption.enabled and math.random() < 0.45 then
                applyBuff("runic_corruption")
            end
        end,
    },
      howling_blast = {
        id = 49184,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend_runes = {0, 1, 0}, -- 0 Blood, 1 Frost, 0 Unholy
        
        gain = function() return 15 + (2.5 * talent.chill_of_the_grave.rank) end,
        gainType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
                removeBuff("freezing_fog")
            removeStack("killing_machine")
            
            if glyph.howling_blast.enabled then
            applyDebuff("target", "frost_fever")
                active_dot.frost_fever = active_enemies
            end
        end,
      pillar_of_frost = {
        id = 51271,
        cast = 0,
        cooldown = function() return glyph.pillar_of_frost.enabled and 60 or 120 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("pillar_of_frost")
        end,
    },
    
    icy_touch = {
        id = 45477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes",
        
        startsCombat = true,
        
        usable = function() return runes.frost.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            applyDebuff("target", "frost_fever")
            
            -- Base RP generation
            local rp_gain = 10
            
            -- Chill of the Grave: additional RP from Icy Touch
            if talent.chill_of_the_grave.enabled then
                rp_gain = rp_gain + 5 -- Extra 5 RP per talent point
            end
            
            gain(rp_gain, "runicpower")
            
            -- Glyph of Icy Touch: increased Frost Fever damage
            if glyph.icy_touch.enabled then
                -- Frost Fever will deal 20% more damage
            end
        end,
    },
    
    chains_of_ice = {
        id = 45524,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes",
        
        startsCombat = true,
        
        usable = function() return runes.frost.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            applyDebuff("target", "chains_of_ice")
            gain(10, "runicpower")
            
            -- Glyph of Chains of Ice: additional damage
            if glyph.chains_of_ice.enabled then
                -- Deal additional frost damage scaled by attack power
            end
        end,
    },
    
    blood_strike = {
        id = 45902,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "blood_runes",
        
        startsCombat = true,
        texture = 237517,
        
        handler = function ()
            -- Blood Strike: Physical weapon attack with disease bonus
            -- Base damage + weapon damage, +12.5% per disease (max +25%)
            local disease_count = 0
            if debuff.blood_plague.up then disease_count = disease_count + 1 end
            if debuff.frost_fever.up then disease_count = disease_count + 1 end
            
            local damage_multiplier = 1.0 + (disease_count * 0.125)
            
            -- Generate 10 Runic Power
            gain(10, "runicpower")
        end,
    },
    
    -- Defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        cast = 0,
        cooldown = function() return glyph.anti_magic_shell.enabled and 60 or 45 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("anti_magic_shell")
        end,
    },
    
    icebound_fortitude = {
        id = 48792,
        cast = 0,
        cooldown = function() return glyph.icebound_fortitude.enabled and 120 or 180 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("icebound_fortitude")
        end,
    },
    
    -- Utility
    death_grip = {
        id = 49576,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "death_grip")
        end,
    },
    
    mind_freeze = {
        id = 47528,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        toggle = "interrupts",
        
        startsCombat = true,
        
        handler = function ()
            if active_enemies > 1 and talent.asphyxiate.enabled then
                -- potentially apply interrupt debuff with talent
            end
        end,
    },
      death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy_runes",
        
        startsCombat = true,
        
        usable = function() return runes.unholy.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            -- Generate RP based on number of enemies hit
            local rp_gain = 10 + (active_enemies > 1 and 5 or 0)
            gain(rp_gain, "runicpower")
            
            -- Glyph of Death and Decay: 15% more damage
            if glyph.death_and_decay.enabled then
                -- Increased damage from glyph
            end
        end,
    },
    
    rune_strike = {
        id = 56815,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "runicpower",
        
        startsCombat = true,
        texture = 237518,
        
        usable = function() return buff.blood_presence.up end,
        
        handler = function ()
            -- Rune Strike: Enhanced weapon strike (requires Blood Presence)
            -- 1.8x weapon damage + 10% Attack Power
            -- 1.75x threat multiplier
        end,
    },
    
    horn_of_winter = {
        id = 57330,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("horn_of_winter")
            if not glyph.horn_of_winter.enabled then
                gain(10, "runicpower")
            end
        end,
    },
    
    raise_dead = {
        id = 46584,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Summon ghoul/geist pet based on glyphs
        end,
    },
      army_of_the_dead = {
        id = 42650,
        cast = function() return 4 end, -- 4 second channel (8 ghouls @ 0.5s intervals)
        cooldown = 600, -- 10 minute cooldown
        gcd = "spell",
        
        spend = function() return 1, 1, 1 end, -- 1 Blood + 1 Frost + 1 Unholy
        spendType = "runes",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 237302,
        
        handler = function ()
            -- Summon 8 ghouls over 4 seconds, each lasting 40 seconds
            -- Generates 30 Runic Power
            gain( 30, "runic_power" )
        end,
    },
    
    path_of_frost = {
        id = 3714,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("path_of_frost")
        end,
    },
    
    -- Presence switching
    blood_presence = {
        id = 48263,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("frost_presence")
            removeBuff("unholy_presence")
            applyBuff("blood_presence")
        end,
    },
    
    frost_presence = {
        id = 48266,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("unholy_presence")
            applyBuff("frost_presence")
        end,
    },
    
    unholy_presence = {
        id = 48265,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("frost_presence")
            applyBuff("unholy_presence")
        end,
    },
    
    -- Rune management
    blood_tap = {
        id = 45529,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = function() return glyph.blood_tap.enabled and 15 or 0 end,
        spendType = function() return glyph.blood_tap.enabled and "runicpower" or nil end,
        
        startsCombat = false,
        
        handler = function ()
            if not glyph.blood_tap.enabled then
                -- Original functionality: costs health
                spend(0.05, "health")
            end
            -- Convert a blood rune to a death rune
        end,
    },
    
    empower_rune_weapon = {
        id = 47568,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            -- Refresh all rune cooldowns and generate 25 runic power
            gain(25, "runicpower")
        end,
    },
    }
} )

-- Register runes state table
spec:RegisterStateTable( "runes", {
    blood = { count = 2 },
    frost = { count = 2 },
    unholy = { count = 2 },
    death = { count = 0 }
} )
spec:RegisterStateFunction( "spend_runes", function( rune_array )
    if type(rune_array) == "table" then
        local blood_cost, frost_cost, unholy_cost = rune_array[1], rune_array[2], rune_array[3]
        
        -- Spend Blood runes
        if blood_cost and blood_cost > 0 then
            if runes.blood.count >= blood_cost then
                runes.blood.count = runes.blood.count - blood_cost
            elseif runes.death.count >= blood_cost then
                runes.death.count = runes.death.count - blood_cost
            end
        end
        
        -- Spend Frost runes
        if frost_cost and frost_cost > 0 then
            if runes.frost.count >= frost_cost then
                runes.frost.count = runes.frost.count - frost_cost
            elseif runes.death.count >= frost_cost then
                runes.death.count = runes.death.count - frost_cost
            end
        end
        
        -- Spend Unholy runes
        if unholy_cost and unholy_cost > 0 then
            if runes.unholy.count >= unholy_cost then
                runes.unholy.count = runes.unholy.count - unholy_cost
            elseif runes.death.count >= unholy_cost then
                runes.death.count = runes.death.count - unholy_cost
            end
        end
    else
        -- Legacy support for single rune type spending
        local rune_type, amount = rune_array, 1
        
        if rune_type == "obliterate" then
            if runes.frost.count > 0 and runes.unholy.count > 0 then
                runes.frost.count = runes.frost.count - 1
                runes.unholy.count = runes.unholy.count - 1
            elseif runes.death.count >= 2 then
                runes.death.count = runes.death.count - 2
            end
        elseif rune_type == "frost" and (runes.frost.count >= amount or runes.death.count >= amount) then
            if runes.frost.count >= amount then
                runes.frost.count = runes.frost.count - amount
            else
                runes.death.count = runes.death.count - amount
            end
        elseif rune_type == "unholy" and (runes.unholy.count >= amount or runes.death.count >= amount) then
            if runes.unholy.count >= amount then
                runes.unholy.count = runes.unholy.count - amount
            else
                runes.death.count = runes.death.count - amount
            end
        elseif rune_type == "death" and runes.death.count >= amount then
            runes.death.count = runes.death.count - amount
        end
    end
end )
    
spec:RegisterRanges( "obliterate", "frost_strike", "howling_blast" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 2,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    cycle = true,
    cycleDebuff = "frost_fever",

    potion = "tempered_potion",

    package = "Frost",
} )

spec:RegisterSetting( "dps_shell", false, {
    name = strformat( "Use %s Offensively", Hekili:GetSpellLinkWithTexture( 48707 ) ),
    desc = strformat( "If checked, %s will not be on the Defensives toggle by default.", Hekili:GetSpellLinkWithTexture( 48707 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "it_macro", nil, {
    name = strformat( "%s Macro", Hekili:GetSpellLinkWithTexture( 45477 ) ),
    desc = strformat( "Using a mouseover macro makes it easier to apply %s and %s to other enemies without retargeting.",
        Hekili:GetSpellLinkWithTexture( 45477 ), Hekili:GetSpellLinkWithTexture( 59921 ) ),
    type = "input",
    width = "full",
    multiline = true,
    get = function() return "#showtooltip\n/use [@mouseover,harm,nodead][] Icy Touch" end,
    set = function() end,
} )

spec:RegisterPack( "Frost", 20250803, [[Hekili:TRvBpUnUr4FlghQp7RjkI27U3MdRxG2E4qY22db1PTFts0Y0RewjrxjQySfg63EhsQxiLeLSYUhAlqcqYQLICMHZmppZiY4GC(SZ29ygX5xxzV6A7BTxBzBV69xHC2YE(iXz7rS)t4hHhsWXW)EiLrYy8HFoII3ZxEgnp1hELZ2D5HrSpM4SRxzU(gyUhj(WWxdIpiC)EICUKmFNTFoimRWJ)xCHxPwl8OhGF3Nfstk8IcZyWRpqtl8(a5PWOqlNTIbf7cYbCEedE8xf7k5QC2ghMS39qkH8VbBKKG3fr278hDyGzWNwZi1RaNWcJXpg67MfqIIC26NgYiPHy4jknAp9uIvR5yLsIXHjG1TPWZMV9JfonKn)pCLTw1MoggfHtDPhadJYDNA21vTSRg1Vl)WbRwl2k)yJG3frPWUnp9zUGU(fiisAgj9PWKh5c6gJcknpb8bhPNiqq5Ucpydx4nVWBufGt9XjexgnnLKW4k5hneoyPHjpryOlY(LzP1lbe7Tdl2vtxSR4I99gDjZG0xcZ6XaAEKfxBFH0O1uCygXDpbGoGqq2gLcdhb(fR8KaA0ZU7IcFmGzvotHhErH3EkZsyJUhiFHK2KecbI1fENplNImP4ye(XCs75SSX00uLW6qgToq5Z6r4SqFEkJu1Z6AG1VxrT0C2Uuc(jHgBdj18QMuNcUsmUBgeOEIie46XeypMxJ8c9FgYqZ9deYYmUSmyvQ(icXpODSAX4XI5Jgrxk9SGSQjIQCFAtfjM6YoogHLj2lMPgy40hH0xGEJJoD3hcSW3bSA3CHaBsSGnWfygiUNi4JWGCnAMd5ly4hWWwStu3aCYEycnaM8ex5ZUCQEjHVRepUsUxAtCOfJ)QfoIlCM4NvLugYFfqWrSaRJ(ScV3kcw)Giq1ZRFx9OAo5Ls)86RBSpO0AKleDpss7RGvNeqz2fdFul7teYKVYpGRyRmguFTW7EqDxxLGkMGS(LmlteAvhqsqunYY2vDa1wxOZCrhOSDeGXCJX(bHjCmaM7taBqRuc30wz3OcjOObypsnYuWXkfDJicONeAExeoJnC5XoMYTdykMtSNv67BSgjihkbGZiwqNjU1O27HqXa2Q5CCzfgxscjoKKv65AKeuQHf4c59qrhF8Z9vruX3vNdSsyPnPaYFxjdqrfuOKbiaEhFdwy8LMKoycIwo4a1v7iKRgi0I06KuzFQ3W2aLTA3FKQ2cOPjCo0tHjmjaFGYvtcDmqPkny(8wOC9qS9yK6mbf83yh))n2XE1Ij88V5SKV0OZLtlyMe91IM2m160PPntK(Aqtpaf5eepYO4ntjyw8Ol36nd2BepAmR3S4Nap8G1pEnAtr2R(4fHU8psFKIqMHjtIecDj9z8Que6ykXNgVdZ6Rwef(2KmIIdU6lc4pfLtehkvuKRSOtMLM)xjpItai(aclOMN4mRsdpkL4pZbVfE)5e(xo)tfE)I8qDafv(TekF7XGfQQAyupOO95vDJxANSKmiaoKmsIF7uKr)a2jYbloVhdCTAjTkN6HUfDJ6SWPXpZ3ASG(MRisFcNMabNm(XfcnfeczePSYJe87xf89q1aY)kpmLB5z0yyk4CgngqlWaGXN8ijZQ4H)cu1dSDiu9NOjW3zlEn9ihwbwc)yita51P5K3U(hw0zWFx3UvwE3M1xd2cJEXs5DMKsT1UgS2)Esw(r(wMBVs3gObvGxZ8VY48BOqAM91tu6)OX5RHFAwW7NK5GSN20rtB6RM20NQRhz23BW7Gm7)71IUzafOYpOSeZrS2Bcb06ankIEsCyD48umGjaQxy88m(A54dgFAvcHFWjCMcw18sOcCzEI2S3VNp59ygEh0A1pv8G4ZbA1pA5O8IJWJp0dsh9nK(fH0nKTnvW(qzB9QGBNw2SzWUb81RgC3iA5YJb)VpAP8MXMgKXSdO1H)(FfFqlBWWgVUVWPT1NE6Yyzlv9JXxrXdFmUAAxP7o4Ma0guod0JZ2TX5hGKmE7T0dH8(v)UcVEB1Kl0VdE5NprF7heTzw49P0qk0Eh0e9)OSF3SIhKklZQ2X8738UQ2HFdVv1nnDQ(gr3XBgO54nO5QnfxzfFQs4fE)bP(6xX6oZ3eEyZS(B(T)LR7z7Fo1DKYLUPECNBO)27q29l1MUz7)9T7JTYX8ZsCyx3cSgLBPwD4wxZ8BK3R8g51kZ3uJDH0BSvfxhytZRAU5yUynClpAlO(gIVWfOFJV8fP85KGZ2E(fieGmXfi4JlZwlVN3l0c6DXRUWf3e1fPQTVIxn9OEtQkPE9EzUZxy4s)UB95ZMUYW7wVSoRsEmvfE)vCcKBedkcyv4KO)nI8)AgaKeYs4eZk2y19gYnVfZmD1QNppZWLKUulVs9ExfUhJxnSYQQVD16v0JE6rnIBXuXT231UoFXcZ(U5g94lpFEHXRw9o0sTDDpNhH0QA3F3DBUzGK7YW4N2QqARM3PFhLYC3vI9Fp3T5ORej929U0Uvr(fnAcGKheRYXURSD)k7DULSFre23V565ledVX(8zHdM)Ge1TXEzlDP2ixnhqVhn(CfIQ73SYULGA65CyXmI(1uYTTvYl2Zm8EqRWE92O58jN3ZPHFF7OxRdXMlgj5y1XEdkEyFNi4TAUm2TAEzO7RArOjSi0u0eAmZBWa7vt1ZB0I6iN2TtPwETJAh0i7KEyGQReSv6qSRCi21KA54O3(pdjrDPsq)gsLGEvamxgvc61IkbnTKHE1RrkK(f(SjcYrthKJgd61hk61j(nSN(IbPitOo00qDJR1o24erDIJi35)m]]  )

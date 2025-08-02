-- HunterMarksmanship.lua
-- Updated July 05, 2025 - by Smufrik

-- Early return if not a Hunter
if select(2, UnitClass('player')) ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]

-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
local class = Hekili.Class
local state = Hekili.State

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
-- Enhanced helper functions for Marksmanship mechanics
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetPetBuffByID(spellID)
    return FindUnitBuffByID("pet", spellID)
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID)
end

-- Marksmanship specific combat log tracking
local mm_combat_log_events = {}

local function RegisterMMCombatLogEvent(event, callback)
    if not mm_combat_log_events[event] then
        mm_combat_log_events[event] = {}
    end
    table.insert(mm_combat_log_events[event], callback)
end

-- Hook into combat log for Marksmanship-specific tracking
local mmCombatLogFrame = CreateFrame("Frame")
mmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mmCombatLogFrame:SetScript("OnEvent", function(self, event)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    
    if sourceGUID == UnitGUID("player") then
        if mm_combat_log_events[subevent] then
            for _, callback in ipairs(mm_combat_log_events[subevent]) do
                callback(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
            end
        end
    end
end)

local function RegisterMarksmanshipSpec()
    if not class or not state or not Hekili.NewSpecialization then return end
    

    local spec = Hekili:NewSpecialization( 254, false ) -- Marksmanship spec ID for MoP (ranged)
    if not spec then return end -- Not ready yet

    spec:RegisterStateFunction( "apply_aspect", function( name )
        removeBuff( "aspect_of_the_hawk" )
        removeBuff( "aspect_of_the_iron_hawk" )
        removeBuff( "aspect_of_the_cheetah" )
        removeBuff( "aspect_of_the_pack" )

        if name then applyBuff( name ) end
    end )

-- Enhanced Resource System for Marksmanship
spec:RegisterResource( 2, { -- Focus = 2 in MoP
    -- Steady Shot focus generation (standard MoP cast time for all specs)
    steady_shot = {
        resource = "focus",
        last = function()
            local app = (state.last_cast_time and state.last_cast_time.steady_shot) or 0
            local t = state.query_time
            return app + floor( ( t - app ) / 2.0 ) * 2.0
        end,
        interval = function() return 2.0 / state.haste end, -- Standard 2.0s cast time in MoP
        value = 14, -- Steady Shot generates 14 focus in MoP
    },
    
    -- Cobra Shot focus generation (alternative builder for MM)
    cobra_shot = {
        resource = "focus",
        last = function()
            local app = (state.last_cast_time and state.last_cast_time.cobra_shot) or 0
            local t = state.query_time
            return app + floor( ( t - app ) / 2.0 ) * 2.0
        end,
        interval = function() return 2.0 / state.haste end,
        value = 14, -- Cobra Shot generates 14 focus in MoP
    },
    
    -- Dire Beast focus generation (if talented)
    dire_beast = {
        resource = "focus",
        aura = "dire_beast",
        last = function()
            local app = state.buff.dire_beast.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2 ) * 2
        end,
        interval = 2,
        value = 2, -- Dire Beast generates 2 focus every 2 seconds
    },
    
    -- Fervor talent focus restoration
    fervor = {
        resource = "focus",
        aura = "fervor",
        last = function()
            local app = state.buff.fervor.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function() return state.buff.fervor.up and 50 or 0 end, -- Instant 50 focus
    },
}, {
    -- Enhanced base focus regeneration for MoP Marksmanship
    base_regen = 6, -- Base 6 focus per second in MoP
    haste_scaling = true,
    
    regenerates = function()
        local base = 6 * state.haste
        local bonus = 0
        
        -- Aspect bonuses
        if state.buff.aspect_of_the_iron_hawk.up then
            bonus = bonus + 0.3 -- 30% increased focus regen
        elseif state.buff.aspect_of_the_hawk.up then
            bonus = bonus + 0.15 -- 15% increased focus regen
        end
        
        -- Rapid Fire bonus (MM signature cooldown)
        if state.buff.rapid_fire.up then
            bonus = bonus + 0.5 -- 50% increased focus regen during Rapid Fire
        end
        
        -- Steady Focus talent bonus (MM specific)
        if state.buff.steady_focus.up then
            bonus = bonus + 0.2 -- 20% increased focus regen with Steady Focus
        end
        
        return base * (1 + bonus)
    end,
} )

-- Enhanced Tier Sets with proper bonuses
spec:RegisterGear( 13, 8, { -- Tier 14 - Heart of Fear / Terrace of Endless Spring
    { 88183, head = 86098, shoulder = 86101, chest = 86096, hands = 86097, legs = 86099 }, -- LFR
    { 88184, head = 85251, shoulder = 85254, chest = 85249, hands = 85250, legs = 85252 }, -- Normal
    { 88185, head = 87003, shoulder = 87006, chest = 87001, hands = 87002, legs = 87004 }, -- Heroic
} )

spec:RegisterGear( 14, 8, { -- Tier 15 - Throne of Thunder
    { 96548, head = 95101, shoulder = 95104, chest = 95099, hands = 95100, legs = 95102 }, -- LFR
    { 96549, head = 95608, shoulder = 95611, chest = 95606, hands = 95607, legs = 95609 }, -- Normal
    { 96550, head = 96004, shoulder = 96007, chest = 96002, hands = 96003, legs = 96005 }, -- Heroic
} )

spec:RegisterGear( 15, 8, { -- Tier 16 - Siege of Orgrimmar
    { 99548, head = 99101, shoulder = 99104, chest = 99099, hands = 99100, legs = 99102 }, -- LFR
    { 99549, head = 99608, shoulder = 99611, chest = 99606, hands = 99607, legs = 99609 }, -- Normal
    { 99550, head = 99004, shoulder = 99007, chest = 99002, hands = 99003, legs = 99005 }, -- Heroic
    { 99551, head = 99804, shoulder = 99807, chest = 99802, hands = 99803, legs = 99805 }, -- Mythic
} )

-- Tier set bonuses
spec:RegisterGear( "tier14_2pc", function() return set_bonus.tier14_2pc end )
spec:RegisterGear( "tier14_4pc", function() return set_bonus.tier14_4pc end )
spec:RegisterGear( "tier15_2pc", function() return set_bonus.tier15_2pc end )
spec:RegisterGear( "tier15_4pc", function() return set_bonus.tier15_4pc end )
spec:RegisterGear( "tier16_2pc", function() return set_bonus.tier16_2pc end )
spec:RegisterGear( "tier16_4pc", function() return set_bonus.tier16_4pc end )

-- Enhanced Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, 102247, 102248 ) -- Legendary cloak variations
spec:RegisterGear( "lfr_weapon", 86905, 87171, 89678 ) -- Notable MoP weapons
spec:RegisterGear( "normal_weapon", 86399, 86893, 89649 )
spec:RegisterGear( "heroic_weapon", 87164, 87183, 89678 )

-- Enhanced Talent System - MoP Complete Integration
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Movement/Escape Talents
    posthaste              = { 1, 1, 109215 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 50% for 4 sec.
    narrow_escape          = { 1, 2, 109298 }, -- When you Disengage, you leave behind a web trap that snares all targets within 8 yards, reducing their movement speed by 70% for 8 sec.
    crouching_tiger        = { 1, 3, 118675 }, -- Reduces the cooldown of Disengage by 6 sec and reduces the cooldown of Deterrence by 10 sec.
    
    -- Tier 2 (Level 30) - Crowd Control Talents
    silencing_shot         = { 2, 1, 34490 }, -- Silences the target, preventing any spellcasting for 3 sec.
    wyvern_sting           = { 2, 2, 19386 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes 2,345 Nature damage over 6 sec. Only one Sting can be active on the target at a time.
    binding_shot           = { 2, 3, 109248 }, -- Fires a magical projectile, tethering the enemy and any other enemies within 5 yds for 10 sec, stunning them for 5 sec if they move more than 5 yds from the arrow.
    
    -- Tier 3 (Level 45) - Defensive/Utility Talents
    exhilaration           = { 3, 1, 109304 }, -- Instantly heals you and your pet for 22% of total health.
    aspect_of_the_iron_hawk = { 3, 2, 109260 }, -- You take 15% less damage and your Aspect of the Hawk increases attack power by an additional 10%.
    spirit_bond            = { 3, 3, 117902 }, -- You and your pet heal for 2% of total health every 10 sec. This effect persists for 10 sec after your pet dies.
    
    -- Tier 4 (Level 60) - Pet Enhancement Talents
    murder_of_crows        = { 4, 1, 131894 }, -- Summons a murder of crows to attack your target over the next 30 sec. If your target dies while under attack, the cooldown on this ability will reset.
    blink_strikes          = { 4, 2, 130392 }, -- Your pet's Basic Attacks deal 50% more damage, have a 30 yard range, and instantly teleport your pet behind the target.
    lynx_rush              = { 4, 3, 120697 }, -- Commands your pet to attack your target 9 times over 4 sec for 115% normal damage.
    
    -- Tier 5 (Level 75) - Focus Management Talents
    fervor                 = { 5, 1, 82726 }, -- Instantly restores 50 Focus to you and your pet, and then an additional 50 Focus over 10 sec.
    dire_beast             = { 5, 2, 120679 }, -- Summons a powerful wild beast that attacks the target for 15 sec. Each time the beast deals damage, you gain 2 Focus.
    thrill_of_the_hunt     = { 5, 3, 34720 }, -- Your Arcane Shot and Multi-Shot have a 30% chance to instantly restore 20 Focus.
    
    -- Tier 6 (Level 90) - AoE/Ranged Talents
    glaive_toss            = { 6, 1, 109215 }, -- Throw a glaive at your target and another nearby enemy within 10 yards for 7,750 to 8,750 damage, and reduce their movement speed by 70% for 3 sec.
    powershot              = { 6, 2, 109259 }, -- A powerful attack that deals 100% weapon damage to all targets in front of you, knocking them back.
    barrage                = { 6, 3, 120360 }, -- Rapidly fires a spray of shots for 3 sec, dealing 60% weapon damage to all enemies in front of you.
    
    -- Additional talents
    piercing_shots         = { 7, 1, 82924 }, -- Your critical strikes have a chance to apply Piercing Shots, dealing damage over time.
    lock_and_load          = { 7, 2, 56453 }, -- Your critical strikes have a chance to reset the cooldown on Aimed Shot.
    careful_aim            = { 7, 3, 82926 }, -- After killing a target, your next 2 shots deal increased damage.
} )

-- Enhanced Glyphs System (MoP Complete)
--[[ TODO: RegisterGlyphs function not implemented
spec:RegisterGlyphs( {
    -- Major Glyphs (affect gameplay mechanics)
    [109261] = "Glyph of Aimed Shot", -- Reduces the cast time of Aimed Shot by 0.2 sec
    [109262] = "Glyph of Animal Bond", -- Increases healing done to your pet by 20%
    [109263] = "Glyph of Arcane Shot", -- Arcane Shot reduces target's movement speed by 50% for 6 sec
    [109264] = "Glyph of Camouflage", -- Increases movement speed by 25% while Camouflage is active
    [109265] = "Glyph of Chimera Shot", -- Reduces focus cost of Chimera Shot by 10
    [109266] = "Glyph of Deterrence", -- Deterrence also reduces magic damage taken by 40%
    [109267] = "Glyph of Disengage", -- Increases the distance traveled by Disengage by 8 yards
    [109268] = "Glyph of Distracting Shot", -- Increases damage of Distracting Shot by 250%
    [109269] = "Glyph of Hunter's Mark", -- Hunter's Mark increases your pet's damage by 10%
    [109270] = "Glyph of Explosive Trap", -- Increases Explosive Trap damage by 20%
    [109271] = "Glyph of Freezing Trap", -- Reduces cooldown of Freezing Trap by 5 sec
    [109272] = "Glyph of Ice Trap", -- Increases area of Ice Trap by 100%
    [109273] = "Glyph of Kill Shot", -- Reduces cooldown of Kill Shot by 6 sec
    [109274] = "Glyph of Marked for Death", -- Hunter's Mark spreads to nearest enemy when target dies
    [109275] = "Glyph of Master's Call", -- Reduces cooldown of Master's Call by 20 sec
    [109276] = "Glyph of Mending", -- Increases healing done by Mend Pet by 25%
    [109277] = "Glyph of Misdirection", -- Reduces cooldown of Misdirection by 10 sec
    [109278] = "Glyph of Multi-Shot", -- Multi-Shot has no range limit
    [109279] = "Glyph of Pathfinding", -- Increases speed bonus of Aspect of the Cheetah by 20%
    [109280] = "Glyph of Scatter Shot", -- Increases range of Scatter Shot by 5 yards
    [109281] = "Glyph of Snake Trap", -- Snakes from Snake Trap reduce healing by 25%
    [109282] = "Glyph of Steady Shot", -- Increases Steady Shot damage by 10% when standing still
    [109283] = "Glyph of Tranquilizing Shot", -- Reduces cooldown of Tranquilizing Shot by 4 sec
    [109284] = "Glyph of Rapid Fire", -- Reduces focus cost of shots by 50% during Rapid Fire
    [109285] = "Glyph of Serpent Sting", -- Increases duration of Serpent Sting by 6 sec
    [109286] = "Glyph of Trueshot Aura", -- Trueshot Aura increases crit chance by 5%
    
    -- Minor Glyphs (cosmetic/convenience effects)
    [109287] = "Glyph of Aspect of the Cheetah", -- Aspect of the Cheetah appears as different animals
    [109288] = "Glyph of Aspect of the Hawk", -- Aspect of the Hawk has different visual effect
    [109289] = "Glyph of Fetch", -- Your pet can retrieve items from 50 yards away
    [109290] = "Glyph of Fireworks", -- Multi-Shot produces firework effects
    [109291] = "Glyph of Lesser Proportion", -- Your pet appears 25% smaller
    [109292] = "Glyph of Revive Pet", -- Reduces cast time of Revive Pet by 50%
    [109293] = "Glyph of Stampede", -- Animals from Stampede appear as different creatures
    [109294] = "Glyph of Tame Beast", -- Reduces cast time of Tame Beast by 50%
    [109295] = "Glyph of the Dire Stable", -- Allows storing 6 pets instead of 5
    [109296] = "Glyph of the Lean Pack", -- Aspect of the Pack appears sleeker
    [109297] = "Glyph of the Loud Horn", -- Horn of Winter creates louder sound
    [109298] = "Glyph of the Solstice", -- Track Humanoids shows different races
} )
--]]

-- Comprehensive Aura System for Marksmanship (40+ auras)
spec:RegisterAuras( {
    -- === MARKSMANSHIP SIGNATURE AURAS ===
    master_marksman = {
        id = 82899,
        duration = 30,
        max_stack = 5,
        generate = function( t )
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 82899 )
            if name then
                t.name = name
                t.count = count
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    aimed_shot_instant = {
        id = 82925,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name = UA_GetPlayerAuraBySpellID( 82925 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    careful_aim = {
        id = 82926,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.talent.careful_aim.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    piercing_shots = {
        id = 82924,
        duration = 8,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name = GetTargetDebuffByID( 82924 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    rapid_recuperation = {
        id = 53228,
        duration = 9,
        tick_time = 3,
        max_stack = 1,
    },
    
    lock_and_load = {
        id = 82914,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.talent.lock_and_load.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Fallback for lock_and_load if not properly registered
    lock_and_load_fallback = {
        id = 82914,
        duration = 3600,
        max_stack = 1,
        copy = "lock_and_load" -- This ensures both names work
    },
    
    steady_focus = {
        id = 82923,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name = UA_GetPlayerAuraBySpellID( 82923 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    improved_steady_shot = {
        id = 82927,
        duration = 12,
        max_stack = 1,
    },
    
    -- Focus regeneration tracking for Cobra Shot
    cobra_shot_regen = {
        id = 1, -- Virtual aura for focus regen tracking
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            -- This tracks Cobra Shot focus regeneration timing
            t.count = 1
            t.expires = query_time + 3600
            t.applied = 0
            t.caster = "player"
        end,
    },
    
    -- === TALENT-SPECIFIC AURAS ===
    thrill_of_the_hunt = {
        id = 34720,
        duration = 10,
        max_stack = 3,
    },
    
    lynx_rush = {
        id = 120697,
        duration = 4,
        max_stack = 1,
    },
    
    a_murder_of_crows = {
        id = 131894,
        duration = 30,
        tick_time = 1,
        max_stack = 1,
    },
    
    posthaste = {
        id = 118922,
        duration = 4,
        max_stack = 1,
    },
    
    dire_beast = {
        id = 120679,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name = UA_GetPlayerAuraBySpellID( 120679 )
            if name then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    fervor = {
        id = 82726,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    
    spirit_bond = {
        id = 117902,
        duration = 3600,
        tick_time = 10,
        max_stack = 1,
        generate = function( t )
            if state.talent.spirit_bond.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- === ASPECT AURAS ===
    aspect_of_the_hawk = {
        id = 13165,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_pack = {
        id = 13159,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_iron_hawk = {
        id = 109260,
        duration = 3600,
        max_stack = 1,
    },
    
    -- === DEFENSIVE AURAS ===
    deterrence = {
        id = 19263,
        duration = 5,
        max_stack = 1,
    },
    
    camouflage = {
        id = 51755,
        duration = 6,
        max_stack = 1,
    },
    
    feign_death = {
        id = 5384,
        duration = 6,
        max_stack = 1,
    },
    
    -- === UTILITY AURAS ===
    hunters_mark = {
        id = 1130,
        duration = 300,
        max_stack = 1,
    },
    
    misdirection = {
        id = 34477,
        duration = 8,
        max_stack = 1,
    },
    
    rapid_fire = {
        id = 3045,
        duration = 15,
        max_stack = 1,
    },
    
    -- Readiness not available in MoP - removed
    --[[
    readiness = {
        id = 23989,
        duration = 2,
        max_stack = 1,
    },
    --]]
    
    trueshot_aura = {
        id = 19506,
        duration = 3600,
        max_stack = 1,
    },
    
    -- === TARGET DEBUFFS ===
    serpent_sting = {
        id = 118253,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
    },

    explosive_trap = {
        id = 13813,
        duration = 10,
        max_stack = 1,
    },
    
    concussive_shot = {
        id = 5116,
        duration = 6,
        max_stack = 1,
    },
    
    -- explosive_shot aura removed - Survival-only ability in MoP
    
    wyvern_sting = {
        id = 19386,
        duration = 30,
        max_stack = 1,
    },
    
    scatter_shot = {
        id = 19503,
        duration = 4,
        max_stack = 1,
    },
    
    -- === PET AURAS ===
    mend_pet = {
        id = 136,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, _, count, _, duration, expires, caster = GetPetBuffByID( 136 )
            if name then
                t.name = name
                t.count = count
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- === TIER SET BONUSES ===
    tier14_4pc = {
        id = 123157,
        duration = 10,
        max_stack = 1,
    },

    tier15_2pc = {
        id = 138368,
        duration = 10,
        max_stack = 1,
    },

    tier15_4pc = {
        id = 138369,
        duration = 10,
        max_stack = 1,
    },

    tier16_2pc = {
        id = 144659,
        duration = 5,
        max_stack = 1,
    },

    tier16_4pc = {
        id = 144660,
        duration = 5,
        max_stack = 1,
    },
    
    call_pet = {
        duration = 3600,
        max_stack = 1,
    },
    
    blink_strikes = {
        id = 130392,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.talent.blink_strikes.enabled and state.pet.alive then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- === CONSUMABLE/EXTERNAL AURAS ===
    flask_of_spring_blossoms = {
        id = 105698,
        duration = 3600,
        max_stack = 1,
    },
    
    potion_of_the_tolvir = {
        id = 80496,
        duration = 25,
        max_stack = 1,
    },
    
    drums_of_rage = {
        id = 35476,
        duration = 30,
        max_stack = 1,
    },
    
    -- === GLYPH EFFECTS ===
    glyph_of_aimed_shot = {
        id = 109261,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.glyph.aimed_shot.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    glyph_of_chimera_shot = {
        id = 109265,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.glyph.chimera_shot.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    glyph_of_rapid_fire = {
        id = 109284,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.glyph.rapid_fire.enabled then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- === DEBUFFS ===
    -- Marksmanship: Wing Clip (Debuff version)
    wing_clip = {
        id = 2974,
        duration = 10,
        max_stack = 1
    },
    
    -- Marksmanship: Entrapment (Debuff version)
    entrapment = {
        id = 135373,
        duration = 4,
        mechanic = "root",
        max_stack = 1
    },

    -- === PET ABILITY AURAS ===
    -- Pet basic abilities
    pet_dash = {
        id = 61684,
        duration = 16,
        max_stack = 1,
        generate = function( t )
            if state.pet.alive then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "pet"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    pet_prowl = {
        id = 24450,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.pet.alive and state.pet.family == "cat" then
                t.count = 1
                t.expires = 0
                t.applied = 0
                t.caster = "pet"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Pet debuffs on targets
    growl = {
        id = 2649,
        duration = 3,
        max_stack = 1,
        type = "Taunt",
    },

    widow_venom = {
        id = 82654,
        duration = 12,
        max_stack = 1,
        debuff = true
    },
} )

-- Enhanced Pet System for Marksmanship
spec:RegisterPet( "tenacity", 1, "call_pet_1" )
spec:RegisterPet( "ferocity", 2, "call_pet_2" )
spec:RegisterPet( "cunning", 3, "call_pet_3" )
spec:RegisterPet( "spirit_beast", 4, "call_pet_4" )
spec:RegisterPet( "exotic", 5, "call_pet_5" )

-- Comprehensive Abilities System for Marksmanship (35+ abilities)
spec:RegisterAbilities( {
    -- === CORE MARKSMANSHIP SIGNATURE ABILITIES ===
    aimed_shot = {
        id = 19434,
        cast = function() 
            local base_cast = 2.4
            if buff.aimed_shot_instant.up or buff.master_marksman.stack == 5 then 
                return 0 
            end
            if glyph.aimed_shot.enabled then
                base_cast = base_cast - 0.2
            end
            if talent.focused_aim.enabled then
                base_cast = base_cast * 0.85 -- 15% faster cast with talent
            end
            return base_cast / haste 
        end,
        cooldown = 10,
        gcd = "spell",
        school = "physical",
        
        spend = function() 
            if buff.aimed_shot_instant.up or buff.master_marksman.stack == 5 then 
                return 0 
            else 
                local cost = 50
                if talent.focused_aim.enabled then
                    cost = cost - (talent.focused_aim.rank * 5) -- Reduces cost by 5/10/15
                end
                if talent.efficiency.enabled then
                    cost = cost - talent.efficiency.rank -- Reduces cost by 1/2/3
                end
                if glyph.rapid_fire.enabled and buff.rapid_fire.up then
                    cost = cost * 0.5 -- 50% cost reduction during Rapid Fire
                end
                return cost
            end
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Remove instant proc
            if buff.aimed_shot_instant.up then
                removeBuff( "aimed_shot_instant" )
            end
            if buff.master_marksman.stack == 5 then
                removeBuff( "master_marksman" )
            end
            
            -- Apply Piercing Shots if talented and crit
            if talent.piercing_shots.enabled and action.aimed_shot.lastCast and action.aimed_shot.lastCrit then
                applyDebuff( "target", "piercing_shots", 8 )
            end
            
            -- Careful Aim bonus damage for first 2 shots after kill
            if buff.careful_aim.up then
                -- Enhanced damage, tracked by combat log
            end
            
            -- Lock and Load chance to reset cooldown
            if talent.lock_and_load.enabled and math.random() <= (talent.lock_and_load.rank * 0.05) then
                setCooldown( "aimed_shot", 0 )
            end
        end,
    },
      
    chimera_shot = {
        id = 53209,
        cast = 0,
        cooldown = 9,
        gcd = "spell",
        school = "nature",
        
        spend = function()
            local cost = 35
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            if glyph.chimera_shot.enabled then
                cost = cost - 10
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Refresh Serpent Sting if present
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 9
                if debuff.serpent_sting.expires > query_time + 18 then
                    debuff.serpent_sting.expires = query_time + 18
                end
                -- Heal for 5% max health
                gain( 0.05 * health.max, "health" )
            end
            
            -- Master Marksman chance (passive in MoP)
            if math.random() <= 0.2 then
                addStack( "master_marksman" )
                if buff.master_marksman.stack == 5 then
                    removeBuff( "master_marksman" )
                    applyBuff( "aimed_shot_instant" )
                end
            end
        end,
    },
    
    -- === FOCUS BUILDERS ===
    steady_shot = {
        id = 56641,
        cast = function() return 2.0 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local regen = -14
            if talent.improved_steady_shot.enabled then
                regen = regen - (talent.improved_steady_shot.rank * 2) -- Additional 2/4/6 focus
            end
            if glyph.steady_shot.enabled and not moving then
                regen = regen - 2 -- Additional 2 focus when standing still
            end
            return regen
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Rapid Recuperation trigger
            if (buff.rapid_fire.up or buff.readiness.up) and talent.rapid_recuperation.enabled then
                applyBuff( "rapid_recuperation" )
            end
            
            -- Improved Steady Shot buff
            if talent.improved_steady_shot.enabled then
                applyBuff( "improved_steady_shot", 12 )
            end
            
            -- Steady Focus management
            if not buff.steady_focus.up then
                applyBuff( "steady_focus" )
            else
                buff.steady_focus.expires = query_time + 3600 -- Refresh
            end
            
            -- Master Marksman chance
            if math.random() <= 0.2 then
                addStack( "master_marksman" )
                if buff.master_marksman.stack == 5 then
                    removeBuff( "master_marksman" )
                    applyBuff( "aimed_shot_instant" )
                end
            end
            
            -- Careful Aim consumption
            if buff.careful_aim.up then
                if buff.careful_aim.stack == 1 then
                    removeBuff( "careful_aim" )
                else
                    removeStack( "careful_aim" )
                end
            end
        end,
    },
    
    cobra_shot = {
        id = 77767,
        cast = function () return 1.5 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        spend = -14,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Extend Serpent Sting duration
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                if debuff.serpent_sting.expires > query_time + 21 then
                    debuff.serpent_sting.expires = query_time + 21
                end
            end
            
            -- Careful Aim consumption
            if buff.careful_aim.up then
                if buff.careful_aim.stack == 1 then
                    removeBuff( "careful_aim" )
                else
                    removeStack( "careful_aim" )
                end
            end
        end,
    },
    
    -- === SHOT ROTATION ABILITIES ===
    arcane_shot = {
        id = 3044,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        
        spend = function()
            local cost = 30
            if talent.improved_arcane_shot.enabled then
                cost = cost - (talent.improved_arcane_shot.rank * 2) -- Reduces cost by 2/4/6
            end
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            if glyph.rapid_fire.enabled and buff.rapid_fire.up then
                cost = cost * 0.5
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Thrill of the Hunt proc chance
            if talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then
                gain( 20, "focus" )
                addStack( "thrill_of_the_hunt" )
            end
            
            -- Improved Arcane Shot damage bonus handled by talent system
        end,
    },
    
    multi_shot = {
        id = 2643,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local cost = 40 -- Standard MoP Multi-Shot cost
            if talent.improved_multi_shot.enabled then
                cost = cost - (talent.improved_multi_shot.rank * 5) -- Reduces cost by 5/10/15
            end
            if talent.scattered_shots.enabled then
                cost = cost - talent.scattered_shots.rank -- Reduces cost by 1/2/3
            end
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            if glyph.rapid_fire.enabled and buff.rapid_fire.up then
                cost = cost * 0.5
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            -- Thrill of the Hunt proc chance (30% chance in MoP)
            if talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then
                applyBuff( "thrill_of_the_hunt", 20 ) -- 20-second duration, not focus gain
            end
            
            -- Scattered Shots damage bonus per target (handled by talent system)
            -- Multi-Shot hits all enemies within 8 yards of target
        end,
    },
    
    kill_shot = {
        id = 53351,
        cast = 0,
        cooldown = function() 
            local cd = 10
            if glyph.kill_shot.enabled then
                cd = cd - 6 -- Reduces cooldown by 6 sec
            end
            return cd
        end,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local cost = 35
            if talent.efficiency.enabled then
                cost = cost - talent.efficiency.rank
            end
            return cost
        end,
        spendType = "focus",
        
        startsCombat = true,
        usable = function() return target.health_pct < 20, "target must be below 20% health" end,
        
        handler = function ()
            -- Significant damage to low health targets
        end,
    },
    
    -- Explosive Shot removed - This is a Survival-only ability in MoP Classic    
    -- === TALENT ABILITIES ===
    -- Tier 4 (Level 60) Talents
    a_murder_of_crows = {
        id = 131894,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "shadow",
        spend = 60,
        spendType = "focus",
        talent = "murder_of_crows",
        startsCombat = true,
        toggle = "cooldowns",
        handler = function ()
            applyDebuff( "target", "a_murder_of_crows", 30 )
            summonPet( "murder_of_crows", 30 )
        end,
    },
    
    lynx_rush = {
        id = 120697,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        school = "physical",
        talent = "lynx_rush",
        startsCombat = true,
        toggle = "cooldowns",
        usable = function() return pet.alive, "requires active pet" end,
        handler = function ()
            applyBuff( "lynx_rush" )
        end,
    },
    
    blink_strikes = {
        id = 130392,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",
        
        talent = "blink_strikes",
        startsCombat = false,
        
        handler = function ()
            if pet.alive then
                applyBuff( "blink_strikes" )
            end
        end,
    },
    
    -- Tier 5 (Level 75) Talents  
    fervor = {
        id = 82726,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        
        talent = "fervor",
        startsCombat = false,
        
        handler = function ()
            gain( 50, "focus" )
            applyBuff( "fervor", 10 ) -- HoT component
            if pet.alive then
                pet.focus = min( pet.focus + 50, pet.focus.max )
            end
        end,
    },
    
    dire_beast = {
        id = 120679,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "dire_beast",
        startsCombat = true,
        toggle = "cooldowns",
        handler = function ()
            applyBuff( "dire_beast", 15 )
            summonPet( "dire_beast_cat", 15 )
        end,
    },
    
    -- Tier 6 (Level 90) Talents
    glaive_toss = {
        id = 117050,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "physical",
        spend = 15,
        spendType = "focus",
        talent = "glaive_toss",
        startsCombat = true,
        toggle = "cooldowns",
        handler = function ()
            -- Hits primary target + 1 additional within 10 yards
        end,
    },
    
    powershot = {
        id = 109259,
        cast = 2,
        cooldown = 45,
        gcd = "spell",
        school = "physical",
        talent = "powershot",
        startsCombat = true,
        toggle = "cooldowns",
        usable = function() return active_enemies > 2, "more effective with multiple targets" end,
        handler = function ()
            -- AoE knockback effect
        end,
    },
    
    barrage = {
        id = 120360,
        cast = 3,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        spend = 60,
        spendType = "focus",
        talent = "barrage",
        startsCombat = true,
        toggle = "cooldowns",
        usable = function() return active_enemies > 3, "most effective with 4+ targets" end,
        handler = function ()
            -- Channel for 3 seconds, AoE damage
        end,
    },
    
    -- === UTILITY AND DEBUFF ABILITIES ===
    serpent_sting = {
        id = 118253,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        spend = 25,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            local duration = 15
            if glyph.serpent_sting.enabled then
                duration = duration + 6 -- Glyph increases duration by 6 sec
            end
            applyDebuff( "target", "serpent_sting", duration )
        end,
    },
    
    hunters_mark = {
        id = 1130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        
        startsCombat = false,
        
        handler = function ()
            applyDebuff( "target", "hunters_mark", 300 )
        end,
    },
    
    concussive_shot = {
        id = 5116,
        cast = 0,
        cooldown = 5,
        gcd = "spell",
        school = "nature",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff( "target", "concussive_shot", 6 )
            -- Improved Concussive Shot stun chance
            if talent.improved_concussive_shot.enabled and math.random() <= (talent.improved_concussive_shot.rank * 0.05) then
                applyDebuff( "target", "concussive_stun", 3 )
            end
        end,
    },
    
    -- === CROWD CONTROL ABILITIES ===
    silencing_shot = {
        id = 34490,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        school = "physical",
        talent = "silencing_shot",
        startsCombat = true,
        toggle = "interrupts",
        usable = function() return target.casting, "target must be casting" end,
        handler = function ()
            interrupt()
            applyDebuff( "target", "silencing_shot", 3 )
        end,
    },
    
    wyvern_sting = {
        id = 19386,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",
        talent = "wyvern_sting",
        startsCombat = true,
        toggle = "interrupts",
        handler = function ()
            applyDebuff( "target", "wyvern_sting", 30 )
        end,
    },
    
    binding_shot = {
        id = 109248,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",
        talent = "binding_shot",
        startsCombat = false,
        toggle = "interrupts",
        handler = function ()
            -- Tether effect not directly modeled
        end,
    },
    
    scatter_shot = {
        id = 19503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff( "target", "scatter_shot", 4 )
        end,
    },
    
    -- === DEFENSIVE ABILITIES ===
    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = function() 
            local cd = 180
            if talent.crouching_tiger.enabled then
                cd = cd - 10 -- Reduces cooldown by 10 sec
            end
            return cd
        end,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "defensives",
        handler = function ()
            applyBuff( "deterrence" )
        end,
    },
    
    disengage = {
        id = 781,
        cast = 0,
        cooldown = function() 
            local cd = 20
            if talent.crouching_tiger.enabled then
                cd = cd - 6 -- Reduces cooldown by 6 sec
            end
            return cd
        end,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            if talent.posthaste.enabled then 
                applyBuff( "posthaste", 4 ) 
            end
            if talent.narrow_escape.enabled then
                -- Web trap effect not directly modeled
            end
        end,
    },
    
    exhilaration = {
        id = 109304,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",
        
        talent = "exhilaration",
        startsCombat = false,
        
        toggle = "defensives",
        defensive = true,
        
        handler = function ()
            gain( 0.22 * health.max, "health" )
            if pet.alive then
                pet.health = min( pet.health + 0.22 * pet.health.max, pet.health.max )
            end
        end,
    },
    
    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "defensives",
        handler = function ()
            applyBuff( "feign_death" )
        end,
    },
    
    camouflage = {
        id = 51755,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff( "camouflage", 6 )
        end,
    },
    
    -- === MAJOR COOLDOWNS ===
    rapid_fire = {
        id = 3045,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff( "rapid_fire", 15 )
            if talent.rapid_recuperation.enabled then
                applyBuff( "rapid_recuperation", 9 )
            end
        end,
    },
    
    -- Readiness not available in MoP - removed
    --[[
    readiness = {
        id = 23989,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Reset all cooldowns except Readiness
            for k, v in pairs( cooldown ) do
                if k ~= "readiness" and v.remains > 0 then 
                    setCooldown( k, 0 ) 
                end
            end
            applyBuff( "readiness", 2 )
        end,
    },
    --]]
    
    trueshot_aura = {
        id = 19506,
        cast = 0,
        cooldown = 2,
        gcd = "spell",
        school = "physical",
        
        talent = "trueshot_aura",
        startsCombat = false,
        
        handler = function ()
            applyBuff( "trueshot_aura" )
        end,
    },
    
    -- === UTILITY ABILITIES ===
    misdirection = {
        id = 34477,
        cast = 0,
        cooldown = function()
            local cd = 30
            if glyph.misdirection.enabled then
                cd = cd - 10 -- Reduces cooldown by 10 sec
            end
            return cd
        end,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return pet.alive or group, "requires pet or group member" end,
        
        handler = function ()
            applyBuff( "misdirection", 8 )
        end,
    },
    
    -- === PET MANAGEMENT ===
    mend_pet = {
        id = 136,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "nature",
        
        spend = 35,
        spendType = "focus",
        
        startsCombat = false,
        
        usable = function() return pet.alive and pet.health_pct < 100, "pet must be alive and injured" end,
        
        handler = function ()
            applyBuff( "mend_pet", 10 )
        end,
    },
    
    call_pet_1 = {
        id = 883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
        handler = function ()
            summonPet( "tenacity" )
        end,
    },
    
    call_pet_2 = {
        id = 83242,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
        handler = function ()
            summonPet( "ferocity" )
        end,
    },
    
    call_pet_3 = {
        id = 83243,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
        handler = function ()
            summonPet( "cunning" )
        end,
    },
    
    revive_pet = {
        id = 982,
        cast = function() 
            local cast_time = 10
            if glyph.revive_pet.enabled then
                cast_time = cast_time * 0.5 -- 50% faster cast time
            end
            return cast_time
        end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        spend = 50,
        spendType = "focus",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "pet must be dead" end,
        
        handler = function ()
            summonPet( "ferocity" ) -- Default to last active pet type
        end,
    },
    
    dismiss_pet = {
        id = 2641,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return pet.alive, "requires active pet" end,
        
        handler = function ()
            dismissPet()
        end,
    },

    -- === BASIC PET ABILITIES ===
    pet_growl = {
        id = 2649,
        cast = 0,
        cooldown = 5,
        gcd = "off",
        school = "physical",

        startsCombat = true,

        usable = function() return pet.alive, "requires a living pet" end,

        handler = function ()
            -- Pet taunt - forces target to attack pet
            applyDebuff( "target", "growl", 3 )
        end,
    },

    pet_claw = {
        id = 16827,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        school = "physical",

        startsCombat = true,

        usable = function() return pet.alive and pet.family == "cat", "requires cat pet" end,

        handler = function ()
            -- Basic cat attack
        end,
    },

    pet_bite = {
        id = 17253,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        school = "physical",

        startsCombat = true,

        usable = function() return pet.alive and (pet.family == "wolf" or pet.family == "dog"), "requires wolf or dog pet" end,

        handler = function ()
            -- Basic canine attack
        end,
    },

    pet_dash = {
        id = 61684,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        usable = function() return pet.alive, "requires a living pet" end,

        handler = function ()
            applyBuff( "pet_dash", 16 )
        end,
    },

    pet_prowl = {
        id = 24450,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        usable = function() return pet.alive and pet.family == "cat", "requires cat pet" end,

        handler = function ()
            applyBuff( "pet_prowl" )
        end,
    },
    
    -- === TRAPS ===
    freezing_trap = {
        id = 1499,
        cast = 0,
        cooldown = function()
            local cd = 30
            if glyph.freezing_trap.enabled then
                cd = cd - 5 -- Reduces cooldown by 5 sec
            end
            return cd
        end,
        gcd = "spell",
        school = "frost",
        
        startsCombat = false,
        
        handler = function ()
            -- Trap placement not modeled in simulation
        end,
    },
    
    ice_trap = {
        id = 13809,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "frost",
        
        startsCombat = false,
        
        handler = function ()
            -- Area effect trap not modeled in simulation
        end,
    },
    
    explosive_trap = {
        id = 13813,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "fire",
        
        startsCombat = false,
        
        handler = function ()
            -- Damage trap not modeled in simulation
            -- Glyph increases damage by 20%
        end,
    },
    
    snake_trap = {
        id = 34600,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",
        
        startsCombat = false,
        
        handler = function ()
            -- Snake summon trap not modeled in simulation
        end,
    },    
    -- === ASPECTS ===
    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_cheetah" )
            removeBuff( "aspect_of_the_pack" )
            removeBuff( "aspect_of_the_iron_hawk" )
            applyBuff( "aspect_of_the_hawk" )
        end,
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_hawk" )
            removeBuff( "aspect_of_the_pack" )
            removeBuff( "aspect_of_the_iron_hawk" )
            applyBuff( "aspect_of_the_cheetah" )
        end,
    },
    
    aspect_of_the_pack = {
        id = 13159,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_hawk" )
            removeBuff( "aspect_of_the_cheetah" )
            removeBuff( "aspect_of_the_iron_hawk" )
            applyBuff( "aspect_of_the_pack" )
        end,
    },
    
    aspect_of_the_iron_hawk = {
        id = 109260,
        cast = 0,
        cooldown = 1,
        gcd = "spell",
        school = "physical",
        
        talent = "aspect_of_the_iron_hawk",
        startsCombat = false,
        
        handler = function ()
            removeBuff( "aspect_of_the_hawk" )
            removeBuff( "aspect_of_the_cheetah" )
            removeBuff( "aspect_of_the_pack" )
            applyBuff( "aspect_of_the_iron_hawk" )
        end,
    },
    
    -- === AUTO SHOT (PASSIVE) ===
    auto_shot = {
        id = 75,
        cast = 0,
        cooldown = function() return ranged_speed or 2.8 end,
        gcd = "off",
        school = "physical",
        
        startsCombat = true,
        
        handler = function ()
            -- Master Marksman proc chance (20% on all ranged attacks)
            if math.random() <= 0.2 then
                addStack( "master_marksman" )
                if buff.master_marksman.stack == 5 then
                    removeBuff( "master_marksman" )
                    applyBuff( "aimed_shot_instant" )
                end
            end
            
            -- Piercing Shots on crit
            if talent.piercing_shots.enabled and action.auto_shot.lastCrit then
                applyDebuff( "target", "piercing_shots", 8 )
            end
        end,
    },

    widow_venom = {
        id = 82654,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 15,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff( "target", "widow_venom" )
        end,
    },
} )

-- Enhanced State Expressions for Marksmanship optimization
spec:RegisterStateExpr( "current_focus", function()
    return focus.current or 0
end )

spec:RegisterStateExpr( "focus_deficit", function()
    return (focus.max or 100) - (focus.current or 0)
end )

spec:RegisterStateExpr( "focus_time_to_max", function()
    local regen_rate = 6 * haste
    if buff.aspect_of_the_iron_hawk.up then regen_rate = regen_rate * 1.3 end
    if buff.rapid_fire.up then regen_rate = regen_rate * 1.5 end
    if talent.improved_tracking.enabled then regen_rate = regen_rate * (1 + talent.improved_tracking.rank * 0.02) end
    
    return math.max( 0, ( (focus.max or 100) - (focus.current or 0) ) / regen_rate )
end )

spec:RegisterStateExpr( "master_marksman_ready", function()
    return buff.master_marksman.stack == 5 or buff.aimed_shot_instant.up
end )

spec:RegisterStateExpr( "aimed_shot_ready", function()
    return cooldown.aimed_shot.remains == 0 and ((focus.current or 0) >= 50 or master_marksman_ready)
end )

spec:RegisterStateExpr( "chimera_shot_ready", function()
    return cooldown.chimera_shot.remains == 0 and (focus.current or 0) >= 35
end )

spec:RegisterStateExpr( "serpent_sting_refreshable", function()
    return debuff.serpent_sting.remains < 4.5 or not debuff.serpent_sting.up
end )

spec:RegisterStateExpr( "steady_focus_active", function()
    return buff.steady_focus.up
end )

spec:RegisterStateExpr( "piercing_shots_ticking", function()
    return debuff.piercing_shots.up and debuff.piercing_shots.ticking
end )

spec:RegisterStateExpr( "careful_aim_available", function()
    return buff.careful_aim.up and buff.careful_aim.stack > 0
end )

spec:RegisterStateExpr( "rapid_fire_optimal", function()
    return not buff.rapid_fire.up and cooldown.rapid_fire.remains == 0 and (focus.current or 0) < 30
end )

spec:RegisterStateExpr( "focus_dump_ready", function()
    return (focus.current or 0) > 80 and not focus_time_to_max <= 3
end )

spec:RegisterStateExpr( "pet_focus_available", function()
    return pet.alive and pet.focus and pet.focus > 25
end )

spec:RegisterStateExpr( "thrill_proc_available", function()
    return talent.thrill_of_the_hunt.enabled and buff.thrill_of_the_hunt.stack > 0
end )

spec:RegisterStateExpr( "threat", function()
    -- Threat situation for misdirection logic
    return {
        situation = 0 -- Default to no threat situation
    }
end )

spec:RegisterStateExpr( "pet_alive", function()
    return pet.alive
end )

spec:RegisterStateExpr( "bloodlust", function()
    return buff.bloodlust
end )

-- === SHOT ROTATION STATE EXPRESSIONS ===

-- For Marksmanship, Steady Shot is primary focus generator with special buffs
spec:RegisterStateExpr( "should_steady_shot", function()
    -- Steady Shot is preferred for Marksmanship when:
    -- 1. We need to maintain Steady Focus buff
    -- 2. We need reliable focus generation
    -- 3. We can benefit from Improved Steady Shot
    
    if focus.current > 86 then return false end -- Don't cast if we'll cap focus
    
    -- High priority if Steady Focus is down or expiring soon
    if not buff.steady_focus.up or buff.steady_focus.remains < 3 then
        return true
    end
    
    -- Use for general focus generation
    return true
end )

-- Cobra Shot is secondary for MM, used mainly for Serpent Sting maintenance
spec:RegisterStateExpr( "should_cobra_shot", function()
    -- Cobra Shot for Marksmanship when:
    -- 1. Serpent Sting needs maintenance
    -- 2. Steady Shot isn't optimal
    
    if focus.current > 86 then return false end -- Don't cast if we'll cap focus
    
    -- Use for Serpent Sting maintenance
    if debuff.serpent_sting.up and debuff.serpent_sting.remains < 6 then
        return true
    end
    
    -- Otherwise prefer Steady Shot for MM
    return not should_steady_shot
end )

-- Focus management optimized for Aimed Shot usage
spec:RegisterStateExpr( "focus_spender_threshold", function()
    -- Marksmanship focus priorities:
    -- Aimed Shot: 50 focus (highest priority when proc'd)
    -- Chimera Shot: 35 focus
    -- Arcane Shot: 20 focus
    
    -- During Careful Aim, prioritize Aimed Shot
    if buff.careful_aim.up then return 60 end
    
    -- With Master Marksman, save focus for instant Aimed Shot
    if buff.master_marksman.stack >= 3 then return 70 end
    
    -- Normal threshold
    return 75
end )

-- Determines if we should use focus builders or wait for abilities
spec:RegisterStateExpr( "optimal_shot_window", function()
    -- Optimal windows for MM shot rotation:
    -- 1. When major abilities are on cooldown
    -- 2. When we have focus room
    -- 3. When building/maintaining buffs
    
    if focus.current < 30 then return false end
    
    -- Don't build focus if Aimed Shot is ready and we have proc
    if cooldown.aimed_shot.ready and (buff.master_marksman.stack >= 5 or buff.careful_aim.up) then
        return false
    end
    
    -- Don't build if Chimera Shot is ready and Serpent Sting is up
    if cooldown.chimera_shot.ready and debuff.serpent_sting.up then
        return false
    end
    
    return true
end )

-- Combat Log Event Tracking for Marksmanship mechanics
RegisterMMCombatLogEvent( "SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    -- Track successful casts for Master Marksman procs
    local ranged_abilities = {
        [19434] = true, -- Aimed Shot
        [56641] = true, -- Steady Shot
        [77767] = true, -- Cobra Shot
        [3044] = true,  -- Arcane Shot
        [2643] = true,  -- Multi-Shot
        [75] = true,    -- Auto Shot
    }
    
    if ranged_abilities[spellID] then
        -- 20% chance to generate Master Marksman stack
        if math.random() <= 0.2 then
            state.addStack( "master_marksman" )
            if state.buff.master_marksman.stack >= 5 then
                state.removeBuff( "master_marksman" )
                state.applyBuff( "aimed_shot_instant", 10 )
            end
        end
    end
    
    -- Track Steady Shot/Cobra Shot for Careful Aim
    if spellID == 56641 or spellID == 77767 then
        if state.buff.careful_aim.up then
            if state.buff.careful_aim.stack == 1 then
                state.removeBuff( "careful_aim" )
            else
                state.removeStack( "careful_aim" )
            end
        end
    end
end )

RegisterMMCombatLogEvent( "SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand)
    -- Track critical strikes for Piercing Shots
    local piercing_abilities = {
        [19434] = true, -- Aimed Shot
        [56641] = true, -- Steady Shot
        [75] = true,    -- Auto Shot
    }
    
    if critical and piercing_abilities[spellID] and state.talent.piercing_shots.enabled then
        state.applyDebuff( "target", "piercing_shots", 8 )
    end
    
    -- Track Lock and Load proc chances
    if spellID == 82924 and state.talent.lock_and_load.enabled then -- Piercing Shots damage
        if math.random() <= (state.talent.lock_and_load.rank * 0.05) then
            state.setCooldown( "aimed_shot", 0 )
        end
    end
end )

RegisterMMCombatLogEvent( "UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    if destGUID == UnitGUID("target") then
        -- Apply Careful Aim buff for next 2 shots
        if state.talent.careful_aim.enabled then
            state.applyBuff( "careful_aim", 3600, 2 )
        end
        
        -- Reset Murder of Crows cooldown if target dies while under effect
        if state.debuff.a_murder_of_crows.up then
            state.setCooldown( "a_murder_of_crows", 0 )
        end
    end
end )

RegisterMMCombatLogEvent( "SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType)
    -- Track Thrill of the Hunt procs
    if spellID == 34720 and destGUID == UnitGUID("player") then
        state.addStack( "thrill_of_the_hunt" )
    end
    
    -- Track Dire Beast focus generation
    if spellID == 120679 and destGUID == UnitGUID("player") then
        state.applyBuff( "dire_beast", 15 )    end
end )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = false,
    nameplateRange = 40,
    rangeFilter = false,

    damage = true,
    damageExpiration = 3,

    potion = "virmen_bite", -- MoP potion
    package = "Marksmanship",
} )

spec:RegisterSetting( "pet_healing", 0, {
    name = strformat( "%s Below Health %%", Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
    desc = strformat( "If set above zero, %s may be recommended when your pet falls below this health percentage. Setting to |cFFFFd1000|r disables this feature.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
    icon = 132179,
    iconCoords = { 0.1, 0.9, 0.1, 0.9 },
    type = "range",
    min = 0,
    max = 100,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "mark_boss_only", true, {
    name = strformat( "%s Bosses Only", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    desc = strformat( "If checked, %s will be recommended for boss targets only.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

-- Register default pack for MoP Marksmanship Hunter
spec:RegisterPack( "Marksmanship", 20250705, [[Hekili:vZXAVnUXXFlgbvXoxov9(8fylGMMuKC4sqa01VkkkQvwSwIuLK685cd9BVZUlj3xZSK02OxkkAsm1UZ7x7ml5YHl)0YfBclyl)9rdgnDW7gmT)Gbthn66LlkE8iB5IJHr3hEh8FKeEa(N)wy295hctY3fFK)JpUpnCdhi5PNYIGfSCX6tX7l(1KLRrH8W3dR9ilcE80jlxSlEZgMCTS8OLl(0U48ZR4))WZRkX95vPBH)oQion58Q9X5fWpVnn78QFHDF8(4(lxiEiNmyFHfDcq6Nw(7cEJLeUEpBZYFC5cjawUa2Y(G8DPfsCMfFu(8FwUvaT7cZH)1LfHz3XkoVAnBF6dNxnAWF58QDSW9f7UA5cyFfSS4qqojwwF5VeCmc2Xn3Yx(5v940z0jGCNdpzYGLfaBBrwTfqRpTDB)dH5WIdouQf6F6OIVcJpW2izmanJFMOzdtGOCw2rwsrqErCYDaAS5LXduioAhG5SWAup5zIAdrLINl2LX1yPBdk2Xc2DkPWKTZIcty1iF6ld58NmvJ3aXD4MhRGoyYSpn6(GWKnbLg(KMzSVCCFAE8Nzy2AFeGcysNS58QpcWbS5YsJoVcuPG9(bqWBs47HN03eG9lrPsozqzCrKxJn0Tia2fNx5fJewCajFKveOXcEeos748GOW97Ten)b3L7ub4xx8yPicxSuzPcoNmjX)0t12VzPPfSMLcLmACsr8HyiAfqbgc2sBMOqHFG(JGnWcksd2edHkMdgnkMthA(DfbrniZ6hUhKXcGhLEyDyHMRfiFc4I1H(DSmHIuceEmEtW24mMH7YAgWkH7dEilSyNuTj5OG8hIlI25tRX994AnE4ha7pgThebInNZ3KRUrFd93K(qIpjipKIHLWNkJ)kjmH8xyoCmlontyDiHe8lyA5Axy9qzwsFFr7iiZHY4fCOdogSe2HywzGJjicfe9pACted7UqutXrnTfJn9lcQBhgwps4Ht7lI1C2dt9MLvB5MA1)w6pRRcd38VoLxW9TZFoKxB8U9e4KgnkJdRTR7mzfJVH0UcIzDywgemRrQyQnZottxucKMs2kq4D7d5aVinpVrKoYgPd1cRPbOMs0kq8riUCwRK4tqQuQgT1GHJ0zDYEEcPMSaIosOj5)ehvVZFQt0QsOfSK1RC9FsJAXJifMX2EAFaKM3NNUwvaME6)D5(pV6VfFaQH)ipR4)rKvekUofiDriDr12x5iF1qUfRPxahWzV3P4Xznew4LaF)1h6X9NcPTtD6qtugksfxAglilTqwbIhvNLrMP2daY5vvqPoKny20wRrE5yxs87zSdHXjvwG9N6Z296ZRUYVg1Ne8sEvvP75vF0xpJlqcGMtsLUfmXrj5bCAmiVNmopZ8k0H5FjwZ25vmpc5l8Ou2bYvN72BG8sPZXywweOgf7iVIPW)rdJjTqTMlZFqD60HOXmBDLsob4BDEeQFoViKF4rrPkKPvEVFSwg2sWaQcZjuCwX4goOdW2q1mwXxgls303gz2HUuit3gEwLRoMNm3dxDO2nWJdwZGt0P8l5ROoiH2cQP(5IcYUIuCpKo2KHRwtKjvKkfzm2KmSob(wWyHL5nKVM81UNep82sIvcgQy(gPcRcQHQvBonmTXYOUBSqhx2OZv6rsiYkn3W3kkDDRAVLBdSU0xpSKQCSKEC(NxXgTbhDSzx7nsmmL2qA9PSCVDWrz8Azg9J8Dw3ev9Q(SQBaZhWjOABoFxyWHtzByzCXBuw6d5U9gJOzio7Svz33)yYxcYoLVZapTVfm17Vfj2DB4BJGVTjX9v0Kp4BxneDQ8M1W6PzSSWB48xUGLodEBYtlIgULLWR6YND)ggqfzSKiB7(FQA3uHnJtIspWRgzt4b4W7btLXzKfrbk6VCE13DE1G(t8B0BdMXeGzMIM3YIVljydt2XVMhnWMyOgdGdLHjU2ieFiF4nf1rYcF4ETtYGSI4S0KQLPPRnwZH0K7zp63BW09I)xqmvGJaAKZTxxgPl5EXjzQvXX5805Y)sMHKBl0YUutNR8FiTOuGHosNeHvbFf6N5w9Y6gvS6))itQj7iYLuEeUgtRoP7PvBOoznHOE4e3neiJqiTdaVZSG1PjNYz5(Sbi7UXNI5viLZBqDzxP5tWHYkawNeB95iE4KGjhJ0QYV(ziXiBQDgwGEAWihqlEM1zOSJ7thGN2yWb1UC1ucUYtKFAlbl8ndHvNPZQOPeisa4jtPdADzZz6Sj(rSOC2KzEcbAbZo0WM73a3OQHeP3e98hbqEqtGEc8nR4lHLt1VaM7baBDixhji64Q1Fm12sM6OluvzY7VG8UdSjlKLehfeENy4EyQ6Atq1CVSgspyzEhK99rroaZiWc3WYjhAvRzD2d)kA3KmgT4W58oevibKZgo17V6ON1SfJsfJuRfvjvwSAEm8VQBcYlF4MMWBP3gC8QKZ2PvgMtlolgQngSg(P)yHQBLwgsY)iGFjrKxvKaPbz1PTfL970wJwbcR6Z1lSaR7fTcMMTV1F3fWIWnUL4Hpbpo0jNpPVnx2Pbr4RJG2so4AFjsDkC0sv(lcl7F48k97y05v8)3FKXEBvupiympKJmNRziGLihW0t1OT6SLeBVApeSx9c9N)0iYewWVQqKv)K5e4nIGthvJUh9AU1ytrOY7WxBaGmzXjS8CNPhi3Sh1tRo9EDdX0c1Qxoztfhr3NHlToxO2KaS7MUwBy0A7HxnBxZsoYOFRHhoY20UX76x85PvJ05Rn77ewlsAC2VTPfjpdABOztynAKIVeTKn(vZoaoF824O4cv)7AXKHuWSvjJ3YY(CAMb6nAMQcWYv6p9A1nkiozJV87QtZpV(08EUgjvuGoyXsd7qhKxIkt1o5aQvO26cuv4nn7Z5SB)MaCQmnU3)UYlyQ44CHYryZ5MfaSGAmZf3iwlVDFTQZ(3SMyvZNU)f3hWgcvraF6MttHNNx)mDBA9fOXIPWkDaPgLEDy0PeyNBFM(5MTgnQqiAhJveUZ2WSeoEpmtvLq9O65wjSBrnoibigoTcYLfneLMakh8bvB9B(n0W7UOEW0CwYDnEVMQK140Tw80R9CpEbD2dHz8BGso)sNdWi(WX0Sk)(VT8EK)TWzky)7tGRfOnYtpaRJF26dHf8heTlm5owE)ZF4JqnqajafV(ptYpDKdj(cKyhax9SV)26fpICXkJl1QhtUA9U1Wx)5pGWogx03xlMY8wk0DodLsLgjLxg1UrPVqzeCCOUHpA(0vYGIrTqpDdZ06etjSaNBt3Vp9bXj8dpLfcohpW4xTNt58DYBOubFzvGGFgpEuLIQ1LKki4tjgREZg(IHC0HRdZz)aWHRElqOkoIIN1pCB34AA5TT(Tj7bkl3jTuUkx90U4UpJCXM3sf1og2w)OVYAz(tm5HYhQ3bucRbzxe6MzaTy)RSyPf8RyS6DJDFTSjBvmW6rG2nAK2tdBqFKy3E2CTLi(ZOMwF(sTLp6wW9Ugu8RTuI)iTX2y8GjIhqyrYhns3eH0bB17FUsi(oY1B2UB6m5v9kRB0jTQUUVATjDwvdJ(QOLBoLp9H3FTKwDZXOB1xJT6xRyYFLtyzP6(1dve4W3zIbUoyjFQI7sZwUyXHtBZIVN33)uiboB5IV58k6U3)HVP1nW)8hKynVF9ifEZT)v3jh89XBV9IgAVFBGv965aSDD8hhSQw2linvhVqxTEx8XxHr74fGK62A9bH81)GHRXbxaunAy9hwpvy9hkh973Zh3ZTwJULtrUTE6PNCBx0n3oBqjn22r3QtdnkxH1unTv(kQxqpZH3EZ0b9UaPxU6OslZG0CqF6O9CzT5t13UzIcn7j8bW2RJGxFOOUmQCSQ3mO)19khNAPmhF8Oosy5FkgYNuFxNpR5LshDV59ACyWMxoCcDoVZFUAMNZVDCZ7S8cnlfkyZMs5gwZ6aWQZclS(AAIl98mSQ5C3auuuVuvqndB0ExkkGA(Tth80tiDS8kC4wvtqxCvhrqJoCSE4ssPXLTfTZgqWd1Z3rdFotwQNYvO1yC4ucmQMNJgkDhCuPoPAKrZVDsLUXa5eiroBhneyowOEcyFdOVX3U(Gz0ac2yG6z1Y153EnwKMHtXXK(Cy0We2GE00cyiyqDEQx(Gxu0kDOhUrBDTv1UaUJbONVPZaoeV(4cp)ZRb4rn0h8QIIYirZQsMAn7KxtuHa)EoZLz(7huhtN6Tvu30wlBtxkY6PNU039A9MBN0FkMz)1xrJC9tNZXnbQ7DPNxEXgJ5yIsZUEQ5qJ)6k27cQxurAuGOBBHouzxrd56wQQvBMw9DqURkOmXdum7tPMC351nSN3x1qJqd2irDTsXQwzupZNawp9QZW7rYQUJS1Iw07eDpQFs8EdQxTKRdHAiz14i3(AS2gXCJaQwmoUN7p61aZumuz4mdp3)fKzWF6jpVVFZN6XlY0exfreLa8((8nF8vLrVO)MyOOdO43gTTgJzjj3yxD(DbDlchirv5xNc9Atm)Ox4a8PyraKat7RoHgar(Ow4a0rvavV8gjqR)MsObsNpxfoaCcMPVT0L)5Jat1mbr(v(vOWgyT3v3HLTbLzkoJpZd3o0xkp8Q4CdDvvxh69wqRGGYF)n2DGP8Qkiifz7l6H1yh1nAafMwxdbTueQkFhoTwd4EJgqHA99rabE3C71O7XkYNZDvqqhLf4FDvXlOV6ykWxpugonv)6NXbV7Ru2C17b23nO)eCGO9(GHbLXwqzgouWgTdUKcvLw2Mo0FdVpE6i)52peFFCXuy6OXhYmo6efOk)ELPxTw13ESNEY(7oMhG1LJv1L2e5IjQ2N1RStH0704ZeMPag7ymcHBdVuCkSzpNpx)g5k0ElZMpUYRP(WhK1m0m49uqYOgkibb4Q3JnushofgC8aFhGy(eVWN8nzRHSdLcSjvHz6W3tnf9yCFCEJzVRXsOuYNoF53WmDhpGgp)piZffQnoAgnl2kepLgnDOuoP6RXx4qnCPn9zNAwXExelp1G(7HiwnzwW1(qSyVkIAqU61qe3zq3lZM(nRic71o0anMmWeAgWuhG96fQb3QxTqFLDzbFR4oyViHgiOKWXp5vPDa9hybfziUNjVPnDxg5advB(512xS0d2qURn2TnWSdTvQbi12wZ0gyHvlpQcycIcW06ezVogIobn8(rDrlRJ43iYdZBfDJ5CjaWljtBfirYVcXhh4pL6yeaH38GjvNDhnlkXae0hzHc(eTgaFeevJfTdF2Pv4S8(j)MNBJXu73KOXbaH3eg4SDEWbiLlvTYfLsnvFnWRK9bdNUTSB9a8BuExD5lCOcPADefpU1ZTLPgWfZrS1a2A6tMa2UT5yGUPQZW6HFJFuSvuKX9z)nDV7wcAZ5RFnj4r0r2BU3fEXO4voy5)9]] )

end

-- Deferred loading mechanism - try to register immediately or wait for ADDON_LOADED
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterMarksmanshipSpec()
        return true
    end
    return false
end

-- Try to register immediately, or wait for addon loaded
if not TryRegister() then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end



-- Enhanced Pet System for Marksmanship

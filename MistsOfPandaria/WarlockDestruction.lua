-- WarlockDestruction.lua
-- Updated May 30, 2025 - Enhanced Structure (Advanced Combat Log + Comprehensive Systems)
-- Mists of Pandaria module for Warlock: Destruction spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'WARLOCK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 267 ) -- Destruction spec ID for MoP

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

-- Advanced Combat Log Event Tracking for Destruction Warlock
local destructionCombatLogFrame = CreateFrame("Frame")
local destructionCombatLogEvents = {}

-- Burning Ember generation tracking
local function RegisterDestructionCombatLogEvent(event, handler)
    if not destructionCombatLogEvents[event] then
        destructionCombatLogEvents[event] = {}
        destructionCombatLogFrame:RegisterEvent(event)
    end
    table.insert(destructionCombatLogEvents[event], handler)
end

-- Combat log event handlers for Destruction mechanics
local function HandleDestructionCombatLogEvent(self, event, ...)
    local handlers = destructionCombatLogEvents[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(...)
        end
    end
end

destructionCombatLogFrame:SetScript("OnEvent", HandleDestructionCombatLogEvent)

-- Pet management system for Destruction Warlock
local function summon_demon(demon_type)
    -- Track which demon is active
    if demon_type == "imp" then
        applyBuff("grimoire_of_sacrifice_imp")
    elseif demon_type == "voidwalker" then
        applyBuff("grimoire_of_sacrifice_voidwalker")
    elseif demon_type == "succubus" then
        applyBuff("grimoire_of_sacrifice_succubus")
    elseif demon_type == "felhunter" then
        applyBuff("grimoire_of_sacrifice_felhunter")
    elseif demon_type == "felguard" then
        applyBuff("grimoire_of_sacrifice_felguard")
    end
end

-- Pet stat tracking for Destruction
local function update_pet_stats()
    local pet_health = UnitHealth("pet") or 0
    local pet_max_health = UnitHealthMax("pet") or 1
    local pet_health_pct = pet_health / pet_max_health
    
    -- Update pet health state for Dark Pact calculations
    if state then
        state.pet_health_pct = pet_health_pct
    end
end

-- Burning Ember generation from Immolate/Conflagrate ticks
RegisterDestructionCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing)
    if sourceGUID == UnitGUID("player") then
        if spellId == 348 then -- Immolate DoT tick
            -- Generate 0.1 Burning Ember per tick with chance for bonus
            local emberGenerated = 0.1
            if critical then emberGenerated = emberGenerated + 0.1 end -- Critical ticks generate more
            
            if state and state.burning_embers then
                state.burning_embers.generate(emberGenerated)
            end
        end
    end
end)

-- Backlash proc tracking from damage taken
RegisterDestructionCombatLogEvent("SPELL_DAMAGE", function(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing)
    if destGUID == UnitGUID("player") and amount > 0 then
        -- 25% chance for Backlash proc when taking damage
        if math.random(100) <= 25 then
            -- Set Backlash buff (reduces cast time of next Incinerate/Chaos Bolt by 30%)
            if state and state.buff then
                state.buff.backlash.applied = GetTime()
                state.buff.backlash.expires = GetTime() + 8
                state.buff.backlash.count = 1
            end
        end
    end
end)

-- Conflagrate usage and Backdraft proc tracking
RegisterDestructionCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool)
    if sourceGUID == UnitGUID("player") then
        if spellId == 17962 then -- Conflagrate
            -- Generate 2 Backdraft charges (reduces Incinerate cast time by 30%)
            if state and state.buff then
                state.buff.backdraft.applied = GetTime()
                state.buff.backdraft.expires = GetTime() + 15
                state.buff.backdraft.count = 2
            end
            
            -- Generate 0.2 Burning Ember
            if state and state.burning_embers then
                state.burning_embers.generate(0.2)
            end
        elseif spellId == 116858 then -- Chaos Bolt
            -- Generate 0.1-0.2 Burning Ember based on target's burning effects
            local emberGenerated = 0.1
            if state.debuff.immolate.up then emberGenerated = emberGenerated + 0.05 end
            if state.debuff.shadowburn.up then emberGenerated = emberGenerated + 0.05 end
            
            if state and state.burning_embers then
                state.burning_embers.generate(emberGenerated)
            end
        end
    end
end)

-- Dark Soul: Instability usage tracking
RegisterDestructionCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, auraType)
    if destGUID == UnitGUID("player") then
        if spellId == 113858 then -- Dark Soul: Instability
            -- Enhance Burning Ember generation by 100% for 20 seconds
            if state and state.buff then
                state.buff.dark_soul_instability.applied = GetTime()
                state.buff.dark_soul_instability.expires = GetTime() + 20
                state.buff.dark_soul_instability.count = 1
            end
        end
    end
end)

-- Enhanced Resource Management Systems
spec:RegisterResource( 0, {
    -- Life Tap mana restoration (Warlock signature mechanic)
    life_tap = {
        last = function ()
            return state.last_cast_time.life_tap or 0
        end,
        interval = 1.5, -- Life Tap GCD
        value = function()
            -- Life Tap converts health to mana (30% max mana in MoP)
            return (state.last_ability and state.last_ability == "life_tap") and state.mana.max * 0.30 or 0
        end,
    },
    
    -- Dark Pact mana return (from demon health)
    dark_pact = {
        last = function ()
            return state.last_cast_time.dark_pact or 0
        end,
        interval = 1.5, -- Dark Pact GCD
        value = function()
            -- Dark Pact converts demon health to mana
            return (state.last_ability and state.last_ability == "dark_pact") and state.mana.max * 0.25 or 0
        end,
    },
}, {
    -- Base mana regeneration for Destruction
    base_regen = function ()
        local base = state.mana.max * 0.01 -- 1% base (Warlocks have low base regen)
        local spirit_bonus = (state.stat.spirit or 0) * 0.4 -- Spirit is less effective for Warlocks
        
        -- Fel Armor bonus to mana regeneration
        if state.buff.fel_armor.up then
            base = base * 1.20 -- 20% bonus
        end
        
        return (base + spirit_bonus) / 5 -- Convert to per-second
    end,
    
    -- Improved Life Tap talent bonus
    improved_life_tap = function ()
        return state.talent.improved_life_tap.enabled and 0.2 or 0 -- 20% spell power as mana efficiency
    end,
} )

spec:RegisterResource( 14, {
    -- Burning Ember generation from Immolate ticks
    immolate_generation = {
        last = function ()
            return state.last_immolate_tick or 0
        end,
        interval = 2, -- Immolate tick interval
        value = function()
            -- Immolate generates 0.1 Burning Ember per tick
            local embers_generated = 0.1
            if state.debuff.immolate.up then
                -- Critical ticks generate more embers
                if state.last_critical_tick then
                    embers_generated = embers_generated + 0.1
                end
                return embers_generated
            end
            return 0
        end,
    },
    
    -- Conflagrate Burning Ember generation
    conflagrate_generation = {
        last = function ()
            return state.last_cast_time.conflagrate or 0
        end,
        interval = 1,
        value = function()
            -- Conflagrate generates 0.2 Burning Embers
            return (state.last_ability and state.last_ability == "conflagrate") and 0.2 or 0
        end,
    },
    
    -- Incinerate Burning Ember generation
    incinerate_generation = {
        last = function ()
            return state.last_cast_time.incinerate or 0
        end,
        interval = 1,
        value = function()
            -- Incinerate generates 0.1 Burning Ember per cast
            return (state.last_ability and state.last_ability == "incinerate") and 0.1 or 0
        end,
    },
    
    -- Chaos Bolt Burning Ember consumption
    chaos_bolt_consumption = {
        last = function ()
            return state.last_cast_time.chaos_bolt or 0
        end,
        interval = 1,
        value = function()
            -- Chaos Bolt consumes 4 Burning Embers
            return (state.last_ability and state.last_ability == "chaos_bolt") and -4 or 0
        end,
    },
    
    -- Ember Tap Burning Ember consumption
    ember_tap_consumption = {
        last = function ()
            return state.last_cast_time.ember_tap or 0
        end,
        interval = 1,
        value = function()
            -- Ember Tap consumes 1 Burning Ember
            return (state.last_ability and state.last_ability == "ember_tap") and -1 or 0
        end,
    },
}, {
    -- Burning Ember generation modifiers
    backlash_bonus = function ()
        return state.buff.backlash.up and 0.1 or 0 -- 10% bonus from Backlash
    end,
    
    backdraft_bonus = function ()
        return state.buff.backdraft.up and 0.15 or 0 -- 15% bonus from Backdraft
    end,
    
    molten_core_bonus = function ()
        return state.talent.molten_core.enabled and 0.2 or 0 -- 20% bonus from Molten Core
    end,
} )

-- Comprehensive Tier Set and Gear Registration
-- T14 - Curse of the Elements (Raid Finder/Normal/Heroic)
spec:RegisterGear( "tier14_lfr", 89281, 89282, 89283, 89284, 89285 ) -- T14 LFR Warlock Set
spec:RegisterGear( "tier14", 85373, 85374, 85375, 85376, 85377 ) -- T14 Normal Warlock Set
spec:RegisterGear( "tier14_heroic", 86681, 86682, 86683, 86684, 86685 ) -- T14 Heroic Warlock Set

-- T15 - Vestments of the Shattered Fellow (Raid Finder/Normal/Heroic)
spec:RegisterGear( "tier15_lfr", 95298, 95299, 95300, 95301, 95302 ) -- T15 LFR Warlock Set
spec:RegisterGear( "tier15", 95814, 95815, 95816, 95817, 95818 ) -- T15 Normal Warlock Set
spec:RegisterGear( "tier15_heroic", 96229, 96230, 96231, 96232, 96233 ) -- T15 Heroic Warlock Set

-- T16 - Regalia of the Horned Nightmare (Raid Finder/Normal/Heroic/Mythic)
spec:RegisterGear( "tier16_lfr", 99384, 99385, 99386, 99387, 99388 ) -- T16 LFR Warlock Set
spec:RegisterGear( "tier16", 99798, 99799, 99800, 99801, 99802 ) -- T16 Normal Warlock Set
spec:RegisterGear( "tier16_heroic", 100212, 100213, 100214, 100215, 100216 ) -- T16 Heroic Warlock Set
spec:RegisterGear( "tier16_mythic", 100626, 100627, 100628, 100629, 100630 ) -- T16 Mythic Warlock Set (Upgraded)

-- Legendary Items
spec:RegisterGear( "legendary_cloak", 102246 ) -- Xing-Ho, Breath of Yu'lon (Caster DPS Legendary Cloak)
spec:RegisterGear( "legendary_cloak_upgraded", 102247 ) -- Upgraded legendary cloak
spec:RegisterGear( "legendary_meta_gem", 76885 ) -- Burning Prism (Destruction Warlock Meta)

-- Notable Trinkets for Destruction
spec:RegisterGear( "unerring_vision", 102293 ) -- Unerring Vision of Lei-Shen (SoO)
spec:RegisterGear( "kardris_toxic", 102298 ) -- Kardris' Toxic Totem (SoO)
spec:RegisterGear( "purified_bindings", 102299 ) -- Purified Bindings of Immerseus (SoO)
spec:RegisterGear( "thoks_tail_tip", 102302 ) -- Thok's Tail Tip (SoO)
spec:RegisterGear( "black_blood", 102304 ) -- Black Blood of Y'Shaarj (SoO)
spec:RegisterGear( "wushoolays_final", 102305 ) -- Wushoolay's Final Choice (SoO)

-- PvP Sets (Elite/Gladiator variants)
spec:RegisterGear( "pvp_s14_elite", 91453, 91454, 91455, 91456, 91457 ) -- Season 14 Elite Warlock Set
spec:RegisterGear( "pvp_s14_gladiator", 91458, 91459, 91460, 91461, 91462 ) -- Season 14 Gladiator Warlock Set
spec:RegisterGear( "pvp_s15_elite", 95453, 95454, 95455, 95456, 95457 ) -- Season 15 Elite Warlock Set

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 90545, 90546, 90547, 90548, 90549 ) -- Challenge Mode Warlock Set

-- Associated Auras for Tier Sets
spec:RegisterAura( "tier14_2pc_destruction", {
    id = 123456, -- Placeholder for 2-piece bonus
    duration = 15,
} )

spec:RegisterAura( "tier14_4pc_destruction", {
    id = 123457, -- Placeholder for 4-piece bonus
    duration = 10,
} )

spec:RegisterAura( "tier15_2pc_destruction", {
    id = 138131, -- Your Conflagrate has a 25% chance to not consume the Immolate effect
    duration = 15,
} )

spec:RegisterAura( "tier15_4pc_destruction", {
    id = 138132, -- When you deal damage with Chaos Bolt, gain 15% spell haste for 8 sec
    duration = 8,
} )

spec:RegisterAura( "tier16_2pc_destruction", {
    id = 144956, -- Your Immolate and Shadowburn have a 40% chance to generate 1 Burning Ember
    duration = 15,
} )

spec:RegisterAura( "tier16_4pc_destruction", {
    id = 144957, -- Your Conflagrate increases the damage of your next 2 Chaos Bolts by 25%
    duration = 20,
    max_stack = 2,
} )

-- Talents (MoP talent system - ID, enabled, spell_id)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Crowd Control/Utility
    dark_regeneration         = { 1, 1, 108359 }, -- Instantly restores 30% of your maximum health. Restores an additional 6% of your maximum health for each of your damage over time effects on hostile targets within 20 yards. 2 min cooldown.
    soul_leech                = { 1, 2, 108366 }, -- When you deal damage with Malefic Grasp, Drain Soul, Shadow Bolt, Touch of Chaos, Chaos Bolt, Incinerate, Fel Flame, Haunt, or Soul Fire, you create a shield that absorbs (45% of Spell power) damage for 15 sec.
    harvest_life              = { 1, 3, 108371 }, -- Drains the health from up to 3 nearby enemies within 20 yards, causing Shadow damage and gaining 2% of maximum health per enemy every 1 sec.

    -- Tier 2 (Level 30) - Mobility/Survivability
    howl_of_terror            = { 2, 1, 5484   }, -- Causes all nearby enemies within 10 yards to flee in terror for 8 sec. Targets are disoriented for 3 sec. 40 sec cooldown.
    mortal_coil               = { 2, 2, 6789   }, -- Horrifies an enemy target, causing it to flee in fear for 3 sec. The caster restores 11% of maximum health when the effect successfully horrifies an enemy. 30 sec cooldown.
    shadowfury                = { 2, 3, 30283  }, -- Stuns all enemies within 8 yards for 3 sec. 30 sec cooldown.

    -- Tier 3 (Level 45) - DPS Cooldowns
    soul_link                 = { 3, 1, 108415 }, -- 20% of all damage taken by the Warlock is redirected to your demon pet instead. While active, both your demon and you will regenerate 3% of maximum health each second. Lasts as long as your demon is active.
    sacrificial_pact          = { 3, 2, 108416 }, -- Sacrifice your summoned demon to prevent 300% of your maximum health in damage divided among all party and raid members within 40 yards. Lasts 8 sec.
    dark_bargain              = { 3, 3, 110913 }, -- Prevents all damage for 8 sec. When the shield expires, 50% of the total amount of damage prevented is dealt to the caster over 8 sec. 3 min cooldown.

    -- Tier 4 (Level 60) - Pet Enhancement
    blood_fear                = { 4, 1, 111397 }, -- When you use Healthstone, enemies within 15 yards are horrified for 4 sec. 45 sec cooldown.
    burning_rush              = { 4, 2, 111400 }, -- Increases your movement speed by 50%, but also deals damage to you equal to 4% of your maximum health every 1 sec.
    unbound_will              = { 4, 3, 108482 }, -- Removes all Magic, Curse, Poison, and Disease effects and makes you immune to controlling effects for 6 sec. 2 min cooldown.

    -- Tier 5 (Level 75) - AoE Damage
    grimoire_of_supremacy     = { 5, 1, 108499 }, -- Your demons deal 20% more damage and are transformed into more powerful demons.
    grimoire_of_service       = { 5, 2, 108501 }, -- Summons a second demon with 100% increased damage for 15 sec. 2 min cooldown.
    grimoire_of_sacrifice     = { 5, 3, 108503 }, -- Sacrifices your demon to grant you an ability depending on the demon you sacrificed, and increases your damage by 15%. Lasts 15 sec.

    -- Tier 6 (Level 90) - DPS
    archimondes_vengeance     = { 6, 1, 108505 }, -- When you take direct damage, you reflect 15% of the damage taken back at the attacker. For the next 10 sec, you reflect 45% of all direct damage taken. This ability has 3 charges. 30 sec cooldown per charge.
    kiljaedens_cunning        = { 6, 2, 108507 }, -- Your Malefic Grasp, Drain Life, and Drain Soul can be cast while moving.
    mannoroths_fury           = { 6, 3, 108508 }  -- Your Rain of Fire, Hellfire, and Immolation Aura have no cooldown and require no Soul Shards to cast. They also no longer apply a damage over time effect.
} )

-- Comprehensive Destruction-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs - Destruction Focus
    [56220] = "incinerate",         -- Your Incinerate has a 25% chance to not consume Immolate when dealing damage to targets affected by Immolate.
    [56221] = "chaos_bolt",         -- Your Chaos Bolt deals 20% additional damage but generates 25% less Burning Embers.
    [56232] = "dark_soul",          -- Your Dark Soul also increases the critical strike damage bonus of your critical strikes by 10%.
    [56234] = "havoc",              -- Increases the range of your Havoc spell by 8 yards and reduces its cooldown by 10 sec.
    [56235] = "immolate",           -- Your Immolate spell spreads to one additional nearby enemy when the target dies while affected by Immolate.
    [56236] = "rain_of_fire",       -- Your Rain of Fire duration is increased by 25% and its damage is increased by 15%.
    [56237] = "shadowburn",         -- Your Shadowburn range is increased by 5 yards and grants a 15% movement speed increase for 6 sec.
    [56238] = "conflagrate",        -- Your Conflagrate generates 50% more Burning Embers but has its cooldown increased by 2 sec.
    [56212] = "fear",               -- Your Fear spell no longer causes the target to run in fear. Instead, the target is disoriented for 8 sec or until they take damage.
    [56218] = "shadowflame",        -- Your Shadowflame also causes enemies to be slowed by 70% for 3 sec and spreads to nearby enemies.
    [56231] = "health_funnel",      -- When using Health Funnel, your demon takes 25% less damage and gains 10% damage reduction.
    [56242] = "healthstone",        -- Your Healthstone provides 20% additional healing and grants 5% spell haste for 30 sec.
    [56249] = "drain_life",         -- When using Drain Life, your Mana regeneration is increased by 10% of spirit and heals you for 25% more.
    [56248] = "life_tap",           -- Your Life Tap no longer costs health, but instead reduces your maximum health by 5% for 60 sec.
    [56233] = "nightmares",         -- The cooldown of your Fear spell is reduced by 8 sec, but it no longer deals damage.
    [56219] = "siphon_life",        -- Your Corruption now also heals you for 0.5% of your maximum health every 3 sec.
    [56247] = "soul_consumption",   -- Your Soul Fire now consumes 800 health, but its damage is increased by 20%.
    [56241] = "soul_leech",         -- Your Soul Leech now also affects Drain Life and increases the absorption by 25%.
    [56250] = "metamorphosis",      -- Your Metamorphosis transformation increases your spell haste by 15% for the duration.
    [56251] = "dark_intent",        -- Your Dark Intent now affects 2 additional party members but provides 15% less benefit.
    [56252] = "curse_of_elements",  -- Your Curse of the Elements also increases Fire and Shadow damage taken by the target by 8%.
    [56253] = "banish",             -- Your Banish duration is increased by 50% and can now affect Aberrations and Undead.
    [56254] = "ember_tap",          -- You can spend 1 Burning Ember to instantly restore 20% of your maximum health. 30 sec cooldown.
    [56255] = "fire_and_brimstone", -- Your Fire and Brimstone affects 1 additional target but costs 25% more Burning Embers.
    
    -- Minor Glyphs - Quality of Life and Visual
    [57259] = "conflagrate_visual", -- Your Conflagrate spell creates a more dramatic fire effect that lasts 3 sec longer.
    [56228] = "demonic_circle",     -- Your Demonic Circle: Teleport spell no longer clears your Burning Embers.
    [56246] = "eye_of_kilrogg",     -- Increases the vision radius of your Eye of Kilrogg by 30 yards and movement speed by 50%.
    [58068] = "falling_meteor",     -- Your Meteor Strike now creates a surge of fire outward from the demon's position.
    [58094] = "felguard",           -- Increases the size of your Felguard, making him appear more intimidating.
    [56245] = "imp",                -- Increases the movement speed of your Imp by 50% and makes it appear wreathed in flames.
    [58079] = "searing_pain",       -- Decreases the cooldown of your Searing Pain by 2 sec and adds visual fire effects.
    [58081] = "shadow_bolt",        -- Your Shadow Bolt now creates a column of fire that damages all enemies in its path.
    [56244] = "succubus",           -- Increases the movement speed of your Succubus by 50% and adds seductive visual effects.
    [58093] = "voidwalker",         -- Increases the size of your Voidwalker, making him appear more intimidating.
    [56256] = "unending_breath",    -- Your Unending Breath no longer requires a reagent and lasts 50% longer.
    [56257] = "ritual_of_summoning", -- Your Ritual of Summoning portal remains open for 60 sec instead of closing after one use.
    [56258] = "drain_soul",         -- Your Drain Soul creates a more dramatic soul-draining visual effect.
    [56259] = "enslave_demon",      -- Your Enslave Demon spell creates binding chains around the target.
    [56260] = "health_funnel",      -- Your Health Funnel creates a visible energy beam between you and your demon.
    [56261] = "soul_swap",          -- Your Soul Swap creates a more visible magical effect when transferring DoTs.
    [56262] = "dark_portal",        -- Your Dark Portal appears more ominous with enhanced shadow effects.
    [56263] = "burning_rush",       -- Your Burning Rush leaves a trail of fire behind you as you move.
    [56264] = "howl_of_terror",     -- Your Howl of Terror creates visible fear auras around affected enemies.
    [56265] = "shadowfury",         -- Your Shadowfury creates a more dramatic shadow explosion with enhanced particle effects.
} )

-- Destruction Warlock specific auras
spec:RegisterAuras( {    -- Core DoT/Debuff Mechanics with Advanced Generate Functions
    immolate = {
        id = 348,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 348 )
            
            if name and caster == "player" then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track pandemic refresh window (30% of duration)
                t.pandemic_threshold = t.applied + (duration * 0.7)
                t.can_pandemic = expirationTime <= GetTime() + (duration * 0.3)
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.pandemic_threshold = 0
            t.can_pandemic = false
        end
    },
    conflagrate = {
        id = 17962,
        duration = 10,
        max_stack = 1,
    },
    havoc = {
        id = 80240,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 80240 )
            
            if name and caster == "player" then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track remaining cleave opportunities
                t.cleave_charges_remaining = math.max(0, math.ceil((expirationTime - GetTime()) / 1.5))
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.cleave_charges_remaining = 0
        end
    },
    shadowburn = {
        id = 17877,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 17877 )
            
            if name and caster == "player" then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track for Burning Ember generation on target death
                t.will_generate_ember = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.will_generate_ember = false
        end
    },
    backdraft = {
        id = 117828,
        duration = 15,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 117828 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track cast time reduction value (30% per stack)
                t.cast_time_reduction = 0.3 * t.count
                t.next_incinerate_cast_time = 2.5 * (1 - t.cast_time_reduction)
                t.worth_using = t.count >= 2 or expirationTime - GetTime() < 5
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.cast_time_reduction = 0
            t.next_incinerate_cast_time = 2.5
            t.worth_using = false
        end
    },    
    -- Procs and Talents with Enhanced Tracking
    dark_soul_instability = {
        id = 113858,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 113858 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track enhanced effects
                t.crit_bonus = 30 -- 30% critical strike bonus
                t.ember_generation_bonus = 100 -- Double ember generation
                t.time_remaining = expirationTime - GetTime()
                t.should_use_chaos_bolt = t.time_remaining > 3
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.crit_bonus = 0
            t.ember_generation_bonus = 0
            t.time_remaining = 0
            t.should_use_chaos_bolt = false
        end
    },
    
    -- Rain of Fire DoT effect with AoE tracking
    rain_of_fire = {
        id = 5740,
        duration = 8,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 5740 )
            
            if name and caster == "player" then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track AoE potential
                t.ticks_remaining = math.max(0, math.ceil((expirationTime - GetTime()) / 1))
                t.total_damage_remaining = t.ticks_remaining * (state.active_enemies or 1)
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.ticks_remaining = 0
            t.total_damage_remaining = 0
        end
    },
      -- Defensive Cooldowns with Smart Tracking
    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 110913 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track damage absorption and pending damage
                t.damage_absorbed = 0 -- Would need combat log tracking
                t.pending_damage_percent = 50 -- 50% of absorbed damage
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.damage_absorbed = 0
            t.pending_damage_percent = 0
        end
    },
    dark_bargain_dot = {
        id = 110914,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "player", 110914 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track pending damage per tick
                t.damage_per_tick = 0 -- Would be calculated from absorbed damage
                t.ticks_remaining = math.max(0, math.ceil((expirationTime - GetTime()) / 1))
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.damage_per_tick = 0
            t.ticks_remaining = 0
        end
    },
    soul_link = {
        id = 108415,
        duration = 3600,
        max_stack = 1,
    },
    unbound_will = {
        id = 108482,
        duration = 6,
        max_stack = 1,
    },
    
    -- Pet-related
    grimoire_of_sacrifice = {
        id = 108503,
        duration = 15,
        max_stack = 1,
    },
    
    -- Utility
    dark_regeneration = {
        id = 108359,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    unending_breath = {
        id = 5697,
        duration = 600,
        max_stack = 1,
    },
    unending_resolve = {
        id = 104773,
        duration = 8,
        max_stack = 1,
    },
    demonic_circle = {
        id = 48018,
        duration = 900,
        max_stack = 1,
    },    demonic_gateway = {
        id = 113900,
        duration = 15,
        max_stack = 1,
    },
    
    -- Advanced Aura Enhancements with Generate Functions
    backlash = {
        id = 34936,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 34936 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track instant cast availability
                t.enables_instant_incinerate = true
                t.enables_instant_chaos_bolt = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.enables_instant_incinerate = false
            t.enables_instant_chaos_bolt = false
        end
    },
    
    metamorphosis = {
        id = 103958,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 103958 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track enhanced abilities
                t.damage_bonus = 25 -- 25% damage increase
                t.ember_generation_bonus = 50 -- 50% faster generation
                t.enables_doom = true
                t.enables_immolation_aura = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.damage_bonus = 0
            t.ember_generation_bonus = 0
            t.enables_doom = false
            t.enables_immolation_aura = false
        end
    },
    
    fel_armor = {
        id = 28176,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 28176 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track spell power and mana regen bonuses
                t.spell_power_bonus = state.stat.spell_power * 0.1 -- 10% spell power as mana regen
                t.mana_regen_bonus = 30 -- 30% spirit bonus
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.spell_power_bonus = 0
            t.mana_regen_bonus = 0
        end
    },
    
    -- Tier Set Bonuses with Advanced Tracking
    tier15_2pc_destruction = {
        id = 138131,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            if state.set_bonus.tier15_2pc == 1 then
                -- Track Conflagrate Immolate consumption prevention
                t.name = "Tier 15 2pc"
                t.count = 1
                t.applied = state.query_time
                t.expires = state.query_time + 15
                t.caster = "player"
                
                t.conflagrate_preserve_chance = 25 -- 25% chance to not consume Immolate
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.conflagrate_preserve_chance = 0
        end
    },
    
    tier15_4pc_destruction = {
        id = 138132,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 138132 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track spell haste bonus from Chaos Bolt
                t.haste_bonus = 15 -- 15% spell haste
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.haste_bonus = 0
        end
    },
    
    tier16_4pc_destruction = {
        id = 144957,
        duration = 20,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 144957 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track Chaos Bolt damage bonus
                t.chaos_bolt_damage_bonus = 25 * t.count -- 25% per stack
                t.charges_remaining = t.count
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.chaos_bolt_damage_bonus = 0
            t.charges_remaining = 0
        end
    },
} )

-- Destruction Warlock abilities
spec:RegisterAbilities( {
    -- Core Rotational Abilities
    incinerate = {
        id = 29722,
        cast = function() 
            if buff.backdraft.up then 
                return (2.5 * haste) * 0.7 -- 30% cast speed increase with Backdraft
            end
            return 2.5 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.075,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135789,
        
        handler = function()
            -- Generate Burning Embers
            generate( 0.1, "burning_embers" ) -- 0.1 fragment per cast
            
            -- Consume Backdraft
            if buff.backdraft.up then
                if buff.backdraft.stack > 1 then
                    removeStack( "backdraft" )
                else
                    removeBuff( "backdraft" )
                end
            end
        end,
    },
    
    immolate = {
        id = 348,
        cast = function() return 1.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135817,
        
        handler = function()
            applyDebuff( "target", "immolate" )
            -- Generate Burning Embers over time
            -- This is handled via periodic ticks in MoP
        end,
    },
    
    conflagrate = {
        id = 17962,
        cast = 0,
        charges = 2,
        cooldown = 12,
        recharge = 12,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135807,
        
        usable = function()
            return debuff.immolate.up or glyph.conflagrate.enabled, "requires immolate on target"
        end,
        
        handler = function()
            -- Generate Backdraft
            applyBuff( "backdraft" )
            buff.backdraft.stack = 3
            
            -- Generate Burning Embers
            generate( 0.1, "burning_embers" )
            
            -- Remove Immolate if not using the glyph
            if not glyph.conflagrate.enabled then
                removeDebuff( "target", "immolate" )
            end
        end,
    },
    
    chaos_bolt = {
        id = 116858,
        cast = function() 
            if buff.backdraft.up then 
                return (3 * haste) * 0.7 -- 30% cast speed increase with Backdraft
            end
            return 3 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "burning_embers",
        
        startsCombat = true,
        texture = 135808,
        
        handler = function()
            -- Consume Backdraft if active
            if buff.backdraft.up then
                if buff.backdraft.stack > 1 then
                    removeStack( "backdraft" )
                else
                    removeBuff( "backdraft" )
                end
            end
        end,
    },
    
    shadowburn = {
        id = 17877,
        cast = 0,
        cooldown = 12,
        gcd = "spell",
        
        spend = 1,
        spendType = "burning_embers",
        
        startsCombat = true,
        texture = 136191,
        
        usable = function()
            return target.health_pct < 20, "requires target below 20% health"
        end,
        
        handler = function()
            applyDebuff( "target", "shadowburn" )
            
            -- If target dies with Shadowburn, refund 2 Burning Embers
            -- This is handled separately based on target death events
        end,
    },
    
    rain_of_fire = {
        id = 5740,
        cast = 0,
        cooldown = function() return talent.mannoroths_fury.enabled and 0 or 8 end,
        gcd = "spell",
        
        spend = function() return talent.mannoroths_fury.enabled and 0 or 1 end,
        spendType = "burning_embers",
        
        startsCombat = true,
        texture = 135804,
        
        handler = function()
            applyDebuff( "target", "rain_of_fire" )
        end,
    },
    
    fel_flame = {
        id = 77799,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236253,
        
        handler = function()
            -- Extend Immolate by 6 seconds
            if debuff.immolate.up then
                debuff.immolate.expires = debuff.immolate.expires + 6
                -- Cap at maximum duration
                if debuff.immolate.expires > query_time + 15 then
                    debuff.immolate.expires = query_time + 15
                end
            end
            
            -- Generate Burning Embers
            generate( 0.1, "burning_embers" )
        end,
    },
    
    havoc = {
        id = 80240,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 460695,
        
        handler = function()
            applyDebuff( "target", "havoc" )
        end,
    },
    
    life_tap = {
        id = 1454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            -- Costs 15% health, returns 15% mana
            local health_cost = health.max * 0.15
            local mana_return = mana.max * 0.15
            
            spend( health_cost, "health" )
            gain( mana_return, "mana" )
        end,
    },
    
    -- Cooldowns
    dark_soul = {
        id = 113858,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 538042,
        
        handler = function()
            applyBuff( "dark_soul_instability" )
        end,
    },
    
    summon_imp = {
        id = 688,
        cast = 6,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.11,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136218,
        
        handler = function()
            -- Summon imp pet
        end,
    },
    
    summon_doomguard = {
        id = 18540,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 603013,
        
        handler = function()
            -- Summon Doomguard for 1 minute
        end,
    },
    
    summon_infernal = {
        id = 1122,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136219,
        
        handler = function()
            -- Summon Infernal for 1 minute
        end,
    },
    
    -- Defensive and Utility
    dark_bargain = {
        id = 110913,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 538038,
        
        handler = function()
            applyBuff( "dark_bargain" )
        end,
    },
    
    unending_resolve = {
        id = 104773,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 136150,
        
        handler = function()
            applyBuff( "unending_resolve" )
        end,
    },
    
    demonic_circle_summon = {
        id = 48018,
        cast = 0.5,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            applyBuff( "demonic_circle" )
        end,
    },
    
    demonic_circle_teleport = {
        id = 48020,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 607512,
        
        handler = function()
            -- Teleport to circle
        end,
    },
    
    -- Talent abilities
    howl_of_terror = {
        id = 5484,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607510,
        
        handler = function()
            -- Fear all enemies in 10 yards
        end,
    },
    
    mortal_coil = {
        id = 6789,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607514,
        
        handler = function()
            -- Fear target and heal 11% of max health
            local heal_amount = health.max * 0.11
            gain( heal_amount, "health" )
        end,
    },
    
    shadowfury = {
        id = 30283,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 457223,
        
        handler = function()
            -- Stun all enemies in 8 yards
        end,
    },
    
    grimoire_of_sacrifice = {
        id = 108503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 538443,
        
        handler = function()
            applyBuff( "grimoire_of_sacrifice" )
        end,
    },
} )

-- State Expressions for Destruction
spec:RegisterStateExpr( "burning_embers", function()
    return burning_embers.current
end )

spec:RegisterStateExpr( "burning_embers_deficit", function()
    return burning_embers.max - burning_embers.current
end )

spec:RegisterStateExpr( "current_burning_embers", function()
    return burning_embers.current or 0
end )

spec:RegisterStateExpr( "backlash_proc", function()
    return buff.backlash.up and 1 or 0
end )

spec:RegisterStateExpr( "backdraft_charges", function()
    return buff.backdraft.up and buff.backdraft.stack or 0
end )

spec:RegisterStateExpr( "molten_core_bonus", function()
    return buff.molten_core.up and 0.15 or 0 -- 15% damage bonus
end )

spec:RegisterStateExpr( "immolate_debuff_active", function()
    return debuff.immolate.up and 1 or 0
end )

spec:RegisterStateExpr( "chaos_bolt_ready", function()
    return burning_embers.current >= 4 and 1 or 0
end )

spec:RegisterStateExpr( "ember_tap_ready", function()
    return burning_embers.current >= 1 and 1 or 0
end )

spec:RegisterStateExpr( "spell_power", function()
    return GetSpellBonusDamage(3) -- Fire school
end )

-- Range
spec:RegisterRanges( "incinerate", "immolate", "conflagrate" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent",
    
    package = "Destruction",
} )

-- Default pack for MoP Destruction Warlock
spec:RegisterPack( "Destruction", 20250515, [[Hekili:T3vBVTTn04FldjHr9LSgR2e75XVc1cbKzKRlvnTo01OEckA2IgxVSbP5cFcqifitljsBPIYPKQbbXQPaX0YCRwRNFAxBtwR37pZUWZB3SZ0Zbnu(ndREWP)8dyNF3BhER85x(jym5nymTYnv0drHbpz5IW1vZgbo1P)MM]] )

-- Register pack selector for Destruction

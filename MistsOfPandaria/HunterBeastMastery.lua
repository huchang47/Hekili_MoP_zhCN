    -- HunterBeastMastery.lua
    -- july 2025 by smufrik


    local _, playerClass = UnitClass('player')
    if playerClass ~= 'HUNTER' then return end

    local addon, ns = ...
    local Hekili = _G[ addon ]
    local class, state = Hekili.Class, Hekili.State

    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local strformat = string.format

local spec = Hekili:NewSpecialization( 253, true )



    -- Use MoP power type numbers instead of Enum
    -- Focus = 2 in MoP Classic
    spec:RegisterResource( 2, {
        steady_shot = {
            resource = "focus",
            cast = function(x) return x > 0 and x or nil end,
            aura = function(x) return x > 0 and "casting" or nil end,

            last = function()
                return state.buff.casting.applied
            end,

            interval = function() return state.buff.casting.duration end,
            value = 9,
        },

        cobra_shot = {
            resource = "focus",
            cast = function(x) return x > 0 and x or nil end,
            aura = function(x) return x > 0 and "casting" or nil end,

            last = function()
                return state.buff.casting.applied
            end,

            interval = function() return state.buff.casting.duration end,
            value = 14,
        },

        dire_beast = {
            resource = "focus",
            aura = "dire_beast",

            last = function()
                local app = state.buff.dire_beast.applied
                local t = state.query_time

                return app + floor( ( t - app ) / 2 ) * 2
            end,

            interval = 2,
            value = 5,
        },

        fervor = {
            resource = "focus",
            aura = "fervor",

            last = function()
                return state.buff.fervor.applied
            end,

            interval = 0.1,
            value = 50,
        },
    } )

    -- Talents
    spec:RegisterTalents( {
        -- Tier 1 (Level 15)
        posthaste = { 1, 1, 109215 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 60% for 4 sec.
        narrow_escape = { 1, 2, 109298 }, -- When Disengage is activated, you also activate a web trap which encases all targets within 8 yards in sticky webs, preventing movement for 8 sec. Damage caused may interrupt the effect.
        crouching_tiger_hidden_chimera = { 1, 3, 118675 }, -- Reduces the cooldown of Disengage by 6 sec and Deterrence by 10 sec.

        -- Tier 2 (Level 30)
        silencing_shot = { 2, 1, 34490 }, -- Interrupts spellcasting and prevents any spell in that school from being cast for 3 sec.
        wyvern_sting = { 2, 2, 19386 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, they will be poisoned, taking Nature damage over 6 sec. Only one Sting per Hunter can be active on the target at a time.
        binding_shot = { 2, 3, 109248 }, -- Fires a magical projectile, tethering the enemy and any other enemies within 5 yards, stunning them for 5 sec if they move more than 5 yards from the arrow.

        -- Tier 3 (Level 45)
        intimidation = { 3, 1, 19577 }, -- Commands your pet to intimidate the target, causing a high amount of threat and stunning the target for 3 sec.
        spirit_bond = { 3, 2, 19579 }, -- While your pet is active, you and your pet regen 2% of total health every 10 sec.
        iron_hawk = { 3, 3, 109260 }, -- Reduces all damage taken by 10%.

        -- Tier 4 (Level 60)
        dire_beast = { 4, 1, 120679 }, -- Summons a powerful wild beast that attacks the target for 15 sec.
        fervor = { 4, 2, 82726 }, -- Instantly restores 50 Focus to you and your pet, and increases Focus regeneration by 50% for you and your pet for 10 sec.
        a_murder_of_crows = { 4, 3, 131894 }, -- Summons a flock of crows to attack your target over 30 sec. If the target dies while the crows are attacking, their cooldown is reset.

        -- Tier 5 (Level 75)
        blink_strikes = { 5, 1, 130392 }, -- Your pet's Basic Attacks deal 50% increased damage and can be used from 30 yards away. Their range is increased to 40 yards while Dash or Stampede is active.
        lynx_rush = { 5, 2, 120697 }, -- Commands your pet to rush the target, performing 9 attacks in 4 sec for 800% normal damage. Each hit deals bleed damage to the target over 8 sec. Bleeds stack and persist on the target.
        thrill_of_the_hunt = { 5, 3, 34720 }, -- You have a 30% chance when you hit with Multi-Shot or Arcane Shot to make your next Steady Shot or Cobra Shot cost no Focus and deal 150% additional damage.

        -- Tier 6 (Level 90)
        glaive_toss = { 6, 1, 117050 }, -- Throws a pair of glaives at your target, dealing Physical damage and reducing movement speed by 30% for 3 sec. The glaives return to you, also dealing damage to any enemies in their path.
        powershot = { 6, 2, 109259 }, -- A powerful aimed shot that deals weapon damage to the target and up to 5 targets in the line of fire. Knocks all targets back, reduces your maximum Focus by 20 for 10 sec and refunds some Focus for each target hit.
        barrage = { 6, 3, 120360 }, -- Rapidly fires a spray of shots for 3 sec, dealing Physical damage to all enemies in front of you. Usable while moving.
    } )

-- Glyphs (Enhanced System - authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs - Beast Mastery Combat
    [54825] = "aspect_of_the_beast",  -- Aspect of the Beast now also increases your pet's damage by 10%
    [54760] = "bestial_wrath",        -- Bestial Wrath now also increases your pet's movement speed by 50%
    [54821] = "kill_command",         -- Kill Command now has a 50% chance to not trigger a cooldown
    [54832] = "mend_pet",             -- Mend Pet now also heals you for 50% of the amount
    [54743] = "revive_pet",           -- Revive Pet now has a 100% chance to succeed
    [54829] = "scare_beast",          -- Scare Beast now affects all beasts within 10 yards
    [54754] = "tame_beast",           -- Tame Beast now has a 100% chance to succeed
    [54755] = "call_pet",             -- Call Pet now summons your pet instantly
    [116218] = "aspect_of_the_pack",  -- Aspect of the Pack now also increases your pet's movement speed by 30%
    [125390] = "aspect_of_the_cheetah", -- Aspect of the Cheetah now also increases your pet's movement speed by 30%
    [125391] = "aspect_of_the_hawk",  -- Aspect of the Hawk now also increases your pet's attack speed by 10%
    [125392] = "aspect_of_the_monkey", -- Aspect of the Monkey now also increases your pet's dodge chance by 10%
    [125393] = "aspect_of_the_viper", -- Aspect of the Viper now also increases your pet's mana regeneration by 50%
    [125394] = "aspect_of_the_wild",  -- Aspect of the Wild now also increases your pet's critical strike chance by 5%
    [125395] = "aspect_mastery",      -- Your aspects now last 50% longer
    
    -- Major glyphs - Pet Abilities
    [94388] = "growl",                -- Growl now has a 100% chance to succeed
    [59219] = "claw",                 -- Claw now has a 50% chance to not trigger a cooldown
    [114235] = "bite",                -- Bite now has a 50% chance to not trigger a cooldown
    [125396] = "dash",                -- Dash now also increases your pet's attack speed by 20%
    [125397] = "cower",               -- Cower now also reduces the target's attack speed by 20%
    [125398] = "demoralizing_screech", -- Demoralizing Screech now affects all enemies within 10 yards
    [125399] = "monkey_business",     -- Monkey Business now has a 100% chance to succeed
    [125400] = "serpent_swiftness",   -- Serpent Swiftness now also increases your pet's movement speed by 30%
    [125401] = "great_stamina",       -- Great Stamina now also increases your pet's health by 20%
    [54828] = "great_resistance",     -- Great Resistance now also increases your pet's resistance by 20%
    
    -- Major glyphs - Defensive/Survivability
    [125402] = "mend_pet",            -- Mend Pet now also heals you for 50% of the amount
    [125403] = "revive_pet",          -- Revive Pet now has a 100% chance to succeed
    [125404] = "call_pet",            -- Call Pet now summons your pet instantly
    [125405] = "dismiss_pet",         -- Dismiss Pet now has no cooldown
    [125406] = "feed_pet",            -- Feed Pet now has a 100% chance to succeed
    [125407] = "play_dead",           -- Play Dead now has a 100% chance to succeed
    [125408] = "tame_beast",          -- Tame Beast now has a 100% chance to succeed
    [125409] = "beast_lore",          -- Beast Lore now provides additional information
    [125410] = "track_beasts",        -- Track Beasts now also increases your damage against beasts by 5%
    [125411] = "track_humanoids",     -- Track Humanoids now also increases your damage against humanoids by 5%
    
    -- Major glyphs - Control/CC
    [125412] = "freezing_trap",       -- Freezing Trap now affects all enemies within 5 yards
    [125413] = "ice_trap",            -- Ice Trap now affects all enemies within 5 yards
    [125414] = "snake_trap",          -- Snake Trap now summons 3 additional snakes
    [125415] = "explosive_trap",      -- Explosive Trap now affects all enemies within 5 yards
    [125416] = "immolation_trap",     -- Immolation Trap now affects all enemies within 5 yards
    [125417] = "black_arrow",         -- Black Arrow now has a 50% chance to not trigger a cooldown
    
    -- Minor glyphs - Visual/Convenience
    [57856] = "aspect_of_the_beast",  -- Your pet appears as a different beast type
    [57862] = "aspect_of_the_cheetah", -- Your pet leaves a glowing trail when moving
    [57863] = "aspect_of_the_hawk",   -- Your pet has enhanced visual effects
    [57855] = "aspect_of_the_monkey", -- Your pet appears more agile and nimble
    [57861] = "aspect_of_the_viper",  -- Your pet appears more serpentine
    [57857] = "aspect_of_the_wild",   -- Your pet appears more wild and untamed
    [57858] = "beast_lore",           -- Beast Lore provides enhanced visual information
    [57860] = "track_beasts",         -- Track Beasts has enhanced visual effects
    [121840] = "track_humanoids",     -- Track Humanoids has enhanced visual effects
    [125418] = "blooming",            -- Your abilities cause flowers to bloom around the target
    [125419] = "floating",            -- Your spells cause you to hover slightly above the ground
    [125420] = "glow",                -- Your abilities cause you to glow with natural energy
} )

-- Auras
    spec:RegisterAuras( {
        -- Talent: Under attack by a flock of crows.
        -- https://wowhead.com/beta/spell=131894
        a_murder_of_crows = {
            id = 131894,
            duration = 30,
            tick_time = 1,
            max_stack = 1
        },
        -- Movement speed increased by $w1%.
        -- https://wowhead.com/beta/spell=186258
        aspect_of_the_cheetah = {
            id = 5118,
            duration = 3600,
            max_stack = 1
        },
        -- Talent: Damage dealt increased by $w1%.
        -- https://wowhead.com/beta/spell=19574
        bestial_wrath = {
            id = 19574,
            duration = 10,
            type = "Ranged",
            max_stack = 1
        },
        -- Alias used by some APLs/imports for Bestial Wrath
        the_beast_within = {
            id = 19574,
            duration = 10,
            type = "Ranged",
            max_stack = 1,
            copy = "bestial_wrath"
        },
        -- Stunned.
        binding_shot_stun = {
            id = 117526,
            duration = 5,
            max_stack = 1,
        },
        -- Movement slowed by $s1%.
        concussive_shot = {
            id = 5116,
            duration = 6,
            mechanic = "snare",
            type = "Ranged",
            max_stack = 1
        },
        -- Talent: Haste increased by $s1%.
        dire_beast = {
            id = 120694,
            duration = 15,
            max_stack = 1
        },
        -- Feigning death.
        feign_death = {
            id = 5384,
            duration = 360,
            max_stack = 1
        },
        -- Restores Focus.
        fervor = {
            id = 82726,
            duration = 10,
            max_stack = 1
        },
        -- Incapacitated.
        freezing_trap = {
            id = 3355,
            duration = 8,
            type = "Magic",
            max_stack = 1
        },
        -- Talent: Increased movement speed by $s1%.
        posthaste = {
            id = 118922,
            duration = 4,
            max_stack = 1
        },
        -- Silenced.
        silencing_shot = {
            id = 34490,
            duration = 3,
            mechanic = "silence",
            max_stack = 1
        },
        -- Asleep.
        wyvern_sting = {
            id = 19386,
            duration = 30,
            mechanic = "sleep",
            max_stack = 1
        },
        -- Poisoned.
        wyvern_sting_dot = {
            id = 19386,
            duration = 6,
            tick_time = 2,
            max_stack = 1
        },
        -- Stunned.
        intimidation = {
            id = 19577,
            duration = 3,
            max_stack = 1
        },
        -- Health regeneration increased.
        spirit_bond = {
            id = 19579,
            duration = 3600,
            max_stack = 1
        },
        -- Damage taken reduced by $s1%.
        iron_hawk = {
            id = 109260,
            duration = 3600,
            max_stack = 1
        },
        -- Talent: Bleeding for $w1 damage every $t1 sec.
        lynx_rush = {
            id = 120697,
            duration = 8,
            tick_time = 1,
            max_stack = 9
        },
        -- Talent: Thrill of the Hunt - next 3 Arcane/Multi-Shots cost 20 less Focus (tracked from game aura)
        thrill_of_the_hunt = {
            id = 34720,
            duration = 12,
            max_stack = 3,
            generate = function( t )
                local name, _, _, count = FindUnitBuffByID( "player", 34720 )
                if name then
                    t.name = name
                    t.count = count and count > 0 and count or 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 12
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
        },
        -- Talent: Movement speed reduced by $s1%.
        glaive_toss = {
            id = 117050,
            duration = 3,
            mechanic = "snare",
            max_stack = 1
        },
        -- Talent: Focus reduced by $s1.
        powershot = {
            id = 109259,
            duration = 10,
            max_stack = 1
        },
        -- Talent: Rapidly firing.
        barrage = {
            id = 120360,
            duration = 3,
            tick_time = 0.2,
            max_stack = 1
        },
        -- Summons a herd of stampeding animals from the wild to fight for you for 12 sec.
        stampede = {
            id = 121818,
            duration = 12,
            max_stack = 1
        },
        -- Movement speed reduced by $s1%.
        wing_clip_debuff = {
            id = 2974,
            duration = 10,
            max_stack = 1
        },
        -- Healing over time.
        mend_pet = {
            id = 136,
            duration = 10,
            type = "Magic",
            max_stack = 1,
            generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "pet", 136 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 10
                    t.caster = "pet"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
        },
        -- Threat redirected from Hunter.
        misdirection = {
            id = 35079,
            duration = 8,
            max_stack = 1
        },
        -- Feared.
        scare_beast = {
            id = 1513,
            duration = 20,
            mechanic = "flee",
            type = "Magic",
            max_stack = 1
        },
        -- Disoriented.
        scatter_shot = {
            id = 213691,
            duration = 4,
            type = "Ranged",
            max_stack = 1
        },
        -- Casting.
        casting = {
            duration = function () return haste end,
            max_stack = 1,
            generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "player", 116951 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 2.5
                    t.caster = "player"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
        },
        -- MoP specific auras
        improved_steady_shot = {
            id = 53220,
            duration = 15,
            max_stack = 1
        },
        serpent_sting = {
            id = 118253,    
            duration = 15,
            tick_time = 3,
            type = "Ranged",
            max_stack = 1
        },
        frenzy = {
            id = 19615,
            duration = 8,
            max_stack = 5
        },
        focus_fire = {
            id = 82692,
            duration = 20,
            max_stack = 5,  -- Stacks correspond to consumed frenzy stacks
            copy = "focus_fire_buff"
        },
        beast_cleave = {
            id = 115939,
            duration = 4,
            max_stack = 1
        },
        hunters_mark = {
            id = 1130,
            duration = 300,
            type = "Ranged",
            max_stack = 1
        },
        aspect_of_the_iron_hawk = {
            id = 109260,
            duration = 3600,
            max_stack = 1
        },
        rapid_fire = {
            id = 3045,
            duration = 3,
            tick_time = 0.2,
            max_stack = 1
        },
        explosive_trap = {
            id = 13813,
            duration = 20,
            max_stack = 1
        },
        -- Tier set bonuses
        tier14_4pc = {
            id = 105919,
            duration = 3600,
            max_stack = 1
        },
        tier15_2pc = {
            id = 138267,
            duration = 3600,
            max_stack = 1
        },
        tier15_4pc = {
            id = 138268,
            duration = 3600,
            max_stack = 1
        },
        tier16_2pc = {
            id = 144659,
            duration = 5,
            max_stack = 1
        },
        tier16_4pc = {
            id = 144660,
            duration = 5,
            max_stack = 1
        },
        -- Additional missing auras
        deterrence = {
            id = 19263,
            duration = 5,
            max_stack = 1
        },
        aspect_of_the_hawk = {
            id = 13165,
            duration = 3600,
            max_stack = 1
        },
        aspect_of_the_pack = {
            id = 13159,
            duration = 3600,
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

    spec:RegisterStateFunction( "apply_aspect", function( name )
        removeBuff( "aspect_of_the_hawk" )
        removeBuff( "aspect_of_the_iron_hawk" )
        removeBuff( "aspect_of_the_cheetah" )
        removeBuff( "aspect_of_the_pack" )

        if name then applyBuff( name ) end
    end )

    -- Pets
    spec:RegisterPets({
        dire_beast = {
            id = 100,
            spell = "dire_beast",
            duration = 15
        },
    } )



    --- Mists of Pandaria
    spec:RegisterGear( "tier16", 99169, 99170, 99171, 99172, 99173 )
    spec:RegisterGear( "tier15", 95307, 95308, 95309, 95310, 95311 )
    spec:RegisterGear( "tier14", 84242, 84243, 84244, 84245, 84246 )


    spec:RegisterHook( "spend", function( amt, resource )
        if amt < 0 and resource == "focus" and talent.fervor.enabled and buff.fervor.up then
            amt = amt * 1.5
        end

        return amt, resource
    end )


    -- State Expressions for MoP Beast Mastery Hunter
    spec:RegisterStateExpr( "current_focus", function()
    return state.focus.current or 0
end )

    spec:RegisterStateExpr( "focus_deficit", function()
    return (state.focus.max or 100) - (state.focus.current or 0)
end )

spec:RegisterStateExpr( "should_focus_fire", function()
    -- Enhanced Focus Fire logic for optimal Beast Mastery play
    if not pet.alive or buff.frenzy.stack == 0 then return false end
    
    -- Always use at 5 stacks
    if buff.frenzy.stack >= 5 then return true end
    
    -- Use at 3+ stacks if Bestial Wrath is on cooldown > 10s
    if buff.frenzy.stack >= 3 and cooldown.bestial_wrath.remains > 10 then return true end
    
    -- Use at 2+ stacks if frenzy is about to expire (< 3s remaining)
    if buff.frenzy.stack >= 2 and buff.frenzy.remains < 3 then return true end
    
    -- Never use during Bestial Wrath (waste of synergy)
    if buff.bestial_wrath.up then return false end
    
    return false
end )

-- Threat is handled by engine; no spec override

spec:RegisterStateExpr( "should_maintain_beast_cleave", function()
    -- Beast Cleave is a passive buff that needs to be refreshed every 4 seconds
    -- Track when Multi-Shot was last cast to maintain Beast Cleave uptime
    local last_multi_shot = state.history.casts.multi_shot or 0
    local current_time = state.query_time or 0
    
    -- Return true if it's been more than 3.5 seconds since last Multi-Shot
    -- This ensures we refresh Beast Cleave before it expires (4 second duration)
    return (current_time - last_multi_shot) >= 3.5
end )

spec:RegisterStateExpr( "beast_cleave_remains", function()
    -- Calculate remaining time on Beast Cleave based on last Multi-Shot cast
    local last_multi_shot = state.history.casts.multi_shot or 0
    local current_time = state.query_time or 0
    local time_since_cast = current_time - last_multi_shot
    
    -- Beast Cleave lasts 4 seconds, return remaining time
    return math.max(0, 4 - time_since_cast)
end )

    spec:RegisterStateExpr( "focus_time_to_max", function()
        return focus.time_to_max
    end )

    spec:RegisterStateExpr( "pet_alive", function()
        return pet.alive
    end )

    spec:RegisterStateExpr( "bloodlust", function()
        return buff.bloodlust
    end )

    -- Enhanced frenzy tracking for better Focus Fire timing
    spec:RegisterStateExpr( "frenzy_duration_remaining", function()
        return buff.frenzy.remains or 0
    end )

    spec:RegisterStateExpr( "can_generate_frenzy", function()
        return pet.alive and buff.frenzy.stack < 5
    end )

    -- === SHOT ROTATION STATE EXPRESSIONS ===
    
    -- Determines if we should use Cobra Shot over Steady Shot
    spec:RegisterStateExpr( "should_cobra_shot", function()
        -- Cobra Shot is preferred for Beast Mastery when:
        -- 1. We need focus and aren't at cap
        -- 2. We need to maintain Serpent Sting
        -- 3. General focus generation
        
        if (state.focus.current or 0) > 86 then return false end -- Don't cast if we'll cap focus
        
        -- Always prioritize Cobra Shot for Beast Mastery (pulled from Survival logic)
        return true
    end )
    
    -- Determines if we should use Steady Shot
    spec:RegisterStateExpr( "should_steady_shot", function()
        -- Beast Mastery should never use Steady Shot - always use Cobra Shot for focus generation
        return false
    end )
    
    -- Optimal focus threshold for casting focus spenders
    spec:RegisterStateExpr( "focus_spender_threshold", function()
        -- Beast Mastery focus thresholds:
        -- Kill Command: 40 focus (highest priority)
        -- Arcane Shot: 20 focus
        -- Reserve at least 20 focus for emergency Kill Command
        
        if not pet.alive then return 80 end -- Higher threshold without pet
        
        -- During Bestial Wrath, be more aggressive
        if buff.bestial_wrath.up then return 60 end
        
        -- Normal threshold allows for Kill Command priority
        return 70
    end )
    
    -- Determines if we're in an optimal shot weaving window
    spec:RegisterStateExpr( "optimal_shot_window", function()
        -- Optimal windows for shot rotation:
        -- 1. Not during Bestial Wrath (save focus for Kill Command spam)
        -- 2. When we have focus room
        -- 3. When cooldowns aren't ready
        
        if buff.bestial_wrath.up then return false end
        if (state.focus.current or 0) < 30 then return false end
        if cooldown.kill_command.ready and pet.alive then return false end
        
        return true
    end )

    -- Abilities
    spec:RegisterAbilities( {
        a_murder_of_crows = {
            id = 131894,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            talent = "a_murder_of_crows",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "a_murder_of_crows" )
            end,
        },

        arcane_shot = {
            id = 3044,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "arcane",

            spend = function () return buff.thrill_of_the_hunt.up and 0 or 20 end,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- Cost reduction/stack usage is handled by the real aura; no manual consume/proc here.
            end,
        },

        aspect_of_the_cheetah = {
            id = 5118,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                apply_aspect( "aspect_of_the_cheetah" )
            end,
        },

        aspect_of_the_hawk = {
            id = 13165,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                applyBuff( "aspect_of_the_hawk" )
            end,
        },

        aspect_of_the_iron_hawk = {
            id = 109260,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                applyBuff( "aspect_of_the_iron_hawk" )
            end,
        },

        barrage = {
            id = 120360,
            cast = function () return 3 * haste end,
            channeled = true,
            cooldown = 20,
            gcd = "spell",
            school = "physical",

            spend = 40,
            spendType = "focus",

            talent = "barrage",
            startsCombat = true,
            toggle = "cooldowns",

            start = function ()
                applyBuff( "barrage" )
            end,
        },

        stampede = {
            id = 121818,
            cast = 0,
            cooldown = 300,
            gcd = "off",

            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "stampede" )
            end,
        },

        bestial_wrath = {
            id = 19574,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "physical",

            startsCombat = false,

            toggle = "cooldowns",

            handler = function ()
                applyBuff( "bestial_wrath" )
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
                applyDebuff( "target", "binding_shot_stun" )
            end,
        },

        call_pet = {
            id = 883,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,

            usable = function () return not pet.exists, "requires no active pet" end,

            handler = function ()
                -- spec:summonPet( "hunter_pet" ) handled by the system
            end,
        },

        call_pet_1 = {
            id = 883,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,

            usable = function () return not pet.exists, "requires no active pet" end,

            handler = function ()
                -- summonPet( "hunter_pet", 3600 ) handled by the system
            end,
        },

        cobra_shot = {
            id = 77767,
            cast = function() return 2.0 / haste end,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end
                
                -- Cobra Shot maintains Serpent Sting in MoP
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                    if debuff.serpent_sting.expires > query_time + 15 then
                        debuff.serpent_sting.expires = query_time + 15 -- Cap at max duration
                    end
                end
                
                -- ToTH procs are handled by the game; don't simulate.
            end,
        },

        concussive_shot = {
            id = 5116,
            cast = 0,
            cooldown = 5,
            gcd = "spell",
            school = "physical",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "concussive_shot" )
            end,
        },

        deterrence = {
            id = 19263,
            cast = 0,
            cooldown = function () return talent.crouching_tiger_hidden_chimera.enabled and 170 or 180 end,
            gcd = "spell",
            school = "physical",

            startsCombat = false,

            toggle = "defensives",

            handler = function ()
                applyBuff( "deterrence" )
            end,
        },

        dire_beast = {
            id = 120679,
            cast = 0,
            cooldown = 20,
            gcd = "spell",
            school = "nature",

            talent = "dire_beast",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "dire_beast" )
                -- summonPet( "dire_beast", 15 ) handled by the system
            end,
        },

        disengage = {
            id = 781,
            cast = 0,
            cooldown = function () return talent.crouching_tiger_hidden_chimera.enabled and 14 or 20 end,
            gcd = "off",
            school = "physical",

            startsCombat = false,

            handler = function ()
                if talent.posthaste.enabled then applyBuff( "posthaste" ) end
                if talent.narrow_escape.enabled then
                    -- Apply web trap effect
                end
            end,
        },

        dismiss_pet = {
            id = 2641,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,

            usable = function () return pet.exists, "requires an active pet" end,

            handler = function ()
                -- dismissPet() handled by the system
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
                applyDebuff( "target", "explosive_trap" )
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

        focus_fire = {
            id = 82692,
            cast = 0,
            cooldown = 20,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            usable = function () 
                return state.should_focus_fire and true or false, "requires pet with frenzy stacks" 
            end,

            handler = function ()
                local stacks = buff.frenzy.stack
                removeBuff( "frenzy" )
                
                -- Focus Fire converts frenzy stacks to haste buff
                -- Each stack provides 3% haste for 20 seconds
                if stacks > 0 then
                    applyBuff( "focus_fire", 20, stacks )
                end
            end,
        },

        fervor = {
            id = 82726,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "nature",

            spend = -50,
            spendType = "focus",

            talent = "fervor",
            startsCombat = false,

            handler = function ()
                applyBuff( "fervor" )
            end,
        },

        freezing_trap = {
            id = 1499,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "frost",

            startsCombat = false,

            handler = function ()
                -- Freezing trap effects
            end,
        },

        glaive_toss = {
            id = 117050,
            cast = 3,
            cooldown = 6,
            gcd = "spell",
            school = "physical",

            spend = 15,
            spendType = "focus",

            talent = "glaive_toss",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "glaive_toss" )
            end,
        },

        hunters_mark = {
            id = 1130,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                applyDebuff( "target", "hunters_mark" )
            end,
            copy = 1130,    
        },

        intimidation = {
            id = 19577,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            talent = "intimidation",
            startsCombat = true,
            toggle = "interrupts",

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                applyDebuff( "target", "intimidation" )
            end,
        },

        kill_command = {
            id = 34026,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            school = "physical",

            spend = 25,
            spendType = "focus",

            startsCombat = true,

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                -- Kill Command effects
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
                -- Basic cat attack with frenzy generation (10% chance)
                if state.can_generate_frenzy and math.random() <= 0.1 then
                    applyBuff( "frenzy", 8, min( 5, buff.frenzy.stack + 1 ) )
                end
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
                -- Basic canine attack with frenzy generation (10% chance)
                if state.can_generate_frenzy and math.random() <= 0.1 then
                    applyBuff( "frenzy", 8, min( 5, buff.frenzy.stack + 1 ) )
                end
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

        kill_shot = {
            id = 53351,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            school = "physical",

            spend = 25,
            spendType = "focus",

            startsCombat = true,

            usable = function () return target.health_pct <= 20, "requires target below 20% health" end,

            handler = function ()
                -- Kill Shot effects
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

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                applyDebuff( "target", "lynx_rush" )
            end,
        },

        masters_call = {
            id = 53271,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            usable = function () return pet.alive, "requires a living pet" end,

            handler = function ()
                -- Masters Call removes movement impairing effects
            end,
        },

        mend_pet = {
            id = 136,
            cast = 10,
            channeled = true,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            usable = function ()
                if not pet.alive then return false, "requires a living pet" end
                if settings.pet_healing > 0 and pet.health_pct > settings.pet_healing then return false, "pet health is above threshold" end
                return true
            end,

            start = function ()
                applyBuff( "mend_pet" )
            end,
        },

        misdirection = {
            id = 34477,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            school = "physical",

            startsCombat = false,

            handler = function ()
                applyBuff( "misdirection" )
            end,
        },

        multi_shot = {
            id = 2643,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = function () return buff.thrill_of_the_hunt.up and 20 or 40 end, -- ToTH reduces by 20
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- ToTH procs are handled by the game; don't simulate.
                
                -- Apply Beast Cleave buff when Multi-Shot is used
                if pet.alive then
                    applyBuff( "beast_cleave", 4 )
                end
            end,
        },

        powershot = {
            id = 109259,
            cast = 2.5,
            cooldown = 45,
            gcd = "spell",
            school = "physical",

            spend = 45,
            spendType = "focus",

            talent = "powershot",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "player", "powershot" )
            end,
        },

        rapid_fire = {
            id = 3045,
            cast = 3,
            channeled = true,
            cooldown = 300,
            gcd = "spell",
            school = "physical",

            startsCombat = true,
            toggle = "cooldowns",

            start = function ()
                applyBuff( "rapid_fire" )
            end,
        },

        scare_beast = {
            id = 1513,
            cast = 1.5,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            spend = 25,
            spendType = "focus",

            startsCombat = false,

            usable = function() return target.is_beast, "requires a beast target" end,

            handler = function ()
                applyDebuff( "target", "scare_beast" )
            end,
        },

        scatter_shot = {
            id = 19503,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "physical",

            startsCombat = false,

            handler = function ()
                applyDebuff( "target", "scatter_shot" )
            end,
        },

        serpent_sting = {
            id = 1978,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            spend = 25,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "serpent_sting" )
            end,
        },

        silencing_shot = {
            id = 34490,
            cast = 0,
            cooldown = 20,
            gcd = "spell",
            school = "physical",

            talent = "silencing_shot",
            startsCombat = true,
            toggle = "interrupts",

            debuff = "casting",
            readyTime = state.timeToInterrupt,

            handler = function ()
                applyDebuff( "target", "silencing_shot" )
                -- interrupt() handled by the system
            end,
        },

        steady_shot = {
            id = 56641,
            cast = function() return 2.0 / haste end,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = -14,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- No Thrill of the Hunt consumption/proc simulation on generators.
            end,
        },



        thrill_of_the_hunt_active = {
            id = 34720, -- Corrected ID to match talent
            cast = 0,
            cooldown = 0,
            gcd = "off",

            startsCombat = false,

            usable = function () return buff.thrill_of_the_hunt.up, "requires thrill of the hunt buff" end,

            handler = function ()
                -- Active version of thrill of the hunt
            end,
        },

        wing_clip = {
            id = 2974,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = 20,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "wing_clip" )
            end,
        },

        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            talent = "wyvern_sting",
            startsCombat = true,
            toggle = "interrupts",

            handler = function ()
                applyDebuff( "target", "wyvern_sting" )
            end,
        },

        widow_venom = {
            id = 82654,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",
            
            spend = 15,
            spendType = "focus",
            
            startsCombat = true,
            
            handler = function ()
                applyDebuff( "target", "widow_venom" )
            end,
        },
    } )

    spec:RegisterRanges( "arcane_shot", "kill_command", "wing_clip" )

    spec:RegisterOptions( {
        enabled = true,

        aoe = 3,
        cycle = false,

        nameplates = false,
        nameplateRange = 40,
        rangeFilter = false,

        damage = true,
        damageExpiration = 3,

        potion = "tempered_potion",
        package = "Beast Mastery",
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

    spec:RegisterSetting( "avoid_bw_overlap", false, {
        name = strformat( "Avoid %s Overlap", Hekili:GetSpellLinkWithTexture( spec.abilities.bestial_wrath.id ) ),
        desc = strformat( "If checked, %s will not be recommended if the buff is already active.", Hekili:GetSpellLinkWithTexture( spec.abilities.bestial_wrath.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "mark_any", false, {
        name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "check_pet_range", false, {
        name = strformat( "Check Pet Range for %s", Hekili:GetSpellLinkWithTexture( spec.abilities.kill_command.id ) ),
        desc = function ()
            return strformat( "If checked, %s will only be recommended if your pet is in range of your target.\n\n" ..
                            "Requires |c" .. ( state.settings.petbased and "FF00FF00" or "FFFF0000" ) .. "Pet-Based Target Detection|r",
                            Hekili:GetSpellLinkWithTexture( spec.abilities.kill_command.id ) )
        end,
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "thrill_of_the_hunt_priority", true, {
        name = strformat( "Prioritize %s Usage", Hekili:GetSpellLinkWithTexture( spec.talents.thrill_of_the_hunt.id ) ),
        desc = strformat( "If checked, %s or %s will be prioritized when %s is active to use the Focus-free proc.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.steady_shot.id ),
            Hekili:GetSpellLinkWithTexture( spec.abilities.cobra_shot.id ),
            Hekili:GetSpellLinkWithTexture( spec.talents.thrill_of_the_hunt.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "focus_dump_threshold", 80, {
        name = "Focus Dump Threshold",
        desc = strformat( "Focus level at which to prioritize spending abilities like %s and %s to avoid Focus capping.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.arcane_shot.id ),
            Hekili:GetSpellLinkWithTexture( spec.abilities.multi_shot.id ) ),
        type = "range",
        min = 50,
        max = 120,
        step = 5,
        width = 1.5
    } )

    spec:RegisterSetting( "pet_to_call", 1, {
        name = "Pet to Call",
        desc = "Which pet slot to call when no pet is active. Set to 0 to disable automatic pet calling.",
        type = "range",
        min = 0,
        max = 5,
        step = 1,
        width = 1.5
    } )

    spec:RegisterPack( "Beast Mastery", 20250816, [[Hekili:D31EZTnos(plPM6uS3jrrpSCs212v5K4zMKltsQyp1w3)ijksilEMIulFyhpLl9z)6gpiEqaqkBNzZE1uzsmfqJUbA0p)j6PdNEX0ZJckjt)0ObJMm4vdpS)WjJE9OdMEE5TBitpFtq4vbxc)J0G1W))nKGIYTZ)D4)tYVf)4BtYcIqYuKvLhcdz65lQItkFF60fwP9WxdJDdjeE8KXtpFvCueHnwsr40ZVyvCX254Fc2oNV6BNNTe(5WY4S0TZtIlkHpEzw(25)g5Q4K4(tpN(qKnY2qsj5W)6tuHJKgSiHen9ntpNnFyfRsbMVy26G8RyRAE8g2h95VC2No7RBN)1pFXPx8(p)PTZ37xIZrjE4GTZliHzPrf7VD(PB2KClS6uk90cCdj)QNTDE5kcWGVHuughKSD()mpOC125p)KTZ)VJtGh82S1RdsJyp6RbBIH)jSae2doVmy9gsK4NUnnytb8dNVjpo9YIxuc)1vKYIxKhecKV4fBYyBi4OFhLk8Jh8b)Asq81WJUiROGtqsoS3uIRdqp2ZonpmifxJvzLtph2ia5joy657HsBjoUI(4(0SGuqEV7oqedYVKu2pUy2ckLHDJESZMRjZIYk7RU9UD(XBNpGoc(8kJxtMvMnlkgwvGbgozAjOjyCujzKnWCcsOssp8mpScwZtaQozG8eDbBdF2n4(nsVXDKElQwUSV2S7xTrsxq3kzwi7mdj7bizfFyoE8nBjSVRUuWOMOoQc(zQXyo0LUjSsfWSsWJd2paJ(LognxJyOyc1)mmNx5FoJmMZiCoVwLZxKKLbYxfEnxJ3hoqByWznj)kqtXCyM3)ywqUooFnjf0EGtKzmnyjX4)moB3QeLbjGAC)iyNF2cuHVVyy10r(zuA5wDGtRlPxwa9YIcbXm13af1AYRmCk9pWj9FY25reQwwb723Sc8sLMwM2NqP3eN0ZQcRjRowHvdOxWNvG3VX)dOaypZN5rnLEDZJVPIAlCZQa0Uug801X)za3i025)Xg0CpSZvMTD(6GYWv4nm6uUjonk7gCZOMCBN))aEmAmc4ctoAEpa(trgom8FDBw125RcUM006Aoji6w2AwHSf1(Asa1hbykkorB2WqGpoUKpU4s06n5BBafMO(OnY)vfjnK83bB1utP6RwFXJ1mNJZBtWADRPaTtrEYWW)nupeuE2bX2vRvEnF2r9f6tcZYsGJG0(QAa9ZjRdItlygRDPx5XGl)gwWS1v5rK8zzlNfMNDJ(9SwSd3yY1gJ9TKj3M(Tz5vfR0wQUSLwVW1KO2UULlmHzlYdy7e6xx(f2wmZbpOnamf88Gem0bY3ctQIqEAzE266Bbyympd1vtJOm8IB5NuuhnGp1uiCO1uV4OYvW1zyievfuh6rv50)wxNvDNbyYQKOzkCm1Ma5BKWkiqT7NvHZyZU2UWEmx9aZtsWB0Jg8FbsejiPC1(UvU5XhWg3SnHW8p6yCY(vWDontL8dg0rL8b9p8EOM3CN1M(bD3ED210JqFB3byeYLO(oes5SWveszWkJ99FNthUPSkWuxC5TgEFajCrqjv0FcxD3kTB1scFJocuqdadKcNIckZ9Ybbid74fO3ruG1Umz8zTz2Wy5Wt1xP6HVGKEjMzIxtbI9A78DRUMnp6IilHyxajW3zxebw8C0lIXb27eZgUQKhNbmzmPqLBJtHJlGhMffSgeTztyAKmLBio8VTD(FdvqpW)rLjzg7Gmk65ljXxMolISJXpJ)u5kWBgETdj5R43Ltzbeki)64cmKSqE0D4LJS2n3yXK6V)hF8I3)8lo9R)6zxOLM2PzNTpniK3NsnSwiSOarrCtmekc1Y4KFE78ZsjRH9DWd)VxLug)CMZ6cQd8vySgRIVCfHgNd7qcmbVh(8neiALlRIJiWkn65hOskqFnnkihUgMNvYJicw2v1PK92ecn(d0od4iiGQD0bZy(pP1pnEId)zQzOrySm94AIdZ7wuaShRANc01B2FdSYBOKde)2Wey00zwGQkEVP3cdyUe04ESVXGol8eDURWawJAt20z)uwjgpP4k)Fk0cG)WDxRPHWIq8ISl(nbV1iGo4khEEXTGJjCletUBib9z5anlKs6PwY7munJFBhdSK(T8HTSbslmW(TYt28sJlyth32w)jw39TKW89lHVUSUgPcAM1DJfErqEoyt21IEyNeworMksz36cALggURHeFsYOEKlZd20YL1rkvCrFItRRkGvorr(E5RDAm6ri8SgLCWt8zE4dubSLtaTad8vSc(6wuIz89iSWkeAQTsBigNEroBykvHd5QcQtOpEe4tvy8adBCxy6RDQT6I8xRxeUHClUrknkz4Scsje2NVy6KfusxWphLAK9YjScGxWdhhCnxWlsTzfleL6GgqXnq6SXRlyrw0mSahL6s)YIYNZRgI6NQhoq9DjC75W2I5NU8lj5xNLBFP9rCPXniYYLXHyvxmlDlJ2(J50QkHCPafGrUUz6oEb9qNAtE0l(Hz0sURxNIPVxn4ESsnkFhKYq(SfzPvfKcVjqQmrJRQXOAxbrK34M8Sq9I51mEdykdpy2bBcTu9Oj7sI1TxSk6Anz2i5AvFs19WvTttf()(K5xaeIHTTC9euaXvM1TmdIIBbl3R9weCdM2Au8SpbRmFsvblQpLMYOzy8iz4e69SrkKYYTBEOuVneaB0WbWSHMf9znbOzA4T0ZhmIwrLPmSNRFpRUPsinbofPpnqZH7AANAPkvRf6kfiLafjPrOezZ6GMe(L8yWxiiFV7lNltRZyRH9dZWY2Pz4eoiywMgWAn5m25oV5KEnz0MbcPP12f2M8OcZyZfOLue6eTemT32v5LcwRYP)qQFqcpTniwcGw37ECzf9yh9EZifV)ZDtpWwWCJ04dSoi(JE2sOIJ6OqgMb7M1AU(dq2rLYM0XLQUOM(dhURv4AChxwzb58fmSxsGwI014Cg3Qx6O5zM6ZytoH5iWRJ6ouPxgod(71LkGd)cLoU9HkSPcJE5ZW00gbPsSD(xYjpx4hIE5wgyQhZ1ERqSWQZ6mKHyrcch88W9DFQBNURcU5kfIkAuK2yIZHTA6afe2Xghog)Uq6etyzeswqDd4AT6B6yg(JaL5CCMrOnkEC96M4VseAypRsl(k2Lw8xQ61WZfeDWDyur9ZU403)XZE325V9ZF(JV7Z)Zpb3jo)0F9STZ1B(wHsp1Wa0C0tn86SwN1IxVjlVedyomlDzsCiMuxd89GvcUOcxiECX0lAM4TjQkNAigUJcN5xwxHyT2)6oONMHC7pVizIXTeAo4qzSVyavb6I2UVoaMGDEA73lq0Avs4nUFdOcgdu8z0o7hELqOXSoKqAQvV6mn72cn6ewv78frmdVrolVDnAD0ddqcmlUuwEtm6HKMb)Y4lxHnTTGwptAg)AyAqt6Cwqf6j1EoRGVImXDwkI8fN6(2S0iekN1UGLj4bBNFb10BHjkY4YAwQCNheZ4icRf2liGSs81Uz)LVypRfhqub42oRzvmBFBgjfcoV2cgnLN(qP0Xk3o)YfnrcqgVesWQl9t3Dbs2tst(fwuOCC4UVV4U9KjpTnamWrc(Dy4rKkzFjOG1NXfqyJlJrTZ)3k8mLBwJZAHbB2yubUw6VGImzwpJ2Y73vwbnb3HnT0jkAPNITUdNct0FloPUyakfSRNseau6MauLJEDLAmYY5QFqR0PlRwtjFFB51i2pKyorFF4JWZ3o)RWh48Qj70oKQRk6(OURQfvGmhLL(u8Vijb3ArQ7cUz8l7TD3LBNEFB5Fj2guBSIbk0saNgOx184RifQ678ZyrIA4znY9mnOdv0GmahR9DtqZjMriQscTdtpNDSAzxRtDuYAQE1b6W7QJH0YEA7MJzh4kH9yHj7w3NehUYGKQpzTLq7y(jzJKlLH8Dde0yt7xFr88hPJG61XL8DWeRPNwFaOG4vJaDy3PcwGqSjUUg)7y4lUnjyn71hknvIGUgIU(YUvIM4h8k3eoYnW0QXQo6XEvhXsXWEzL8KUHCcMboOMqHk0qIc2ukbYhcVJ8LbHAdcZRWd23y32YjP)5T95rjR1Tw31dEVozSDIs0h8LrR9j9fgJDDZGdl9WMfPSG9Tuywb7lPGs)NEiUhnba)oE1W6vAEgNQve7EaaP3sd5vcYhjqUCcbAeCMjKNlGJKCUAGHwb5X8VDjM5pgVeDVvkmcJzr6dhX6pLdj5LsyrH5e3eHM9Xsh9(LwwD0O3ISkE(XldyrEcJCVec6fTeoTOEz5FnzaTEYYY95OY(Ty)uySrnNzaxAGuHviW5kRDJHl6A6ooJ6V811twLGwsW67dsQm0p6uhOUxFfaCx1OwBgQc8i07fAN6sjhGgDlQER5OyjvMUhyTV0cSKdrxYetjLLXVSrYHwceFxdi2wO7wcST9WvSfXKTagBqPD4RcJ7ga4oow7bL7lskNqI)mbUHWGNc2qRKQWC5PzNHbaIM((m2nAmIlw0HstMCKUdojraNt(2MCW2d8jAoNAG1NwcVQjgDuRiKkEBkB0UapUqGibIxhhXBBOEKVuuJWaSnpws1Yq(vcFBznTq)f82KUxvAr1gAbj5LXuuEY9v)odCDCGcXjjfKBwrSMoGkhQPBZnIgguWm(7U6WT813RrdG5nerQPOwUB6g81GaJFe)Bn6aiE0BcYrOswGL8GiKAEobpL1t1NIiW5FvHFnEWV3qy7xdQkZwZ8ghcBoxsk6V9dFmg94mc8Y(hQBMIugFQMf)NctGUIlZsahL0TIGQCSScW9ts93MOuE9xeuHvgzAU2SXrDBVmRkvB0rr0Oackdweuao()anecnoaE2hSiZ06l2vr(hsjqTBz)WkisCVO(ak4u0FaBe2KtoUr(Hve7YzL1CO6QeXUWn05fojX)H42g(mwkso2mcYiDv0)3UWyJ)1Ya6)WLeE3d7Qu0MQ4pG2(F)Abxo8a91afiWnAv5kSfhNVUAzE8viMdYwgNao7)jXRNGMWg4d)KxKd8b8)(PodGGTFGXwf9RX7WpF8lScHGNfV84N4fHb9EchBb9yTyVleh70UlkZ7BFVN0n0f0LLREsTUMTaMauwDlJYaJORtnsbSpA1gZJJFVgyd4U70XfW(9yLrObIaoEqVMX6DYWj2xyw78Fg24)JT03FUQKFurwt52PhkBwZmVh7PkiJSwGveJJo(WAPtGpcgh6gpJQCxZdfwOT9SHRXJhQovbUdXjkNNosgpAYaUwtJIMjUsAdtIn4q2psHOeBNKfJmU04MXrdh0(uSGoqC((R2iS)6uaABbRnN3(qTJEJwNgnQzNAq8Ty3q(R9faInajp)IfVjjNC8O2NPMx5M04Ooqcbc8Wz3amFNC8K2Pqny6qs0ePENirP3FBq)XTtp9uLBF8Q5eWpn64lKhCO))Y3jpsJUSRW)vBQVEv1UTOBdJEBeuWgyzAQLpuFw(TsiPGe9rw(qbEDS8rGs0mWVX6NHTs4yANeADuIgw11boY2gvDhhSUlk6eNLpSvxPnMHS2Eut7orBtZzQuipLPAP2FItxRkfAfHM6r013ERMZvPKXUDQZx8Xt4MdCJ3p8t)(b5p2Q)9e3FYDOA)GD8wxpFDe4KHd65Tw(hnMlCpEG5ZUOiVh784(U78hDbyzYEqDdf6hpqG6zNZfgzyxuAyUC8GE75qCAayVJgpyFoR2a8Du97ho(7SldD0srV90qK3jhFWG2ouoAIqIEWiRZoRZAuJcBR3JholFeCt4U7SEouVJ)ibxo7SPn7zwXrxpo)(QwUzEYG(hQPRmrxx57dk4CiCMnJt54WzV8A7AHrEzIJPVp4CZUCv3Wof5Pr3(6jn66sIA1ULq42vSRPE(FO(5)dfdB23rUxbgWeT7nq1C47JrpfUWa9Aco4qHbyn8QD3D8GERtdBS4q4bH7m7mBDdBvy3g93vWWhmP2NRFCL5yJPoctpEsTFhZvugIOsFKiO9OQ)Es8r3dI3mMX7dQUKmP1amrhy1p3sgqQO(cIMZr1t6TxlwyMW99PJURJg2FshyqlPkPvQhRy8A3TU3gB0b9AryEp6V0fKCNL6ETdXpvVNz(kzOxRfoRnwOT4GADb6zeBNAc72xsjckWL1xEghnCuBeZDPaAZ7zBu2i0lUvw14RCsyQ603lm9Xuv)HbwFi78FAi7t1fGsfsfQtspUgG(7OJhnOL5AvvSLIx3Gs3JkGysID4s2HUPI97aV81DjhdN08(e1VBY1MbmEErJFPBsSJXR7MqDkEn3tVJUdCtGohMnR5uDc1C06LVZaNRRkMnavNNlfsmZPmt1xbw8Uc(GEzoIu4r795isShHxPJY9KGmYoAKszg7GPPE6z5C0etcQBHs7LH1Xd9zXYARbgySEk92Y665J(6ucYpZuwo(a65Yd(9NOjlkFxbwhOP9k1u47nxOxIUN520D3TxhK39337AwNa5G7UR(F2yFSHkqNn2iZPVDIUlPN3kX0FDcI0SXu69exVZcTPO28ILthKMxG2fpMms3IHYgRqZstqliGX9O2mI2nYIvpQPPt9LsRJIwSq46neOTn(Xn24)(AaIAKG5nX6RdBj3i6j(p7dCsmiQyf6okVguSrtJ3U1kg8L9GFOulU5lkBRuT(1CTf6D0XVYbNOQoAbkaaB4mkvwBiS9IQwUw14eazW6x214I1gOboWoruE7tBJkJnOYH2PI6lzADxN4)I9AQ(Ob9Fvp(RNAr1a9IfFAz62z44)pAho(szqhMeGGOclFf7R2qRV4ochP(2UYmXZk5eptCOAPw(zFVXaLlHkgoAA1L5Rv9TjOsFm3b7UgRIzqtYLr8Ie0wobger)AJkj4CQ)7mpU)UrbP4pE)6rXOGg)763qkYJq6MJ3OMBjFEbb2n0i0IQ6ql0)(KkDxz(DmRyxK1SA4D)3yj)Jh3FJL0ucBnvuEAYD)xejY1G)l)eVArTK6MKeg6rwNNmk(DXKNCnAzZG(TOA6)3p]] )

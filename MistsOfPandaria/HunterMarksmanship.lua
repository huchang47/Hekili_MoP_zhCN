    -- HunterSurvival.lua
    -- August 2025 by Smufrik & SaschaDaSilva

-- Early return if not a Hunter
if select(2, UnitClass('player')) ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]

-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
    

local class = Hekili.Class
local state = Hekili.State

-- Custom variable to track if the last spell cast was Steady Shot.
local mm_last_spell_was_steady = false

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local spec = Hekili:NewSpecialization( 254, true )



    -- Use MoP power type numbers instead of Enum
    -- Focus = 2 in MoP Classic
    spec:RegisterResource( 2, {
    steady_shot = {
        resource = "focus",
            cast = function(x) return x > 0 and x or nil end,
            aura = function(x)
                -- Only predict focus if casting Steady Shot
                if state.buff.casting.up and state.casting and state.casting.name == "steady_shot" then
                    return "casting"
                end
                return nil
            end,
        last = function()
                return state.buff.casting.applied
            end,
            interval = function() return state.buff.casting.duration end,
            value = function()
                -- Steady Shot provides 14 focus (17 with Steady Focus active)
                if state.buff.steady_focus and state.buff.steady_focus.up then
                    return 17
                end
                return 14
            end,
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

        interval = 1,
            value = 5,
            duration = 10,
        },
    } )

    -- Talents
spec:RegisterTalents( {
        -- Tier 1 (Level 15)
        posthaste = { 1, 1, 109215 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 60% for 4 sec.
        narrow_escape = { 1, 2, 109298 }, -- When Disengage is activated, you also activate a web trap which encases all targets within 8 yards in sticky webs, preventing movement for 8 sec. Damage caused may interrupt the effect.
        crouching_tiger_hidden_chimera = { 1, 3, 118675 }, -- Reduces the cooldown of Disengage by 6 sec and Deterrence by 10 sec.

        -- Tier 2 (Level 30)
        binding_shot = { 2, 1, 109248 }, -- Your next Arcane Shot, Chimera Shot, or Multi-Shot also deals 50% of its damage to all other enemies within 8 yards of the target, and reduces the movement speed of those enemies by 50% for 4 sec.
        wyvern_sting = { 2, 2, 19386 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes 0 Nature damage over 6 sec. Only one Sting per Hunter can be active on the target at a time.
        intimidation = { 2, 3, 19577 }, -- Command your pet to intimidate the target, causing a high amount of threat and reducing the target's movement speed by 50% for 3 sec.

        -- Tier 3 (Level 45)
        exhilaration = { 3, 1, 109260 }, -- Instantly heals you for 30% of your total health.
        aspect_of_the_iron_hawk = { 3, 2, 109260 }, -- Reduces all damage taken by 15%.
        spirit_bond = { 3, 3, 109212 }, -- While your pet is active, you and your pet will regenerate 2% of total health every 2 sec, and your pet will grow to 130% of normal size.

        -- Tier 4 (Level 60)
        fervor = { 4, 1, 82726 }, -- Instantly resets the cooldown on your Kill Command and causes you and your pet to generate 50 Focus over 3 sec.
        dire_beast = { 4, 2, 120679 }, -- Summons a powerful wild beast that attacks your target and roars, increasing your Focus regeneration by 50% for 8 sec.
        thrill_of_the_hunt = { 4, 3, 34720 }, -- You have a 30% chance when you fire a ranged attack that costs Focus to reduce the Focus cost of your next 3 Arcane Shots or Multi-Shots by 20.

        -- Tier 5 (Level 75)
        a_murder_of_crows = { 5, 1, 131894 }, -- Sends a murder of crows to attack the target, dealing 0 Physical damage over 15 sec. If the target dies while under attack, A Murder of Crows' cooldown is reset.
        blink_strikes = { 5, 2, 109304 }, -- Your pet's Basic Attacks deal 50% additional damage, and your pet can now use Blink Strike, teleporting to the target and dealing 0 Physical damage.
        lynx_rush = { 5, 3, 120697 }, -- Your pet charges your target, dealing 0 Physical damage and causing the target to bleed for 0 Physical damage over 8 sec.

        -- Tier 6 (Level 90)
        glaive_toss = { 6, 1, 117050 }, -- Throws a glaive at the target, dealing 0 Physical damage to the target and 0 Physical damage to all enemies in a line between you and the target. The glaive returns to you, damaging enemies in its path again.
        powershot = { 6, 2, 109259 }, -- A powerful shot that deals 0 Physical damage and reduces the target's movement speed by 50% for 6 sec.
        barrage = { 6, 3, 120360 }, -- Rapidly fires a spray of shots for 3 sec, dealing 0 Physical damage to all enemies in front of you.
        
    } )

    -- Auras
spec:RegisterAuras( {
        -- Common aspects
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
        aspect_of_the_iron_hawk = {
            id = 109260,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "player", 109260 )
                
                if name then
                    t.name = name
                t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 3600
                t.caster = "player"
                return
            end
                
            t.count = 0
            t.applied = 0
                t.expires = 0
            t.caster = "nobody"
        end,
    },
        casting = {
            id = 116951,
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
        cobra_shot = {
            id = 19386,
        duration = 6,
        max_stack = 1
    },

        disengage = {
            id = 781,
            duration = 20,
            max_stack = 1
        },

        focus_fire = {
            id = 82692,
            duration = 20,
            max_stack = 1
        },
        kill_command = {
            id = 34026,
            duration = 5,
        max_stack = 1
    },
        multi_shot = {
            id = 2643,
            duration = 4,
        max_stack = 1
    },
        rapid_fire = {
            id = 3045,
        duration = 15,
        max_stack = 1
    },
        -- Master Marksman (Aimed Shot!); expose as master_marksman for APL compatibility
        master_marksman = {
            -- Ready, Set, Aim... buff for instant/free Aimed Shot
            id = 82926,
            duration = 8,
            max_stack = 1
        },
        master_marksman_counter = {
            -- Counter for Master Marksman stacks (hidden)
            id = 82925,
            duration = 30,
            max_stack = 2
        },
    steady_focus = {
        id = 53220,
        duration = 20,
        max_stack = 1,
        haste = 0.15
    
    },

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
    
        hunters_mark = {
            id = 1130,
            duration = 300,
        type = "Ranged",
        max_stack = 1
    },



    serpent_sting = { --- Debuff
        id = 118253,    
        duration = 15,
        tick_time = 3,
        type = "Ranged",
        max_stack = 1
    },

        concussive_shot = {
            id = 5116,
            duration = 6,
            max_stack = 1
        },

        deterrence = {
            id = 19263,
            duration = 5,
            max_stack = 1
        },

        mend_pet = {
            id = 136,
            duration = 10,
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
    
        misdirection = {
            id = 34477,
            duration = 8,
            max_stack = 1
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        duration = 3600,
            max_stack = 1
        },

        a_murder_of_crows = {
            id = 131894,
            duration = 30,
            max_stack = 1
        },

        lynx_rush = {
            id = 120697,
            duration = 4,
            max_stack = 1
        },

        barrage = {
            id = 120360,
            duration = 3,
            max_stack = 1
        },

        black_arrow = {
            id = 3674,
            duration = 15,
        max_stack = 1,
            debuff = true
        },

        lock_and_load = {
        id = 56453,
        duration = 8,
        max_stack = 3,
        },

        piercing_shots = {
            id = 82924,
            duration = 8,
            max_stack = 1
        },


        blink_strikes = {
            id = 109304,
            duration = 0,
            max_stack = 1
        },

        -- Tier 2 Talent Auras (Active abilities only)
        binding_shot = {
            id = 109248,
            duration = 4,
            max_stack = 1
        },
    
    wyvern_sting = {
        id = 19386,
        duration = 30,
            max_stack = 1
        },

        intimidation = {
            id = 19577,
            duration = 3,
            max_stack = 1
        },

        -- Tier 3 Talent Auras (Active abilities only)
        exhilaration = {
            id = 109260,
            duration = 0,
            max_stack = 1
        },

        -- Tier 4 Talent Auras (Active abilities only)
        fervor = {
            id = 82726,
            duration = 3,
            max_stack = 1
        },



        counter_shot = {
            id = 147362,
            duration = 3,
            mechanic = "interrupt",
            max_stack = 1
        },

        silencing_shot = {
            id = 34490,
            duration = 3,
            max_stack = 1
        },

        explosive_shot = {
            id = 53301,
            duration = 4, -- DoT duration
            max_stack = 1
        },

        stampede = {
            id = 121818,
            duration = 12,
        max_stack = 1,
            
        },

        explosive_trap = {
            id = 13813,
            duration = 20,
        max_stack = 1
    },
        -- Dire Beast focus regen aura (used by resources)
        dire_beast = {
            id = 120694,
            duration = 15,
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

        -- Tier set bonuses for MoP (for APL expressions that reference them)
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



        
    } )

    spec:RegisterStateFunction( "apply_aspect", function( name )
        removeBuff( "aspect_of_the_hawk" )
        removeBuff( "aspect_of_the_iron_hawk" )
        removeBuff( "aspect_of_the_cheetah" )
        removeBuff( "aspect_of_the_pack" )

        if name then applyBuff( name ) end
    end )



    -- Abilities
    spec:RegisterAbilities( {
       arcane_shot = {
            id = 3044,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
            spend = function () return buff.thrill_of_the_hunt.up and 10 or 30 end,
        spendType = "focus",
        startsCombat = true,
        handler = function ()
                mm_last_spell_was_steady = false
        end,
    },
    
        aspect_of_the_hawk = {
            id = 13165,
            cast = 0,
        cooldown = 0,
        gcd = "spell",
            
            startsCombat = false,
            texture = 136076,
        
        handler = function ()
                apply_aspect( "aspect_of_the_hawk" )
            end,
        },
        
        black_arrow = {
            id = 3674,
            cast = 0,
            cooldown = 30,
            gcd = "spell",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "black_arrow" )
        end,
    },
    
    cobra_shot = {
        id = 77767,
            cast = function() return 2.0 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = -14,
        spendType = "focus",
        startsCombat = true,
        
        handler = function ()
                -- Cobra Shot maintains Serpent Sting in MoP (key Survival mechanic)
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                    if debuff.serpent_sting.expires > query_time + 15 then
                        debuff.serpent_sting.expires = query_time + 15 -- Cap at max duration
                end
            end
        end,
    },
    

        disengage = {
            id = 781,
        cast = 0,
            cooldown = 20,
            gcd = "off",

            startsCombat = false,
        
        handler = function ()
                applyBuff( "disengage" )
        end,
    },
    


        kill_command = {
            id = 34026,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

            spend = 40,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
                applyBuff( "kill_command" )
        end,
    },
    
        multi_shot = {
            id = 2643,
        cast = 0,
            cooldown = 0,
        gcd = "spell",

            spend = function () return buff.thrill_of_the_hunt.up and 20 or 40 end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
                -- Apply Multi-Shot buff for tracking
                applyBuff( "multi_shot" )
                
                -- Serpent Spread: Multi-Shot spreads Serpent Sting to all targets hit (Survival passive)
                if debuff.serpent_sting.up then
                    -- In MoP, Multi-Shot spreads Serpent Sting to all enemies within range
                    applyDebuff( "target", "serpent_sting" )
                    -- Note: In a real implementation, this would spread to all targets in AoE range
                end
        end,
    },
    
        rapid_fire = {
            id = 3045,
        cast = 0,
            cooldown = 300,
        gcd = "off",
        
        startsCombat = false,
            toggle = "cooldowns",
        
        handler = function ()
                applyBuff( "rapid_fire" )
        end,
    },
    
        steady_shot = {
            id = 56641,
            cast = function() return 2.0 / haste end,
            cooldown = 0,
        gcd = "spell",
            school = "physical",

            spend = function()
                -- Steady Shot provides 14 focus (17 with Steady Focus)
                return buff.steady_focus.up and -17 or -14
            end,
            spendType = "focus",

            startsCombat = true,
            texture = 132213,
        
        handler = function ()
                -- Master Marksman: 50% chance to gain a stack on Steady Shot cast
                -- At 2 stacks, gain Ready, Set, Aim... buff for instant free Aimed Shot
                if talent.master_marksman.enabled then
                    if math.random() < 0.5 then
                        if buff.master_marksman_counter.stack == 1 then
                            removeBuff("master_marksman_counter")
                            applyBuff("master_marksman", 8) -- Ready, Set, Aim...
                        else
                            applyBuff("master_marksman_counter")
                        end
                    end
                end
        end,
    },
    
        serpent_sting = {
            id = 1978,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        school = "nature",
            
        spend = 15,
        spendType = "focus",
            
        startsCombat = true,

        handler = function ()
                applyDebuff( "target", "serpent_sting" )
        end,
    },
    
        explosive_shot = {
            id = 53301,
        cast = 0,
            cooldown = 6, -- 6-second cooldown in MoP
        gcd = "spell",
        
            spend = function() return buff.lock_and_load.up and 0 or 25 end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
                -- Apply Explosive Shot DoT (fires a shot that explodes after a delay)
                applyDebuff( "target", "explosive_shot" )
                
                -- Handle Lock and Load charge consumption
                if buff.lock_and_load.up then
                    -- Consume one charge when Explosive Shot is cast during Lock and Load
                    removeBuff( "lock_and_load", 1 )
                end
                
                -- Explosive Shot is the signature Survival ability
                -- It does high fire damage and is central to the rotation
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
    

        tranquilizing_shot = {
            id = 19801,
        cast = 0,
            cooldown = 8,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
                -- Dispel magic effect
        end,
    },
    
        counter_shot = {
            id = 147362,
            cast = 0,
            cooldown = 24,
            gcd = "spell",
            school = "physical",

            startsCombat = true,
            toggle = "interrupts",

            debuff = "casting",
            readyTime = state.timeToInterrupt,

            handler = function ()
                applyDebuff( "target", "counter_shot" )
                -- interrupt() handled by the system
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
    
        hunters_mark = {
            id = 1130,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
            startsCombat = false,
        
        handler = function ()
                applyDebuff( "target", "hunters_mark", 300 )
        end,
    },
    
        aimed_shot = {
            id = 19434,
            cast = function()
                -- Master Marksman makes Aimed Shot instant cast
                if buff.master_marksman.up then
                    return 0
                end
                return 2.5 / haste
            end,
            cooldown = 0,
            gcd = "spell",
            
            spend = function()
                -- Master Marksman makes Aimed Shot free
                return buff.master_marksman.up and 0 or 50
            end,
            spendType = "focus",
            
            startsCombat = true,
        
        handler = function ()
                -- Consume Master Marksman buff if present
                if buff.master_marksman.up then
                    removeBuff("master_marksman")
                end
        end,
    },
    
        -- Master Marksman proc version (spell ID changes when buff is active)
        master_marksman_aimed_shot = {
            id = 82928,
            cast = 0, -- Instant when procced
            cooldown = 0,
            gcd = "spell",
            
            spend = 0, -- Free when procced
            spendType = "focus",
            
            startsCombat = true,
            
            copy = "aimed_shot", -- Link to main aimed_shot for keybind sharing
        
        handler = function ()
                -- Consume Master Marksman buff
                removeBuff("master_marksman")
        end,
    },
    
        chimera_shot = {
            id = 53209,
        cast = 0,
            cooldown = 10,
        gcd = "spell",
        
            spend = 45,
            spendType = "focus",
        
            startsCombat = true,
        
        handler = function ()
                -- Refresh Serpent Sting to its full duration (15s) if present
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = query_time + 15
            end
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
            texture = 132215,
        },

        kill_shot = {
            id = 53351,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
            
            spend = 35,
            spendType = "focus",
            
            startsCombat = true,
            texture = 236174,
        
        handler = function ()
                -- Kill Shot for targets below 20% health
        end,
    },
    
        concussive_shot = {
            id = 5116,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
            spend = 15,
            spendType = "focus",
        
            startsCombat = true,
            texture = 132296,
        
        handler = function ()
                applyDebuff( "target", "concussive_shot", 6 )
        end,
    },
    
        deterrence = {
            id = 19263,
        cast = 0,
            cooldown = 90,
        gcd = "off",
        
        startsCombat = false,
            texture = 132369,
        
        handler = function ()
                applyBuff( "deterrence" )
        end,
    },
    
        feign_death = {
            id = 5384,
        cast = 0,
            cooldown = 0,
            gcd = "off",
        
        startsCombat = false,
            texture = 132293,
        
        handler = function ()
                -- Feign Death drops combat
        end,
    },
    
        mend_pet = {
            id = 136,
            cast = 3,
            cooldown = 0,
            gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                applyBuff( "mend_pet" )
        end,
    },
        revive_pet = {
            id = 982,
            cast = 6,
            cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                -- Revive Pet ability
        end,
    },
    
        call_pet = {
        id = 883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
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
    
        call_pet_2 = {
            id = 83242,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
            usable = function () return not pet.exists, "requires no active pet" end,
        handler = function ()
                -- summonPet( "ferocity" ) handled by the system
        end,
    },
    
        call_pet_3 = {
            id = 83243,
            cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
            usable = function () return not pet.exists, "requires no active pet" end,
        handler = function ()
                -- summonPet( "cunning" ) handled by the system
        end,
    },
    
    dismiss_pet = {
        id = 2641,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return pet.alive, "requires active pet" end,
        
        handler = function ()
                -- dismissPet() handled by the system
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
    
        misdirection = {
            id = 34477,
        cast = 0,
            cooldown = 30,
            gcd = "off",

            startsCombat = false,

            handler = function ()
                applyBuff( "misdirection", 8 )
            end,
        },

        aspect_of_the_cheetah = {
            id = 5118,
            cast = 0,
            cooldown = 60,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                apply_aspect( "aspect_of_the_cheetah" )
        end,
    },
    
        aspect_of_the_iron_hawk = {
            id = 109260,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                apply_aspect( "aspect_of_the_iron_hawk" )
        end,
    },

        a_murder_of_crows = {
            id = 131894,
            cast = 0,
            cooldown = 120,
            gcd = "spell",

            spend = 60,
            spendType = "focus",

            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "a_murder_of_crows" )
            end,
        },

        lynx_rush = {
            id = 120697,
            cast = 0,
            cooldown = 90,
            gcd = "spell",

            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "lynx_rush" )
            end,
        },

        glaive_toss = {
            id = 117050,
            cast = 0,
            cooldown = 15,
            gcd = "spell",

            spend = 15,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- Glaive Toss deals damage to target and enemies in line
            end,
        },

        powershot = {
            id = 109259,
            cast = 3,
            cooldown = 45,
            gcd = "spell",
            
            spend = 15,
            spendType = "focus",
            
            startsCombat = true,

            handler = function ()
                -- Power Shot deals damage and knocks back enemies
            end,
        },

        barrage = {
            id = 120360,
            cast = 3,
            channeled = true,
            cooldown = 20,
            gcd = "spell",

            spend = 40,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyBuff( "barrage" )
            end,
        },

        blink_strike = {
            id = 130392,
            cast = 0,
            cooldown = 20,
            gcd = "spell",

            startsCombat = true,

            handler = function ()
                -- Pet ability, no special handling needed
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
    
        -- Additional talent abilities
        piercing_shots = {
            id = 82924,
        cast = 0,
            cooldown = 0,
            gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
                -- Passive talent, no active handling needed
        end,
    },
    
        -- Pet abilities that can be talented
        blink_strikes = {
            id = 109304,
        cast = 0,
            cooldown = 0,
            gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
                -- Passive talent, no active handling needed
        end,
    },
    
        -- Tier 2 Talents (Active abilities only)
        binding_shot = {
            id = 109248,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
            startsCombat = true,
        
        handler = function ()
                -- Passive talent, no active handling needed
        end,
    },
    

        intimidation = {
            id = 19577,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                -- Pet ability, no special handling needed
            end,
        },

        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "wyvern_sting" )
            end,
        },

        -- Tier 3 Talents (Active abilities only)
        exhilaration = {
            id = 109260,
            cast = 0,
            cooldown = 120,
            gcd = "off",
            
        startsCombat = false,
            toggle = "defensives",
        
        handler = function ()
                -- Self-heal ability
        end,
    },
    
        -- Tier 4 Talents (Active abilities only)
        fervor = {
            id = 82726,
        cast = 0,
            cooldown = 30,
        gcd = "off",
        
            startsCombat = false,
            toggle = "cooldowns",
        
        handler = function ()
                applyBuff( "fervor" )
            end,
        },

        dire_beast = {
            id = 120679,
            cast = 0,
            cooldown = 45,
            gcd = "spell",
            
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "dire_beast" )
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



    -- duplicate exhilaration and tranquilizing_shot definitions removed
    } )

    -- Pet Registration
    spec:RegisterPet( "tenacity", 1, "call_pet_1" )
    spec:RegisterPet( "ferocity", 2, "call_pet_2" )
    spec:RegisterPet( "cunning", 3, "call_pet_3" )

    -- Gear Registration
    spec:RegisterGear( "tier16", 99169, 99170, 99171, 99172, 99173 )
    spec:RegisterGear( "tier15", 95307, 95308, 95309, 95310, 95311 )
    spec:RegisterGear( "tier14", 84242, 84243, 84244, 84245, 84246 )

-- Combat log event handlers for Survival mechanics
spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID ~= state.GUID then return end
    
    -- Do NOT allow Auto Shot to proc Thrill of the Hunt (MoP requirement)
    
    -- Lock and Load procs from Auto Shot crits and other ranged abilities
    if subtype == "SPELL_DAMAGE" and ( spellID == 2643 or spellID == 3044 ) then -- Multi-Shot, Arcane Shot (exclude Auto Shot)
        if state.talent.lock_and_load.enabled then
            local crit_chance = math.random()
                            -- 15% chance for Lock and Load to proc on ranged crits in MoP
                if crit_chance <= 0.15 then
                    state.applyBuff( "lock_and_load", 8 )
                end
        end
    end
    
    -- Lock and Load procs from trap activation (important Survival mechanic)
    if subtype == "SPELL_CAST_SUCCESS" and ( spellID == 1499 or spellID == 13813 or spellID == 13809 ) then -- Freezing, Explosive, Ice Trap
        if state.talent.lock_and_load.enabled and math.random() <= 0.25 then -- 25% chance from traps
            state.applyBuff( "lock_and_load", 8 )
        end
    end
end )

    -- State Expressions
    spec:RegisterStateExpr( "focus_time_to_max", function()
        local regen_rate = 6 * haste
        if buff.aspect_of_the_iron_hawk.up then regen_rate = regen_rate * 1.3 end
        if buff.rapid_fire.up then regen_rate = regen_rate * 1.5 end
        
        return math.max( 0, ( (state.focus.max or 100) - (state.focus.current or 0) ) / regen_rate )
    end )
    spec:RegisterStateExpr("ttd", function()
        if state.is_training_dummy then
            return Hekili.Version:match( "^Dev" ) and settings.dummy_ttd or 300
        end
    
        return state.target.time_to_die
    end)

    spec:RegisterStateExpr( "focus_deficit", function()
        return (state.focus.max or 100) - (state.focus.current or 0)
end )

spec:RegisterStateExpr( "pet_alive", function()
    return pet.alive
end )

spec:RegisterStateExpr( "bloodlust", function()
    return buff.bloodlust
end )

    -- Threat is provided by engine; no spec override

-- === SHOT ROTATION STATE EXPRESSIONS ===

    -- For Survival, Cobra Shot is the primary focus generator and maintains Serpent Sting
    spec:RegisterStateExpr( "should_cobra_shot", function()
        -- Cobra Shot is preferred for Survival when:
        -- 1. We need focus and aren't at cap
        -- 2. We need to maintain Serpent Sting
        -- 3. General focus generation
        
        if (focus.current or 0) > 86 then return false end -- Don't cast if we'll cap focus
        
        -- Always prioritize Cobra Shot for Survival
    return true
end )

    -- Steady Shot is not used in Survival, only as emergency fallback
    spec:RegisterStateExpr( "should_steady_shot", function()
        -- Survival should never use Steady Shot - always use Cobra Shot for focus generation
        return false
    end )
    
    -- Focus management for Explosive Shot priority
spec:RegisterStateExpr( "focus_spender_threshold", function()
        -- Survival focus priorities:
        -- Explosive Shot: 25 focus (highest priority)
        -- Black Arrow: 35 focus
    -- Arcane Shot: 20 focus
    
        -- During Lock and Load, save focus for multiple Explosive Shots
        if buff.lock_and_load.up then return 50 end
    
        -- Normal threshold allows for Explosive Shot priority
    return 75
end )

    -- Determines priority for shot rotation based on buffs and cooldowns
spec:RegisterStateExpr( "optimal_shot_window", function()
        -- Optimal windows for Survival shot rotation:
        -- 1. When Explosive Shot is on cooldown
    -- 2. When we have focus room
        -- 3. When maintaining DoTs
        
        if (focus.current or 0) < 25 then return false end
        if cooldown.explosive_shot.ready then return false end -- Save focus for Explosive Shot
    
    return true
end )



    -- Options
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
    package = "Marksmanship",
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

    spec:RegisterSetting( "mark_any", false, {
        name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

    spec:RegisterPack( "Marksmanship", 20251005, [[Hekili:TR1wVTnUs4FlbfRrkAJRTtCVSioaT94IMSyZMtvk65jjrlrxleDBjPs2aeOF77qrDHsIux8M098qFib2ICUqoFZWpowMZnV20WfXWMxUy2ILZNnB505VE2jZxyAWUpgBAeJCUb9D4dHOa4))oICdnafs35fZh8E)iKlxj0OeIdmbtJnjE(SZdn30uZWKIXoW3xcFCNNRlwmjm1X046DE0uB(FOu7CJMAhTf(UdZlkm123JYGH3grsT)m(gpFVPMgzpKB)OyCiMaF6YS1KqitdNDEbycYIUlIzAGdrB8XUMFWKbUbFEvpXWH4XWepeSYr(4q2ukdfeJDXtlMuPwlgHRMJLnhbf75AT1JGBySt6ZyiRGeIlMyfT1YHeDhTTvBnfUIxQvXhKA7I3KSD7ukMa7omlkZl87ttILwiYJWv3RLxnugg5EVQ9U3mSP9wToxMFfGarjwb5yQAEgcIBUcDck6DdZEZNnSyp)R)f2jHHTI3HO4syJUnsX2OWUBJCsOGVMA)WdQgHGdqEHas90vP2NO2TlGF97Q1XxaQ3x1K0dV2luGEq1iJBVwRI4Z)wSfK0g4HHnRZGnRJRutqIpZRunVPVSNTyYTrKIuMu7j86eqWqeewoRsXIz2n4mxPF3hXDrweLwtZorr(Ur3fwBceEWv2W8f08LvgwAYLiALwxs(3nRUbLHjv4SSTUSjwGuRkdLHtLgzJFuKRFcLvpOrCqH4YTBrAuFo3Yb7Cl0bpMRpPtk8DYmTjrZ1xeVMNQ1boEiY)UL62Qy8JV2IaWA3LqyiY3XSPEulhKilRk1pkjKNnvRUGKskNhcs9fFXIFQxn1dlQYTA(GwItRlIn0YcjkumjjSB9YJbaKqwX5N2QOYZqCxvy0YAP1rOs2Ctcb(8DEHWksvrQHy584WomYNTBASdd21sTF7SMgkm)CbfLW2tZW3exu3o1pcsrzo9MssluyRcs1k1cmAmb7efSb1dO8WuBkMXrJ0P8A5wOW7fbIk46gOCvQ9ZZY0Zlz7cP37YWS0SJasTHLMOwqUCCyduOZY1dNT)kxguwsvW92h7I4SgzCspSDyRDO7UrQOwb7PAZXJaBuztSnhQwktvQXiDcfZOYfQMwq0T1Y81ir3NNxgXIJ4AHwPoXdkZmuuWRjhOQYdDx8suDrueOSQrft3HWLwl9wbUrLfus3vFKsPoKjQ3lfCxyXyTbdfOBJBQgRB(r5QY)(W)YIKq31wtLd1n)i9Cq0sPqpljnKckp6MEFikMcNQftYWwzKzKYzrHUaqJ6ZXqIVOG)uXSzGoUbZMxiq53vW6PHmlAiZcboTEjU)FNRUo)A80W1JyhjnC9418A6dJgEVO19HgEVC7FsPHR)sa)7tdFqxr4XGfEV097JfEV047Hf(GyX3jl8AKd)zfIhXke7fwBUo70BjKN0SD91AgeoT3If9KNmOe6ruSP78HFEE5pZg(NNnmc44J5zF)qs164ePEpsSVtKaO(TW9C5Jj9dGChIeYzyBACEqCeHXdNVTXpXX00l4xHpARNpC9(N9SuB5F0Lu7pNDd6u7JGbIUcwftxoDw6f8jEfpH)OnW)a9sIyiUA)1u7pavdsTp8S3o7xa5V65Vm12qWPgE6Izhj981IMsap)0f5pn9I0leEiCRZIwl8IvVs(Q8V0B7QdB1nHhEOENeE(KC(Mn7HWQztA37GZMVuTHBFzCU5pq)f1NCWW6tWqmxPq9AZEAlWKdeneqTrf3MNBJM34xJtwIF5Hloy4C(2ljjMvkamn5UnYvERgtwi97tyrhXFwvUpG6rBZGElO10zJ2t9sEJPwvkvMzaV7Svlku(FK1(qE7N(ZeCOdhTbvk42A(m(tDIG7y(CzB0OjLcti6czH(pDfiCUb(qsM2e8bP8pW2LAVJFaqQnE7wiKmGLGmPsUvAxy7HhAvsRWfuMloiBMFWTu4PQrIqkC)6OwJfvQMtxTya6P29UlJDxT(Y1FbkGS()(11x(X1qS7tDe7MkcsCBiDYHIHlAvJWFv(dWQqQQOHIbB1bjjDRVHukCnzIgzP9A4MOCzvEU0OhTkNUe91MdZO1A94qE(Yx)IX1P2F78l)p)X3Gi6x4BRP2qGf)QpuaUl6aSuWvodPUHRQo2GAzEkJkALNU6eTQwn6PP9hFGQHgg5wENsNT2oB1Yzt6K90zRMRvHsm2KWUkyforpJWj5(H8PPdZVhACotai4Pxaj2rsw4D9UZCSea9sOM6NFVXAzImzSG(y2PuiOmFq2VGX75RgOafOjQ45XWMHhSnvZ)YRR94dBRuSwqRKT3liBL8JhWQt29eUwPUNqWQKpVViPC(y1o(o)z1p(Eiqe1i(E3zh3AAzb434Rgx)(ZLW)su2ZYaGRlg6IiYenYP8yWexk8tIBTW3myquGZ5Q0xQDm)JC6qtDRoJOLhm(KIMQyK5fnfVQX3CXfN7v0L8SYs6eu0yBj8F9EIpjh5iJfAQINQ8OwBr)WsL6o4m4cplgmMvr(5a9HrVDvMLU()T(JF961vzPvxGMNJ(nm6w4Yh8RC)BE((IZNQSwno7pYjHn1T6KWMZQ8DnRdNC85PnvXiZtBk(GZtBk4EKN2ufpv5PT2I(HLN2DWzFYt7bwRipDG(WO3UkZt)yv7momVFgI7gjDVMYMx8c5RyMfL5DYy(m1tDVUW5KovzTRf31eREdfKmA7xPb1cx(sjijBR3Hb1Io4Sa1INqXwEmCWl5)W)RYE5ckleuh429BRWq0EXBIWiMl)hnnHTlIyAyeKSL4DtwVDn)7)]] )

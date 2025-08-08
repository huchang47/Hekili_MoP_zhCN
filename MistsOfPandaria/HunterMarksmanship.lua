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
                if state.buff.casting.up and state.casting and state.casting.name == "Steady Shot" then
                    return "casting"
                end
                return nil
            end,
            last = function()
                return state.buff.casting.applied
            end,
            interval = function() return state.buff.casting.duration end,
            value = function()
                -- Predict 17 focus if Steady Focus buff is up, otherwise 14
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
        aspect_of_the_hawk = {
            id = 13165,
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
     steady_focus = {
        id = 53220,
        duration = 20,
        max_stack = 1,
        haste = 0.15,
    
    },

        thrill_of_the_hunt = {
            id = 34720,
            duration = 8,
            max_stack = 1
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

        aimed_shot_instant = {
            id = 82926,
            duration = 10,
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



    -- Abilities
    spec:RegisterAbilities( {
       arcane_shot = {
            id = 3044,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = function () return buff.thrill_of_the_hunt.up and 0 or 30 end,
            spendType = "focus",
            startsCombat = true,
            handler = function ()
                mm_last_spell_was_steady = false
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end
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
            spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
            spendType = "focus",
            startsCombat = true,
            
            handler = function ()
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end
                
                -- Cobra Shot maintains Serpent Sting in MoP (key Survival mechanic)
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                    if debuff.serpent_sting.expires > query_time + 15 then
                        debuff.serpent_sting.expires = query_time + 15 -- Cap at max duration
                    end
                end
                
                -- Thrill of the Hunt proc chance (30% on focus-costing shots)
                if talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then
                    applyBuff( "thrill_of_the_hunt", 20 )
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

            spend = 40,
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
                
                -- Thrill of the Hunt proc chance (30% chance for Multi-Shot to proc in MoP)
                if talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then
                    applyBuff( "thrill_of_the_hunt", 20 )
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

            spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
            spendType = "focus",

            startsCombat = true,
            texture = 132213,

            handler = function ()
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end

                -- Track consecutive Steady Shot casts for Steady Focus buff
                state.last_steady_shot = state.last_steady_shot or 0
                state.steady_shot_chain = state.steady_shot_chain or 0
                if state.last_steady_shot > 0 and (query_time - state.last_steady_shot) < 5 then
                    state.steady_shot_chain = state.steady_shot_chain + 1
                else
                    state.steady_shot_chain = 1
                end
                state.last_steady_shot = query_time

                if state.steady_shot_chain >= 2 then
                    applyBuff("steady_focus", 10)
                    state.steady_shot_chain = 0
                end

                -- Thrill of the Hunt proc chance (30% on focus-costing shots)
                if talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then
                    applyBuff( "thrill_of_the_hunt", 20 )
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
            cast = 2.5,
            cooldown = 1,
            gcd = "spell",
            
            spend = function() return buff.aimed_shot_instant and buff.aimed_shot_instant.up and 0 or 50 end,
            spendType = "focus",
            
            startsCombat = true,

            handler = function ()
                -- Basic Aimed Shot handling
            end,
        },

        chimera_shot = {
            id = 53209,
            cast = 0,
            cooldown = 9,
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

        careful_aim = {
            id = 82926,
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



        exhilaration = {
            id = 109260,
            cast = 0,
            cooldown = 120,
            gcd = "off",
            
            startsCombat = false,
            toggle = "defensive",
            
            handler = function ()
                -- Instantly heals you for 30% of your total health
                applyBuff( "exhilaration" )
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
    
    -- Track auto shot for Thrill of the Hunt procs
    if ( subtype == "SPELL_CAST_SUCCESS" or subtype == "SPELL_DAMAGE" ) and spellID == 75 then -- Auto Shot
        if state.talent.thrill_of_the_hunt.enabled and math.random() <= 0.3 then -- 30% chance
            state.applyBuff( "thrill_of_the_hunt", 8 )
        end
    end
    
    -- Lock and Load procs from Auto Shot crits and other ranged abilities
    if subtype == "SPELL_DAMAGE" and ( spellID == 75 or spellID == 2643 or spellID == 3044 ) then -- Auto Shot, Multi-Shot, Arcane Shot
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

    -- Threat situation for misdirection logic
    spec:RegisterStateExpr( "threat", function()
        return {
            situation = 0 -- Default to no threat situation
        }
    end )

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

    spec:RegisterPack( "Marksmanship", 20250705, [[Hekili:vZXAVnUXXFlgbvXoxov9(8fylGMMuKC4sqa01VkkkQvwSwIuLK685cd9BVZUlj3xZSK02OxkkAsm1UZ7x7ml5YHl)0YfBclyl)9rdgnDW7gmT)Gbthn66LlkE8iB5IJHr3hEh8FKeEa(N)wy295hctY3fFK)JpUpnCdhi5PNYIGfSCX6tX7l(1KLRrH8W3dR9ilcE80jlxSlEZgMCTS8OLl(0U48ZR4))WZRkX95vPBH)oQion58Q9X5fWpVnn78QFHDF8(4(lxiEiNmyFHfDcq6Nw(7cEJLeUEpBZYFC5cjawUa2Y(G8DPfsCMfFu(8FwUvaT7cZH)1LfHz3XkoVAnBF6dNxnAWF58QDSW9f7UA5cyFfSS4qqojwwF5VeCmc2Xn3Yx(5v940z0jGCNdpzYGLfaBBrwTfqRpTDB)dH5WIdouQf6F6OIVcJpW2izmanJFMOzdtGOCw2rwsrqErCYDaAS5LXduioAhG5SWAup5zIAdrLINl2LX1yPBdk2Xc2DkPWKTZIcty1iF6ld58NmvJ3aXD4MhRGoyYSpn6(GWKnbLg(KMzSVCCFAE8Nzy2AFeGcysNS58QpcWbS5YsJoVcuPG9(bqWBs47HN03eG9lrPsozqzCrKxJn0Tia2fNx5fJewCajFKveOXcEeos748GOW97Ten)b3L7ub4xx8yPicxSuzPcoNmjX)0t12VzPPfSMLcLmACsr8HyiAfqbgc2sBMOqHFG(JGnWcksd2edHkMdgnkMthA(DfbrniZ6hUhKXcGhLEyDyHMRfiFc4I1H(DSmHIuceEmEtW24mMH7YAgWkH7dEilSyNuTj5OG8hIlI25tRX994AnE4ha7pgThebInNZ3KRUrFd93K(qIpjipKIHLWNkJ)kjmH8xyoCmlontyDiHe8lyA5Axy9qzwsFFr7iiZHY4fCOdogSe2HywzGJjicfe9pACted7UqutXrnTfJn9lcQBhgwps4Ht7lI1C2dt9MLvB5MA1)w6pRRcd38VoLxW9TZFoKxB8U9e4KgnkJdRTR7mzfJVH0UcIzDywgemRrQyQnZottxucKMs2kq4D7d5aVinpVrKoYgPd1cRPbOMs0kq8riUCwRK4tqQuQgT1GHJ0zDYEEcPMSaIosOj5)ehvVZFQt0QsOfSK1RC9FsJAXJifMX2EAFaKM3NNUwvaME6)D5(pV6VfFaQH)ipR4)rKvekUofiDriDr12x5iF1qUfRPxahWzV3P4Xznew4LaF)1h6X9NcPTtD6qtugksfxAglilTqwbIhvNLrMP2daY5vvqPoKny20wRrE5yxs87zSdHXjvwG9N6Z296ZRUYVg1Ne8sEvvP75vF0xpJlqcGMtsLUfmXrj5bCAmiVNmopZ8k0H5FjwZ25vmpc5l8Ou2bYvN72BG8sPZXywweOgf7iVIPW)rdJjTqTMlZFqD60HOXmBDLsob4BDEeQFoViKF4rrPkKPvEVFSwg2sWaQcZjuCwX4goOdW2q1mwXxgls303gz2HUuit3gEwLRoMNm3dxDO2nWJdwZGt0P8l5ROoiH2cQP(5IcYUIuCpKo2KHRwtKjvKkfzm2KmSob(wWyHL5nKVM81UNep82sIvcgQy(gPcRcQHQvBonmTXYOUBSqhx2OZv6rsiYkn3W3kkDDRAVLBdSU0xpSKQCSKEC(NxXgTbhDSzx7nsmmL2qA9PSCVDWrz8Azg9J8Dw3ev9Q(SQBaZhWjOABoFxyWHtzByzCXBuw6d5U9gJOzio7Svz33)yYxcYoLVZapTVfm17Vfj2DB4BJGVTjX9v0Kp4BxneDQ8M1W6PzSSWB48xUGLodEBYtlIgULLWR6YND)ggqfzSKiB7(FQA3uHnJtIspWRgzt4b4W7btLXzKfrbk6VCE13DE1G(t8B0BdMXeGzMIM3YIVljydt2XVMhnWMyOgdGdLHjU2ieFiF4nf1rYcF4ETtYGSI4S0KQLPPRnwZH0K7zp63BW09I)xqmvGJaAKZTxxgPl5EXjzQvXX5805Y)sMHKBl0YUutNR8FiTOuGHosNeHvbFf6N5w9Y6gvS6))itQj7iYLuEeUgtRoP7PvBOoznHOE4e3neiJqiTdaVZSG1PjNYz5(Sbi7UXNI5viLZBqDzxP5tWHYkawNeB95iE4KGjhJ0QYV(ziXiBQDgwGEAWihqlEM1zOSJ7thGN2yWb1UC1ucUYtKFAlbl8ndHvNPZQOPeisa4jtPdADzZz6Sj(rSOC2KzEcbAbZo0WM73a3OQHeP3e98hbqEqtGEc8nR4lHLt1VaM7baBDixhji64Q1Fm12sM6OluvzY7VG8UdSjlKLehfeENy4EyQ6Atq1CVSgspyzEhK99rroaZiWc3WYjhAvRzD2d)kA3KmgT4W58oevibKZgo17V6ON1SfJsfJuRfvjvwSAEm8VQBcYlF4MMWBP3gC8QKZ2PvgMtlolgQngSg(P)yHQBLwgsY)iGFjrKxvKaPbz1PTfL970wJwbcR6Z1lSaR7fTcMMTV1F3fWIWnUL4Hpbpo0jNpPVnx2Pbr4RJG2so4AFjsDkC0sv(lcl7F48k97y05v8)3FKXEBvupiympKJmNRziGLihW0t1OT6SLeBVApeSx9c9N)0iYewWVQqKv)K5e4nIGthvJUh9AU1ytrOY7WxBaGmzXjS8CNPhi3Sh1tRo9EDdX0c1Qxoztfhr3NHlToxO2KaS7MUwBy0A7HxnBxZsoYOFRHhoY20UX76x85PvJ05Rn77ewlsAC2VTPfjpdABOztynAKIVeTKn(vZoaoF824O4cv)7AXKHuWSvjJ3YY(CAMb6nAMQcWYv6p9A1nkiozJV87QtZpV(08EUgjvuGoyXsd7qhKxIkt1o5aQvO26cuv4nn7Z5SB)MaCQmnU3)UYlyQ44CHYryZ5MfaSGAmZf3iwlVDFTQZ(3SMyvZNU)f3hWgcvraF6MttHNNx)mDBA9fOXIPWkDaPgLEDy0PeyNBFM(5MTgnQqiAhJveUZ2WSeoEpmtvLq9O65wjSBrnoibigoTcYLfneLMakh8bvB9B(n0W7UOEW0CwYDnEVMQK140Tw80R9CpEbD2dHz8BGso)sNdWi(WX0Sk)(VT8EK)TWzky)7tGRfOnYtpaRJF26dHf8heTlm5owE)ZF4JqnqajafV(ptYpDKdj(cKyhax9SV)26fpICXkJl1QhtUA9U1Wx)5pGWogx03xlMY8wk0DodLsLgjLxg1UrPVqzeCCOUHpA(0vYGIrTqpDdZ06etjSaNBt3Vp9bXj8dpLfcohpW4xTNt58DYBOubFzvGGFgpEuLIQ1LKki4tjgREZg(IHC0HRdZz)aWHRElqOkoIIN1pCB34AA5TT(Tj7bkl3jTuUkx90U4UpJCXM3sf1og2w)OVYAz(tm5HYhQ3bucRbzxe6MzaTy)RSyPf8RyS6DJDFTSjBvmW6rG2nAK2tdBqFKy3E2CTLi(ZOMwF(sTLp6wW9Ugu8RTuI)iTX2y8GjIhqyrYhns3eH0bB17FUsi(oY1B2UB6m5v9kRB0jTQUUVATjDwvdJ(QOLBoLp9H3FTKwDZXOB1xJT6xRyYFLtyzP6(1dve4W3zIbUoyjFQI7sZwUyXHtBZIVN33)uiboB5IV58k6U3)HVP1nW)8hKynVF9ifEZT)v3jh89XBV9IgAVFBGv965aSDD8hhSQw2linvhVqxTEx8XxHr74fGK62A9bH81)GHRXbxaunAy9hwpvy9hkh973Zh3ZTwJULtrUTE6PNCBx0n3oBqjn22r3QtdnkxH1unTv(kQxqpZH3EZ0b9UaPxU6OslZG0CqF6O9CzT5t13UzIcn7j8bW2RJGxFOOUmQCSQ3mO)19khNAPmhF8Oosy5FkgYNuFxNpR5LshDV59ACyWMxoCcDoVZFUAMNZVDCZ7S8cnlfkyZMs5gwZ6aWQZclS(AAIl98mSQ5C3auuuVuvqndB0ExkkGA(Tth80tiDS8kC4wvtqxCvhrqJoCSE4ssPXLTfTZgqWd1Z3rdFotwQNYvO1yC4ucmQMNJgkDhCuPoPAKrZVDsLUXa5eiroBhneyowOEcyFdOVX3U(Gz0ac2yG6z1Y153EnwKMHtXXK(Cy0We2GE00cyiyqDEQx(Gxu0kDOhUrBDTv1UaUJbONVPZaoeV(4cp)ZRb4rn0h8QIIYirZQsMAn7KxtuHa)EoZLz(7huhtN6Tvu30wlBtxkY6PNU039A9MBN0FkMz)1xrJC9tNZXnbQ7DPNxEXgJ5yIsZUEQ5qJ)6k27cQxurAuGOBBHouzxrd56wQQvBMw9DqURkOmXdum7tPMC351nSN3x1qJqd2irDTsXQwzupZNawp9QZW7rYQUJS1Iw07eDpQFs8EdQxTKRdHAiz14i3(AS2gXCJaQwmoUN7p61aZumuz4mdp3)fKzWF6jpVVFZN6XlY0exfreLa8((8nF8vLrVO)MyOOdO43gTTgJzjj3yxD(DbDlchirv5xNc9Atm)Ox4a8PyraKat7RoHgar(Ow4a0rvavV8gjqR)MsObsNpxfoaCcMPVT0L)5Jat1mbr(v(vOWgyT3v3HLTbLzkoJpZd3o0xkp8Q4CdDvvxh69wqRGGYF)n2DGP8Qkiifz7l6H1yh1nAafMwxdbTueQkFhoTwd4EJgqHA99rabE3C71O7XkYNZDvqqhLf4FDvXlOV6ykWxpugonv)6NXbV7Ru2C17b23nO)eCGO9(GHbLXwqzgouWgTdUKcvLw2Mo0FdVpE6i)52peFFCXuy6OXhYmo6efOk)ELPxTw13ESNEY(7oMhG1LJv1L2e5IjQ2N1RStH0704ZeMPag7ymcHBdVuCkSzpNpx)g5k0ElZMpUYRP(WhK1m0m49uqYOgkibb4Q3JnushofgC8aFhGy(eVWN8nzRHSdLcSjvHz6W3tnf9yCFCEJzVRXsOuYNoF53WmDhpGgp)piZffQnoAgnl2kepLgnDOuoP6RXx4qnCPn9zNAwXExelp1G(7HiwnzwW1(qSyVkIAqU61qe3zq3lZM(nRic71o0anMmWeAgWuhG96fQb3QxTqFLDzbFR4oyViHgiOKWXp5vPDa9hybfziUNjVPnDxg5advB(512xS0d2qURn2TnWSdTvQbi12wZ0gyHvlpQcycIcW06ezVogIobn8(rDrlRJ43iYdZBfDJ5CjaWljtBfirYVcXhh4pL6yeaH38GjvNDhnlkXae0hzHc(eTgaFeevJfTdF2Pv4S8(j)MNBJXu73KOXbaH3eg4SDEWbiLlvTYfLsnvFnWRK9bdNUTSB9a8BuExD5lCOcPADefpU1ZTLPgWfZrS1a2A6tMa2UT5yGUPQZW6HFJFuSvuKX9z)nDV7wcAZ5RFnj4r0r2BU3fEXO4voy5)9]] )

-- MonkBrewmaster.lua July 2025
-- by Smufrik, Tacodilla , Uilyam

local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

-- Define FindUnitBuffByID and FindUnitDebuffByID from the namespace
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Create frame for deferred loading and combat log events
local bmCombatLogFrame = CreateFrame("Frame")

-- Define Brewmaster specialization registration
local function RegisterBrewmasterSpec()
    -- Create the Brewmaster spec (268 is Brewmaster in MoP)
    local spec = Hekili:NewSpecialization(268, true)

    spec.name = "Brewmaster"
    spec.role = "TANK"
    spec.primaryStat = 2 -- Agility

    -- Ensure state is properly initialized
    if not state then
        state = Hekili.State
    end

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
        -- No special energy regeneration mechanics for Brewmaster in MoP
    }, {
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end
    })

    -- --- Compatibility wrappers for group/raid checks (MoP-era safe) ---
    local function BM_IsInGroup()
        if IsInGroup then return IsInGroup() end
        local raid  = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
        local party = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or (GetNumPartyMembers and GetNumPartyMembers()) or 0
        return (raid > 0) or (party > 0)
    end

    local function BM_IsInRaid()
        if IsInRaid then return IsInRaid() end
        local raid = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
        return raid > 0
    end


    -- Talents for MoP Brewmaster Monk
    spec:RegisterTalents({
        celerity = { 1, 1, 115173 },
        tigers_lust = { 1, 2, 116841 },
        momentum = { 1, 3, 115174 },
        chi_wave = { 2, 1, 115098 },
        zen_sphere = { 2, 2, 124081 },
        chi_burst = { 2, 3, 123986 },
        power_strikes = { 3, 1, 121817 },
        ascension = { 3, 2, 115396 },
        chi_brew = { 3, 3, 115399 },
        deadly_reach = { 4, 1, 115176 },
        charging_ox_wave = { 4, 2, 119392 },
        leg_sweep = { 4, 3, 119381 },
        healing_elixirs = { 5, 1, 122280 },
        dampen_harm = { 5, 2, 122278 },
        diffuse_magic = { 5, 3, 122783 },
        rushing_jade_wind = { 6, 1, 116847 },
        invoke_xuen = { 6, 2, 123904 },
        chi_torpedo = { 6, 3, 115008 }
    })

    -- Auras for Brewmaster Monk
    spec:RegisterAuras({

         death_note = { 
            id = 121125, -- This is the Spell ID for the buff
            duration = 1, 
            max_stack = 1, 
            emulated = true,
        },
         power_strikes = { 
            id = 129914, -- This is the Spell ID for the Tiger Power buff
            duration = 1, 
            max_stack = 1, 
            emulated = true,
        },    
        tiger_power = { 
            id = 125359, -- This is the Spell ID for the Tiger Power buff
            duration = 20, 
            max_stack = 1, 
            emulated = true,
        },
        elusive_brew_stacks = {
            id = 128939, -- This is the Spell ID for the stacks buff itself
            duration = 30,
            max_stack = 15,
            emulated = true,
        },
        legacy_of_the_emperor = { 
            id = 115921, 
            duration = 3600, 
            max_stack = 1, 
            emulated = true,
        },
        shuffle = { 
            id = 115307, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
        },
        elusive_brew = { 
            id = 115308, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
        },
        fortifying_brew = { 
            id = 120954, 
            duration = 15, 
            max_stack = 1, 
            emulated = true,
        },
        guard = { 
            id = 115295, 
            duration = 30, 
            max_stack = 1, 
            emulated = true,
        },
        dampen_harm = { 
            id = 122278, 
            duration = 10, 
            max_stack = 1, 
            emulated = true,
        },
        diffuse_magic = { 
            id = 122783, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
        },
        breath_of_fire_dot = { 
            id = 123725, 
            duration = 8, 
            tick_time = 2, 
            max_stack = 1, 
            emulated = true,
        },
        heavy_stagger = { 
            id = 124273, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
        },
        moderate_stagger = { 
            id = 124274, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
        },
        light_stagger = { 
            id = 124275, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
        },
        zen_sphere = { 
            id = 124081, 
            duration = 16, 
            max_stack = 1, 
            emulated = true,
        },
        rushing_jade_wind = { 
            id = 116847, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
        }
    })

    -- State Expressions
    spec:RegisterStateExpr("boss", function()
        -- ENCOUNTER_START triggered (works for raids & dungeons)
        if state.encounterID and state.encounterID ~= 0 then return true end

        -- Boss frames active
        for i = 1, 5 do
            local u = "boss" .. i
            if UnitExists(u) and UnitCanAttack("player", u) then return true end
        end

        -- World boss check
        if UnitExists("target") and UnitClassification("target") == "worldboss" then return true end

        -- Blizzard's internal boss flag (works for dungeon bosses)
        if UnitExists("target") and UnitCanAttack("player", "target") and UnitIsBossMob and UnitIsBossMob("target") then
            return true
        end

        return false
    end)

    spec:RegisterStateExpr("ininstance", function()
        local inInstance = IsInInstance()
        return inInstance
    end)

    spec:RegisterStateExpr("indungeon", function()
        local _, instanceType = IsInInstance()
        return instanceType == "party"
    end)

    spec:RegisterStateExpr("inraidinstance", function()
        local _, instanceType = IsInInstance()
        return instanceType == "raid"
    end)

    spec:RegisterStateExpr("ingroup", function()
        return BM_IsInGroup()
    end)

    spec:RegisterStateExpr("inraid", function()
        return BM_IsInRaid()
    end)




    spec:RegisterStateExpr("elusive_brew_stacks", function()
        -- This now points directly to the stack count of our new aura
        return state.buff.elusive_brew_stacks.count
    end)

    spec:RegisterStateExpr("stagger_level", function()
        if state.buff.heavy_stagger and state.buff.heavy_stagger.up then
            return 3 -- Heavy
        elseif state.buff.moderate_stagger and state.buff.moderate_stagger.up then
            return 2 -- Moderate
        elseif state.buff.light_stagger and state.buff.light_stagger.up then
            return 1 -- Light
        end
        return 0 -- None
    end)

    -- Abilities for Brewmaster Monk
    spec:RegisterAbilities({
        auto_attack = {
                id  = 6603,
                cast     = 0,
                cooldown = 0,
                gcd      = "spell",
                handler  = function()
            end,
         },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "on",
            toggle = "cooldowns",
            startsCombat = true,
            handler = function() end
        },
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 10,
            gcd = "off",
            toggle = "interrupts",
            startsCombat = true,
            handler = function() end
        },
        legacy_of_the_emperor = {
            id = 115921,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            toggle = "buffs",
            startsCombat = false,
            handler = function() applyBuff("legacy_of_the_emperor", 3600) end,
            generate = function(t) end
        },
        chi_burst = {
            id = 123986,
            cast = 1,
            cooldown = 30,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            talent = "chi_burst",
            startsCombat = true,
            handler = function() spend(2, "chi") end,
            generate = function(t) end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            talent = "zen_sphere",
            startsCombat = true,
            handler = function() applyBuff("zen_sphere", 16) end,
            generate = function(t) end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            talent = "invoke_xuen",
            toggle = "cooldowns",
            startsCombat = true,
            handler = function() end,
            generate = function(t) end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "dampen_harm",
            toggle = "defensives",
            startsCombat = false,
            handler = function() applyBuff("dampen_harm", 10) end,
            generate = function(t) end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "diffuse_magic",
            toggle = "defensives",
            startsCombat = false,
            handler = function() applyBuff("diffuse_magic", 6) end,
            generate = function(t) end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            talent = "chi_wave",
            startsCombat = true,
            handler = function() end,
            generate = function(t) end
        },
        elusive_brew = {
            id = 115308,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            startsCombat = false,
            handler = function()
                applyBuff("elusive_brew", 6)
            end,
            generate = function(t) end
        },
        jab = {
            id = 100780,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(1, "chi")
                if state.talent.power_strikes.enabled and math.random() <= 0.2 then
                    gain(1, "chi")
                end
            end,
            generate = function(t) end
        },
        keg_smash = {
            id = 121253,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(2, "chi")
                applyDebuff("target", "breath_of_fire_dot", 8)
            end,
            generate = function(t) end
        },
        tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 25,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                applyBuff("tiger_power", 20)
            end,
            generate = function(t) end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyBuff("shuffle", 6)
            end,
            generate = function(t) end
        },
        purifying_brew = {
            id = 119582,
            cast = 0,
            cooldown = 1,
            gcd = "off",
            spend = 1,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                removeDebuff("heavy_stagger")
                removeDebuff("moderate_stagger")
                removeDebuff("light_stagger")
            end,
            generate = function(t) end
        },
        guard = {
            id = 115295,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            spend = 2,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                applyBuff("guard", 30)
            end,
            generate = function(t) end
        },
        breath_of_fire = {
            id = 115181,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyDebuff("target", "breath_of_fire_dot", 8)
            end,
            generate = function(t) end
        },
        rushing_jade_wind = {
            id = 116847,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            spend = 1,
            spendType = "chi",
            talent = "rushing_jade_wind",
            startsCombat = true,
            handler = function()
                spend(1, "chi")
                applyBuff("rushing_jade_wind", 6)
            end,
            generate = function(t) end
        },
        fortifying_brew = {
            id = 115203,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                applyBuff("fortifying_brew", 15)
            end,
            generate = function(t) end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 45,
            charges = 2,
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            handler = function()
                gain(2, "chi") -- This is the correct function call
            end,
            generate = function(t) end
        },
       spinning_crane_kick = {
            id = 101546,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2, 
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(2, "chi") 
            end,
            generate = function(t) end
        },
        expel_harm = {
            id = 115072,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(1, "chi")
            end,
            generate = function(t) end
        },
        energizing_brew = {
            id = 115288,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            startsCombat = false,
            handler = function() end,
            generate = function(t) end
        }
    })

bmCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")

bmCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_POWER_UPDATE" then
        local unit, powerTypeString = ...

        -- Only update for the player and if the Brewmaster spec is active
        if unit == "player" and state.spec.id == 268 then
            if powerTypeString == "CHI" then
                local currentChi = UnitPower(unit, 12)
                if state.chi.current ~= currentChi then
                    state.chi.current = currentChi
                    state.chi.actual = currentChi
                    Hekili:ForceUpdate(event) -- Force a display refresh
                end
            elseif powerTypeString == "ENERGY" then
                local currentEnergy = UnitPower(unit, 3)
                if state.energy.current ~= currentEnergy then
                    state.energy.current = currentEnergy
                    state.energy.actual = currentEnergy
                    Hekili:ForceUpdate(event) -- Force a display refresh
                end
            end
        end
    end
end)

    -- Options
    spec:RegisterOptions({
        enabled = true,
        aoe = 2,
        cycle = false,
        nameplates = true,
        nameplateRange = 8,
        damage = true,
        damageExpiration = 8,
        package = "Brewmaster"
    })

    spec:RegisterSetting("use_purifying_brew", true, {
        name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(119582)), -- Purifying Brew
        desc = "If checked, Purifying Brew will be recommended based on stagger level.",
        type = "toggle",
        width = "full"
    })

    spec:RegisterSetting("proactive_shuffle", true, {
        name = "Proactive Shuffle",
        desc = "If checked, Blackout Kick will be recommended to maintain Shuffle proactively.",
        type = "toggle",
        width = "full"
    })
    -- Settings for Defensive Thresholds
    spec:RegisterSetting("purify_level", 2, {
        name = "Purify Stagger At",
        desc = "The stagger level at which Purifying Brew will be recommended.",
        type = "select",
        values = { [1] = "Light", [2] = "Moderate", [3] = "Heavy" },
        width = "full"
    })

    spec:RegisterSetting("guard_health_threshold", 50, {
        name = "Guard Health Threshold (%)",
        desc = "Guard will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 90, step = 5,
        width = "full"
    })

    spec:RegisterSetting("elusive_brew_threshold", 8, {
        name = "Elusive Brew Stacks Threshold",
        desc = "Elusive Brew will be recommended when you have at least this many stacks.",
        type = "range", min = 1, max = 15, step = 1,
        width = "full"
    })

    spec:RegisterSetting("fortify_health_pct", 30, {
        name = "Fortifying Brew Health Threshold (%)",
        desc = "Fortifying Brew will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 50, step = 5,
        width = "full"
    })

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:TZvwZTTrs4FlQufkYyzgEPdNvuv5RSXY2jUcDQ8WwHeJigkclqaU4WkYflu7R559P998lZ)s2UNbdoNbae8WADTPk7yIJz6(RpM(yWmU743pEKoXJo(N61P3jDoVZ5T72Dq)(NnEK39lPJhTKm9wYnW)WISa(7NQtw6z8rAG2ZCO3TG46rDc0(r6TgMgbA2ZMzm1GyIV29M2eDC4DT9DMcV64rx7By69kRXxlFohap7s6u4YNE(4rZn01P8NL6oD8O3p3Wnqd)djqlKQWze(9updBRantdxp42ZSJOO2JhXUisgE2i18tmoMArU2KQp(zJhXFz82(tNpXE2eDkXBoFsDmwYV5q5)xG27X3kq7NbQ4f47fOP8r)bdhk(cVayIflO6gacyEp8dKd8c06)OaTNpharILEG2ckf5LRTDD)ophIlmYo(Mu3XJaQcWCdc8VMB0EQVJd1cE9lHPOFGwJaTM8xlqB1QanpIZnuV2ZPetV5TxofFYaTEDc0An2dqAfOX1MaaB77n5wJP3MbmEH)ILHKks7tjlxsbk(Aka8ahIczDdRBkKspjq7BrIZeUsBI7uQLlm2TdPKanalgWEKdu)ui93xb9Fl9MjUG2zwb5RP3eOnAbdpB(OEm2OvG2N)x)7anlBqD6JuhGHus7xSLO9aThdsbM4k94leIulQZn33g4hFIjhZg0b54bk4yhF35aQp5deD6K7mS0ZW5)Yv)gYYDpgysW(a597mqf23nQeaaNHpsNau0cdQBsnTqUl3uhZLi)zBBQBFNLKhZHs0VxOZIQT(ZM1EP9DuNjUEog3sDB7VuciTLfcT4Mknzp8xcAOlJgAjxDaf6NOqO7U0WYcX0PoelQmJ1rp)1BDX(bvuYlvh()lUlwCZUkJQCNd)TjfSswqmSCzoU72(jO(WPk0hO)XsQ5K5eNfzudEjEdyvr4omhFc1H(vwDqSccCdbT2TtNhSY5(paKZ9kZS(mfIXpqUoJ87kY110m(HOW5bVrikCoVobkMiipYnGvlp0oV5u0kbMy8ktjUWpVd(dS(305i90pmEQzo2lcJGI6SLJ1ZdwUWROiGZR1Pmw2rGtFtKrzZyG23fO9gJBMd)RNBsjy2bn)8F(x9yUgWvpAvqCXmvBmqYz4iadmm8VNRMBYhZPSXeu9Nd)w4U54WaLtgrhMCaMiGiKdG)72UVBrRQH6u9u5f78ZshbtuuLz8jNDzX0QYjcxvv42km43POIWdcJyd0cP29hw1mJDxSsTc3bTkkGFfiilxqbWnnu3eHvlBVqBor(lmCJZyaA4ZYKfiSAdiHEzZ6Bz74aRAQBQYvyNbwBzDQ9aewlTquPaY1TiNPfLaTsxHpNLaDZrqaCif(g7BmMwKRZ3c2vESvzgXJvKt1CH2cdx3mPHBs)ineA7pip0EzKS4GmHG6VSiVxkJ68xXf6sf6PbRqjUquKep4EVLsC9DOI66W0nssWmIqx88twe(4YJoylQyOwxScwDRBnjyOush2EqKC3GKadJIk0IP9DrgE2(X(8vxScMQ8JyX6uiUOIJlYhINXna7VKyMvOhRu(E8rGqu5odAgQ91FWJALsdL7VbuImCkvFveWA4SJJCB(AAyaq5Uv0spHUzAvuY0RPASH1h8DI8fM1fzftD6HPg8ANE5EeH6lIEVwA0BKBFL5RvKZ(FHod8ynpHlAg04De6W7A4L427m1Fk3uyt8C3uvXdUGZHOzsEV7H8NQuEG5AYDe01CEPotI(BrHkWfju9JzndioEWJRGwqO4umBYRIy0DtXz7xRjyOp)eeWEsgalNa7c1YRUBSdTbOytMdzGY62rLUQdM2kM)6mqHtMe9zo8ozGTwHNplBvBJp9P7zER)rYNO8fS9xESiRt8cwh5HKSdwrsH8owRh7MbX620I8SHdgBhQq)wDLX44PoLhZqi1coR(eveUq49sJam0MHy1juUNz)6iESW017XMcvrqT2lMIvvGybXEZ0Z29Rz2vvqnkPCb9c3btI10e)fldJ44asexJixcHtI5mvnQjQq67ItBXmzEl0(NkXNaA3XdGxNoJ4BkTGivly93YelpLHdy5pC9ugPEcpPetZj8Fmb7mjV)Kt49wfij03ZhHmMKeTDUOIrLyaPIuVJCrMUcv56YYb4kZ34yh(Afu1OOA0L85zVoOG4rSMsR1iK515fWQvkNzfItyNClio7cFxbi5kl22yioB8bd3wlMuvEeRK7mWYOOawlHrbV7sILRKuXR4O76jlEOs8RxXXMytJcgr8ceFp7jeppc6boEgzwYrqvrPJx0QEkSAdJt5Ndh(cYdFVVS5Ur3SOLxpFdwDLD7SH4JAeN1POYkCJpXjBxSzi9FhVrG2DZPH1xxepzi4XdUMf(5ZFbGOWIfwjkKf62wNyblpT)GugVedgLaZ5shkcRu5ZROyuyOJoBtBKC)AWGQqOKHl(U7ELmUflAHxGXAzBLbL2Hp1(LWIn9dZIIvmTk0aIN(ZV87d0y7pcwbqd7PoO8Gnvpq71aKYHoCl6WTBDZx39IYSrDyUHa1wyluijF3t3XPfvHsjOokg1yYgS)coBhZXf1y(kbjrk5Y26gfyGx(o9yhPgV(L0)Rgbz9ksK6Gk)61lqnqQc82VzB4j569ZGioVMf9yvKhvvXT0UD(evcLDyRTwVO(Jz6TCbtxpGmdomOuhLR5ENri)fHnY8tIbxlkyjpYr3STkpvJoXBxTodVMM2huFR74nZZUqxsihBwSUERq19bvAnqjvA(HnsoOUWW6B1KwrwsjMxt9Ct(Y2EZjWpgCAOcTUncTSL6V1ctTD0ZFD1ecX11EWPRNfEzUkLwhV9GRsLvkF9kTjhUZUVBs4eP0IAQg0Rh2DrkD6mLmfllNSwseT9geLjRG80yZNXNqzoK1)DvnlTNlg7YQOYlJgF(xBsIYfJoPtvYyiI1KyPAOqA9GvwdcSBts4T4oFftxIfsIjiUkawzk5n5ch4cxfmrlpOM(yLH5VJRhZchEINevmBrLJlsELymQQW6frJCPsl(OlGeU9aJsHxLG5IJzAazy8JVJdmm3pZ8nnpoQoectgrzWU32hVG1N)x)h4zjMH(VNZA3iBxvQBRJFgqigLRe5j53jCkraDmTDUcrb9EwzPBsnY8sIf2fjvksl9DmMDVctL3jUPa8Em(bmr(49ma8gM3MMd68n4gNizzBIqrURdLfVj02gOExQhUzcHfBCPtstt5w(KZ4Xlzgskts6jPOuwxBw(T26H75LyUUpNRJm8rLhm92eiGKa2IEFhJSDsVMatt5vLdDQe2sD54wlvqxpz5ksQyPpx6yZf54hqgRPA8S4J4B2NahavF(p)lmx6VHJG)GTJxAupS6Z8btKQVhF9TLS13YAzvuFzLzQmlAo5(UIUBZCWYWODOG8cGkqZCTSKV90uLZygkidSMhtECOdneXY4xsKpaatuNypz8LKCsG)4v5IK7iw4hYhUhpMohR6C0sX4LilS9rg0eu7DY5aldEQqh8KqDWSkzm0SLSSbfiJozXsQLSn0Zly3rSzEae5neS)MMgyg1yho4R4qf(5HP05(uX3KbYap5hX6jI0IVZDHgtnvvhsgkj3mLVo5sh6u7fxt2G2((oXqW8zGXSR4rtKblRxNylra1gyHiFh97Ny)hmscika6WysJ(Ay72U7P97398XJUJWAkKl(XVIy3ILaqeAWFe2GVJWVHG)PVbBxw5AVaEiStzliS4q46BUTdUI96ZSnbfvMiI47qCXVbbhkVU)CbdBfvovZ)AAre2t8C81Rb91upTUUntK6rUM4s)(GRyQlP7cu4fZVroHBCLewlS38vL7EdtRCW3JHwAbOj722SPc4exo1EuZeEUgo8KVvvobpAW3EGQ716iUzB6bRUJvBfSVOHMRh)3Te(FlW(nKv10lpVHI2c2qDlbBK2k9YHN1raTBoYUBjZiaV3(cWJDWPIZstMxSdqZArdrqv)DpuT9y4JEq4WuHFXWKXwpxdL5AmbMD5WEYf4YwdUrZuXCmCy)vRYRg0QHKa2KiU2OPEnM5VeI3CjmQqchfGY6jGrF))QLR)sCSyLGiKOpsrShI1EWO0GKjMzi2Rjr7j)WblKWyFocgtbM0XW6wQhm1AbAVYJ)smIEb1shNAV5ySrSacXX2WgIYdRDU1utFDSmc8ONfiZ)GfR9R8OlC)9JXWjnWduJ4NMTlhfZAiOt)JLMgtn8mJh3KYaXK(3ybLhonVNpeaw97HHKgFPEjM57mmntWrHdPN4rzOb7sw(lUMYfpM2EaE(Qfc0)jP1Aq5eg7jdMhp6q1vs5QdLeG5vf9c85XTDKIZqfsCuExYmNOwpf(OHd1dJQ(edbXEhF0WK2BhBmByX1d6YHD7KD9RUD6i3BK8A)eHkBPA5iNT(U0vMa5Suoq72OG6y04azLOOrk)OxoSFb8XoRan7cUTz21dg0z1kPqqRSyqVKA4Fzk5IceHr15aInyDtSMlvEPZqy5bujtuatz48ipajqOCQhNaQhP1d63kKH3dvdrbJKOMirmr26KuGWoltN3KOcllK7mUQKfhoCBDwxfJjE26ayKEFTNZkOFJM4qSAvU9J(L96ejkR2Hxv2Po1(Rm3mxV8mcPOkEKuLLIIAfygQ5IAsnpUxJKJs)gPAH2LXQkR3bjvwYoxtIrYNKQZNOKSSwk3OSM83OztMYF2wS3yRavTwTQ5b7UXVBRwPfgHq)6DyoLf6LSrAKd(huk6Nt34Rl4wEjoWDZfxouVttPSYJ4VMwumij8Z9lk3FhJY9uOuVEhTrzbXpqUgrV9luT3viZVS6MF6cTlwDvzubhMCBFuE8d1z7FeZprBEf0il9EujNUcgduAzw3K0q13JhYN(PHBZdCEdf3tZSZpsn79YNJjpf1lEsugMkHUdZ(flvrGEx)LlfdnIoBGruLQGNzu3QBrG3Pv(xssHB(NGKuSrwwEBgKuNY3hYVRZNpKCjDbXoxxUQAgdspoDQsPTQYbRtsdEhQm(uurLbnYKT(bPKbr5vxRJlNCKr6Wk469YobDs53PEsbjrOiEwP783K85gCG3KJLvMlu)h1vjJPmbNn8aSjh1fVpstRu0mxfwq7ZvRYD5qJ0lg2RvHAkfFERuIIIK4p)YQGSxzV(pEDuuACqZmXgjnwqH0Q(hbmBGpMMY8ZFb2NSSEFALlGN6FCUKJGNgECTKjaOKNVlnuE2UCXWTVs4fNFcYVLBJErwmTBnSyh06ltGwc1LCbzLpB)PsQKCUuF7wJqOIwnn5HKs5A0PPNs8jN(CqPkI1nY1lJw26NSjvMStRi3)u5jUOm4MdRZb3A55qShoQsJaixV4C(tRkdIOSoQp)SgQ)YjWbUslgThypPFIT7oMETw8ABDYGwpUzWwzbGklM3c852uwUL4(1sER0w)WIpFfQsAv7Qpr9i0Lyt3N9yiJ460TJ4QmL10m7URQ(NTvyhvLsVC(ChQWuIr6)RJSv3G)RkdNQZ28yHk(KcyhQou4c0pzNSkaJNvWXsng2CCO2PnxfembGmisIUR(s)Zcbsx)UswghSUMgyNS2CPFlyquQZ1cu6guU7yaH3z4BL8h)fe1hufaSAk3fPQw9pw)kJn8szm40QytvKxPb7mVsQZPUEFs9zHM0jtNhHwh2M1TWMrjKVAv6cefV2IYiHpu6bhAjbphYqy50YCWjEmEKjoupXg3TSN1ZwprFbsCgIgdeYo)qB0S5bg8ZWZgs7a8Qvnf3)G4d4ZsF2epk2E5wTkNdMg3i5YEurxOqoER89Fv(uILWP8Nc()YsaS8xe0PLQgN4ntDwzc)yUTZ4r)QH59KfSp4WX)3p]])
end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterBrewmasterSpec()
        bmCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

-- Attempt immediate registration or wait for ADDON_LOADED
if not TryRegister() then
    bmCombatLogFrame:RegisterEvent("ADDON_LOADED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

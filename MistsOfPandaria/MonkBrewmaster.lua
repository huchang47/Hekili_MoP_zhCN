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
        -- In an encounter?
        if state.encounterID and state.encounterID ~= 0 then return true end

        -- Boss frames present?
        for i = 1, 5 do
            local u = "boss" .. i
            if UnitExists(u) and UnitCanAttack("player", u) then return true end
        end

        -- Target is a world boss?
        local c = UnitClassification("target")
        if c == "worldboss" then return true end

        return false
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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:TZvwZTTrs4FlQsfjYyfAEPRSIQQKyVBSZLRqLkpSvi5qWHIWceGloIICXIvEnpVpTVNFz(xY29CGZzaabjO16ADv2wchZ09xF3ZmyuNr3oA4mIpD0p0TD3ZAFz7lA15Y(T73B0q)hxrhnCfX4EYDWpytwc)7xoJSY383OBM8vU0hws88PUBM8n07nTm3mXz(CtdtIf(ApA5qMHdVNtGRb8QJgonW0Y)v2JMQEo7ap7kQbC5ZVC0WfMZMr5pl1Zy0WBxy6Tzc(xYMjcQcNr43n8nDS3mXY0ZhU9CNqkQfqiUoZnTGP)t2mzG6)S51W9EJl1Wz5uI)MjEu)GvSlQ9f4tPxRvY3AGNpX2Go2z(y)f0XE(bUZECSZVV515pqW9EbDo12dWuV8FuXq9ZEaB)sRaVqPWMjpSGc8pqcg3J4JlCJfM3T4uahEdhZSDagBEGLfCT)raXDg)YZCEWgUcXg(9hDcWly)()4)aplXYLsM9imqeCEaMcV5meZNgmFEeemlK8F2akNSgpfOQtnNpaFYwXV4yon2I9F3mOt7Jxqjw(lATIc6i2(x3PD7JzV1Dir2cPVJZokSRG3levEtGR58hnTVtcjFoQdq(ThzWYD3HAPn63(tFwtb3gdeyydYoaJQKTE(k5OhYzglmBze46c0mWghdQm(WT9Af4rhN8Pp(idhhlKyf8edxpwqvJTO)g16Mb9YHp(ENzuxWEjoR0JZkMG6VLZdC5mQ3hJTqtc5uly6W3310dNJAGBBKsGoOF71RvcbntJbDJRHlyeW8LlzSEuyzJk2X4eMXoW8V)p)RntUO9NYXK)UJRFsC00Z(KiX8Khm9HrX3KngRiwlZtT(5mQodq0vTM68W5MHi870ibVcMZt6TEDAO6I2n5dbJUgVY5bQBl0vedwYYtFUaRqooLrTqGtb2K6g5gGPRGqwi(HxLdPpqSr3N(oGAZcInAPZiw(LilDcSba0IGE8vdtP48qpaXqOmQhNbQhj1d61uWWVGSCf6x7BiUlzm73bHBq382ch)8jNk9)bVT7J(lyae1IbmjrdWd3jOVrt4cZqouhJmJnZJxatCite7AfjStZ0znjkryHBDcmaPYpohJqqaT1ccoGAiMi3DRZlawC5s6mtqwH2nO(bgyR3Z2m5RxykqJLukkVN6459CFxIhmzUbwyuijM47mdadFKqWaBZqYiJvqVJBGdX61(e37O(TKmRH)nDBhkkdwUsm3iXyqwTIcKWukGFSikMwZs4qIp1tTGWeob(JV304(mZ8zFMpXc(Pwepdu25y3IAtMArN9S(F2r6UNGI(wkOLmCjJTB8SUmIdCO(()4FJbea9lqzciZ0u0907g7HVvkQ56ksnFE3JJpk9oMAtDV7XwWSgqaFIHQk)0R)fKq7Ck3(fPyUpS3mSeKTBGhAxm(TKz0XpyAZCMX9fogMXLMupuskOYmpTKApo0pE2hHhwRrdMYpZ1feS318EkeMy1X7fOQ561noQ(g)onBMuyiG(HF93UdqV3ktBBeQmCj20qn5SG)rfI(z0n(4cU5(n9wa)Rff0NwsmT9UPtRReYHx(7RWOr8WbGnRuE0BRKhuCucDTRi9Zdlk3RMr5UAuQFnz6oOu)wYue9oSq1bxHmByvYDem5bmykRIikgifVIbHLhc8xWpOXcm4wpraV5UolfH4OU1s0vTzfa37RfESlS4YWslrzQ57IN6SSidSIcUixKcbYFH8Jm2aMafnCqcZemHUcMduszwN40ad3IMCUedX0WznmBwLtpmYHZRqClVuuOSyZE3S1yYlr96RcRWul09jck6hbtL5msQCanWFyADSmz5QyiV(cZ39oEo(Fd5DIuydwDkccOcqyHmtdCXOkYI3hY9AYF(Pe77XeDKqJJGYWmQytkQVnhMYuQBdQOLJAh3xE8mkpZzblboDFhfnwfxpjTOkv5BGsIuuuipDF0iKb8O)joky6FIhRluWDEXPSkcS5WkRgFv59hdBuvL3UbjPlnmleLTeqb)Y4SzS0MJNXC8ExW4jOeCns6CYDUQCv5mgyP03yieIfP4VZ5otJMfzuWU)3dGIpZbBO6mROCgcS00lzplmG5rfFk7Os)JtvT(rjKbH1vZ96fp3cMDi1BLORlFpL4f4sLDFmvJIeKrY0k469YHy8sXiKosv1KckYqr(SjJlMSIhgFgVShSS(7WXIXLHfNXC1Z7EGTta2zaHp)0SS2AH69SoAzmTf4ej8VL3vM3G8cOijAcrV(YgEj1eyjUa4UPRk9crpuiwltQu0ithwq7Z1RZCzHr61d62mxnft73g4gABYmkLULwf32uPIII8p)WQGCqzVEF(2OOC8rnsLBKYCbLsRFIohm5wep24CzicYuWJb3cGPar5kt7UpMgQ8ZF9GERxN27tZmj88lSoThpHNtfbZK52CAzLcy2opadxQeGWlfLaKSw(W7esU7FLWRV8mKFl2g960yANkyX2V5hMeTKQlzsYkB1(gk6KCMsF7uHuOcJM(voFBe5wOgDs6PaFYyQxe7hLniUeI1DY1lJwKuaRx9ZnTSWFJTIarbiIfalrDkG9s82ch4HAOLMStQi37C1fUOn5gSdsWKJ6m3kuTEoKwK5DlqJylkZQVX7)Z)QlJQrfKctxswapYUZXrIXDdVL7gZIp2gSX(uz)95SHupoEIazxTOB60QxSsv98JQ5pPQmiIs7O(YlICTeMIqS250RubJoaSNOHhR460cYO(y6Tk4fJ9zA3sU2qOPewntC))Y81468EbS1HhMNkYn93lbakTyEpWN7tz5EI73k5TwBD4EFPZlXv8vKIcR6QY6NG)()4l)cXciWaArdPbKf7inyRaHa44nUar8WFEzTR0N0bXHEixJHuIRZ3pIRIuwtYS1xx9VyVWo6ALEX8znQWuGr6)RJSL3G)JkdNYZ28CHuRnnNyznfYjTgvhYna9v1suagpRHJvAmS74qLlBUmiymaPFOeLhdxs3IUZY8EGzEjRLL3Gw17ljzaD82QsEHdbkJFxklJJ2wtdCLS2DPFtyq0QZ1eu66xS7yaHRn8Tu(J)aI69ldawoL78uvT48V)cc8l9pxGzZCOY9g492yfL42aOSydVvg9pVm2u55vQFT5vsFn1CqjDbuX0MkOAAo0KSy6Si02W2SvlSryb5RxNSbrrXw0MjSOxgqQnmIel)2ZVOKNfme2onqJzm)xhJ7Y4tXnd9GzX24Uf9S(o8vwsY1jx2xH5GyvdWo6aymRpp5V6VfnRgrl(BrpQCLJqQmUjvvxQOsrDU0IFk4)vv0wXViOhQu1l2Bsc8Dgt8Xv6D0qaaqgiCxP3PvNZ71RZLJg(aH1cqpCtOJvMUCLJRVOS1tqU4eCz))xbMS(K75SeEiCOxsylAnF3u61AZRzV(ChlaNzgqKaxc2hcQlvSsES1OKT1cicnvKHWUq6lFo(w52jWoXtpBMdB1n9jtjE0Va0FXDmzY(dkUy21Lc12vWAGcojWYVSC33X2yM9)cCjaTb0KDBh2uHWnNApzVOCDcV39jhSQowT0W(stITJ)7ua)Vhy)AD92Lq7UJS1lzgc4DpuaEvwn)9nAwjAieQ6v)q1(JHp5jHdtn(ffb(3oxdf5Au1AcvPtxq5pBbkex70uVfZ8hcXBMtrKgjC456A7eWOV)F22lyfowS2vli6t0C8WKXEWmSfNunE62H7XbXGjim221W0aysxt77P(WupzZKx5ZFjgrVKApdNAOCgFXzIahBthxtFSeqBdRGzyPn8ZgIez(NSLk9v(0LE)6PyraM4Ppi6Pzl3NCwfGo93xzbLs6BfnUXLbYj9VXAJOyAULpeaw9RIYjIUu3yZ8dq1iX4iXq6lFugAWUKDWYPuU4XYXhWZxTuI(xLuRbLtJgY(j8CjcPKd)3pWocKcxoJ(Qrd5VbE74zOZpfIUMR43uxvdzp1gAlWypDAngneOkFqPGa)uKr8Mj3mGTfupEZKg8xBZK1RLDRnwLeWtciF7ntAoYhY9vdAKy9ItbgL8WDKlLE2MjFMSxgkkyDcGf9zpYr6FkK(7PH(dRYmfTxYJbIwA)69eTZmo6YexjhFPqmrbXCmRFBKJ7RHJZ0XHuC(2DGsIdajROkUMwrn7GZFf0viPoBd(U)ltVCuas7zHqtUPsd2d)HGg6WOHMQvhqH(zAe6k6sCkX(2DywkNy)Osk5vQd))f35lUzxvvU(mh3DADfQpCUg9HODJxk1GQDwAIRoKmnpgT2PD7NSY5EpbKZDlYS(cnIX3sMMs(TDhFN4YTNIcNN8gHOW5YQKO4E9SdTFZ1Zhcx4NxgWz160Ml72Vb30NxC9VZVYlQgQt1vNxSlVizgmzw7cHp50HfvU6E5LUTgd(AfvuVCGhoSQrk7UiLAnUdAMxc)AqWDFRMvzar4LnTVL9JdSYPUPRwHAdS2Z6uhaiSsAHOsbuRBEotZRaATUcvFuQ076SmhGQ4GVyNtZ4X(zH2BcLfhLkf0Gv559sBwNv6OwfNGfRqQIZvv9QyOxxSewDBBpj21dQL(MvWuLFglxNCXfDCCE(qIwW)uSZoEWUYxFvMWA6dvapbOm3km0JWntZ8kMElvJZ)GsvYsNEAQbV1LxEarOEYS3RKg9o52xB9A55SV6hlTk55UHUMhCnNdrZKSE3f8NUsEmeNymvs9D8OSfNjfItJuNCTK5vAK60RX5SdR1em0xEgcyxLcWYiWUwV8QZo7qRpk2u5qgOSoT1PRMyfpvjrR7Zpx5AYOg9B9DgJJNA2SbXVNInCadXQsQCXp0D5wUEx2uOldQToyAYtKx9hZSJUKA0s579ZVx(mzwl0ENRWNaA3XtGxSzNuLdF5swxXgmuxM6X8KMARRXxFYX8p2Qr7ZavzBht5kVDvyKvsIDwyOMqP6wu5OxCfvZjF3CF3WTQOQCmJy10XPhSVCQxwEuUPWYlXXcyuWlRICQkOK4so6E(QYlPa)RLCSjo0WKcKVqIDqz0mYSOc3efv3MkZxL3ITO0StlKvPl1YYPuDMRJOpErLLwJ(slPVa9Q8fwAK(M3F9an9er4wtBf6gIVgsAtGRuF8L0KRw8pZsktdlwK7SFYLypXvCXvOXwEnwjV8x0kis(fBQab2HmbO6X7wEjkD5oKNe72Plwd9PCr78u)y7Smv6E7TpWthoinAxYvgyotHTHyLUOM5LT528rIQUrKWSOKPSKNh2yw9L1In2Nj9I8V(H(JJ(O0DSu7NaDrLFTvRBe10dTAAQ)SONNTxYVx3Pq)90Nr9CR8HxxwoFdXL9KjmT2yF0W5VB8TCQmhMCmH2AwU2(IRVhaMgQDIGPbi6LJACRPoORBED1Tip1h4Vp75IFDZ3ur12xwIOPGLbHTgtT)AjAMPwz(6IORUGuuq6TkWtNVV7zCGLcp1OdEMqhmTsgF33KxJKJ9XvpfQCa(iWNHBt)PEVe6qQqj1MP84KyTu5eGSOnVP2aG59TcrFyZA6d(qHfEYGjrcf7HnnQIo8FEn3i4sS4j67BJEmzh2rLxuZCS(gU26QsbjrvQRyZQMtu8I3BR1KA82Vjg(OrqwTLftF77(41lqfqQC82NtsefBguWxyLYjpkRIBH7VRR0juQXnZZ21F1iMEpVeXBhqMch6xOJYTC3cxdFbrkhQwk2)OQBDhT9LRdDjPCSr(66nfQ79lvmqfRT(tBKSFvHHT3QjPISIfvFl1Zl)N3LYjeIwj)(NVDw4f5Qu5kxEaCvQDVbSDlMB1(WXuoqVAy31j0PtTiXyLQQ6bdFdDI1Of4VWbQo8NnTEKSKDTr)3p]])
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

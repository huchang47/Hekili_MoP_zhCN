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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:DZv6YTTrs4NfvQcfzSmdPi1vwsvLVYgR4K4k0PYp2kKyiWqsybcWfhswUuHA)7(iS)FFYYtY29mdUNba8sYRtvYkcyWmD)1NtpnW4UJ)W4rgeF64F5KoNCANl6Cw7Ux09YtpF8i)7xrhpAfr)gYC4)XMSe(3xyqw5BElnu7LU07ws88PUHA)i9gtlZqnNzZm1njw4JDVLdXaNEpNaxD4rhpAAGPL)BThpn3AEkSMD63bwtVvuD4YNDX4rlmnmO8Xs90hp6dlm9c1WFiHAcQcxr4V19nDSd1Sm98HBpZjMIApEe7IizO74sHF)lmwMAtMArng)s46UMapysGHsVLAfQD1WqTE9d1AeQPVWSTEGRl12NF9tyx(GqTPbZM12Bb8Vw02bRgpIteapAbKMtG)KBm1VHt7UMR43BO8)lu7vaTfQ1C0cIl1iu7DoZn1BfQPC8)mX02h(juBeNe4eeapWpln98mTNp2hasL8kJ(bIBf1fKetwsjEbUupGvkY4dc1onu7Bd18jwWfAt80P2Eah1wm1HApluRpBihu2OGjMAtDNFFBaTcicSUFNiqv8KRCUJ6oXZ318gGIIi)yeM(PvuRjauTmh8(7Eao8g8UG8hUnhoEDetcWMGlfQr6OImct9uct5XHEmwTBfOHk(mHhUHoFIhy9Sqgl8t05GGfVlSioHAZXjJXaVAHjNPSCUdyaBdCHCcMViAbrUP)AOG3uOj7BohGCgW32W5oqX6HhKClx6sqRdWUbCBHwjCKyyeR8sLeD1pGdju794ublTGA61)zTYO4cg1WTbPSPRqn(uLC0ckXYFrBqaRhjI62PZxBQWM2FmG5yGjXTD8fAc6KvRGPfqOZ2fieOC)8nx5ocbAkXTzp2nzQtzrg0DtR9iUC(AylOWzFZCo7Zyd0JBOumGqg2QSyc)gDg4rArkp5moZ)i0d1u4H4(ayMduUPrkh8xOK)ecqGPMCh5wAg5NUJJfALNC3mm1JR9dm1xCAcwfrsYuayc3)GCRaK4Rc14ywIhjS1XLOqCzvkeduRp0DRDz2xLltGY62rjPXJunbaULMy0Retkf6SYvyVcybopyq5X)n)8NVh0KalUptJc9lU3uxkXFXeNztMbkEmomLcDMBktu9s2i45N9dmnxwSyXcIgXFMYddhS6yuu6oN6JxW(iFK(DTHHfjitmnGXpLyFdxw2vDQCfXL6zn(sNFkE5ylH6mO(IkykXhHQ7HedqQIr5QtQPiLx0KS3zsCcG2a1GiJin4oq24Mww4FXYkpjKFQ0y4lEIn7cMcc1cvJc8q6h4hFylfUuDNLtj(YYIVE5z)(OPiuZJ6Jk8kgAcx65tS1POQU)cke3kW14(joFItsg0zKalPeuS)mIL1e(Fmb3lsDj1FMjLFHyRnVdEYsiwCINW3GgqsOp3BPEY2aGAQk1ue5h1twUXQNHefS8PamCxf9Ovg605wQ7mqfswsV1KrDPYYVSo8yEFYd4ozsn7E(YYmBtMBMLAM5M4qJtVjAgjb(oti((e0RwYkYuuJHQs3a8(rOvw8Ol2IWrSBNp9weQoVtnJuPWEsK0WVkWSs2h(JwOo1HH2VYS5bexJe0Uc5yH9AKtyWMnzzl83XBeQD3cQnpwwuwBcuHNomljVx9AaQGWi2CyMLJh6P0GydrDwJDZVJWQ6LxbJFmcwUIt188rfmNG5zCsGhtE7ZTWl1yvDsHcs1nWddLo5Jed6K7mTnKVhGIdd0NnUx1g9oBpV7GAVh6c0DDnUFHZBGC16j2lfRYBcqSSsU9IF9nFFO2VD9FWFUrRmTTzM3VYLyJfTbe6CHBVNfzK7bQQlmtQoZXY3tIAJB1Y4dQPywIe889Seu9MpAF56jI9eG8eDeJ52vLAG)vlETnfvrgkM1uzpPBdo0nXaJR47rrqELxIYVE9QTnIWI(6kTQOBVzqmogxOAPAMQle4(ajxhvAf6WZGSUNs4UruxZu143oUYNRNmjhK2VshLQR(5wAMDWMBPjGR8y1osfjctBwUkClHwC)1lE0hjtZPMDnzAIsvucSmhPy(7rfOKNdlMbRDcDfF(n8QFG32lGD(PWZuETD)su61FtH(13QjRaP0I6QgPsk3B)ZwpZWQCnkTKApAUgRPoQfpMS)cInhbykJgoiiXIJFJnUZ3rV6N28AtVra1GmAz5kvjwhvzLLVoLovAvj5Gr6dCfTdtzEws9i9Kw3VkQqKkDJloVEyw(W4RThlLBWzeWMyHh(GO(eFhw1X5lWu6SOSZCP5F9V)VNuRnlXu5W8fNHZad)g9bEYLw85uNnNfZHKb65LhzDBEfGcslU5Jf0VTESKyEUxXk15Hx)DsvkcUhDSTTQ7CNFSD1iavDH2CC1JYSJLmXKZgpU(BA5PgS2dkOBpeQul0pZHwuQlvg5tTcWHozQl9oGlGGAETz)seoGJVL03dkRSzMzMxs6mh7z67xx3QVoM1QQoYVHp78oRlk0eN)aqfltfA)d29)475M6mOFwGL1XXfrmk6vK3H7DcWly)x)R)dmwILi5UfmXN)ckEtdSp6qUDnk0SiUBd25OHoTa9ip6KvbUMZyLWFkJhYLSjhZtsWeyU5y060r5tq7Stwo8(9r3mcUEo2ZFKBVpEwbZG(D(gS3IsxL1yCJBZUg1lU(SCt5vchn8fnlICePLkq5KTau(zhdrZJLGl944s8jWIkuODDkmsYovIFExZO2prTlXYAmbzMEG)f)umwYDBwargg32nYpVHiGSWbUNUnnR6Oiw56W1qSUx48Jh8ngeynzkGBqor4I(nC48hIzJirG4yE4twKpqFEUORy5Igz6PUEoYqnfkzNkuYYRfXWSuU5ZH35qIISXZfoPqMmNVMip(aNrDt8oX0SCCtbz4v5O4DeBStDXgBsFbEWnXz6JxIS0ja5hlqT1T8k1WDstwUIAZABS6QvjdrLBZMazPwMCW1Rz3jQZ0aO6De846TmXcpHhlip(gnYPoWQU3NzFf5WsWT9rSdsm9bBHhrC8jZxAys1BPQS(5G9uMFwHkHYyxVkIMQm(w88hBBe5ac92qt3giqcfLhnsKce2TymjBzfk7e5r4JsAagXLjOq0mQS)Zsi9OY7KqZXA(mXfiWabnMGwCNU3TD3Z61R7fJhDhHDUVEyJTJs6LRaDvHRMJWgt4iWrl9FgyYAWrpNLWGWt4FjHTICZgV2HxZE8zowWQYGwsGlbt5N6s5NNixnIfSNZK8oLhre)OXXtLam7YmAddhMcOpzkXJ(9HxZuUZEK6IlAuOvYHBCTewt0Ym1L7EhZgQ33J6z2aAYUTdBPaoXJtTh1mLiF4Wt)wvji)S(F7bQUxRJ4EFYozB6C1wb7h3etRha0faGF32lyfoxmnoHK8if9NKscijv71Jc6xHiifOD1WtAKZbBdLUJB0mtOQHd79Wdz9epy45DA1qs08ib2UAPxJv(PWURWUtuiHJ61N1t(2T(Y3n1cRHSt68QlAOO9FAOU1FAKvoDfiNKOm8fjzgd4N8yb45nfkYzf1631O5grd129)oaQ2Dm8tIVHcXKVM)6YbBJzMzu7Kf)(1iIJiCyWE9Im1HfW10(gQp4tqlu7T(8hIfVAj12ajA)fyZzXsFfNBthiFm8SRS1TcmWkCW3eqev9pyzn9wF6sV)8ym5xt9fPhnRJLJwvbdt)0kltDtFRK5nn)hTO)n2ElelZh4tb4e7pf5ILCPtsTY3zAzLIJetPF0qzOb7s2blNs5(nTC8bb6Bxgf49ISsm0bk2AYmyE8OdvNe81hkP)JVUShGVoETJZzyOIG9O8UIvovzOkDOIP6lJcsLabjzT8SHPJdES5SHLxuWRg2TtENlD70rUBj5famgv2rfDsoB9DzlTdYzzsSPBJsQ7uJdKvsPgzYV5QH9kHp2B1jAFWTnZhTOFNhEqke0kpgCsAn8NMI9OaryuDbGylYNfluwTtPvalFbv5hfWuoop2dqkeQG6XPG6rw9GETem8JqTBuWiPQNumtKVuwLiSZZ0fnjQryHKI3uruHd3SI4KW6XLUc48CvAc5(mLScj(gPScgmSBAAO(LHr(YhvIhCDvuhPmR(jfdoWJTm4Y4qdkHUdZ)2eutGEF)wfKanr7xeqMSPrMZx0MMA9ED)us8MV9VfbsXgzUN3oizt2uKGFxN3Na5s60VSc7iUQEgds)uxuNCsRZh9I0g8Uuz8zuQq9BKlm7bzKbXbe3OpQefiJKxS9ex9Y(4BKXVZMjfAKXv6vOR0dkR7jsZNBXxEIcSCCB0Kt7AqVN1vjJvK4li83OVIefOUK2elRsrZcPgH2Np8qHllmshm8KwLQPu(3OGkuuKSVLNwfKhv2R3ZxhfLgh0mJfDpUt18n7sK0AZ)UlSf(yAkZp)aSWZ59(0QqcpB(39GceSU4BSqUeGs)DIOHYVredgU7vchCXPi)wTn6G8yA3nWITFRNMeTIuxkKKfpOru)JHQUY2cy(0d62DdsHkoAA6V0bvRrNLEQWNC2pgb1rSUvUEz0Yo)BoqTj7SkY9ot(gxuMCZHBsN3w9EiEe6Q0yaYZhGNpsMwuvger5DuFX5nu3PT4exRGrpcSN02vC)X0RvWRDvlzUzCt)DsaGAlM3b85UuwUJ4(1sER0w)WYFDMRZ2Q2xV8NXOlXbDFw4LQrEGpbGP8vWPrvV5s5fxNTBexvPSMLzL8(4jNDpOs(nh7C(oHDKNpr7lRMp3JkmvyK()7iB9n4)QYWP(SnpxOYFVD3JQdLgG(Y9suagpRGJLAmS94WgVT56GGPaK(Xs091RiBEiqA87AzzCW6AAaOwZTx63cMeL6CTaLU(v7ogq49g(wl)XpHOE)6aG1t5Umv16)MYwBSHxkJ(NvhBQY8k1FV5vs9EQ3S3y28qt2ntxeHwh2MDAHnJ3q(dpKTarjXwuMj8Hs)C7vrYZcgclNwUpLBhJFJ2gAKQJBQAS6jhdBvdn6mCqCBN02ZvVKybqQEuWVLT9PQFqqJqQsqQNmZN2o4pw44oE0VBADpzjRp7h))o]])
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

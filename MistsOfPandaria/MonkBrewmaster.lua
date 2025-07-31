-- MonkBrewmaster.lua July 2025
-- by Smufrik, Tacodilla 

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

    -- Force Chi initialization with fallback
    local function UpdateChi()
        local chi = UnitPower("player", 12) or 0
        local maxChi = UnitPowerMax("player", 12) or (state.talent.ascension.enabled and 5 or 4)

        state.chi = state.chi or {}
        state.chi.current = chi
        state.chi.max = maxChi

        return chi, maxChi
    end

    UpdateChi() -- Initial Chi sync

    -- Ensure Chi stays in sync, but not so often it overwrites prediction.
    for _, fn in pairs({ "resetState", "refreshResources" }) do
        spec:RegisterStateFunction(fn, UpdateChi)
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
        legacy_of_the_emperor = { 
            id = 115921, 
            duration = 3600, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115921)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        shuffle = { 
            id = 115307, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115307)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        elusive_brew = { 
            id = 115308, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115308)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        fortifying_brew = { 
            id = 115203, 
            duration = 15, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115203)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        guard = { 
            id = 115295, 
            duration = 30, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115295)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        dampen_harm = { 
            id = 122278, 
            duration = 10, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122278)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        diffuse_magic = { 
            id = 122783, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122783)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        breath_of_fire_dot = { 
            id = 123725, 
            duration = 8, 
            tick_time = 2, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 123725)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        heavy_stagger = { 
            id = 124273, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124273)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        moderate_stagger = { 
            id = 124274, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124274)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        light_stagger = { 
            id = 124275, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124275)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        zen_sphere = { 
            id = 124081, 
            duration = 16, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 124081)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        }
    })

    -- State Expressions
    state.elusive_brew_manual_stacks = 0

    spec:RegisterStateExpr("elusive_brew_stacks", function()
        return state.elusive_brew_manual_stacks or 0
    end)

    spec:RegisterStateExpr("stagger_level", function()
        if state.buff.heavy_stagger and state.buff.heavy_stagger.up then
            return "heavy"
        elseif state.buff.moderate_stagger and state.buff.moderate_stagger.up then
            return "moderate"
        elseif state.buff.light_stagger and state.buff.light_stagger.up then
            return "light"
        end
        return "none"
    end)

    -- Abilities for Brewmaster Monk
    spec:RegisterAbilities({
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
                state.elusive_brew_manual_stacks = 0
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
            handler = function() end,
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
            cooldown = 90,
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
            spend = 1,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(1, "chi")
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

    -- Register combat log event for Elusive Brew stacks
    bmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
        local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, _, _, amount, critical = ...
		local playerGUID = UnitGUID("player")

        -- Build stacks on crits
        if subevent == "SPELL_DAMAGE" and sourceGUID == playerGUID and critical and (spellID == 100780 or spellID == 115072 or spellID == 121253) then
            state.elusive_brew_manual_stacks = math.min((state.elusive_brew_manual_stacks or 0) + 1, 15)

        -- Reset stacks on Elusive Brew cast
        elseif subevent == "SPELL_CAST_SUCCESS" and sourceGUID == playerGUID and spellID == 115308 then
            state.elusive_brew_manual_stacks = 0
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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:1I12YTTnq0VfpDg7hAIQS8TKowEgNe1uNjrkJPs7BKeIeKerKeSaGYr5b(T3fauKGxDSt7dXrCbWzxS7zxSa2NAV22YhjW2lNnD2ftVA2RMm7SPtp9kBlX(mSTvgYBlke(rkkb(lcjfTpMI8LlLtZzEGyBRn5KyXDP2B6I3SlE9SxbZnd7bIVe(zeX3hRNlM7zBToIWlCL)dv4wQXcxAa8TNGqtlCJjCbmCaLv4(N4TKyYeWqy0asmO(FPW9t00T)EH7By4hsqCbMv8bq6kwikL8DSpGEQGw4YXzigyF9JS16xu4ElDb833sPX(0hs5WVrPW6FhoaNYj7W8jfFqb(NVFXBx9P3C7A1x3MLftWasX00WxcgqsH7M8GaqYgmGoOsCkiMKgw46rt2GeaqARGpjJH1Y(15)wmoe5T3Hg4iIWo4KmmJYEbjy(rs8MWfibFsEw)loJkL9cz0A(oclbN6SHa73puA03TC9I7V)lFETL6ZVWL(MhIWGNa0gmU0gz5zsFIGgggJ1bgCkAtm23WKjvZeuleCrmNiWt5WfmYwS0EfiwiwmXdIhYD9bt4Dl(JflTU7VwOnH7Xse3jdjBG4Qq5eZv2LkILZ2PgLKcBsL3ZhLaeedtXVk2i9a5msWEyIoBaYG0oapwyiM5eJ3HJVzohlK2d43uZul(yViYnZpDamdZrmFjuryuSiAces8GO511yPMHJEyiUXW8iGaPrD2aOIJZL)SYon)gCJqEa3WABmALggaAGWjA5fg00lN7bJpZtmaOGFpd4triwIo8gdanXq6KswYXT11LthcssqaeRDGakXZeut5vWEGcOf7O5boxWVzAf56TRw9X3T6VxQ5wFc9vzEnnOuLL5YGVtv4sMiwMMBWMQKb2N0gG0NeE)dts3r3ID(woo1W4nKEW07F54umlK8DZOKs0(jE5mMYZD(ujhQ(7t7hjyovquAfhev59AGJ8Je03E5S(XBtmL67eKZ2pW4yghZ2AMwF7QfqY8Q13U(Uvl7uCjjpwqYKvt0vfK16L1eHAxCP1wRgefdkylo0HdvYJApalNhjDyFf5JDEGK6BSL7mM5E)M5N1glW9GagpuPnGWuLSANVQNhpJKMkb2JHsXoBjEBLtwx3YbczjqrRBMFEz6(Xh9y2thdjgs2P5IkO1v6JG)gJNWWjisk)6Z6uorVA83YWXvPLTZ9ETIbD9Ha(PTx9xrBk35dphbrw)mdfNugSTUB57)ieVxF79VFX6wX96JZvhPKXiji2E4Gui1hb8GMh(wh6F(oIEjmpFptFgIsJ9o1rDGL5MpG2HBLBkf1Hp0WxBB9aIj5DCzlsYJatYGA1LnRCs9bWNilP9p5ahgY340ezDUCbnbA0be4bhlhQAB5JKuyOtH(K(skpptcMCchIgN05u8tu96CxYHzEzR(MGHTTu)s1iPo8c)CPQXYYnN9BST8yezVpizJIDdOfUxx4EwH7XsJLu4EZ8c3zqZMkvblXmwO7zKrY0Jnir8PYcTfqZPsR(GwRiuMBeysNn4wRj)c2uW241tR3wxR(FjbPW9LqCOwx18uPgoFqnu5DgaNMEkaQlghQHTiGulx)LdU(byY1iCyejmxz6ynj4MEwHSJ(YozhNdDKU16QwHRXU3ENBrz6EvH)VUNGXveEw3pOItA4f03dZO1(6nVU3FTNeQB3NpSHJO5j2pPJR7lnPhJTdDz4teBK8Fwn(DwX45G9w)OXX8JNH18mDnuN3QYK6ZJKUMX3t1wqpnqmE25pDvYrZD)VQq1v)KvxE1pyzHQopFukDD7)pLE)RnIQ(9)HyZ90OFnugdooLTzl)6OX5vrJMYndfnV8W406bUtq)kXmOnRzb9dA6cZix9LfADu5LnMv1vg6eFRVs4419BCrEDcqVxMVzoIHpR5Bd0I7y8Uep)hLyCEtFjEpYtimy(UA6pcZQ7dk0YR1)JkyqYmgFCg2OBTUpXqTkA9ufJxxC43Cq5N6ZiUCATUmw3pu3n9(meknn0tra(3cxtnAIGMTx33(4S9MpFM5HjT6sVfp24j(E6VVNYeLrNCrKSZP1ipAzyryB)Vd]])
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

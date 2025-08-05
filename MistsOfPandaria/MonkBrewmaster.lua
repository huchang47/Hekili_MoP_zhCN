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

         power_strikes = { 
            id = 129914, -- This is the Spell ID for the Tiger Power buff
            duration = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 129914)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },    
        tiger_power = { 
            id = 125359, -- This is the Spell ID for the Tiger Power buff
            duration = 20, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 125359)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        elusive_brew_stacks = {
            id = 128939, -- This is the Spell ID for the stacks buff itself
            duration = 30,
            max_stack = 15,
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 128939)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
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
            id = 120954, 
            duration = 15, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 120954)
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
        },
        rushing_jade_wind = { 
            id = 116847, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116847)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:DZv6YTTrs4NfvUcfzSmdpGUYsQQCSDwBzNexHov(XwHedbgsclqaU4WkYLku7F3hH8)9jlpjB3Zm4EWbbjLCYwLxhJJz6(R)M(AgWP9N(HPt0jE0P)4GEdoT3f9u62)0bdp9YPt8UBdD6KneTBilH)dlYA4))56KnEgFIgO(Do0BxtC9OobQVMEJHPrGQ9IfgAget81UZ0MOJdVRTVJg8QtNm33W07nwtNNBo7POCHYzWZUHQbx(SlMozLHUoL)SuxTPt(Wkd3av8pKavHuHZi8V18mSTcunnC9GBVWosI6oDc7IOyOz7qH)(hzQm1Im3KQp974JUJXgCiMozS8)xG6lG3oqT9KvehQEG67SxAO1jqTWN)higwEWFcuNSYFXct4LNd)nOaWFwB46AyTeKjhda)miGys)e1mq9k4vhQeO2kqvBLrxnFhhQLh)6dyx(i(a11LpSD93mDchaa81eGfBFVz3yODZupailtx)fxqOE1VVbN3xtCwZLTxsbBGdyDaDGsC9DOHOUgA3tkZm5qp85NTw84GiLxbgfOEAG6xhO6rmHl0L4QrTCb5ORq8cuFAGQc7roQSNcgyQf1z5DDbbYNiWmLEHGJ4n3yFl1zMRNJXnGefcbriffv7zGXCnctdReMElDjyjb6(kygSduxIYadKEXkdoWzAFlasw6O8z7VCvOCMeXYcjdzAD)kaMIu5y15g6YzUO0HAJszAtmV8dglXLUVhbkGzliGdvEANuKuyjgCBaVmCQKY2wWn9WHEgZe0v3(wyYU)Ej3YHUgKeGAnIZU7eRqIhJyYSpNwP9jhn2W6J(SvQmlILTNWsPr2SbjcXQXkkX0BvxGeRfAw63R3FXyWN9fccbe6N1CcDic0wI3VHSBY4qPrg0BtNIWLZldx(z6cWD1QeUOz4I3XO3U5GFu(ADg3NYxhSlEUBNXZDk6)q(AK8E3tPC5CWFrL2DMn9xjFsODCJcv)ewWAqwTTnXLONudEGWGcQ3SBHbmL9mCCIVBk17HD9em0xCAmQfksiGDzgalNDCuXMX(7StoLsCY1Vxz2YVZ(Tr80cJOW4ALWw6xAUpffAG4HCJ7GiCic94ebOFPzYekVWddP)zyAI)lwAGXr1seKMZwIj8RyH5OM4YfFxCkkxjZZ2gEMe(nYykqF8MoX(tuNfG4SdPKIRs)jXWusQOm3aq26eVv88L)EM7mwYEgF(Z3X0(xt(mLNNN)MtWvBolPE4fSo2dnCowWJf6Ki2Fj88Zjw3K2prkyy8ECzUC3NxbR2z3wNYZivOuqqGptdtgvCV5myyM9IzlaqGrntSEj1nRx(Z)tFIdiC3UIAXxPe67uav8OjmxTV4La(bKjlo2Z80IR20jwa14HdaxIICgvNDTktfMPB6(R3W1aEecHIkacMw57E4jef7MZdL6feFtpzRTIckqmnNX)hZWAeR7QUFG5H85IsoFh8MfU0Jx85mEHZGiHkWNOUYiwflvjgIWySUYmufpcX2HS5vTNmfm)2jKZixBskgPMkkF5x28(RJoYltDg4JETbnmYsQr31twgZnzSzXesn2eBAuANHJiX3ZEgXZdyPjNrgrDJdvZE9CIuQA9iKVpCicuDPEO7UcE0yjY1JyPrrhDEROqI0(o63nZ(35IumlRXI0lchIQIk9kmsQXNzrGW(jLiinU6kvGAW5tsBr2GWXfquwuyA0eod82FB98XZC7flEHPqhlx8aHiJxE2Y4uLoB5mjcpi27m10h9sWFhxK0WEIltNoRq49yS5gBNMa4agg)dIO9Fd6qB5kmkMjLvYq7)8)()gWmeiJVSgEDnzohEwGJaZIo5d8IMm5JPgBmHyGRmI7osykfjBWccMO5pKjcl063DOBLRYlQWYlopDjkrDljvoeWuSDvG)rY8k5phEubY9WatSBdpzDH0(WHv7sT6ceS0Coyiilx(qGttWnJsIkr5QrDGJ74W1N1qAqWAmGi1PY(kUzdOBL2DV9eyTN5upaq4UZc9sLIwJDP(YOXOYyFCh9Hrw4vqWC4JTFcRqd9iaEcE975l(zMVf(MMNeLTnE5KDV5oBF8cw)5)5pWI2nHcA0bl7kgfaI1J3uFPyViMMTv(jd9mJljHrGyT)GBglPBGzkVqEqTz8I0sv(rY7xPp1377yS4Ue5m8mC7EiF6og8TK1kG2k9(kSr2jlnjcd5K3s7IcVvpq(uOpBGX4sNTjCAzsziXlYrjxTfaERirzwY2heRWPhSkDcktL)bBDXwqeR1d5ADusui1b9cKabshcHHprVVJr2MB2qGPTeAIWrGOlNYXTofbDdkd6k1LyYQ034yZT9M3jCtYd6gbaSDoeWmiRNa1Z79vCO87TD8sd)I2IWhSqVLE8UqTH1fQSlWkONWfUIzr0CYZem6UTZHpJJ6ESmm)8EHWAUUVLCRdJAaqP71sEK4zcVzioLXPuy4faCOoXUX4z37Ka1XRYne3sSWDWf76U2kSTirDWdVezTTpQwMaR3jN3RmOybuWtfuWSCmggMiOqg8xwfJPqMxswVbDGZ3FfavEhb7mGPHfL30nEWfAOJEyADUlvNhZaBGR8JzTPtAhI4(qzZjBVoQl7rgsjFLAmuKyA4XjXICBCaYNB)k0rLy7uy7QEnQU45)0R(2a1F(6FL)Et2yyzXWUx4qqe(TgyukKeo8PHDV0nFs1LT7gslUNbqIKpC8Dr71Sps0PZU1Wsx(gGK)XIdkij5OZo8jhvV8lZj3Ycexh46OAIysaJZpWGrHnqUF3l3o0YvWaNPHeWODyP0O4his82NT(FBSv7sA)fybZMmrDqXAbHFb7GyxGrPUnknjIc49liMMZz9iToqEDjUv2iJllc3pGvTwjjmBQg1brkwfAKfE7q5mGKsLAyPhmdEBme8HWmMy(nXKKc7)kF)1KxstypnWBxVMaTLRMpQ5lOfwLSMK9e3k001UCUFhb9xz7c7jAcv2JDYx2WQstXKTFvtoKk75nPAEUjpmUhu)di6Nji0620W2xCJfwb1Kx826H7XNRfLZ2Uf1v56u6PH4bZ1PaGl)yZi9KHWX5S9wpH3JkptifJ2nd0gLI)M5eNGLRkRpmfDyzy1ObLxIWw0rSUF3(NnCy)lMo5wc7SC4INOAS(Y1BGIffTd5yCNxpoq1H(V9nyhoqx71WdHBH5AcBpV41L72n4A2RVW2eiSmWI47qaTeyVu(raGx8kRTJCbLFeTXvpEHphVPMqD9PEADDBwzVEK5ex63gCnRKA9Ch1y4gxlrleB)FDvK3XksF43IBCPfaCSBBZMkqOD5c2XTtydgp(0VUig6tv(6Jk6EDarc7Kr6bRPJv3cu)OnvE7aG(aa8lwU(BWXcFGqJ2XfSFXfkaXnsF7KaLkmbjaTRgpOvMMz0QWwF0QDQ29mE8W7VpDxpgn(8EDAjPdzHgS91uVfZ8JXsSCnQValC4r8y7SV9RV9TPRWAjRSXRUOvbNnSwfFUWKy5F8LPiOCWdfugtY33asIrU2oH3dQ1(tnEuwHMMvWxEIPVSXXgYVHYZLj6B3q4nxSSL9vRyObtGJH1nupyLPAG6B84VelQXAQLok0q6NEIUuJJTHnK7dwpLLMPVoMYdVT(Hs1)ITjaVXJU293obZWYqBvYNMD(HdNvHct)9nMqDzEMXJBs9pCs)hSULjMMpWhcWvYVjYvl(sdsmZ3cP6LqJedPx4JYqd2LS8xpNY9EzA7bg03Som83fPTyOBm8aBXG5PtEsXDR(6Ni5uzDDzVaFEC7gf5ECbHCr7DfZCIDGU0hvmuFzSx0XqqCUdpDCYOrNySyC(9so5UuF14(9ALj4A)E9KhRw(oshHk7P9ywUA9nP3ctuZsLEr)wLS)QTos2wN2kvwgxnEyj6XbBJJpeAB7SzlP07(7LcbDYIbdsYWFC2b4cqeMuNdi2HSkXkfRDILcy5lO9YTaykJMh5bibcLJECkqpsZdg2rOWpaBrBbksIDqnsjYU5TLySZQ05xsuJWcXNj3kIk8KMD2CJv9OdqmO500N3wu7t16du4BLyvWOX9tkd1)K3kF61ehvwCEfzXPL584MA2hKp4ap2YOlJcnui09KSFso1eOp0FAoXqtyvBaYKonYm(IAAQ17VcDK46E3)eBKceY8fVB6FIJxX1XSIA(zZi3yL8lCzpjR1Jpl9x9G6KwzD(9pi5AwhQm9mmBgLwzIuEukMwumTg9tAqoXi(tio2BTSFLds56OzwHwP8gEf6n8OY2jMK65o8BsqovoQB1zyxJg(0(fQy5f(Cg)g9JmqoPlU92PjfTZLDdUQ7(7ZDzHROrJh0PuMs5Ft8vquKu6XJlb5bv9g(STHO06O2PwrpK76m7oQfATA(xQ)o4JPTSOzJWo4M17tNC5S08p4(CcSM4Rxptomj)c8Bv4xF)OX7Fs4Olof13QxJoklM2VbRyvcb3KFb8vBvtBlRWVu6VW96OA7K7hMSS3)M1RTyN2yo8m55Fxya(N0KVBSQtf(b4lLkcGC9a45JK5iUWZbiCRCbtuwNvxCERI3uxCGRLd5ha1t6Xa8WP0BLd891hMuZ0gL9ItWABM3d65(0wUN0(TYEx4A9Nu(jaVoLwCOogTrOlXgDFM7WXKhSryqayfEuAAv15zkR56S9J5QkYAALvYP0tU6EuL6Bg1589I6iTXc97Ez165bKWuXI0)QJS1Fb)FRw4uF1MNlu5NM5diDO0a0xEqIcW05c0yPlg2DCOXLowhembGOezrpuN(4SqG0431ALXrB7sda1AV7w)oWGuiNRdq6uQ2DmGWhm8Tw(JFerDL6aG1JCxgvT(hG4AJn8Y5voRoRPkZRKYbZRuX1u3St7BwOjDX05rOTrTzB6v7OcYV)(0njjo2sHzc)eP)ouvrYZcfcBPuMFJJob)XlASEIdosvpRw8Ujw1JgUpgiUTxodTvpLydqQ(PG)ww5tv)IaJqkjiXBM638j4FSY2z6KFXW8oc)eAp9)p]])
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

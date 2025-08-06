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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:DZ16UTTrw4NfdJkl14OkzrFRRLbYTUnoPTbvPO)yrL4yYrsmMIulVehhyqS)DFe2)Vpz9jzpNzgEFgskAjNSTaUoMC4mNZ35(zgYPdN((Ptmjb0P)8rdo64bNn44(d10o9OJNoj4U10PtwtmUHSa(hoKvW))zMK1bwFKgP)Cp6TRi(buVi9FKEJLTvKU785wgweB8XUZ2LyItVVBONb8OtNCDOLDWRDMEDH1uR)anTZ0obg7AQbC5toB6KLwMMu(yP(gtN8(Lw(r64pKiDbvHRi83gbwUor62w(bWTN7Mqr9NoHDrKmmC9OWV)zgltDixBtnN(8Pt4pnqC2WC6ggm7glJB4lQN1A(9gl))I0FbmPr6DNSK4rnJ0FR7clJEr6kh)prSCcGFI0NSmC(CB4HVg(nWxWpRS89TCwaKQNfaRweG6PFKAhPFj8OJ0I07ePBS0QVrONh1jGF9JyxEp(e13NpT9dxpnaasf8k9tRP2ZaIEvbg938bk6v4DbieUnNWEjfKlEGedyakXp0JgljmqDHSemJimJh)SvIHd0tzQ)Ii9JJ0)2i9aInCH(eFdQJpqh9fKCK(tI01ydzVQgfmXuhQ3I76deuirayAdIrgXtU29wQ3m)apRBakkgwayAKcy6g6Iz(Go(szO0BOlaPiExybCJ0xGKadJEXsloUz7ElGroMi55gUyzmzMfWkIiJym9WAWfvCmYnAk4MaRfa7VMyxuONQu(ECir6VdbkqTwO9ns7j9YPHcMDWTbLilVA1x7kumfRooZ9nDVfwS7VxYT8ORakbuTUGRA3d5OJ3oQXwoFiKzMYejoUbcrLbz9AyIZWglPe7GL9bLyJy5YWbd(kwd(KVIriqJ(PTxJogb6kX13i2nz6q5rg0BdtZ50w4S)xPZbpwlZ4IMbnbhGo8UgEiU9ot9NYnfEiEU7wWZDolGrCZKYE3f83zk4pyTMDlbDnxwQZKO)o5JcgJlsOMhYcFdKPRRnAGEyd0ceIZ4vlN0mEEsVBoo7X1AcM6ZogbSZlayLeyxOwEn8b7qtdfBYCidu2WbTqx95UVjrpvzufMUgBjuL7ZghAGeGAh3bH4quB3hbyOQmzus5X0lChiLqlBB8VyPgMgvltuAU(sQk)swyoQnAWe6JlB1mzz9TrNirdh1Ia(jy6e3ps9MdlDLPK6rjblN5oF2CWvtJZjfTv)fX0xrUOmNbpNTe88O)bM)mwcFwF(Z3XqGFK8zkpxVW1hI2CElOb4fCoiafEEoWWIDvK6Weg)1eNBY7TihumElASl3)5LGnp72MuEwPcMcch(zACcPI7LhPzQNvL)8IqINPmFR)D8gr63UK6WnsIDCkqiEueMF2x8sa2a9ihoKZCZIgAMehqZ9Xd3y8schRkv4QCcX4rZWvR5CcpmHGHfacJ7c9396dCJlt6CsODqv2wgeB7z8)ygwJytTU(jM3WNjk58TWtQ0eJx85mEHZajHu6hP(vPyvMQYmfXru9RsqvEgsb8I5qTLWCwqTm0zIRTkkgPggf82vrE)vXJ8ssNb(JxzrJJIKB29dQkJ5nzUz()Zn3exAsANXZijmWDgjiGGgoPRitrDTh1WD11ePQQntH8DXtrKUpnaDRPyOPuKFaXXGIE7cwsHKMd9mVBM7N4KuQwwfwpSWDwFg9McUoVTP06lIN76cl9QK5N3OPmrQrZUCrRb3pzfsfJeNwfH0qXQnfH0wLWBPPqNsxXPqNsq8qGOnG8SLXjoF2Yfse(Ouh0u7q0Vb)z8r1i2ioNlU8R0l3hix3uzZeaSXy3VxeI)7qVBlwIXWSPSQf6(N)7)7rmWhv)RQnxxrUMJmZXzGjfN8EEPs2850GnNqeWLwP9fjopISTwbXruKhRwcwDd7pYVwtEvvuE2P5RojPhp5sCawIMw6Tk9NYq)UhvGmpSWS5wZZsxqTpEyv7ksxvOmfiilj(yGZqOBMKcvMkvt69g3zHFiR70aH1AarQJKTvq0MPUPkG6odS2Y6upcqyR0cdYLIwvH(Y4oUP(wFzYmxBGp(ShhDHxibZPp29jS(m01a4s4hFh3latoop02(WKKTXlNTdo35gIxW5p)x)hSSDBOwhtqeVKPlazaG30CHyRiMwSz(z53zCkjokeRPiC5zf9dSqvgYdSnJxIwn1DTo0ZA(DkY64DX3mg8EkUnqKpEhdaxWAhqxTbFd2m7S1MKGIC94kBJcVfqqEwO7Bq5XNolpnfRdM4ZKZ4ciVtcPmlBleQYj4gZY)KRPyFis56rCUojhku5bDiKbbYhnHHpjpVNvXUB2sGPReffHpbrBoLJB9ubDhvLlX6QsFTNlxKBFNWrjpSBcFZ2iraQG8EI0pDW3WrWFW1lipQl6gcFYI9xgWBa1AwdOkAzPOxWknvMNSM80atUB3sWY4KUgldQpDqmAwQXB8TmuvnxfOGcWAzm5PchAiIvWVuCOgaMOEPEY4z37Lb)XRYfj3sCWT2f77UXsSbjjTXdVezLBiYG2GAVxjhyfWtf6Ghl0blQKXqZEvvXOjz1AQJSnz5LS7eVblaI8wc2UaBlhkVJB8io0y)8Ws6DxUwpwaYap5hW6rN0(eXDHMsnnvhsgkj3mLhNelYTIaKEH(ilm7det6SBTCkAcQma4ZCFf6RsSLkSDwVb1A8SF5vFFK(VE1VZFUjRTCCyi4l8iio)glmufQgo6jXnW0VCk2vTnhsR7NbtIurkXYY3jKYdlnUGKuLoz3NQuDzBwmqCtWK9AiSiHJpDhZXkBu8W(N3iijTfkc1SzgOwgVROvefx2WZBvSJuJ38S3)lJGSvLbukzIMauncL(k2lqlqQk82xrse1BgOqVFoX2(AwduBI8OPkU12yJZvju2HvXklvJMW0QPYwjH3mGSaoOvRJsvhmdvTXqi)JZuI5NetokU1R8DxtEDmX90aVDZAc0gAAVx7TUfIOIYNTKUuSCSB1669eQ7AnkgOKJDYx3iPwBHHn3QjVISKZBYgQNBZdBha18a8XjcfAtxACplUXbRAAYlEtZecPhYfTt2ml86Cvk9yq8i4Qu5XMzZoziC4Uyl2Z4eP2ZeIAqVDy3f50PlCItWkvL1dgENmbFBqLKisLCeRh2F4jJgn8SPtULWoZg(4jQglLC1AOUqr)poa351dI09O)Zql2bb03DfmiClmxry7WfV8B)(rxXE85U2GokdyiHEeGJafwkFV(51PYAWixOWpI2O1tq844TVekFp3OnnDzv4gqUM4t)(ORyvpBw6yfd34kjCHy7)BkJ8ww94J(EC)jDaGJDBx2sbeTpNWoOBg8E84J)wvkLpr7B3t196bKe2WI8twBNR(ky)KnvEZaGHaa8Bo(HRX5chqSq7af7xSsciTr6BgfOvJiidOD54J6uOVfDu2LJoDZ1vNXJhD)95BWXfJpDqVosAjwSaBBT0BWk)LWeRul5viHJpIhBM8DyZLVT1cRJSkdV8SokodyDuF(VKi5)Yttjq5rpwqzQs(2gqYmZn2j8wGT2ESXxel08AfCZtmvL1EUqUmuEEljVNgcV5cZw2ROILbSaEwo3qdalt9i9xhWFiwuJvuhtKOHmodenKgNBlxiphSekhd7qtm9gE37JPQ)bRx)VoGUY)poeZMYYyz2rZoRWXRQGHPFATnukwGD68ML)Jx0)gRHyIL598PaCL8hI8YsV0rzw5BH06YWrIPmiEOm0GDjNWvxt5EVSDdab6Rxfh(7S8sm0ngEGTyW80j7RUL0xTVKtL1vv9a81XVFsK7Xkc5IY7Aw5m71CLdvmvFDSRZPqqAUdpzC2OrhAnFC5Dno7(rF54Hd6ui46WbdKhRw(EpNGkBP9swoB9D53zuKZYLEXWovSpQD2t2wK2jxwgxoEuf8XoBdI3fCB3IzlPn4(7Lcb9kIbhLvd)lZw(QaryuDjG4bKvjwvyJtSualFfTLTkGPcCEIhGmiuj1JJb1J86bJ6jy4hHDJvbJKzpztyII7tBfc7ImDztIgewi9O3wtuH9B3rWnL1toaXaNtZFoHrUpxBoqIVtgRGlgpmln08ZzR8L3qCuBX1vKfNrHtFBUv)OYbh4XwU48KqdkHU9l(Q30qGEx)k4KcnXvTbit(0il4lQTPwV9k0rIR7h(7uJuGqMV4hg)N5KuCvQwrdF)yKlSY(Y3SLO1MPpl9ZBqtsRSjFOdYAZ6rLXNXzZO1PqKY9YPPLetRvF(ckrgPV00PERL9fniNRJ2jf6KZB4LO3W9QAZxYYNpGpabLy5Kotxq76IrpzOsgRmXxs43QpOaLOU0w5NxPOBPSBqRU7VV0LfUIUy8r9QutP63)9AuuKu6XxwfKhv2B0t3efLo71nNf9iURZI7OwS0Q9Vs(paFmDLfn7cSdUf9(0RuolT)1RVebBiE95lKdt233(okFx7Vy82xj8IZog536TrVOiMoSfwSAXGB2x196LQ5LL14xk)BZEtyThK7hgTS1F)0BmzNxyo6e55FRma)(T5vfR(uHFeE5Osai)aaE(a5Aex45aeVTTGiQOZQZoTJ6nWfN4g5q(rG9KEs)2Dm9g5aFB9Ui1oUrBR4eSXI5TaFUnLLBjUFJK3kT13V6J5DtkTyxDsztqxIl6(S05HPmyJWGaWuE6z6u35zQO46KTJ4QoL18mRKtPNC2DVA53cSZPBf2rAJfg2)865ZDOctngP))oY2Cd()sz40C2MNlu1hy5DO6qLbOpFNefGXZk4yPgdpCCO1Lo2eemdGOLir3vh44IqG043nYYyVn10aqTUpCPFpysuQZ1du60Q3DmGW7m8Tr(J)cI6AnbaBMYDvQQn)md3ySHxoV2jnXMQkVsA7mVsQRPUDNS3Iqt(IPlJqBcBZ20RUjfKF)95BssASfLzcVV0Vdv1K8SGHWwkv4BC0H4hVOXMzo4i1nwJ0DtSUHgVpgiUTvodT1VKydqQFuWVLv(u9piOrivjiZtM7B(e8hlD9Mo53SSVJSID(SN()(d]])
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

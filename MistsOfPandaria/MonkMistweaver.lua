-- MonkMistweaver.lua August 2025
-- Adapted by Himea

local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

-- Helper functions
local strformat = string.format

-- TODO: There's some issues with tracking mana percent properly.

-- Enhanced MoP Specialization Detection for Monks
function Hekili:GetMoPSpecialization()
    -- Prioritize the most defining abilities for each spec

    -- Windwalker check
    if IsPlayerSpell(113656) or IsPlayerSpell(107428) then -- Fists of Fury or Rising Sun Kick
        return 269
    end

    -- Brewmaster check
    if IsPlayerSpell(121253) or IsPlayerSpell(115295) then -- Keg Smash or Guard
        return 268
    end

    -- Mistweaver check (currently not implemented, but placeholder for completeness)
    if IsPlayerSpell(115175) or IsPlayerSpell(115151) then -- Soothing Mist or Renewing Mist
        return 270
    end

    return nil -- Return nil if no specific spec is detected, to allow fallbacks
end

-- Mistweaver specific combat log tracking
local mw_combat_log_events = {}

local function RegisterMWCombatLogEvent(event, callback)
    if not mw_combat_log_events[event] then
        mw_combat_log_events[event] = {}
    end
    table.insert(mw_combat_log_events[event], callback)
end

-- Hook into combat log for Mistweaver-specific tracking
local mwCombatLogFrame = CreateFrame("Frame")
mwCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mwCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")
mwCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
        if not state or not state.GUID or sourceGUID ~= state.GUID then return end

        if mw_combat_log_events[subevent] then
            for _, callback in ipairs(mw_combat_log_events[subevent]) do
                callback(timestamp, subevent, sourceGUID, destGUID, spellID)
            end
        end
        return
    end

    if event == "UNIT_POWER_UPDATE" then
        local unit, powerTypeString = ...
        if unit == "player" and state and state.spec and state.spec.id == 270 then
            if powerTypeString == "MANA" then
                local currentMana = UnitPower(unit, 0)
                if state.mana and state.mana.current ~= currentMana then
                    state.mana.current = currentMana
                    state.mana.actual = currentMana
                    Hekili:ForceUpdate(event)
                end
            elseif powerTypeString == "ENERGY" then
                local currentEnergy = UnitPower(unit, 3)
                if state.energy and state.energy.current ~= currentEnergy then
                    state.energy.current = currentEnergy
                    state.energy.actual = currentEnergy
                    Hekili:ForceUpdate(event)
                end
            elseif powerTypeString == "CHI" then
                local currentChi = UnitPower(unit, 12)
                if state.chi and state.chi.current ~= currentChi then
                    state.chi.current = currentChi
                    state.chi.actual = currentChi
                    Hekili:ForceUpdate(event)
                end
            end
        end
        return
    end
end)


local function RegisterMistweaverSpec()
    if not class or not state or not Hekili.NewSpecialization then return end

    local spec = Hekili:NewSpecialization(270, true) -- Mistweaver spec ID for MoP
    if not spec then return end

    spec.name = "Mistweaver"
    spec.role = "HEALER"
    spec.primaryStat = 3 -- Intellect

    -- Resource Registration
    spec:RegisterResource(0, {}, { -- Mana (In Stance of the Wise Serpent)
        -- max = function()
        --     return UnitPowerMax("player", 0) or 100
        -- end,
        -- base_regen = function()
        --     return 0
        -- end,
        -- regen = function()
        --     return 0
        -- end,
    })
    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
    --     base_energy_regen = {
    --         last = function ()
    --             return state.query_time
    --         end,
    --         interval = 1,
    --         value = function()
    --             local base = 10 -- Base energy regen (10 energy per second)
    --             local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
    --             return base * haste_bonus
    --         end,
    --     },
    -- }, {
    --     max = function() return 100 end,
    --     base_regen = function()
    --         local base = 10 -- Base energy regen (10 energy per second)
    --         local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
    --         return base * haste_bonus
    --     end,
    --     regen = function()
    --         return state:CombinedResourceRegen( state.energy )
    --     end,
    })
    spec:RegisterResource(12, {}, { -- Chi (Secondary)
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    spec:RegisterStateExpr("time_to_max_energy", function()
        if state.energy.active_regen and state.energy.active_regen > 0 then
            local deficit = state.energy.max - state.energy.current
            if deficit <= 0 then
                return 0
            end
            return deficit / state.energy.active_regen
        end
        return 3600 -- Large number indicating it will never be reached
    end)

    -- MoP Tier Gear Registration
    spec:RegisterGear("tier14", 85470, 85473, 85476, 85479, 85482)
    spec:RegisterGear("tier15", 95863, 95866, 95869, 95872, 95875)
    spec:RegisterGear("tier16", 99252, 99255, 99258, 99261, 99264)

    -- MoP Talent Registration (Shared with other Monk specs)
    spec:RegisterTalents({
        celerity = { 1, 1, 115173 }, tigers_lust = { 1, 2, 116841 }, momentum = { 1, 3, 115174 },
        chi_wave = { 2, 1, 115098 }, zen_sphere = { 2, 2, 124081 }, chi_burst = { 2, 3, 123986 },
        power_strikes = { 3, 1, 121817 }, ascension = { 3, 2, 115396 }, chi_brew = { 3, 3, 115399 },
        ring_of_peace = { 4, 1, 116844 }, charging_ox_wave = { 4, 2, 119392 }, leg_sweep = { 4, 3, 119381 },
        healing_elixirs = { 5, 1, 122280 }, dampen_harm = { 5, 2, 122278 }, diffuse_magic = { 5, 3, 122783 },
        rushing_jade_wind = { 6, 1, 116847 }, invoke_xuen = { 6, 2, 123904 }, chi_torpedo = { 6, 3, 115008 },
    })

    -- MoP Glyph Registration
    spec:RegisterGlyphs({
        [123394] = "renewing_mist", -- Removes Renewing Mist's cooldown, but makes it cost mana.
        [123399] = "uplift", -- Uplift no longer requires Renewing Mist, but has a mana cost.
        [123403] = "mana_tea", -- Mana Tea can be channeled while moving.
        [123402] = "soothing_mist", -- Soothing Mist can be channeled while moving.
        [123408] = "life_cocoon",
    })

    -- MoP Aura Registration
    spec:RegisterAuras({
        -- Stances
        stance_of_the_wise_serpent = {
            id = 115070,
        },
        stance_of_the_fierce_tiger = {
            id = 103985,
        },

        legacy_of_the_emperor = {
            id = 117666,
            duration = 3600,
            max_stack = 1
        },

        -- Core Buffs & HoTs
        renewing_mist = {
            id = 115151,
            duration = 18,
            tick_time = 3,
            hot = true,
        },
        enveloping_mist = {
            id = 124682,
            duration = 6,
            tick_time = 1,
            hot = true,
        },
        soothing_mist_channel = {
            id = 115175,
            duration = 8,
            channeled = true,
        },
        thunder_focus_tea = {
            id = 116680,
            duration = 30,
        },
        mana_tea = {
            id = 115867,
            duration = 120,
            max_stack = 20,
            emulated = true
        },
        serpents_zeal = {
            id = 127722,
            duration = 30
        },
        vital_mists = {
            id = 118674,
            duration = 30,
            max_stack = 5
        },
        muscle_memory = {
            id = 139597,
            duration = 15
        },
        tiger_power = {
            id = 125359,
            duration = 20
        },

        -- Cooldowns
        revival = {
            id = 115310,
        },
        life_cocoon = {
            id = 116849,
            duration = 12,
            absorb = true,
        },
        death_note = {
            id = 121125,
            duration = 3600,
            max_stack = 1
        },

        -- Talent Auras
        zen_sphere = {
            id = 124081,
            duration = 16,
            hot = true,
        },
    })

    -- Ability Registration (MoP 5.4.8 accurate)
    spec:RegisterAbilities({
        -- Stances
        stance_of_the_wise_serpent = {
            id = 115070,
            gcd = "spell",

            handler = function()
                removeBuff("stance_of_the_fierce_tiger")
                applyBuff("stance_of_the_wise_serpent")
            end
        },
        stance_of_the_fierce_tiger = {
            id = 103985,
            gcd = "spell",

            handler = function()
                removeBuff("stance_of_the_wise_serpent")
                applyBuff("stance_of_the_fierce_tiger")
            end
        },

        legacy_of_the_emperor = {
            id = 115921,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,

            handler = function()
                applyBuff("legacy_of_the_emperor", 3600)
            end
        },

        -- Serpent Stance Abilities (Healing)
        soothing_mist = {
            id = 115175,
            cast = 8,
            channeled = true,
            gcd = "spell",

            spend = 0,
            spendType = "mana", -- Cost is per tick

            usable = function()
                return buff.stance_of_the_wise_serpent.up
            end,
            handler = function()
                applyBuff("soothing_mist_channel")
            end
        },
        surging_mist = {
            id = 116694,
            cast = function()
                return buff.soothing_mist_channel.up and 0 or 1.5
            end,
            gcd = "spell",

            spend = 0.063,
            spendType = "mana",

            handler = function()
                gain(1, "chi")
            end
        },
        enveloping_mist = {
            id = 124682,
            cast = function()
                return buff.soothing_mist_channel.up and 0 or 2
            end,
            gcd = "spell",

            spend = 3,
            spendType = "chi",

            handler = function()
                applyBuff("enveloping_mist")
            end
        },
        renewing_mist = {
            id = 115151,
            cooldown = 8,
            gcd = "spell",

            spend = 0.044,
            spendType = "mana",

            handler = function()
                applyBuff("renewing_mist")
            end
        },
        uplift = {
            id = 116670,
            gcd = "spell",

            spend = 2,
            spendType = "chi",

            usable = function()
                return settings.uplift_min_targets <= active_dot.renewing_mist
            end
        },

        -- Crane Stance Abilities (Fistweaving)
        jab = {
            id = 100780,
            gcd = "spell",

            spend = function()
                return buff.stance_of_the_fierce_tiger.up and 0.8 or 0
            end,
            spendType = "mana",

            handler = function()
                if buff.stance_of_the_wise_serpent.up then
                    gain(1, "chi")
                elseif buff.stance_of_the_fierce_tiger.up then
                    gain(2, "chi")
                end
            end,

            copy = { 103985, 108561, 115697, 120267, 121278, 124146, 108557 },
        },
        tiger_palm = {
            id = 100787,
            gcd = "spell",

            spend = 1,
            spendType = "chi",

            handler = function()
                applyBuff("tiger_power")
            end
        },
        blackout_kick = {
            id = 100784,
            gcd = "spell",

            spend = 2,
            spendType = "chi",

            handler = function()
                applyBuff("serpents_zeal")
            end
        },
        spinning_crane_kick = {
            id = 101546,
            gcd = "spell",
            cast = 3,
            channeled = true,

            spend = 0.048,
            spendType = "mana",

            handler = function()
                applyBuff("spinning_crane_kick", 3)
                if active_enemies >= 3 then
                    gain(1, "chi")
                end
            end
        },

        -- Shared Abilities
        detox = {
            id = 115450,
            cooldown = 8,
            gcd = "spell",

            spend = 0.046,
            spendType = "mana"
        },
        thunder_focus_tea = {
            id = 116680,
            cooldown = 45,
            gcd = "spell",

            handler = function()
                applyBuff("thunder_focus_tea", 30)
            end
        },
        mana_tea = {
            id = 115294,
            cast = 10,
            channeled = true,
            gcd = "spell",

            usable = function()
                return buff.mana_tea.count > 0
            end,

            handler = function()
                removeBuff("mana_tea")
            end
        },
        revival = {
            id = 115310,
            cooldown = 180,
            gcd = "spell",

            toggle = "cooldowns"
        },
        life_cocoon = {
            id = 116849,
            cooldown = 120,

            toggle = "cooldowns"
        },
        expel_harm = {
            id = 115072,
            cooldown = 15,
            gcd = "spell",

            handler = function()
                gain(1, "chi")
            end
        },

        -- Talent Abilities

        chi_brew = {
            id = 115399,
            cooldown = 45,
            charges = 2,
            gcd = "off",

            talent = "chi_brew",

            handler = function()
                gain(2, "chi")
            end
        },
        chi_wave = {
            id = 115098,
            cooldown = 15,
            gcd = "spell",

            talent = "chi_wave"
        },
        chi_burst = {
            id = 123986,
            cooldown = 30,
            cast = 1,
            gcd = "spell",

            talent = "chi_burst"
        },
        chi_torpedo = {
            id = 115008,
            cooldown = 20,
            charges = 2,
            gcd = "spell",

            talent = "chi_torpedo"
        },
        zen_sphere = {
            id = 124081,
            cooldown = 10,
            gcd = "spell",

            talent = "zen_sphere"
        }
    })

    -- Combat Log Logic: Mana Tea Generation
    -- Mana Tea: For every 4 Chi you consume, you gain a charge of Mana Tea.
    local chi_spent_for_tea = 0
     RegisterMWCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, destGUID, spellID)
        local ability = class.abilities[spellID]
        if not ability or ability.spendType ~= "chi" or not ability.spend or ability.spend <= 0 then return end

        chi_spent_for_tea = chi_spent_for_tea + ability.spend
        if chi_spent_for_tea >= 4 then
            local stacks_to_add = math.floor(chi_spent_for_tea / 4)
            if state and state.addStack then
                state.addStack("mana_tea", nil, stacks_to_add)
            else
                applyBuff("mana_tea", 120)
            end
            chi_spent_for_tea = chi_spent_for_tea % 4
        end
     end)

    -- State Expressions for APL
    spec:RegisterStateExpr("active_stance", function()
        if buff.stance_of_the_fierce_tiger.up then return "tiger" end
        return "serpent"
    end)
    spec:RegisterStateExpr("renewing_mist_count", function()
        return active_dot.renewing_mist or 0
    end)
    -- Commented out until mana is fixed
    -- spec:RegisterStateExpr("mana", function()
    --     local maxMana = UnitPowerMax("player", 0) or 100
    --     local currentMana = UnitPower("player", 0) or 0
    --     local pct = maxMana > 0 and (currentMana / maxMana) * 100 or 0
    --     return {
    --         max = maxMana,
    --         current = currentMana,
    --         pct = pct,
    --     }
    -- end)
    -- spec:RegisterStateExpr("mana_deficit", function()
    --     return mana.max - mana.current
    -- end)
    spec:RegisterStateExpr("mana_tea_ready", function()
        return buff.mana_tea.count >= settings.mana_tea_min_stacks and mana.pct < settings.mana_tea_health_pct
    end)

    -- Temporary expression to fix a warning about missing threat value
    -- Should probably remove this
    spec:RegisterStateExpr("threat", function()
        return {
            situation = threat_situation or 0,
            percentage = threat_percent or 0
        }
    end)

    -- Options and Settings
    spec:RegisterOptions({
        enabled = true,
        aoe = 5, -- Default number of allies to consider for AoE healing
        cycle = false,
        nameplates = false,
        damage = false, -- Mistweaver is primarily a healer
        package = "Mistweaver",
    })

    spec:RegisterSetting("uplift_min_targets", 4, {
        name = strformat("Min. %s Targets", Hekili:GetSpellLinkWithTexture(spec.abilities.uplift.id)),
        desc = "The minimum number of players with Renewing Mist before Uplift will be recommended.",
        type = "range", min = 1, max = 20, step = 1, width = "full"
    })
    spec:RegisterSetting("mana_tea_min_stacks", 10, {
        name = strformat("Min. %s Stacks", Hekili:GetSpellLinkWithTexture(spec.abilities.mana_tea.id)),
        desc = "The minimum number of Mana Tea stacks required before it will be recommended.",
        type = "range", min = 1, max = 20, step = 1, width = 1.5
    })
    spec:RegisterSetting("mana_tea_health_pct", 75, {
        name = strformat("%s Mana %% Threshold", Hekili:GetSpellLinkWithTexture(spec.abilities.mana_tea.id)),
        desc = "The mana percentage below which Mana Tea will be recommended.",
        type = "range", min = 1, max = 99, step = 1, width = 1.5
    })
    spec:RegisterSetting("fistweave_mana_pct", 85, {
        name = "Fistweave Mana % Threshold",
        desc = "The mana percentage above which you may be prompted to enter Crane Stance to conserve mana.",
        type = "range", min = 1, max = 100, step = 5, width = "full"
    })

    -- APL Package
    spec:RegisterPack("Mistweaver", 20250807, [[Hekili:fFvZsUTnm4NLmzgVhAIRT8UR3MXApKtjzAYfLEvs0sWwSwsuLKADCoON9cqzzQFJ92lD8SRTa)WhajabG8x6)DFVyMg8)MZcNhw80I1ZxUEHZI7990NkaFVcw0b2E8h5Sm8)FLR0hb2lGSk8JGMraoLkyXerkrPmcb57TTKNQ)CU)2HS)49pUATVhRuNiK(EFINbilj84yOgpOI89(Ecxvfs)XQcp7dvHID4ZrAUiVkmf9eC5Dc0t(eCGNYNJoJuSJNIUWBFBv4xf5h(a(L1L)c9PMa18cjejY2Y0)M7VR0S8iiqSlqNabh5kiqbYcixpo(uypl6udEiRaKc5747C3wUB3CKnTAES4y(mZZJI2SEl)bzTenlxdzQ2c3MkeXb7kLN6ifKOdEGNVVTuMmILdbAHu221XvYy5SanWU4JncMhjkZ1p76mJKmVisVX9PfZ2NEQiXccYzBtH42mgLWd2kHJeJAwkAV5nIAGpdfSXDz3nj8JciniHjZinreOv(X7XVF2D5SeGLQtmEXtl6ynwAAq9JbuK)Du6OltaVtPL8iT7sIncWl4jCoKXb1ZURUof43tZWMvD9DAdIhUfqSO32(S0l78mXlySH27D1(iMh2tvs0yhW)eYdufjGSTcwHxm1BmXZwluwmiovkX9zVafjBm7IPoWr05dY41k1ngDRXYU5W4nyrPo4ap6G9As9nmvWpXO(CjKX45QnoTvuvk332vm69ch3ggrQ6Sx3h6OtbppNukssxgAm5GCJzt7V)nB7ijd4DKPvrZ3dYGcwAZrbLoBC3ZRiocYw1eYkvrPqqgKjKN6fYgCCzOZ56koTt0xlFVJmjDkPOATyPvEwHqQpxp9UyyhRmvFxvOe(NsUeZqcvImehw3wKHL0rbrjS89GAE1x(tEoU0ASy7FLRkliMianLQVZMNC3f0lxmj8wxOAH3zs82C)wWF4g9gZUFNinvqj90guYW(ky0cLJvKrn5OwAcwdfu5JQWTL6gC5cZrxzEh0XXeySbiBltbFaRLe(ECnB(Wzjw)Nk3ms44sRNxxaz6tSr7i9)YPXOEcDm85SgV2PxtF0nXznkGiCSI1l89mcndYuN1I)8BMbBQ1Y37sFvFVZ178)OVg1UniBF2EOw1b1L(U9qDFBuD7d3d5desReVij6BsoJMAAqJ5QWNDnNaZQcBAqxfUbLH9hjHJ3O26knRqw(XjT8enWnwafwBXLwwBasSUEswpxT0eNnSq7LLgsTn6rUPnJLB71tI9NMK9UvNRjFfMyy6MtzawVTxN)6uMG6jAXzii78h3SD28FYm4Je6f3siO3We1bFZafvHdJdNrBOF5TqF7bo6sfTIHhNRXZW5qmE5BO6a9NgXAdRyJvwDnRmyoLEzG0sgMU)vMdA5PZ0ogUM((514QBM7YPVUn94pM0lN2vLAnkGH1PVUn(WrMuMhSm2EKkdHVYByn1e(LNeJmdMXwVIBzxk7DnBHdRzkMp9vRE1EgDQm7kdhvQXs2XRmgC6lBxmOZTq7GySZ0x)gBRCJoSME94ZZrmOf50Va8y9m)fj1xE1xR)n9R)AT)OymoD9h))9d]])

end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterMistweaverSpec()
        mwCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

if not TryRegister() then
    mwCombatLogFrame:RegisterEvent("ADDON_LOADED")
    mwCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

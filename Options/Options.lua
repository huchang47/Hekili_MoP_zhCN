-- Options.lua
-- Everything related to building/configuring options.
local addon, ns = ...
local Hekili = _G[addon]

local class = Hekili.Class
local scripts = Hekili.Scripts
local state = Hekili.State

local format, lower, match = string.format, string.lower, string.match
local insert, remove, sort, wipe = table.insert, table.remove, table.sort, table.wipe
local UnitBuff, UnitDebuff, SkeletonHandler = ns.UnitBuff, ns.UnitDebuff, ns.SkeletonHandler
local callHook = ns.callHook
local SpaceOut = ns.SpaceOut
local formatKey, orderedPairs, tableCopy, GetItemInfo, RangeType = ns.formatKey, ns.orderedPairs, ns.tableCopy,
    ns.CachedGetItemInfo, ns.RangeType

-- Atlas/Textures
local AtlasToString, GetAtlasFile, GetAtlasCoords = ns.AtlasToString, ns.GetAtlasFile, ns.GetAtlasCoords

-- Options Functions
local TableToString, StringToTable, SerializeActionPack, DeserializeActionPack, SerializeDisplay, DeserializeDisplay,
    SerializeStyle, DeserializeStyle

local ACD = LibStub("AceConfigDialog-3.0")
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local LSM = LibStub("LibSharedMedia-3.0")
local SF = SpellFlashCore

local NewFeature = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0|t"
local GreenPlus = "Interface\\AddOns\\Hekili\\Textures\\GreenPlus"
local RedX = "Interface\\AddOns\\Hekili\\Textures\\RedX"
local BlizzBlue = "|cFF00B4FF"

-- MoP: AtlasToString function not available, provide fallback
local AtlasToString = function(atlas)
    return "＊ " -- Simple bullet point fallback
end
local Bullet = AtlasToString("characterupdate_arrow-bullet-point")

-- MoP: C_ClassColor not available, use RAID_CLASS_COLORS
local ClassColor = RAID_CLASS_COLORS and class and class.file and RAID_CLASS_COLORS[class.file] or {
    r = 1,
    g = 1,
    b = 1,
    colorStr = "FFFFFFFF",
    GenerateHexColor = function()
        return "FFFFFFFF"
    end
}

local GetSpellInfo = ns.GetUnpackedSpellInfo

-- MoP: C_Spell.GetSpellDescription not available, use GetSpellDescription
local GetSpellDescription = GetSpellDescription or function(spellID)
    return ""
end

-- MoP: Specialization system fallbacks (similar to Wrath)
local GetSpecialization = _G.GetSpecialization or function()
    return GetActiveTalentGroup()
end

-- Force override GetSpecializationInfo for MoP since the native one is incomplete
SpecData = {
    HUNTER = {
        [1] = {253, "兽王", "Master of pets and beasts", "Interface\\Icons\\ability_hunter_bestialdiscipline",
               "DAMAGER"},
        [2] = {254, "射击", "Ranged weapon specialist", "Interface\\Icons\\ability_hunter_focusedaim", "DAMAGER"},
        [3] = {255, "生存", "Traps and survival expert", "Interface\\Icons\\ability_hunter_camouflage", "DAMAGER"}
    },
    WARRIOR = {
        [1] = {71, "武器", "Two-handed weapon specialist", "Interface\\Icons\\ability_warrior_savageblow", "DAMAGER"},
        [2] = {72, "狂怒", "Dual-wield berserker", "Interface\\Icons\\ability_warrior_innerrage", "DAMAGER"},
        [3] = {73, "防护", "Shield and defense specialist", "Interface\\Icons\\Ability_Warrior_DefensiveStance",
               "TANK"}
    },
    PALADIN = {
        [1] = {65, "神圣", "Healing and support", "Interface\\Icons\\Spell_Holy_HolyBolt", "HEALER"},
        [2] = {66, "防护", "Shield and defense", "Interface\\Icons\\Ability_paladin_shieldofthetemplar", "TANK"},
        [3] = {70, "惩戒", "Two-handed combat", "Interface\\Icons\\Spell_Holy_AuraOfLight", "DAMAGER"}
    },
    ROGUE = {
        [1] = {259, "刺杀", "Poisons and stealth", "Interface\\Icons\\Ability_Rogue_DeadlyBrew", "DAMAGER"},
        [2] = {260, "战斗", "Melee combat specialist", "Interface\\Icons\\Ability_BackStab", "DAMAGER"},
        [3] = {261, "敏锐", "Stealth and shadows", "Interface\\Icons\\Ability_Stealth", "DAMAGER"}
    },
    PRIEST = {
        [1] = {256, "戒律", "Damage prevention", "Interface\\Icons\\Spell_Holy_PowerWordShield", "HEALER"},
        [2] = {257, "神圣", "Healing specialist", "Interface\\Icons\\Spell_Holy_GuardianSpirit", "HEALER"},
        [3] = {258, "暗影", "Shadow magic and damage", "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "DAMAGER"}
    },
    DEATHKNIGHT = {
        [1] = {250, "鲜血", "Tank specialization", "Interface\\Icons\\Spell_Deathknight_BloodPresence", "TANK"},
        [2] = {251, "冰霜", "Dual-wield DPS", "Interface\\Icons\\Spell_Deathknight_FrostPresence", "DAMAGER"},
        [3] = {252, "邪恶", "Disease and pets", "Interface\\Icons\\Spell_Deathknight_UnholyPresence", "DAMAGER"}
    },
    SHAMAN = {
        [1] = {262, "元素", "Ranged spell damage", "Interface\\Icons\\Spell_Nature_Lightning", "DAMAGER"},
        [2] = {263, "增强", "Melee combat", "Interface\\Icons\\Spell_Nature_LightningShield", "DAMAGER"},
        [3] = {264, "恢复", "Healing specialist", "Interface\\Icons\\Spell_Nature_MagicImmunity", "HEALER"}
    },
    MAGE = {
        [1] = {62, "奥术", "Arcane magic specialist", "Interface\\Icons\\Spell_Holy_MagicalSentry", "DAMAGER"},
        [2] = {63, "火焰", "Fire magic specialist", "Interface\\Icons\\Spell_Fire_FlameBolt", "DAMAGER"},
        [3] = {64, "冰霜", "Frost magic specialist", "Interface\\Icons\\Spell_Frost_FrostBolt02", "DAMAGER"}
    },
    WARLOCK = {
        [1] = {265, "痛苦", "Damage over time", "Interface\\Icons\\Spell_Shadow_DeathCoil", "DAMAGER"},
        [2] = {266, "恶魔", "Demon summoning", "Interface\\Icons\\Spell_Shadow_Metamorphosis", "DAMAGER"},
        [3] = {267, "毁灭", "Direct damage", "Interface\\Icons\\Spell_Shadow_RainOfFire", "DAMAGER"}
    },
    MONK = {
        [1] = {268, "酒仙", "Tank specialization", "Interface\\Icons\\spell_monk_brewmaster_spec", "TANK"},
        [2] = {270, "织雾", "Healing specialist", "Interface\\Icons\\spell_monk_mistweaver_spec", "HEALER"},
        [3] = {269, "踏风", "Melee damage", "Interface\\Icons\\spell_monk_windwalker_spec", "DAMAGER"}
    },
    DRUID = {
        [1] = {102, "平衡", "Ranged spell damage", "Interface\\Icons\\Spell_Nature_StarFall", "DAMAGER"},
        [2] = {103, "野性", "Melee damage in cat form", "Interface\\Icons\\Ability_Druid_CatForm", "DAMAGER"},
        [3] = {104, "守护", "Tank in bear form", "Interface\\Icons\\Ability_Racial_BearForm", "TANK"},
        [4] = {105, "恢复", "Healing specialist", "Interface\\Icons\\Spell_Nature_HealingTouch", "HEALER"}
    }
}
local GetSpecializationInfo = function(index)
    local className, classFile, classID = UnitClass("player")
    if not className then
        return nil
    end

    local classSpecs = SpecData[classFile]
    if not classSpecs or not classSpecs[index] then
        return nil
    end

    local spec = classSpecs[index]
    return spec[1], spec[2], spec[3], spec[4], spec[5]
end
local function GetSpecTextureByID(specID)
    -- 获取职业代码
    local _, classFile = UnitClass("player")
    local classSpecs = SpecData[classFile]
    if not classSpecs then
        return nil
    end
    for i, info in pairs(classSpecs) do
        if info[1] == specID then
            return info[4] -- 获取职业贴图路径
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local GetNumSpecializations = _G.GetNumSpecializations or function()
    local className, classFile = UnitClass("player")
    if classFile == "DRUID" then
        return 4
    end
    return 3
end
-- EasyPlay提供的查询功能
ns.searchID = ""
ns.searchItemName = ""

-- One Time Fixes
local oneTimeFixes = {
    resetAberrantPackageDates_20190728_1 = function(p)
        for _, v in pairs(p.packs) do
            if type(v.date) == 'string' then
                v.date = tonumber(v.date) or 0
            end
            if type(v.version) == 'string' then
                v.date = tonumber(v.date) or 0
            end
            if v.date then
                while (v.date > 21000000) do
                    v.date = v.date / 10
                end
            end
            if v.version then
                while (v.version > 21000000) do
                    v.version = v.version / 10
                end
            end
        end
    end,

    forceEnableAllClassesOnceDueToBug_20220225 = function(p)
        for id, spec in pairs(p.specs) do
            spec.enabled = true
        end
    end,

    forceReloadAllDefaultPriorities_20220228 = function(p)
        for name, pack in pairs(p.packs) do
            if pack.builtIn then
                Hekili.DB.profile.packs[name] = nil
                Hekili:RestoreDefault(name)
            end
        end
    end,
    forceReloadClassDefaultOptions_20220306 = function(p)
        local sendMsg = false
        if class and class.specs then
            for spec, data in pairs(class.specs) do
                if spec > 0 and not p.runOnce['forceReloadClassDefaultOptions_20220306_' .. spec] then
                    local cfg = p.specs[spec]
                    for k, v in pairs(data.options) do
                        if cfg[k] == ns.specTemplate[k] and cfg[k] ~= v then
                            cfg[k] = v
                            sendMsg = true
                        end
                    end
                    p.runOnce['forceReloadClassDefaultOptions_20220306_' .. spec] = true
                end
            end
        end
        if sendMsg then
            local timer = C_Timer and C_Timer.After or function(delay, func)
                return Hekili:ScheduleTimer(func, delay)
            end
            timer(5, function()
                if Hekili.DB.profile.notifications.enabled then
                    Hekili:Notify("部分专精选项已重置。", 6)
                end
                Hekili:Print("部分专精选项已重置为默认值")
            end)
        end
        p.runOnce.forceReloadClassDefaultOptions_20220306 = nil
    end,

    forceDeleteBrokenMultiDisplay_20220319 = function(p)
        if rawget(p.displays, "Multi") then
            p.displays.Multi = nil
        end

        p.runOnce.forceDeleteBrokenMultiDisplay_20220319 = nil
    end,

    forceSpellFlashBrightness_20221030 = function(p)
        for display, data in pairs(p.displays) do
            if data.flash and data.flash.brightness and data.flash.brightness > 100 then
                data.flash.brightness = 100
            end
        end
    end,

    -- MoP: Removed fixHavocPriorityVersion_20240805 function (Demon Hunter not available in MoP)

    removeOldThrottles_20241115 = function(p)
        for id, spec in pairs(p.specs) do
            spec.throttleRefresh = nil
            spec.combatRefresh = nil
            spec.regularRefresh = nil

            spec.throttleTime = nil
            spec.maxTime = nil
        end
    end,

    migrateIndicatorDefaults_20250126 = function(p)
        -- Migrate existing profiles to include new indicator appearance settings
        for displayName, display in pairs(p.displays) do
            if display.indicators and not display.indicators.width then
                -- Set sensible defaults based on display size or use upstream defaults
                local primarySize = max(display.primaryWidth or 50, display.primaryHeight or 50)
                local queueSize = max(display.queue and display.queue.width or 50,
                    display.queue and display.queue.height or 30)

                -- Use roughly one-third of the smaller display size for indicators
                local indicatorSize = min(primarySize, queueSize) / 3
                indicatorSize = max(8, min(100, indicatorSize)) -- Clamp between 8-100

                display.indicators.width = indicatorSize
                display.indicators.height = indicatorSize
                display.indicators.zoom = 30
                display.indicators.keepAspectRatio = true
            end
        end

        -- Trigger UI rebuild to apply new indicator settings
        if Hekili.BuildUI then
            Hekili:BuildUI()
        end
    end,

    migrateFrameBudget_20250126 = function(p)
        -- Migrate frameCapPct to frameBudget (percentage to decimal)
        if p.performance and p.performance.frameCapPct then
            p.performance.frameBudget = p.performance.frameCapPct
            p.performance.frameCapPct = nil
        end

        -- Ensure frameBudget exists with default
        if not p.performance then
            p.performance = {}
        end
        if not p.performance.frameBudget then
            p.performance.frameBudget = 0.7
        end
    end,

    migrateEnhancedEvents_20250126 = function(p)
        -- Initialize enhanced events setting for existing profiles
        if not p.performance then
            p.performance = {}
        end

        -- Set enhanced events to false by default for existing profiles
        if p.performance.enhancedEvents == nil then
            p.performance.enhancedEvents = false
        end

        -- Trigger UI rebuild to apply new settings
        if Hekili.BuildUI then
            Hekili:BuildUI()
        end
    end
}

function Hekili:RunOneTimeFixes()
    local profile = Hekili.DB.profile
    if not profile then
        return
    end

    profile.runOnce = profile.runOnce or {}

    for k, v in pairs(oneTimeFixes) do
        if not profile.runOnce[k] then
            profile.runOnce[k] = true
            local ok, err = pcall(v, profile)
            if err then
                Hekili:Error("一次性更新失败：" .. k .. ": " .. err)
                profile.runOnce[k] = nil
            end
        end
    end
end

function Hekili:LoadOptionModules()
    local modules = {"DevTools", "ChatCommands" -- "ControlBar",
    -- "Displays",
    -- etc.
    }

    for _, m in ipairs(modules) do
        require("Hekili.Options." .. m)
    end

    -- Add enhanced events chat command
    if Hekili.RegisterChatCommand then
        Hekili:RegisterChatCommand("hekili-events", function(msg)
            if msg == "debug" then
                if Hekili.DebugEventPerformance then
                    Hekili:DebugEventPerformance()
                else
                    print("Hekili: 增强事件功能未启用。请在性能设置中启用。")
                end
            elseif msg == "stats" then
                if Hekili.GetEventPerformanceStats then
                    local stats = Hekili:GetEventPerformanceStats()
                    if stats then
                        print("Hekili 增强事件统计:")
                        print("总事件数:", stats.totalEvents)
                        print("总时间:", string.format("%.2fms", stats.totalTime))
                        print("最大事件时间:", string.format("%.2fms", stats.maxEventTime))
                    end
                else
                    print("Hekili: 增强事件功能未启用。请在性能设置中启用。")
                end
            else
                print("Hekili 增强事件命令:")
                print("/hekili-events debug - 显示详细事件性能")
                print("/hekili-events stats - 显示事件统计")
            end
        end)
    end
end

local displayTemplate = {
    enabled = true,

    numIcons = 4,
    forecastPeriod = 15,

    primaryWidth = 50,
    primaryHeight = 50,

    keepAspectRatio = true,
    zoom = 30,

    frameStrata = "LOW",
    frameLevel = 10,

    elvuiCooldown = false,
    hideOmniCC = false,

    queue = {
        anchor = 'RIGHT',
        direction = 'RIGHT',
        style = 'RIGHT',
        alignment = 'CENTER',

        width = 50,
        height = 50,

        -- offset = 5, -- deprecated.
        offsetX = 5,
        offsetY = 0,
        spacing = 5,

        elvuiCooldown = false

        --[[ font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 12,
        fontStyle = "OUTLINE" ]]
    },

    visibility = {
        advanced = false,

        mode = {
            aoe = true,
            automatic = true,
            dual = true,
            single = true,
            reactive = true
        },

        pve = {
            alpha = 1,
            always = 1,
            target = 1,
            combat = 1,
            combatTarget = 1,
            hideMounted = false
        },

        pvp = {
            alpha = 1,
            always = 1,
            target = 1,
            combat = 1,
            combatTarget = 1,
            hideMounted = false
        }
    },

    border = {
        enabled = true,
        thickness = 1,
        fit = false,
        coloring = 'custom',
        color = {0, 0, 0, 1}
    },

    range = {
        enabled = true,
        type = 'ability'
    },

    glow = {
        enabled = false,
        queued = false,
        mode = "autocast",
        coloring = "default",
        color = {0.95, 0.95, 0.32, 1},

        highlight = true
    },

    flash = {
        enabled = false,
        color = {255 / 255, 215 / 255, 0, 1}, -- gold.
        blink = false,
        suppress = false,
        combat = false,

        size = 240,
        brightness = 100,
        speed = 0.4,

        fixedSize = false,
        fixedBrightness = false
    },

    captions = {
        enabled = false,
        queued = false,

        align = "CENTER",
        anchor = "BOTTOM",
        x = 0,
        y = 0,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 12,
        fontStyle = "OUTLINE",

        color = {1, 1, 1, 1}
    },

    empowerment = {
        enabled = true,
        queued = true,
        glow = true,

        align = "CENTER",
        anchor = "BOTTOM",
        x = 0,
        y = 1,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 16,
        fontStyle = "THICKOUTLINE",

        color = {1, 0.8196079, 0, 1}
    },

    indicators = {
        enabled = true,
        queued = true,

        anchor = "RIGHT",
        x = 0,
        y = 0,

        -- Indicator icon appearance defaults
        width = 20,
        height = 20,
        zoom = 30,
        keepAspectRatio = true
    },

    targets = {
        enabled = true,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 12,
        fontStyle = "OUTLINE",

        anchor = "BOTTOMRIGHT",
        x = 0,
        y = 0,

        color = {1, 1, 1, 1}
    },

    delays = {
        type = "__NA",
        fade = false,
        extend = true,
        elvuiCooldowns = false,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 12,
        fontStyle = "OUTLINE",

        anchor = "TOPLEFT",
        x = 0,
        y = 0,

        color = {1, 1, 1, 1}
    },

    keybindings = {
        enabled = true,
        queued = true,

        font = ElvUI and "PT Sans Narrow" or "Arial Narrow",
        fontSize = 12,
        fontStyle = "OUTLINE",

        lowercase = false,

        separateQueueStyle = false,

        queuedFont = ElvUI and "PT Sans Narrow" or "Arial Narrow",
        queuedFontSize = 12,
        queuedFontStyle = "OUTLINE",

        queuedLowercase = false,

        anchor = "TOPRIGHT",
        x = 1,
        y = -1,

        cPortOverride = true,
        cPortZoom = 0.6,

        color = {1, 1, 1, 1},
        queuedColor = {1, 1, 1, 1}
    }

}

local actionTemplate = {
    action = "auto_shot",
    enabled = true,
    criteria = "",
    caption = "",
    description = "",

    -- Shared Modifiers
    early_chain_if = "", -- NYI

    cycle_targets = 0,
    max_cycle_targets = 3,
    max_energy = 0,

    interrupt = 0, -- NYI
    interrupt_if = "", -- NYI
    interrupt_immediate = 0, -- NYI

    travel_speed = nil,

    enable_moving = false,
    moving = nil,
    sync = "",

    use_while_casting = 0,
    use_off_gcd = 0,
    only_cwc = 0,

    wait_on_ready = 0, -- NYI

    -- Call/Run Action List
    list_name = nil,
    strict = nil,
    strict_if = "",

    -- Pool Resource
    wait = "0.5",
    for_next = 0,
    extra_amount = "0",

    -- Variable
    op = "set",
    condition = "",
    default = "",
    value = "",
    value_else = "",
    var_name = "unnamed",

    -- Wait
    sec = "1"
}

local packTemplate = {
    spec = 0,
    builtIn = false,

    author = UnitName("player"),
    desc = "这个技能优先级配置基于Hekili汉化版制作。",
    source = "",
    date = tonumber(date("%Y%M%D.%H%M")),
    warnings = "",

    hidden = false,
    lists = {
        precombat = {{
            enabled = false,
            action = "auto_shot"
        }},
        default = {{
            enabled = false,
            action = "auto_shot"
        }}
    }
}

local specTemplate = ns.specTemplate

do
    local defaults

    -- Default Table
    function Hekili:GetDefaults()
        defaults = defaults or {
            global = {
                styles = {}
            },

            profile = {
                enabled = true,
                minimapIcon = false,
                autoSnapshot = true,
                screenshot = true,

                flashTexture = "Interface\\Cooldown\\star4",

                toggles = {
                    pause = {
                        key = "ALT-SHIFT-P"
                    },

                    snapshot = {
                        key = "ALT-SHIFT-["
                    },

                    mode = {
                        key = "ALT-SHIFT-N",
                        value = "automatic",
                        -- type = "AutoSingle",
                        automatic = true,
                        single = true,
                        reactive = "false",
                        dual = "false",
                        aoe = "false"
                    },

                    cooldowns = {
                        key = "ALT-SHIFT-R",
                        value = true,
                        infusion = false,
                        override = false,
                        separate = false
                    },

                    defensives = {
                        key = "ALT-SHIFT-T",
                        value = true,
                        separate = false
                    },

                    potions = {
                        key = "",
                        value = false,
                        override = false
                    },

                    interrupts = {
                        key = "ALT-SHIFT-I",
                        value = true,
                        separate = false,
                        filterCasts = false,
                        castRemainingThreshold = 0.25
                    },
                    funnel = {
                        key = "",
                        value = false
                    },

                    custom1 = {
                        key = "",
                        value = false,
                        name = "自定义#1"
                    },

                    custom2 = {
                        key = "",
                        value = false,
                        name = "自定义#2"
                    }
                },

                specs = {
                    -- ['**'] = specTemplate
                },

                packs = {
                    ['**'] = packTemplate
                },

                notifications = {
                    enabled = true,

                    x = 0,
                    y = 0,

                    font = ElvUI and "Expressway" or "Arial Narrow",
                    fontSize = 20,
                    fontStyle = "OUTLINE",
                    color = {1, 1, 1, 1},

                    width = 600,
                    height = 40
                },

                displays = {
                    Primary = {
                        enabled = true,
                        builtIn = true,

                        name = "主显示",

                        relativeTo = "SCREEN",
                        displayPoint = "TOP",
                        anchorPoint = "BOTTOM",

                        x = 0,
                        y = -225,

                        numIcons = 3,
                        order = 1,

                        flash = {
                            color = {1, 0, 0, 1}
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast"
                        }
                    },

                    AOE = {
                        enabled = true,
                        builtIn = true,

                        name = "AOE",

                        x = 0,
                        y = -170,

                        numIcons = 3,
                        order = 2,

                        flash = {
                            color = {0, 1, 0, 1}
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast"
                        }
                    },

                    Cooldowns = {
                        enabled = true,
                        builtIn = true,

                        name = "爆发",
                        filter = 'cooldowns',

                        x = 0,
                        y = -280,

                        numIcons = 1,
                        order = 3,

                        flash = {
                            color = {1, 0.82, 0, 1}
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast"
                        }
                    },

                    Defensives = {
                        enabled = true,
                        builtIn = true,

                        name = "防御",
                        filter = 'defensives',

                        x = -110,
                        y = -225,

                        numIcons = 1,
                        order = 4,

                        flash = {
                            color = {0.522, 0.302, 1, 1}
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast"
                        }
                    },

                    Interrupts = {
                        enabled = true,
                        builtIn = true,

                        name = "打断",
                        filter = 'interrupts',

                        x = -55,
                        y = -225,

                        numIcons = 1,
                        order = 5,

                        flash = {
                            color = {1, 1, 1, 1}
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast"
                        }
                    },

                    ['**'] = displayTemplate
                },

                -- STILL NEED TO REVISE.
                Clash = 0,
                -- (above)

                runOnce = {},

                performance = {
                    frameBudget = 0.7,
                    enhancedEvents = false
                },

                clashes = {},
                trinkets = {
                    ['**'] = {
                        disabled = false,
                        minimum = 0,
                        maximum = 0
                    }
                },

                interrupts = {
                    pvp = {},
                    encounters = {}
                },

                filterCasts = true,
                castRemainingThreshold = 0.25,
                iconStore = {
                    hide = false
                }
            }
        }

        if class and class.specs then
            for id, spec in pairs(class.specs) do
                if id > 0 then
                    defaults.profile.specs[id] = defaults.profile.specs[id] or tableCopy(specTemplate)
                    for k, v in pairs(spec.options) do
                        defaults.profile.specs[id][k] = v
                    end
                end
            end
        end

        return defaults
    end
end

do
    local shareDB = {
        displays = {},
        styleName = "",
        export = "",
        exportStage = 0,

        import = "",
        imported = {},
        importStage = 0
    }

    function Hekili:GetDisplayShareOption(info)
        local n = #info
        local option = info[n]

        if shareDB[option] then
            return shareDB[option]
        end
        return shareDB.displays[option]
    end

    function Hekili:SetDisplayShareOption(info, val, v2, v3, v4)
        local n = #info
        local option = info[n]

        if type(val) == 'string' then
            val = val:trim()
        end
        if shareDB[option] then
            shareDB[option] = val
            return
        end

        shareDB.displays[option] = val
        shareDB.export = ""
    end

    local multiDisplays = {
        Primary = true,
        AOE = true,
        Cooldowns = false,
        Defensives = false,
        Interrupts = false
    }

    local frameStratas = ns.FrameStratas

    -- Display Config.
    function Hekili:GetDisplayOption(info)
        local n = #info
        local display, category, option = info[2], info[3], info[n]

        if category == "shareDisplays" then
            return self:GetDisplayShareOption(info)
        end

        local conf = self.DB.profile.displays[display]

        if category ~= option and category ~= "main" then
            conf = conf[category]
        end

        if option == "color" or option == "queuedColor" then
            return unpack(conf.color)
        end
        if option == "frameStrata" then
            return frameStratas[conf.frameStrata] or 3
        end
        if option == "name" then
            return display
        end

        return conf[option]
    end

    local multiSet = false
    local timer
    local function QueueRebuildUI()
        -- Use appropriate timer method
        if timer then
            if Hekili.CancelTimer then
                Hekili:CancelTimer(timer)
            elseif type(timer) == "function" then
                -- C_Timer handle
                timer = nil
            end
        end

        if Hekili.ScheduleTimer then
            timer = Hekili:ScheduleTimer(function()
                Hekili:BuildUI()
            end, 0.5)
        elseif C_Timer and C_Timer.After then
            -- Fallback to C_Timer
            timer = C_Timer.After(0.5, function()
                Hekili:BuildUI()
            end)
        else
            -- Last resort - direct call
            Hekili:BuildUI()
        end
    end

    function Hekili:SetDisplayOption(info, val, v2, v3, v4)
        local n = #info
        local display, category, option = info[2], info[3], info[n]
        local set = false

        if category == "shareDisplays" then
            self:SetDisplayShareOption(info, val, v2, v3, v4)
            return
        end

        local conf = self.DB.profile.displays[display]
        if category ~= option and category ~= 'main' then
            conf = conf[category]
        end

        if option == 'color' or option == 'queuedColor' then
            conf[option] = {val, v2, v3, v4}
            set = true
        elseif option == 'frameStrata' then
            conf.frameStrata = frameStratas[val] or "LOW"
            set = true
        end

        if not set then
            val = type(val) == 'string' and val:trim() or val
            conf[option] = val
        end

        if not multiSet then
            QueueRebuildUI()
        end
    end

    function Hekili:GetMultiDisplayOption(info)
        info[2] = "Primary"
        local val, v2, v3, v4 = self:GetDisplayOption(info)
        info[2] = "Multi"
        return val, v2, v3, v4
    end

    function Hekili:SetMultiDisplayOption(info, val, v2, v3, v4)
        multiSet = true

        local orig = info[2]

        for display, active in pairs(multiDisplays) do
            if active then
                info[2] = display
                self:SetDisplayOption(info, val, v2, v3, v4)
            end
        end
        QueueRebuildUI()
        info[2] = orig

        multiSet = false
    end

    local function GetNotifOption(info)
        local n = #info
        local option = info[n]

        local conf = Hekili.DB.profile.notifications
        local val = conf[option]

        if option == "color" then
            if type(val) == "table" and #val == 4 then
                return unpack(val)
            else
                local defaults = Hekili:GetDefaults()
                return unpack(defaults.profile.notifications.color)
            end
        end
        return val
    end

    local function SetNotifOption(info, ...)
        local n = #info
        local option = info[n]

        local conf = Hekili.DB.profile.notifications
        local val = option == "color" and {...} or select(1, ...)

        conf[option] = val
        QueueRebuildUI()
    end

    local fontStyles = {
        ["MONOCHROME"] = "单色",
        ["MONOCHROME,OUTLINE"] = "单色，描边",
        ["MONOCHROME,THICKOUTLINE"] = "单色，粗描边",
        ["NONE"] = "无",
        ["OUTLINE"] = "描边",
        ["THICKOUTLINE"] = "粗描边"
    }

    local fontElements = {
        font = {
            type = "select",
            name = "字体",
            order = 1,
            width = 1.49,
            dialogControl = 'LSM30_Font',
            values = LSM:HashTable("font")
        },

        fontStyle = {
            type = "select",
            name = "样式",
            order = 2,
            values = fontStyles,
            width = 1.49
        },

        break01 = {
            type = "description",
            name = " ",
            order = 2.1,
            width = "full"
        },

        fontSize = {
            type = "range",
            name = "尺寸",
            order = 3,
            min = 8,
            max = 64,
            step = 1,
            width = 1.49
        },

        color = {
            type = "color",
            name = "颜色",
            order = 4,
            width = 1.49
        }
    }

    local anchorPositions = {
        TOP = '顶部',
        TOPLEFT = '顶部左侧',
        TOPRIGHT = '顶部右侧',
        BOTTOM = '底部',
        BOTTOMLEFT = '底部左侧',
        BOTTOMRIGHT = '底部右侧',
        LEFT = '左侧',
        LEFTTOP = '左侧上部',
        LEFTBOTTOM = '左侧下部',
        RIGHT = '右侧',
        RIGHTTOP = '右侧上部',
        RIGHTBOTTOM = '右侧下部'
    }

    local realAnchorPositions = {
        TOP = '顶部',
        TOPLEFT = '顶部左侧',
        TOPRIGHT = '顶部右侧',
        BOTTOM = '底部',
        BOTTOMLEFT = '底部左侧',
        BOTTOMRIGHT = '底部右侧',
        CENTER = "中间",
        LEFT = '左侧',
        RIGHT = '右侧'
    }

    local function getOptionTable(info, notif)
        local disp = info[2]
        local tab = Hekili.Options.args.displays

        if notif then
            tab = tab.args.nPanel
        else
            tab = tab.plugins[disp][disp]
        end

        for i = 3, #info do
            tab = tab.args[info[i]]
        end

        return tab
    end

    local function rangeXY(info, notif)
        local tab = getOptionTable(info, notif)

        local resolution = GetCVar("gxWindowedResolution") or "1280x720"
        local width, height = resolution:match("(%d+)x(%d+)")

        width = tonumber(width)
        height = tonumber(height)

        tab.args.x.min = -1 * width
        tab.args.x.max = width
        tab.args.x.softMin = -1 * width * 0.5
        tab.args.x.softMax = width * 0.5

        tab.args.y.min = -1 * height
        tab.args.y.max = height
        tab.args.y.softMin = -1 * height * 0.5
        tab.args.y.softMax = height * 0.5
    end

    local function setWidth(info, field, condition, if_true, if_false)
        local tab = getOptionTable(info)

        if condition then
            tab.args[field].width = if_true or "full"
        else
            tab.args[field].width = if_false or "full"
        end
    end

    local function rangeIcon(info)
        local tab = getOptionTable(info)

        local display = info[2]
        display = display == "Multi" and "Primary" or display

        local data = display and Hekili.DB.profile.displays[display]

        if data then
            tab.args.x.min = -1 * max(data.primaryWidth, data.queue.width)
            tab.args.x.max = max(data.primaryWidth, data.queue.width)

            tab.args.y.min = -1 * max(data.primaryHeight, data.queue.height)
            tab.args.y.max = max(data.primaryHeight, data.queue.height)

            return
        end

        tab.args.x.min = -50
        tab.args.x.max = 50

        tab.args.y.min = -50
        tab.args.y.max = 50
    end

    local dispCycle = {"Primary", "AOE", "Cooldowns", "Defensives", "Interrupts"}

    local MakeMultiDisplayOption
    local modified = {}

    local function GetOptionData(db, info)
        local display = info[2]
        local option = db[display][display]
        local desc, set, get = nil, option.set, option.get

        for i = 3, #info do
            local category = info[i]

            if not option then
                break
            elseif option.args then
                if not option.args[category] then
                    break
                end
                option = option.args[category]
            else
                break
            end

            get = option and option.get or get
            set = option and option.set or set
            desc = option and option.desc or desc
        end

        return option, get, set, desc
    end

    local function WrapSetter(db, data)
        local _, _, setfunc = GetOptionData(db, data)
        if setfunc and modified[setfunc] then
            return setfunc
        end

        local newFunc = function(info, val, v2, v3, v4)
            multiSet = true

            for display, active in pairs(multiDisplays) do
                if active then
                    info[2] = display

                    _, _, setfunc = GetOptionData(db, info)

                    if type(setfunc) == "string" then
                        Hekili[setfunc](Hekili, info, val, v2, v3, v4)
                    elseif type(setfunc) == "function" then
                        setfunc(info, val, v2, v3, v4)
                    end
                end
            end

            multiSet = false

            info[2] = "Multi"
            QueueRebuildUI()
        end

        modified[newFunc] = true
        return newFunc
    end

    local function WrapDesc(db, data)
        local option, getfunc, _, descfunc = GetOptionData(db, data)
        if descfunc and modified[descfunc] then
            return descfunc
        end

        local newFunc = function(info)
            local output

            for _, display in ipairs(dispCycle) do
                info[2] = display
                option, getfunc, _, descfunc = GetOptionData(db, info)

                if not output then
                    output = option and type(option.desc) == "function" and (option.desc(info) or "") or
                                 (option.desc or "")
                    if output:len() > 0 then
                        output = output .. "\n"
                    end
                end

                local val, v2, v3, v4

                if not getfunc then
                    val, v2, v3, v4 = Hekili:GetDisplayOption(info)
                elseif type(getfunc) == "function" then
                    val, v2, v3, v4 = getfunc(info)
                elseif type(getfunc) == "string" then
                    val, v2, v3, v4 = Hekili[getfunc](Hekili, info)
                end

                if val == nil then
                    Hekili:Error("无法从WrapDesc获取%s的值。", table.concat(info, "："))
                    info[2] = "Multi"
                    return output
                end

                -- Sanitize/format values.
                if type(val) == "boolean" then
                    val = val and "|cFF00FF00勾选|r" or "|cFFFF0000未勾选|r"
                elseif option.type == "color" then
                    val = string.format("|A:WhiteCircle-RaidBlips:16:16:0:0:%d:%d:%d|a |cFFFFD100#%02x%02x%02x|r",
                        val * 255, v2 * 255, v3 * 255, val * 255, v2 * 255, v3 * 255)
                elseif option.type == "select" and option.values and not option.dialogControl then
                    if type(option.values) == "function" then
                        val = option.values(data)[val] or val
                    else
                        val = option.values[val] or val
                    end

                    if type(val) == "number" then
                        if val % 1 == 0 then
                            val = format("|cFFFFD100%d|r", val)
                        else
                            val = format("|cFFFFD100%.2f|r", val)
                        end
                    else
                        val = format("|cFFFFD100%s|r", tostring(val))
                    end
                elseif type(val) == "number" then
                    if val % 1 == 0 then
                        val = format("|cFFFFD100%d|r", val)
                    else
                        val = format("|cFFFFD100%.2f|r", val)
                    end
                else
                    if val == nil then
                        Hekili:Error("未找到%s的值，默认设置为'???'.", table.concat(data, "："))
                        val = "|cFFFF0000???|r"
                    else
                        val = "|cFFFFD100" .. val .. "|r"
                    end
                end

                output = format("%s%s%s%s:|r %s", output, output:len() > 0 and "\n" or "", BlizzBlue, display, val)
            end

            info[2] = "Multi"
            return output
        end

        modified[newFunc] = true
        return newFunc
    end

    local function GetDeepestSetter(db, info)
        local position = db.Multi.Multi
        local setter

        for i = 3, #info - 1 do
            local key = info[i]
            position = position.args[key]

            local setfunc = rawget(position, "set")

            if setfunc and type(setfunc) == "function" then
                setter = setfunc
            end
        end

        return setter
    end

    MakeMultiDisplayOption = function(db, t, inf)
        local info = {}

        if not inf or #inf == 0 then
            info[1] = "displays"
            info[2] = "Multi"

            for k, v in pairs(t) do
                -- Only load groups in the first level (bypasses selection for which display to edit).
                if v.type == "group" then
                    info[3] = k
                    MakeMultiDisplayOption(db, v.args, info)
                    info[3] = nil
                end
            end

            return
        else
            for i, v in ipairs(inf) do
                info[i] = v
            end
        end

        for k, v in pairs(t) do
            if k:match("^MultiMod") then
                -- do nothing.
            elseif v.type == "group" then
                info[#info + 1] = k
                MakeMultiDisplayOption(db, v.args, info)
                info[#info] = nil
            elseif inf and v.type ~= "description" then
                info[#info + 1] = k
                v.desc = WrapDesc(db, info)

                if rawget(v, "set") then
                    v.set = WrapSetter(db, info)
                else
                    local setfunc = GetDeepestSetter(db, info)
                    if setfunc then
                        v.set = WrapSetter(db, info)
                    end
                end

                info[#info] = nil
            end
        end
    end

    local function newDisplayOption(db, name, data, pos)
        name = tostring(name)

        local fancyName

        if name == "Multi" then
            fancyName = AtlasToString("auctionhouse-icon-favorite") .. " 统一设置"
        elseif name == "Defensives" then
            fancyName = AtlasToString("nameplates-InterruptShield") .. " 防御"
        elseif name == "Interrupts" then
            fancyName = AtlasToString("voicechat-icon-speaker-mute") .. " 打断"
        elseif name == "Cooldowns" then
            fancyName = AtlasToString("chromietime-32x32") .. " 爆发"
        else
            fancyName = name
        end

        local option = {
            ['btn' .. name] = {
                type = 'execute',
                name = fancyName,
                desc = data.desc,
                order = 10 + pos,
                func = function()
                    ACD:SelectGroup("Hekili", "displays", name)
                end
            },

            [name] = {
                type = 'group',
                name = function()
                    if name == "Multi" then
                        return "|cFF00FF00" .. fancyName .. "|r"
                    elseif data.builtIn then
                        return '|cFF00B4FF' .. fancyName .. '|r'
                    end
                    return fancyName
                end,
                desc = function()
                    if name == "Multi" then
                        return
                            "同时对多个显示框架进行设置。当前显示的设置项来自主显示框架（其他框架的设置项显示在鼠标指向提示中）。\n\n部分选项不可在统一设置中使用。"
                    end
                    return data.desc
                end,
                set = name == "Multi" and "SetMultiDisplayOption" or "SetDisplayOption",
                get = name == "Multi" and "GetMultiDisplayOption" or "GetDisplayOption",
                childGroups = "tab",
                order = 100 + pos,

                args = {
                    MultiModPrimary = {
                        type = "toggle",
                        name = function()
                            return multiDisplays.Primary and "|cFF00FF00主显示|r" or "|cFFFF0000主显示|r"
                        end,
                        desc = function()
                            if multiDisplays.Primary then
                                return "更改 |cFF00FF00将会|r 应用于主显示框架。"
                            end
                            return "更改 |cFFFF0000不会|r 应用于主显示框架。"
                        end,
                        order = 0.01,
                        width = 0.65,
                        get = function()
                            return multiDisplays.Primary
                        end,
                        set = function()
                            multiDisplays.Primary = not multiDisplays.Primary
                        end,
                        hidden = function()
                            return name ~= "Multi"
                        end
                    },
                    MultiModAOE = {
                        type = "toggle",
                        name = function()
                            return multiDisplays.AOE and "|cFF00FF00AOE|r" or "|cFFFF0000AOE|r"
                        end,
                        desc = function()
                            if multiDisplays.AOE then
                                return "更改|cFF00FF00将会|r应用于AOE显示框架。"
                            end
                            return "更改|cFFFF0000将不会|r应用于AOE显示框架。"
                        end,
                        order = 0.02,
                        width = 0.65,
                        get = function()
                            return multiDisplays.AOE
                        end,
                        set = function()
                            multiDisplays.AOE = not multiDisplays.AOE
                        end,
                        hidden = function()
                            return name ~= "Multi"
                        end
                    },
                    MultiModCooldowns = {
                        type = "toggle",
                        name = function()
                            return AtlasToString("chromietime-32x32") ..
                                       (multiDisplays.Cooldowns and " |cFF00FF00爆发|r" or " |cFFFF0000爆发|r")
                        end,
                        desc = function()
                            if multiDisplays.Cooldowns then
                                return "更改 |cFF00FF00将会|r 应用于爆发框架。"
                            end
                            return "更改 |cFFFF0000不会|r 应用于爆发框架。"
                        end,
                        order = 0.03,
                        width = 0.65,
                        get = function()
                            return multiDisplays.Cooldowns
                        end,
                        set = function()
                            multiDisplays.Cooldowns = not multiDisplays.Cooldowns
                        end,
                        hidden = function()
                            return name ~= "Multi"
                        end
                    },
                    MultiModDefensives = {
                        type = "toggle",
                        name = function()
                            return AtlasToString("nameplates-InterruptShield") ..
                                       (multiDisplays.Defensives and " |cFF00FF00防御|r" or " |cFFFF0000防御|r")
                        end,
                        desc = function()
                            if multiDisplays.Defensives then
                                return "更改 |cFF00FF00将会|r 应用于防御框架。"
                            end
                            return "更改 |cFFFF0000不会|r 应用于防御框架。"
                        end,
                        order = 0.04,
                        width = 0.65,
                        get = function()
                            return multiDisplays.Defensives
                        end,
                        set = function()
                            multiDisplays.Defensives = not multiDisplays.Defensives
                        end,
                        hidden = function()
                            return name ~= "Multi"
                        end
                    },
                    MultiModInterrupts = {
                        type = "toggle",
                        name = function()
                            return AtlasToString("voicechat-icon-speaker-mute") ..
                                       (multiDisplays.Interrupts and " |cFF00FF00打断|r" or " |cFFFF0000打断|r")
                        end,
                        desc = function()
                            if multiDisplays.Interrupts then
                                return "更改 |cFF00FF00将会|r 应用于打断框架。"
                            end
                            return "更改 |cFFFF0000不会|r 应用于打断框架。"
                        end,
                        order = 0.05,
                        width = 0.65,
                        get = function()
                            return multiDisplays.Interrupts
                        end,
                        set = function()
                            multiDisplays.Interrupts = not multiDisplays.Interrupts
                        end,
                        hidden = function()
                            return name ~= "Multi"
                        end
                    },
                    main = {
                        type = 'group',
                        name = "主页",
                        desc = "包括显示位置、图标、图标大小和形状等等。",
                        order = 1,

                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果禁用，该显示框架在任何情况下都不会显示。",
                                order = 0.5,
                                hidden = function()
                                    return data.name == "Primary" or data.name == "AOE" or data.name == "Cooldowns" or
                                               data.name == "Defensives" or data.name == "Interrupts"
                                end
                            },

                            elvuiCooldown = {
                                type = "toggle",
                                name = "使用ElvUI的冷却样式",
                                desc = "如果安装了ElvUI，你可以在推荐队列中使用ElvUI的冷却样式。\n\n禁用此设置需要重新加载UI (|cFFFFD100/reload|r)。",
                                width = "full",
                                order = 16,
                                hidden = function()
                                    return _G["ElvUI"] == nil
                                end
                            },

                            numIcons = {
                                type = 'range',
                                name = "图标显示",
                                desc = "设置建议技能的显示数量。每个图标都会提前显示。",
                                min = 1,
                                max = 10,
                                step = 1,
                                bigStep = 1,
                                width = "full",
                                order = 1,
                                disabled = function()
                                    return name == "Multi"
                                end,
                                hidden = function(info, val)
                                    local n = #info
                                    local display = info[2]

                                    if display == "Defensives" or display == "Interrupts" then
                                        return true
                                    end

                                    return false
                                end
                            },

                            forecastPeriod = {
                                type = "range",
                                name = "预测期",
                                desc = "设置插件预测技能提示的时间。例如，在【爆发】显示中，如果此处被设置为|cFFFFD10015|r （默认），" ..
                                    "那么一个技能在满足使用条件时，会在冷却时间少于15秒时就被推荐。\n\n" ..
                                    "如果设置为很短的时间，可能会导致满足资源要求和使用条件时，没有冷却完成，而导致无法被推荐。",
                                softMin = 1.5,
                                min = 0,
                                softMax = 15,
                                max = 30,
                                step = 0.1,
                                width = "full",
                                order = 2,
                                disabled = function()
                                    return name == "Multi"
                                end,
                                hidden = function(info, val)
                                    local n = #info
                                    local display = info[2]

                                    if display == "Primary" or display == "AOE" then
                                        return true
                                    end

                                    return false
                                end
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeXY(info)
                                    return "位置"
                                end,
                                order = 10,

                                args = {
                                    --[[
                                    relativeTo = {
                                        type = "select",
                                        name = "锚定到",
                                        values = {
                                            SCREEN = "屏幕",
                                            PERSONAL = "角色资源条",
                                            CUSTOM = "自定义"
                                        },
                                        order = 1,
                                        width = 1.49,
                                    },

                                    customFrame = {
                                        type = "input",
                                        name = "自定义框架",
                                        desc = "指定该自定义锚定位置框架的名称。\n" ..
                                                "如果框架不存在，则不会显示。",
                                        order = 1.1,
                                        width = 1.49,
                                        hidden = function() return data.relativeTo ~= "CUSTOM" end,
                                    },

                                    setParent = {
                                        type = "toggle",
                                        name = "设置父对象为锚点",
                                        desc = "如果勾选，则会在显示或隐藏锚点时同步显示隐藏。",
                                        order = 3.9,
                                        width = 1.49,
                                        hidden = function() return data.relativeTo == "SCREEN" end,
                                    },

                                    preXY = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 97
                                    }, ]]

                                    x = {
                                        type = "range",
                                        name = "X",
                                        desc = "设置该显示框架主图标相对于屏幕中心的水平位置。" ..
                                            "负值代表显示框架向左移动，正值向右。",
                                        min = -512,
                                        max = 512,
                                        step = 1,

                                        order = 98,
                                        width = 1.49,

                                        disabled = function()
                                            return name == "Multi"
                                        end
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y",
                                        desc = "设置该显示框架主图标相对于屏幕中心的垂直位置。" ..
                                            "负值代表显示框架向下移动，正值向上。",
                                        min = -384,
                                        max = 384,
                                        step = 1,

                                        order = 99,
                                        width = 1.49,

                                        disabled = function()
                                            return name == "Multi"
                                        end
                                    }
                                }
                            },

                            primaryIcon = {
                                type = "group",
                                name = "主图标",
                                inline = true,
                                order = 15,
                                args = {
                                    primaryWidth = {
                                        type = "range",
                                        name = "宽度",
                                        desc = "指定主图标的宽度，适用于 " ..
                                            (name == "统一设置" and "每个框架。" or
                                                ("你的 " .. name .. " 框架")),
                                        min = 10,
                                        max = 500,
                                        step = 1,

                                        width = 1.49,
                                        order = 1
                                    },

                                    primaryHeight = {
                                        type = "range",
                                        name = "高度",
                                        desc = "指定主图标的高度，适用于 " ..
                                            (name == "统一设置" and "每个框架。" or
                                                ("你的 " .. name .. " 框架。")),
                                        min = 10,
                                        max = 500,
                                        step = 1,

                                        width = 1.49,
                                        order = 2
                                    },

                                    spacer01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 3
                                    },

                                    zoom = {
                                        type = "range",
                                        name = "图标缩放",
                                        desc = "选择该框架内的图标缩放百分比。(缩放约 30% 时，将裁剪掉暴雪默认图标的边框。)",
                                        min = 0,
                                        softMax = 100,
                                        max = 200,
                                        step = 1,

                                        width = 1.49,
                                        order = 4
                                    },

                                    keepAspectRatio = {
                                        type = "toggle",
                                        name = "保持纵横比",
                                        desc = "如果主图标或队列中的图标不是正方形，勾选此项将无法图标缩放，" ..
                                            "变为裁切部分图标图案。",
                                        disabled = function(info, val)
                                            return not (data.primaryHeight ~= data.primaryWidth or
                                                       (data.numIcons > 1 and data.queue.height ~= data.queue.width))
                                        end,
                                        width = 1.49,
                                        order = 5
                                    }
                                }
                            },

                            advancedFrame = {
                                type = "group",
                                name = "框架层级",
                                inline = true,
                                order = 99,
                                args = {
                                    frameStrata = {
                                        type = "select",
                                        name = "层级",
                                        desc = "框架层级决定了在哪个图形层上绘制此显示框架。\n" ..
                                            "默认层级是中间层。",
                                        values = {"背景层", "底层", "中间层", "高层", "对话框", "全屏",
                                                  "全屏对话框", "提示框"},
                                        width = "full",
                                        order = 1
                                    }
                                }
                            },

                            queuedElvuiCooldown = {
                                type = "toggle",
                                name = "队列图标使用 ElvUI 冷却样式",
                                desc = "如果安装了ElvUI，则可以将队列图标使用 ElvUI 的冷却样式。\n\n禁用此设置需要重新加载用户界面(|cFFFFD100/reload|r)。",
                                width = "full",
                                order = 23,
                                get = function(info)
                                    return Hekili.DB.profile.displays[name].queue.elvuiCooldown
                                end,
                                set = function(info, val)
                                    Hekili.DB.profile.displays[name].queue.elvuiCooldown = val
                                end,
                                hidden = function()
                                    return _G["ElvUI"] == nil
                                end
                            },

                            iconSizeGroup = {
                                type = "group",
                                inline = true,
                                name = "队列图标大小",
                                order = 21,
                                args = {
                                    width = {
                                        type = 'range',
                                        name = '宽度',
                                        desc = "设置队列中图标的宽度。",
                                        min = 10,
                                        max = 500,
                                        step = 1,
                                        bigStep = 1,
                                        order = 10,
                                        width = 1.49,
                                        get = function(info)
                                            return Hekili.DB.profile.displays[name].queue.width
                                        end,
                                        set = function(info, val)
                                            Hekili.DB.profile.displays[name].queue.width = val
                                        end
                                    },

                                    height = {
                                        type = 'range',
                                        name = '高度',
                                        desc = "设置队列中图标的高度。",
                                        min = 10,
                                        max = 500,
                                        step = 1,
                                        bigStep = 1,
                                        order = 11,
                                        width = 1.49,
                                        get = function(info)
                                            return Hekili.DB.profile.displays[name].queue.height
                                        end,
                                        set = function(info, val)
                                            Hekili.DB.profile.displays[name].queue.height = val
                                        end
                                    }
                                }
                            },

                            anchorGroup = {
                                type = "group",
                                inline = true,
                                name = "队列图标定位",
                                order = 22,
                                args = {
                                    anchor = {
                                        type = 'select',
                                        name = '锚定到',
                                        desc = "在主图标上选择队列图标附加到的位置。",
                                        values = anchorPositions,
                                        width = 1.49,
                                        order = 1,
                                        get = function(info)
                                            return Hekili.DB.profile.displays[name].queue.anchor
                                        end,
                                        set = function(info, val)
                                            Hekili.DB.profile.displays[name].queue.anchor = val
                                            Hekili:BuildUI()
                                        end
                                    },

                                    direction = {
                                        type = 'select',
                                        name = '延伸方向',
                                        desc = "选择图标队列的延伸方向。\n\n" ..
                                            "该选项通常与锚点的选择相匹配，但也可以指定其他方向来制作创意布局。",
                                        values = {
                                            TOP = '向上',
                                            BOTTOM = '向下',
                                            LEFT = '向左',
                                            RIGHT = '向右'
                                        },
                                        width = 1.49,
                                        order = 1.1,
                                        get = function(info)
                                            return Hekili.DB.profile.displays[name].queue.direction
                                        end,
                                        set = function(info, val)
                                            Hekili.DB.profile.displays[name].queue.direction = val
                                            Hekili:BuildUI()
                                        end
                                    },

                                    spacer01 = {
                                        type = "description",
                                        name = " ",
                                        order = 1.2,
                                        width = "full"
                                    },

                                    offsetX = {
                                        type = 'range',
                                        name = '队列水平偏移',
                                        desc = '设置主图标后方队列图标显示位置的水平偏移量（单位为像素）。正数向右，负数向左。',
                                        min = -100,
                                        max = 500,
                                        step = 1,
                                        width = 1.49,
                                        order = 2,
                                        get = function(info)
                                            return Hekili.DB.profile.displays[name].queue.offsetX
                                        end,
                                        set = function(info, val)
                                            Hekili.DB.profile.displays[name].queue.offsetX = val
                                            Hekili:BuildUI()
                                        end
                                    },

                                    offsetY = {
                                        type = 'range',
                                        name = '队列垂直偏移',
                                        desc = '设置主图标后方队列图标显示位置的垂直偏移量（单位为像素）。正数向上，负数向下。',
                                        min = -100,
                                        max = 500,
                                        step = 1,
                                        width = 1.49,
                                        order = 2.1,
                                        get = function(info)
                                            return Hekili.DB.profile.displays[name].queue.offsetY
                                        end,
                                        set = function(info, val)
                                            Hekili.DB.profile.displays[name].queue.offsetY = val
                                            Hekili:BuildUI()
                                        end
                                    },

                                    spacer02 = {
                                        type = "description",
                                        name = " ",
                                        order = 2.2,
                                        width = "full"
                                    },

                                    spacing = {
                                        type = 'range',
                                        name = '间距',
                                        desc = "设置队列图标的间距像素。",
                                        softMin = (data.queue.direction == "LEFT" or data.queue.direction == "RIGHT") and
                                            -data.queue.width or -data.queue.height,
                                        softMax = (data.queue.direction == "LEFT" or data.queue.direction == "RIGHT") and
                                            data.queue.width or data.queue.height,
                                        min = -500,
                                        max = 500,
                                        step = 1,
                                        order = 3,
                                        width = 2.98,
                                        get = function(info)
                                            return Hekili.DB.profile.displays[name].queue.spacing
                                        end,
                                        set = function(info, val)
                                            Hekili.DB.profile.displays[name].queue.spacing = val
                                            Hekili:BuildUI()
                                        end
                                    }
                                }
                            }
                        }
                    },

                    visibility = {
                        type = 'group',
                        name = '透明度',
                        desc = "PvE和PvP模式下不同的透明度设置。",
                        order = 3,

                        args = {

                            advanced = {
                                type = "toggle",
                                name = "进阶设置",
                                desc = "如果勾选，将提供更多关于透明度的细节选项。",
                                width = "full",
                                order = 1
                            },

                            simple = {
                                type = 'group',
                                inline = true,
                                name = "",
                                hidden = function()
                                    return data.visibility.advanced
                                end,
                                get = function(info)
                                    local option = info[#info]

                                    if option == 'pveAlpha' then
                                        return data.visibility.pve.alpha
                                    elseif option == 'pvpAlpha' then
                                        return data.visibility.pvp.alpha
                                    end
                                end,
                                set = function(info, val)
                                    local option = info[#info]

                                    if option == 'pveAlpha' then
                                        data.visibility.pve.alpha = val
                                    elseif option == 'pvpAlpha' then
                                        data.visibility.pvp.alpha = val
                                    end

                                    QueueRebuildUI()
                                end,
                                order = 2,
                                args = {
                                    pveAlpha = {
                                        type = "range",
                                        name = "PvE透明度",
                                        desc = "设置在PvE战斗中显示框架的透明度。如果设置为0，该显示框架将不会在PvE战斗中显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        order = 1,
                                        width = 1.49
                                    },
                                    pvpAlpha = {
                                        type = "range",
                                        name = "PvP透明度",
                                        desc = "设置在PvP战斗中显示框架的透明度。如果设置为0，该显示框架将不会在PvP战斗中显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        order = 1,
                                        width = 1.49
                                    }
                                }
                            },

                            pveComplex = {
                                type = 'group',
                                inline = true,
                                name = "PvE",
                                get = function(info)
                                    local option = info[#info]

                                    return data.visibility.pve[option]
                                end,
                                set = function(info, val)
                                    local option = info[#info]

                                    data.visibility.pve[option] = val
                                    QueueRebuildUI()
                                end,
                                hidden = function()
                                    return not data.visibility.advanced
                                end,
                                order = 2,
                                args = {
                                    always = {
                                        type = "range",
                                        name = "总是",
                                        desc = "如果此项不是0，则在PvE区域无论是否在战斗中，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 1
                                    },

                                    combat = {
                                        type = "range",
                                        name = "战斗",
                                        desc = "如果此项不是0，则在PvE战斗中，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 3
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 2.1
                                    },

                                    target = {
                                        type = "range",
                                        name = "目标",
                                        desc = "如果此项不是0，则当你有可攻击的PvE目标时，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 2
                                    },

                                    combatTarget = {
                                        type = "range",
                                        name = "战斗和目标",
                                        desc = "如果此项不是0，则当你处于战斗状态，且拥有可攻击的PvE目标时，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 4
                                    },

                                    hideMounted = {
                                        type = "toggle",
                                        name = "骑乘时隐藏",
                                        desc = "如果勾选，则当你骑乘时，该显示框架隐藏（除非你在战斗中）。",
                                        width = "full",
                                        order = 0.5
                                    }
                                }
                            },

                            pvpComplex = {
                                type = 'group',
                                inline = true,
                                name = "PvP",
                                get = function(info)
                                    local option = info[#info]

                                    return data.visibility.pvp[option]
                                end,
                                set = function(info, val)
                                    local option = info[#info]

                                    data.visibility.pvp[option] = val
                                    QueueRebuildUI()
                                    Hekili:UpdateDisplayVisibility()
                                end,
                                hidden = function()
                                    return not data.visibility.advanced
                                end,
                                order = 2,
                                args = {
                                    always = {
                                        type = "range",
                                        name = "总是",
                                        desc = "如果此项不是0，则在PvP区域无论是否在战斗中，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 1
                                    },

                                    combat = {
                                        type = "range",
                                        name = "战斗",
                                        desc = "如果此项不是0，则在PvP战斗中，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 3
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 2.1
                                    },

                                    target = {
                                        type = "range",
                                        name = "目标",
                                        desc = "如果此项不是0，则当你有可攻击的PvP目标时，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 2
                                    },

                                    combatTarget = {
                                        type = "range",
                                        name = "战斗和目标",
                                        desc = "如果此项不是0，则当你处于战斗状态，且拥有可攻击的PvP目标时，该显示框架都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 4
                                    },

                                    hideMounted = {
                                        type = "toggle",
                                        name = "骑乘时隐藏",
                                        desc = "如果勾选，则当你骑乘时，该显示框架隐藏（除非你在战斗中）。",
                                        width = "full",
                                        order = 0.5
                                    }
                                }
                            }
                        }
                    },

                    keybindings = {
                        type = "group",
                        name = "绑定按键",
                        desc = "显示技能图标上绑定按键文本的选项。",
                        order = 7,

                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                order = 1,
                                width = 1.49
                            },

                            queued = {
                                type = "toggle",
                                name = "为队列图标启用",
                                order = 2,
                                width = 1.49,
                                disabled = function()
                                    return data.keybindings.enabled == false
                                end
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 2,
                                        width = 1,
                                        values = realAnchorPositions
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        disabled = function(info)
                                            return false
                                        end,
                                        step = 1
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 4,
                                        width = 0.99,
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1
                                    }
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本样式",
                                order = 5,
                                args = tableCopy(fontElements)
                            },

                            lowercase = {
                                type = "toggle",
                                name = "使用小写字母",
                                order = 5.1,
                                width = "full"
                            },

                            separateQueueStyle = {
                                type = "toggle",
                                name = "队列图标使用不同的设置",
                                order = 6,
                                width = "full"
                            },

                            queuedTextStyle = {
                                type = "group",
                                inline = true,
                                name = "队列图标文本样式",
                                order = 7,
                                hidden = function()
                                    return not data.keybindings.separateQueueStyle
                                end,
                                args = {
                                    queuedFont = {
                                        type = "select",
                                        name = "字体",
                                        order = 1,
                                        width = 1.49,
                                        dialogControl = 'LSM30_Font',
                                        values = LSM:HashTable("font")
                                    },

                                    queuedFontStyle = {
                                        type = "select",
                                        name = "样式",
                                        order = 2,
                                        values = fontStyles,
                                        width = 1.49
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 2.1
                                    },

                                    queuedFontSize = {
                                        type = "range",
                                        name = "尺寸",
                                        order = 3,
                                        min = 8,
                                        max = 64,
                                        step = 1,
                                        width = 1.49
                                    },

                                    queuedColor = {
                                        type = "color",
                                        name = "颜色",
                                        order = 4,
                                        width = 1.49
                                    }
                                }
                            },

                            queuedLowercase = {
                                type = "toggle",
                                name = "队列图标使用小写字母",
                                order = 7.1,
                                width = 1.49,
                                hidden = function()
                                    return not data.keybindings.separateQueueStyle
                                end
                            },

                            cPort = {
                                name = "ConsolePort(手柄插件)",
                                type = "group",
                                inline = true,
                                order = 4,
                                args = {
                                    cPortOverride = {
                                        type = "toggle",
                                        name = "使用ConsolePort按键",
                                        order = 6,
                                        width = 1.49
                                    },

                                    cPortZoom = {
                                        type = "range",
                                        name = "ConsolePort按键缩放",
                                        desc = "ConsolePort按键图标周围通常有大量空白填充。" ..
                                            "为了按键适配图标，放大会裁切一些图案。默认值为|cFFFFD1000.6|r。",
                                        order = 7,
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49
                                    }
                                },
                                disabled = function()
                                    return ConsolePort == nil
                                end
                            }

                        }
                    },

                    border = {
                        type = "group",
                        name = "边框",
                        desc = "启用/禁用和设置图标边框的颜色。\n\n" ..
                            "如果使用了Masque或类似的图标美化插件，可能需要禁用此功能。",
                        order = 4,

                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，该显示框架中每个图标都会有窄边框。",
                                order = 1,
                                width = "full"
                            },

                            thickness = {
                                type = "range",
                                name = "边框粗细",
                                desc = "设置边框的厚度（粗细）。默认值为1。",
                                softMin = 1,
                                softMax = 20,
                                step = 1,
                                order = 2,
                                width = 1.49
                            },

                            fit = {
                                type = "toggle",
                                name = "内边框",
                                desc = "如果勾选，当边框启用时，图标的边框将会描绘在按钮的内部（而不是外围）。",
                                order = 2.5,
                                width = 1.49
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                width = "full",
                                order = 2.6
                            },

                            coloring = {
                                type = "select",
                                name = "着色模式",
                                desc = "设置边框颜色是系统颜色或自定义颜色。",
                                width = 1.49,
                                order = 3,
                                values = {
                                    class = format("Class |A:WhiteCircle-RaidBlips:16:16:0:0:%d:%d:%d|a #%s",
                                        ClassColor.r * 255, ClassColor.g * 255, ClassColor.b * 255,
                                        ClassColor:GenerateHexColor():sub(3, 8)),
                                    custom = "设置自定义颜色"
                                },
                                disabled = function()
                                    return data.border.enabled == false
                                end
                            },

                            color = {
                                type = "color",
                                name = "边框颜色",
                                desc = "当启用边框后，边框将使用此颜色。",
                                order = 4,
                                width = 1.49,
                                disabled = function()
                                    return data.border.enabled == false or data.border.coloring ~= "custom"
                                end
                            }
                        }
                    },

                    range = {
                        type = "group",
                        name = "范围",
                        desc = "设置范围检查警告的选项。",
                        order = 5,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，当你不在攻击距离内时，插件将进行红色高亮警告。",
                                width = 1.49,
                                order = 1
                            },

                            type = {
                                type = "select",
                                name = '范围监测',
                                desc = "选择该显示框架使用的范围监测和警告提示类型。\n\n" ..
                                    "|cFFFFD100技能|r - 如果某个技能超出攻击范围，则该技能以红色高亮警告。\n\n" ..
                                    "|cFFFFD100近战|r - 如果你不在近战攻击范围，所有技能都以红色高亮警告。\n\n" ..
                                    "|cFFFFD100排除|r - 如果某个技能超出攻击范围，则不建议使用该技能。",
                                values = {
                                    ability = "每个技能",
                                    melee = "近战范围",
                                    xclude = "排除超出范围的技能"
                                },
                                width = 1.49,
                                order = 2,
                                disabled = function()
                                    return data.range.enabled == false
                                end
                            }
                        }
                    },

                    glow = {
                        type = "group",
                        name = "高亮",
                        desc = "设置高亮或覆盖的选项。",
                        order = 6,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果启用，当队列中第一个技能具有高亮（或覆盖）的功能，也将在显示框架中同步高亮。",
                                width = 1.49,
                                order = 1
                            },

                            queued = {
                                type = "toggle",
                                name = "对队列图标启用",
                                desc = "如果启用，具有高亮（或覆盖）功能的队列技能图标也将在队列中同步高亮。\n\n" ..
                                    "此项效果可能不理想，在未来的时间点，高亮状态可能不再正确。",
                                width = 1.49,
                                order = 2,
                                disabled = function()
                                    return data.glow.enabled == false
                                end
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                order = 2.1,
                                width = "full"
                            },

                            mode = {
                                type = "select",
                                name = "高亮样式",
                                desc = "设置显示框架的高亮样式。",
                                width = 1,
                                order = 3,
                                values = {
                                    default = "默认按钮高亮",
                                    autocast = "自动闪光",
                                    pixel = "像素发光"
                                },
                                disabled = function()
                                    return data.glow.enabled == false
                                end
                            },

                            coloring = {
                                type = "select",
                                name = "着色模式",
                                desc = "设置高亮效果的着色模式。",
                                width = 0.99,
                                order = 4,
                                values = {
                                    default = "使用默认颜色",
                                    class = format("职业 |A:WhiteCircle-RaidBlips:16:16:0:0:%d:%d:%d|a #%s",
                                        ClassColor.r * 255, ClassColor.g * 255, ClassColor.b * 255,
                                        ClassColor:GenerateHexColor():sub(3, 8)),
                                    custom = "设置自定义颜色"
                                },
                                disabled = function()
                                    return data.glow.enabled == false
                                end
                            },

                            color = {
                                type = "color",
                                name = "高亮颜色",
                                desc = "设置该显示框架的高亮颜色。",
                                width = 0.99,
                                order = 5,
                                disabled = function()
                                    return data.glow.coloring ~= "custom"
                                end
                            },

                            break02 = {
                                type = "description",
                                name = " ",
                                order = 10,
                                width = "full"
                            },

                            highlight = {
                                type = "toggle",
                                name = "启用技能高亮",
                                desc = "如果勾选，插件会将当前推荐队列第一个操作指令高亮提示。",
                                width = "full",
                                order = 11
                            }
                        }
                    },

                    flash = {
                        type = "group",
                        name = "技能高光",
                        desc = function()
                            if SF then
                                return
                                    "如果勾选，插件可以在推荐使用某个技能时，在动作条技能图标上进行高光提示。"
                            end
                            return "此功能要求SpellFlash插件或库正常工作。"
                        end,
                        order = 8,
                        args = {
                            warning = {
                                type = "description",
                                name = "此页设置不可用。原因是SpellFlash插件没有安装或被禁用。",
                                order = 0,
                                fontSize = "medium",
                                width = "full",
                                hidden = function()
                                    return SF ~= nil
                                end
                            },

                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，插件将该显示框架的第一个推荐技能图标上显示彩色高光。",

                                width = 1.49,
                                order = 1,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            color = {
                                type = "color",
                                name = "颜色",
                                desc = "设置技能高亮的高光颜色。",
                                order = 2,
                                width = 1.49,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            break00 = {
                                type = "description",
                                name = " ",
                                order = 2.1,
                                width = "full",
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            sample = {
                                type = "description",
                                name = "",
                                image = function()
                                    return Hekili.DB.profile.flashTexture
                                end,
                                order = 3,
                                width = 0.3,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            flashTexture = {
                                type = "select",
                                name = "纹理",
                                icon = function()
                                    return data.flash.texture or "Interface\\Cooldown\\star4"
                                end,
                                desc = "你的选择将覆盖所有显示框中高亮的纹理。",
                                order = 3.1,
                                width = 1.19,
                                values = {
                                    ["Interface\\AddOns\\Hekili\\Textures\\MonoCircle2"] = "单星环",
                                    ["Interface\\AddOns\\Hekili\\Textures\\MonoCircle5"] = "粗星环",
                                    ["Interface\\Cooldown\\ping4"] = "星环",
                                    ["Interface\\Cooldown\\star4"] = "星光（默认）",
                                    ["Interface\\Cooldown\\starburst"] = "星爆",
                                    ["Interface\\Masks\\CircleMaskScalable"] = "圆形",
                                    ["Interface\\Masks\\SquareMask"] = "方形"
                                },
                                get = function()
                                    return Hekili.DB.profile.flashTexture
                                end,
                                set = function(_, val)
                                    Hekili.DB.profile.flashTexture = val
                                end,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            speed = {
                                type = "range",
                                name = "速率",
                                desc = "设定技能闪光闪动的速率。默认值是|cFFFFD1000.4秒|r。",
                                min = 0.1,
                                max = 2,
                                step = 0.1,
                                order = 3.2,
                                width = 1.49,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                order = 4,
                                width = "full",
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            size = {
                                type = "range",
                                name = "大小",
                                desc = "设置技能高光的光晕大小。默认大小为|cFFFFD100240|r。",
                                order = 5,
                                min = 0,
                                max = 240 * 8,
                                step = 1,
                                width = 1.49,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            fixedSize = {
                                type = "toggle",
                                name = "固定大小",
                                desc = "如果勾选，技能闪光的尺寸将不会发生变化（不会放大缩小）。",
                                order = 6,
                                width = 1.49,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            break02 = {
                                type = "description",
                                name = " ",
                                order = 7,
                                width = "full",
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            brightness = {
                                type = "range",
                                name = "闪光亮度",
                                desc = "设定技能闪光的亮度。默认亮度为|cFFFFD100100|r。",
                                order = 8,
                                min = 0,
                                max = 100,
                                step = 1,
                                width = 1.49,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            fixedBrightness = {
                                type = "toggle",
                                name = "固定亮度",
                                desc = "如果勾选，技能闪光的亮度将不会发生变化（不会闪烁）。",
                                order = 9,
                                width = 1.49,
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            break03 = {
                                type = "description",
                                name = " ",
                                order = 10,
                                width = "full",
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            combat = {
                                type = "toggle",
                                name = "仅在战斗中",
                                desc = "如果勾选，插件将仅在你处于战斗状态时进行闪光提示。",
                                order = 11,
                                width = "full",
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            suppress = {
                                type = "toggle",
                                name = "隐藏显示框",
                                desc = "如果勾选，插件将隐藏所有显示框架，仅通过技能闪光来推荐技能。",
                                order = 12,
                                width = "full",
                                hidden = function()
                                    return SF == nil
                                end
                            },

                            blink = {
                                type = "toggle",
                                name = "按钮闪烁",
                                desc = "如果勾选，整个技能按钮都将发生闪烁。默认值是|cFFFF0000不启用|r。",
                                order = 13,
                                width = "full",
                                hidden = function()
                                    return SF == nil
                                end
                            }
                        }
                    },

                    captions = {
                        type = "group",
                        name = "提示",
                        desc = "提示是动作条中偶尔使用的简短描述，用于该技能的说明。",
                        order = 9,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，当显示框中第一个技能具有说明时，将显示该说明。",
                                order = 1,
                                width = 1.49
                            },

                            queued = {
                                type = "toggle",
                                name = "对队列图标启用",
                                desc = "如果勾选，将显示队列技能图标的说明（如果可用）。",
                                order = 2,
                                width = 1.49,
                                disabled = function()
                                    return data.captions.enabled == false
                                end
                            },

                            position = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info);
                                    return "位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 1,
                                        width = 1,
                                        values = {
                                            TOP = '顶部',
                                            BOTTOM = '底部'
                                        }
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 2,
                                        width = 0.99,
                                        step = 1
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        step = 1
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        order = 3.1,
                                        width = "full"
                                    },

                                    align = {
                                        type = "select",
                                        name = "对齐",
                                        order = 4,
                                        width = 1.49,
                                        values = {
                                            LEFT = "左对齐",
                                            RIGHT = "右对齐",
                                            CENTER = "居中对齐"
                                        }
                                    }
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 4,
                                args = tableCopy(fontElements)
                            }
                        }
                    },

                    empowerment = {
                        type = "group",
                        name = "授权",
                        desc = "授权期间会在推荐图标上显示提示文字，并在达到所需的阶段时发光。",
                        order = 9.1,
                        hidden = function()
                            local spec = class and class.specs and state and state.spec and class.specs[state.spec.id]
                            return not spec or not spec.can_empower
                        end,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，当首个推荐技能是被授权的技能时，将显示该技能的授权状态。",
                                order = 1,
                                width = 1.49
                            },

                            queued = {
                                type = "toggle",
                                name = "队列图标启用",
                                desc = "如果勾选，授权状态的文字也会显示在队列中的技能图标上。",
                                order = 2,
                                width = 1.49,
                                disabled = function()
                                    return data.empowerment.enabled == false
                                end
                            },

                            glow = {
                                type = "toggle",
                                name = "授权时高亮",
                                desc = "如果勾选，该技能将在达到所需的授权等级时高亮。",
                                order = 2.5,
                                width = "full"
                            },

                            position = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "文本位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 1,
                                        width = 1,
                                        values = {
                                            TOP = '顶部',
                                            BOTTOM = '底部'
                                        }
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 2,
                                        width = 0.99,
                                        step = 1
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        step = 1
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        order = 3.1,
                                        width = "full"
                                    },

                                    align = {
                                        type = "select",
                                        name = "对齐",
                                        order = 4,
                                        width = 1.49,
                                        values = {
                                            LEFT = "左对齐",
                                            RIGHT = "右对齐",
                                            CENTER = "居中对齐"
                                        }
                                    }
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 4,
                                args = tableCopy(fontElements)
                            }
                        }
                    },

                    targets = {
                        type = "group",
                        name = "目标数",
                        desc = "目标数量统计可以在显示框的第一个技能图标上。",
                        order = 10,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，插件将在显示框上显示识别到的目标数。",
                                order = 1,
                                width = "full"
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 2,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = "锚定到",
                                        values = realAnchorPositions,
                                        order = 1,
                                        width = 1
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        step = 1,
                                        order = 2,
                                        width = 0.99
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1,
                                        order = 2,
                                        width = 0.99
                                    }
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 3,
                                args = tableCopy(fontElements)
                            }
                        }
                    },

                    delays = {
                        type = "group",
                        name = "延时",
                        desc = "当未来某个时间点建议使用某个技能时，使用着色或倒计时进行延时提示。" ..
                            "",
                        order = 11,
                        args = {
                            extend = {
                                type = "toggle",
                                name = "扩展冷却扫描",
                                desc = "如果勾选，主图标的冷却扫描将不会刷新，直到该技能被使用。",
                                width = 1.49,
                                order = 1
                            },

                            fade = {
                                type = "toggle",
                                name = "无法使用则淡化",
                                desc = "当你在施放该技能之前等待时，主图标将淡化，类似于某个技能缺少能量时。",
                                width = 1.49,
                                order = 1.1
                            },

                            desaturate = {
                                type = "toggle",
                                name = format("%s降低饱和度", NewFeature),
                                desc = "当应该在使用推荐技能之前等待时，主图标会降低饱和度。",
                                width = 1.49,
                                order = 1.15
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                order = 1.2,
                                width = "full"
                            },

                            type = {
                                type = "select",
                                name = "提示方式",
                                desc = "设置在施放该技能之前等待时间的提示方式。",
                                values = {
                                    __NA = "不提示",
                                    ICON = "显示图标（颜色）",
                                    TEXT = "显示文本（倒计时）"
                                },
                                width = 1.49,
                                order = 2
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 2,
                                        width = 1,
                                        values = realAnchorPositions
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        step = 1
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 4,
                                        width = 0.99,
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1
                                    }
                                },
                                disabled = function()
                                    return data.delays.type == "__NA"
                                end
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 4,
                                args = tableCopy(fontElements),
                                disabled = function()
                                    return data.delays.type ~= "TEXT"
                                end
                            }
                        }
                    },

                    indicators = {
                        type = "group",
                        name = "扩展提示",
                        desc = "扩展提示是当需要切换目标时或取消增益效果时的小图标。",
                        order = 11,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，主图标上将会出现提示切换目标和取消效果的小图标。",
                                order = 1,
                                width = 1.49
                            },

                            queued = {
                                type = "toggle",
                                name = "对队列图标启用",
                                desc = "如果勾选，扩展提示也将适时地出现在队列图标上。",
                                order = 2,
                                width = 1.49,
                                disabled = function()
                                    return data.indicators.enabled == false
                                end
                            },

                            size = {
                                type = "group",
                                inline = true,
                                name = "外观样式",
                                order = 1.5,
                                args = {
                                    width = {
                                        type = "range",
                                        name = "宽度",
                                        desc = "设置提示图标的宽度。",
                                        min = 8,
                                        max = 100,
                                        step = 1,
                                        width = 1.49,
                                        order = 1
                                    },

                                    height = {
                                        type = "range",
                                        name = "高度",
                                        desc = "设置提示图标的高度。",
                                        min = 8,
                                        max = 100,
                                        step = 1,
                                        width = 1.49,
                                        order = 2
                                    },

                                    spacer01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 3
                                    },

                                    zoom = {
                                        type = "range",
                                        name = "图标缩放",
                                        desc = "选择图标纹理的缩放百分比。（大约30%会裁剪掉Blizzard默认的边框。）",
                                        min = 0,
                                        softMax = 100,
                                        max = 200,
                                        step = 1,
                                        width = 1.49,
                                        order = 4
                                    },

                                    keepAspectRatio = {
                                        type = "toggle",
                                        name = "保持纵横比",
                                        desc = "当启用时，提示图标将在调整大小时保持其原始纵横比。",
                                        width = 1.49,
                                        order = 5
                                    }
                                }
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 2,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = "锚点",
                                        values = realAnchorPositions,
                                        order = 1,
                                        width = 1
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        step = 1,
                                        order = 2,
                                        width = 0.99
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1,
                                        order = 2,
                                        width = 0.99
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        return option
    end

    function Hekili:EmbedDisplayOptions(db)
        db = db or self.Options
        if not db then
            return
        end

        local section = db.args.displays or {
            type = "group",
            name = "显示框架",
            childGroups = "tree",
            cmdHidden = true,
            get = 'GetDisplayOption',
            set = 'SetDisplayOption',
            order = 30,

            args = {
                header = {
                    type = "description",
                    name = "Hekili拥有五个内置的显示框（蓝色标识），以用于显示不同类型的建议。" ..
                        "插件的建议通常基于（但不完全）SimulationCraft模拟结果的技能优先级。" ..
                        "你可以将判断实际情况与模拟结果进行比较得到最优解。",
                    fontSize = "medium",
                    width = "full",
                    order = 1
                },

                displays = {
                    type = "header",
                    name = "显示框架",
                    order = 10
                },

                nPanelHeader = {
                    type = "header",
                    name = "通知栏",
                    order = 950
                },

                nPanelBtn = {
                    type = "execute",
                    name = "通知栏",
                    desc = "当在战斗中更改或切换设置是，通知栏将提供简要的说明。" .. "",
                    func = function()
                        ACD:SelectGroup("Hekili", "displays", "nPanel")
                    end,
                    order = 951
                },

                nPanel = {
                    type = "group",
                    name = "|cFF1EFF00通知栏|r",
                    desc = "当在战斗中更改或切换设置是，通知栏将提供简要的说明。" .. "",
                    order = 952,
                    get = GetNotifOption,
                    set = SetNotifOption,
                    args = {
                        enabled = {
                            type = "toggle",
                            name = "启用",
                            order = 1,
                            width = "full"
                        },

                        posRow = {
                            type = "group",
                            name = function(info)
                                rangeXY(info, true)
                                return "位置"
                            end,
                            inline = true,
                            order = 2,
                            args = {
                                x = {
                                    type = "range",
                                    name = "X",
                                    desc = "输入通知面板相对于屏幕中心的水平位置，" ..
                                        "负值向左偏移，正值向右。" .. "",
                                    min = -512,
                                    max = 512,
                                    step = 1,

                                    width = 1.49,
                                    order = 1
                                },

                                y = {
                                    type = "range",
                                    name = "Y",
                                    desc = "输入通知面板相对于屏幕中心的垂直位置，" ..
                                        "负值向下偏移，正值向上。" .. "",
                                    min = -384,
                                    max = 384,
                                    step = 1,

                                    width = 1.49,
                                    order = 2
                                }
                            }
                        },

                        sizeRow = {
                            type = "group",
                            name = "大小",
                            inline = true,
                            order = 3,
                            args = {
                                width = {
                                    type = "range",
                                    name = "宽度",
                                    min = 50,
                                    max = 1000,
                                    step = 1,

                                    width = "full",
                                    order = 1
                                },

                                height = {
                                    type = "range",
                                    name = "高度",
                                    min = 20,
                                    max = 600,
                                    step = 1,

                                    width = "full",
                                    order = 2
                                }
                            }
                        },

                        fontGroup = {
                            type = "group",
                            inline = true,
                            name = "文字",

                            order = 5,
                            args = tableCopy(fontElements)
                        }
                    }
                },

                fontHeader = {
                    type = "header",
                    name = "字体",
                    order = 960
                },

                fontWarn = {
                    type = "description",
                    name = "更改下面的字体将调整|cFFFF0000所有|r显示框架中的文字。\n" ..
                        "如果想修改单独显示框架的文字，请选择对应的显示框架（左侧）后再设置字体。",
                    order = 960.01
                },

                font = {
                    type = "select",
                    name = "字体",
                    order = 960.1,
                    width = 1.5,
                    dialogControl = 'LSM30_Font',
                    values = LSM:HashTable("font"),
                    get = function(info)
                        -- Display the information from Primary, Keybinds.
                        return Hekili.DB.profile.displays.Primary.keybindings.font
                    end,
                    set = function(info, val)
                        -- Set all fonts in all displays.
                        for _, display in pairs(Hekili.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.font then
                                    data.font = val
                                end
                            end
                        end
                        QueueRebuildUI()
                    end
                },

                fontSize = {
                    type = "range",
                    name = "大小",
                    order = 960.2,
                    min = 8,
                    max = 64,
                    step = 1,
                    get = function(info)
                        -- Display the information from Primary, Keybinds.
                        return Hekili.DB.profile.displays.Primary.keybindings.fontSize
                    end,
                    set = function(info, val)
                        -- Set all fonts in all displays.
                        for _, display in pairs(Hekili.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.fontSize then
                                    data.fontSize = val
                                end
                            end
                        end
                        QueueRebuildUI()
                    end,
                    width = 1.5
                },

                fontStyle = {
                    type = "select",
                    name = "样式",
                    order = 960.3,
                    values = {
                        ["MONOCHROME"] = "单色",
                        ["MONOCHROME,OUTLINE"] = "单色，描边",
                        ["MONOCHROME,THICKOUTLINE"] = "单色，粗描边",
                        ["NONE"] = "无",
                        ["OUTLINE"] = "描边",
                        ["THICKOUTLINE"] = "粗描边"
                    },
                    get = function(info)
                        -- Display the information from Primary, Keybinds.
                        return Hekili.DB.profile.displays.Primary.keybindings.fontStyle
                    end,
                    set = function(info, val)
                        -- Set all fonts in all displays.
                        for _, display in pairs(Hekili.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.fontStyle then
                                    data.fontStyle = val
                                end
                            end
                        end
                        QueueRebuildUI()
                    end,
                    width = 1.5
                },

                color = {
                    type = "color",
                    name = "颜色",
                    order = 960.4,
                    get = function(info)
                        return unpack(Hekili.DB.profile.displays.Primary.keybindings.color)
                    end,
                    set = function(info, ...)
                        for name, display in pairs(Hekili.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.color then
                                    data.color = {...}
                                end
                            end
                        end
                        QueueRebuildUI()
                    end,
                    width = 1.5
                },

                shareHeader = {
                    type = "header",
                    name = "分享",
                    order = 996
                },

                shareBtn = {
                    type = "execute",
                    name = "分享样式",
                    desc = "你的显示样式可以通过导出这些字符串与其他插件用户分享。\n\n" ..
                        "你也可以在这里导入他人分享的字符串。",
                    func = function()
                        ACD:SelectGroup("Hekili", "displays", "shareDisplays")
                    end,
                    order = 998
                },

                shareDisplays = {
                    type = "group",
                    name = "|cFF1EFF00分享样式|r",
                    desc = "你的显示选项可以通过导出这些字符串与其他插件用户分享。\n\n" ..
                        "你也可以在这里导入他人分享的字符串。",
                    childGroups = "tab",
                    get = 'GetDisplayShareOption',
                    set = 'SetDisplayShareOption',
                    order = 999,
                    args = {
                        import = {
                            type = "group",
                            name = "导入",
                            order = 1,
                            args = {
                                stage0 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = "选择保存的样式，或者在文本框中粘贴字符串。",
                                            order = 1,
                                            width = "full",
                                            fontSize = "medium"
                                        },

                                        separator = {
                                            type = "header",
                                            name = "导入字符串",
                                            order = 1.5
                                        },

                                        selectExisting = {
                                            type = "select",
                                            name = "选择保存的样式",
                                            order = 2,
                                            width = "full",
                                            get = function()
                                                return "0000000000"
                                            end,
                                            set = function(info, val)
                                                local style = self.DB.global.styles[val]

                                                if style then
                                                    shareDB.import = style.payload
                                                end
                                            end,
                                            values = function()
                                                local db = self.DB.global.styles
                                                local values = {
                                                    ["0000000000"] = "选择保存的样式"
                                                }

                                                for k, v in pairs(db) do
                                                    values[k] = k .. " (|cFF00FF00" .. v.date .. "|r)"
                                                end

                                                return values
                                            end
                                        },

                                        importString = {
                                            type = "input",
                                            name = "导入字符串",
                                            get = function()
                                                return shareDB.import
                                            end,
                                            set = function(info, val)
                                                val = val:trim()
                                                shareDB.import = val
                                            end,
                                            order = 3,
                                            multiline = 5,
                                            width = "full"
                                        },

                                        btnSeparator = {
                                            type = "header",
                                            name = "导入",
                                            order = 4
                                        },

                                        importBtn = {
                                            type = "execute",
                                            name = "导入样式",
                                            order = 5,
                                            func = function()
                                                shareDB.imported, shareDB.error = DeserializeStyle(shareDB.import)

                                                if shareDB.error then
                                                    shareDB.import =
                                                        "无法解析当前的导入字符串。\n" .. shareDB.error
                                                    shareDB.error = nil
                                                    shareDB.imported = {}
                                                else
                                                    shareDB.importStage = 1
                                                end
                                            end,
                                            disabled = function()
                                                return shareDB.import == ""
                                            end
                                        }
                                    },
                                    hidden = function()
                                        return shareDB.importStage ~= 0
                                    end
                                },

                                stage1 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = function()
                                                local creates, replaces = {}, {}

                                                for k, v in pairs(shareDB.imported) do
                                                    if rawget(self.DB.profile.displays, k) then
                                                        insert(replaces, k)
                                                    else
                                                        insert(creates, k)
                                                    end
                                                end

                                                local o = ""

                                                if #creates > 0 then
                                                    o = o .. "导入的样式将创建以下的显示框架样式："
                                                    for i, display in orderedPairs(creates) do
                                                        if i == 1 then
                                                            o = o .. display
                                                        else
                                                            o = o .. ", " .. display
                                                        end
                                                    end
                                                    o = o .. ".\n"
                                                end

                                                if #replaces > 0 then
                                                    o = o .. "导入的样式将覆盖以下的显示框架样式："
                                                    for i, display in orderedPairs(replaces) do
                                                        if i == 1 then
                                                            o = o .. display
                                                        else
                                                            o = o .. ", " .. display
                                                        end
                                                    end
                                                    o = o .. "."
                                                end

                                                return o
                                            end,
                                            order = 1,
                                            width = "full",
                                            fontSize = "medium"
                                        },

                                        separator = {
                                            type = "header",
                                            name = "应用更改",
                                            order = 2
                                        },

                                        apply = {
                                            type = "execute",
                                            name = "应用更改",
                                            order = 3,
                                            confirm = true,
                                            func = function()
                                                for k, v in pairs(shareDB.imported) do
                                                    if type(v) == "table" then
                                                        self.DB.profile.displays[k] = v
                                                    end
                                                end

                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 2

                                                self:EmbedDisplayOptions()
                                                QueueRebuildUI()
                                            end
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 4,
                                            func = function()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end
                                        }
                                    },
                                    hidden = function()
                                        return shareDB.importStage ~= 1
                                    end
                                },

                                stage2 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    args = {
                                        note = {
                                            type = "description",
                                            name = "导入的设置已经成功应用！\n\n如果有必要，点击重置重新开始。",
                                            order = 1,
                                            fontSize = "medium",
                                            width = "full"
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 2,
                                            func = function()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end
                                        }
                                    },
                                    hidden = function()
                                        return shareDB.importStage ~= 2
                                    end
                                }
                            },
                            plugins = {}
                        },

                        export = {
                            type = "group",
                            name = "导出",
                            order = 2,
                            args = {
                                stage0 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = "选择要导出的显示样式，然后单击导出样式生成导出字符串。",
                                            order = 1,
                                            fontSize = "medium",
                                            width = "full"
                                        },

                                        displays = {
                                            type = "header",
                                            name = "显示框架",
                                            order = 2
                                        },

                                        exportHeader = {
                                            type = "header",
                                            name = "导出",
                                            order = 1000
                                        },

                                        exportBtn = {
                                            type = "execute",
                                            name = "导出样式",
                                            order = 1001,
                                            func = function()
                                                local disps = {}
                                                for key, share in pairs(shareDB.displays) do
                                                    if share then
                                                        insert(disps, key)
                                                    end
                                                end

                                                shareDB.export = SerializeStyle(unpack(disps))
                                                shareDB.exportStage = 1
                                            end,
                                            disabled = function()
                                                local hasDisplay = false

                                                for key, value in pairs(shareDB.displays) do
                                                    if value then
                                                        hasDisplay = true
                                                        break
                                                    end
                                                end

                                                return not hasDisplay
                                            end
                                        }
                                    },
                                    plugins = {
                                        displays = {}
                                    },
                                    hidden = function()
                                        local plugins = self.Options.args.displays.args.shareDisplays.args.export.args
                                                            .stage0.plugins.displays
                                        wipe(plugins)

                                        local i = 1
                                        for dispName, display in pairs(self.DB.profile.displays) do
                                            local pos = 20 + (display.builtIn and display.order or i)
                                            plugins[dispName] = {
                                                type = "toggle",
                                                name = function()
                                                    if display.builtIn then
                                                        return "|cFF00B4FF" .. dispName .. "|r"
                                                    end
                                                    return dispName
                                                end,
                                                order = pos,
                                                width = "full"
                                            }
                                            i = i + 1
                                        end

                                        return shareDB.exportStage ~= 0
                                    end
                                },

                                stage1 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        exportString = {
                                            type = "input",
                                            name = "样式字符串",
                                            order = 1,
                                            multiline = 8,
                                            get = function()
                                                return shareDB.export
                                            end,
                                            set = function()
                                            end,
                                            width = "full",
                                            hidden = function()
                                                return shareDB.export == ""
                                            end
                                        },

                                        instructions = {
                                            type = "description",
                                            name = "你可以复制这些字符串用以分享所选的显示样式，" ..
                                                "或者使用下方选项保存所选的显示样式在以后使用。",
                                            order = 2,
                                            width = "full",
                                            fontSize = "medium"
                                        },

                                        store = {
                                            type = "group",
                                            inline = true,
                                            name = "",
                                            order = 3,
                                            hidden = function()
                                                return shareDB.export == ""
                                            end,
                                            args = {
                                                separator = {
                                                    type = "header",
                                                    name = "保存样式",
                                                    order = 1
                                                },

                                                exportName = {
                                                    type = "input",
                                                    name = "样式名称",
                                                    get = function()
                                                        return shareDB.styleName
                                                    end,
                                                    set = function(info, val)
                                                        val = val:trim()
                                                        shareDB.styleName = val
                                                    end,
                                                    order = 2,
                                                    width = "double"
                                                },

                                                storeStyle = {
                                                    type = "execute",
                                                    name = "保存导出字符串",
                                                    desc = "通过保存导出字符串，你可以保存你的显示设置，并在以后需要时使用它们。\n\n" ..
                                                        "即使使用不同的配置文件，也可以调用任意一个存储的样式。",
                                                    order = 3,
                                                    confirm = function()
                                                        if shareDB.styleName and
                                                            self.DB.global.styles[shareDB.styleName] ~= nil then
                                                            return
                                                                "已经存在名为'" .. shareDB.styleName ..
                                                                    "' 的样式了 -- 覆盖它吗？"
                                                        end
                                                        return false
                                                    end,
                                                    func = function()
                                                        local db = self.DB.global.styles
                                                        db[shareDB.styleName] = {
                                                            date = tonumber(date("%Y%m%d.%H%M%S")),
                                                            payload = shareDB.export
                                                        }
                                                        shareDB.styleName = ""
                                                    end,
                                                    disabled = function()
                                                        return shareDB.export == "" or shareDB.styleName == ""
                                                    end
                                                }
                                            }
                                        },

                                        restart = {
                                            type = "execute",
                                            name = "重新开始",
                                            order = 4,
                                            func = function()
                                                shareDB.styleName = ""
                                                shareDB.export = ""
                                                wipe(shareDB.displays)
                                                shareDB.exportStage = 0
                                            end
                                        }
                                    },
                                    hidden = function()
                                        return shareDB.exportStage ~= 1
                                    end
                                }
                            },
                            plugins = {
                                displays = {}
                            }
                        }
                    }
                }
            },
            plugins = {}
        }
        db.args.displays = section
        wipe(section.plugins)

        local i = 1

        for name, data in pairs(self.DB.profile.displays) do
            local pos = data.builtIn and data.order or i
            section.plugins[name] = newDisplayOption(db, name, data, pos)
            if not data.builtIn then
                i = i + 1
            end
        end

        section.plugins["Multi"] = newDisplayOption(db, "Multi", self.DB.profile.displays["Primary"], 0)
        MakeMultiDisplayOption(section.plugins, section.plugins.Multi.Multi.args)
    end
end

do
    local impControl = {
        name = "",
        source = UnitName("player") .. " @ " .. GetRealmName(),
        apl = "在此处粘贴您的SimulationCraft操作优先级列表或配置文件。",

        lists = {},
        warnings = ""
    }

    Hekili.ImporterData = impControl

    local function AddWarning(s)
        if impControl.warnings then
            impControl.warnings = impControl.warnings .. s .. "\n"
            return
        end

        impControl.warnings = s .. "\n"
    end

    function Hekili:GetImporterOption(info)
        return impControl[info[#info]]
    end

    function Hekili:SetImporterOption(info, value)
        if type(value) == 'string' then
            value = value:trim()
        end
        impControl[info[#info]] = value
        impControl.warnings = nil
    end

    function Hekili:ImportSimcAPL(name, source, apl, pack)
        name = name or impControl.name
        source = source or impControl.source
        apl = apl or impControl.apl

        impControl.warnings = ""

        local lists = {
            precombat = "",
            default = ""
        }

        local count = 0

        -- Rename the default action list to 'default'
        apl = "\n" .. apl
        apl = apl:gsub("actions(%+?)=", "actions.default%1=")

        local comment

        for line in apl:gmatch("\n([^\n^$]*)") do
            local newComment = line:match("^# (.+)")
            if newComment then
                if comment then
                    comment = comment .. ' ' .. newComment
                else
                    comment = newComment
                end
            end

            local list, action = line:match("^[ +]?actions%.(%S-)%+?=/?([^\n^$]*)")

            if list and action then
                lists[list] = lists[list] or ""

                if action:sub(1, 16) == "call_action_list" or action:sub(1, 15) == "run_action_list" then
                    local name = action:match(",name=(.-),") or action:match(",name=(.-)$")
                    if name then
                        action:gsub(",name=" .. name, ",name=\"" .. name .. "\"")
                    end
                end

                if comment then
                    -- Comments can have the form 'Caption::Description'.
                    -- Any whitespace around the '::' is truncated.
                    local caption, description = comment:match("(.+)::(.*)")
                    if caption and description then
                        -- Truncate whitespace and change commas to semicolons.
                        caption = caption:gsub("%s+$", ""):gsub(",", ";")
                        description = description:gsub("^%s+", ""):gsub(",", ";")
                        -- Replace "[<texture-id>]" in the caption with the escape sequence for the texture.
                        caption = caption:gsub("%[(%d+)%]", "|T%1:0|t")
                        -- Replace "[h:<text>]" in the caption with the escape sequence for the texture string.
                        caption = caption:gsub("%[h:(.-)%]", "|TInterface\\AddOns\\Hekili\\Textures\\%1:0|t")
                        -- Replace "[<text>:<height>:<width>]" in the caption with the escape sequence for the atlas.
                        caption = caption:gsub("%[(.-):(%d+):(%d+)%]", "|A:%1:%2:%3|a")
                        action = action .. ',caption=' .. caption .. ',description=' .. description
                    else
                        -- Change commas to semicolons.
                        action = action .. ',description=' .. comment:gsub(",", ";")
                    end
                    comment = nil
                end

                lists[list] = lists[list] .. "actions+=/" .. action .. "\n"
            end
        end
        if lists.precombat:len() == 0 then
            lists.precombat = "actions+=/auto_shot,enabled=0"
        end
        if lists.default:len() == 0 then
            lists.default = "actions+=/auto_shot,enabled=0"
        end

        local count = 0
        local output = {}

        for name, list in pairs(lists) do
            local import, warnings = self:ParseActionList(list)

            if warnings then
                AddWarning("警告：导入'" .. name .. "'列表需要一些自动修改。")

                for i, warning in ipairs(warnings) do
                    AddWarning(warning)
                end

                AddWarning("")
            end

            if import then
                output[name] = import

                for i, entry in ipairs(import) do
                    if entry.enabled == nil then
                        entry.enabled = not (entry.action == 'heroism' or entry.action == 'bloodlust')
                    elseif entry.enabled == "0" then
                        entry.enabled = false
                    end
                end

                count = count + 1
            end
        end

        local use_items_found = false
        local trinket1_found = false
        local trinket2_found = false

        for _, list in pairs(output) do
            for i, entry in ipairs(list) do
                if entry.action == "use_items" then
                    use_items_found = true
                elseif entry.action == "trinket1" then
                    trinket1_found = true
                elseif entry.action == "trinket2" then
                    trinket2_found = true
                end
            end
        end

        if not use_items_found and not (trinket1_found and trinket2_found) then
            AddWarning("此配置文件缺少对通用饰品的支持。建议每个优先级都需要包括：\n" ..
                           " - [使用物品]，包含任何没有包含在优先级中的饰品，或者\n" ..
                           " - [饰品1]和[饰品2]，这样做将推荐对应饰品装备栏中的饰品。")
        end

        if not output.default then
            output.default = {}
        end
        if not output.precombat then
            output.precombat = {}
        end

        if count == 0 then
            AddWarning("未能从当前配置文件导入任何技能列表。")
        else
            AddWarning("成功导入了" .. count .. "个技能列表。")
        end

        return output, impControl.warnings
    end
end

local snapshots = {
    snaps = {},
    empty = {},

    selected = 0
}

local config = {
    qsDisplay = 99999,

    qsShowTypeGroup = false,
    qsDisplayType = 99999,
    qsTargetsAOE = 3,

    displays = {}, -- auto-populated and recycled.
    displayTypes = {
        [1] = "Primary",
        [2] = "AOE",
        [3] = "Automatic",
        [99999] = " "
    },

    expanded = {
        cooldowns = true
    },
    adding = {}
}

local specs = {}
local activeSpec
-- EasyPlay：修正低于10级默认专精为第一专精
function GetCurrentSpec()
    activeSpec = activeSpec or GetSpecializationInfo(GetSpecialization())
    -- 如果角色低于10级或未有专精
    if not activeSpec or activeSpec == 0 then
        local _, classFile = UnitClass("player")
        local classSpecs = SpecData[classFile]
        -- 如果该职业存在定义的专精数据，则使用首个专精作为默认
        if classSpecs and classSpecs[1] then
            activeSpec = classSpecs[1][1] -- 第1个专精的ID作为默认
            -- kili:Print("提示：角色等级过低，自动设置首个专精: " .. classSpecs[1][2])
        else
            activeSpec = 0
        end
    end
    return activeSpec
end

-- local function GetCurrentSpec()
--     activeSpec = activeSpec or GetSpecializationInfo( GetSpecialization() )
--     return activeSpec
-- end

local function SetCurrentSpec(_, val)
    activeSpec = val
end

local function GetCurrentSpecList()
    return specs
end

do
    local packs = {}

    local specNameByID = {}
    local specIDByName = {}

    local shareDB = {
        actionPack = "",
        packName = "",
        export = "",

        import = "",
        imported = {},
        importStage = 0
    }

    function Hekili:GetPackShareOption(info)
        local n = #info
        local option = info[n]

        return shareDB[option]
    end

    function Hekili:SetPackShareOption(info, val, v2, v3, v4)
        local n = #info
        local option = info[n]

        if type(val) == 'string' then
            val = val:trim()
        end

        shareDB[option] = val

        if option == "actionPack" and rawget(self.DB.profile.packs, shareDB.actionPack) then
            shareDB.export = SerializeActionPack(shareDB.actionPack)
        else
            shareDB.export = ""
        end
    end

    function Hekili:SetSpecOption(info, val)
        local n = #info
        local spec, option = info[1], info[n]

        spec = specIDByName[spec]
        if not spec then
            return
        end

        if type(val) == 'string' then
            val = val:trim()
        end

        self.DB.profile.specs[spec] = self.DB.profile.specs[spec] or {}
        self.DB.profile.specs[spec][option] = val

        if option == "package" then
            self:UpdateUseItems()
            self:ForceUpdate("SPEC_PACKAGE_CHANGED")
        elseif option == "enabled" then
            ns.StartConfiguration()
        end

        if WeakAuras and WeakAuras.ScanEvents then
            WeakAuras.ScanEvents("HEKILI_SPEC_OPTION_CHANGED", option, val)
        end

        Hekili:UpdateDamageDetectionForCLEU()
    end

    function Hekili:GetSpecOption(info)
        local n = #info
        local spec, option = info[1], info[n]

        if type(spec) == 'string' then
            spec = specIDByName[spec]
        end
        if not spec then
            return
        end

        self.DB.profile.specs[spec] = self.DB.profile.specs[spec] or {}

        if option == "药剂" then
            local p = self.DB.profile.specs[spec].potion

            if not class.potionList[p] then
                return class.potions[p] and class.potions[p].key or p
            end
        end

        return self.DB.profile.specs[spec][option]
    end

    function Hekili:SetSpecPref(info, val)
    end

    function Hekili:GetSpecPref(info)
    end
    -- EasyPlay 修正低等级角色无专精报错
    function Hekili:SetAbilityOption(info, val)
        local n = #info
        local ability, option = info[2], info[n]
        local spec = GetCurrentSpec()
        if not spec then
            return
        end

        local db = self.DB
        db.profile = db.profile or {}
        db.profile.specs = db.profile.specs or {}
        db.profile.specs[spec] = db.profile.specs[spec] or {}
        local specData = db.profile.specs[spec]
        specData.abilities = specData.abilities or {}
        specData.abilities[ability] = specData.abilities[ability] or {}

        specData.abilities[ability][option] = val

        if option == "toggle" then
            Hekili:EmbedAbilityOption(nil, ability)
        end

        if LibStub and LibStub("AceConfigRegistry", true) then
            LibStub("AceConfigRegistry"):NotifyChange("Hekili")
        end
    end

    function Hekili:GetAbilityOption(info)
        local n = #info
        local ability, option = info[2], info[n]
        local spec = GetCurrentSpec()
        local db = self.DB
        local specData = db and db.profile and db.profile.specs and db.profile.specs[spec]
        if not specData or not specData.abilities or not specData.abilities[ability] then
            return nil
        end
        return specData.abilities[ability][option]
    end

    function Hekili:SetItemOption(info, val)
        local n = #info
        local item, option = info[2], info[n]
        local spec = GetCurrentSpec()
        if not spec then
            return
        end

        local db = self.DB
        db.profile = db.profile or {}
        db.profile.specs = db.profile.specs or {}
        db.profile.specs[spec] = db.profile.specs[spec] or {}
        local specData = db.profile.specs[spec]
        specData.items = specData.items or {}
        specData.items[item] = specData.items[item] or {}

        specData.items[item][option] = val

        if option == "toggle" then
            Hekili:EmbedItemOption(nil, item)
        end

        if LibStub and LibStub("AceConfigRegistry", true) then
            LibStub("AceConfigRegistry"):NotifyChange("Hekili")
        end
    end

    function Hekili:GetItemOption(info)
        local n = #info
        local item, option = info[2], info[n]
        local spec = GetCurrentSpec()
        local db = self.DB
        local specData = db and db.profile and db.profile.specs and db.profile.specs[spec]
        if not specData or not specData.items or not specData.items[item] then
            return nil
        end
        return specData.items[item][option]
    end

    function Hekili:EmbedAbilityOption(db, key)
        db = db or self.Options
        if not db or not key then
            return
        end

        local ability = class.abilities[key]
        if not ability then
            return
        end

        local toggles = {}

        local k = class.abilityList[ability.key]
        local v = ability.key

        if not k or not v then
            return
        end

        local useName = class.abilityList[v] and class.abilityList[v]:match("|t (.+)$") or ability.name

        if not useName then
            Hekili:Error("当前技能%s(id:%d)没有可用选项。", ability.key or "不存在此ID", ability.id or 0)
            useName = ability.key or ability.id or "???"
        end

        local option = db.args.abilities.plugins.actions[v] or {}

        option.type = "group"
        option.name = function()
            return useName .. (state:IsDisabled(v, true) and "|cFFFF0000*|r" or "")
        end
        option.order = 1
        option.set = "SetAbilityOption"
        option.get = "GetAbilityOption"
        option.args = {
            disabled = {
                type = "toggle",
                name = function()
                    return "禁用" .. (ability.item and ability.link or k)
                end,
                desc = function()
                    return "如果勾选，此技能将|cffff0000永远|r不会被插件推荐。" ..
                               "如果其他技能依赖此技能|W" .. (ability.item and ability.link or k) ..
                               "|w，那么可能会出现问题。"
                end,
                width = 2,
                order = 1
            },

            boss = {
                type = "toggle",
                name = "仅用于BOSS战",
                desc = "如果勾选，插件将不会推荐此技能 |W" .. k ..
                    "|w ，除非你处于BOSS战中。如果不勾选，|W" .. k ..
                    "|w 技能会在所有战斗中被推荐。",
                width = 2,
                order = 1.1
            },

            keybind = {
                type = "input",
                name = "覆盖键位绑定文本",
                desc = function()
                    local output =
                        "如果设置此项，当推荐此技能时，插件将显示此文本，而不是自动检测到的键位。 " ..
                            "如果键位检测错误或在多个动作栏上存在键位，这将很有帮助。"

                    local detected = Hekili.KeybindInfo and Hekili.KeybindInfo[ability.key]
                    if detected then
                        output = output .. "\n"

                        for page, text in pairs(detected.upper) do
                            output = format("%s\n检测到键位|cFFFFD100%s|r 位于动作条 |cFFFFD100%d|r上。",
                                output, text, page)
                        end
                    else
                        output = output .. "\n|cFFFFD100未检测到该技能的键位。|r"
                    end

                    return output
                end,
                validate = function(info, val)
                    val = val:trim()
                    if val:len() > 20 then
                        return "键位文本的长度不应超过20个字符。"
                    end
                    return true
                end,
                width = 2,
                order = 3
            },

            toggle = {
                type = "select",
                name = "开关状态切换",
                desc = "设置此项后，插件在技能列表中使用必须的开关切换。" ..
                    "当开关被关闭时，技能将被视为不可用，插件将假装它们处于冷却状态（除非另有设置）。",
                width = 1.5,
                order = 2,
                values = function()
                    table.wipe(toggles)

                    local t = class.abilities[v].toggle or "none"

                    toggles.none = "无"
                    toggles.default = "默认|cffffd100(" .. t .. ")|r"
                    toggles.cooldowns = "主要爆发"
                    toggles.defensives = "防御"
                    toggles.interrupts = "打断"
                    toggles.potions = "药剂"
                    toggles.custom1 = "自定义1"
                    toggles.custom2 = "自定义2"

                    return toggles
                end
            },

            targetMin = {
                type = "range",
                name = "最小目标数",
                desc = "如果设置大于0，则只有监测到敌人数至少有" .. k ..
                    "人的情况下，才会推荐此项。所有其他条件也必须满足。\n设置为0将忽略此项。",
                width = 1.5,
                min = 0,
                softMax = 15,
                max = 100,
                step = 1,
                order = 3.1
            },

            targetMax = {
                type = "range",
                name = "最大目标数",
                desc = "如果设置大于0，则只有监测到敌人数小于" .. k ..
                    "人的情况下，才会推荐此项。所有其他条件也必须满足。.\n设置为0将忽略此项。",
                width = 1.5,
                min = 0,
                max = 15,
                step = 1,
                order = 3.2
            },

            dotCap = {
                type = "range",
                name = "最大生效数",
                desc = "如果设置大于0，当该技能在等于或超过此数量的目标身上生效时，将不会再推荐该技能。如果在当前目标上的该技能可刷新，则不会受到此限制。\n\n" ..
                    "设置为0则忽略此限制。",
                width = 1.5,
                min = 0,
                max = 100,
                step = 1,
                order = 3.25
            },

            clash = {
                type = "range",
                name = "冲突",
                desc = "如果设置大于0，插件将假设" .. k .. "拥有更快的冷却时间。" ..
                    "当某个技能的优先级非常高，并且你希望插件更多地推荐它，而不是其他更快的可能技能时，此项会很有效。",
                width = 3,
                min = -1.5,
                max = 1.5,
                step = 0.05,
                order = 4
            }
        }

        db.args.abilities.plugins.actions[v] = option
    end

    local testFrame = CreateFrame("Frame")
    testFrame.Texture = testFrame:CreateTexture()
    function Hekili:EmbedAbilityOptions(db)
        db = db or self.Options
        if not db then
            return
        end

        -- 清空现有的技能选项以实现筛选功能
        -- 重置标志，确保每次调用都会重新构建UI
        self.AbilityOptionsEmbedded = false

        -- 清空现有技能选项
        if db.args.abilities and db.args.abilities.plugins then
            db.args.abilities.plugins.actions = {}
        end

        local abilities = {}
        local toggles = {}
        local searchTerm = ns.searchID or ""
        local searchLower = searchTerm:lower()

        if class and class.abilityList then
            for k, v in pairs(class.abilityList) do
                local a = class.abilities[k]
                if a and a.id and (a.id > 0 or a.id < -100) and a.id ~= 61304 and not a.item then
                    -- 添加搜索过滤逻辑
                    if searchLower == "" or v:lower():find(searchLower) or (a.name and a.name:lower():find(searchLower)) or
                        (k:lower():find(searchLower)) then
                        abilities[v] = k
                    end
                end
            end
        end
        for k, v in orderedPairs(abilities) do
            local ability = class and class.abilities and class.abilities[v]
            if ability then
                local useName = class.abilityList[v] and class.abilityList[v]:match("|t (.+)$") or ability.name

                if not useName then
                    Hekili:Error("No name available for %s (id:%d) in EmbedAbilityOptions.", ability.key or "no_id",
                        ability.id or 0)
                    useName = ability.key or ability.id or "???"
                end

                local option = {
                    type = "group",
                    name = function()
                        return useName .. (state:IsDisabled(v, true) and "|cFFFF0000*|r" or "")
                    end,
                    order = 1,
                    set = "SetAbilityOption",
                    get = "GetAbilityOption",
                    args = {
                        disabled = {
                            type = "toggle",
                            name = function()
                                return "禁用 " .. (ability.item and ability.link or k)
                            end,
                            desc = function()
                                return "如果勾选，此技能将|cffff0000永远|r不会被插件推荐。" ..
                                           "如果其他技能依赖此技能" .. (ability.item and ability.link or k) ..
                                           "，那么可能会出现问题。"
                            end,
                            width = 1.5,
                            order = 1
                        },

                        boss = {
                            type = "toggle",
                            name = "仅用于BOSS战",
                            desc = "如果勾选，插件将不会推荐此技能" .. k ..
                                "，除非你处于BOSS战中。如果不勾选，" .. k ..
                                "技能会在所有战斗中被推荐。",
                            width = 1.5,
                            order = 1.1
                        },

                        lineBreak1 = {
                            type = "description",
                            name = " ",
                            width = "full",
                            order = 1.9
                        },

                        toggle = {
                            type = "select",
                            name = "开关状态切换",
                            desc = "设置此项后，插件在技能列表中使用必须的开关切换。" ..
                                "当开关被关闭时，技能将被视为不可用，插件将假设它们处于冷却状态（除非另有设置）。",
                            width = 1.5,
                            order = 1.2,
                            values = function()
                                table.wipe(toggles)

                                local t = class.abilities[v].toggle or "none"

                                toggles.none = "无"
                                toggles.default = "默认|cffffd100(" .. t .. ")|r"
                                toggles.cooldowns = "主要爆发"
                                toggles.defensives = "防御"
                                toggles.interrupts = "打断"
                                toggles.potions = "药剂"
                                toggles.custom1 = "自定义1"
                                toggles.custom2 = "自定义2"

                                return toggles
                            end
                        },

                        lineBreak5 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 1.29
                        },

                        -- Test Option for Separate Cooldowns
                        noFeignedCooldown = {
                            type = "toggle",
                            name = "|cFFFFD100(全局)|r 当爆发单独显示时，使用实际冷却时间",
                            desc = "如果勾选，|cFFFFD100同时|r 启用了爆发单独显示 |cFFFFD100和|r 激活了爆发，插件将 |cFFFF0000不会|r 假设你的爆发技能完全处于冷却状态。\n\n" ..
                                "这可能有助于解决由于爆发单独显示框和其他显示框显示不同步，导致的技能推荐不同步的问题。" ..
                                "\n\n" ..
                                "请查阅 |cFFFFD100快捷开关|r > |cFFFFD100爆发|r 了解 |cFFFFD100爆发：单独显示|r 的功能细节。",
                            set = function()
                                self.DB.profile.specs[state.spec.id].noFeignedCooldown =
                                    not self.DB.profile.specs[state.spec.id].noFeignedCooldown
                            end,
                            get = function()
                                return self.DB.profile.specs[state.spec.id].noFeignedCooldown
                            end,
                            order = 1.3,
                            width = 3
                        },

                        lineBreak4 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 1.9
                        },

                        targetMin = {
                            type = "range",
                            name = "最小目标数",
                            desc = "如果设置大于0，则只有监测到敌人数至少有" .. k ..
                                "人的情况下，才会推荐此项。所有其他条件也必须满足。\n设置为0将忽略此项。",
                            width = 1.5,
                            min = 0,
                            max = 15,
                            step = 1,
                            order = 2
                        },

                        targetMax = {
                            type = "range",
                            name = "最大目标数",
                            desc = "如果设置大于0，则只有监测到敌人数小于" .. k ..
                                "人的情况下，才会推荐此项。所有其他条件也必须满足。.\n设置为0将忽略此项。",
                            width = 1.5,
                            min = 0,
                            max = 15,
                            step = 1,
                            order = 2.1
                        },

                        lineBreak2 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 2.11
                        },

                        dotCap = {
                            type = "range",
                            name = "最大生效数",
                            desc = "如果设置大于0，当该技能在等于或超过此数量的目标身上生效时，将不会再推荐该技能。如果在当前目标上的该技能可刷新，则不会受到此限制。\n\n" ..
                                "设置为0则忽略此限制。",
                            width = 1.5,
                            min = 0,
                            max = 100,
                            step = 1,
                            order = 2.19
                        },

                        clash = {
                            type = "range",
                            name = "冲突",
                            desc = "如果设置大于0，插件将假设" .. k .. "拥有更快的冷却时间。" ..
                                "当某个技能的优先级非常高，并且你希望插件更多地推荐它，而不是其他更快的可能技能时，此项会很有效。",
                            width = 1.5,
                            min = -1.5,
                            max = 1.5,
                            step = 0.05,
                            order = 2.2
                        },

                        lineBreak3 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 2.3
                        },

                        keybind = {
                            type = "input",
                            name = "覆盖键位绑定文本",
                            desc = function()
                                local output =
                                    "如果设置此项，当推荐此技能时，插件将显示此文本，而不是自动检测到的键位。  " ..
                                        "如果键位检测错误或在多个动作栏上存在键位，这将很有帮助。"

                                local detected = Hekili.KeybindInfo and Hekili.KeybindInfo[ability.key]
                                local found = false

                                if detected then
                                    for page, text in pairs(detected.upper) do
                                        if found == false then
                                            output = output .. "\n"
                                            found = true
                                        end
                                        output = format(
                                            "%s\n检测到键位|cFFFFD100%s|r 位于动作条 |cFFFFD100%d|r上。",
                                            output, text, page)
                                    end
                                end

                                if not found then
                                    output = format("%s\n|cFFFFD100未检测到该技能的键位。|r", output)
                                end

                                return output
                            end,
                            validate = function(info, val)
                                val = val:trim()
                                if val:len() > 6 then
                                    return "技能按键文字长度不应超过6个字符。"
                                end
                                return true
                            end,
                            width = 1.5,
                            order = 3
                        },

                        noIcon = {
                            type = "input",
                            name = "图标更改",
                            desc = "如果设置此项，插件将尝试加载设置的纹理，而不是默认图标。 此处可以是纹理 ID 或纹理文件的路径。\n\n" ..
                                "留空并按 Enter 重置为默认图标。",
                            icon = function()
                                local options = Hekili:GetActiveSpecOption("abilities")
                                return options and options[v] and options[v].icon or nil
                            end,
                            validate = function(info, val)
                                val = val:trim()
                                testFrame.Texture:SetTexture("?")
                                testFrame.Texture:SetTexture(val)
                                return testFrame.Texture:GetTexture() ~= "?"
                            end,
                            set = function(info, val)
                                val = val:trim()
                                if val:len() == 0 then
                                    val = nil
                                end

                                local options = Hekili:GetActiveSpecOption("abilities")
                                options[v].icon = val
                            end,
                            hidden = function()
                                local options = Hekili:GetActiveSpecOption("abilities")
                                return (options and rawget(options, v) and options[v].icon)
                            end,
                            width = 1.5,
                            order = 3.1
                        },

                        hasIcon = {
                            type = "input",
                            name = "图标更改",
                            desc = "如果设置此项，插件将尝试加载设置的纹理，而不是默认图标。 此处可以是纹理 ID 或纹理文件的路径。\n\n" ..
                                "留空并按 Enter 重置为默认图标。",
                            icon = function()
                                local options = Hekili:GetActiveSpecOption("abilities")
                                return options and options[v] and options[v].icon or nil
                            end,
                            validate = function(info, val)
                                val = val:trim()
                                testFrame.Texture:SetTexture("?")
                                testFrame.Texture:SetTexture(val)
                                return testFrame.Texture:GetTexture() ~= "?"
                            end,
                            get = function()
                                local options = Hekili:GetActiveSpecOption("abilities")
                                return options and rawget(options, v) and options[v].icon
                            end,
                            set = function(info, val)
                                val = val:trim()
                                if val:len() == 0 then
                                    val = nil
                                end

                                local options = Hekili:GetActiveSpecOption("abilities")
                                options[v].icon = val
                            end,
                            hidden = function()
                                local options = Hekili:GetActiveSpecOption("abilities")
                                return not (options and rawget(options, v) and options[v].icon)
                            end,
                            width = 1.3,
                            order = 3.2
                        },
                        showIcon = {
                            type = 'description',
                            name = "",
                            image = function()
                                local options = Hekili:GetActiveSpecOption("abilities")
                                return options and rawget(options, v) and options[v].icon
                            end,
                            width = 0.2,
                            order = 3.3
                        }
                    }
                }

                db.args.abilities.plugins.actions[v] = option
            end
        end

        -- 如果有搜索条件但没有匹配结果，显示提示信息
        if ns.searchID and ns.searchID ~= "" then
            local hasResults = false
            for k, v in pairs(db.args.abilities.plugins.actions or {}) do
                if k ~= "no_results" then -- 排除可能已存在的提示信息
                    hasResults = true
                    break
                end
            end

            if not hasResults then
                db.args.abilities.plugins.actions["no_results"] = {
                    type = "description",
                    name = "|cFFFF6600没有找到匹配 '" .. ns.searchID .. "' 的技能|r",
                    fontSize = "medium",
                    order = 1
                }
            end
        end
    end

    function Hekili:EmbedItemOption(db, item)
        db = db or self.Options
        if not db then
            return
        end

        local ability = class.abilities[item]
        local toggles = {}

        local k = class.itemList[ability.item] or ability.name
        local v = ability.itemKey or ability.key

        if not item or not ability.item or not k then
            Hekili:Error("在物品列表中无法找到 %s / %s / %s 。", item or "unknown",
                ability.item or "unknown", k or "unknown")
            return
        end

        local option = db.args.items.plugins.equipment[v] or {}

        option.type = "group"
        option.name = function()
            return ability.name .. (state:IsDisabled(v, true) and "|cFFFF0000*|r" or "")
        end
        option.order = 1
        option.set = "SetItemOption"
        option.get = "GetItemOption"
        option.args = {
            disabled = {
                type = "toggle",
                name = function()
                    return "禁用" .. (ability.item and ability.link or k)
                end,
                desc = function()
                    return "如果勾选，此技能将|cffff0000永远|r不会被插件推荐。" ..
                               "如果其他技能依赖此技能" .. (ability.item and ability.link or k) ..
                               "，那么可能会出现问题。"
                end,
                width = 1.5,
                order = 1
            },

            boss = {
                type = "toggle",
                name = "仅用于BOSS战",
                desc = "如果勾选，插件将不会推荐该物品" .. k ..
                    "，除非你处于BOSS战。如果不选中，" .. k .. "物品会在所有战斗中被推荐。",
                width = 1.5,
                order = 1.1
            },

            keybind = {
                type = "input",
                name = "技能按键文字",
                desc = "如果设置此项，插件将在推荐此技能时显示此处的文字，替代自动检测到的技能绑定按键的名称。" ..
                    "如果插件检测你的按键绑定出现问题，此设置能够有所帮助。",
                validate = function(info, val)
                    val = val:trim()
                    if val:len() > 6 then
                        return "技能按键文字长度不应超过6个字符。"
                    end
                    return true
                end,
                width = 1.5,
                order = 2
            },

            toggle = {
                type = "select",
                name = "开关状态切换",
                desc = "设置此项后，插件在技能列表中使用必须的开关切换。" ..
                    "当开关被关闭时，技能将被视为不可用，插件将假设它们处于冷却状态（除非另有设置）。",
                width = 1.5,
                order = 3,
                values = function()
                    table.wipe(toggles)

                    toggles.none = "无"
                    toggles.default = "默认" ..
                                          (class.abilities[v].toggle and
                                              (" |cffffd100(" .. class.abilities[v].toggle .. ")|r") or
                                              " |cffffd100(无)|r")
                    toggles.cooldowns = "主要爆发"

                    toggles.defensives = "防御"
                    toggles.interrupts = "打断"
                    toggles.potions = "药剂"
                    toggles.custom1 = "自定义1"
                    toggles.custom2 = "自定义2"

                    return toggles
                end
            },

            targetMin = {
                type = "range",
                name = "最小目标数",
                desc = "如果设置大于0，则只有检测到敌人数至少有" .. k ..
                    "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                width = 1.5,
                min = 0,
                max = 15,
                step = 1,
                order = 5
            },

            targetMax = {
                type = "range",
                name = "最大目标数",
                desc = "如果设置大于0，则只有监测到敌人数小于" .. k ..
                    "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                width = 1.5,
                min = 0,
                max = 15,
                step = 1,
                order = 6
            }
        }

        db.args.items.plugins.equipment[v] = option
    end

    function Hekili:EmbedItemOptions(db)
        db = db or self.Options
        if not db then
            return
        end

        -- 清空现有的装备选项以实现筛选功能
        if db.args and db.args.items and db.args.items.plugins and db.args.items.plugins.equipment then
            wipe(db.args.items.plugins.equipment)
        end

        local abilities = {}
        local toggles = {}

        for k, v in pairs(class.abilities) do
            if k == "potion" or v.item and not abilities[v.itemKey or v.key] then
                local name = class.itemList[v.item] or v.name
                if name then
                    abilities[name] = v.itemKey or v.key
                end
            end
        end
        for k, v in orderedPairs(abilities) do
            local ability = class.abilities[v]

            -- 筛选功能：如果有搜索条件，只显示匹配的项目
            if ns.searchItemName ~= "" and not string.find(ability.name, ns.searchItemName) then
                -- 跳过不匹配的项目，继续下一个循环
            else
                local option = {
                    type = "group",
                    -- EasyPlay提供的装备和道具
                    name = function()
                        local name = ability.name .. (state:IsDisabled(v, true) and "|cFFFF0000禁|r" or "")
                        return name
                    end,
                    order = 1,
                    set = "SetItemOption",
                    get = "GetItemOption",
                    args = {
                        multiItem = {
                            type = "description",
                            name = function()
                                return "这些设置将应用于|cFF00FF00所有|r 类似于" .. ability.name ..
                                           "的PvP饰品。"
                            end,
                            fontSize = "medium",
                            width = "full",
                            order = 1,
                            hidden = function()
                                return ability.key ~= "gladiators_badge" and ability.key ~= "gladiators_emblem" and
                                           ability.key ~= "gladiators_medallion"
                            end
                        },

                        disabled = {
                            type = "toggle",
                            name = function()
                                return "禁用" .. (ability.item and ability.link or k)
                            end,
                            desc = function()
                                return "如果勾选，此技能将|cffff0000永远|r不会被插件推荐。" ..
                                           "如果其他技能依赖此技能" .. (ability.item and ability.link or k) ..
                                           "，那么可能会出现问题。"
                            end,
                            width = 1.5,
                            order = 1.05
                        },

                        boss = {
                            type = "toggle",
                            name = "仅用于BOSS战",
                            desc = "如果勾选，插件将不会推荐该物品" .. k ..
                                "，除非你处于BOSS战。如果不选中，" .. k ..
                                "物品会在所有战斗中被推荐。",
                            width = 1.5,
                            order = 1.1
                        },

                        keybind = {
                            type = "input",
                            name = "技能按键文字",
                            desc = "如果设置此项，插件将在推荐此技能时显示此处的文字，替代自动检测到的技能绑定按键的名称。" ..
                                "如果插件检测你的按键绑定出现问题，此设置能够有所帮助。",
                            validate = function(info, val)
                                val = val:trim()
                                if val:len() > 6 then
                                    return "技能按键文字长度不应超过6个字符。"
                                end
                                return true
                            end,
                            width = 1.5,
                            order = 2
                        },

                        toggle = {
                            type = "select",
                            name = "开关状态切换",
                            desc = "设置此项后，插件在技能列表中使用必须的开关切换。" ..
                                "当开关被关闭时，技能将被视为不可用，插件将假装它们处于冷却状态（除非另有设置）。",
                            width = 1.5,
                            order = 3,
                            values = function()
                                table.wipe(toggles)

                                toggles.none = "无"
                                toggles.default = "默认" ..
                                                      (ability.toggle and (" |cffffd100(" .. ability.toggle .. ")|r") or
                                                          " |cffffd100(无)|r")
                                toggles.cooldowns = "主要爆发"

                                toggles.defensives = "防御"
                                toggles.interrupts = "打断"
                                toggles.potions = "药剂"
                                toggles.custom1 = "自定义1"
                                toggles.custom2 = "自定义2"

                                return toggles
                            end
                        },

                        targetMin = {
                            type = "range",
                            name = "最小目标数",
                            desc = "如果设置大于0，则只有监测到敌人数至少有" ..
                                (ability.item and ability.link or k) ..
                                "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                            width = 1.5,
                            min = 0,
                            max = 15,
                            step = 1,
                            order = 5
                        },

                        targetMax = {
                            type = "range",
                            name = "最大目标数",
                            desc = "如果设置大于0，则只有监测到敌人数小于" ..
                                (ability.item and ability.link or k) ..
                                "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                            width = 1.5,
                            min = 0,
                            max = 15,
                            step = 1,
                            order = 6
                        }
                    }
                }

                db.args.items.plugins.equipment[v] = option
            end
        end

        -- 如果有搜索条件但没有匹配结果，显示提示信息
        if ns.searchItemName ~= "" then
            local hasResults = false
            for k, v in pairs(db.args.items.plugins.equipment or {}) do
                hasResults = true
                break
            end

            if not hasResults then
                db.args.items.plugins.equipment["no_results"] = {
                    type = "description",
                    name = "|cFFFF6600没有找到匹配 '" .. ns.searchItemName .. "' 的装备|r",
                    fontSize = "medium",
                    order = 1
                }
            end
        end

        self.NewItemInfo = false
    end

    local ToggleCount = {}
    local tAbilities = {}
    local tItems = {}

    -- Options table constructors.
    function Hekili:EmbedSpecOptions(db)
        db = db or self.Options
        if not db then
            return
        end

        local i = 1
        local numSpecs = GetNumSpecializations()

        -- First, populate specs table for dropdown usage
        for specIndex = 1, numSpecs do
            local id, name, description, texture, role = GetSpecializationInfo(specIndex)

            if id and name then
                if description then
                    description = description:match("^(.-)\n")
                end

                local sName = lower(name)
                specNameByID[id] = sName
                specIDByName[sName] = id

                -- Create display name with safe fallbacks
                local displayName = name or ("Spec " .. tostring(id))
                local safeTexture = texture or 134400

                specs[id] = Hekili:ZoomedTextureWithText(safeTexture, displayName)
            end
        end

        -- Now create options only for specs that are defined in class.specs
        i = 1
        while (true) do
            local id, name, description, texture, role = GetSpecializationInfo(i)

            if not id then
                break
            end

            if description then
                description = description:match("^(.-)\n")
            end
            local spec = class and class.specs and class.specs[id]

            if spec then
                local sName = lower(name or ("spec_" .. tostring(id)))
                specNameByID[id] = sName
                specIDByName[sName] = id

                local options = {
                    type = "group",
                    name = name,
                    icon = texture,
                    iconCoords = {0.15, 0.85, 0.15, 0.85},
                    desc = description,
                    order = 50 + i,
                    childGroups = "tab",
                    get = "GetSpecOption",
                    set = "SetSpecOption",

                    args = {
                        core = {
                            type = "group",
                            name = "核心",
                            desc = "对" .. specs[id] .. "职业专精的核心技能进行专门优化设置。",
                            order = 1,
                            args = {
                                enabled = {
                                    type = "toggle",
                                    name = "启用",
                                    desc = "如果勾选，插件将基于" .. name ..
                                        "职业专精的优先级进行技能推荐。",
                                    order = 0,
                                    width = "full"
                                },

                                package = {
                                    type = "select",
                                    name = "优先级",
                                    desc = "插件在进行技能推荐时使用的优先级配置。",
                                    order = 1,
                                    width = 1.5,
                                    values = function(info, val)
                                        wipe(packs)

                                        for key, pkg in pairs(self.DB.profile.packs) do
                                            local pname = pkg.builtIn and "|cFF00B4FF" .. key .. "|r" or key
                                            if pkg.spec == id then
                                                packs[key] = Hekili:ZoomedTextureWithText(texture, pname)
                                            end
                                        end

                                        packs['(none)'] = '（无）'

                                        return packs
                                    end
                                },

                                openPackage = {
                                    type = 'execute',
                                    name = "",
                                    desc = "打开查看该优先级配置和技能列表。",
                                    image = GetAtlasFile("communities-icon-searchmagnifyingglass"),
                                    imageCoords = GetAtlasCoords("communities-icon-searchmagnifyingglass"),
                                    imageHeight = 24,
                                    imageWidth = 24,
                                    disabled = function(info, val)
                                        local pack = self.DB.profile.specs[id].package
                                        return rawget(self.DB.profile.packs, pack) == nil
                                    end,
                                    func = function()
                                        ACD:SelectGroup("Hekili", "packs", self.DB.profile.specs[id].package)
                                    end,
                                    order = 1.1,
                                    width = 0.15
                                },

                                potion = {
                                    type = "select",
                                    name = "药剂",
                                    desc = "除非优先级中另有指定，否则将推荐此处选择的药剂。",
                                    order = 3,
                                    width = 1.5,
                                    values = class.potionList,
                                    get = function()
                                        local p = self.DB.profile.specs[id].potion or
                                                      (class and class.specs and class.specs[id] and
                                                          class.specs[id].options.potion) or "default"
                                        if not class.potionList[p] then
                                            p = "default"
                                        end
                                        return p
                                    end
                                },

                                blankLine1 = {
                                    type = 'description',
                                    name = '',
                                    order = 2,
                                    width = 'full'
                                }
                            },
                            plugins = {
                                settings = {}
                            }
                        },

                        targets = {
                            type = "group",
                            name = "目标识别",
                            desc = "设置插件如何识别和统计敌人的数量。",
                            order = 3,
                            args = {
                                targetsHeader = {
                                    type = "description",
                                    name = "这些设置可以控制在推荐技能时，如何统计目标。\n\n" ..
                                        "默认情况下，识别到的目标数量将显示在“主显示”和“AOE”显示框架的主图标的右下角，除非只识别到一个目标。" ..
                                        "\n\n" ..
                                        "你真正的攻击目标总是被统计的。\n\n|cFFFF0000警告：|r 动作目标系统的“软目标”目前尚未支持。\n\n",
                                    width = "full",
                                    fontSize = "medium",
                                    order = 0.01
                                },
                                yourTarget = {
                                    type = "toggle",
                                    name = "选中的目标",
                                    desc = "即使没有敌对目标，你选中的目标也会被视作敌人。\n\n" ..
                                        "此设置不可禁用。",
                                    width = "full",
                                    get = function()
                                        return true
                                    end,
                                    set = function()
                                    end,
                                    order = 0.02
                                },

                                -- Damage Detection Quasi-Group
                                damage = {
                                    type = "toggle",
                                    name = "统计受伤害敌人",
                                    desc = "如果勾选，你造成过伤害的目标将在数秒内被判定为有效敌人，" ..
                                        "与未被你攻击过的其他敌人区分开来。\n\n" ..
                                        CreateAtlasMarkup("services-checkmark") ..
                                        " 当姓名板禁用时，此功能将自动启用\n\n" ..
                                        CreateAtlasMarkup("services-checkmark") ..
                                        "推荐 |cffffd100远程职业|r 在无法使用 |cffffd100基于宠物的目标检测|r 时使用。",
                                    width = "full",
                                    order = 0.3
                                },

                                dmgGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "伤害监测",
                                    order = 0.4,
                                    hidden = function()
                                        return self.DB.profile.specs[id].damage == false
                                    end,
                                    args = {
                                        damagePets = {
                                            type = "toggle",
                                            name = "被宠物伤害的敌人",
                                            desc = "如果勾选，插件会统计你的宠物或仆从在过去几秒内击中（或被击中）的敌人。" ..
                                                "如果你的宠物/仆从分散在多处，可能会统计错误。",
                                            order = 2,
                                            width = "full"
                                        },

                                        damageExpiration = {
                                            type = "range",
                                            name = "超时",
                                            desc = "当勾选 |cFFFFD100统计受伤害敌人|r 时，在该时间段内，敌人将被计算在内，直到被忽略/清除（或死亡）。\n\n" ..
                                                "理想状况下，此应该应该设置足够长，以便在此期间持续对敌人造成AOE/延时伤害，" ..
                                                "但又不能太长，以免敌人已经离开攻击范围。",
                                            softMin = 3,
                                            min = 1,
                                            max = 10,
                                            step = 0.1,
                                            order = 1,
                                            width = 1.5
                                        },

                                        damageDots = {
                                            type = "toggle",
                                            name = "统计被削弱/延时伤害(Dot)的敌人",
                                            desc = "勾选时，受到你的削弱技能或延时伤害效果的敌人将被算作目标，无论他们在战场上的位置如何。\n\n" ..
                                                "这可能不是近战专精的理想选择，因为敌人会在你施放流血后走开。|cFFFFD100Use Nameplate Detection|r, " ..
                                                "如果与|cFFFFD100使用姓名板检测|r一起使用，将过滤不再处于近战范围内的敌人。\n\n" ..
                                                "推荐给对多个敌人造成 DoT 且不依赖敌人叠加 AOE 伤害的远程专精。",
                                            width = "full",
                                            order = 3
                                        },

                                        damageOnScreen = {
                                            type = "toggle",
                                            name = "过滤屏幕外的敌人",
                                            desc = function()
                                                return
                                                    "如果勾选，基于伤害的目标检测将只统计屏幕内的敌人。如果未勾选，屏幕外的目标数量也会包含在计数中。\n\n" ..
                                                        (GetCVar("nameplateShowEnemies") == "0" and
                                                            "|cFFFF0000启用敌对姓名板|r" or
                                                            "|cFF00FF00启用敌对姓名板|r")
                                            end,
                                            width = "full",
                                            order = 4
                                        }
                                    }
                                },
                                nameplates = {
                                    type = "toggle",
                                    name = "使用姓名板检测",
                                    desc = "如果勾选，则所选法术范围内的敌方姓名板将被算作敌对目标。\n\n" ..
                                        AtlasToString("common-icon-checkmark") ..
                                        " 建议使用近战技能或短程法术的近战专精使用。\n\n" ..
                                        AtlasToString("common-icon-redx") .. " 不建议用于远程专精。",
                                    width = "full",
                                    order = 0.1
                                },

                                petbased = {
                                    type = "toggle",
                                    name = "统计宠物附近的敌人",
                                    desc = function()
                                        local msg =
                                            "如果勾选并配置正确，当你的目标也在你的宠物的攻击范围内时，插件会将你宠物附近的目标也进行统计。\n\n"
                                        msg = msg .. "|cFFFFD100熊猫人之谜基于宠物的检测：|r\n"
                                        msg = msg .. "• 自动检测你宠物技能范围内的目标 \n"
                                        msg = msg .. "• 适用于所有宠物类型（猎人 / 术士）\n"
                                        msg = msg .. "• 需启用敌人姓名板方可使用\n"
                                        msg = msg .. "• 借助你动作条中的宠物技能实现范围检测"

                                        if Hekili:HasPetBasedTargetSpell() then
                                            local spell = Hekili:GetPetBasedTargetSpell()
                                            local link = Hekili:GetSpellLinkWithTexture(spell)

                                            msg = msg .. "\n\n" .. link ..
                                                      "|w|r 存在于你的动作条上，并且将作用于你所有的 " ..
                                                      UnitClass("player") .. " 宠物。"
                                        else
                                            msg = msg ..
                                                      "\n\n|cFFFFD100提示：|r 基于宠物的检测功能会自动检查你宠物的动作条，以获取适用的技能。"
                                        end

                                        if GetCVar("nameplateShowEnemies") == "1" then
                                            msg = msg ..
                                                      "\n\n敌对姓名板|cFF00FF00已启用|r，并将用于检测你宠物附近的目标。"
                                        else
                                            msg = msg .. "\n\n|cFFFF0000需要启用敌对姓名板。|r"
                                        end

                                        return msg
                                    end,
                                    width = "full",
                                    hidden = function()
                                        return Hekili:GetPetBasedTargetSpells() == nil
                                    end,
                                    order = 0.2
                                },

                                petbasedGuidance = {
                                    type = "description",
                                    name = function()
                                        local out

                                        if not self:HasPetBasedTargetSpell() then
                                            out =
                                                "基于宠物的检测功能会自动检查你宠物的动作条，以获取适用的技能。\n\n"
                                            out = out .. "|cFFFFD100设置方法：|r\n"
                                            out = out ..
                                                      "• |cFF00FF00自动模式|r: 依赖宠物动作条上的宠物技能（推荐使用）\n"
                                            out = out ..
                                                      "• |cFF00FF00宏模式|r: 创建包含（/cast [@pet] Bite）或（/cast [@pet] Whiplash）的宏命令，并放置到动作条上\n\n"
                                            local spells = Hekili:GetPetBasedTargetSpells()

                                            if not spells then
                                                return " "
                                            end

                                            -- MoP-specific guidance
                                            local className = UnitClass("player")
                                            if className == "HUNTER" then
                                                out = out ..
                                                          "对于熊猫人之谜中的|cFF00FF00猎人|r，推荐使用|cFFFFD100撕咬|r，因为它具有射程和可用性。适用于你所有的宠物。\n\n"
                                                out = out .. "|cFFFFD100推荐宠物技能：|r\n"
                                                out = out .. "• |cFF00FF00撕咬|r - 野兽宠物，5码范围\n"
                                                out = out .. "• |cFF00FF00爪击|r - 野兽宠物，5码范围\n"
                                                out = out .. "• |cFF00FF00重击|r - 野兽宠物，5码范围\n"
                                                out = out .. "• |cFF00FF00尖啸|r - 鸟类宠物，7码范围\n"
                                                out = out .. "• |cFF00FF00尘云|r - 蠕虫宠物，7码范围\n"
                                                out = out .. "• |cFF00FF00缠绕|r - 蜘蛛宠物，7码范围\n"
                                                out = out ..
                                                          "• |cFF00FF00巨兽撕咬|r - 魔暴龙宠物，7码范围\n"
                                                out = out .. "• |cFF00FF00跃迁|r - 跃迁兽宠物，7码范围\n\n"
                                            elseif className == "WARLOCK" then
                                                out = out ..
                                                          "对于熊猫人之谜中的|cFF00FF00术士|r，推荐使用|cFFFFD100鞭打|r（魅魔），因其射程优势。\n\n"
                                                out = out .. "|cFFFFD100推荐宠物技能：|r\n"
                                                out = out .. "• |cFF00FF00鞭打|r - 魅魔，10码范围\n"
                                                out = out .. "• |cFF00FF00剧痛鞭笞|r - 魅魔，7码范围\n"
                                                out = out .. "• |cFF00FF00顺劈|r - 恶魔卫士，7码范围\n"
                                                out = out ..
                                                          "• |cFF00FF00恶魔风暴|r - 恶魔卫士，7码范围\n"
                                                out = out ..
                                                          "• |cFF00FF00暗影撕咬|r - 地狱猎犬，7码范围\n"
                                                out = out ..
                                                          "• |cFF00FF00腐肉群袭|r - 地狱猎犬，7码范围\n\n"
                                            else
                                                out = out ..
                                                          "对于%s，推荐%s，因其射程优势，适用于你所有的宠物。"
                                                local link = Hekili:GetSpellLinkWithTexture(spells.best)
                                                out = format(out, className, link)
                                            end

                                            if spells.count > 1 and className ~= "HUNTER" and className ~= "WARLOCK" then
                                                out = out .. "\nAlternative(s): "
                                                local n = 1
                                                for spell in pairs(spells) do
                                                    if type(spell) == "number" and spell ~= spells.best then
                                                        n = n + 1
                                                        local link = Hekili:GetSpellLinkWithTexture(spell)
                                                        if n == 2 and spells.count == 2 then
                                                            out = out .. link .. "."
                                                        elseif n ~= spells.count then
                                                            out = out .. link .. ", "
                                                        else
                                                            out = out .. "and " .. link .. "."
                                                        end
                                                    end
                                                end
                                            end
                                        end

                                        if GetCVar("nameplateShowEnemies") ~= "1" then
                                            if not out then
                                                out =
                                                    "|cFFFFD100注意：|r 基于宠物的检测无需姓名板，但只能检测你的目标和焦点。"
                                            else
                                                out = out ..
                                                          "\n\n|cFFFFD100注意：|r 基于宠物的检测无需姓名板，但是只能检测你的目标和焦点。"
                                            end
                                        end

                                        return out
                                    end,
                                    fontSize = "medium",
                                    width = "full",
                                    disabled = function(info, val)
                                        if Hekili:GetPetBasedTargetSpells() == nil then
                                            return true
                                        end
                                        if self.DB.profile.specs[id].petbased == false then
                                            return true
                                        end
                                        if self:HasPetBasedTargetSpell() then
                                            return true
                                        end

                                        return false
                                    end,
                                    order = 0.21,
                                    hidden = function()
                                        return not self.DB.profile.specs[id].petbased
                                    end
                                },

                                mopPetDetection = {
                                    type = "group",
                                    inline = true,
                                    name = "宠物检测设置",
                                    order = 0.12,
                                    hidden = function()
                                        return
                                            not self.DB.profile.specs[id].petbased or UnitClass("player") ~= "HUNTER" and
                                                UnitClass("player") ~= "WARLOCK"
                                    end,
                                    args = {
                                        mopPetInfo = {
                                            type = "description",
                                            name = function()
                                                local className = UnitClass("player")
                                                if className == "HUNTER" then
                                                    return "|cFFFFD100猎人宠物检测：|r\n" ..
                                                               "• 自动探测 5-7 码范围内的目标\n" ..
                                                               "• 适用于所有宠物类型（野兽、鸟类、蠕虫等）\n" ..
                                                               "• 使用你动作条上的宠物技能\n" ..
                                                               "• 推荐：撕咬 以获得最佳探测范围"
                                                elseif className == "WARLOCK" then
                                                    return "|cFFFFD100术士宠物检测：|r\n" ..
                                                               "• 自动探测 7-10 码范围内的目标\n" ..
                                                               "• 适用于所有恶魔类型（魅魔、恶魔卫士、地狱犬）\n" ..
                                                               "• 使用你动作条上的宠物技能\n" ..
                                                               "• 推荐：鞭打 以获得最佳探测范围"
                                                end
                                                return ""
                                            end,
                                            width = "full",
                                            order = 1
                                        },

                                        petRangeInfo = {
                                            type = "description",
                                            name = function()
                                                local className = UnitClass("player")
                                                if className == "HUNTER" then
                                                    return "|cFF00FF00宠物技能范围：|r\n" ..
                                                               "• 撕咬/爪击/重击：5码（野兽类宠物）\n" ..
                                                               "• 尖啸：7码（鸟类宠物）\n" ..
                                                               "• 尘雾：7码（蠕虫类宠物）\n" ..
                                                               "• 钉刺：7码（蜘蛛类宠物）\n" ..
                                                               "• 巨兽撕咬：7码（魔暴龙类宠物）\n" ..
                                                               "• 跃迁：7码（跃迁追猎者类宠物）"
                                                elseif className == "WARLOCK" then
                                                    return "|cFF00FF00宠物技能范围：|r\n" ..
                                                               "• 鞭笞：10码\n" ..
                                                               "• 痛苦鞭笞/顺劈/邪能风暴：7码\n" ..
                                                               "• 暗影撕咬/腐肉群袭：7码"
                                                end
                                                return ""
                                            end,
                                            width = "full",
                                            order = 2
                                        }
                                    }
                                },

                                npGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "姓名板",
                                    order = 0.11,
                                    hidden = function()
                                        return not self.DB.profile.specs[id].nameplates
                                    end,
                                    args = {
                                        nameplateRequirements = {
                                            type = "description",
                                            name = "该功能需要同时启用|cFFFFD100显示敌对姓名板|r和|cFFFFD100显示所有姓名板|r。",
                                            width = "full",
                                            hidden = function()
                                                return GetCVar("nameplateShowEnemies") == "1" and
                                                           GetCVar("nameplateShowAll") == "1"
                                            end,
                                            order = 1
                                        },

                                        nameplateShowEnemies = {
                                            type = "toggle",
                                            name = "显示敌对姓名板",
                                            desc = "如果勾选，将显示敌人的姓名板，并可用于计算敌人数量。",
                                            width = 1.4,
                                            get = function()
                                                return GetCVar("nameplateShowEnemies") == "1"
                                            end,
                                            set = function(info, val)
                                                if InCombatLockdown() then
                                                    return
                                                end
                                                SetCVar("nameplateShowEnemies", val and "1" or "0")
                                            end,
                                            hidden = function()
                                                return GetCVar("nameplateShowEnemies") == "1" and
                                                           GetCVar("nameplateShowAll") == "1"
                                            end,
                                            order = 1.2
                                        },

                                        nameplateShowAll = {
                                            type = "toggle",
                                            name = "显示所有姓名板",
                                            desc = "如果勾选，则会显示所有姓名板（而不仅仅是你的目标），并可用于计算敌人数量。",
                                            width = 1.4,
                                            get = function()
                                                return GetCVar("nameplateShowAll") == "1"
                                            end,
                                            set = function(info, val)
                                                if InCombatLockdown() then
                                                    return
                                                end
                                                SetCVar("nameplateShowAll", val and "1" or "0")
                                            end,
                                            hidden = function()
                                                return GetCVar("nameplateShowEnemies") == "1" and
                                                           GetCVar("nameplateShowAll") == "1"
                                            end,
                                            order = 1.3
                                        },

                                        nameplateRange = {
                                            type = "range",
                                            name = "攻击半径内的敌人",
                                            desc = "如果启用了 |cFFFFD100姓名板统计|r，处于该范围内的敌人将包含在目标统计中。\n\n" ..
                                                "只有同时启用了 |cFFFFD100显示敌人姓名板|r 和 |cFFFFD100显示所有姓名板|r 时，此设置才可用。",
                                            width = "full",
                                            order = 0.1,
                                            min = 0,
                                            max = 100,
                                            step = 1,
                                            hidden = function()
                                                return not (GetCVar("nameplateShowEnemies") == "1" and
                                                           GetCVar("nameplateShowAll") == "1")
                                            end
                                        }

                                    }
                                },

                                cycle = {
                                    type = "toggle",
                                    name = "允许切换目标|TInterface\\Addons\\Hekili\\Textures\\Cycle:0|t",
                                    desc = "启用切换目标时, 当你需要对另一目标使用技能时，会显示图标(|TInterface\\Addons\\Hekili\\Textures\\Cycle:0|t)。\n\n" ..
                                        "这对于某些只想将Debuff应用于另一个目标的专精非常有效（比如踏风），但对于那些需要根据持续时间来维持输出的专精（比如痛苦），" ..
                                        "效果会可能不尽人意。.\n\n该功能将在今后的更新中逐步加以改进。",
                                    width = "full",
                                    order = 6
                                },

                                cycleGroup = {
                                    type = "group",
                                    name = "切换目标",
                                    inline = true,
                                    hidden = function()
                                        return not self.DB.profile.specs[id].cycle
                                    end,
                                    order = 7,
                                    args = {
                                        cycle_min = {
                                            type = "range",
                                            name = "死亡时间过滤器",
                                            desc = "勾选|cffffd100推荐切换目标|r 时，该值将决定哪些目标会被作为目标切换。" ..
                                                "如果设置为5，没有存活超过5秒的目标，则不会推荐切换目标。这有助于避免即将死亡的目标无法受到延时伤害效果。" ..
                                                "\n\n设为 0 则计算所有检测到的目标。",
                                            width = "full",
                                            min = 0,
                                            max = 15,
                                            step = 1,
                                            order = 1
                                        }
                                    }
                                },

                                aoe = {
                                    type = "range",
                                    name = "AOE显示框：最小目标数",
                                    desc = "当监测到满足该数量的目标数时，将启用AOE显示框进行技能推荐。\n\n这在双显示模式下会很有用，例如，若群体伤害优先级通常在至少有5个目标时才会改变，那么该设置可确保在正常情况下不改变的情况下仍能显示出你的群体伤害优先级。\n设置为5，可以确保在AOE模式下遵循正确的优先级。不同的专精和配装可能对应着不同的最优数值。",
                                    width = "full",
                                    min = 2,
                                    max = 10,
                                    step = 1,
                                    order = 10
                                }
                            }
                        },

                        performance = {
                            type = "group",
                            name = "性能",
                            order = 10,
                            args = {
                                mode = {
                                    type = "select",
                                    name = "模式",
                                    desc = "选择性能预设：\n\n" ..
                                        "• 低：为较慢/较旧的系统提供保守更新。\n" ..
                                        "• 中：为大多数系统提供平衡更新。\n" ..
                                        "• 高：为高端机器提供最快更新。",
                                    order = 1,
                                    width = 1.5,
                                    values = {"低", "中", "高"},
                                    get = function(info)
                                        local p = Hekili.DB.profile
                                        p.performance = p.performance or {}
                                        return p.performance.mode or 2
                                    end,
                                    set = function(info, v)
                                        local p = Hekili.DB.profile
                                        p.performance = p.performance or {}
                                        p.performance.mode = v
                                    end
                                },
                                frameBudget = {
                                    type = "range",
                                    name = "帧预算",
                                    desc = "设定可以用于计算推荐技能的时间。",
                                    min = 0.1,
                                    softMin = 0.2,
                                    softMax = 0.9,
                                    max = 1,
                                    step = 0.05,
                                    isPercent = true,
                                    get = function(_)
                                        return Hekili.DB.profile.performance.frameBudget or 0.7
                                    end,
                                    set = function(_, v)
                                        Hekili.DB.profile.performance.frameBudget = v
                                    end,
                                    width = "full"
                                },
                                frameBudgetInfo = {
                                    type = "description",
                                    name = function()
                                        local fps = Hekili.GetSmoothedFPS and Hekili.GetSmoothedFPS() or GetFramerate()
                                        local budget = Hekili.DB.profile.performance.frameBudget or 0.7
                                        local frameBudgetMs = (1000 / math.max(fps, 30)) * budget

                                        return "\n设定可以用于计算推荐技能的时间。\n\n" ..
                                                   "|cFFFFD100• 较高值|r 允许推荐技能 |cFF00FF00更快速地更新|r 但可能会风险降低帧率，" ..
                                                   "尤其是当其他插件同时工作时。\n" ..
                                                   "|cFFFFD100• 较低值|r 意味着推荐技能可能会 |cFF00FF00更慢地更新|r 但可能会 |cFF00FF00保留帧率|r。\n\n" ..

                                                   "调整此预算以平衡 |cFF00FF00流畅的游戏体验|r 和 |cFF00FF00及时的技能推荐|r。 " ..
                                                   "请根据你的系统情况，设置最高的数值，确保游戏运行流畅，且屏幕不会出现冻结或卡顿。\n\n" ..

                                                   "|cFF00B4FF默认（推荐）|r: |cFFFFD10070%|r\n\n" ..

                                                   "在 |cFFFFD700" .. format("%.1f", fps) ..
                                                   " FPS|r 的帧率下，|cFFFFD700" .. (budget * 100) ..
                                                   "%|r 的预算 " .. "允许每次更新最多使用 |cFFFFD700" ..
                                                   format("%.2f", frameBudgetMs) ..
                                                   " 毫秒|r 的帧时间。计算耗时更长的建议 " ..
                                                   "将至少延迟 1 帧。"
                                    end,
                                    fontSize = "medium",
                                    width = "full",
                                    order = 2
                                },
                                enhancedEvents = {
                                    type = "toggle",
                                    name = "增强事件",
                                    desc = "启用增强的事件处理，以获得更好的APL兼容性和性能监控。这提供了对重要光环的改进追踪、更好的战斗日志事件处理以及性能监控工具。",
                                    order = 3,
                                    width = "full",
                                    get = function()
                                        return Hekili.DB.profile.enhancedEvents or false
                                    end,
                                    set = function(_, value)
                                        Hekili.DB.profile.enhancedEvents = value
                                        Hekili:BuildUI()
                                    end
                                },
                                enhancedEventsInfo = {
                                    type = "description",
                                    name = "增强事件提供：\n" ..
                                        "• 通过改进的光环追踪实现更好的APL兼容性\n" ..
                                        "• 增强的战斗日志事件处理\n" .. "• 性能监控与调试工具\n" ..
                                        "• 改进的事件注册与管理\n\n" ..
                                        "此功能专为5.5.0及更高版本的APL设计。",
                                    fontSize = "small",
                                    width = "full",
                                    order = 4
                                }
                            }
                        }
                    }
                }
                local specCfg = class and class.specs and class.specs[id] and class.specs[id].settings
                local specProf = self.DB.profile.specs[id]

                if specCfg and #specCfg > 0 then
                    options.args.core.plugins.settings.prefSpacer = {
                        type = "description",
                        name = " ",
                        order = 100,
                        width = "full"
                    }
                    options.args.core.plugins.settings.prefHeader = {
                        type = "header",
                        name = (specs[id] or name or "未知") .. " 设置项",
                        order = 100.1
                    }

                    for i, option in ipairs(specCfg) do
                        if i > 1 and i % 2 == 1 then
                            -- Insert line break.
                            options.args.core.plugins.settings[sName .. "LB" .. i] = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = option.info.order - 0.01
                            }
                        end
                        options.args.core.plugins.settings[option.name] = option.info
                        -- Ensure spec profile exists and has settings table
                        if not self.DB.profile.specs[id] then
                            self.DB.profile.specs[id] = {}
                        end
                        if not self.DB.profile.specs[id].settings then
                            self.DB.profile.specs[id].settings = {}
                        end
                        if self.DB.profile.specs[id].settings[option.name] == nil then
                            self.DB.profile.specs[id].settings[option.name] = option.default
                        end
                    end
                end

                db.plugins.specializations[sName] = options
            end

            i = i + 1
        end
    end

    local packControl = {
        listName = "default",
        actionID = "0001",

        makingNew = false,
        newListName = nil,

        showModifiers = false,

        newPackName = "",
        newPackSpec = ""
    }

    local nameMap = {
        call_action_list = "list_name",
        run_action_list = "list_name",
        variable = "var_name",
        op = "op"
    }

    local defaultNames = {
        list_name = "default",
        var_name = "unnamed_var"
    }

    local toggleToNumber = {
        cycle_targets = true,
        for_next = true,
        max_energy = true,
        only_cwc = true,
        strict = true,
        use_off_gcd = true,
        use_while_casting = true
    }

    -- Updated GetActionList to include all internal handlers, abilities, and items.
    local GetActionList = function(packName, listName, i)
        local p = Hekili.DB.profile
        local pack = p.packs[packName]
        local list = pack and pack.lists and pack.lists[listName]

        local actions = {
            -- Internal Handlers
            auto_attack = "自动攻击",
            auto_shot = "自动射击",
            call_action_list = "调用动作列表",
            cancel_action = "取消动作",
            cancel_aura = "取消光环",
            custom = "自定义",
            flask = "合剂",
            food = "食物",
            pause = "暂停",
            potion = "药水",
            run_action_list = "执行动作列表",
            snapshot_stats = "快照属性",
            start_moving = "开始移动",
            stop_moving = "停止移动",
            use_item = "使用物品",
            variable = "变量",
            wait = "等待"
        }

        -- Merge abilities from abilityList if available
        if class and class.abilityList then
            for k, v in pairs(class.abilityList) do
                if type(k) == 'string' and not actions[k] then
                    actions[k] = v
                end
            end
        end

        -- Fallback: Merge Abilities from class.abilities if abilityList is empty/missing
        if class and class.abilities then
            for k, v in pairs(class.abilities) do
                if type(k) == 'string' and not actions[k] then
                    actions[k] = v.name or k
                end
            end
        end

        -- Merge Items
        if class and class.items then
            for k, v in pairs(class.items) do
                if type(k) == 'string' and not actions[k] then
                    actions[k] = v.name or k
                end
            end
        end

        return actions
    end

    local function GetListEntry(pack)
        local entry = rawget(Hekili.DB.profile.packs, pack)

        if rawget(entry.lists, packControl.listName) == nil then
            packControl.listName = "default"
        end

        if entry then
            entry = entry.lists[packControl.listName]
        else
            return
        end

        if rawget(entry, tonumber(packControl.actionID)) == nil then
            packControl.actionID = "0001"
        end

        local listPos = tonumber(packControl.actionID)
        if entry and listPos > 0 then
            entry = entry[listPos]
        else
            return
        end

        return entry
    end

    function Hekili:GetActionOption(info)
        local n = #info
        local pack, option = info[2], info[n]

        if rawget(self.DB.profile.packs[pack].lists, packControl.listName) == nil then
            packControl.listName = "default"
        end

        local actionID = tonumber(packControl.actionID)
        local data = self.DB.profile.packs[pack].lists[packControl.listName]

        if option == 'position' then
            return actionID
        elseif option == 'newListName' then
            return packControl.newListName
        end

        if not data then
            return
        end

        if not data[actionID] then
            actionID = 1
            packControl.actionID = "0001"
        end
        data = data[actionID]

        if option == "inputName" or option == "selectName" then
            option = nameMap[data.action]
            if not data[option] then
                data[option] = defaultNames[option]
            end
        end

        if option == "op" and not data.op then
            return "set"
        end

        if option == "potion" then
            if not data.potion then
                return "default"
            end
            if not class.potionList[data.potion] then
                return class.potions[data.potion] and class.potions[data.potion].key or data.potion
            end
        end

        if toggleToNumber[option] then
            return data[option] == 1
        end
        return data[option]
    end

    -- Options to nil if val is false.
    local review_options = {
        enable_moving = 1,
        line_cd = 1,
        only_cwc = 1,
        strict = 1,
        strict_if = 1,
        use_off_gcd = 1,
        use_while_casting = 1
    }

    function Hekili:SetActionOption(info, val)
        local n = #info
        local pack, option = info[2], info[n]

        local actionID = tonumber(packControl.actionID)
        local data = self.DB.profile.packs[pack].lists[packControl.listName]

        if option == 'newListName' then
            packControl.newListName = val:trim()
            return
        end

        if not data then
            return
        end
        data = data[actionID]

        if option == "inputName" or option == "selectName" then
            option = nameMap[data.action]
        end

        if toggleToNumber[option] then
            if review_options[option] and not val then
                val = nil
            else
                val = val and 1 or 0
            end
        end
        if type(val) == 'string' then
            val = val:trim()
            if val:len() == 0 then
                val = nil
            end
        end

        if option == "caption" then
            val = val:gsub("||", "|")
        end

        data[option] = val

        if option == "use_while_casting" and not val then
            data.use_while_casting = nil
        end

        if option == "action" then
            self:LoadScripts()
        else
            self:LoadScript(pack, packControl.listName, actionID)
        end

        if option == "enabled" then
            Hekili:UpdateDisplayVisibility()
        end
    end

    function Hekili:GetPackOption(info)
        local n = #info
        local category, subcat, option = info[2], info[3], info[n]

        if rawget(self.DB.profile.packs, category) and
            rawget(self.DB.profile.packs[category].lists, packControl.listName) == nil then
            packControl.listName = "default"
        end

        if option == "newPackSpec" and packControl[option] == "" then
            packControl[option] = GetCurrentSpec()
        end

        if packControl[option] ~= nil then
            return packControl[option]
        end

        if subcat == 'lists' then
            return self:GetActionOption(info)
        end

        local data = rawget(self.DB.profile.packs, category)
        if not data then
            return
        end

        if option == 'date' then
            return tostring(data.date)
        end

        return data[option]
    end

    function Hekili:SetPackOption(info, val)
        local n = #info
        local category, subcat, option = info[2], info[3], info[n]

        if packControl[option] ~= nil then
            packControl[option] = val
            if option == "listName" then
                packControl.actionID = "0001"
            end
            return
        end

        if subcat == 'lists' then
            return self:SetActionOption(info, val)
        end
        -- if subcat == 'newActionGroup' or ( subcat == 'actionGroup' and subtype == 'entry' ) then self:SetActionOption( info, val ); return end

        local data = rawget(self.DB.profile.packs, category)
        if not data then
            return
        end

        if type(val) == 'string' then
            val = val:trim()
        end

        if option == "desc" then
            -- Auto-strip comments prefix
            val = val:gsub("^#+ ", "")
            val = val:gsub("\n#+ ", "\n")
        end

        data[option] = val
    end

    function Hekili:EmbedPackOptions(db)
        db = db or self.Options
        if not db then
            return
        end

        local packs = db.args.packs or {
            type = "group",
            name = "优先级配置",
            desc = "优先级配置（或指令集）是一组操作列表，基于每个职业专精提供技能推荐。",
            get = 'GetPackOption',
            set = 'SetPackOption',
            order = 65,
            childGroups = 'tree',
            args = {
                packDesc = {
                    type = "description",
                    name = "优先级配置（或指令集）是一组操作列表，基于每个职业专精提供技能推荐。" ..
                        "它们可以自定义和共享。|cFFFF0000导入SimulationCraft优先级通常需要在导入之前进行一些转换，" ..
                        "才能够应用于插件。不支持导入和自定义已过期的优先级配置。|r",
                    order = 1,
                    fontSize = "medium"
                },

                newPackHeader = {
                    type = "header",
                    name = "创建新的配置",
                    order = 200
                },

                newPackName = {
                    type = "input",
                    name = "配置名称",
                    desc = "输入唯一的配置名称。允许使用字母、数字、空格、下划线和撇号。（译者加入了中文支持）",
                    order = 201,
                    width = "full",
                    validate = function(info, val)
                        val = val:trim()
                        if rawget(Hekili.DB.profile.packs, val) then
                            return "请确保配置名称唯一。"
                        elseif val == "UseItems" then
                            return "UseItems是系统保留名称。"
                        elseif val == "(none)" then
                            return "别耍小聪明，你这愚蠢的土拨鼠。"
                        elseif val:find("[^a-zA-Z0-9 _'()一-龥]") then
                            return
                                "配置名称允许使用字母、数字、空格、下划线和撇号。（译者加入了中文支持）"
                        end
                        return true
                    end
                },

                newPackSpec = {
                    type = "select",
                    name = "职业专精",
                    order = 202,
                    width = "full",
                    values = specs
                },

                createNewPack = {
                    type = "execute",
                    name = "创建新配置",
                    order = 203,
                    disabled = function()
                        return packControl.newPackName == "" or packControl.newPackSpec == ""
                    end,
                    func = function()
                        Hekili.DB.profile.packs[packControl.newPackName].spec = packControl.newPackSpec
                        Hekili:EmbedPackOptions()
                        ACD:SelectGroup("Hekili", "packs", packControl.newPackName)
                        packControl.newPackName = ""
                        packControl.newPackSpec = ""
                    end
                },

                shareHeader = {
                    type = "header",
                    name = "分享",
                    order = 100
                },

                shareBtn = {
                    type = "execute",
                    name = "导入 / 导出",
                    desc = "优先级可通过编码字符串进行导入或导出。",
                    func = function()
                        ACD:SelectGroup("Hekili", "packs", "sharePacks")
                    end,
                    order = 101
                },

                sharePacks = {
                    type = "group",
                    name = "|cFF1EFF00导入 / 导出|r",
                    desc = "优先级可通过编码字符串进行导入或导出。",
                    childGroups = "tab",
                    get = 'GetPackShareOption',
                    set = 'SetPackShareOption',
                    order = 1001,
                    args = {
                        import = {
                            type = "group",
                            name = "导入",
                            order = 1,
                            args = {
                                stage0 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = "|cFFFF0000不提供对来自其他地方的自定义或导入优先级的支持。|r\n\n" ..
                                                "|cFF00CCFF插件中包含的默认优先级是最新的，与你的角色兼容，不需要额外的更改。|r\n\n" ..
                                                "在下方的文本框中粘贴优先级字符串开始导入。",
                                            order = 1,
                                            width = "full",
                                            fontSize = "medium"
                                        },

                                        separator = {
                                            type = "header",
                                            name = "导入字符串",
                                            order = 1.5
                                        },

                                        importString = {
                                            type = "input",
                                            name = "导入字符串",
                                            get = function()
                                                return shareDB.import
                                            end,
                                            set = function(info, val)
                                                val = val:trim()
                                                shareDB.import = val
                                            end,
                                            order = 3,
                                            multiline = 5,
                                            width = "full"
                                        },

                                        btnSeparator = {
                                            type = "header",
                                            name = "导入",
                                            order = 4
                                        },

                                        importBtn = {
                                            type = "execute",
                                            name = "导入优先级配置",
                                            order = 5,
                                            func = function()
                                                shareDB.imported, shareDB.error = DeserializeActionPack(shareDB.import)

                                                if shareDB.error then
                                                    shareDB.import =
                                                        "无法解析当前的导入字符串。\n" .. shareDB.error
                                                    shareDB.error = nil
                                                    shareDB.imported = {}
                                                else
                                                    shareDB.importStage = 1
                                                end
                                            end,
                                            disabled = function()
                                                return shareDB.import == ""
                                            end
                                        }
                                    },
                                    hidden = function()
                                        return shareDB.importStage ~= 0
                                    end
                                },

                                stage1 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 1,
                                    args = {
                                        packName = {
                                            type = "input",
                                            order = 1,
                                            name = "配置名称",
                                            get = function()
                                                return shareDB.imported.name
                                            end,
                                            set = function(info, val)
                                                shareDB.imported.name = val:trim()
                                            end,
                                            width = "full"
                                        },

                                        packDate = {
                                            type = "input",
                                            order = 2,
                                            name = "生成日期",
                                            get = function()
                                                return tostring(shareDB.imported.date)
                                            end,
                                            set = function()
                                            end,
                                            width = "full",
                                            disabled = true
                                        },
                                        packSpec = {
                                            type = "input",
                                            order = 3,
                                            name = "配置职业专精",
                                            get = function()
                                                if shareDB.imported.payload and shareDB.imported.payload.spec then
                                                    return select(2, GetSpecializationInfoByID(
                                                        shareDB.imported.payload.spec)) or "没有对应的职业专精"
                                                else
                                                    return "没有对应的职业专精"
                                                end
                                            end,
                                            set = function()
                                            end,
                                            width = "full",
                                            disabled = true
                                        },
                                        guide = {
                                            type = "description",
                                            name = function()
                                                local listNames = {}

                                                if shareDB.imported.payload and shareDB.imported.payload.lists then
                                                    for k, v in pairs(shareDB.imported.payload.lists) do
                                                        insert(listNames, k)
                                                    end
                                                end

                                                table.sort(listNames)

                                                local o

                                                if #listNames == 0 then
                                                    o = "导入的优先级配置不包含任何技能列表。"
                                                elseif #listNames == 1 then
                                                    o = "导入的优先级配置含有一个技能列表：" ..
                                                            listNames[1] .. "。"
                                                elseif #listNames == 2 then
                                                    o = "导入的优先级配置包含两个技能列表：" ..
                                                            listNames[1] .. " 和 " .. listNames[2] .. "。"
                                                else
                                                    o = "导入的优先级配置包含以下技能列表："
                                                    for i, name in ipairs(listNames) do
                                                        if i == 1 then
                                                            o = o .. name
                                                        elseif i == #listNames then
                                                            o = o .. ", 和 " .. name .. "."
                                                        else
                                                            o = o .. ", " .. name
                                                        end
                                                    end
                                                end

                                                return o
                                            end,
                                            order = 4,
                                            width = "full",
                                            fontSize = "medium"
                                        },

                                        separator = {
                                            type = "header",
                                            name = "应用更改",
                                            order = 10
                                        },
                                        apply = {
                                            type = "execute",
                                            name = "应用更改",
                                            order = 11,
                                            confirm = function()
                                                if rawget(self.DB.profile.packs, shareDB.imported.name) then
                                                    return "你已经拥有名为“" .. shareDB.imported.name ..
                                                               "”的优先级配置。\n覆盖它吗？"
                                                end
                                                return "确定从导入的数据创建名为“" ..
                                                           shareDB.imported.name .. "”的优先级配置吗？"
                                            end,
                                            func = function()
                                                if shareDB.imported.payload then
                                                    self.DB.profile.packs[shareDB.imported.name] = shareDB.imported
                                                                                                       .payload
                                                    shareDB.imported.payload.date = shareDB.imported.date
                                                    shareDB.imported.payload.version = shareDB.imported.date
                                                end

                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 2

                                                self:LoadScripts()
                                                self:EmbedPackOptions()
                                            end,
                                            disabled = function()
                                                return not shareDB.imported.payload
                                            end
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 12,
                                            func = function()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end
                                        }
                                    },
                                    hidden = function()
                                        return shareDB.importStage ~= 1
                                    end
                                },

                                stage2 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    args = {
                                        note = {
                                            type = "description",
                                            name = "导入的设置已经成功应用！\n\n如果有必要，点击重置重新开始。",
                                            order = 1,
                                            fontSize = "medium",
                                            width = "full"
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 2,
                                            func = function()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end
                                        }
                                    },
                                    hidden = function()
                                        return shareDB.importStage ~= 2
                                    end
                                }
                            },
                            plugins = {}
                        },

                        export = {
                            type = "group",
                            name = "导出",
                            order = 2,
                            args = {
                                guide = {
                                    type = "description",
                                    name = "请选择要导出的优先级配置。",
                                    order = 1,
                                    fontSize = "medium",
                                    width = "full"
                                },

                                actionPack = {
                                    type = "select",
                                    name = "优先级配置",
                                    order = 2,
                                    values = function()
                                        local v = {}
                                        for k, pack in pairs(Hekili.DB.profile.packs) do
                                            if pack.spec and class and class.specs and class.specs[pack.spec] then
                                                v[k] = k
                                            end
                                        end

                                        return v
                                    end,
                                    width = "full"
                                },

                                exportString = {
                                    type = "input",
                                    name = "导出优先级配置字符串",
                                    desc = "按CTRL+A全选，然后CTRL+C复制",
                                    order = 3,
                                    get = function()
                                        if rawget(Hekili.DB.profile.packs, shareDB.actionPack) then
                                            shareDB.export = SerializeActionPack(shareDB.actionPack)
                                        else
                                            shareDB.export = ""
                                        end
                                        return shareDB.export
                                    end,
                                    set = function()
                                    end,
                                    width = "full",
                                    hidden = function()
                                        return shareDB.export == ""
                                    end
                                }
                            }
                        }
                    }
                }
            },
            plugins = {
                packages = {},
                links = {}
            }
        }

        wipe(packs.plugins.packages)
        wipe(packs.plugins.links)

        local count = 0
        for pack, data in orderedPairs(self.DB.profile.packs) do
            if data.spec and class and class.specs and class.specs[data.spec] and not data.hidden then
                packs.plugins.links.packButtons = packs.plugins.links.packButtons or {
                    type = "header",
                    name = "已安装的配置",
                    order = 10
                }

                packs.plugins.links["btn" .. pack] = {
                    type = "execute",
                    name = pack,
                    order = 11 + count,
                    func = function()
                        ACD:SelectGroup("Hekili", "packs", pack)
                    end
                }

                local opts = packs.plugins.packages[pack] or {
                    type = "group",
                    name = function()
                        local p = rawget(Hekili.DB.profile.packs, pack)
                        if p.builtIn then
                            return '|cFF00B4FF' .. pack .. '|r'
                        end
                        return pack
                    end,
                    icon = function()
                        return GetSpecTextureByID(data.spec)
                    end,
                    iconCoords = {0.15, 0.85, 0.15, 0.85},
                    childGroups = "tab",
                    order = 100 + count,
                    args = {
                        pack = {
                            type = "group",
                            name = data.builtIn and (BlizzBlue .. "摘要|r") or "摘要",
                            order = 1,
                            args = {
                                isBuiltIn = {
                                    type = "description",
                                    name = function()
                                        return BlizzBlue ..
                                                   "这是个默认的优先级配置。当插件更新时，它将会自动更新。" ..
                                                   "如果想要自定义调整技能优先级，请点击|TInterface\\Addons\\Hekili\\Textures\\WhiteCopy:0|t创建一个副本后操作|r。"
                                    end,
                                    fontSize = "medium",
                                    width = 3,
                                    order = 0.1,
                                    hidden = not data.builtIn
                                },

                                lb01 = {
                                    type = "description",
                                    name = "",
                                    order = 0.11,
                                    hidden = not data.builtIn
                                },

                                toggleActive = {
                                    type = "toggle",
                                    name = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        if p and p.builtIn then
                                            return BlizzBlue .. "激活|r"
                                        end
                                        return "激活"
                                    end,
                                    desc = "如果勾选，插件将会在职业专精对应时使用该优先级配置进行技能推荐。",
                                    order = 0.2,
                                    width = 3,
                                    get = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        -- 添加空值检查，防止访问不存在的专精
                                        local specConfig = p and Hekili.DB.profile.specs and
                                                               Hekili.DB.profile.specs[p.spec]
                                        return specConfig and specConfig.package == pack
                                    end,
                                    set = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        -- 添加空值检查，确保专精配置存在
                                        if not p or not Hekili.DB.profile.specs then
                                            return
                                        end

                                        -- 确保专精配置表存在
                                        if not Hekili.DB.profile.specs[p.spec] then
                                            Hekili.DB.profile.specs[p.spec] = {}
                                        end

                                        if Hekili.DB.profile.specs[p.spec].package == pack then
                                            if p.builtIn then
                                                Hekili.DB.profile.specs[p.spec].package = "(none)"
                                            else
                                                for def, data in pairs(Hekili.DB.profile.packs) do
                                                    if data.spec == p.spec and data.builtIn then
                                                        Hekili.DB.profile.specs[p.spec].package = def
                                                        return
                                                    end
                                                end
                                            end
                                        else
                                            Hekili.DB.profile.specs[p.spec].package = pack
                                        end
                                    end
                                },

                                lb04 = {
                                    type = "description",
                                    name = "",
                                    order = 0.21,
                                    width = "full"
                                },

                                packName = {
                                    type = "input",
                                    name = "配置名称",
                                    order = 0.25,
                                    width = 2.7,
                                    validate = function(info, val)
                                        val = val:trim()
                                        if rawget(Hekili.DB.profile.packs, val) then
                                            return "请确保配置名称唯一。"
                                        elseif val == "UseItems" then
                                            return "UseItems是系统保留名称。"
                                        elseif val == "(none)" then
                                            return "别耍小聪明，你这愚蠢的土拨鼠。"
                                        elseif val:find("[^a-zA-Z0-9 _'()一-龥]") then
                                            return
                                                "配置名称允许使用字母、数字、空格、下划线和撇号。（译者加入了中文支持）"
                                        end
                                        return true
                                    end,
                                    get = function()
                                        return pack
                                    end,
                                    set = function(info, val)
                                        local profile = Hekili.DB.profile

                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        Hekili.DB.profile.packs[pack] = nil

                                        val = val:trim()
                                        Hekili.DB.profile.packs[val] = p

                                        for _, spec in pairs(Hekili.DB.profile.specs) do
                                            if spec.package == pack then
                                                spec.package = val
                                            end
                                        end

                                        Hekili:EmbedPackOptions()
                                        Hekili:LoadScripts()
                                        ACD:SelectGroup("Hekili", "packs", val)
                                    end,
                                    disabled = data.builtIn
                                },

                                copyPack = {
                                    type = "execute",
                                    name = "",
                                    desc = "拷贝配置",
                                    order = 0.26,
                                    width = 0.15,
                                    image = "Interface\\AddOns\\Hekili\\Textures\\WhiteCopy",
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    confirm = function()
                                        return "确定创建此优先级配置的副本吗？"
                                    end,
                                    func = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)

                                        local newPack = tableCopy(p)
                                        newPack.builtIn = false
                                        newPack.basedOn = pack

                                        local newPackName, num = pack:match("^(.+) %((%d+)%)$")

                                        if not num then
                                            newPackName = pack
                                            num = 1
                                        end

                                        num = num + 1
                                        while (rawget(Hekili.DB.profile.packs, newPackName .. " (" .. num .. ")")) do
                                            num = num + 1
                                        end
                                        newPackName = newPackName .. " (" .. num .. ")"

                                        Hekili.DB.profile.packs[newPackName] = newPack
                                        Hekili:EmbedPackOptions()
                                        Hekili:LoadScripts()
                                        ACD:SelectGroup("Hekili", "packs", newPackName)
                                    end
                                },

                                reloadPack = {
                                    type = "execute",
                                    name = "",
                                    desc = "重载配置",
                                    order = 0.27,
                                    width = 0.15,
                                    image = "Interface\\AddOns\\Hekili\\Textures\\WhiteReset",
                                    imageWidth = 25,
                                    imageHeight = 24,
                                    confirm = function()
                                        return "确定从默认值重载此优先级配置吗？"
                                    end,
                                    hidden = not data.builtIn,
                                    func = function()
                                        Hekili.DB.profile.packs[pack] = nil
                                        Hekili:RestoreDefault(pack)
                                        Hekili:EmbedPackOptions()
                                        Hekili:LoadScripts()
                                        ACD:SelectGroup("Hekili", "packs", pack)
                                    end
                                },

                                deletePack = {
                                    type = "execute",
                                    name = "",
                                    desc = "删除配置",
                                    order = 0.27,
                                    width = 0.15,
                                    image = "Interface\\AddOns\\Hekili\\Textures\\RedX",
                                    imageHeight = 24,
                                    imageWidth = 24,
                                    confirm = function()
                                        return "确定删除此优先级配置吗？"
                                    end,
                                    func = function()
                                        local defPack

                                        local specId = data.spec
                                        local spec = specId and Hekili.DB.profile.specs[specId]

                                        if specId then
                                            for pId, pData in pairs(Hekili.DB.profile.packs) do
                                                if pData.builtIn and pData.spec == specId then
                                                    defPack = pId
                                                    if spec.package == pack then
                                                        spec.package = pId
                                                        break
                                                    end
                                                end
                                            end
                                        end

                                        Hekili.DB.profile.packs[pack] = nil
                                        Hekili.Options.args.packs.plugins.packages[pack] = nil

                                        -- Hekili:EmbedPackOptions()
                                        ACD:SelectGroup("Hekili", "packs")
                                    end,
                                    hidden = function()
                                        return data.builtIn and not Hekili.Version:sub(1, 3) == "Dev"
                                    end
                                },

                                lb02 = {
                                    type = "description",
                                    name = "",
                                    order = 0.3,
                                    width = "full"
                                },

                                spec = {
                                    type = "select",
                                    name = "对应职业专精",
                                    order = 1,
                                    width = 3,
                                    values = specs,
                                    disabled = data.builtIn and not Hekili.Version:sub(1, 3) == "Dev"
                                },

                                lb03 = {
                                    type = "description",
                                    name = "",
                                    order = 1.01,
                                    width = "full",
                                    hidden = data.builtIn
                                },

                                desc = {
                                    type = "input",
                                    name = "说明",
                                    multiline = 15,
                                    order = 2,
                                    width = "full"
                                }
                            }
                        },

                        profile = {
                            type = "group",
                            name = "文件",
                            desc = "如果此优先级配置是通过SimulationCraft配置文件生成的，则可以在这里保存和查看该配置文件。" ..
                                "还可以重新导入该配置文件，或使用较新的文件覆盖旧的文件。",
                            order = 2,
                            args = {
                                signature = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    args = {
                                        source = {
                                            type = "input",
                                            name = "来源",
                                            desc = "如果优先级配置基于SimulationCraft文件或职业指南，" ..
                                                "最好提供来源的链接（尤其是分享之前）。",
                                            order = 1,
                                            width = 3
                                        },

                                        break1 = {
                                            type = "description",
                                            name = "",
                                            width = "full",
                                            order = 1.1
                                        },

                                        author = {
                                            type = "input",
                                            name = "作者",
                                            desc = "创建新的优先级配置时，作业信息将自动填写。" ..
                                                "你可以在这里修改作者信息。",
                                            order = 2,
                                            width = 2
                                        },

                                        date = {
                                            type = "input",
                                            name = "最后更新",
                                            desc = "调整此优先级配置的技能列表时，此日期将自动更新。",
                                            width = 1,
                                            order = 3,
                                            set = function()
                                            end,
                                            get = function()
                                                local d = data.date or 0

                                                if type(d) == "string" then
                                                    return d
                                                end
                                                return format("%.4f", d)
                                            end
                                        }
                                    }
                                },

                                profile = {
                                    type = "input",
                                    name = "文件",
                                    desc = "如果此优先级配置的技能列表是来自于SimulationCraft文件的，那么该文件就在这里。",
                                    order = 4,
                                    multiline = 10,
                                    confirm = true,
                                    confirmText = "直到点击导入按钮，更改才会被应用",
                                    width = "full"
                                },

                                profilewarning = {
                                    type = "description",
                                    name = "|cFFFF0000你不需要导入一个SimulationCraft配置文件来使用这个插件。不提供对来自其他地方的自定义或导入优先级的支持。|r\n\n" ..
                                        "|cFF00CCFF插件中包含的默认优先级是最新的，与你的角色兼容，并且不需要额外的更改。|r\n\n",
                                    order = 2.1,
                                    fontSize = "medium",
                                    width = "full"
                                },

                                reimport = {
                                    type = "execute",
                                    name = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        if p.spec ~= state.spec.id then
                                            return "|A:UI-LFG-DeclineMark:16:16|a 导入"
                                        end
                                        return format("%s导入",
                                            p.spec ~= state.spec.id and "|A:UI-LFG-DeclineMark:16:16|a" or "")
                                    end,
                                    desc = "清除现有的指令列表，并加载上一个优先级。",
                                    order = 5.1,
                                    width = 0.7,
                                    func = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        local profile = p.profile:gsub('"', '')

                                        local result, warnings = Hekili:ImportSimcAPL(nil, nil, profile)

                                        wipe(p.lists)

                                        for k, v in pairs(result) do
                                            p.lists[k] = v
                                        end

                                        p.warnings = warnings
                                        p.date = tonumber(date("%Y%m%d.%H%M%S"))

                                        if not p.lists[packControl.listName] then
                                            packControl.listName = "default"
                                        end

                                        local id = tonumber(packControl.actionID)
                                        if not p.lists[packControl.listName][id] then
                                            packControl.actionID = "zzzzzzzzzz"
                                        end

                                        self:LoadScripts()
                                    end,
                                    disabled = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        -- Removed spec check for MoP Classic - allow all imports
                                        return false
                                    end
                                },
                                importWarningSpace = {
                                    type = "description",
                                    name = " ",
                                    width = 0.1,
                                    order = 5.11
                                },
                                importWarning = {
                                    type = "description",
                                    name = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        if class and class.specs and p and p.spec and class.specs[p.spec] then
                                            local spec = class.specs[p.spec]
                                            local texture = spec.texture or 136012
                                            local name = spec.name or "未知"
                                            return format(
                                                "你必须处于 |T%d:0|t |cFFFFD100%s|r 专精才能导入此优先级。",
                                                texture, name)
                                        else
                                            -- Debug information
                                            local debugInfo = ""
                                            if p and p.spec then
                                                debugInfo = debugInfo .. " Priority spec: " .. tostring(p.spec)
                                            end
                                            if state and state.spec and state.spec.id then
                                                debugInfo = debugInfo .. " Current spec: " .. tostring(state.spec.id)
                                            end
                                            if class and class.specs then
                                                local specExists = class.specs[p and p.spec] ~= nil
                                                debugInfo = debugInfo .. " Spec exists: " .. tostring(specExists)
                                            end
                                            return "你必须处于对应的专精才能导入此优先级。" ..
                                                       debugInfo
                                        end
                                    end,
                                    image = GetAtlasFile("Ping_Chat_Warning"),
                                    imageCoords = GetAtlasCoords("Ping_Chat_Warning"),
                                    fontSize = "medium",
                                    width = 2.2,
                                    order = 5.12,
                                    hidden = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        -- Removed spec check for MoP Classic - hide warning
                                        return true
                                    end
                                },
                                profileConsiderations = {
                                    type = "description",
                                    name = "\n|cFF00CCFF在尝试导入配置文件前，请检查以下几点：|r\n\n" ..
                                        " |cFFFFD100•|r SimulationCraft 的指令列表对于单个角色来说通常不会有显著变化。这些配置文件在编写时适配了所有装备、天赋和其他综合因素的条件。\n\n" ..
                                        " |cFFFFD100•|r 大多数 SimulationCraft 的指令列表需要进行一些额外的自定义设置才能与该插件配合使用。例如，|cFFFFD100target_if|r 不能直接转换到插件中，必须重新编写。\n\n" ..
                                        " |cFFFFD100•|r 为了使某些 SimulationCraft的指令列表更加高效，已经对其进行修正。\n\n" ..
                                        " |cFFFFD100•|r 此功能是为喜欢钻研和高级用户保留的。\n\n",
                                    order = 5,
                                    fontSize = "medium",
                                    width = "full"
                                },
                                warnings = {
                                    type = "input",
                                    name = "导入记录",
                                    order = 5.3,
                                    width = "full",
                                    multiline = 20,
                                    hidden = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        return not p.warnings or p.warnings == ""
                                    end
                                }
                            }
                        },

                        lists = {
                            type = "group",
                            childGroups = "select",
                            name = "技能列表",
                            desc = "技能列表用于确定在合适的时机推荐使用正确的技能。",
                            order = 3,
                            args = {
                                listName = {
                                    type = "select",
                                    name = "技能列表",
                                    desc = "选择要查看或修改的技能列表。",
                                    order = 1,
                                    width = 2.7,
                                    values = function()
                                        local v = {
                                            -- ["zzzzzzzzzz"] = "|cFF00FF00增加新的指令列表|r"
                                        }

                                        local p = rawget(Hekili.DB.profile.packs, pack)

                                        for k in pairs(p.lists) do
                                            local err = false

                                            if Hekili.Scripts and Hekili.Scripts.DB then
                                                local scriptHead = "^" .. pack .. ":" .. k .. ":"
                                                for k, v in pairs(Hekili.Scripts.DB) do
                                                    if k:match(scriptHead) and v.Error then
                                                        err = true
                                                        break
                                                    end
                                                end
                                            end

                                            if err then
                                                v[k] = "|cFFFF0000" .. k .. "|r"
                                            elseif k == 'precombat' or k == 'default' then
                                                v[k] = "|cFF00B4FF" .. k .. "|r"
                                            else
                                                v[k] = k
                                            end
                                        end

                                        return v
                                    end
                                },

                                newListBtn = {
                                    type = "execute",
                                    name = "",
                                    desc = "创建新的技能列表",
                                    order = 1.1,
                                    width = 0.15,
                                    image = "Interface\\AddOns\\Hekili\\Textures\\GreenPlus",
                                    -- image = GetAtlasFile( "communities-icon-addgroupplus" ),
                                    -- imageCoords = GetAtlasCoords( "communities-icon-addgroupplus" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    func = function()
                                        packControl.makingNew = true
                                    end
                                },

                                delListBtn = {
                                    type = "execute",
                                    name = "",
                                    desc = "删除当前技能列表",
                                    order = 1.2,
                                    width = 0.15,
                                    image = RedX,
                                    -- image = GetAtlasFile( "common-icon-redx" ),
                                    -- imageCoords = GetAtlasCoords( "common-icon-redx" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    confirm = function()
                                        return "确定删除这个技能列表吗？"
                                    end,
                                    disabled = function()
                                        return packControl.listName == "default" or packControl.listName == "precombat"
                                    end,
                                    func = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        p.lists[packControl.listName] = nil
                                        Hekili:LoadScripts()
                                        packControl.listName = "default"
                                    end
                                },

                                lineBreak = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 1.9
                                },

                                actionID = {
                                    type = "select",
                                    name = "项目",
                                    desc = "在此技能列表中选择要修改的项目。\n\n" ..
                                        "红色项目表示被禁用、没有技能列表、条件错误或执行指令被禁用/忽略的技能。",
                                    order = 2,
                                    width = 2.4,
                                    values = function()
                                        local v = {}

                                        local data = rawget(Hekili.DB.profile.packs, pack)
                                        local list = rawget(data.lists, packControl.listName)

                                        if list then
                                            local last = 0

                                            for i, entry in ipairs(list) do
                                                local key = format("%04d", i)
                                                local action = entry.action
                                                local desc

                                                local warning, color = false, nil

                                                if not action then
                                                    action = "Unassigned"
                                                    warning = true
                                                else
                                                    if not class.abilities[action] then
                                                        warning = true
                                                    else
                                                        if action == "trinket1" or action == "trinket2" or action ==
                                                            "main_hand" then
                                                            local passthru = "actual_" .. action
                                                            if state:IsDisabled(passthru, true) then
                                                                warning = true
                                                            end
                                                            action =
                                                                class.abilityList[passthru] and
                                                                    class.abilityList[passthru] or
                                                                    class.abilities[passthru] and
                                                                    class.abilities[passthru].name or action
                                                        else
                                                            if state:IsDisabled(action, true) then
                                                                warning = true
                                                            end
                                                            action = class.abilityList[action] and
                                                                         class.abilityList[action]:match("|t (.+)$") or
                                                                         class.abilities[action] and
                                                                         class.abilities[action].name or action
                                                        end
                                                    end
                                                end

                                                local scriptID = pack .. ":" .. packControl.listName .. ":" .. i
                                                local script = Hekili.Scripts.DB[scriptID]

                                                if script and script.Error then
                                                    warning = true
                                                end

                                                local cLen = entry.criteria and entry.criteria:len()

                                                if entry.caption and entry.caption:len() > 0 then
                                                    desc = entry.caption
                                                elseif entry.action == "variable" then
                                                    if entry.op == "reset" then
                                                        desc =
                                                            format("重置 |cff00ccff%s|r",
                                                                entry.var_name or "unassigned")
                                                    elseif entry.op == "default" then
                                                        desc =
                                                            format("|cff00ccff%s|r 默认 = |cffffd100%s|r",
                                                                entry.var_name or "unassigned", entry.value or "0")
                                                    elseif entry.op == "set" or entry.op == "setif" then
                                                        desc =
                                                            format("设置 |cff00ccff%s|r = |cffffd100%s|r",
                                                                entry.var_name or "unassigned", entry.value or "nothing")
                                                    else
                                                        desc =
                                                            format("%s |cff00ccff%s|r (|cffffd100%s|r)",
                                                                entry.op or "set", entry.var_name or "unassigned",
                                                                entry.value or "nothing")
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = format("%s, 是 |cffffd100%s|r", desc, entry.criteria)
                                                    end
                                                elseif entry.action == "call_action_list" or entry.action ==
                                                    "run_action_list" then
                                                    if not entry.list_name or not rawget(data.lists, entry.list_name) then
                                                        desc = "|cff00ccff(未设置)|r"
                                                        warning = true
                                                    else
                                                        desc = "|cff00ccff" .. entry.list_name .. "|r"
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = desc .. ", 是 |cffffd100" .. entry.criteria .. "|r"
                                                    end
                                                elseif entry.action == "cancel_buff" then
                                                    if not entry.buff_name then
                                                        desc = "|cff00ccff(未设置)|r"
                                                        warning = true
                                                    else
                                                        local a = class.auras[entry.buff_name]

                                                        if a then
                                                            desc = "|cff00ccff" .. a.name .. "|r"
                                                        else
                                                            desc = "|cff00ccff(未找到)|r"
                                                            warning = true
                                                        end
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = desc .. ", 如果 |cffffd100" .. entry.criteria .. "|r"
                                                    end
                                                elseif entry.action == "cancel_action" then
                                                    if not entry.action_name then
                                                        desc = "|cff00ccff(未设置)|r"
                                                        warning = true
                                                    else
                                                        local a = class.abilities[entry.action_name]

                                                        if a then
                                                            desc = "|cff00ccff" .. a.name .. "|r"
                                                        else
                                                            desc = "|cff00ccff(未找到)|r"
                                                            warning = true
                                                        end
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = desc .. ", 如果 |cffffd100" .. entry.criteria .. "|r"
                                                    end
                                                elseif cLen and cLen > 0 then
                                                    desc = "|cffffd100" .. entry.criteria .. "|r"
                                                end

                                                if not entry.enabled then
                                                    warning = true
                                                    color = "|cFF808080"
                                                end

                                                if desc then
                                                    desc = desc:gsub("[\r\n]", "")
                                                end

                                                if not color then
                                                    color = warning and "|cFFFF0000" or "|cFFFFD100"
                                                end

                                                if entry.empower_to then
                                                    if entry.empower_to == "max_empower" then
                                                        action = action .. "(Max)"
                                                    else
                                                        action = action .. " (" .. entry.empower_to .. ")"
                                                    end
                                                end

                                                if desc then
                                                    v[key] =
                                                        color .. i .. ".|r " .. action .. " - " .. "|cFFFFD100" .. desc ..
                                                            "|r"
                                                else
                                                    v[key] = color .. i .. ".|r " .. action
                                                end

                                                last = i + 1
                                            end
                                        end

                                        return v
                                    end,
                                    hidden = function()
                                        return packControl.makingNew == true
                                    end
                                },

                                moveUpBtn = {
                                    type = "execute",
                                    name = "",
                                    image = "Interface\\AddOns\\Hekili\\Textures\\WhiteUp",
                                    -- image = GetAtlasFile( "hud-MainMenuBar-arrowup-up" ),
                                    -- imageCoords = GetAtlasCoords( "hud-MainMenuBar-arrowup-up" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.1,
                                    func = function(info)
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        local data = p.lists[packControl.listName]
                                        local actionID = tonumber(packControl.actionID)

                                        local a = remove(data, actionID)
                                        insert(data, actionID - 1, a)
                                        packControl.actionID = format("%04d", actionID - 1)

                                        local listName = format("%s:%s:", pack, packControl.listName)
                                        scripts:SwapScripts(listName .. actionID, listName .. (actionID - 1))
                                    end,
                                    disabled = function()
                                        return tonumber(packControl.actionID) == 1
                                    end,
                                    hidden = function()
                                        return packControl.makingNew
                                    end
                                },

                                moveDownBtn = {
                                    type = "execute",
                                    name = "",
                                    image = "Interface\\AddOns\\Hekili\\Textures\\WhiteDown",
                                    -- image = GetAtlasFile( "hud-MainMenuBar-arrowdown-up" ),
                                    -- imageCoords = GetAtlasCoords( "hud-MainMenuBar-arrowdown-up" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.2,
                                    func = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        local data = p.lists[packControl.listName]
                                        local actionID = tonumber(packControl.actionID)

                                        local a = remove(data, actionID)
                                        insert(data, actionID + 1, a)
                                        packControl.actionID = format("%04d", actionID + 1)

                                        local listName = format("%s:%s:", pack, packControl.listName)
                                        scripts:SwapScripts(listName .. actionID, listName .. (actionID + 1))
                                    end,
                                    disabled = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        return not p.lists[packControl.listName] or tonumber(packControl.actionID) ==
                                                   #p.lists[packControl.listName]
                                    end,
                                    hidden = function()
                                        return packControl.makingNew
                                    end
                                },

                                newActionBtn = {
                                    type = "execute",
                                    name = "",
                                    image = "Interface\\AddOns\\Hekili\\Textures\\GreenPlus",
                                    -- image = GetAtlasFile( "communities-icon-addgroupplus" ),
                                    -- imageCoords = GetAtlasCoords( "communities-icon-addgroupplus" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.3,
                                    func = function()
                                        local data = rawget(self.DB.profile.packs, pack)
                                        if data then
                                            insert(data.lists[packControl.listName], {{}})
                                            packControl.actionID = format("%04d", #data.lists[packControl.listName])
                                        else
                                            packControl.actionID = "0001"
                                        end
                                    end,
                                    hidden = function()
                                        return packControl.makingNew
                                    end
                                },

                                delActionBtn = {
                                    type = "execute",
                                    name = "",
                                    image = RedX,
                                    -- image = GetAtlasFile( "common-icon-redx" ),
                                    -- imageCoords = GetAtlasCoords( "common-icon-redx" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.4,
                                    confirm = function()
                                        return "确定删除这个项目吗？"
                                    end,
                                    func = function()
                                        local id = tonumber(packControl.actionID)
                                        local p = rawget(Hekili.DB.profile.packs, pack)

                                        remove(p.lists[packControl.listName], id)

                                        if not p.lists[packControl.listName][id] then
                                            id = id - 1
                                            packControl.actionID = format("%04d", id)
                                        end
                                        if not p.lists[packControl.listName][id] then
                                            packControl.actionID = "zzzzzzzzzz"
                                        end

                                        self:LoadScripts()
                                    end,
                                    disabled = function()
                                        local p = rawget(Hekili.DB.profile.packs, pack)
                                        return not p.lists[packControl.listName] or #p.lists[packControl.listName] < 2
                                    end,
                                    hidden = function()
                                        return packControl.makingNew
                                    end
                                },

                                enabled = {
                                    type = "toggle",
                                    name = "启用",
                                    desc = "如果禁用，即使满足条件也不会显示此项。",
                                    order = 3.0,
                                    width = "full"
                                },

                                action = {
                                    type = "select",
                                    name = "指令（技能）",
                                    desc = "选择满足项目条件时推荐进行的操作指令。",
                                    values = function()
                                        local list = {""}
                                        local bypass = {
                                            trinket1 = actual_trinket1,
                                            trinket2 = actual_trinket2,
                                            main_hand = actual_main_hand
                                        }

                                        -- Add internal handlers first
                                        local internalHandlers = {
                                            auto_attack = "自动攻击",
                                            auto_shot = "自动射击",
                                            call_action_list = "调用动作列表",
                                            cancel_action = "取消动作",
                                            cancel_aura = "取消光环",
                                            custom = "自定义",
                                            flask = "合剂",
                                            food = "食物",
                                            pause = "暂停",
                                            potion = "药水",
                                            run_action_list = "执行动作列表",
                                            snapshot_stats = "快照属性",
                                            start_moving = "开始移动",
                                            stop_moving = "停止移动",
                                            use_item = "使用物品",
                                            variable = "变量",
                                            wait = "等待"
                                        }

                                        for k, v in pairs(internalHandlers) do
                                            list[k] = v
                                        end

                                        -- Add abilities from abilityList if available
                                        if class and class.abilityList then
                                            for k, v in pairs(class.abilityList) do
                                                if not list[k] then -- Don't overwrite internal handlers
                                                    list[k] = bypass[k] or v
                                                end
                                            end
                                        end

                                        -- Fallback: add abilities from class.abilities if abilityList is empty/missing
                                        if class and class.abilities then
                                            for k, v in pairs(class.abilities) do
                                                if type(k) == "string" and not list[k] then
                                                    list[k] = bypass[k] or v.name or k
                                                end
                                            end
                                        end

                                        return list
                                    end,
                                    sorting = function(a, b)
                                        local list = {}

                                        for k in pairs(class.abilityList) do
                                            insert(list, k)
                                        end

                                        local bypass = {
                                            trinket1 = actual_trinket1,
                                            trinket2 = actual_trinket2,
                                            main_hand = actual_main_hand
                                        }

                                        -- 先创建结果表
                                        local result = {}

                                        -- 先搜索：根据搜索条件过滤技能
                                        if search_out and not Hekili.Trans.isChinese(search_out) then
                                            -- 非中文搜索：精确匹配键
                                            for k, v in pairs(class.abilityList) do
                                                if k == search_out then
                                                    result[k] = bypass[k] or v
                                                end
                                            end
                                        elseif search_out and Hekili.Trans.isChinese(search_out) then
                                            -- 中文搜索：模糊匹配值
                                            for k, v in pairs(class.abilityList) do
                                                if v and string.find(v, search_out) then
                                                    result[k] = bypass[k] or v
                                                end
                                            end
                                        else
                                            -- 无搜索：返回所有项
                                            for k, v in pairs(class.abilityList) do
                                                result[k] = bypass[k] or v
                                            end
                                        end

                                        -- 后排序：将结果表的键放入列表并排序
                                        list = {}
                                        for k in pairs(result) do
                                            insert(list, k)
                                        end

                                        sort(list, function(a, b)
                                            local aName =
                                                result[a] or (class.abilities[a] and class.abilities[a].name) or a
                                            local bName =
                                                result[b] or (class.abilities[b] and class.abilities[b].name) or b
                                            if aName ~= nil and type(aName.name) == "string" then
                                                aName = aName.name
                                            end
                                            if bName ~= nil and type(bName.name) == "string" then
                                                bName = bName.name
                                            end
                                            return aName < bName
                                        end)

                                        return list
                                    end,
                                    order = 3.1,
                                    width = 1.5
                                },
                                search_input = {
                                    type = "input",
                                    name = "技能搜索",
                                    desc = "输入技能名称或部分，进行搜索。\n可能遇到搜索不到的情况，这是正常的，手动翻找一下。",
                                    get = function()
                                        return search_in
                                    end,
                                    set = function(info, val)
                                        search_in = val
                                        search_out =
                                            Hekili.Trans.isChinese(val) and val or Hekili.Trans.transSpell(val) or val
                                    end,
                                    order = 3.15,
                                    width = 1.3
                                },

                                list_name = {
                                    type = "select",
                                    name = "技能列表",
                                    values = function()
                                        local e = GetListEntry(pack)
                                        local v = {}

                                        local p = rawget(Hekili.DB.profile.packs, pack)

                                        for k in pairs(p.lists) do
                                            if k ~= packControl.listName then
                                                if k == 'precombat' or k == 'default' then
                                                    v[k] = "|cFF00B4FF" .. k .. "|r"
                                                else
                                                    v[k] = k
                                                end
                                            end
                                        end

                                        return v
                                    end,
                                    order = 3.2,
                                    width = 1.5,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return not (e.action == "call_action_list" or e.action == "run_action_list")
                                    end
                                },

                                buff_name = {
                                    type = "select",
                                    name = "Buff名称",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "选择要取消的Buff。",
                                    values = class.auraList,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "cancel_buff"
                                    end
                                },

                                action_name = {
                                    type = "select",
                                    name = "指令名称",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "设定要取消的指令。插件将立即停止该指令的后续操作",
                                    values = class.abilityList,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "cancel_action"
                                    end
                                },

                                potion = {
                                    type = "select",
                                    name = "药剂",
                                    order = 3.2,
                                    -- width = "full",
                                    values = class.potionList,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "potion"
                                    end,
                                    width = 1.5
                                },

                                sec = {
                                    type = "input",
                                    name = "秒",
                                    order = 3.2,
                                    width = 1.5,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "wait"
                                    end
                                },

                                max_energy = {
                                    type = "toggle",
                                    name = "最大连击点数",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "勾选后此项后，将要求玩家有足够大的连击点数激发凶猛撕咬的全部伤害加成。",
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "ferocious_bite"
                                    end
                                },

                                empower_to = {
                                    type = "select",
                                    name = "蓄力到",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "对于蓄力技能，指定其使用的蓄力等级（默认为最大）。",
                                    values = {
                                        [1] = "I",
                                        [2] = "II",
                                        [3] = "III",
                                        [4] = "IV",
                                        max_empower = "最大"
                                    },
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local action = e.action
                                        local ability = action and class.abilities[action]
                                        return not (ability and ability.empowered)
                                    end
                                },

                                lb00 = {
                                    type = "description",
                                    name = "",
                                    order = 3.201,
                                    width = "full"
                                },

                                caption = {
                                    type = "input",
                                    name = "标题",
                                    desc = "标题是出现在推荐技能图标上的|cFFFF0000简短|r的描述。\n\n" ..
                                        "这样做有助于理解为什么在此刻推荐这个技能。\n\n" ..
                                        "需要在每个显示框架上启用。",
                                    order = 3.202,
                                    width = 1.5,
                                    validate = function(info, val)
                                        val = val:trim()
                                        val = val:gsub("||", "|"):gsub("|T.-:0|t", "") -- Don't count icons.
                                        if val:len() > 20 then
                                            return "标题文本应等于或少于20个字符。"
                                        end
                                        return true
                                    end,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local ability = e.action and class.abilities[e.action]

                                        return not ability or (ability.id < 0 and ability.id > -10)
                                    end
                                },

                                description = {
                                    type = "input",
                                    name = "说明",
                                    desc = "这里允许你提供解释此项目的说明。当你暂停并用鼠标悬停时，将显示此处的文本，以便查看推荐此项目的原因。" ..
                                        "",
                                    order = 3.205,
                                    width = "full"
                                },

                                lb01 = {
                                    type = "description",
                                    name = "",
                                    order = 3.21,
                                    width = "full"
                                },

                                var_name = {
                                    type = "input",
                                    name = "变量名",
                                    order = 3.3,
                                    width = 1.5,
                                    desc = "指定此变量的名称。变量名必须使用小写字母，且除了下划线之外不允许其他符号。",
                                    validate = function(info, val)
                                        if val:len() < 3 then
                                            return "变量名的长度必须不少于3个字符。"
                                        end

                                        local check = formatKey(val)
                                        if check ~= val then
                                            return "输入的字符无效。请重试。"
                                        end

                                        return true
                                    end,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "variable"
                                    end
                                },

                                op = {
                                    type = "select",
                                    name = "操作",
                                    values = {
                                        add = "增加数值",
                                        ceil = "数值向上取整",
                                        default = "设置默认值",
                                        div = "数值除法",
                                        floor = "数值向下取整",
                                        max = "最大值",
                                        min = "最小值",
                                        mod = "数值取余",
                                        mul = "数值乘法",
                                        pow = "数值幂运算",
                                        reset = "重置为默认值",
                                        set = "设置数值为",
                                        setif = "如果…设置数值为",
                                        sub = "数值减法"
                                    },
                                    order = 3.31,
                                    width = 1.5,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "variable"
                                    end
                                },

                                modPooling = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3.5,
                                    args = {
                                        for_next = {
                                            type = "toggle",
                                            name = function()
                                                local n = packControl.actionID
                                                n = tonumber(n) + 1
                                                local e = Hekili.DB.profile.packs[pack].lists[packControl.listName][n]

                                                local ability = e and e.action and class.abilities[e.action]
                                                ability = ability and ability.name or "未设置"

                                                return "归集到下一个项目(" .. ability .. ")"
                                            end,
                                            desc = "如果勾选，插件将归集资源，直到下一个技能有足够的资源可供使用。",
                                            order = 5,
                                            width = 1.5,
                                            hidden = function()
                                                local e = GetListEntry(pack)
                                                return e.action ~= "pool_resource"
                                            end
                                        },

                                        wait = {
                                            type = "input",
                                            name = "归集时间",
                                            desc = "以秒为单位指定时间，需要是数字或计算结果为数字的表达式。\n" ..
                                                "默认值为|cFFFFD1000.5|r。表达式示例为|cFFFFD100energy.time_to_max|r。",
                                            order = 6,
                                            width = 1.5,
                                            multiline = 3,
                                            hidden = function()
                                                local e = GetListEntry(pack)
                                                return e.action ~= "pool_resource" or e.for_next == 1
                                            end
                                        },

                                        extra_amount = {
                                            type = "input",
                                            name = "额外归集",
                                            desc = "指定除了下一项目所需的资源外，还需要额外归集的资源量。",
                                            order = 6,
                                            width = 1.5,
                                            hidden = function()
                                                local e = GetListEntry(pack)
                                                return e.action ~= "pool_resource" or e.for_next ~= 1
                                            end
                                        }
                                    },
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= 'pool_resource'
                                    end
                                },

                                criteria = {
                                    type = "input",
                                    name = "条件",
                                    desc = "设置当前指令被推荐或用于生成推荐时必须满足的条件。",
                                    order = 3.6,
                                    width = "full",
                                    multiline = 6,
                                    dialogControl = "HekiliCustomEditor",
                                    arg = function(info)
                                        local pack, list, action = info[2], packControl.listName,
                                            tonumber(packControl.actionID)
                                        local results = {}

                                        state.reset("Primary", true)

                                        local apack = rawget(self.DB.profile.packs, pack)

                                        -- Let's load variables, just in case.
                                        for name, alist in pairs(apack.lists) do
                                            state.this_list = name

                                            for i, entry in ipairs(alist) do
                                                if name ~= list or i ~= action then
                                                    if entry.action == "variable" and entry.var_name then
                                                        state:RegisterVariable(entry.var_name,
                                                            pack .. ":" .. name .. ":" .. i, name)
                                                    end
                                                end
                                            end
                                        end

                                        local entry = apack and apack.lists[list]
                                        entry = entry and entry[action]

                                        state.this_action = entry.action
                                        state.this_list = list

                                        local scriptID = pack .. ":" .. list .. ":" .. action
                                        state.scriptID = scriptID
                                        scripts:StoreValues(results, scriptID)

                                        return results, list, action
                                    end
                                },
                                trans_input = {
                                    type = "input",
                                    name = "中英文全称查询：",
                                    desc = "输入完整的中英文名称用于翻译",
                                    get = function()
                                        return trans_in
                                    end,
                                    set = function(info, val)
                                        trans_in = val
                                        trans_out = Hekili.Trans.transSpell(trans_in)
                                    end,
                                    width = 1.5,
                                    order = 3.56
                                },

                                trans_result = {
                                    type = "input",
                                    name = "翻译结果：",
                                    desc = "翻译结果",
                                    get = function()
                                        return trans_out
                                    end,
                                    width = 1.5,
                                    order = 3.57
                                },

                                value = {
                                    type = "input",
                                    name = "数值",
                                    desc = "提供调用此变量时要存储（或计算）的数值。\n\n" ..
                                        "如果提供了条件，那么当这些条件满足时，此数值就会被设置。",
                                    order = 3.61,
                                    width = "full",
                                    multiline = 3,
                                    dialogControl = "HekiliCustomEditor",
                                    arg = function(info)
                                        local pack, list, action = info[2], packControl.listName,
                                            tonumber(packControl.actionID)
                                        local results = {}

                                        state.reset("Primary", true)

                                        local apack = rawget(self.DB.profile.packs, pack)

                                        -- Let's load variables, just in case.
                                        for name, alist in pairs(apack.lists) do
                                            state.this_list = name
                                            for i, entry in ipairs(alist) do
                                                if name ~= list or i ~= action then
                                                    if entry.action == "variable" and entry.var_name then
                                                        state:RegisterVariable(entry.var_name,
                                                            pack .. ":" .. name .. ":" .. i, name)
                                                    end
                                                end
                                            end
                                        end

                                        local entry = apack and apack.lists[list]
                                        entry = entry and entry[action]

                                        state.this_action = entry.action
                                        state.this_list = list

                                        local scriptID = pack .. ":" .. list .. ":" .. action
                                        state.scriptID = scriptID
                                        scripts:StoreValues(results, scriptID, "value")

                                        return results, list, action
                                    end,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        return e.action ~= "variable" or e.op == "reset" or e.op == "ceil" or e.op ==
                                                   "floor"
                                    end
                                },

                                value_else = {
                                    type = "input",
                                    name = "不满足时数值",
                                    desc = "提供不满足此变量条件时要存储（或计算）的数值。",
                                    order = 3.62,
                                    width = "full",
                                    multiline = 3,
                                    dialogControl = "HekiliCustomEditor",
                                    arg = function(info)
                                        local pack, list, action = info[2], packControl.listName,
                                            tonumber(packControl.actionID)
                                        local results = {}

                                        state.reset("Primary", true)

                                        local apack = rawget(self.DB.profile.packs, pack)

                                        -- Let's load variables, just in case.
                                        for name, alist in pairs(apack.lists) do
                                            state.this_list = name
                                            for i, entry in ipairs(alist) do
                                                if name ~= list or i ~= action then
                                                    if entry.action == "variable" and entry.var_name then
                                                        state:RegisterVariable(entry.var_name,
                                                            pack .. ":" .. name .. ":" .. i, name)
                                                    end
                                                end
                                            end
                                        end

                                        local entry = apack and apack.lists[list]
                                        entry = entry and entry[action]

                                        state.this_action = entry.action
                                        state.this_list = list

                                        local scriptID = pack .. ":" .. list .. ":" .. action
                                        state.scriptID = scriptID
                                        scripts:StoreValues(results, scriptID, "value_else")

                                        return results, list, action
                                    end,
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        -- if not e.criteria or e.criteria:trim() == "" then return true end
                                        return e.action ~= "variable" or e.op == "reset" or e.op == "ceil" or e.op ==
                                                   "floor"
                                    end
                                },

                                showModifiers = {
                                    type = "toggle",
                                    name = "显示设置项",
                                    desc = "如果勾选，可以调整更多的设置项和条件。",
                                    order = 999,
                                    width = "full",
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local ability = e.action and class.abilities[e.action]

                                        return not ability -- or ( ability.id < 0 and ability.id > -100 )
                                    end
                                },

                                modCycle = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 21,
                                    args = {
                                        cycle_targets = {
                                            type = "toggle",
                                            name = "切换目标",
                                            desc = "如果勾选，插件将检查每个可用目标，并提示切换目标。",
                                            order = 1,
                                            width = "single"
                                        },

                                        max_cycle_targets = {
                                            type = "input",
                                            name = "最大循环目标数",
                                            desc = "如果勾选循环目标，插件将监测指定数量的目标。",
                                            order = 2,
                                            width = "double",
                                            disabled = function(info)
                                                local e = GetListEntry(pack)
                                                return e.cycle_targets ~= 1
                                            end
                                        }
                                    },
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local ability = e.action and class.abilities[e.action]

                                        return not e.cycle_targets and not e.max_cycle_targets and
                                                   not packControl.showModifiers or
                                                   (not ability or (ability.id < 0 and ability.id > -100))
                                    end
                                },

                                modMoving = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 22,
                                    args = {
                                        enable_moving = {
                                            type = "toggle",
                                            name = "监测移动",
                                            desc = "如果勾选，仅当角色的移动状态与设置匹配时，才会推荐此项目。",
                                            order = 1
                                        },

                                        moving = {
                                            type = "select",
                                            name = "移动状态",
                                            desc = "如果设置，仅当你的移动状态与设置匹配时，才会推荐此项目。",
                                            order = 2,
                                            width = "double",
                                            values = {
                                                [0] = "站立",
                                                [1] = "移动"
                                            },
                                            disabled = function(info)
                                                local e = GetListEntry(pack)
                                                return not e.enable_moving
                                            end
                                        }
                                    },
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local ability = e.action and class.abilities[e.action]

                                        return not e.enable_moving and not packControl.showModifiers or
                                                   (not ability or (ability.id < 0 and ability.id > -100))
                                    end
                                },

                                modAsyncUsage = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 22.1,
                                    args = {
                                        use_off_gcd = {
                                            type = "toggle",
                                            name = "GCD时可用",
                                            desc = "如果勾选，即使处于全局冷却（GCD）中，也可以推荐使用此项。",
                                            order = 1,
                                            width = 0.99
                                        },
                                        use_while_casting = {
                                            type = "toggle",
                                            name = "施法中可用",
                                            desc = "如果勾选，即使已经在施法或引导中，也可以推荐使用此项。",
                                            order = 2,
                                            width = 0.99
                                        },
                                        only_cwc = {
                                            type = "toggle",
                                            name = "仅引导时使用",
                                            desc = "如果勾选，只有在你引导其他技能时才能使用此项（如暗影牧师的灼烧梦魇）。",
                                            order = 3,
                                            width = 0.99
                                        }
                                    },
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local ability = e.action and class.abilities[e.action]

                                        return not e.use_off_gcd and not e.use_while_casting and not e.only_cwc and
                                                   not packControl.showModifiers or
                                                   (not ability or (ability.id < 0 and ability.id > -100))
                                    end
                                },

                                modCooldown = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 23,
                                    args = {

                                        line_cd = {
                                            type = "input",
                                            name = "强制冷却时间",
                                            desc = "如果设置，则强制在上次使用此项目后一定时间后，才会再次被推荐。",
                                            order = 1,
                                            width = "full"
                                        }
                                    },
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local ability = e.action and class.abilities[e.action]

                                        return not e.line_cd and not packControl.showModifiers or
                                                   (not ability or (ability.id < 0 and ability.id > -100))
                                    end
                                },

                                modAPL = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 24,
                                    args = {
                                        strict = {
                                            type = "toggle",
                                            name = "严谨/时间不敏感",
                                            desc = "如果勾选，插件将认为此项目不在乎时间，并且在不满足条件时，不会尝试推荐链接的技能列表中的操作。",
                                            order = 1,
                                            width = "full"
                                        },
                                        strict_if = {
                                            type = "input",
                                            name = "额外即时条件",
                                            desc = "如果填写了此处，则必须先满足即时条件，才会检测上述的常规条件。",
                                            multiline = 3,
                                            dialogControl = "HekiliCustomEditor",
                                            arg = function(info)
                                                local pack, list, action = info[2], packControl.listName,
                                                    tonumber(packControl.actionID)
                                                local results = {}

                                                state.reset("Primary", true)

                                                local apack = rawget(self.DB.profile.packs, pack)

                                                -- Let's load variables, just in case.
                                                for name, alist in pairs(apack.lists) do
                                                    state.this_list = name

                                                    for i, entry in ipairs(alist) do
                                                        if name ~= list or i ~= action then
                                                            if entry.action == "variable" and entry.var_name then
                                                                state:RegisterVariable(entry.var_name,
                                                                    pack .. ":" .. name .. ":" .. i, name)
                                                            end
                                                        end
                                                    end
                                                end

                                                local entry = apack and apack.lists[list]
                                                entry = entry and entry[action]

                                                state.this_action = entry.action
                                                state.this_list = list

                                                local scriptID = pack .. ":" .. list .. ":" .. action
                                                state.scriptID = scriptID
                                                scripts:StoreValues(results, scriptID, "strict_if")

                                                return results, list, action
                                            end,
                                            order = 2,
                                            width = "full"
                                        }
                                    },
                                    hidden = function()
                                        local e = GetListEntry(pack)
                                        local ability = e.action and class.abilities[e.action]

                                        return not e.strict and not e.strict_if and not packControl.showModifiers or
                                                   (not ability or
                                                       not (ability.key == "call_action_list" or ability.key ==
                                                           "run_action_list"))
                                    end
                                },

                                newListGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 2,
                                    hidden = function()
                                        return not packControl.makingNew
                                    end,
                                    args = {
                                        newListName = {
                                            type = "input",
                                            name = "列表名",
                                            order = 1,
                                            validate = function(info, val)
                                                local p = rawget(Hekili.DB.profile.packs, pack)

                                                if val:len() < 2 then
                                                    return "技能列表名的长度至少为2个字符。"
                                                elseif rawget(p.lists, val) then
                                                    return "已存在同名的技能列表。"
                                                elseif val:find("[^a-zA-Z0-9一-龥_]") then
                                                    return
                                                        "技能列表能使用中文、字母、数字、字符和下划线。"
                                                end
                                                return true
                                            end,
                                            width = 3
                                        },

                                        lineBreak = {
                                            type = "description",
                                            name = "",
                                            order = 1.1,
                                            width = "full"
                                        },

                                        createList = {
                                            type = "execute",
                                            name = "添加列表",
                                            disabled = function()
                                                return packControl.newListName == nil
                                            end,
                                            func = function()
                                                local p = rawget(Hekili.DB.profile.packs, pack)
                                                p.lists[packControl.newListName] = {{}}
                                                packControl.listName = packControl.newListName
                                                packControl.makingNew = false

                                                packControl.actionID = "0001"
                                                packControl.newListName = nil

                                                Hekili:LoadScript(pack, packControl.listName, 1)
                                            end,
                                            width = 1,
                                            order = 2
                                        },

                                        cancel = {
                                            type = "execute",
                                            name = "取消",
                                            func = function()
                                                packControl.makingNew = false
                                            end
                                        }
                                    }
                                },

                                newActionGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    hidden = function()
                                        return packControl.makingNew or packControl.actionID ~= "zzzzzzzzzz"
                                    end,
                                    args = {
                                        createEntry = {
                                            type = "execute",
                                            name = "创建新项目",
                                            order = 1,
                                            func = function()
                                                local p = rawget(Hekili.DB.profile.packs, pack)
                                                insert(p.lists[packControl.listName], {})
                                                packControl.actionID = format("%04d", #p.lists[packControl.listName])
                                            end
                                        }
                                    }
                                }
                            },
                            plugins = {}
                        },

                        export = {
                            type = "group",
                            name = "导出",
                            order = 4,
                            args = {
                                exportString = {
                                    type = "input",
                                    name = "导出字符串",
                                    desc = "按CTRL+A全部选中，然后CTRL+C复制。",
                                    get = function(info)
                                        Hekili.PackExports = Hekili.PackExports or {}

                                        -- Wipe previous output for this pack.
                                        local exportData = {
                                            export = "",
                                            stress = "",
                                            linked = false,
                                            unrelated = false
                                        }
                                        Hekili.PackExports[pack] = exportData

                                        local export = SerializeActionPack(pack)
                                        exportData.export = export

                                        wipe(Hekili.ErrorDB)
                                        wipe(Hekili.ErrorKeys)

                                        Hekili.Scripts:LoadScripts()
                                        local stressTestResults = Hekili:RunStressTest()

                                        local function ColorizeAPLIdentifier(key)
                                            local spec, list, entry, context = key:match(
                                                "^([^:]+):([^:]+):(%d+)%s+(%a+):")
                                            if not spec then
                                                return key
                                            end

                                            return string.format("|cff00ccff%s|r:|cffffd100%s|r:%s |cff888888%s|r:",
                                                spec, list, entry, context)
                                        end

                                        local output, finalOutput = {}, {}
                                        local lowerPack = pack:lower()
                                        local shadowKey = "error in " .. lowerPack .. ":"
                                        local shadowLabel = "priority '" .. lowerPack .. "'"

                                        for _, key in ipairs(Hekili.ErrorKeys) do
                                            local entry = Hekili.ErrorDB[key]
                                            if entry then
                                                local body = entry.text or "|cff777777<无可用信息>|r"
                                                local coloredKey = ColorizeAPLIdentifier(key)

                                                table.insert(output, format("|cff888888[%s (%dx)]|r %s\n%s",
                                                    entry.last or "??", entry.n or 1, coloredKey, body))

                                                local k = key:lower()
                                                if k:find(shadowKey, 1, true) or k:find(shadowLabel, 1, true) then
                                                    exportData.linked = true
                                                else
                                                    exportData.unrelated = true
                                                end
                                            end
                                        end

                                        -- 1. Stress Test
                                        if type(stressTestResults) == "string" and stressTestResults ~= "" then
                                            table.insert(finalOutput,
                                                "|cffa0a0ff自动压力测试：|r " .. stressTestResults)
                                        end
                                        -- 2. Header
                                        if exportData.linked then
                                            table.insert(finalOutput,
                                                "|cffff0000警告：|r 与此优先级相关的一些错误尚未解决。请在导出前进行检查。")
                                        elseif exportData.unrelated then
                                            table.insert(finalOutput,
                                                "|cffffff00注意：|r 自从加载用户界面以来，存在尚未解决的警告信息。这些警告可能与该优先级无关。")
                                        end
                                        -- 3. Error entries
                                        for _, line in ipairs(output) do
                                            table.insert(finalOutput, line)
                                        end
                                        if not exportData.linked and not exportData.unrelated and #output == 0 then
                                            table.insert(finalOutput,
                                                "|cff00ff00未检测到任何警告或错误！|r\n")
                                        end

                                        exportData.stress = table.concat(finalOutput, "\n\n")
                                        return export
                                    end,
                                    set = function()
                                    end,
                                    order = 1,
                                    width = "full"
                                },
                                stressResults = {
                                    type = "input",
                                    multiline = 20,
                                    name = "压力测试结果",
                                    get = function()
                                        local info = Hekili.PackExports and Hekili.PackExports[pack]
                                        return info and info.stress or ""
                                    end,
                                    set = function()
                                    end,
                                    order = 2,
                                    width = "full",
                                    hidden = function()
                                        local info = Hekili.PackExports and Hekili.PackExports[pack]
                                        return not (info and info.stress and info.stress ~= "")
                                    end
                                }
                            },
                            hidden = function()
                                if Hekili.PackExports then
                                    Hekili.PackExports[pack] = nil
                                end
                                return false
                            end
                        }
                    }
                }

                --[[ wipe( opts.args.lists.plugins.lists )

                local n = 10
                for list in pairs( data.lists ) do
                    opts.args.lists.plugins.lists[ list ] = EmbedActionListOptions( n, pack, list )
                    n = n + 1
                end ]]
                packs.plugins.packages[pack] = opts
                count = count + 1
            end
        end
        collectgarbage()
        db.args.packs = packs
    end

    do
        local completed = false
        local SetOverrideBinds

        SetOverrideBinds = function()
            if InCombatLockdown() then
                local timer = C_Timer and C_Timer.After or function(delay, func)
                    return Hekili:ScheduleTimer(func, delay)
                end
                timer(5, SetOverrideBinds)
                return
            end

            if completed then
                ClearOverrideBindings(Hekili_Keyhandler)
                completed = false
            end

            for name, toggle in pairs(Hekili.DB.profile.toggles) do
                if toggle.key and toggle.key ~= "" then
                    SetOverrideBindingClick(Hekili_Keyhandler, true, toggle.key, "Hekili_Keyhandler", name)
                    completed = true
                end
            end
        end

        function Hekili:OverrideBinds()
            SetOverrideBinds()
        end

        local function SetToggle(info, val)
            local self = Hekili
            local p = self.DB.profile
            local n = #info
            local bind, option = info[n - 1], info[n]

            local toggle = p.toggles[bind]
            if not toggle then
                return
            end

            if option == 'value' then
                if bind == 'pause' then
                    self:TogglePause()
                elseif bind == 'mode' then
                    toggle.value = val
                else
                    self:FireToggle(bind)
                end
            elseif option == 'type' then
                toggle.type = val

                if val == "AutoSingle" and not (toggle.value == "automatic" or toggle.value == "single") then
                    toggle.value = "automatic"
                end
                if val == "AutoDual" and not (toggle.value == "automatic" or toggle.value == "dual") then
                    toggle.value = "automatic"
                end
                if val == "SingleAOE" and not (toggle.value == "single" or toggle.value == "aoe") then
                    toggle.value = "single"
                end
                if val == "ReactiveDual" and toggle.value ~= "reactive" then
                    toggle.value = "reactive"
                end
            elseif option == 'key' then
                for t, data in pairs(p.toggles) do
                    if data.key == val then
                        data.key = ""
                    end
                end

                toggle.key = val
                self:OverrideBinds()
            elseif option == 'override' then
                toggle[option] = val
                ns.UI.Minimap:RefreshDataText()
            else
                toggle[option] = val
            end
        end

        local function GetToggle(info)
            local self = Hekili
            local p = Hekili.DB.profile
            local n = #info
            local bind, option = info[n - 1], info[n]

            local toggle = bind and p.toggles[bind]
            if not toggle then
                return
            end

            if bind == 'pause' and option == 'value' then
                return self.Pause
            end
            return toggle[option]
        end

        -- Bindings.
        function Hekili:EmbedToggleOptions(db)
            db = db or self.Options
            if not db then
                return
            end

            db.args.toggles = db.args.toggles or {
                type = "group",
                name = "快捷开关",
                desc = "快捷开关是一种按键绑定，可用于控制哪些能力可以推荐以及在哪里显示。",
                order = 20,
                childGroups = "tab",
                get = GetToggle,
                set = SetToggle,
                args = {
                    cooldowns = {
                        type = "group",
                        name = "爆发",
                        desc = "设置主要爆发和次要爆发，确保能够在理想时间推荐使用。",
                        order = 2,
                        args = {
                            key = {
                                type = "keybinding",
                                name = "主要爆发",
                                desc = "设置一个按键对主要爆发技能是否推荐进行开/关。",
                                order = 1
                            },

                            value = {
                                type = "toggle",
                                name = "启用主要爆发",
                                desc = "如果勾选，则可以推荐 |cFFFFD100主要爆发|r 中的技能和物品。\n\n" ..
                                    "此快捷开关一般适用于冷却时间为 60 秒以上的主要伤害技能。\n\n" ..
                                    "可以在|cFFFFD100技能|r和|cFFFFD100装备和物品|r部分添加/删除隶属于此快捷开关的内容。",
                                order = 2,
                                width = 2
                            },

                            cdLineBreak1 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 2.1
                            },

                            cdIndent1 = {
                                type = "description",
                                name = "",
                                width = 1,
                                order = 2.2
                            },

                            separate = {
                                type = "toggle",
                                name = format("在单独的 %s 主要爆发显示框中显示",
                                    AtlasToString("chromietime-32x32")),
                                desc = format(
                                    "如果勾选，则在启用该快捷开关时，该快捷开关中的技能将单独显示在|W%s |cFFFFD100主要爆发|r|w 显示框中。" ..
                                        "\n\n" .. "这是一项试验功能，可能对某些专精效果不佳。",
                                    AtlasToString("chromietime-32x32")),
                                width = 2,
                                order = 3
                            },

                            cdLineBreak2 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 3.1
                            },

                            cdIndent2 = {
                                type = "description",
                                name = "",
                                width = 1,
                                order = 3.2
                            },

                            override = {
                                type = "toggle",
                                name = format("%s 凌驾", Hekili:GetSpellLinkWithTexture(2825)),
                                desc = format(
                                    "如果勾选，当任何 %s 效果激活时，将自动启用|cFFFFD100主要爆发|r 快捷开关，即使你并没有开启。",
                                    Hekili:GetSpellLinkWithTexture(2825)),
                                width = 2,
                                order = 4
                            },

                            cdLineBreak3 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 4.1
                            },

                            cdIndent3 = {
                                type = "description",
                                name = "",
                                width = 1,
                                order = 4.2
                            },

                            infusion = {
                                type = "toggle",
                                name = format("%s 凌驾", Hekili:GetSpellLinkWithTexture(10060)),
                                desc = format(
                                    "如果勾选，当任何 %s 效果激活时，将自动开启|cFFFFD100主要爆发|r 快捷开关，即使你并没有开启。",
                                    Hekili:GetSpellLinkWithTexture(10060)),
                                width = 2,
                                order = 5
                            },

                            potions = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 7,
                                args = {
                                    key = {
                                        type = "keybinding",
                                        name = "药剂",
                                        desc = "设置一个按键来开启或关闭药剂的推荐。",
                                        order = 1
                                    },

                                    value = {
                                        type = "toggle",
                                        name = "启用药剂",
                                        desc = "如果勾选，将会推荐 |cFFFFD100药剂|r 类别中的指令（物品）。",
                                        width = 2,
                                        order = 2
                                    },

                                    potLineBreak2 = {
                                        type = "description",
                                        name = "",
                                        width = "full",
                                        order = 3.1
                                    },

                                    potIndent3 = {
                                        type = "description",
                                        name = "",
                                        width = 1,
                                        order = 3.2
                                    },

                                    override = {
                                        type = "toggle",
                                        name = "当 |cFFFFD100主要爆发|r 激活时自动启用",
                                        desc = "如果勾选，当启用（或自动启用）|cFFFFD100主要爆发|r时，即使没有启用，也会推荐使用|cFFFFD100药剂|r。",
                                        width = 2,
                                        order = 4
                                    }
                                }
                            },

                            funnel = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 8,
                                args = {
                                    key = {
                                        type = "keybinding",
                                        name = "漏斗优先级",
                                        desc = "对于支持此功能的专精，设置一个按键来开启或关闭漏斗优先级。",
                                        width = 1,
                                        order = 1
                                    },

                                    value = {
                                        type = "toggle",
                                        name = "启用漏斗优先级",
                                        desc = "如果勾选，漏斗优先级中的推荐技能会稍有调整，以便在群体攻击场景中使用单体输出技能（资源消耗技能）。\n\n",
                                        width = 2,
                                        order = 2
                                    },

                                    supportedSpecs = {
                                        type = "description",
                                        name = "支持专精：敏锐，奇袭，增强，毁灭",
                                        desc = "",
                                        width = "full",
                                        order = 3
                                    }
                                }
                            }
                        }
                    },

                    interrupts = {
                        type = "group",
                        name = "打断和防御",
                        desc = "根据需要切换打断技能（控制技能）和防御技能。",
                        order = 4,
                        args = {
                            key = {
                                type = "keybinding",
                                name = "打断",
                                desc = "设置一个按键对打断建议进行开/关。",
                                order = 1
                            },

                            value = {
                                type = "toggle",
                                name = "启用打断",
                                desc = "如果勾选，则允许推荐使用 |cFFFFD100打断|r 中的技能。",
                                order = 2
                            },

                            lb1 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 2.1
                            },

                            indent1 = {
                                type = "description",
                                name = "",
                                width = 1,
                                order = 2.2
                            },

                            separate = {
                                type = "toggle",
                                name = format("在单独的 %s 打断显示框中显示",
                                    AtlasToString("voicechat-icon-speaker-mute")),
                                desc = format(
                                    "如果勾选，快捷开关 |cFFFFD100打断|r 中的技能将在 %s 中断显示框中单独显示。",
                                    AtlasToString("voicechat-icon-speaker-mute")),
                                width = 2,
                                order = 3
                            },

                            lb2 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 3.1
                            },

                            indent2 = {
                                type = "description",
                                name = "",
                                width = 1,
                                order = 3.2
                            },

                            filterCasts = {
                                type = "toggle",
                                name = format("%s 地下城打断过滤器", NewFeature),
                                desc = format(
                                    "如果勾选，当目标使用可以被打断的技能时，将忽略低优先级的技能。\n\n" ..
                                        "举例:  在永茂林地地下城， 塑地者特鲁的 |W%s|w 将被忽略，而 |W%s|w 会被打断。",
                                    (GetSpellInfo(168040) or "自然之怒"), (GetSpellInfo(427459) or "毒性爆发")),
                                width = 2,
                                order = 4
                            },
                            lb3 = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = 4.1
                            },

                            indent3 = {
                                type = "description",
                                name = "",
                                width = 1,
                                order = 4.2
                            },
                            castRemainingThreshold = {
                                type = "range",
                                name = "打断时机",
                                desc = "默认情况下，当敌人的技能施法剩余时间为 0.25 秒（或更短）时，会推荐使用打断技能。\n\n" ..
                                    "如果设置为 2，那么当敌人的技能施法剩余时间少于 2 秒时，就会推荐使用打断技能。",
                                min = 0.25,
                                max = 3,
                                step = 0.25,
                                width = 2,
                                order = 4.3
                            },

                            defensives = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 5,
                                args = {
                                    key = {
                                        type = "keybinding",
                                        name = "防御",
                                        desc = "设置一个按键，用于打开或关闭防御技能的推荐。\n\n" ..
                                            "此快捷开关主要适用于坦克专精。",
                                        order = 1
                                    },

                                    value = {
                                        type = "toggle",
                                        name = "启用防御",
                                        desc = "如果勾选，则允许推荐使用 |cFFFFD100防御|r 中的技能。\n\n" ..
                                            "防御快捷开关主要适用于坦克专精。",
                                        order = 2
                                    },

                                    lb1 = {
                                        type = "description",
                                        name = "",
                                        width = "full",
                                        order = 2.1
                                    },

                                    indent1 = {
                                        type = "description",
                                        name = "",
                                        width = 1,
                                        order = 2.2
                                    },

                                    separate = {
                                        type = "toggle",
                                        name = format("在单独的 %s 防御显示框中显示",
                                            AtlasToString("nameplates-InterruptShield")),
                                        desc = format(
                                            "如果勾选，防御/减伤技能将在|W%s |cFFFFD100防御|r|w显示框单独显示。\n\n" ..
                                                "防御快捷开关主要适用于坦克专精。",
                                            AtlasToString("nameplates-InterruptShield")),
                                        width = 2,
                                        order = 3
                                    }
                                }
                            }
                        }
                    },

                    displayModes = {
                        type = "group",
                        name = "显示模式控制",
                        desc = "使用你绑定的快捷键循环切换你喜欢的显示模式。",
                        order = 10,
                        args = {
                            mode = {
                                type = "group",
                                inline = true,
                                name = "",
                                order = 10.1,
                                args = {
                                    key = {
                                        type = 'keybinding',
                                        name = '显示模式',
                                        desc = "按下此键后，将循环显示下面选中的显示模式。",
                                        order = 1,
                                        width = 1
                                    },

                                    value = {
                                        type = "select",
                                        name = "选择显示模式",
                                        desc = "选择你的显示模式。",
                                        values = {
                                            automatic = "自动",
                                            single = "单目标",
                                            aoe = "AOE（多目标）",
                                            dual = "固定式双显",
                                            reactive = "响应式双显"
                                        },
                                        width = 1,
                                        order = 1.02
                                    },

                                    modeLB2 = {
                                        type = "description",
                                        name = "勾选想要使用的 |cFFFFD100显示模式|r 。当你按下 |cFFFFD100切换显示模式|r 快捷键时，插件将切换到你下一个选中的显示模式。",
                                        fontSize = "medium",
                                        width = "full",
                                        order = 2
                                    },

                                    automatic = {
                                        type = "toggle",
                                        name = "自动" .. BlizzBlue .. "（默认）|r",
                                        desc = "如果勾选，显示模式切换键可以选择自动模式。主显示框根据检测到的敌人数量（基于你的专业选项）来推荐技能。",
                                        width = "full",
                                        order = 3
                                    },

                                    autoIndent = {
                                        type = "description",
                                        name = "",
                                        width = 0.15,
                                        order = 3.1
                                    },

                                    autoDesc = {
                                        type = "description",
                                        name = format("%s 使用主显示框\n" ..
                                                          "%s 根据检测到的敌人数量进行推荐", Bullet,
                                            Bullet),
                                        fontSize = "medium",
                                        width = 2.85,
                                        order = 3.2
                                    },

                                    single = {
                                        type = "toggle",
                                        name = "单目标",
                                        desc = "如果勾选，显示模式切换键就可以选择单目标模式。",
                                        width = "full",
                                        order = 4
                                    },

                                    singleIndent = {
                                        type = "description",
                                        name = "",
                                        width = 0.15,
                                        order = 4.1
                                    },

                                    singleDesc = {
                                        type = "description",
                                        name = format(
                                            "%s 使用主显示框\n" .. "%s 基于 1 个目标的推荐\n" ..
                                                "%s 对高优先级敌人集中伤害时非常有用", Bullet, Bullet,
                                            Bullet),
                                        fontSize = "medium",
                                        width = 2.85,
                                        order = 4.2
                                    },

                                    aoe = {
                                        type = "toggle",
                                        name = "AOE（多目标）",
                                        desc = function()
                                            return format(
                                                "如果勾选，显示模式切换开关可以选择AOE模式。\n\n主显示框会显示推荐技能，需要你至少有 |cFFFFD100%d|r 个目标（即使检测到的目标较少）。\n\n" ..
                                                    "需求目标数量在专精页面中设定。",
                                                self.DB.profile.specs[state.spec.id].aoe or 3)
                                        end,
                                        width = "full",
                                        order = 5
                                    },

                                    aoeIndent = {
                                        type = "description",
                                        name = "",
                                        width = 0.15,
                                        order = 5.1
                                    },

                                    aoeDesc = {
                                        type = "description",
                                        name = function()
                                            return format("%s 使用主显示框\n" ..
                                                              "%s 至少基于 |cFFFFD100%d|r 目标的推荐\n",
                                                Bullet, Bullet, self.DB.profile.specs[state.spec.id].aoe or 3)
                                        end,
                                        fontSize = "medium",
                                        width = 2.85,
                                        order = 5.2
                                    },

                                    dual = {
                                        type = "toggle",
                                        name = "固定式双显",
                                        desc = function()
                                            return format(
                                                "如果勾选，显示模式切换键可选择固定式双显。\n\n主显示框显示单目标推荐，AOE显示框显示 |cFFFFD100%d|r 或更多目标的推荐（即使检测到的目标较少）。\n\n" ..
                                                    "AOE目标的数量在专精页面中设定。",
                                                self.DB.profile.specs[state.spec.id].aoe or 3)
                                        end,
                                        width = "full",
                                        order = 6
                                    },

                                    dualIndent = {
                                        type = "description",
                                        name = "",
                                        width = 0.15,
                                        order = 6.1
                                    },

                                    dualDesc = {
                                        type = "description",
                                        name = function()
                                            return format(
                                                "%s 使用两个显示框：主显示框和 AOE显示框\n" ..
                                                    "%s 基于 1 个目标的推荐在主显示器显示\n" ..
                                                    "%s 基于至少 |cFFFFD100%d|r 目标的 AOE显示推荐\n" ..
                                                    "%s 适用于使用基于伤害的目标检测的远程专精\n",
                                                Bullet, Bullet, Bullet, self.DB.profile.specs[state.spec.id].aoe or 3,
                                                Bullet)
                                        end,
                                        fontSize = "medium",
                                        width = 2.85,
                                        order = 6.2
                                    },

                                    reactive = {
                                        type = "toggle",
                                        name = "响应式双显",
                                        desc = function()
                                            return format(
                                                "如果勾选，显示模式切换键可选择响应式双显。\n\n主显示框显示单个目标推荐，而 AOE显示框保持隐藏，直到检测到|cFFFFD100%d|r 或更多目标。",
                                                self.DB.profile.specs[state.spec.id].aoe or 3)
                                        end,
                                        width = "full",
                                        order = 7
                                    },

                                    reactiveIndent = {
                                        type = "description",
                                        name = "",
                                        width = 0.15,
                                        order = 7.1
                                    },
                                    reactiveDesc = {
                                        type = "description",
                                        name = function()
                                            local specID = state.spec and state.spec.id or 0
                                            local aoeCount =
                                                self.DB.profile.specs and self.DB.profile.specs[specID] and
                                                    self.DB.profile.specs[specID].aoe or 3
                                            return format("%s 使用两个显示框：主显示框和AOE显示框\n" ..
                                                              "%s 主显示框基于单目标给出推荐\n" ..
                                                              "%s 当检测到 |cFFFFD100%d|r+ 个目标时显示AOE",
                                                Bullet, Bullet, Bullet, aoeCount)
                                        end,
                                        fontSize = "medium",
                                        width = 2.85,
                                        order = 7.2
                                    }
                                }
                            }
                        }
                    },

                    troubleshooting = {
                        type = "group",
                        name = "故障排除",
                        desc = "这些快捷键有助于在排除故障或报告问题时提供关键信息。",
                        order = 20,
                        args = {
                            pause = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 1,
                                args = {
                                    key = {
                                        type = 'keybinding',
                                        name = function()
                                            return Hekili.Pause and "取消暂停" or "暂停"
                                        end,
                                        desc = "设置一个按键使你的技能列表暂停。当前显示框架将被冻结，" ..
                                            "你可以将鼠标悬停在每个技能图标上，查看有关该技能的操作信息。\n\n" ..
                                            "同时还将创建一个快照，可用于故障排除和错误报告。",
                                        order = 1
                                    },
                                    value = {
                                        type = 'toggle',
                                        name = '暂停',
                                        order = 2
                                    }
                                }
                            },

                            snapshot = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 2,
                                args = {
                                    key = {
                                        type = 'keybinding',
                                        name = '快照',
                                        desc = "设置一个快捷键，生成一个可在快照页面中查看的快照（不暂停）。这对于测试和调试非常有用。",
                                        order = 1
                                    }
                                }
                            }
                        }
                    },

                    custom = {
                        type = "group",
                        name = "自定义快捷键",
                        desc = "通过指定快捷键，可以创建自定义来控制特定技能。",
                        order = 30,
                        args = {
                            custom1 = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 1,
                                args = {
                                    key = {
                                        type = "keybinding",
                                        name = "自定义 1",
                                        desc = "设置一个按键来切换第一个自定义设置。",
                                        width = 1,
                                        order = 1
                                    },

                                    value = {
                                        type = "toggle",
                                        name = "启用自定义 1",
                                        desc = "如果勾选，则允许推荐自定义 1 中的技能。",
                                        width = 2,
                                        order = 2
                                    },

                                    lb1 = {
                                        type = "description",
                                        name = "",
                                        width = "full",
                                        order = 2.1
                                    },

                                    indent1 = {
                                        type = "description",
                                        name = "",
                                        width = 1,
                                        order = 2.2
                                    },

                                    name = {
                                        type = "input",
                                        name = "自定义 1 名称",
                                        desc = "为自定义切换开关指定一个描述性名称。",
                                        width = 2,
                                        order = 3
                                    }
                                }
                            },

                            custom2 = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 30.2,
                                args = {
                                    key = {
                                        type = "keybinding",
                                        name = "自定义 2",
                                        desc = "设置一个按键来切换第二个自定义设置。",
                                        width = 1,
                                        order = 1
                                    },

                                    value = {
                                        type = "toggle",
                                        name = "启用自定义 2",
                                        desc = "如果勾选，则允许推荐自定义 2 中的技能。",
                                        width = 2,
                                        order = 2
                                    },

                                    lb1 = {
                                        type = "description",
                                        name = "",
                                        width = "full",
                                        order = 2.1
                                    },

                                    indent1 = {
                                        type = "description",
                                        name = "",
                                        width = 1,
                                        order = 2.2
                                    },

                                    name = {
                                        type = "input",
                                        name = "自定义 2 名称",
                                        desc = "为自定义切换开关指定一个描述性名称。",
                                        width = 2,
                                        order = 3
                                    }
                                }
                            }
                        }
                    }
                }
            }
        end
    end

    function Hekili:EmbedSkeletonOptions(db)
        db = db or self.Options
        if not db then
            return
        end

        db.args.skeleton = {
            type = "group",
            name = "Skeleton",
            order = 100,
            hidden = function()
                return not Hekili.Skeleton -- hide whole group until chat command sets this
            end,
            args = {
                spooky = {
                    type = "input",
                    name = "开发框架",
                    desc = "当前专精的一个大致框架，仅用于开发目的。",
                    order = 1,
                    get = function()
                        return Hekili.Skeleton or ""
                    end,
                    multiline = 25,
                    width = "full"
                },
                regen = {
                    type = "execute",
                    name = "生成开发框架",
                    order = 2,
                    func = function()
                        Hekili:StopSkeletonListener()

                        local result = ns.SkeletonGen:Generate()
                        Hekili.Skeleton = result or "-- 无法生成开发框架"

                        -- MoP: Use Hekili timer instead of C_Timer
                        Hekili:ScheduleTimer(function()
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("Hekili")
                        end, 0.1)
                    end
                }

            }
        }
    end

    do
        local selectedError = nil
        local errList = {}

        function Hekili:EmbedErrorOptions(db)
            db = db or self.Options
            if not db then
                return
            end

            db.args.errors = {
                type = "group",
                name = "警告信息",
                order = 99,
                args = {
                    errName = {
                        type = "select",
                        name = "警告标签",
                        width = "full",
                        order = 1,

                        values = function()
                            wipe(errList)

                            for i, err in ipairs(self.ErrorKeys) do
                                local eInfo = self.ErrorDB[err]

                                errList[i] = "[" .. eInfo.last .. " (" .. eInfo.n .. "x)] " .. err
                            end

                            return errList
                        end,

                        get = function()
                            return selectedError
                        end,
                        set = function(info, val)
                            selectedError = val
                        end
                    },

                    errorInfo = {
                        type = "input",
                        name = "警告信息",
                        width = "full",
                        multiline = 10,
                        order = 2,

                        get = function()
                            if selectedError == nil then
                                return ""
                            end
                            return Hekili.ErrorKeys[selectedError]
                        end,

                        dialogControl = "HekiliCustomEditor"
                    }
                },
                disabled = function()
                    return #self.ErrorKeys == 0
                end
            }
        end
    end

    function Hekili:GenerateProfile()
        local s = state

        local spec = s.spec.key

        local talents = self:GetLoadoutExportString()

        for k, v in orderedPairs(s.talent) do
            if v.enabled then
                if talents then
                    talents = format("%s\n    %s = %d/%d", talents, k, v.rank, v.max)
                else
                    talents = format("%s = %d/%d", k, v.rank, v.max)
                end
            end
        end

        local sets
        for k, v in orderedPairs(class.gear) do
            if s.set_bonus[k] > 0 then
                if sets then
                    sets = format("%s\n    %s = %d", sets, k, s.set_bonus[k])
                else
                    sets = format("%s = %d", k, s.set_bonus[k])
                end
            end
        end

        local gear, items
        for k, v in orderedPairs(state.set_bonus) do
            if type(v) == "number" and v > 0 then
                if type(k) == 'string' then
                    if gear then
                        gear = format("%s\n    %s = %d", gear, k, v)
                    else
                        gear = format("%s = %d", k, v)
                    end
                elseif type(k) == 'number' then
                    if items then
                        items = format("%s, %d", items, k)
                    else
                        items = tostring(k)
                    end
                end
            end
        end

        local legendaries
        for k, v in orderedPairs(state.legendary) do
            if k ~= "no_trait" and v.rank > 0 then
                if legendaries then
                    legendaries = format("%s\n    %s = %d", legendaries, k, v.rank)
                else
                    legendaries = format("%s = %d", k, v.rank)
                end
            end
        end

        local settings
        if state.settings.spec then
            for k, v in orderedPairs(state.settings.spec) do
                if type(v) ~= "table" then
                    if settings then
                        settings = format("%s\n    %s = %s", settings, k, tostring(v))
                    else
                        settings = format("%s = %s", k, tostring(v))
                    end
                end
            end
            for k, v in orderedPairs(state.settings.spec.settings) do
                if type(v) ~= "table" then
                    if settings then
                        settings = format("%s\n    %s = %s", settings, k, tostring(v))
                    else
                        settings = format("%s = %s", k, tostring(v))
                    end
                end
            end
        end

        local toggles
        for k, v in orderedPairs(self.DB.profile.toggles) do
            if type(v) == "table" and rawget(v, "value") ~= nil then
                if toggles then
                    toggles = format("%s\n    %s = %s %s", toggles, k, tostring(v.value),
                        (v.separate and "[separate]" or
                            (k ~= "cooldowns" and v.override and self.DB.profile.toggles.cooldowns.value and
                                "[overridden]") or ""))
                else
                    toggles = format("%s = %s %s", k, tostring(v.value), (v.separate and "[separate]" or
                        (k ~= "cooldowns" and v.override and self.DB.profile.toggles.cooldowns.value and "[overridden]") or
                        ""))
                end
            end
        end

        local keybinds = ""
        local bindLength = 1

        for name in pairs(Hekili.KeybindInfo) do
            if name:len() > bindLength then
                bindLength = name:len()
            end
        end

        for name, data in orderedPairs(Hekili.KeybindInfo) do
            local action = format("%-" .. bindLength .. "s =", name)
            local count = 0
            for i = 1, 12 do
                local bar = data.upper[i]
                if bar then
                    if count > 0 then
                        action = action .. ","
                    end
                    action = format("%s %-4s[%02d]", action, bar, i)
                    count = count + 1
                end
            end
            keybinds = keybinds .. "\n    " .. action
        end

        local warnings

        for i, err in ipairs(Hekili.ErrorKeys) do
            if warnings then
                warnings = format("%s\n[#%d] %s", warnings, i, err:gsub("\n\n", "\n"))
            else
                warnings = format("[#%d] %s", i, err:gsub("\n\n", "\n"))
            end
        end

        return format(
            "build: %s\n" .. "level: %d (%d)\n" .. "class: %s\n" .. "spec: %s\n\n" .. "### Talents ###\n\n" ..
                "In-Game Import: %s\n\n" .. "### Legacy Content ###\n\n" .. "legendaries: %s\n\n" ..

                "### Gear & Items ###\n\n" .. "sets:\n    %s\n\n" .. "gear:\n    %s\n\n" .. "itemIDs: %s\n\n" ..

                "### Settings ###\n\n" .. "Settings:\n    %s\n\n" .. "Toggles:\n    %s\n\n" .. "Keybinds:%s\n\n" ..

                "### Warnings ###\n\n%s\n", self.Version or "no info", UnitLevel('player') or 0,
            UnitEffectiveLevel('player') or 0, class.file or "NONE", spec or "none", talents or "none",
            legendaries or "none", sets or "none", gear or "none", items or "none", settings or "none",
            toggles or "none", keybinds or "none", warnings or "none")
    end

    do
        local Options = {
            name = "Hekili " .. Hekili.Version,
            type = "group",
            handler = Hekili,
            get = 'GetOption',
            set = 'SetOption',
            childGroups = "tree",
            args = {
                general = {
                    type = "group",
                    name = "通用",
                    desc = "欢迎使用Hekili；这里包括常规信息和重要链接。",
                    order = 10,
                    childGroups = "tab",
                    args = {
                        enabled = {
                            type = "toggle",
                            name = "启用",
                            desc = "启用或禁用插件。",
                            order = 1
                        },

                        minimapIcon = {
                            type = "toggle",
                            name = "隐藏小地图图标",
                            desc = "如果勾选，小地图旁的图标将被隐藏。",
                            order = 2
                        },

                        monitorPerformance = {
                            type = "toggle",
                            name = BlizzBlue .. "监控性能|r",
                            desc = "如果勾选，插件将追踪事件的处理时间和数量。",
                            order = 3,
                            hidden = true
                        },

                        debugTargets = {
                            type = "toggle",
                            name = "目标检测调试",
                            desc = "如果勾选，插件将在聊天框中显示目标计数和筛选的详细信息，有助于排查目标检测相关问题。",
                            order = 4
                        },

                        welcome = {
                            type = 'description',
                            name = "",
                            fontSize = "medium",
                            image = "Interface\\Addons\\Hekili\\Textures\\Taco256",
                            imageWidth = 96,
                            imageHeight = 96,
                            order = 5,
                            width = "full"
                        },

                        supporters = {
                            type = "description",
                            name = function()
                                return "|cFF00CCFF感谢我们的支持者！|r\n\n" .. ns.Patrons .. "\n\n" ..
                                           "有关如何报告漏洞的信息，请查看|cFFFFD100快照（故障排除）|r 部分。\n\n"
                            end,
                            fontSize = "medium",
                            order = 6,
                            width = "full"
                        },

                        discord = {
                            type = "input",
                            name = "Discord",
                            desc = "加入 Hekili 的Discord服务器获取支持和参与讨论。",
                            order = 7,
                            get = function()
                                return "https://discord.gg/3cCTFxM"
                            end,
                            set = function()
                            end,
                            width = "full",
                            dialogControl = "SFX-Info-URL"
                        },
                        discordSpace = {
                            type = "description",
                            name = " ",
                            order = 8,
                            width = "full"
                        },

                        github = {
                            type = "input",
                            name = "GitHub代码平台",
                            desc = "在Github上更新。",
                            order = 10,
                            get = function()
                                return "https://github.com/Hekili/hekili/releases"
                            end,
                            set = function()
                            end,
                            width = "full",
                            dialogControl = "SFX-Info-URL"
                        },
                        curse = {
                            type = "input",
                            name = "CurseForge插件站",
                            desc = "在CF插件站上更新",
                            order = 11,
                            get = function()
                                return "https://www.curseforge.com/wow/addons/hekili"
                            end,
                            set = function()
                            end,
                            width = "full",
                            dialogControl = "SFX-Info-URL"
                        },
                        wago = {
                            type = "input",
                            name = "Wago分享站",
                            desc = "在Wago上更新。",
                            order = 12,
                            get = function()
                                return "https://addons.wago.io/addons/hekili"
                            end,
                            set = function()
                            end,
                            width = "full",
                            dialogControl = "SFX-Info-URL"
                        },
                        wowi = {
                            type = "input",
                            name = "WoW Interface插件站",
                            desc = "在WoW Interface上更新",
                            order = 13,
                            get = function()
                                return "https://www.wowinterface.com/downloads/info24608-HekiliPriorityHelper.html"
                            end,
                            set = function()
                            end,
                            width = "full",
                            dialogControl = "SFX-Info-URL"
                        },
                        updaterSpace = {
                            type = "description",
                            name = " ",
                            order = 14,
                            width = "full"
                        },

                        link = {
                            type = "input",
                            name = "建议反馈",
                            order = 20,
                            width = "full",
                            get = function()
                                return "http://github.com/Hekili/hekili/issues"
                            end,
                            set = function()
                            end,
                            dialogControl = "SFX-Info-URL"
                        },
                        faq = {
                            type = "input",
                            name = "FAQ / 帮助",
                            order = 21,
                            width = "full",
                            get = function()
                                return "https://github.com/Hekili/hekili/wiki/Frequently-Asked-Questions"
                            end,
                            set = function()
                            end,
                            dialogControl = "SFX-Info-URL"
                        },
                        simulationcraft = {
                            type = "input",
                            name = "SimC Wiki",
                            order = 22,
                            get = function()
                                return "https://github.com/simulationcraft/simc/wiki"
                            end,
                            set = function()
                            end,
                            width = "full",
                            dialogControl = "SFX-Info-URL"
                        },
                        newbee = {
                            type = "input",
                            name = "新手盒子",
                            order = 23,
                            get = function()
                                return "https://www.wclbox.com/"
                            end,
                            set = function()
                            end,
                            width = "full",
                            dialogControl = "SFX-Info-URL"
                        }
                    }
                },

                gettingStarted = {
                    type = "group",
                    name = "入门指南",
                    desc = "这是一个快速入门教程和插件的解释说明。",
                    order = 11,
                    childGroups = "tab",
                    args = {
                        gettingStarted_welcome_header = {
                            type = "header",
                            name = "欢迎使用 Hekili\n",
                            order = 1,
                            width = "full"
                        },
                        gettingStarted_welcome_info = {
                            type = "description",
                            name = "这里是对插件基础知识的快速概览。在最后，你还会找到一些我们在GitHub或Discord上收到的常见问题的答案。\n\n" ..
                                "|cFF00CCFF非常鼓励你阅读几分钟，以改善你的体验！|r\n\n",
                            order = 1.1,
                            fontSize = "medium",
                            width = "full"
                        },
                        gettingStarted_toggles = {
                            type = "group",
                            name = "如何使用快捷开关",
                            order = 2,
                            width = "full",
                            args = {
                                gettingStarted_toggles_info = {
                                    type = "description",
                                    name = "插件提供了多个 |cFFFFD100快捷开关|r，它们可以帮助你精准控制你在战斗中，愿意接收到的推荐技能的类型，这些快捷开关可以通过快捷键进行开关。具体内容请查看 |cFFFFD100快捷开关|r 部分。\n\n" ..
                                        "|cFFFFD100爆发技能|r：你的重要爆发技能被分配到了 |cFF00CCFF爆发|r 的快捷开关下。这允许你使用快捷键在战斗中启用/禁用这些技能，这可以防止插件在一些不值得的情况下推荐你的重要爆发技能，例如：\n" ..
                                        "• 在地下城战斗的收尾阶段\n" ..
                                        "• 在团队首领的无敌阶段期间，或者在易伤阶段之前\n\n" ..
                                        "你可以在 |cFFFFD100技能|r 或者 |cFFFFD100装备和道具|r 页面中，添加/移除这些快捷开关中的技能。\n\n" ..
                                        "|cFF00CCFF学会在游戏过程中使用爆发技能快捷开关可以大幅提高你的DPS！|r\n\n",
                                    order = 2.1,
                                    fontSize = "medium",
                                    width = "full"
                                }
                            }
                        },
                        gettingStarted_displays = {
                            type = "group",
                            name = "设置你的显示框架",
                            order = 3,
                            args = {
                                gettingStarted_displays_info = {
                                    type = "description",
                                    name = "|cFFFFD100显示框架|r 是 Hekili 向你展示推荐施放的技能和道具的区域，其中 |cFF00CCFFPrimary|r 显示框架推荐DPS技能。当选项窗口打开时，所有的显示框架都是可见的。\n" ..
                                        "\n|cFFFFD100显示框架|r 的移动方法：\n" ..
                                        "• 点击后拖动它们\n" ..
                                        "  - 你可以通过点击顶部的 |cFFFFD100Hekili " .. Hekili.Version ..
                                        " |r 标题然后拖动，把这个窗口移开后调整。\n" ..
                                        "  - 或者，你可以输入命令 |cFFFFD100/hek move|r 来允许拖动显示框架，而不需要打开选项。再次输入锁定显示框架。\n" ..
                                        "• 在每个 |cFFFFD100显示框架|r 的主页设置中，精确设置 |cFFFFD100图标|r 的X/Y位置。\n\n" ..
                                        "默认情况下，插件使用 |cFFFFD100自动|r 模式，根据检测到的敌对目标数量推荐 |cFF00CCFF单目标|r 还是 |cFF00CCFFAoE（多目标）|r 显示模式。 你可以在 |cFFFFD100快捷开关|r > |cFFFFD100显示模式控制|r 中启用其他类型的显示模式。" ..
                                        " 在这里你可以使用其他显示类型，并且有选项将它们与你的 |cFF00CCFFPrimary|r 显示框架区分开来分别显示。\n" ..
                                        "\n其他显示框架：\n• |cFF00CCFF爆发|r\n" ..
                                        "• |cFF00CCFF打断|r\n" .. "• |cFF00CCFF防御|r\n\n",
                                    order = 3.1,
                                    fontSize = "medium",
                                    width = "full"
                                }
                            }
                        },
                        gettingStarted_faqs = {
                            type = "group",
                            name = "插件问题和故障",
                            order = 4,
                            width = "full",
                            args = {
                                gettingStarted_toggles_info = {
                                    type = "description",
                                    name = "排名前3的问题/故障\n\n" ..
                                        "1. 我的绑定按键没有正确显示\n- |cFF00CCFF这确实有时会在使用宏或姿态栏时发生。你可以在|r |cFFFFD100技能|r |cFF00CCFF部分手动告诉插件使用哪个按键绑定。在下拉菜单中找到这个技能，然后在|r |cFFFFD100覆盖键位绑定文本|r |cFF00CCFF的文本框中输入你想显示的键位。同样的方法也可以用于|r |cFFFFD100装备和道具|r 中的饰品。\n\n" ..
                                        "2. 我不认识这个法术！这是个啥？\n- |cFF00CCFF如果你是冰霜法师，那可能是你的水元素宠物技能———冻结。否则，它可能是个饰品。你可以按 |cFFFFD100alt-shift-p|r 来暂停插件的推荐，并将鼠标悬停在图标上看看它是个啥玩意儿！|r\n\n" ..
                                        "3. 我如何禁用某个特定的技能或饰品？\n- |cFF00CCFF前往 |cFFFFD100技能|r 或者 |cFFFFD100装备和道具|r 页面，找到下拉列表中的它，然后禁用它。\n\n|r" ..
                                        "\n我已经看完了但是我还是有问题！\n- |cFF00CCFF请前往|r |cFFFFD100问题报告|r |cFF00CCFF寻找解答或提出新的问题。\n- |cFF00CCFF中文用户请前往|r |cFFFFD100NGA发布贴|r |cFF00CCFF。（译者注）",
                                    order = 4.1,
                                    fontSize = "medium",
                                    width = "full"
                                }
                            }
                        }
                    }
                },

                abilities = {
                    type = "group",
                    name = "技能",
                    desc = "编辑特定技能，例如禁用、分配至快捷开关、覆盖键位绑定文本或图标等。",
                    order = 80,
                    childGroups = "select",
                    args = {
                        -- EasyPlay提供的技能查询
                        searchInPut = {
                            type = "input",
                            name = "技能搜索(模糊输入)",
                            desc = "匹配到的技能会筛选显示在列表中",
                            order = 0.2,
                            width = "full",
                            set = function(info, val)
                                ns.searchID = val
                                -- 重新构建技能选项列表以实现筛选
                                Hekili:EmbedAbilityOptions()
                            end,
                            get = function()
                                return ns.searchID or ""
                            end
                        },
                        spec = {
                            type = "select",
                            name = "职业专精",
                            desc = "这些选项对应你当前选择的职业专精。",
                            order = 0.1,
                            width = "full",
                            set = SetCurrentSpec,
                            get = GetCurrentSpec,
                            values = GetCurrentSpecList
                        }
                    },
                    plugins = {
                        actions = {}
                    }
                },

                items = {
                    type = "group",
                    name = "装备和道具",
                    desc = "编辑特定物品，例如禁用、分配至快捷开关、覆盖键位绑定文本等。",
                    order = 81,
                    childGroups = "select",
                    args = {
                        -- EasyPlay提供装备道具查询
                        searchInPut = {
                            type = "input",
                            name = "装备搜索(模糊输入)",
                            desc = "匹配到的装备会筛选显示在列表中",
                            order = 0.2,
                            width = "full",
                            set = function(info, val)
                                ns.searchItemName = val
                                -- 重新构建装备选项列表以实现筛选
                                Hekili:EmbedItemOptions()
                            end,
                            get = function()
                            end

                        },
                        spec = {
                            type = "select",
                            name = "职业专精",
                            desc = "这些选项对应你当前选择的职业专精。",
                            order = 0.1,
                            width = 1.49,
                            set = SetCurrentSpec,
                            get = GetCurrentSpec,
                            values = GetCurrentSpecList
                        },
                        disable_items = {
                            type = "toggle",
                            name = "禁用装备和物品",
                            desc = function()
                                return format(
                                    "如果勾选，无论下方选择了任何选项，|cFFFFD100%s|r 中带有 |cFF00FF00使用：|r 效果的" ..
                                        "已装备饰品、武器和护甲都不会被推荐。",
                                    (GetCurrentSpec() and GetCurrentSpecList()[GetCurrentSpec()] or "本专精"))
                            end,
                            order = 0.2,
                            width = 1.49,
                            get = function()
                                local spec = GetCurrentSpec()
                                return Hekili.DB.profile.specs[spec].disable_items or false
                            end,
                            set = function(info, val)
                                local spec = GetCurrentSpec()
                                Hekili.DB.profile.specs[spec].disable_items = val
                            end
                        }
                    },
                    plugins = {
                        equipment = {}
                    }
                },

                snapshots = {
                    type = "group",
                    name = "问题报告（快照）",
                    desc = "学习如何正确报告插件问题，避免不正确的建议或错误。",
                    order = 86,
                    childGroups = "tab",
                    args = {
                        prefHeader = {
                            type = "header",
                            name = "快照",
                            order = 1,
                            width = "full"
                        },
                        SnapID = {
                            type = "select",
                            name = "选择快照",
                            desc = "选择要导出的快照。",
                            values = function(info)
                                if #ns.snapshots == 0 then
                                    snapshots.snaps[0] = "未生成任何快照。"
                                else
                                    snapshots.snaps[0] = nil
                                    for i, snapshot in ipairs(ns.snapshots) do
                                        snapshots.snaps[i] = "|cFFFFD100" .. i .. ".|r " .. snapshot.header
                                    end
                                end

                                return snapshots.snaps
                            end,
                            set = function(info, val)
                                snapshots.selected = val
                            end,
                            get = function(info)
                                return snapshots.selected
                            end,
                            order = 3,
                            width = "full",
                            disabled = function()
                                return #ns.snapshots == 0
                            end
                        },
                        autoSnapshot = {
                            type = "toggle",
                            name = "自动快照",
                            desc = "如果勾选，插件会在无法生成推荐时自动创建一个快照。\n\n" ..
                                "自动快照每次战斗只会创建一次。",
                            order = 2,
                            width = "normal"
                        },
                        screenshot = {
                            type = "toggle",
                            name = "屏幕截图",
                            desc = "如果勾选，当你手动创建快照时，插件会同时截取屏幕截图。\n\n" ..
                                "提交问题时，将快照和截图一起提交，能够为问题排查提供更多有用的信息。",
                            order = 2.1,
                            width = "normal"
                        },
                        snapshotInstructions = {
                            type = "group",
                            name = "如何创建与分享",
                            order = 4,
                            args = {
                                snapshotInstructions_info = {
                                    type = "description",
                                    name = function()
                                        local snapshotKey = Hekili.DB.profile.toggles.snapshot.key or "NOT BOUND"
                                        local pauseKey = Hekili.DB.profile.toggles.pause.key or "NOT BOUND"
                                        return "|cFFFFD100何时创建|r\n" ..
                                                   "当问题正在发生时生成快照。如果推荐看起来不对，那就是捕捉的时候。\n\n" ..
                                                   "|cFFFFD100如何创建|r\n" .. "• 快照快捷键：|cffffd100" ..
                                                   snapshotKey .. "|r\n" .. "• 暂停快捷键：|cffffd100" ..
                                                   pauseKey .. "|r\n" ..
                                                   "• 未找到推荐时自动生成（请在上方启用）\n\n" ..
                                                   "|cFFFFD100如何分享|r\n" ..
                                                   "1. 使用 |cffffd100打开快照窗口|r 按钮复制快照\n" ..
                                                   "2. 前往 Pastebin.com 并粘贴（Ctrl+V）\n" ..
                                                   "3. 点击“创建新粘贴”并分享链接"
                                    end,
                                    order = 1,
                                    width = "full",
                                    fontSize = "medium"
                                },
                                pastebin_link = {
                                    type = "input",
                                    name = "Pastebin",
                                    dialogControl = "SFX-Info-URL",
                                    get = function()
                                        return "https://pastebin.com/"
                                    end,
                                    set = function()
                                    end,
                                    order = 2,
                                    width = "full"
                                },
                                discord_link = {
                                    type = "input",
                                    name = "Discord",
                                    dialogControl = "SFX-Info-URL",
                                    get = function()
                                        return "https://discord.gg/3cCTFxM"
                                    end,
                                    set = function()
                                    end,
                                    order = 3,
                                    width = "full"
                                },
                                github_link = {
                                    type = "input",
                                    name = "GitHub Issues",
                                    dialogControl = "SFX-Info-URL",
                                    get = function()
                                        return "https://github.com/Smufrik/Hekili/issues"
                                    end,
                                    set = function()
                                    end,
                                    order = 4,
                                    width = "full"
                                }
                            }
                        },

                        issueReporting_snapshot_what = {
                            type = "group",
                            name = "什么是快照？",
                            order = 5,
                            args = {
                                issueReporting_snapshot_what_info = {
                                    type = "description",
                                    name = function()
                                        return "|cFFFFD100什么是快照？|r\n" ..
                                                   "快照是一份全面的诊断日志，用于在某一瞬间捕捉你角色的完整状态。它会记录插件在生成当前屏幕推荐时所“看到”的一切，包括：\n\n" ..
                                                   "• |cFF00CCFF角色属性|r：你当前的生命值、资源（法力/能量/怒气）、增益、减益、天赋与装备\n" ..
                                                   "• |cFF00CCFF战斗状态|r：是否处于战斗、当前目标、敌对减益以及与敌人的距离\n" ..
                                                   "• |cFF00CCFF技能信息|r：冷却时间、可用层数、施法时间与资源消耗\n" ..
                                                   "• |cFF00CCFF决策逻辑|r：插件为每条推荐所做的逐步推理\n" ..
                                                   "• |cFF00CCFF优先级列表|r：已检查的动作优先级列表（APL）条件及其结果\n\n" ..
                                                   "|cFFFFD100为什么快照很重要？|r\n" ..
                                                   "当你报告“插件应该推荐火球术却推荐了冰箭术”这类 bug 时，开发者需要知道插件那一刻到底在“想”什么。快照不会回溯过去，它只提供当前可见推荐的相关信息。没有快照，几乎无法重现和修复问题，因为：\n\n" ..
                                                   "• 角色的确切状态至关重要（天赋、装备、增益、资源）\n" ..
                                                   "• 战斗情况复杂且瞬息万变\n" ..
                                                   "• 插件逻辑涉及数百条条件与计算\n\n" ..
                                                   "|cFFFFD100怎样才算好快照？|r\n" ..
                                                   "最佳快照应在问题正在发生时立即生成。若你看到明显错误的推荐，请立刻创建快照。快照应该非常长（数百甚至数千行）——如果只有一行，说明出了问题。\n\n" ..
                                                   "把快照看作插件的“黑匣子记录仪”——它告诉开发者到底发生了什么，以便他们理解并修复问题。"
                                    end,
                                    order = 1,
                                    fontSize = "medium",
                                    width = "full"
                                }
                            }
                        },
                        Snapshot = {
                            type = 'input',
                            name = "替代方案：手动复制",
                            desc = "如果愿意，可直接从此文本框复制。\n\n粘贴到文本编辑器中查看，或上传到 Pastebin 以支持问题工单。",
                            order = 25,
                            get = function(info)
                                if snapshots.selected == 0 then
                                    return ""
                                end
                                return ns.snapshots[snapshots.selected].log
                            end,
                            set = function()
                            end,
                            width = "full",
                            hidden = function()
                                return snapshots.selected == 0 or #ns.snapshots == 0
                            end
                        },

                        SnapshotInstructions = {
                            type = "description",
                            name = "|cFF00CCFF为了便于复制，请使用上方的 |cFFFFD100打开快照窗口|r 按钮。",
                            order = 30,
                            width = "full",
                            fontSize = "medium",
                            hidden = function()
                                return snapshots.selected == 0 or #ns.snapshots == 0
                            end
                        }

                    }
                }
            },
            plugins = {
                specializations = {}
            }
        }

        function Hekili:GetOptions()
            self:EmbedToggleOptions(Options)

            --[[ self:EmbedDisplayOptions( Options )

        self:EmbedPackOptions( Options )

        self:EmbedAbilityOptions( Options )

        self:EmbedItemOptions( Options )

        self:EmbedSpecOptions( Options ) ]]

            self:EmbedSkeletonOptions(Options)

            self:EmbedErrorOptions(Options)

            Hekili.OptionsReady = false

            return Options
        end
    end

    function Hekili:TotalRefresh(noOptions)
        if Hekili.PLAYER_ENTERING_WORLD then
            if self.SpecializationChanged then
                self:SpecializationChanged()
            end
            self:RestoreDefaults()
        end

        for i, queue in pairs(ns.queue) do
            for j, _ in pairs(queue) do
                ns.queue[i][j] = nil
            end
            ns.queue[i] = nil
        end

        if callHook then
            callHook("onInitialize")
        end

        if class and class.specs then
            for specID, spec in pairs(class.specs) do
                if specID > 0 then
                    local options = self.DB.profile.specs[specID]

                    for k, v in pairs(spec.options) do
                        if rawget(options, k) == nil then
                            options[k] = v
                        end
                    end
                end
            end
        end

        self:RunOneTimeFixes()
        -- Allow ability options to rebuild after a total refresh.
        self.AbilityOptionsEmbedded = nil
        ns.checkImports()

        -- self:LoadScripts()
        if Hekili.OptionsReady then
            if Hekili.Config then
                self:RefreshOptions()
                ACD:SelectGroup("Hekili", "profiles")
            else
                Hekili.OptionsReady = false
            end
        end

        self:BuildUI()
        self:OverrideBinds()

        if WeakAuras and WeakAuras.ScanEvents then
            for name, toggle in pairs(Hekili.DB.profile.toggles) do
                WeakAuras.ScanEvents("HEKILI_TOGGLE", name, toggle.value)
            end
        end

        if ns.UI.Minimap then
            ns.UI.Minimap:RefreshDataText()
        end
    end

    function Hekili:RefreshOptions()
        if not self.Options then
            return
        end

        self:EmbedDisplayOptions()
        self:EmbedPackOptions()
        self:EmbedSpecOptions()
        self:EmbedAbilityOptions()
        self:EmbedItemOptions()

        Hekili.OptionsReady = true

        -- Until I feel like making this better at managing memory.
        collectgarbage()
    end

    function Hekili:GetOption(info, input)
        local category, depth, option = info[1], #info, info[#info]
        local profile = Hekili.DB.profile

        if category == 'general' then
            return profile[option]
        elseif category == 'bindings' then
            if option:match("TOGGLE") or option == "HEKILI_SNAPSHOT" then
                return select(1, GetBindingKey(option))
            elseif option == 'Pause' then
                return self.Pause
            else
                return profile[option]
            end
        elseif category == 'displays' then
            -- This is a generic display option/function.
            if depth == 2 then
                return nil

                -- This is a display (or a hook).
            else
                local dispKey, dispID = info[2], tonumber(match(info[2], "^D(%d+)"))
                local hookKey, hookID = info[3], tonumber(match(info[3] or "", "^P(%d+)"))
                local display = profile.displays[dispID]

                -- This is a specific display's settings.
                if depth == 3 or not hookID then
                    if option == 'x' or option == 'y' then
                        return tostring(display[option])
                    elseif option == 'spellFlashColor' or option == 'iconBorderColor' then
                        if type(display[option]) ~= 'table' then
                            display[option] = {
                                r = 1,
                                g = 1,
                                b = 1,
                                a = 1
                            }
                        end
                        return display[option].r, display[option].g, display[option].b, display[option].a
                    elseif option == 'Copy To' or option == 'Import' then
                        return nil
                    else
                        return display[option]
                    end

                    -- This is a priority hook.
                else
                    local hook = display.Queues[hookID]

                    if option == 'Move' then
                        return hookID
                    else
                        return hook[option]
                    end
                end
            end
        elseif category == 'actionLists' then
            -- This is a general action list option.
            if depth == 2 then
                return nil
            else
                local listKey, listID = info[2], tonumber(match(info[2], "^L(%d+)"))
                local actKey, actID = info[3], tonumber(match(info[3], "^A(%d+)"))
                local list = listID and profile.actionLists[listID]

                -- This is a specific action list.
                if depth == 3 or not actID then
                    return list[option]

                    -- This is a specific action.
                elseif listID and actID then
                    local action = list.Actions[actID]

                    if option == 'ConsumableArgs' then
                        option = 'Args'
                    end

                    if option == 'Move' then
                        return actID
                    else
                        return action[option]
                    end
                end
            end
        elseif category == "snapshots" then
            return profile[option]
        end

        ns.Error("GetOption() - should never see.")
    end

    local getUniqueName = function(category, name)
        local numChecked, suffix, original = 0, 1, name

        while numChecked < #category do
            for i, instance in ipairs(category) do
                if name == instance.Name then
                    name = original .. ' (' .. suffix .. ')'
                    suffix = suffix + 1
                    numChecked = 0
                else
                    numChecked = numChecked + 1
                end
            end
        end

        return name
    end

    function Hekili:SetOption(info, input, ...)
        local category, depth, option = info[1], #info, info[#info]
        local Rebuild, RebuildUI, RebuildScripts, RebuildOptions, RebuildCache, Select
        local profile = Hekili.DB.profile

        if category == 'general' then
            -- We'll preset the option here; works for most options.
            profile[option] = input

            if option == 'enabled' then
                if input then
                    self:Enable()
                    ACD:SelectGroup("Hekili", "general")
                else
                    self:Disable()
                end

                self:UpdateDisplayVisibility()

                return
            elseif option == 'minimapIcon' then
                profile.iconStore.hide = input
                if input then
                    LDBIcon:Hide("Hekili")
                else
                    LDBIcon:Show("Hekili")
                end
            end

            -- General options do not need add'l handling.
            return
        elseif category == "snapshots" then
            profile[option] = input
        end

        if Rebuild then
            ns.refreshOptions()
            ns.loadScripts()
            QueueRebuildUI()
        else
            if RebuildOptions then
                ns.refreshOptions()
            end
            if RebuildScripts then
                ns.loadScripts()
            end
            if RebuildCache and not RebuildUI then
                self:UpdateDisplayVisibility()
            end
            if RebuildUI then
                QueueRebuildUI()
            end
        end

        if ns.UI.Minimap then
            ns.UI.Minimap:RefreshDataText()
        end

        if Select then
            ACD:SelectGroup("Hekili", category, info[2], Select)
        end
    end

    -- Import/Export
    -- Nicer string encoding from WeakAuras, thanks to Stanzilla.

    local bit_band, bit_lshift, bit_rshift = bit.band, bit.lshift, bit.rshift
    local string_char = string.char

    local bytetoB64 = {
        [0] = "a",
        "b",
        "c",
        "d",
        "e",
        "f",
        "g",
        "h",
        "i",
        "j",
        "k",
        "l",
        "m",
        "n",
        "o",
        "p",
        "q",
        "r",
        "s",
        "t",
        "u",
        "v",
        "w",
        "x",
        "y",
        "z",
        "A",
        "B",
        "C",
        "D",
        "E",
        "F",
        "G",
        "H",
        "I",
        "J",
        "K",
        "L",
        "M",
        "N",
        "O",
        "P",
        "Q",
        "R",
        "S",
        "T",
        "U",
        "V",
        "W",
        "X",
        "Y",
        "Z",
        "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "(",
        ")"
    }

    local B64tobyte = {
        a = 0,
        b = 1,
        c = 2,
        d = 3,
        e = 4,
        f = 5,
        g = 6,
        h = 7,
        i = 8,
        j = 9,
        k = 10,
        l = 11,
        m = 12,
        n = 13,
        o = 14,
        p = 15,
        q = 16,
        r = 17,
        s = 18,
        t = 19,
        u = 20,
        v = 21,
        w = 22,
        x = 23,
        y = 24,
        z = 25,
        A = 26,
        B = 27,
        C = 28,
        D = 29,
        E = 30,
        F = 31,
        G = 32,
        H = 33,
        I = 34,
        J = 35,
        K = 36,
        L = 37,
        M = 38,
        N = 39,
        O = 40,
        P = 41,
        Q = 42,
        R = 43,
        S = 44,
        T = 45,
        U = 46,
        V = 47,
        W = 48,
        X = 49,
        Y = 50,
        Z = 51,
        ["0"] = 52,
        ["1"] = 53,
        ["2"] = 54,
        ["3"] = 55,
        ["4"] = 56,
        ["5"] = 57,
        ["6"] = 58,
        ["7"] = 59,
        ["8"] = 60,
        ["9"] = 61,
        ["("] = 62,
        [")"] = 63
    }

    -- This code is based on the Encode7Bit algorithm from LibCompress
    -- Credit goes to Galmok (galmok@gmail.com)
    local encodeB64Table = {}

    local function encodeB64(str)
        local B64 = encodeB64Table
        local remainder = 0
        local remainder_length = 0
        local encoded_size = 0
        local l = #str
        local code
        for i = 1, l do
            code = string.byte(str, i)
            remainder = remainder + bit_lshift(code, remainder_length)
            remainder_length = remainder_length + 8
            while (remainder_length) >= 6 do
                encoded_size = encoded_size + 1
                B64[encoded_size] = bytetoB64[bit_band(remainder, 63)]
                remainder = bit_rshift(remainder, 6)
                remainder_length = remainder_length - 6
            end
        end
        if remainder_length > 0 then
            encoded_size = encoded_size + 1
            B64[encoded_size] = bytetoB64[remainder]
        end
        return table.concat(B64, "", 1, encoded_size)
    end

    local decodeB64Table = {}

    local function decodeB64(str)
        local bit8 = decodeB64Table
        local decoded_size = 0
        local ch
        local i = 1
        local bitfield_len = 0
        local bitfield = 0
        local l = #str
        while true do
            if bitfield_len >= 8 then
                decoded_size = decoded_size + 1
                bit8[decoded_size] = string_char(bit_band(bitfield, 255))
                bitfield = bit_rshift(bitfield, 8)
                bitfield_len = bitfield_len - 8
            end
            ch = B64tobyte[str:sub(i, i)]
            bitfield = bitfield + bit_lshift(ch or 0, bitfield_len)
            bitfield_len = bitfield_len + 6
            if i > l then
                break
            end
            i = i + 1
        end
        return table.concat(bit8, "", 1, decoded_size)
    end

    -- Import/Export Strings
    local Compresser = LibStub:GetLibrary("LibCompress")
    local Encoder = Compresser:GetChatEncodeTable()

    local LibDeflate = LibStub:GetLibrary("LibDeflate")
    local ldConfig = {
        level = 5
    }

    local Serializer = LibStub:GetLibrary("AceSerializer-3.0")

    TableToString = function(inTable, forChat)
        local serialized = Serializer:Serialize(inTable)
        local compressed = LibDeflate:CompressDeflate(serialized, ldConfig)

        return format("Hekili:%s", forChat and (LibDeflate:EncodeForPrint(compressed)) or
            (LibDeflate:EncodeForWoWAddonChannel(compressed)))
    end

    StringToTable = function(inString, fromChat)
        local modern = false
        if inString:sub(1, 7) == "Hekili:" then
            modern = true
            inString = inString:sub(8)
        end

        local decoded, decompressed, errorMsg

        if modern then
            decoded = fromChat and LibDeflate:DecodeForPrint(inString) or LibDeflate:DecodeForWoWAddonChannel(inString)
            if not decoded then
                return "无法解码。"
            end

            decompressed = LibDeflate:DecompressDeflate(decoded)
            if not decompressed then
                return "无法解码该字符串。"
            end
        else
            decoded = fromChat and decodeB64(inString) or Encoder:Decode(inString)
            if not decoded then
                return "无法解码。"
            end

            decompressed, errorMsg = Compresser:Decompress(decoded)
            if not decompressed then
                return "无法解码的字符串：" .. errorMsg
            end
        end

        local success, deserialized = Serializer:Deserialize(decompressed)
        if not success then
            return "无法解码解压缩的字符串：" .. deserialized
        end

        return deserialized
    end

    SerializeDisplay = function(display)
        local serial = rawget(Hekili.DB.profile.displays, display)
        if not serial then
            return
        end

        return TableToString(serial, true)
    end

    DeserializeDisplay = function(str)
        local display = StringToTable(str, true)
        return display
    end

    SerializeActionPack = function(name)
        local pack = rawget(Hekili.DB.profile.packs, name)
        if not pack then
            return
        end

        local serial = {
            type = "package",
            name = name,
            date = tonumber(date("%Y%m%d.%H%M%S")),
            payload = tableCopy(pack)
        }

        serial.payload.builtIn = false

        return TableToString(serial, true)
    end

    DeserializeActionPack = function(str)
        local serial = StringToTable(str, true)

        if not serial or type(serial) == "string" or serial.type ~= "package" then
            return serial or "无法从提供的字符串还原优先级配置。"
        end

        serial.payload.builtIn = false

        return serial
    end
    Hekili.DeserializeActionPack = DeserializeActionPack

    SerializeStyle = function(...)
        local serial = {
            type = "style",
            date = tonumber(date("%Y%m%d.%H%M%S")),
            payload = {}
        }

        local hasPayload = false

        for i = 1, select("#", ...) do
            local dispName = select(i, ...)
            local display = rawget(Hekili.DB.profile.displays, dispName)

            if not display then
                return "尝试序列化无效的显示框（" .. dispName .. "）"
            end

            serial.payload[dispName] = tableCopy(display)
            hasPayload = true
        end

        if not hasPayload then
            return "没有选中用于导出的显示框。"
        end
        return TableToString(serial, true)
    end

    DeserializeStyle = function(str)
        local serial = StringToTable(str, true)

        if not serial or type(serial) == 'string' or not serial.type == "style" then
            return nil, serial
        end

        return serial.payload
    end

    -- End Import/Export Strings

    local Sanitize

    -- Begin APL Parsing
    do
        local ignore_actions = {
            snapshot_stats = 1,
            flask = 1,
            food = 1
        }

        local expressions = {{"stealthed", "stealthed.rogue"}, {"rtb_buffs%.normal", "rtb_buffs_normal"},
                             {"rtb_buffs%.min_remains", "rtb_buffs_min_remains"},
                             {"rtb_buffs%.max_remains", "rtb_buffs_max_remains"},
                             {"rtb_buffs%.shorter", "rtb_buffs_shorter"}, {"rtb_buffs%.longer", "rtb_buffs_longer"},
                             {"rtb_buffs%.will_lose%.([%w_]+)", "rtb_buffs_will_lose_buff.%1"},
                             {"rtb_buffs%.will_lose", "rtb_buffs_will_lose"}, {"rtb_buffs%.total", "rtb_buffs"},
                             {"spell%.usable%.([%w_]+)", "action.%1.ready"},
                             {"buff.supercharge_(%d).up", "supercharge_%1"},
                             {"hyperthread_wristwraps%.([%w_]+)%.first_remains",
                              "hyperthread_wristwraps.first_remains.%1"},
                             {"hyperthread_wristwraps%.([%w_]+)%.count", "hyperthread_wristwraps.%1"},
                             {"cooldown", "action_cooldown"}, {"talent%.([%w_]+)", "talent.%1.enabled", true},
                             {"legendary%.([%w_]+)", "legendary.%1.enabled"},
                             {"runeforge%.([%w_]+)", "runeforge.%1.enabled"},
                             {"rune_word%.([%w_]+)", "buff.rune_word_%1.up"},
                             {"rune_word%.([%w_]+)%.enabled", "buff.rune_word_%1.up"},

                             {"soul_shard%.deficit", "soul_shard_deficit"},
                             {"pet.[%w_]+%.([%w_]+)%.([%w%._]+)", "%1.%2"}, {"target%.1%.time_to_die", "time_to_die"},
                             {"time_to_pct_(%d+)%.remains", "time_to_pct_%1"},
                             {"trinket%.(%d)%.([%w%._]+)", "trinket.t%1.%2"},
                             {"trinket%.([%w_]+)%.cooldown", "trinket.%1.cooldown.duration"},
                             {"trinket%.([%w_]+)%.proc%.([%w_]+)%.duration", "trinket.%1.buff_duration"},
                             {"trinket%.([%w_]+)%.buff%.a?n?y?%.?duration", "trinket.%1.buff_duration"},
                             {"trinket%.([%w_]+)%.proc%.([%w_]+)%.[%w_]+", "trinket.%1.has_use_buff"},
                             {"trinket%.([%w_]+)%.has_buff%.([%w_]+)", "trinket.%1.has_use_buff"},
                             {"trinket%.([%w_]+)%.has_use_buff%.([%w_]+)", "trinket.%1.has_use_buff"},
                             {"min:([%w_]+)", "%1"}, {"position_back", "true"}, {"max:(%w_]+)", "%1"},
                             {"incanters_flow_time_to%.(%d+)", "incanters_flow_time_to_%.%1.any"},
                             {"exsanguinated%.([%w_]+)", "debuff.%1.exsanguinated"},
                             {"time_to_sht%.(%d+)%.plus", "time_to_sht_plus.%1"}, {"target", "target.unit"},
                             {"player", "player.unit"}, {"gcd", "gcd.max"},
                             {"howl_summon%.([%w_]+)%.([%w_]+)", "howl_summon.%1_%2"},

                             {"equipped%.(%d+)", nil, function(item)
            item = tonumber(item)

            if not item then
                return "equipped.none"
            end

            if class.abilities[item] then
                return "equipped." .. (class.abilities[item].key or "none")
            end

            return "equipped[" .. item .. "]"
        end}, {"trinket%.([%w_]+)%.cooldown%.([%w_]+)", nil, function(trinket, token)
            if class.abilities[trinket] then
                return "cooldown." .. trinket .. "." .. token
            end

            return "trinket." .. trinket .. ".cooldown." .. token
        end}}

        local operations = {{"==", "="}, {"%%", "/"}, {"//", "%%"}}

        function Hekili:AddSanitizeExpr(from, to, func)
            insert(expressions, {from, to, func})
        end

        function Hekili:AddSanitizeOper(from, to)
            insert(operations, {from, to})
        end

        Sanitize = function(segment, i, line, warnings)
            if i == nil then
                return
            end

            local operators = {
                [">"] = true,
                ["<"] = true,
                ["="] = true,
                ["~"] = true,
                ["+"] = true,
                ["-"] = true,
                ["%%"] = true,
                ["*"] = true
            }

            local maths = {
                ['+'] = true,
                ['-'] = true,
                ['*'] = true,
                ['%%'] = true
            }

            local times = 0
            local output, pre = "", ""

            for op1, token, op2 in gmatch(i, "([^%w%._ ]*)([%w%._]+)([^%w%._ ]*)") do
                if token and token:len() > 0 then
                    pre = token
                    for _, subs in ipairs(expressions) do
                        local ignore = type(subs[3]) == "boolean" and subs[3]
                        if subs[2] then
                            times = 0
                            local s1, s2, s3, s4, s5 = token:match("^" .. subs[1] .. "$")
                            if s1 then
                                token = subs[2]
                                token, times = token:gsub("%%1", s1)

                                if s2 then
                                    token = token:gsub("%%2", s2)
                                end
                                if s3 then
                                    token = token:gsub("%%3", s3)
                                end
                                if s4 then
                                    token = token:gsub("%%4", s4)
                                end
                                if s5 then
                                    token = token:gsub("%%5", s5)
                                end

                                if times > 0 and not ignore then
                                    insert(warnings, "第" .. line .. "行：转换'" .. pre .. "'为'" .. token ..
                                        "'（" .. times .. "次）。")
                                end
                            end
                        elseif subs[3] and type(subs[3]) == "function" then
                            local val, v2, v3, v4, v5 = token:match("^" .. subs[1] .. "$")
                            if val ~= nil then
                                token = subs[3](val, v2, v3, v4, v5)
                                insert(warnings,
                                    "第" .. line .. "行：转换'" .. pre .. "'为'" .. token .. "'次。")
                            end
                        end
                    end
                end

                output = output .. (op1 or "") .. (token or "") .. (op2 or "")
            end

            local ops_swapped = false
            pre = output

            -- Replace operators after its been stitched back together.
            for _, subs in ipairs(operations) do
                output, times = output:gsub(subs[1], subs[2])
                if times > 0 then
                    ops_swapped = true
                end
            end

            if ops_swapped then
                insert(warnings,
                    "第" .. line .. "行：转换: Converted operations in '" .. pre .. "' to '" .. output .. "'.")
            end

            return output
        end

        local function strsplit(str, delimiter)
            local result = {}
            local from = 1

            if not delimiter or delimiter == "" then
                result[1] = str
                return result
            end

            local delim_from, delim_to = string.find(str, delimiter, from)

            while delim_from do
                insert(result, string.sub(str, from, delim_from - 1))
                from = delim_to + 1
                delim_from, delim_to = string.find(str, delimiter, from)
            end

            insert(result, string.sub(str, from))
            return result
        end

        local parseData = {
            warnings = {},
            missing = {}
        }

        local nameMap = {
            call_action_list = "list_name",
            run_action_list = "list_name",
            variable = "var_name",
            cancel_action = "action_name",
            cancel_buff = "buff_name",
            op = "op"
        }

        function Hekili:ParseActionList(list)
            local line, times = 0, 0
            local output, warnings, missing = {}, parseData.warnings, parseData.missing

            wipe(warnings)
            wipe(missing)

            list = list:gsub("(|)([^|])", "%1|%2"):gsub("|||", "||")

            local n = 0
            for aura in list:gmatch("buff%.([a-zA-Z0-9_]+)") do
                if not class.auras[aura] then
                    missing[aura] = true
                    n = n + 1
                end
            end

            for aura in list:gmatch("active_dot%.([a-zA-Z0-9_]+)") do
                if not class.auras[aura] then
                    missing[aura] = true
                    n = n + 1
                end
            end

            -- TODO: Revise to start from beginning of string.
            for i in list:gmatch("action.-=/?([^\n^$]*)") do
                line = line + 1

                if i:sub(1, 3) == 'jab' then
                    for token in i:gmatch('cooldown%.expel_harm%.remains>=gcd') do
                        local times = 0
                        while (i:find(token)) do
                            local strpos, strend = i:find(token)

                            local pre = strpos > 1 and i:sub(strpos - 1, strpos - 1) or ''
                            local post = strend < i:len() and i:sub(strend + 1, strend + 1) or ''
                            local repl = ((strend < i:len() and pre) and pre or post) or ""

                            local start = strpos > 2 and i:sub(1, strpos - 2) or ''
                            local finish = strend < i:len() - 1 and i:sub(strend + 2) or ''

                            i = start .. repl .. finish
                            times = times + 1
                        end
                        insert(warnings,
                            "第" .. line .. "行：移除不必要的驱散伤害冷却检测(" .. times .. "次)。")
                    end
                end

                if i:sub(1, 13) == 'fists_of_fury' then
                    for token in i:gmatch("energy.time_to_max>cast_time") do
                        local times = 0
                        while (i:find(token)) do
                            local strpos, strend = i:find(token)

                            local pre = strpos > 1 and i:sub(strpos - 1, strpos - 1) or ''
                            local post = strend < i:len() and i:sub(strend + 1, strend + 1) or ''
                            local repl = ((strend < i:len() and pre) and pre or post) or ""

                            local start = strpos > 2 and i:sub(1, strpos - 2) or ''
                            local finish = strend < i:len() - 1 and i:sub(strend + 2) or ''

                            i = start .. repl .. finish
                            times = times + 1
                        end
                        insert(warnings,
                            "第" .. line .. "行：移除不必要的能量上限检测(" .. times .. "次)。")
                    end
                end

                local components = strsplit(i, ",")
                local result = {}

                for a, str in ipairs(components) do
                    -- First element is the action, if supported.
                    if a == 1 then
                        local ability = str:trim()

                        if ability and (ability == "use_item" or class.abilities[ability]) then
                            if ability == "pocketsized_computation_device" then
                                ability = "cyclotronic_blast"
                            else
                                result.action = ability
                            end
                        elseif not ignore_actions[ability] then
                            insert(warnings, "第" .. line .. "行：不支持的操作指令'" .. ability .. "'.")
                            result.action = ability
                        end
                    else
                        local key, value = str:match("^(.-)=(.-)$")

                        if key and value then
                            -- TODO:  Automerge multiple criteria.
                            if key == 'if' or key == 'condition' then
                                key = 'criteria'
                            end

                            if key == 'criteria' or key == 'target_if' or key == 'value' or key == 'value_else' or key ==
                                'sec' or key == 'wait' or key == 'strict_if' then
                                value = Sanitize('c', value, line, warnings)
                                value = SpaceOut(value)
                            end

                            if key == 'caption' then
                                value = value:gsub("||", "|"):gsub(";", ",")
                            end

                            if key == 'description' then
                                value = value:gsub(";", ",")
                            end

                            result[key] = value
                        end
                    end
                end

                if nameMap[result.action] then
                    result[nameMap[result.action]] = result.name
                    result.name = nil
                end

                if result.target_if then
                    result.target_if = result.target_if:gsub("min:", ""):gsub("max:", "")
                end

                -- As of 11/11/2022 (11/11/2022 in Europe), empower_to is purely a number 1-4.
                if result.empower_to and (result.empower_to == "max" or result.empower_to == "maximum") then
                    result.empower_to = "max_empower"
                end
                if result.for_next then
                    result.for_next = tonumber(result.for_next)
                end
                if result.cycle_targets then
                    result.cycle_targets = tonumber(result.cycle_targets)
                end
                if result.max_energy then
                    result.max_energy = tonumber(result.max_energy)
                end

                if result.use_off_gcd then
                    result.use_off_gcd = tonumber(result.use_off_gcd)
                end
                if result.use_while_casting then
                    result.use_while_casting = tonumber(result.use_while_casting)
                end
                if result.strict then
                    result.strict = tonumber(result.strict)
                end
                if result.moving then
                    result.enable_moving = true
                    result.moving = tonumber(result.moving)
                end

                if result.target_if and not result.criteria then
                    result.criteria = result.target_if
                    result.target_if = nil
                end

                if result.action == "use_item" then
                    if result.effect_name and class.abilities[result.effect_name] then
                        result.action = class.abilities[result.effect_name].key
                    elseif result.name and class.abilities[result.name] then
                        result.action = result.name
                    elseif (result.slot or result.slots) and class.abilities[result.slot or result.slots] then
                        result.action = result.slot or result.slots
                    end

                    if result.action == "use_item" then
                        insert(warnings,
                            "第" .. line .. "行：不支持的使用道具指令[ " ..
                                (result.effect_name or result.name or "未知") .. "]; 没有权限。")
                        result.action = nil
                        result.enabled = false
                    end
                end

                if result.action == "wait_for_cooldown" then
                    if result.name then
                        result.action = "wait"
                        result.sec = "cooldown." .. result.name .. ".remains"
                        result.name = nil
                    else
                        insert(warnings, "第" .. line ..
                            "行：无法转换wait_for_cooldown,name=X到wait,sec=cooldown.X.remains或没有权限。")
                        result.action = "wait"
                        result.enabled = false
                    end
                end

                if result.action == 'use_items' and (result.slot or result.slots) then
                    result.action = result.slot or result.slots
                end

                if result.action == 'variable' and not result.op then
                    result.op = 'set'
                end

                if result.cancel_if and not result.interrupt_if then
                    result.interrupt_if = result.cancel_if
                    result.cancel_if = nil
                end

                insert(output, result)
            end

            if n > 0 then
                insert(warnings, "以下效果已在技能列表中使用，但无法在插件数据库中找到：")
                for k in orderedPairs(missing) do
                    insert(warnings, " - " .. k)
                end
            end

            return #output > 0 and output or nil, #warnings > 0 and warnings or nil
        end
    end

    -- End APL Parsing

    local warnOnce = false

    -- Begin Toggles
    function Hekili:TogglePause(...)
        Hekili.btns = ns.UI.Buttons

        if not self.Pause then
            self:MakeSnapshot()
            self.Pause = true
        else
            self.Pause = false
            self.ActiveDebug = false

            -- Discard the active update thread so we'll definitely start fresh at next update.
            Hekili:ForceUpdate("TOGGLE_PAUSE", true)
        end

        local MouseInteract = self.Pause or self.Config

        for _, group in pairs(ns.UI.Buttons) do
            for _, button in pairs(group) do
                if button:IsShown() then
                    button:EnableMouse(MouseInteract)
                end
            end
        end

        self:Print((not self.Pause and "解除" or "") .. "暂停。")
        if Hekili.DB.profile.notifications.enabled then
            self:Notify((not self.Pause and "解除" or "") .. "暂停")
        end
    end

    -- Key Bindings
    function Hekili:MakeSnapshot(isAuto)
        print("自动快照已调用:", tostring(isAuto))
        print("数据库配置存在:", self.DB and self.DB.profile and "yes" or "no")
        print("自动快照设置:", self.DB and self.DB.profile and self.DB.profile.autoSnapshot or "未知")

        if isAuto and not Hekili.DB.profile.autoSnapshot then
            print("自动快照已禁用，提前返回")
            return
        end

        print("创建快照...")
        print("设置自动快照为:", not isAuto)
        self.ManualSnapshot = not isAuto
        self.ActiveDebug = true

        print("调用 Hekili.Update()...")
        if Hekili.Update then
            Hekili.Update()
            print("Hekili.Update() 完成")
        else
            print("错误：Hekili.Update() 未找到！")
        end

        -- Explicitly call SaveDebugSnapshot for manual snapshots
        if not isAuto then
            if self:SaveDebugSnapshot("Primary") then
                if self.Config then
                    LibStub("AceConfigDialog-3.0"):SelectGroup("Hekili", "snapshots")
                end
            end
        end

        self.ActiveDebug = false
        self.ManualSnapshot = nil

        if HekiliDisplayPrimary then
            HekiliDisplayPrimary.activeThread = nil
            print("重置 HekiliDisplayPrimary.activeThread")
        else
            print("警告：HekiliDisplayPrimary 未找到")
        end

        print("快照创建完成")
    end

    function Hekili:Notify(str, duration)
        if not self.DB.profile.notifications.enabled then
            self:Print(str)
            return
        end

        -- Access the notification text through the global frame reference or fallback
        local notificationText = _G["HekiliNotificationText"] or (ns.UI.Notification and ns.UI.Notification.Text)

        if not notificationText then
            self:Print(str)
            return
        end

        notificationText:SetText(str)
        notificationText:SetTextColor(1, 0.8, 0, 1)
        UIFrameFadeOut(notificationText, duration or 3, 1, 0)
    end

    do
        local modes = {"automatic", "single", "aoe", "dual", "reactive"}

        local modeIndex = {
            automatic = {1, "自动"},
            single = {2, "单目标"},
            aoe = {3, "AOE（多目标）"},
            dual = {4, "固定式双显"},
            reactive = {5, "响应式双显"}
        }

        local toggles = setmetatable({}, {
            __index = function(t, k)
                local name = k:gsub("^(.)", strupper)
                local toggle = Hekili.DB.profile.toggles[k]
                if k == "custom1" or k == "custom2" then
                    name = toggle and toggle.name or name
                elseif k == "cooldowns" then
                    name = "Major Cooldowns"
                    t[k] = name
                end

                return name
            end
        })

        function Hekili:SetMode(mode)
            mode = lower(mode:trim())

            if not modeIndex[mode] then
                Hekili:Print(
                    "切换模式失败：'%s'不是有效的显示模式。\n请尝试使用|cFFFFD100自动|r，|cFFFFD100单目标|r，|cFFFFD100AOE|r，|cFFFFD100双显|r，或者|cFFFFD100响应|r模式。")
                return
            end

            self.DB.profile.toggles.mode.value = mode

            if self.DB.profile.notifications.enabled then
                self:Notify("切换显示模式为：" .. modeIndex[mode][2])
            else
                self:Print(modeIndex[mode][2] .. "模式已激活。")
            end
        end

        function Hekili:FireToggle(name, explicitState)
            local toggle = name and self.DB.profile.toggles[name]
            if not toggle then
                return
            end

            -- Handle mode toggle with explicitState if provided
            if name == 'mode' then
                if explicitState then
                    self:SetMode(explicitState)
                else
                    -- If no explicit state, cycle through available modes
                    local current = toggle.value
                    local c_index = modeIndex[current][1]
                    local i = c_index + 1

                    while true do
                        if i > #modes then
                            i = i % #modes
                        end
                        if i == c_index then
                            break
                        end

                        local newMode = modes[i]
                        if toggle[newMode] then
                            toggle.value = newMode
                            break
                        end
                        i = i + 1
                    end
                    if self.DB.profile.notifications.enabled then
                        self:Notify("模式： " .. modeIndex[toggle.value][2])
                    else
                        self:Print(modeIndex[toggle.value][2] .. " 模式已启用。")
                    end
                end
            elseif name == 'pause' then
                self:TogglePause()
                return
            elseif name == 'snapshot' then
                self:MakeSnapshot()
                return
            else
                -- Handle other toggles with explicit state if provided
                if explicitState == "on" then
                    toggle.value = true
                elseif explicitState == "off" then
                    toggle.value = false
                elseif explicitState == nil then
                    -- Toggle the value if no explicit state is provided
                    toggle.value = not toggle.value
                else
                    -- If an invalid explicitState is provided, print an error
                    self:Print("指定的状态无效。请使用 'on'（开启）或 'off'（关闭）")
                    return
                end

                if toggle.name then
                    toggles[name] = toggle.name
                end

                if self.DB.profile.notifications.enabled then
                    self:Notify(toggles[name] .. ": " .. (toggle.value and "开启" or "关闭"))
                else
                    self:Print(toggles[name] .. (toggle.value and " |cFF00FF00启用|r。" or " |cFFFF0000禁用|r。"))
                end
            end

            if WeakAuras and WeakAuras.ScanEvents then
                WeakAuras.ScanEvents("HEKILI_TOGGLE", name, toggle.value)
            end
            if ns.UI.Minimap then
                ns.UI.Minimap:RefreshDataText()
            end
            self:UpdateDisplayVisibility()
            self:ForceUpdate("HEKILI_TOGGLE", true)
        end

        function Hekili:GetToggleState(name, class)
            local t = name and self.DB.profile.toggles[name]

            return t and t.value
        end
    end
end

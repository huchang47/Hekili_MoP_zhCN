-- Options/ChatCommands.lua
-- Handles /hekili CLI commands.

local addon, ns = ...
local Hekili = _G[ addon ]
local ACD = rawget( _G, "ACD" ) or ( LibStub and LibStub( "AceConfigDialog-3.0", true ) )

local class = Hekili.Class
local scripts = Hekili.Scripts
local state = Hekili.State

local format, lower, match = string.format, string.lower, string.match
local insert, remove, sort, wipe = table.insert, table.remove, table.sort, table.wipe

local tableCopy =  ns.tableCopy

-- Color constants (fallbacks for chat output)
local BlizzBlue = "|cFF00B4FF"

function Hekili:countPriorities()
    local priorities = {}
    local spec = state.spec.id

    for priority, data in pairs( Hekili.DB.profile.packs ) do
        if data.spec == spec then
            table.insert( priorities, priority )
        end
    end

    table.sort( priorities )
    return priorities
end

function Hekili:CmdLine( input )
    -- Trim the input once and handle empty or 'skeleton' input
    input = input and input:trim() or ""

    -- open menu for `/hek` or `/hekili` without additional args
    if input == "" then
        ns.StartConfiguration()
        return
    end

    -- Parse arguments into a table
    local args = {}
    for arg in string.gmatch( input, "%S+" ) do
        table.insert( args, arg )
    end

    -- Alias maps for argument substitutions
    local arg1Aliases = {
        prio        = "priority",
        snap        = "snapshot"
    }
    local arg2Aliases = {
        cd          = "cooldowns",
        cds         = "cooldowns",
        pot         = "potions",
        display     = "mode",
        target_swap = "cycle",
        swap        = "cycle",

        apl         = "pack",
        rotation    = "pack",
        lost        = "lostmyui",

    }
    local arg3Aliases = {
        auto        = "automatic",
        pi          = "infusion",
    }

    -- Apply aliases to arguments
    if args[1] and arg1Aliases[ args[1]:lower() ] then args[1] = arg1Aliases[ args[1]:lower() ] end
    if args[2] and arg2Aliases[ args[2]:lower() ] then args[2] = arg2Aliases[ args[2]:lower() ] end
    if args[3] and arg3Aliases[ args[3]:lower() ] then args[3] = arg3Aliases[ args[3]:lower() ] end

    local command = args[1]

    -- Command handlers mapping
    local commandHandlers = {
        set      = function () self:HandleSetCommand( args ) end,
        profile  = function () self:HandleProfileCommand( args ) end,
        priority = function () self:HandlePriorityCommand( args ) end,
        enable   = function () self:HandleEnableDisableCommand( args ) end,
        disable  = function () self:HandleEnableDisableCommand( args ) end,
        move     = function () self:HandleMoveCommand( args ) end,
        unlock   = function () self:HandleMoveCommand( args ) end,
        lock     = function () self:HandleMoveCommand( args ) end,
        stress   = function () self:RunStressTest() end,
        dotinfo  = function () self:DumpDotInfo( args[2] ) end,
    dump     = function () self:DumpSpecInfo( args[2], args[3] ) end,
        recover  = function () self:HandleRecoverCommand() end,
        fix      = function () self:HandleFixCommand( args ) end,
        snapshot = function () 
            self:Print("快照命令已调用")
            self:MakeSnapshot() 
        end,
        skeleton = function () self:HandleSkeletonCommand( input ) end,
        spectest = function () 
            if ns.TestSpecDetection then
                ns.TestSpecDetection()
            else
                self:Print("专精测试函数不可用")
            end
        end,
        testauras = function()
            self:Print("测试 MoP 光环扫描...")
            
            -- Test basic UnitBuff API first
            self:Print("=== 测试 UnitBuff API ===")
            local testResult = UnitBuff("player", 1)
            self:Print("UnitBuff('player', 1) 返回: %s", tostring(testResult))
            
            -- Test with different filters
            local testResult2 = UnitBuff("player", 1, "HELPFUL")
            self:Print("UnitBuff('player', 1, 'HELPFUL') 返回: %s", tostring(testResult2))
            
            -- Test ALL return values from first buff to see what MoP actually returns
            self:Print("=== 测试 UnitBuff 返回值 ===")
            local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17 = UnitBuff("player", 1)
            self:Print("原始返回值: 1=%s, 2=%s, 3=%s, 4=%s, 5=%s, 6=%s, 7=%s, 8=%s, 9=%s, 10=%s, 11=%s, 12=%s, 13=%s, 14=%s, 15=%s, 16=%s, 17=%s", 
                tostring(r1), tostring(r2), tostring(r3), tostring(r4), tostring(r5), tostring(r6), tostring(r7), tostring(r8), tostring(r9), tostring(r10), 
                tostring(r11), tostring(r12), tostring(r13), tostring(r14), tostring(r15), tostring(r16), tostring(r17))
            
            -- Test player buffs with more verbose output
            self:Print("=== 测试玩家光环 ===")
            local buffCount = 0
            local success, errorMsg = pcall(function()
                for i = 1, 40 do
                    self:Print("检查光环槽位 %d...", i)
                    
                    -- Try to safely call UnitBuff
                    local callSuccess, name, rank, icon, count, debuffType, duration, expires, caster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, isCastByPlayer, v1, v2, v3 = pcall(UnitBuff, "player", i)
                    
                    if not callSuccess then
                        self:Print("ERROR 调用 UnitBuff(%d): %s", i, tostring(name))
                        break
                    end
                    
                    if name then
                        buffCount = buffCount + 1
                        -- Safe conversion of all values to proper types
                        local spellIDNum = tonumber(spellID) or 0
                        local expiresNum = tonumber(expires) or 0
                        local timeLeft = expiresNum > 0 and (expiresNum - GetTime()) or 0
                        self:Print("Buff %d: %s (ID: %d, caster: %s, expires: %.1f)", i, name, spellIDNum, tostring(caster), timeLeft)
                    else
                        self:Print("UnitBuff(%d) returned nil - stopping at %d buffs", i, buffCount)
                        break
                    end
                end
            end)
            
            if not success then
                self:Print("ERROR in buff loop: %s", tostring(errorMsg))
            end
            
            self:Print("Total buffs found: %d", buffCount)
            self:Print("No target selected")
            
            -- Test ScrapeUnitAuras function directly
            self:Print("=== Testing ScrapeUnitAuras ===")
            if state and state.ScrapeUnitAuras then
                state.ScrapeUnitAuras("player", false, "TESTAURAS_BUFFS")
                self:Print("ScrapeUnitAuras completed")
            else
                self:Print("ScrapeUnitAuras not available")
            end
            
            -- Test target debuffs  
            if UnitExists("target") then
                self:Print("=== Target Debuffs ===")
                local debuffCount = 0
                for i = 1, 40 do
                    -- MoP UnitDebuff returns 17 values - catch them all safely
                    local name, rank, icon, count, debuffType, duration, expires, caster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, isCastByPlayer, v1, v2, v3 = UnitDebuff("target", i)
                    if name then
                        debuffCount = debuffCount + 1
                        -- Safe conversion of expires to number
                        local expiresNum = tonumber(expires) or 0
                        local timeLeft = expiresNum > 0 and (expiresNum - GetTime()) or 0
                        self:Print("Debuff %d: %s (ID: %s, caster: %s, expires: %.1f)", i, name, tostring(spellID), tostring(caster), timeLeft)
                    else
                        self:Print("UnitDebuff(%d) returned nil - stopping at %d debuffs", i, debuffCount)
                        break
                    end
                end
                self:Print("Total debuffs found: %d", debuffCount)
            else
                self:Print("No target selected")
            end
            
            -- Test ScrapeUnitAuras
            self:Print("=== Testing ScrapeUnitAuras ===")
            if state and state.ScrapeUnitAuras then
                state.ScrapeUnitAuras("player", false, "manual_test")
                if UnitExists("target") then
                    state.ScrapeUnitAuras("target", false, "manual_test")
                end
                self:Print("ScrapeUnitAuras completed")
            else
                self:Print("ERROR: state.ScrapeUnitAuras not found!")
            end
        end
    }

    -- Execute the corresponding command handler or show error message
    if commandHandlers[ command ] then
        commandHandlers[ command ]()
        self:UpdateDisplayVisibility()
        return true
    elseif command == "help" then
        self:DisplayChatCommandList( "all" )
    else
        self:Print( "无效命令。输入 '/hekili help' 查看可用的命令。" )
        return true
    end
end

-- Simple spec dump: /hekili dump [filter] [detail]
--   filter: 'abilities', 'auras', or a specific ability/aura key to show detail.
--   detail: if provided with 'abilities' or 'auras', limits to entries containing the substring.
function Hekili:DumpSpecInfo( filter, detail )
    local specID = state and state.spec and state.spec.id
    if not specID or not class.specs[ specID ] then
        -- Try to force spec detection once if not initialized yet.
        if self.SpecializationChanged then
            self:SpecializationChanged()
            specID = state and state.spec and state.spec.id
        end
        if not specID or not class.specs[ specID ] then
            -- Fallback: attempt manual Monk spec activation (Windwalker detection) if player is a Monk.
            local _, playerClass = UnitClass("player")
            if playerClass == "MONK" then
                local fallbackID
                -- Rising Sun Kick (107428) is Windwalker-only; if known, pick 269.
                if IsPlayerSpell and IsPlayerSpell(107428) then
                    fallbackID = 269
                else
                    -- Default to Brewmaster (268) if uncertain.
                    fallbackID = 268
                end
                if class.specs[ fallbackID ] then
                    -- Manually activate minimal spec state (subset of SpecializationChanged logic) so we can inspect tables.
                    local specData = class.specs[ fallbackID ]
                    state.spec.id = fallbackID
                    state.spec.key = specData.key
                    state.spec.name = specData.key
                    state.spec[ specData.key ] = true
                    -- Resources
                    for res, model in pairs( specData.resources ) do
                        class.resources[ res ] = model
                        state[ res ] = model.state
                    end
                    for k,v in pairs( specData.resourceAuras ) do
                        class.resourceAuras[ k ] = v
                    end
                    class.primaryResource = specData.primaryResource
                    -- Auras / Abilities / Etc.
                    for k,v in pairs( specData.auras ) do class.auras[k] = v end
                    for k,v in pairs( specData.abilities ) do class.abilities[k] = v end
                    for k,v in pairs( specData.talents ) do class.talents[k] = v end
                    for name, func in pairs( specData.stateExprs ) do class.stateExprs[name] = func end
                    for name, func in pairs( specData.stateFuncs ) do class.stateFuncs[name] = func; rawset(state,name,func) end
                    for name, tbl in pairs( specData.stateTables ) do class.stateTables[name] = tbl; rawset(state,name,tbl) end
                    specID = fallbackID
                    self:Print("(Fallback) Activated %s spec for inspection (ID %d).", specData.key, fallbackID )
                end
            end
            if not specID or not class.specs[ specID ] then
                self:Print("No active spec to dump.")
                local known = {}
                for id,_ in pairs( class.specs ) do if type(id)=="number" and id>0 then known[#known+1]=id end end
                table.sort( known )
                if #known > 0 then self:Print("Known spec IDs: " .. table.concat( known, ", " ) ) end
                return
            end
        end
    end
    local spec = class.specs[ specID ]
    filter = filter and filter:lower() or ""
    detail = detail and detail:lower() or nil

    local function listTable(tbl, label)
        local names = {}
        for k, v in pairs(tbl) do
            if type(k) == 'string' and type(v) == 'table' then
                if not detail or k:lower():find(detail, 1, true) then
                    names[#names+1] = k
                end
            end
        end
        table.sort(names)
        self:Print("%s (%d): %s", label, #names, table.concat(names, ", "))
    end

    if filter == "abilities" or filter == "" then
        if filter == "abilities" or filter == "" then
            listTable(spec.abilities, "Abilities")
        end
    end
    if filter == "auras" or filter == "" then
        listTable(spec.auras, "Auras")
    end

    -- Specific key detail dump.
    if filter ~= "" and filter ~= "abilities" and filter ~= "auras" then
        local key = filter
        local obj = spec.abilities[key] or spec.auras[key]
        if not obj then
            self:Print("No ability or aura named '%s' in spec %d.", key, specID )
            return
        end
        self:Print("Detail for %s:", key)
        for k,v in pairs(obj) do
            if type(v) ~= 'function' then
                self:Print("  %s = %s", tostring(k), tostring(v))
            end
        end
    end
end

function Hekili:HandleSetCommand( args )
    local profile = self.DB.profile
    local mainToggle = args[2] and args[2]:lower()  -- Convert to lowercase
    local subToggleOrState = args[3] and args[3]:lower()
    local explicitState = args[4]

    -- No Main Toggle Provided
    if not mainToggle then
        self:DisplayChatCommandList( "all" )
        return true
    end

    -- Special Case for cycle
    if mainToggle == "cycle" then
        -- Check for whole number minimum time to die (from 0 to 20 seconds)
        local cycleValue = tonumber( subToggleOrState )
        if cycleValue and cycleValue >= 0 and cycleValue <= 20 and floor( cycleValue ) == cycleValue then
            profile.specs[ state.spec.id ].cycle_min = cycleValue
            self:Print( format( "目标切换的最小存活时间已设置为 % d 秒。", cycleValue ) )
        elseif subToggleOrState == nil then
            -- Toggle cycle if no state is provided
            profile.specs[ state.spec.id ].cycle = not profile.specs[ state.spec.id ].cycle
            local toggleStateText = profile.specs[ state.spec.id ].cycle and "|cFF00FF00开启|r" or "|cFFFF0000关闭|r"
            self:Print( format( "目标切换状态已设置为 %s。", toggleStateText ) )
        elseif subToggleOrState == "on" or subToggleOrState == "off" then
            -- Explicitly set cycle to on or off
            local toggleState = ( subToggleOrState == "on" )
            profile.specs[ state.spec.id ].cycle = toggleState
            local toggleStateText = toggleState and "|cFF00FF00开启|r" or "|cFFFF0000关闭|r"
            self:Print( format( "目标切换状态已设置为 %s。", toggleStateText ) )
        else
            -- Invalid parameter handling
            self:Print( "目标切换的指令无效。请使用“on”和“off”和留空进行操作，或者提供一个 0 到 20 之间的整数来设置目标最小存活时间。" )
        end
        self:ForceUpdate( "CLI_TOGGLE" )
        return true
    end

    -- Handle display mode setting
    if mainToggle == "mode" then
        if subToggleOrState then
            self:SetMode( subToggleOrState )
            if WeakAuras and WeakAuras.ScanEvents then WeakAuras.ScanEvents( "HEKILI_TOGGLE", "mode", args[3] ) end
            if ns.UI.Minimap then ns.UI.Minimap:RefreshDataText() end
        return true
        else
            Hekili:FireToggle( "mode" )
        end
        return true
    end

    -- Handle specialization settings
    if mainToggle == "spec" then
        if self:HandleSpecSetting( subToggleOrState, explicitState) then
            return true
        else
            self:Print( "指定的专精设置无效。" )
            return true
        end
    end

    -- Main Toggle and Sub-Toggle Handling
    -- Explicit State Check for Main Toggle
    local toggleCategory = profile.toggles[ mainToggle ]
    if toggleCategory then
        if subToggleOrState == "on" or subToggleOrState == "off" then
            toggleCategory.value = ( subToggleOrState == "on" )
            local stateText = toggleCategory.value and "|cFF00FF00开启|r" or "|cFFFF0000关闭|r"
            self:Print( format( "|cFFFFD100%s|r 当前状态是 %s。", mainToggle, stateText ) )
            self:ForceUpdate( "CLI_TOGGLE" )
            return true
        end

        -- Sub-Toggle Handling with Validation
        if subToggleOrState then
            -- Convert keys of toggleCategory to lowercase to handle case-insensitivity
            local lowerToggleCategory = {}
            for k, v in pairs( toggleCategory) do
                lowerToggleCategory[ k:lower() ] = v
            end

            -- Check if sub-toggle exists in main toggle
            if lowerToggleCategory[ subToggleOrState ] ~= nil then
                if explicitState == "on" or explicitState == "off" then
                    lowerToggleCategory[ subToggleOrState ] = ( explicitState == "on" )
                elseif explicitState == nil then
                    lowerToggleCategory[ subToggleOrState ] = not lowerToggleCategory[ subToggleOrState ]
                else
                    self:Print( "你输入的状态无效，请使用 'on'（开启）或 'off'（关闭）。" )
                    return true
                end

                toggleCategory[ subToggleOrState ] = lowerToggleCategory[ subToggleOrState ]  -- Update the original case-sensitive table
                local stateText = lowerToggleCategory[ subToggleOrState ] and "|cFF00FF00开启|r" or "|cFFFF0000关闭|r"
                self:Print( format( "|cFFFFD100%s_%s|r 当前状态是 %s。", mainToggle, subToggleOrState, stateText ) )
                self:ForceUpdate("CLI_TOGGLE" )
                return true
            else
                self:Print("你指定的开关设置无效。" )
                return true
            end
        end

        -- Default Toggle Behavior for Main Toggle (Toggle)
        self:FireToggle( mainToggle, explicitState )
        local mainToggleState = profile.toggles[ mainToggle ].value and "|cFF00FF00开启|r" or "|cFFFF0000关闭|r"
        self:Print( format( "|cFFFFD100%s|r 当前状态是 %s。", mainToggle, mainToggleState ) )
        self:ForceUpdate( "CLI_TOGGLE" )
        return true
    end
    -- Invalid Toggle or Setting
    self:Print( "你指定的开关或设置无效。" )
    return true
end

function Hekili:HandleFixCommand( args )

    local DB = Hekili.DB
    local profile = DB.profile
    local defaults = DB.defaults
    profile.enabled = true

    local fixType = args[2] and args[2]:lower()  -- Convert to lowercase

    if fixType == "pack" then
        local packName = state.system.packName
        local pack = profile.packs[ packName ]

        if not pack or not pack.builtIn then
            return false
        end

        profile.packs[ packName ] = nil
        Hekili:RestoreDefault( packName )
        Hekili:EmbedPackOptions()
        Hekili:LoadScripts()
        ACD:SelectGroup( "Hekili", "packs", packName )
        if profile.notifications.enabled then
            Hekili:Notify( "你的技能组已重置为默认设置", 6 )
        end

        return true
    end

    if fixType == "lostmyui" then
        local displays = profile.displays
        local displayDefaults = defaults.profile.displays

        for name, display in pairs( displays ) do
            if type( display ) == "table" then
                -- Pull defaults if they exist
                local def = displayDefaults[ name ]

                display.enabled = true
                display.frameStrata = "DIALOG"

                -- Reset anchor and position (use defaults if available)
                display.relativeTo = def and def.relativeTo or "SCREEN"
                display.anchorPoint = def and def.anchorPoint or "BOTTOM"
                display.displayPoint = def and def.displayPoint or "TOP"
                display.x = def and def.x or 0
                display.y = def and def.y or -200

                -- Ensure visibility is sane - initialize complete structure
                display.visibility = display.visibility or {}
                display.visibility.advanced = display.visibility.advanced or false
                
                -- Initialize PvE visibility settings
                display.visibility.pve = display.visibility.pve or {}
                display.visibility.pve.alpha = display.visibility.pve.alpha or 1
                display.visibility.pve.always = display.visibility.pve.always or 1
                display.visibility.pve.target = display.visibility.pve.target or 1
                display.visibility.pve.combat = display.visibility.pve.combat or 1
                display.visibility.pve.combatTarget = display.visibility.pve.combatTarget or 1
                display.visibility.pve.hideMounted = display.visibility.pve.hideMounted or false
                
                -- Initialize PvP visibility settings
                display.visibility.pvp = display.visibility.pvp or {}
                display.visibility.pvp.alpha = display.visibility.pvp.alpha or 1
                display.visibility.pvp.always = display.visibility.pvp.always or 1
                display.visibility.pvp.target = display.visibility.pvp.target or 1
                display.visibility.pvp.combat = display.visibility.pvp.combat or 1
                display.visibility.pvp.combatTarget = display.visibility.pvp.combatTarget or 1
                display.visibility.pvp.hideMounted = display.visibility.pvp.hideMounted or false
                
                -- Initialize mode visibility settings
                display.visibility.mode = display.visibility.mode or {}
                display.visibility.mode.aoe = display.visibility.mode.aoe == nil and true or display.visibility.mode.aoe
                display.visibility.mode.automatic = display.visibility.mode.automatic == nil and true or display.visibility.mode.automatic
                display.visibility.mode.dual = display.visibility.mode.dual == nil and true or display.visibility.mode.dual
                display.visibility.mode.single = display.visibility.mode.single == nil and true or display.visibility.mode.single
                display.visibility.mode.reactive = display.visibility.mode.reactive == nil and true or display.visibility.mode.reactive
            end
        end

        -- Reset display mode to automatic.
        self:SetMode( "automatic" )

        self:Print( "你的用户界面显示已恢复到默认位置和显示状态。" )
        self:BuildUI()
        self:UpdateDisplayVisibility()
        self:ForceUpdate( "CLI_TOGGLE" )
        return true
    end

    if fixType == "toggles" then
        for name, toggle in pairs( profile.toggles ) do
            if type( toggle ) == "table" and toggle.value ~= nil then
                if name == "mode" then
                    -- Skip mode toggle.
                elseif name == "funnel" then
                    self:FireToggle( name, "off" )
                else
                    self:FireToggle( name, "on" )
                end
            end
        end

        self:Print( "除 'funnel'（已禁用）和 'mode'（保持不变）外，所有标准开关已修复（已启用）。" )
        return true
    end

    if fixType == "interrupts" then
        local interrupts = profile.toggles.interrupts
        self:FireToggle( "interrupts", "on" )

        if type( interrupts ) == "table" then
            interrupts.separate = true
        end

        interrupts.castRemainingThreshold = defaults.profile.castRemainingThreshold
        interrupts.filterCasts = defaults.profile.filterCasts

        self:Print( "打断显示已恢复，已设置为独立模式，并且打断调整值已重置。" )
        self:BuildUI()
        self:UpdateDisplayVisibility()
        self:ForceUpdate( "CLI_TOGGLE" )
        return true
    end

    --[[if fixtype == "lowdps" then
        if profile.notifications.enabled then
            Hekili:Notify( "skill issue", 6 )
        end
    end--]]

end

function Hekili:HandleSpecSetting( specSetting, specValue )
    local profile = self.DB.profile
    local settings = class.specs[ state.spec.id ].settings

    -- Search for the spec setting within the settings table
    for i, setting in ipairs( settings ) do
        if setting.name:match( "^" .. specSetting ) then
            if setting.info.type == "toggle" then
                -- If specValue is nil, treat it as a toggle command
                if specValue == nil or specValue == "toggle" then
                    local newValue = not profile.specs[ state.spec.id ].settings[ setting.name ]
                    profile.specs[ state.spec.id ].settings[ setting.name ] = newValue
                    local stateText = newValue and "|cFF00FF00开启|r" or "|cFFFF0000关闭|r"
                    self:Print( format( "%s 已设置为 %s。", setting.name, stateText ) )
                elseif specValue == "on" then
                    profile.specs[state.spec.id].settings[setting.name] = true
                    self:Print( format( "%s 已设置为 |cFF00FF00开启|r。", setting.name ) )
                elseif specValue == "off" then
                    profile.specs[state.spec.id].settings[setting.name] = false
                    self:Print( format( "%s 已设置为 |cFFFF0000关闭|r。", setting.name ) )
                else
                    self:Print( "输入无效。对于切换设置，请使用 'on'、'off'，或留空以进行切换。" )
                end
                return true

            elseif setting.info.type == "range" then
                -- Ensure specValue is a number within the allowed range
                local newValue = tonumber( specValue )
                if newValue and newValue >= ( setting.info.min or -math.huge ) and newValue <= ( setting.info.max or math.huge ) then
                    profile.specs[ state.spec.id ].settings[ setting.name ] = newValue
                    self:Print( format( "%s 已设置为 |cFF00B4FF%.2f|r。", setting.name, newValue ) )
                else
                    self:Print( format( "%s 的值无效。必须介于 %.2f 和 %.2f 之间。", setting.name, setting.info.min or 0, setting.info.max or 100 ) )
                end
                return true
            end
        end
    end

    self:Print( "指定的专精设置无效。" )
    return false
end

function Hekili:DisplayChatCommandList( list )
    local profile = self.DB.profile

    -- Generate and print the "all" overview message.
    if list == "all" then
        self:Print( "使用 |cFFFFD100/hekili set|r 通过聊天命令或宏来调整开关、显示模式和专精设置。\n\n" )
    end

    -- Toggle Options Section
    local function getTogglesChunk()
        return "切换选项:\n" ..
            " - |cFFFFD100冷却技能|r, |cFFFFD100药水|r, |cFFFFD100打断|r 等\n" ..
            " - 示例命令:\n" ..
            "   - 开启冷却技能: |cFFFFD100/hek set cooldowns on|r\n" ..
            "   - 关闭打断: |cFFFFD100/hek set interrupts off|r\n" ..
            "   - 切换防御技能: |cFFFFD100/hek set defensives|r\n\n"
    end

    -- Display Mode Control Section
    local function getModesChunk()
        return format( "显示模式控制 (当前: |cFFFFD100%s|r):\n", profile.toggles.mode.value or "未知" ) ..
            " - 切换模式: |cFFFFD100/hek set mode|r\n" ..
            " - 设置特定模式:\n" ..
            "   - |cFFFFD100/hek set mode automatic|r (自动)\n" ..
            "   - |cFFFFD100/hek set mode single|r (单体)\n" ..
            "   - |cFFFFD100/hek set mode aoe|r (AOE)\n" ..
            "   - |cFFFFD100/hek set mode dual|r (双目标)\n" ..
            "   - |cFFFFD100/hek set mode reactive|r (响应式)\n\n"
    end

    -- Target Swap (Cycle) Setting Section
    local function getCycleChunk()
        return "目标切换设置：\n" ..
            " - 切换目标切换： |cFFFFD100/hek set cycle|r\n" ..
            " - 设置目标切换的最小剩余存活时间： |cFFFFD100/hek set cycle #|r (0-20)\n" ..
            " - 启用： |cFFFFD100/hek set cycle on|r\n" ..
            " - 禁用： |cFFFFD100/hek set cycle off|r\n\n"
    end

    -- Specialization Settings Section
    local function getSpecializationChunk()
        local output = "" .. ( state.spec.name or "你当前专精" ) .. "的专精设置：\n"
        local hasToggle, hasNumber = false, false
        local exToggle, exNumber, exMin, exMax, exStep

        -- Loop through specialization settings if they exist
        local settings = class.specs[ state.spec.id ] and class.specs[ state.spec.id ].settings or {}
        for i, setting in ipairs( settings ) do
            if not setting.info.arg or setting.info.arg() then
                if setting.info.type == "toggle" then
                    output = output .. format(
                        " - |cFFFFD100%s|r = %s|r (%s)\n",
                        setting.name,
                        profile.specs[ state.spec.id ].settings[ setting.name ] and "|cFF00FF00开启" or "|cFFFF0000关闭",
                        type( setting.info.name ) == "function" and setting.info.name() or setting.info.name
                    )
                    hasToggle = true
                    exToggle = setting.name
                elseif setting.info.type == "range" then
                    output = output .. format(
                        " - |cFFFFD100%s|r = |cFF00FF00%.2f|r, 最小： %.2f, 最大： %.2f\n",
                        setting.name,
                        profile.specs[ state.spec.id ].settings[ setting.name ],
                        setting.info.min and format( "%.2f", setting.info.min ) or "无",
                        setting.info.max and format( "%.2f", setting.info.max ) or "无"
                    )
                    hasNumber = true
                    exNumber = setting.name
                    exMin = setting.info.min
                    exMax = setting.info.max
                    exStep = setting.info.step
                end
            end
        end

        -- Example Commands for Specialization Settings
        if hasToggle then
            output = output .. format(
                "\n切换专精设置的命令示例：\n" ..
                " - 切换 开启/关闭： |cFFFFD100/hek set spec %s|r\n" ..
                " - 启用： |cFFFFD100/hek set spec %s on|r\n" ..
                " - 禁用： |cFFFFD100/hek set spec %s off|r\n",
                exToggle, exToggle, exToggle
            )
        end

        if hasNumber then
            -- Adjust range display based on step size
            local rangeFormat = exStep and exStep >= 1 and "%d-%d" or "%.1f-%.1f"
            output = output .. format(
                "\n设置数值的示例命令:\n" ..
                " - 设置一个在范围内的值： |cFFFFD100/hek set spec %s #|r ( " .. rangeFormat .. ")\n",
                exNumber, exMin or 0, exMax or 100
            )
        end

        return output .. "\n"
    end

    -- Other Commands Section (only included with "all")
    local function getOtherCommandsChunk()
        return "其他可用命令：\n" ..
            " - |cFFFFD100/hekili priority|r - 查看或更改优先级设置\n" ..
            " - |cFFFFD100/hekili profile|r - 查看或更改配置文件\n" ..
            " - |cFFFFD100/hekili move|r - 解锁或锁定UI，进行位置调整。\n" ..
            " - |cFFFFD100/hekili enable|r 或者 |cFFFFD100/hekili disable|r - 启用或者禁用插件\n" ..
            " - |cFFFFD100/hekili dump [abilities|auras|<key>] [filter]|r - 导出当前专精数据或特定条目\n"
    end

    -- Determine which sections to print based on the input
    if list == "all" then
        self:Print( getTogglesChunk() )
        self:Print( getModesChunk() )
        self:Print( getCycleChunk() )
        self:Print( getSpecializationChunk() )
        self:Print( getOtherCommandsChunk() )
    elseif list == "toggles" then
        self:Print( getTogglesChunk() )
    elseif list == "modes" then
        self:Print( getModesChunk() )
    elseif list == "cycle" then
        self:Print( getCycleChunk() )
    elseif list == "specialization" then
        self:Print( getSpecializationChunk() )
    end
end

function Hekili:HandleSkeletonCommand( input )
    if input == "skeleton" then
        self.Skeleton = ""  -- must happen BEFORE NotifyChange!
        LibStub("AceConfigRegistry-3.0"):NotifyChange("Hekili")
        self:StartSkeletonListener()
        self:Print( "插件现在将收集专精信息。为获得最佳效果，请选择所有天赋并使用所有技能。" )
    end
end

function Hekili:HandleProfileCommand( args )
    if not args[2] then
        local output = "使用 |cFFFFD100/hekili profile name|r 来切换配置文件。有效的配置文件名称如下："
        for name, prof in ns.orderedPairs( Hekili.DB.profiles ) do
            output = output .. format( "\n - |cFFFFD100%s|r %s", name, Hekili.DB.profile == prof and "|cFF00FF00(当前)|r" or "" )
        end
        self:Print( output )
        return
    end

    local profileName = args[2]
    if not rawget( Hekili.DB.profiles, profileName ) then
        self:Print( "无效的配置名称。请选择一个有效的配置。" )
        return
    end

    self:Print( format( "配置文件已设置为 |cFF00FF00%s|r。", profileName ) )
    self.DB:SetProfile( profileName )
    return
end

function Hekili:HandleEnableDisableCommand( args )
    local enable = args[1] == "enable"
    self.DB.profile.enabled = enable

    for _, buttons in ipairs( ns.UI.Buttons ) do
        for _, button in ipairs( buttons ) do
            if enable then button:Show() else button:Hide() end
        end
    end

    if enable then
        self:Print( "插件已启用。" )
        self:Enable()
    else
        self:Print( "插件已禁用。" )
        self:Disable()
    end
    return
end

function Hekili:HandleMoveCommand( args )
    if InCombatLockdown() then
        self:Print( "战斗中无法解锁UI元素。" )
        return
    end

    if args[1] == "lock" then
        ns.StopConfiguration()
        self:Print( "UI已锁定。" )
    else
        ns.StartConfiguration()
        self:Print( "UI已解锁，可以移动。" )
    end
    return
end

function Hekili:HandleRecoverCommand()
    local defaults = self:GetDefaults()
    for k, v in pairs( self.DB.profile.displays ) do
        local default = defaults.profile.displays[k]
        if default then
            for key, value in pairs( default ) do
                v[ key ] = ( type( value) == "table" ) and tableCopy( value ) or value
            end
        end
    end
    self:RestoreDefaults()
    self:RefreshOptions()
    self:BuildUI()
    self:Print( "默认显示和动作列表已恢复。" )
    return
end

function Hekili:HandlePriorityCommand( args )
    local priorities = self:countPriorities()
    local spec = state.spec.id

    -- Check for "default" keyword as the second argument
    if args[2] == "default" then
        local defaultPriority = nil

        -- Search for the built-in default priority in the current spec
        for _, priority in ipairs( priorities ) do
            if Hekili.DB.profile.packs[ priority ].builtIn then
                defaultPriority = priority
                break
            end
        end

        -- Set the default priority if found
        if defaultPriority then
            Hekili.DB.profile.specs[ spec ].package = defaultPriority
            local output = format("已切换到你当前专精的内置默认优先级：%s%s|r。", Hekili.DB.profile.packs[ defaultPriority ].builtIn and BlizzBlue or "|cFFFFD100", defaultPriority )
            self:Print( output )
            self:ForceUpdate( "CLI_TOGGLE" )
        else
            -- If no built-in default is found, display an error message
            self:Print( "此专精没有内置的默认优先级。" )
        end
        return true
    end

    -- No additional argument provided, show available priorities
    if not args[2] then
        local output = "使用 |cFFFFD100/hekili priority name|r 通过命令行或宏来更改你当前专精的优先级。"

        if #priorities < 2 then
            output = output .. "\n\n|cFFFF0000你必须为你的专精设置多个优先级才能使用此功能。|r"
        else
            output = output .. "\nValid priority |cFFFFD100name|rs are:"
            for _, priority in ipairs( priorities ) do
                local isCurrent = Hekili.DB.profile.specs[ spec ].package == priority
                output = format( "%s\n - %s%s|r %s", output, Hekili.DB.profile.packs[ priority ].builtIn and BlizzBlue or "|cFFFFD100", priority, isCurrent and "|cFF00FF00(当前)|r" or "" )
            end
        end

        output = format( "%s\n\n要创建新的优先级，请查看 |cFFFFD100/hekili|r > |cFFFFD100优先级|r。", output )
        self:Print( output )
        return true
    end

    -- Combine args into full priority name (case-insensitive) if provided
    local rawName = table.concat( args, " ", 2 ):lower()
    local pattern = "^" .. rawName:gsub( "%%", "%%%%" ):gsub( "%^", "%%^" ):gsub( "%$", "%%$" ):gsub( "%(", "%%(" ):gsub( "%)", "%%)" ):gsub( "%.", "%%." ):gsub( "%[", "%%[" ):gsub( "%]", "%%]" ):gsub( "%*", "%%*" ):gsub( "%+", "%%+" ):gsub( "%-", "%%-" ):gsub( "%?", "%%?" )

    for _, priority in ipairs( priorities ) do
        if priority:lower():match( pattern ) then
            Hekili.DB.profile.specs[ spec ].package = priority
            local output = format( "优先级已设置为 %s%s|r。", Hekili.DB.profile.packs[ priority ].builtIn and BlizzBlue or "|cFFFFD100", priority )
            self:Print( output )
            self:ForceUpdate( "CLI_TOGGLE" )
            return true
        end
    end

    -- If no matching priority found, display valid options
    local output = format( "未找到优先级 '%s' 的匹配项。\n有效选项如下：", rawName )
    for i, priority in ipairs( priorities ) do
        output = output .. format( " %s%s|r%s", Hekili.DB.profile.packs[ priority ].builtIn and BlizzBlue or "|cFFFFD100", priority, i == #priorities and "." or "," )
    end
    self:Print( output )
    return true
end

function Hekili:HandlePetSetupCommand()
    self:Print( "=== Pet Ability Setup Guide ===" )
    self:Print( "1. Make sure your pet is summoned and alive" )
    self:Print( "2. Open your pet's spellbook (P key, then Pet tab)" )
    self:Print( "3. Pet abilities will be automatically detected from pet action bar" )
    self:Print( "4. No need to drag abilities to player action bars!" )
    self:Print( "5. Check status with: /hekili pet status" )
    
    if self:CanUsePetBasedTargetDetection() then
        local spells = self:GetPetBasedTargetSpells()
        self:Print( "Supported abilities for your class:" )
        for spellID, range in pairs( spells ) do
            if type( spellID ) == "number" and spellID == spells.best then
                local name = GetSpellInfo( spellID )
                self:Print( "  BEST: " .. spellID .. " - " .. (name or "Unknown") .. " (" .. range .. " yards)" )
            end
        end
    end
end

function Hekili:HandlePetStatusCommand()
    local status = self:GetPetAbilityDetectionStatus()
    self:Print( "Pet Detection Status: " .. status )
    
    if self:CanUsePetBasedTargetDetection() then
        local spells = self:GetPetBasedTargetSpells()
        self:Print( "Supported pet abilities for your class:" )
        for spellID, range in pairs( spells ) do
            if type( spellID ) == "number" then
                local name = GetSpellInfo( spellID )
                self:Print( "  " .. spellID .. " - " .. (name or "Unknown") .. " (" .. range .. " yards)" )
            end
        end
        
        if not UnitExists( "pet" ) then
            self:Print( "|cFFFF0000WARNING:|r No pet is currently summoned!" )
        elseif UnitIsDead( "pet" ) then
            self:Print( "|cFFFF0000WARNING:|r Your pet is dead!" )
        end
    end
end

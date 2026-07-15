local dispelSpells = {
    Poison = {
        "Roll Back",           -- Chronomancer (Universal Dispel)
        "Sanctify",            -- Sun Cleric (Dispel: Magic, Poison, Disease)
        "Elune's Purification",-- Starcaller (Poison & Disease)
        "Antivenom",          -- Venomancer
        "Cure Poison",         
    },
    Curse = {
        "Roll Back",           -- Chronomancer (Universal Dispel)
        "Hexbreak",           -- Witch Doctor (Bound to Right Click)
        "Blight Antidote",    -- Venomancer (Talent)
        "Devour Curse",       -- Cultist (Talent)
        "Remove Curse",        
    },
    Magic = {
        "Roll Back",           -- Chronomancer (Universal Dispel)
        "Sanctify",            -- Sun Cleric (Dispel: Magic, Poison, Disease)
        "Burn Impurities",    -- Pyromancer (Talent - Bound to Left Click)
        "Devour Magic",       -- Cultist
        "Dispel Magic",
        "Cleanse",
    },
    Disease = {
        "Roll Back",           -- Chronomancer (Universal Dispel)
        "Sanctify",            -- Sun Cleric (Dispel: Magic, Poison, Disease)
        "Elune's Purification",-- Starcaller (Poison & Disease)
        "Burn Impurities",    -- Pyromancer (Talent - Bound to Left Click)
        "Cure Disease",
        "Purify",
    },
    Bleed = {
        "Roll Back",           -- Chronomancer (Universal Dispel)
        "Cauterize",          -- Pyromancer (Talent - Bound to Right Click)
    }
}

local activeSpells = { Poison = nil, Curse = nil, Magic = nil, Disease = nil, Bleed = nil }

local function ScanPlayerSpellbook()
    for category, spellList in pairs(dispelSpells) do
        activeSpells[category] = nil 
        for _, spellName in ipairs(spellList) do
            if GetSpellInfo(spellName) then
                activeSpells[category] = spellName 
                break 
            end
        end
    end
end

local frame = CreateFrame("Frame", "DecursiveLiteMain", UIParent)
frame:SetWidth(227)
frame:SetHeight(50)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:SetClampedToScreen(true)

local customAlertSound = "Interface\\AddOns\\DecursiveLite\\Sounds\\AfflictionAlert.ogg"

-- FIXED BUG: Create a private, dedicated scanner tooltip. 
-- This completely prevents stealing focus from the player's primary GameTooltip!
local scanTooltip = CreateFrame("GameTooltip", "DecursiveLiteScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local handle = CreateFrame("Button", "DecursiveLiteHandle", frame)
handle:SetWidth(8)
handle:SetHeight(8)
handle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
handle:EnableMouse(true)
handle:RegisterForDrag("LeftButton")

local handleTex = handle:CreateTexture(nil, "BACKGROUND")
handleTex:SetAllPoints(handle)
handleTex:SetTexture(0.2, 0.2, 0.2, 0.8)

local handleBorder = handle:CreateTexture(nil, "OVERLAY")
handleBorder:SetAllPoints(handle)
handleBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
handleBorder:SetVertexColor(0.4, 0.4, 0.4, 1)

handle:SetAlpha(0)

handle:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then frame:StartMoving() end
end)
handle:SetScript("OnDragStop", function(self)
    frame:StopMovingOrSizing()
end)
handle:SetScript("OnEnter", function(self)
    self:SetAlpha(1) 
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine("DecursiveLite Anchor", 1, 1, 1)
    GameTooltip:AddLine("Hold Shift to drag this frame.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
handle:SetScript("OnLeave", function(self)
    self:SetAlpha(0) 
    GameTooltip:Hide() 
end)

local debuffColors = {
    Magic   = {0.2, 0.2, 1.0}, 
    Curse   = {0.6, 0.0, 1.0}, 
    Poison  = {0.0, 0.6, 0.0}, 
    Disease = {0.6, 0.4, 0.0}, 
    Bleed   = {0.8, 0.1, 0.1}, 
}

local buttons = {} 
local activeUnits = {} 
local soundPlayed = false
local isTesting = false
local myName = UnitName("player")

local function GetDB(key)
    local db = DecursiveLiteDB or {}
    if key == "borderStyle" then return db.borderStyle or "soft" end
    if key == "size" then return db.size or 20 end
    if key == "maxPerRow" then return db.maxPerRow or 10 end
    if key == "hideSolo" then return db.hideSolo == nil and false or db.hideSolo end
    return nil
end

local function SetDB(key, value)
    if DecursiveLiteDB and DecursiveLiteDB.profiles and DecursiveLiteDB.profiles[myName] then
        DecursiveLiteDB.profiles[myName][key] = value
    end
end

local function GetUnitDebuffType(unit, index)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff(unit, index)
    if not name then return nil end
    
    if debuffType and debuffType ~= "" then
        return debuffType
    end
    
    if activeSpells.Bleed then
        -- FIXED BUG: Scans using the private scanTooltip instead of GameTooltip!
        scanTooltip:ClearLines()
        scanTooltip:SetUnitDebuff(unit, index)
        for i = 1, scanTooltip:NumLines() do
            local leftLine = _G["DecursiveLiteScanTooltipTextLeft"..i]
            local text = leftLine and leftLine:GetText()
            if text and string.find(text, "Bleed") then
                return "Bleed"
            end
        end
    end
    
    return nil
end

local function PlayerCanDispel(debuffType)
    if isTesting then return true end
    return activeSpells[debuffType] ~= nil
end

local function GetBestDispelMacro(unit, clickType)
    if not UnitExists(unit) then return "" end
    
    local targetDebuff = nil
    for i = 1, 40 do
        local debuffType = GetUnitDebuffType(unit, i)
        if not debuffType then 
            if not UnitDebuff(unit, i) then break end
        end
        
        if debuffType and PlayerCanDispel(debuffType) then
            targetDebuff = debuffType
            break
        end
    end

    if targetDebuff and activeSpells[targetDebuff] then
        return "/cast [@"..unit.."] " .. activeSpells[targetDebuff]
    end

    if clickType == "left" then
        if activeSpells.Poison then return "/cast [@"..unit.."] " .. activeSpells.Poison end
        if activeSpells.Magic then return "/cast [@"..unit.."] " .. activeSpells.Magic end
    elseif clickType == "right" then
        if activeSpells.Curse then return "/cast [@"..unit.."] " .. activeSpells.Curse end
        if activeSpells.Bleed then return "/cast [@"..unit.."] " .. activeSpells.Bleed end
        if activeSpells.Disease then return "/cast [@"..unit.."] " .. activeSpells.Disease end
    end

    return ""
end

local function CheckAllGroupDebuffs()
    local anyoneAfflictedAndInRange = isTesting
    
    if not anyoneAfflictedAndInRange then
        for u, _ in pairs(buttons) do
            if UnitExists(u) and activeUnits[u] then
                if u == "player" or UnitInRange(u) then
                    for i = 1, 40 do
                        local debuffType = GetUnitDebuffType(u, i)
                        if not debuffType and not UnitDebuff(u, i) then break end
                        if debuffType and PlayerCanDispel(debuffType) then
                            anyoneAfflictedAndInRange = true
                            break
                        end
                    end
                end
            end
        end
    end
    
    if anyoneAfflictedAndInRange then
        if not soundPlayed then
            PlaySoundFile(customAlertSound) 
            soundPlayed = true
        end
    else
        soundPlayed = false
    end
end

local function GetCurrentUISettings()
    if GetDB("borderStyle") == "soft" then
        return 0.5, 0.08, 0.3
    else
        return 0.8, 0.1, 0.45
    end
end

local function UpdateUnitBorderColor(unit, button)
    if not UnitExists(unit) then return end
    local borderAlpha = GetCurrentUISettings()

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        button:SetBackdropBorderColor(color.r, color.g, color.b, borderAlpha)
    else
        button:SetBackdropBorderColor(0.5, 0.5, 0.5, borderAlpha)
    end
end

local function UpdateUnitRaidTarget(unit, button)
    if not UnitExists(unit) then 
        button.raidIcon:Hide()
        return 
    end

    local index = GetRaidTargetIndex(unit)
    if index then
        SetRaidTargetIconTexture(button.raidIcon, index)
        button.raidIcon:Show()
    else
        button.raidIcon:Hide()
    end
end

local function UpdateUnitDebuff(unit, button)
    if not UnitExists(unit) then return end
    local hasDebuff = false
    
    for i = 1, 40 do
        local debuffType = GetUnitDebuffType(unit, i)
        if not debuffType and not UnitDebuff(unit, i) then break end
        
        if debuffType and debuffColors[debuffType] and PlayerCanDispel(debuffType) then
            local color = debuffColors[debuffType]
            button:SetBackdropColor(color[1], color[2], color[3], 1.0)
            button.innerBG:SetVertexColor(color[1], color[2], color[3], 1.0)
            hasDebuff = true; break
        end
    end

    if not hasDebuff then
        local _, bgAlpha, innerAlpha = GetCurrentUISettings()
        button:SetBackdropColor(0, 0.15, 0.05, bgAlpha)      
        button.innerBG:SetVertexColor(0.02, 0.15, 0.05, innerAlpha) 
    end

    UpdateUnitBorderColor(unit, button)
    UpdateUnitRaidTarget(unit, button)
end

local function UpdateAllActiveFrames()
    local bSize = GetDB("size")
    for unit, btn in pairs(buttons) do
        btn:SetWidth(bSize)
        btn:SetHeight(bSize)
        if btn:IsShown() then
            UpdateUnitDebuff(unit, btn)
        end
    end
end

local function UpdateGroupRoster()
    for k, v in pairs(activeUnits) do activeUnits[k] = false end
    
    local inRaid = GetNumRaidMembers() > 0
    local inParty = GetNumPartyMembers() > 0
    
    if GetDB("hideSolo") and not inRaid and not inParty and not isTesting then
        return 
    end

    if inRaid then
        for i = 1, GetNumRaidMembers() do activeUnits["raid"..i] = true end
    elseif inParty then
        activeUnits["player"] = true
        for i = 1, GetNumPartyMembers() do activeUnits["party"..i] = true end
    else
        activeUnits["player"] = true
    end
end

local function GetOrCreateButton(unit)
    if buttons[unit] then return buttons[unit] end
    local btn = CreateFrame("Button", "DecursiveLiteBtn_"..unit, frame, "SecureActionButtonTemplate")
    local currentSize = GetDB("size")
    btn:SetWidth(currentSize)
    btn:SetHeight(currentSize)
    
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    local innerBG = btn:CreateTexture(nil, "ARTWORK")
    innerBG:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    innerBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2) 
    innerBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.innerBG = innerBG

    local raidIcon = btn:CreateTexture(nil, "OVERLAY")
    raidIcon:SetWidth(10)
    raidIcon:SetHeight(10)
    raidIcon:SetPoint("TOP", btn, "TOP", 0, 4) 
    raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raidIcon:Hide()
    btn.raidIcon = raidIcon

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnEnter", function(self)
        if UnitExists(unit) then
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    buttons[unit] = btn
    return btn
end

local function RefreshButtonVisibility()
    if InCombatLockdown() then return end
    ScanPlayerSpellbook()
    UpdateGroupRoster()

    for _, btn in pairs(buttons) do
        btn:Hide()
        btn:SetAttribute("macrotext1", nil)
        btn:SetAttribute("macrotext2", nil)
    end

    local visibleCount = 0
    local checkOrder = {"player", "party1", "party2", "party3", "party4"}
    for i = 1, 40 do table.insert(checkOrder, "raid"..i) end

    local bSize = GetDB("size")
    local bSpacing = 3
    local maxPerRow = GetDB("maxPerRow")

    for _, unit in ipairs(checkOrder) do
        if activeUnits[unit] and UnitExists(unit) then
            local btn = GetOrCreateButton(unit)
            btn:SetWidth(bSize)
            btn:SetHeight(bSize)
            
            local row = math.floor(visibleCount / maxPerRow)
            local col = visibleCount % maxPerRow
            
            local xOffset = col * (bSize + bSpacing)
            local yOffset = -(row * (bSize + bSpacing))
            
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset, yOffset)
            
            btn:SetAttribute("type1", "macro")
            btn:SetAttribute("macrotext1", GetBestDispelMacro(unit, "left"))
            
            btn:SetAttribute("type2", "macro")
            btn:SetAttribute("macrotext2", GetBestDispelMacro(unit, "right"))
            
            UpdateUnitDebuff(unit, btn)
            
            btn:SetAlpha(1.0)
            btn:Show()
            visibleCount = visibleCount + 1
        end
    end
    CheckAllGroupDebuffs()
end

frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("RAID_TARGET_UPDATE") 
frame:RegisterEvent("VARIABLES_LOADED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if buttons[unit] and activeUnits[unit] then
            if UnitExists(unit) then UpdateUnitDebuff(unit, buttons[unit]) end
            CheckAllGroupDebuffs()
        end
    elseif event == "UI_ERROR_MESSAGE" then
        local msg = ...
        if msg == SPELL_FAILED_LINE_OF_SIGHT or msg == SPELL_FAILED_OUT_OF_RANGE or msg == SPELL_FAILED_BAD_TARGETS then
            PlaySoundFile("Sound\\Spells\\Fizzle\\FizzleHoly.wav")
        end
    elseif event == "RAID_TARGET_UPDATE" then
        for unit, btn in pairs(buttons) do
            if btn:IsShown() then
                UpdateUnitRaidTarget(unit, btn)
            end
        end
    elseif event == "VARIABLES_LOADED" then
        if not DecursiveLiteDB then DecursiveLiteDB = {} end
        if not DecursiveLiteDB.profiles then DecursiveLiteDB.profiles = {} end
        
        if not DecursiveLiteDB.profiles[myName] then
            DecursiveLiteDB.profiles[myName] = {
                borderStyle = "soft",
                size = 20,
                maxPerRow = 10,
                hideSolo = false
            }
        end
        UpdateAllActiveFrames()
    else
        RefreshButtonVisibility()
    end
end)

ScanPlayerSpellbook()
RefreshButtonVisibility()

SLASH_DECURSIVELITE1 = "/dl"
SLASH_DECURSIVELITE2 = "/decursivelite"

local function ResetFramePosition()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    print("|cFF00FF00DecursiveLite:|r Frame position has been reset to the center of your screen.")
end

local function LockFrame()
    handle:Hide()
    handle:EnableMouse(false)
    print("|cFF00FF00DecursiveLite:|r Frame is now |cFFFF0000LOCKED|r.")
end

local function UnlockFrame()
    handle:Show()
    handle:EnableMouse(true)
    handle:SetAlpha(1)
    print("|cFF00FF00DecursiveLite:|r Frame is now |cFF00FF00UNLOCKED|r. Hold Shift on the tiny handle above the first button to drag.")
end

local function ToggleTestMode()
    isTesting = not isTesting
    soundPlayed = false
    
    if isTesting then
        print("|cFF00FF00DecursiveLite:|r Test mode |cFF00FF00ENABLED|r. Simulating debuffs & audio alert...")
        RefreshButtonVisibility() 
        local types = {"Magic", "Curse", "Poison", "Disease", "Bleed"}
        local count = 1
        for _, btn in pairs(buttons) do
            if btn:IsShown() then
                local fakeDebuff = types[(count % #types) + 1]
                local color = debuffColors[fakeDebuff]
                btn:SetBackdropColor(color[1], color[2], color[3], 1.0)
                btn.innerBG:SetVertexColor(color[1], color[2], color[3], 1.0)
                count = count + 1
            end
        end
    else
        print("|cFF00FF00DecursiveLite:|r Test mode |cFFFF0000DISABLED|r. Reverting to normal.")
        RefreshButtonVisibility()
    end
end

SlashCmdList["DECURSIVELITE"] = function(msg)
    local cmd, arg = string.split(" ", msg:lower())
    
    if cmd == "reset" then
        ResetFramePosition()
    elseif cmd == "lock" then
        LockFrame()
    elseif cmd == "unlock" then
        UnlockFrame()
    elseif cmd == "test" then
        ToggleTestMode()
    else
        print("|cFF00FF00DecursiveLite Commands:|r")
        print("  |cFF00FF00/dl reset|r - Resets the grid position.")
        print("  |cFF00FF00/dl lock|r - Locks the frame.")
        print("  |cFF00FF00/dl unlock|r - Unlocks the frame.")
        print("  |cFF00FF00/dl test|r - Toggles simulated test debuffs.")
    end
end

local panel = CreateFrame("Frame", "DecursiveLiteOptionsPanel", UIParent)
panel.name = "DecursiveLite"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cFF00FF00DecursiveLite|r - Configurations")

local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
desc:SetText("A lightweight and highly optimized decurse grid built specifically for Ascension (CoA).")

local dropdownHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
dropdownHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
dropdownHeader:SetText("Grid Frame Visual Style:")

local styleDropdown = CreateFrame("Frame", "DecursiveLiteStyleDropdown", panel, "UIDropDownMenuTemplate")
styleDropdown:SetPoint("TOPLEFT", dropdownHeader, "BOTTOMLEFT", -15, -2)
UIDropDownMenu_SetWidth(styleDropdown, 160)

local function StyleDropdown_OnClick(self)
    UIDropDownMenu_SetSelectedValue(styleDropdown, self.value)
    SetDB("borderStyle", self.value)
    UpdateAllActiveFrames()
end

local function StyleDropdown_Initialize()
    local info = UIDropDownMenu_CreateInfo()
    info.text = "Soft Borders (Default)"
    info.value = "soft"
    info.func = StyleDropdown_OnClick
    info.checked = (GetDB("borderStyle") == "soft")
    UIDropDownMenu_AddButton(info)
    
    info.text = "Bright Borders (Legacy)"
    info.value = "bright"
    info.func = StyleDropdown_OnClick
    info.checked = (GetDB("borderStyle") == "bright")
    UIDropDownMenu_AddButton(info)
end

local profileHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
profileHeader:SetPoint("LEFT", dropdownHeader, "LEFT", 185, 0)
profileHeader:SetText("Copy Profile From Character:")

local profileDropdown = CreateFrame("Frame", "DecursiveLiteProfileDropdown", panel, "UIDropDownMenuTemplate")
profileDropdown:SetPoint("TOPLEFT", profileHeader, "BOTTOMLEFT", -15, -2)
UIDropDownMenu_SetWidth(profileDropdown, 160)

local function ProfileDropdown_OnClick(self)
    local sourceChar = self.value
    if DecursiveLiteDB and DecursiveLiteDB.profiles and DecursiveLiteDB.profiles[sourceChar] then
        local src = DecursiveLiteDB.profiles[sourceChar]
        SetDB("borderStyle", src.borderStyle or "soft")
        SetDB("size", src.size or 20)
        SetDB("maxPerRow", src.maxPerRow or 10)
        SetDB("hideSolo", src.hideSolo == nil and false or src.hideSolo)
        
        UpdateAllActiveFrames()
        if not InCombatLockdown() then RefreshButtonVisibility() end
        
        _G["DecursiveLiteSizeSlider"]:SetValue(GetDB("size"))
        _G["DecursiveLiteRowSlider"]:SetValue(GetDB("maxPerRow"))
        _G["DecursiveLiteSoloCheck"]:SetChecked(GetDB("hideSolo"))
        if GetDB("borderStyle") == "bright" then UIDropDownMenu_SetText(styleDropdown, "Bright Borders (Legacy)")
        else UIDropDownMenu_SetText(styleDropdown, "Soft Borders (Default)") end
        
        print("|cFF00FF00DecursiveLite:|r Successfully copied profile from |cFFFFD100" .. sourceChar .. "|r!")
    end
    UIDropDownMenu_SetText(profileDropdown, "Select Character Profile")
end

local function ProfileDropdown_Initialize()
    local info = UIDropDownMenu_CreateInfo()
    if not DecursiveLiteDB or not DecursiveLiteDB.profiles then return end
    
    local hasProfiles = false
    for name, _ in pairs(DecursiveLiteDB.profiles) do
        if name ~= myName then 
            info.text = name
            info.value = name
            info.func = ProfileDropdown_OnClick
            info.checked = false
            UIDropDownMenu_AddButton(info)
            hasProfiles = true
        end
    end
    
    if not hasProfiles then
        info.text = "No other profiles found"
        info.value = nil
        info.func = nil
        info.disabled = true
        UIDropDownMenu_AddButton(info)
    end
end

local sizeSlider = CreateFrame("Slider", "DecursiveLiteSizeSlider", panel, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", styleDropdown, "BOTTOMLEFT", 15, -24)
sizeSlider:SetMinMaxValues(14, 32)
sizeSlider:SetValueStep(1)
_G[sizeSlider:GetName() .. "Low"]:SetText("14px")
_G[sizeSlider:GetName() .. "High"]:SetText("32px")

local function UpdateSizeSliderLabel(val)
    _G[sizeSlider:GetName() .. "Text"]:SetText("Button Size: |cFF00FF00" .. val .. "px|r")
end

sizeSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    UpdateSizeSliderLabel(val)
    SetDB("size", val)
    UpdateAllActiveFrames()
    if not InCombatLockdown() then RefreshButtonVisibility() end
end)

local rowSlider = CreateFrame("Slider", "DecursiveLiteRowSlider", panel, "OptionsSliderTemplate")
rowSlider:SetPoint("LEFT", sizeSlider, "RIGHT", 45, 0)
rowSlider:SetMinMaxValues(2, 20)
rowSlider:SetValueStep(1)
_G[rowSlider:GetName() .. "Low"]:SetText("2")
_G[rowSlider:GetName() .. "High"]:SetText("20")

local function UpdateRowSliderLabel(val)
    _G[rowSlider:GetName() .. "Text"]:SetText("Max Buttons Per Row: |cFF00FF00" .. val .. "|r")
end

rowSlider:SetScript("OnValueChanged", function(self, value)
    local val = math.floor(value)
    UpdateRowSliderLabel(val)
    SetDB("maxPerRow", val)
    if not InCombatLockdown() then RefreshButtonVisibility() end
end)

local soloCheck = CreateFrame("CheckButton", "DecursiveLiteSoloCheck", panel, "InterfaceOptionsCheckButtonTemplate")
soloCheck:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", -4, -18)
_G[soloCheck:GetName() .. "Text"]:SetText("Hide Grid Container When Solo")

soloCheck:SetScript("OnClick", function(self)
    SetDB("hideSolo", self:GetChecked() and true or false)
    if not InCombatLockdown() then RefreshButtonVisibility() end
end)

panel:SetScript("OnShow", function()
    UIDropDownMenu_Initialize(styleDropdown, StyleDropdown_Initialize)
    if GetDB("borderStyle") == "bright" then 
        UIDropDownMenu_SetText(styleDropdown, "Bright Borders (Legacy)")
    else 
        UIDropDownMenu_SetText(styleDropdown, "Soft Borders (Default)") 
    end

    UIDropDownMenu_Initialize(profileDropdown, ProfileDropdown_Initialize)
    UIDropDownMenu_SetText(profileDropdown, "Select Character Profile")

    sizeSlider:SetValue(GetDB("size"))
    UpdateSizeSliderLabel(GetDB("size"))

    rowSlider:SetValue(GetDB("maxPerRow"))
    UpdateRowSliderLabel(GetDB("maxPerRow"))

    soloCheck:SetChecked(GetDB("hideSolo"))
end)

local guideHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
guideHeader:SetPoint("TOPLEFT", soloCheck, "BOTTOMLEFT", 4, -16)
guideHeader:SetText("Quick Guide & Click Maps:")

local guideText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
guideText:SetPoint("TOPLEFT", guideHeader, "BOTTOMLEFT", 10, -6)
guideText:SetJustifyH("LEFT")
guideText:SetText(
    "- |cFF00FF00Mouse Drag:|r Type |cFF00FF00/dl unlock|r, hold |cFF00FF00Shift|r, and drag the tiny anchor box.\n" ..
    "- |cFF00FF00Left-Click Action:|r Triggers standard Poison / Magic dispel priorities.\n" ..
    "- |cFF00FF00Right-Click Action:|r Triggers standard Curse / Disease / Bleed dispel priorities.\n" ..
    "- |cFF00FF00Profile Manager:|r Select any alternate character from the dropdown to inherit their settings instantly."
)

local btnHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
btnHeader:SetPoint("TOPLEFT", guideText, "BOTTOMLEFT", -10, -16)
btnHeader:SetText("Interactive Core Actions:")

local btnReset = CreateFrame("Button", "DecursiveLiteOptReset", panel, "UIPanelButtonTemplate")
btnReset:SetWidth(110)
btnReset:SetHeight(24)
btnReset:SetPoint("TOPLEFT", btnHeader, "BOTTOMLEFT", 0, -8)
btnReset:SetText("Reset Position")
btnReset:SetScript("OnClick", function() ResetFramePosition() end)

local isLockedOpt = true
local btnLock = CreateFrame("Button", "DecursiveLiteOptLock", panel, "UIPanelButtonTemplate")
btnLock:SetWidth(110)
btnLock:SetHeight(24)
btnLock:SetPoint("LEFT", btnReset, "RIGHT", 10, 0)
btnLock:SetText("Unlock / Lock")
btnLock:SetScript("OnClick", function()
    isLockedOpt = not isLockedOpt
    if isLockedOpt then LockFrame() else UnlockFrame() end
end)

local btnTest = CreateFrame("Button", "DecursiveLiteOptTest", panel, "UIPanelButtonTemplate")
btnTest:SetWidth(110)
btnTest:SetHeight(24)
btnTest:SetPoint("LEFT", btnLock, "RIGHT", 10, 0)
btnTest:SetText("Toggle Test Mode")
btnTest:SetScript("OnClick", function() ToggleTestMode() end)

InterfaceOptions_AddCategory(panel)

print("|cFF00FF00DecursiveLite Beta by Pawie @ Vol'jin successfully loaded!|r")
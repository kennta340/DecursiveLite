-- =========================================================================
-- SPELL LIBRARY (Add new classes and spells here!)
-- =========================================================================
local dispelSpells = {
    Poison = {
        "Elune's Purification",-- Starcaller (Poison & Disease)
        "Antivenom",          -- Venomancer
        "Cure Poison",         
    },
    Curse = {
        "Hexbreak",           -- Witch Doctor (Bound to Right Click)
        "Blight Antidote",    -- Venomancer (Talent)
        "Devour Curse",       -- Cultist (Talent)
        "Remove Curse",        
    },
    Magic = {
        "Burn Impurities",    -- Pyromancer (Talent - Bound to Left Click)
        "Devour Magic",       -- Cultist
        "Dispel Magic",
        "Cleanse",
    },
    Disease = {
        "Elune's Purification",-- Starcaller (Poison & Disease)
        "Burn Impurities",    -- Pyromancer (Talent - Bound to Left Click)
        "Cure Disease",
        "Purify",
    },
    Bleed = {
        "Cauterize",          -- Pyromancer (Talent - Bound to Right Click)
    }
}

-- =========================================================================
-- ADDON LOGIC & CONFIGURATION
-- =========================================================================
local frame = CreateFrame("Frame", "DecursiveLiteMain", UIParent)
frame:SetSize(227, 50) 
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:SetClampedToScreen(true)

-- Tiny anchor handle placed directly above the first button
local handle = CreateFrame("Button", "DecursiveLiteHandle", frame)
handle:SetSize(8, 8)
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
    Magic   = {0.2, 0.2, 0.8}, -- Blue
    Curse   = {0.8, 0.2, 0.8}, -- Purple
    Poison  = {0.2, 0.8, 0.2}, -- Green
    Disease = {0.6, 0.4, 0.2}, -- Brown
    Bleed   = {0.8, 0.1, 0.1}, -- Red
}

local activeSpells = { Poison = nil, Curse = nil, Magic = nil, Disease = nil, Bleed = nil }
local buttons = {} 
local activeUnits = {} 
local soundPlayed = false

local BUTTON_SIZE = 20
local BUTTON_SPACING = 3
local BUTTONS_PER_ROW = 10 

-- Scan spellbook
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

-- Custom checker to identify Bleeds since WoW returns nil type for them
local function GetUnitDebuffType(unit, index)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff(unit, index)
    if not name then return nil end
    
    if debuffType and debuffType ~= "" then
        return debuffType
    end
    
    if activeSpells.Bleed then
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:SetUnitDebuff(unit, index)
        for i = 1, GameTooltip:NumLines() do
            local text = _G["GameTooltipTextLeft"..i]:GetText()
            if text and string.find(text, "Bleed") then
                GameTooltip:Hide()
                return "Bleed"
            end
        end
        GameTooltip:Hide()
    end
    
    return nil
end

local function PlayerCanDispel(debuffType)
    return activeSpells[debuffType] ~= nil
end

-- Determine best macro
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
    local anyoneAfflictedAndInRange = false
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
    
    if anyoneAfflictedAndInRange then
        if not soundPlayed then
            PlaySoundFile("Sound\\interface\\AlarmClockWarning3.wav")
            soundPlayed = true
        end
    else
        soundPlayed = false
    end
end

-- Sets the border (edge) to Class Color using WoW's native backdrop system
local function UpdateUnitBorderColor(unit, button)
    if not UnitExists(unit) then return end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        button:SetBackdropBorderColor(color.r, color.g, color.b, 0.8)
    else
        button:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end
end

-- Scans the target player for a Raid Icon and draws it at the top-center of the button
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
        button:SetBackdropColor(0, 0, 0, 0.05) 
        button.innerBG:SetVertexColor(0.01, 0.02, 0.01, 0.4) 
    end

    -- Update border and raid marks
    UpdateUnitBorderColor(unit, button)
    UpdateUnitRaidTarget(unit, button)
end

local function UpdateGroupRoster()
    for k, v in pairs(activeUnits) do activeUnits[k] = false end
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do activeUnits["raid"..i] = true end
    elseif GetNumPartyMembers() > 0 then
        activeUnits["player"] = true
        for i = 1, GetNumPartyMembers() do activeUnits["party"..i] = true end
    else
        activeUnits["player"] = true
    end
end

local function GetOrCreateButton(unit)
    if buttons[unit] then return buttons[unit] end
    local btn = CreateFrame("Button", "DecursiveLiteBtn_"..unit, frame, "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })

    local innerBG = btn:CreateTexture(nil, "ARTWORK")
    innerBG:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    innerBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1) 
    innerBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.innerBG = innerBG

    local raidIcon = btn:CreateTexture(nil, "OVERLAY")
    raidIcon:SetSize(10, 10) 
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

    for _, unit in ipairs(checkOrder) do
        if activeUnits[unit] and UnitExists(unit) then
            local btn = GetOrCreateButton(unit)
            local row = math.floor(visibleCount / BUTTONS_PER_ROW)
            local col = visibleCount % BUTTONS_PER_ROW
            
            local xOffset = col * (BUTTON_SIZE + BUTTON_SPACING)
            local yOffset = -(row * (BUTTON_SIZE + BUTTON_SPACING))
            
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
    else
        RefreshButtonVisibility()
    end
end)

ScanPlayerSpellbook()
RefreshButtonVisibility()

print("|cFF00FF00DecursiveLite by Pawie successfully loaded!|r")
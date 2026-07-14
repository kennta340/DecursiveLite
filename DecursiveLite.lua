local dispelSpells = {
    Poison = {
        "Sanctify",            -- Sun Cleric (Dispel: Magic, Poison, Disease)
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
        "Sanctify",            -- Sun Cleric (Dispel: Magic, Poison, Disease)
        "Burn Impurities",    -- Pyromancer (Talent - Bound to Left Click)
        "Devour Magic",       -- Cultist
        "Dispel Magic",
        "Cleanse",
    },
    Disease = {
        "Sanctify",            -- Sun Cleric (Dispel: Magic, Poison, Disease)
        "Elune's Purification",-- Starcaller (Poison & Disease)
        "Burn Impurities",    -- Pyromancer (Talent - Bound to Left Click)
        "Cure Disease",
        "Purify",
    },
    Bleed = {
        "Cauterize",          -- Pyromancer (Talent - Bound to Right Click)
    }
}

local frame = CreateFrame("Frame", "DecursiveLiteMain", UIParent)
frame:SetSize(227, 50) 
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:SetClampedToScreen(true)

local customAlertSound = "Interface\\AddOns\\DecursiveLite\\Sounds\\AfflictionAlert.ogg"

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
    Magic   = {0.2, 0.2, 0.8},
    Curse   = {0.8, 0.2, 0.8},
    Poison  = {0.2, 0.8, 0.2},
    Disease = {0.6, 0.4, 0.2},
    Bleed   = {0.8, 0.1, 0.1},
}

local activeSpells = { Poison = nil, Curse = nil, Magic = nil, Disease = nil, Bleed = nil }
local buttons = {} 
local activeUnits = {} 
local soundPlayed = false
local isTesting = false

local BUTTON_SIZE = 20
local BUTTON_SPACING = 3
local BUTTONS_PER_ROW = 10 

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

    -- If NO debuffs: Apply the cozy semi-transparent Decursive green color scheme
    if not hasDebuff then
        button:SetBackdropColor(0, 0.15, 0.05, 0.1)      -- Soft backdrop alpha
        button.innerBG:SetVertexColor(0.02, 0.15, 0.05, 0.45) -- Standard warm green inner color
    end

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
    
    -- Thicker border configs (edgeSize changed from 1 to 2)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    -- Reposition inner texture to adapt perfectly to the thicker 2px frame border
    local innerBG = btn:CreateTexture(nil, "ARTWORK")
    innerBG:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    innerBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2) 
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
    end
    RefreshButtonVisibility()
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
desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
desc:SetText("A lightweight and highly optimized decurse grid built specifically for Ascension (CoA).")

local guideHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
guideHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
guideHeader:SetText("Quick Guide & Features:")

local guideText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
guideText:SetPoint("TOPLEFT", guideHeader, "BOTTOMLEFT", 10, -8)
guideText:SetJustifyH("LEFT")
guideText:SetText(
    "- |cFF00FF00Mouse Drag:|r Write |cFF00FF00/dl unlock|r, then hold |cFF00FF00Shift|r and drag the tiny gray handle above the first button.\n" ..
    "- |cFF00FF00Left-Click Grid:|r Dispel Poison / Magic spells.\n" ..
    "- |cFF00FF00Right-Click Grid:|r Dispel Curse / Disease / Bleed spells.\n" ..
    "- |cFF00FF00Borders:|r Permanently locked to target class colors.\n" ..
    "- |cFF00FF00Raid Icons:|r Dynamic 10x10px raid markers displayed centered above frames."
)

local cmdHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
cmdHeader:SetPoint("TOPLEFT", guideText, "BOTTOMLEFT", -10, -20)
cmdHeader:SetText("Available Slash Commands:")

local cmdList = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
cmdList:SetPoint("TOPLEFT", cmdHeader, "BOTTOMLEFT", 10, -8)
cmdList:SetJustifyH("LEFT")
cmdList:SetText(
    "|cFF00FF00/dl reset|r - Snaps the grid back to the center of your screen.\n" ..
    "|cFF00FF00/dl lock|r - Disables dragging and hides the gray handle frame.\n" ..
    "|cFF00FF00/dl unlock|r - Reveals the drag handle and enables frame positioning.\n" ..
    "|cFF00FF00/dl test|r - Spawns simulated dummy debuffs across the active grid."
)

local btnHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
btnHeader:SetPoint("TOPLEFT", cmdList, "BOTTOMLEFT", -10, -20)
btnHeader:SetText("Interactive Panel Actions:")

local btnReset = CreateFrame("Button", "DecursiveLiteOptReset", panel, "UIPanelButtonTemplate")
btnReset:SetSize(120, 26)
btnReset:SetPoint("TOPLEFT", btnHeader, "BOTTOMLEFT", 0, -10)
btnReset:SetText("Reset Position")
btnReset:SetScript("OnClick", function() ResetFramePosition() end)

local isLockedOpt = true
local btnLock = CreateFrame("Button", "DecursiveLiteOptLock", panel, "UIPanelButtonTemplate")
btnLock:SetSize(120, 26)
btnLock:SetPoint("LEFT", btnReset, "RIGHT", 10, 0)
btnLock:SetText("Unlock / Lock")
btnLock:SetScript("OnClick", function()
    isLockedOpt = not isLockedOpt
    if isLockedOpt then
        LockFrame()
    else
        UnlockFrame()
    end
end)

local btnTest = CreateFrame("Button", "DecursiveLiteOptTest", panel, "UIPanelButtonTemplate")
btnTest:SetSize(120, 26)
btnTest:SetPoint("LEFT", btnLock, "RIGHT", 10, 0)
btnTest:SetText("Toggle Test Mode")
btnTest:SetScript("OnClick", function() ToggleTestMode() end)

InterfaceOptions_AddCategory(panel)

print("|cFF00FF00DecursiveLite Beta by Pawie @ Vol'jin successfully loaded!|r")
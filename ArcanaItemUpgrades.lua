local PREFIX = "AUI"
local VISIBLE_ROWS = 14
local ROW_HEIGHT = 20
local SYNC_RETRY_DELAYS = { 1, 3, 8 }
local MINIMAP_RADIUS = 80
local ARCANE_FOCUS_ICON = "Interface\\Icons\\Spell_Holy_Devotion"

local state = {
    slots = {},
    selected = nil,
    maxRank = 5,
    percent = 5,
    syncing = false,
    syncRetryIndex = nil,
    syncRetryAt = nil,
}

local STAT_LABELS = {
    [0] = "Mana", [1] = "Health", [3] = "Agility", [4] = "Strength",
    [5] = "Intellect", [6] = "Spirit", [7] = "Stamina",
    [12] = "Defense Rating", [13] = "Dodge Rating", [14] = "Parry Rating",
    [15] = "Block Rating", [16] = "Melee Hit Rating", [17] = "Ranged Hit Rating",
    [18] = "Spell Hit Rating", [19] = "Melee Crit Rating", [20] = "Ranged Crit Rating",
    [21] = "Spell Crit Rating", [22] = "Melee Hit Avoidance", [23] = "Ranged Hit Avoidance",
    [24] = "Spell Hit Avoidance", [25] = "Melee Crit Avoidance",
    [26] = "Ranged Crit Avoidance", [27] = "Spell Crit Avoidance",
    [28] = "Melee Haste Rating", [29] = "Ranged Haste Rating", [30] = "Spell Haste Rating",
    [31] = "Hit Rating", [32] = "Crit Rating", [33] = "Hit Avoidance Rating",
    [34] = "Crit Avoidance Rating", [35] = "Resilience Rating", [36] = "Haste Rating",
    [37] = "Expertise Rating", [38] = "Attack Power", [39] = "Ranged Attack Power",
    [41] = "Healing", [42] = "Spell Damage", [43] = "Mana per 5 sec",
    [44] = "Armor Penetration Rating", [45] = "Spell Power", [46] = "Health Regeneration",
    [47] = "Spell Penetration", [48] = "Block Value",
}

local VALUE_LABELS = {
    ARMOR = "Armor", BLOCK = "Block Value", HOLY_RES = "Holy Resistance",
    FIRE_RES = "Fire Resistance", NATURE_RES = "Nature Resistance",
    FROST_RES = "Frost Resistance", SHADOW_RES = "Shadow Resistance",
    ARCANE_RES = "Arcane Resistance", FERAL_AP = "Feral Attack Power",
}

local SOURCE_DEFINITIONS = {
    { key = "UNCOMMON_MATCH", count = "uncommonMatching", entry = "uncommonEntry" },
    { key = "RARE_WILD", count = "rareWildcard", entry = "rareWildcardEntry" },
    { key = "EPIC_MATCH", count = "epicMatching", entry = "epicEntry" },
    { key = "EPIC_WILD", count = "epicWildcard", entry = "epicWildcardEntry" },
    { key = "DUP", count = "duplicate", entry = "duplicateEntry" },
    { key = "LEGEND", count = "legendary", entry = "legendaryEntry", legendary = true },
}

local FAMILY_INDEX = {
    Helm = 0, Neck = 1, Shoulders = 2, Cloak = 3, Chest = 4, Wrist = 5,
    Hands = 6, Waist = 7, Legs = 8, Feet = 9, Ring = 10, Trinket = 11,
    Weapon = 12, ["Off-hand"] = 13, Wildcard = 14,
}

local function Split(value)
    local fields = {}
    local start = 1
    while true do
        local position = string.find(value, "\t", start, true)
        if not position then
            table.insert(fields, string.sub(value, start))
            return fields
        end
        table.insert(fields, string.sub(value, start, position - 1))
        start = position + 1
    end
end

local function Send(command)
    SendAddonMessage(PREFIX, command, "WHISPER", UnitName("player"))
end

local function RegisterPrefixIfSupported()
    -- RegisterAddonMessagePrefix was added after the 3.3.5a client. Arcana's
    -- self-whisper protocol works without registration on this client.
    if type(RegisterAddonMessagePrefix) == "function" then
        RegisterAddonMessagePrefix(PREFIX)
    end
end

local RequestSync

local function IsRemoteLocationAllowed()
    if UnitIsDeadOrGhost("player") then
        return false, "You must be alive."
    end
    if UnitAffectingCombat("player") then
        return false, "Remote upgrades are unavailable in combat."
    end
    local inside, instanceType = IsInInstance()
    if inside and instanceType ~= "none" then
        return false, "Remote upgrades are unavailable inside instances."
    end
    return true
end

local function FormatValue(value)
    value = tonumber(value) or 0
    if math.abs(value - math.floor(value + 0.5)) < 0.005 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%.2f", value)
end

local frame = CreateFrame("Frame", "ArcanaItemUpgradesFrame", UIParent)
frame:SetWidth(600)
frame:SetHeight(520)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:Hide()
table.insert(UISpecialFrames, frame:GetName())
local function ToggleUpgradeFrame()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

local minimapButton
local function UpdateMinimapButtonPosition()
    if not minimapButton then return end
    local angle = tonumber(ArcanaItemUpgradesDB and ArcanaItemUpgradesDB.minimapAngle) or 225
    local radians = math.rad(angle)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(radians) * MINIMAP_RADIUS, math.sin(radians) * MINIMAP_RADIUS)
end

local function UpdateMinimapButtonFromCursor(self)
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    if not scale or not centerX or not centerY then return end
    cursorX, cursorY = cursorX / scale, cursorY / scale
    ArcanaItemUpgradesDB.minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
    UpdateMinimapButtonPosition()
end

local function UpdateMinimapButtonIcon()
    if not minimapButton then return end
    local texture = GetItemIcon and GetItemIcon(194329)
    minimapButton.icon:SetTexture(texture or ARCANE_FOCUS_ICON)
end

local function InstallMinimapButton()
    if minimapButton or not Minimap then return end
    ArcanaItemUpgradesDB = ArcanaItemUpgradesDB or {}

    minimapButton = CreateFrame("Button", "ArcanaItemUpgradesMinimapButton", Minimap)
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    minimapButton:RegisterForClicks("LeftButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    minimapButton.icon:SetWidth(20)
    minimapButton.icon:SetHeight(20)
    minimapButton.icon:SetPoint("CENTER")
    minimapButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("TOPLEFT")

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetScript("OnClick", ToggleUpgradeFrame)
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", UpdateMinimapButtonFromCursor)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Arcana Item Upgrades", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click to open.", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdateMinimapButtonIcon()
    UpdateMinimapButtonPosition()
end

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("Arcana Item Upgrades")

local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -7)
subtitle:SetText("Select equipped gear, then use one available upgrade source.")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)

local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
refresh:SetWidth(88)
refresh:SetHeight(22)
refresh:SetPoint("TOPRIGHT", -38, -47)
refresh:SetText("Refresh")

local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 23, -52)
status:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
status:SetJustifyH("LEFT")
status:SetText("Waiting for the realm...")

local list = CreateFrame("Frame", nil, frame)
list:SetPoint("TOPLEFT", 19, -80)
list:SetWidth(562)
list:SetHeight(300)
list:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
list:SetBackdropColor(0.03, 0.03, 0.03, 0.92)

local scrollFrame = CreateFrame("ScrollFrame", "ArcanaItemUpgradesScrollFrame", list, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 4, -7)
scrollFrame:SetPoint("BOTTOMRIGHT", -27, 7)

local rows = {}
local sourceFrame
local ShowSourceChooser
for index = 1, VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -7 - ((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", -30, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", 1, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(370)
    row.name:SetJustifyH("LEFT")

    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rank:SetPoint("RIGHT", -5, 0)
    row.rank:SetWidth(135)
    row.rank:SetJustifyH("RIGHT")

    row:SetScript("OnClick", function(self)
        local chooserWasOpen = sourceFrame and sourceFrame:IsShown()
        state.selected = self.arcanaSlot
        frame:UpdateDisplay()
        if chooserWasOpen and sourceFrame:IsShown() and ShowSourceChooser then
            ShowSourceChooser()
        end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.arcanaSlot then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", self.arcanaSlot + 1)
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
end

local selectedText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
selectedText:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 3, -15)
selectedText:SetWidth(556)
selectedText:SetJustifyH("LEFT")
selectedText:SetText("Select an item.")

local locationText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
locationText:SetPoint("TOPLEFT", selectedText, "BOTTOMLEFT", 0, -7)
locationText:SetWidth(556)
locationText:SetJustifyH("LEFT")

local upgradeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
upgradeButton:SetWidth(160)
upgradeButton:SetHeight(26)
upgradeButton:SetPoint("BOTTOM", 0, 23)
upgradeButton:SetText("Upgrade")

sourceFrame = CreateFrame("Frame", "ArcanaItemUpgradeSourceFrame", frame)
sourceFrame:SetWidth(400)
sourceFrame:SetHeight(280)
sourceFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
sourceFrame:SetFrameStrata("FULLSCREEN_DIALOG")
sourceFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
sourceFrame:Hide()

local sourceTitle = sourceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
sourceTitle:SetPoint("TOP", 0, -18)
sourceTitle:SetText("Choose Upgrade Source")

local sourceSubtitle = sourceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sourceSubtitle:SetPoint("TOP", sourceTitle, "BOTTOM", 0, -8)
sourceSubtitle:SetWidth(350)
sourceSubtitle:SetText("Select exactly which item will be consumed.")

local sourceClose = CreateFrame("Button", nil, sourceFrame, "UIPanelCloseButton")
sourceClose:SetPoint("TOPRIGHT", -5, -5)
sourceClose:SetScript("OnClick", function() sourceFrame:Hide() end)

local sourceButtons = {}
for index = 1, #SOURCE_DEFINITIONS do
    local button = CreateFrame("Button", nil, sourceFrame, "UIPanelButtonTemplate")
    button:SetWidth(350)
    button:SetHeight(25)
    button:SetPoint("TOP", 0, -65 - ((index - 1) * 30))
    button:SetText("")

    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetWidth(20)
    button.icon:SetHeight(20)
    button.icon:SetPoint("LEFT", 8, 0)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 7, 0)
    button.label:SetWidth(307)
    button.label:SetJustifyH("LEFT")

    button:SetScript("OnEnter", function(self)
        if not self.arcanaEntry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.arcanaEntry .. ":0:0:0:0:0:0:0")
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    sourceButtons[index] = button
end

StaticPopupDialogs["ARCANA_ITEM_UPGRADE_CONFIRM"] = {
    text = "Consume one %s to upgrade %s?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(self, data)
        if data then
            Send("CMD\tUPGRADE\t" .. data.slot .. "\t" .. data.payment)
            status:SetText("Waiting for the realm...")
        end
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ARCANA_ITEM_UPGRADE_LEGENDARY_CONFIRM"] = {
    text = "This permanently consumes %s and sets %s directly to 5/5. Continue?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(self, data)
        if data then
            Send("CMD\tUPGRADE\t" .. data.slot .. "\tLEGEND")
            status:SetText("Waiting for the realm...")
        end
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function AvailableSources(slot)
    local available = {}
    if not slot then return available end
    for _, definition in ipairs(SOURCE_DEFINITIONS) do
        if (slot[definition.count] or 0) > 0 then
            table.insert(available, definition)
        end
    end
    return available
end

local function FallbackSourceName(slot, definition)
    local family = slot.family == "Off-hand" and "Off-Hand" or slot.family
    if definition.key == "UNCOMMON_MATCH" then return "Arcana " .. family .. " Sigil" end
    if definition.key == "RARE_WILD" then return "Arcana Wildcard Sigil" end
    if definition.key == "EPIC_MATCH" then return "Enduring Arcana " .. family .. " Sigil" end
    if definition.key == "EPIC_WILD" then return "Enduring Arcana Wildcard Sigil" end
    if definition.key == "LEGEND" then return "Arcana Sigil of Perfection" end
    return slot.itemName or "Duplicate item"
end

local function FallbackSourceEntry(slot, definition)
    local familyIndex = FAMILY_INDEX[slot.family]
    if definition.key == "UNCOMMON_MATCH" and familyIndex then return 194300 + familyIndex end
    if definition.key == "RARE_WILD" then return 194329 end
    if definition.key == "EPIC_MATCH" and familyIndex then return 194330 + familyIndex end
    if definition.key == "EPIC_WILD" then return 194344 end
    if definition.key == "DUP" then return slot.entry end
    if definition.key == "LEGEND" then return 194345 end
end

local function ResolveSourceItem(slot, definition)
    local entry = tonumber(slot[definition.entry]) or FallbackSourceEntry(slot, definition)
    local name, quality, texture
    if entry then
        name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(entry)
        if not texture and GetItemIcon then texture = GetItemIcon(entry) end
    end
    return entry, name or FallbackSourceName(slot, definition), quality,
        texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ConfirmSource(slot, definition, sourceName)
    sourceFrame:Hide()
    local data = { slot = slot.slot, payment = definition.key }
    if definition.legendary then
        StaticPopup_Show("ARCANA_ITEM_UPGRADE_LEGENDARY_CONFIRM", sourceName,
            slot.name or "this item", data)
    else
        StaticPopup_Show("ARCANA_ITEM_UPGRADE_CONFIRM", sourceName,
            slot.name or "this item", data)
    end
end

ShowSourceChooser = function()
    local slot = state.slots[state.selected]
    if not slot then return end
    local available = AvailableSources(slot)
    for index, button in ipairs(sourceButtons) do
        local definition = available[index]
        if definition then
            local entry, sourceName, quality, texture = ResolveSourceItem(slot, definition)
            button.arcanaEntry = entry
            button.label:SetWidth(307)
            button.icon:SetTexture(texture)
            button.label:SetText(sourceName .. " (" .. (slot[definition.count] or 0) .. ")")
            local labelWidth = math.min(button.label:GetStringWidth() + 1, 307)
            local contentWidth = 20 + 7 + labelWidth
            button.icon:ClearAllPoints()
            button.icon:SetPoint("LEFT", button, "LEFT",
                math.max(8, (button:GetWidth() - contentWidth) / 2), 0)
            button.label:SetWidth(labelWidth)
            if quality then
                local red, green, blue = GetItemQualityColor(quality)
                button.label:SetTextColor(red, green, blue)
            else
                button.label:SetTextColor(1, 0.82, 0)
            end
            local chosenDefinition = definition
            local chosenName = sourceName
            button:SetScript("OnClick", function() ConfirmSource(slot, chosenDefinition, chosenName) end)
            button:Show()
        else
            button.arcanaEntry = nil
            button:Hide()
        end
    end
    sourceFrame:SetHeight(85 + (#available * 30))
    sourceFrame:Show()
end

upgradeButton:SetScript("OnClick", ShowSourceChooser)
refresh:SetScript("OnClick", function()
    RequestSync(true)
end)

local function OrderedSlots()
    local ordered = {}
    for _, slot in pairs(state.slots) do table.insert(ordered, slot) end
    table.sort(ordered, function(a, b) return a.slot < b.slot end)
    return ordered
end

function frame:UpdateDisplay()
    local ordered = OrderedSlots()
    if state.selected and not state.slots[state.selected] then state.selected = nil end
    if not state.selected and ordered[1] then state.selected = ordered[1].slot end

    FauxScrollFrame_Update(scrollFrame, #ordered, VISIBLE_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    for index, row in ipairs(rows) do
        local slot = ordered[index + offset]
        if slot then
            local inventorySlot = slot.slot + 1
            local link = GetInventoryItemLink("player", inventorySlot)
            local itemName = GetItemInfo(slot.entry)
            slot.link = link
            slot.itemName = itemName or (link and string.match(link, "%[(.-)%]")) or ("Item " .. slot.entry)
            slot.name = link or slot.itemName
            row.arcanaSlot = slot.slot
            row.icon:SetTexture(GetInventoryItemTexture("player", inventorySlot))
            row.name:SetText(slot.name)
            row.rank:SetText(string.format("%d/%d  (+%d%%)", slot.rank, state.maxRank,
                slot.rank * state.percent))
            if state.selected == slot.slot then row:LockHighlight() else row:UnlockHighlight() end
            row:Show()
        else
            row.arcanaSlot = nil
            row:Hide()
        end
    end

    local selected = state.slots[state.selected]
    local allowed, reason = IsRemoteLocationAllowed()
    if selected then
        selectedText:SetText((selected.name or "Selected item") .. " — " ..
            string.format("%d/%d (+%d%%)", selected.rank, state.maxRank,
                selected.rank * state.percent))
    else
        selectedText:SetText("No eligible equipped items were reported by the realm.")
    end
    locationText:SetText(allowed and
        "Remote upgrading is available here. The Item Upgrader NPC remains available in major cities." or reason)
    locationText:SetTextColor(allowed and 0.4 or 1, allowed and 1 or 0.35, 0.35)

    local canUpgrade = selected and selected.rank < state.maxRank and
        #AvailableSources(selected) > 0 and allowed
    if canUpgrade then upgradeButton:Enable() else upgradeButton:Disable() end
    if not canUpgrade then sourceFrame:Hide() end
end

scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() frame:UpdateDisplay() end)
end)

RequestSync = function(force)
    if force or not state.syncing then
        state.syncing = true
        state.syncRetryIndex = 1
        state.syncRetryAt = GetTime() + SYNC_RETRY_DELAYS[1]
        status:SetText("Syncing with the realm...")
        Send("CMD\tSYNC")
    end
end
local function FinishSync()
    state.syncing = false
    state.syncRetryIndex = nil
    state.syncRetryAt = nil
end

local function UpdateSyncRetry()
    if not state.syncing or not state.syncRetryAt or GetTime() < state.syncRetryAt then return end
    if state.syncRetryIndex >= #SYNC_RETRY_DELAYS then
        FinishSync()
        status:SetText("Unable to sync. Click Refresh to try again.")
        return
    end

    Send("CMD\tSYNC")
    state.syncRetryIndex = state.syncRetryIndex + 1
    state.syncRetryAt = GetTime() + SYNC_RETRY_DELAYS[state.syncRetryIndex]
end

local RefreshVisibleTooltip


frame:SetScript("OnShow", RequestSync)
frame:SetScript("OnHide", function() sourceFrame:Hide() end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

local characterButton
local function InstallCharacterButton()
    if characterButton or not CharacterFrame then return end
    characterButton = CreateFrame("Button", "ArcanaItemUpgradesCharacterButton",
        CharacterFrame, "UIPanelButtonTemplate")
    characterButton:SetWidth(82)
    characterButton:SetHeight(20)
    characterButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -42, -39)
    characterButton:SetFrameLevel(CharacterFrame:GetFrameLevel() + 10)
    characterButton:EnableMouse(true)
    characterButton:SetText("Upgrades")
    characterButton:SetScript("OnClick", ToggleUpgradeFrame)
end

eventFrame:SetScript("OnUpdate", function() UpdateSyncRetry() end)
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "ArcanaItemUpgrades" then
            ArcanaItemUpgradesDB = ArcanaItemUpgradesDB or {}
            RegisterPrefixIfSupported()
            InstallMinimapButton()
        end
        if addon == "ArcanaItemUpgrades" or addon == "Blizzard_CharacterUI" then
            InstallCharacterButton()
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        RegisterPrefixIfSupported()
        InstallCharacterButton()
        InstallMinimapButton()
        UpdateMinimapButtonIcon()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        InstallMinimapButton()
        UpdateMinimapButtonIcon()
        RequestSync(true)
        return
    end
    if event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix ~= PREFIX then return end
        local fields = Split(message)
        if fields[1] == "BEGIN" then
            state.slots = {}
            state.maxRank = tonumber(fields[2]) or 5
            state.percent = tonumber(fields[3]) or 5
        elseif fields[1] == "SLOT" then
            local slot = tonumber(fields[2])
            if slot then
                state.slots[slot] = {
                    slot = slot, entry = tonumber(fields[3]) or 0,
                    rank = tonumber(fields[4]) or 0, family = fields[5] or "",
                    uncommonMatching = tonumber(fields[6]) or 0,
                    rareWildcard = tonumber(fields[7]) or 0,
                    epicMatching = tonumber(fields[8]) or 0,
                    epicWildcard = tonumber(fields[9]) or 0,
                    duplicate = tonumber(fields[10]) or 0,
                    legendary = tonumber(fields[11]) or 0,
                    uncommonEntry = tonumber(fields[12]),
                    rareWildcardEntry = tonumber(fields[13]),
                    epicEntry = tonumber(fields[14]),
                    epicWildcardEntry = tonumber(fields[15]),
                    duplicateEntry = tonumber(fields[16]),
                    legendaryEntry = tonumber(fields[17]),
                    values = {},
                }
            end
        elseif fields[1] == "STAT" then
            local slot = state.slots[tonumber(fields[2])]
            if slot then
                table.insert(slot.values, { label = STAT_LABELS[tonumber(fields[3])] or
                    ("Item stat " .. (fields[3] or "?")), base = tonumber(fields[4]),
                    effective = tonumber(fields[5]) })
            end
        elseif fields[1] == "VALUE" then
            local slot = state.slots[tonumber(fields[2])]
            if slot then
                table.insert(slot.values, { label = VALUE_LABELS[fields[3]] or fields[3],
                    base = tonumber(fields[4]), effective = tonumber(fields[5]) })
            end
        elseif fields[1] == "DAMAGE" then
            local slot = state.slots[tonumber(fields[2])]
            if slot then
                local index = tonumber(fields[3]) or 0
                table.insert(slot.values, { label = index == 0 and "Weapon Damage" or
                    ("Weapon Damage " .. (index + 1)), damage = true,
                    baseMin = tonumber(fields[4]), baseMax = tonumber(fields[5]),
                    effectiveMin = tonumber(fields[6]), effectiveMax = tonumber(fields[7]) })
            end
        elseif fields[1] == "END" then
            FinishSync()
            status:SetText("Up to date.")
            frame:UpdateDisplay()
            UpdateMinimapButtonIcon()
            if RefreshVisibleTooltip then RefreshVisibleTooltip() end
        elseif fields[1] == "RESULT" then
            status:SetText(fields[2] or "Upgrade complete.")
            DEFAULT_CHAT_FRAME:AddMessage("|cffb48cffArcana Upgrades:|r " ..
                (fields[2] or "Upgrade complete."))
        elseif fields[1] == "ERROR" then
            FinishSync()
            status:SetText(fields[2] or "The request was refused.")
            UIErrorsFrame:AddMessage(fields[2] or "The request was refused.", 1, 0.2, 0.2)
        end
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        RequestSync(true)
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or
        event == "ZONE_CHANGED_NEW_AREA" then
        if frame:IsShown() then frame:UpdateDisplay() end
    end
end)

local function AddUpgradeTooltip(tooltip, slot)
    if not slot then return end
    tooltip:AddLine(string.format("Arcana Upgrade: %d/%d (+%d%%)", slot.rank,
        state.maxRank, slot.rank * state.percent), 0.71, 0.55, 1)
    if slot.rank > 0 and slot.values and #slot.values > 0 then
        tooltip:AddLine("Effective item values:", 0.96, 0.82, 0.25)
        for _, value in ipairs(slot.values) do
            if value.damage then
                tooltip:AddDoubleLine(value.label .. ":",
                    FormatValue(value.baseMin) .. "-" .. FormatValue(value.baseMax) .. " -> " ..
                    FormatValue(value.effectiveMin) .. "-" .. FormatValue(value.effectiveMax),
                    0.85, 0.85, 0.85, 0.4, 1, 0.4)
            else
                tooltip:AddDoubleLine((value.label or "Value") .. ":",
                    FormatValue(value.base) .. " -> " .. FormatValue(value.effective),
                    0.85, 0.85, 0.85, 0.4, 1, 0.4)
            end
        end
    end
    tooltip:Show()
end
RefreshVisibleTooltip = function()
    if not GameTooltip:IsShown() then return end
    local owner = GameTooltip:GetOwner()
    local serverSlot = owner and owner.arcanaSlot
    local ownerName = owner and owner.GetName and owner:GetName()
    if not serverSlot and ownerName and string.find(ownerName, "^Character") and owner.GetID then
        local inventorySlot = owner:GetID()
        if inventorySlot then serverSlot = inventorySlot - 1 end
    end
    if serverSlot and state.slots[serverSlot] then
        GameTooltip:SetInventoryItem("player", serverSlot + 1)
    end
end


GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
    local _, link = tooltip:GetItem()
    if not link then return end
    local owner = tooltip:GetOwner()
    local serverSlot = owner and owner.arcanaSlot
    local ownerName = owner and owner.GetName and owner:GetName()
    if not serverSlot and ownerName and string.find(ownerName, "^Character") and owner.GetID then
        local inventorySlot = owner:GetID()
        if inventorySlot then serverSlot = inventorySlot - 1 end
    end
    if serverSlot and state.slots[serverSlot] then
        AddUpgradeTooltip(tooltip, state.slots[serverSlot])
        return
    end

    local matched
    for slotIndex, slot in pairs(state.slots) do
        if GetInventoryItemLink("player", slotIndex + 1) == link then
            if matched then return end
            matched = slot
        end
    end
    AddUpgradeTooltip(tooltip, matched)
end)

SLASH_ARCANAITEMUPGRADES1 = "/upgrades"
SLASH_ARCANAITEMUPGRADES2 = "/itemupgrades"
SlashCmdList["ARCANAITEMUPGRADES"] = ToggleUpgradeFrame

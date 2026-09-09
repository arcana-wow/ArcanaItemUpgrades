local PREFIX = "AUI"
local VISIBLE_ROWS = 14
local ROW_HEIGHT = 20

local state = {
    slots = {},
    selected = nil,
    maxRank = 5,
    percent = 5,
    syncing = false,
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
    { key = "UNCOMMON_MATCH", label = "Uncommon matching token", count = "uncommonMatching" },
    { key = "RARE_WILD", label = "Rare Wildcard token", count = "rareWildcard" },
    { key = "EPIC_MATCH", label = "Epic matching token", count = "epicMatching" },
    { key = "EPIC_WILD", label = "Epic Wildcard token", count = "epicWildcard" },
    { key = "DUP", label = "Duplicate item", count = "duplicate" },
    { key = "LEGEND", label = "Legendary token", count = "legendary", legendary = true },
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
        state.selected = self.arcanaSlot
        frame:UpdateDisplay()
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

local sourceFrame = CreateFrame("Frame", "ArcanaItemUpgradeSourceFrame", frame)
sourceFrame:SetWidth(360)
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
sourceSubtitle:SetWidth(310)
sourceSubtitle:SetText("Select exactly which item will be consumed.")

local sourceClose = CreateFrame("Button", nil, sourceFrame, "UIPanelCloseButton")
sourceClose:SetPoint("TOPRIGHT", -5, -5)
sourceClose:SetScript("OnClick", function() sourceFrame:Hide() end)

local sourceButtons = {}
for index = 1, #SOURCE_DEFINITIONS do
    local button = CreateFrame("Button", nil, sourceFrame, "UIPanelButtonTemplate")
    button:SetWidth(300)
    button:SetHeight(25)
    button:SetPoint("TOP", 0, -65 - ((index - 1) * 30))
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
    text = "This permanently consumes a Legendary token and sets %s directly to 5/5. Continue?",
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

local function ConfirmSource(slot, definition)
    sourceFrame:Hide()
    local data = { slot = slot.slot, payment = definition.key }
    if definition.legendary then
        StaticPopup_Show("ARCANA_ITEM_UPGRADE_LEGENDARY_CONFIRM", slot.name or "this item", nil, data)
    else
        StaticPopup_Show("ARCANA_ITEM_UPGRADE_CONFIRM", definition.label,
            slot.name or "this item", data)
    end
end

local function ShowSourceChooser()
    local slot = state.slots[state.selected]
    if not slot then return end
    local available = AvailableSources(slot)
    for index, button in ipairs(sourceButtons) do
        local definition = available[index]
        if definition then
            button:SetText(definition.label .. " (" .. (slot[definition.count] or 0) .. ")")
            button:SetScript("OnClick", function() ConfirmSource(slot, definition) end)
            button:Show()
        else
            button:Hide()
        end
    end
    sourceFrame:SetHeight(85 + (#available * 30))
    sourceFrame:Show()
end

upgradeButton:SetScript("OnClick", ShowSourceChooser)
refresh:SetScript("OnClick", function()
    state.syncing = true
    status:SetText("Syncing with the realm...")
    Send("CMD\tSYNC")
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
            slot.link = link
            slot.name = link or ("Item " .. slot.entry)
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

local function RequestSync()
    if not state.syncing then
        state.syncing = true
        status:SetText("Syncing with the realm...")
        Send("CMD\tSYNC")
    end
end

frame:SetScript("OnShow", RequestSync)
frame:SetScript("OnHide", function() sourceFrame:Hide() end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
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
    characterButton:SetWidth(112)
    characterButton:SetHeight(22)
    characterButton:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -38, 84)
    characterButton:SetText("Item Upgrades")
    characterButton:SetScript("OnClick", function()
        if frame:IsShown() then frame:Hide() else frame:Show() end
    end)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "ArcanaItemUpgrades" or addon == "Blizzard_CharacterUI" then
            InstallCharacterButton()
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        RegisterAddonMessagePrefix(PREFIX)
        InstallCharacterButton()
        RequestSync()
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
            state.syncing = false
            status:SetText("Up to date.")
            frame:UpdateDisplay()
        elseif fields[1] == "RESULT" then
            status:SetText(fields[2] or "Upgrade complete.")
            DEFAULT_CHAT_FRAME:AddMessage("|cffb48cffArcana Upgrades:|r " ..
                (fields[2] or "Upgrade complete."))
        elseif fields[1] == "ERROR" then
            state.syncing = false
            status:SetText(fields[2] or "The request was refused.")
            UIErrorsFrame:AddMessage(fields[2] or "The request was refused.", 1, 0.2, 0.2)
        end
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        RequestSync()
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
SlashCmdList["ARCANAITEMUPGRADES"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

local PREFIX = "AUI"
local MAX_ROWS = 19

local state = {
    slots = {},
    selected = nil,
    maxRank = 5,
    percent = 5,
    syncing = false,
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

local frame = CreateFrame("Frame", "ArcanaItemUpgradesFrame", UIParent)
frame:SetWidth(560)
frame:SetHeight(500)
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
subtitle:SetText("Select equipped gear, then choose an upgrade source.")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)

local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
refresh:SetWidth(88)
refresh:SetHeight(22)
refresh:SetPoint("TOPRIGHT", -38, -47)
refresh:SetText("Refresh")
refresh:SetScript("OnClick", function()
    state.syncing = true
    Send("CMD\tSYNC")
end)

local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 23, -52)
status:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
status:SetJustifyH("LEFT")
status:SetText("Waiting for the realm...")

local list = CreateFrame("Frame", nil, frame)
list:SetPoint("TOPLEFT", 19, -80)
list:SetWidth(522)
list:SetHeight(300)
list:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
list:SetBackdropColor(0.03, 0.03, 0.03, 0.92)

local rows = {}
for index = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(20)
    row:SetPoint("TOPLEFT", 8, -7 - ((index - 1) * 20))
    row:SetPoint("RIGHT", -8, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", 1, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(335)
    row.name:SetJustifyH("LEFT")

    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rank:SetPoint("RIGHT", -5, 0)
    row.rank:SetWidth(135)
    row.rank:SetJustifyH("RIGHT")

    row:SetScript("OnClick", function(self)
        state.selected = self.slot
        if frame.UpdateDisplay then
            frame:UpdateDisplay()
        end
    end)
    rows[index] = row
end

local selectedText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
selectedText:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 3, -15)
selectedText:SetWidth(516)
selectedText:SetJustifyH("LEFT")
selectedText:SetText("Select an item.")

local locationText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
locationText:SetPoint("TOPLEFT", selectedText, "BOTTOMLEFT", 0, -7)
locationText:SetWidth(516)
locationText:SetJustifyH("LEFT")

local paymentButtons = {}
local paymentDefinitions = {
    { key = "MATCH", label = "Matching token", count = "matching" },
    { key = "WILD", label = "Wildcard token", count = "wildcard" },
    { key = "DUP", label = "Duplicate item", count = "duplicate" },
    { key = "LEGEND", label = "Legendary token", count = "legendary" },
}

StaticPopupDialogs["ARCANA_ITEM_UPGRADE_CONFIRM"] = {
    text = "Consume this upgrade source to improve %s?",
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

for index, definition in ipairs(paymentDefinitions) do
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetWidth(125)
    button:SetHeight(24)
    button:SetPoint("BOTTOMLEFT", 19 + ((index - 1) * 130), 22)
    button.definition = definition
    button:SetScript("OnClick", function(self)
        local slot = state.slots[state.selected]
        if not slot then
            return
        end
        local dialog = self.definition.key == "LEGEND"
            and "ARCANA_ITEM_UPGRADE_LEGENDARY_CONFIRM" or "ARCANA_ITEM_UPGRADE_CONFIRM"
        StaticPopup_Show(dialog, slot.name or "this item", nil, {
            slot = slot.slot,
            payment = self.definition.key,
        })
    end)
    paymentButtons[index] = button
end

function frame:UpdateDisplay()
    local ordered = {}
    for _, slot in pairs(state.slots) do
        table.insert(ordered, slot)
    end
    table.sort(ordered, function(a, b) return a.slot < b.slot end)

    if state.selected and not state.slots[state.selected] then
        state.selected = nil
    end
    if not state.selected and ordered[1] then
        state.selected = ordered[1].slot
    end

    for index, row in ipairs(rows) do
        local slot = ordered[index]
        if slot then
            local inventorySlot = slot.slot + 1
            local link = GetInventoryItemLink("player", inventorySlot)
            slot.link = link
            slot.name = link or ("Item " .. slot.entry)
            row.slot = slot.slot
            row.icon:SetTexture(GetInventoryItemTexture("player", inventorySlot))
            row.name:SetText(slot.name)
            row.rank:SetText(string.format("%d/%d  (+%d%%)", slot.rank, state.maxRank,
                slot.rank * state.percent))
            if state.selected == slot.slot then
                row:LockHighlight()
            else
                row:UnlockHighlight()
            end
            row:Show()
        else
            row.slot = nil
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

    for index, button in ipairs(paymentButtons) do
        local definition = button.definition
        local count = selected and selected[definition.count] or 0
        button:SetText(definition.label .. " (" .. count .. ")")
        if selected and selected.rank < state.maxRank and count > 0 and allowed then
            button:Enable()
        else
            button:Disable()
        end
    end
end

local function RequestSync()
    if not state.syncing then
        state.syncing = true
        status:SetText("Syncing with the realm...")
        Send("CMD\tSYNC")
    end
end

frame:SetScript("OnShow", function()
    RequestSync()
end)

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
    if characterButton or not CharacterFrame then
        return
    end
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
        if prefix ~= PREFIX then
            return
        end
        local fields = Split(message)
        if fields[1] == "BEGIN" then
            state.slots = {}
            state.maxRank = tonumber(fields[2]) or 5
            state.percent = tonumber(fields[3]) or 5
        elseif fields[1] == "SLOT" then
            local slot = tonumber(fields[2])
            if slot then
                state.slots[slot] = {
                    slot = slot,
                    entry = tonumber(fields[3]) or 0,
                    rank = tonumber(fields[4]) or 0,
                    family = fields[5] or "",
                    matching = tonumber(fields[6]) or 0,
                    wildcard = tonumber(fields[7]) or 0,
                    duplicate = tonumber(fields[8]) or 0,
                    legendary = tonumber(fields[9]) or 0,
                }
            end
        elseif fields[1] == "END" then
            state.syncing = false
            status:SetText("Up to date.")
            frame:UpdateDisplay()
        elseif fields[1] == "RESULT" then
            status:SetText(fields[2] or "Upgrade complete.")
            DEFAULT_CHAT_FRAME:AddMessage("|cffb48cffArcana Upgrades:|r " .. (fields[2] or "Upgrade complete."))
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
        if frame:IsShown() then
            frame:UpdateDisplay()
        end
    end
end)

GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
    local _, link = tooltip:GetItem()
    if not link then
        return
    end
    for slotIndex, slot in pairs(state.slots) do
        if GetInventoryItemLink("player", slotIndex + 1) == link then
            tooltip:AddLine(string.format("Arcana Upgrade: %d/%d (+%d%%)", slot.rank,
                state.maxRank, slot.rank * state.percent), 0.71, 0.55, 1)
            tooltip:Show()
            return
        end
    end
end)

SLASH_ARCANAITEMUPGRADES1 = "/upgrades"
SLASH_ARCANAITEMUPGRADES2 = "/itemupgrades"
SlashCmdList["ARCANAITEMUPGRADES"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

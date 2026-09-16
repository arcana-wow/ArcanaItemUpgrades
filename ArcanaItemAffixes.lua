local P = ArcanaAffixProtocol
local state = P.New()
local snapshots, rolls = {}, {}
local pending, sequence = {}, 0
local frame = ArcanaItemUpgradesFrame
local ready, paying, refreshAt = false, false, nil

local function Send(text)
    SendAddonMessage("AAF", text, "WHISPER", UnitName("player"))
end
local function Sync() Send("SYNC") end
local function Allowed()
    local inside = IsInInstance()
    return not inside and not UnitIsDeadOrGhost("player") and not UnitAffectingCombat("player")
end
local function AddLine(tooltip, row)
    local text = row and P.Describe(row.packed)
    if not text or tooltip.arcanaAffixAdded then return end
    tooltip.arcanaAffixAdded = true
    tooltip:AddLine("Arcana Bonus: " .. text, 0.60, 0.82, 1)
    tooltip:Show()
end
local function CurrentLink(tooltip)
    local _, link = tooltip:GetItem()
    return link
end
local function Query(tooltip, context, first, second)
    local entry = P.Entry(CurrentLink(tooltip))
    if not entry then return end
    sequence = sequence + 1
    tooltip.arcanaAffixRequest = sequence
    pending[sequence] = { tooltip=tooltip, entry=entry, expires=GetTime()+5 }
    Send(table.concat({"Q", sequence, context, first, second or 0, entry}, "\t"))
end
local function SnapshotTooltip(tooltip, context, index)
    local row = snapshots[context] and snapshots[context][index]
    if P.Matches(row, CurrentLink(tooltip)) then AddLine(tooltip, row) end
end

local bonusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bonusText:SetPoint("BOTTOM", 0, 64)
local button = CreateFrame("Button", "ArcanaItemRecalibrateButton", frame, "UIPanelButtonTemplate")
button:SetWidth(180)
button:SetHeight(26)
button:SetPoint("BOTTOMRIGHT", -65, 23)
button:SetText("Recalibrate")
button:Disable()
local function RefreshControls()
    local slot = frame:GetSelectedEquipmentSlot()
    local row = slot and state.slots[slot]
    local text = row and P.Describe(row.packed)
    local sigils = GetItemCount(194500) or 0
    bonusText:SetText(text and ("Arcana Bonus: " .. text .. "     Recalibration Sigils: " .. sigils) or "")
    if ready and text and Allowed() and sigils > 0 and not paying then button:Enable() else button:Disable() end
end
StaticPopupDialogs["ARCANA_AFFIX_CONFIRM"] = {
    text="Consume one Arcana Recalibration Sigil to replace %s on %s? The new stat will be different and its amount may be lower.",
    button1=ACCEPT, button2=CANCEL, timeout=0, whileDead=false, hideOnEscape=true, preferredIndex=3,
    OnAccept=function(self, data)
        if not data or paying then return end
        paying = true
        Send(table.concat({"R", data.slot, data.guid, data.revision}, "\t"))
        RefreshControls()
    end,
}
button:SetScript("OnClick", function()
    local slot = frame:GetSelectedEquipmentSlot()
    local row = slot and state.slots[slot]
    local link = slot and GetInventoryItemLink("player", slot + 1)
    if not P.Matches(row, link) or not Allowed() or not P.Describe(row.packed) then Sync(); return end
    StaticPopup_Show("ARCANA_AFFIX_CONFIRM", P.Describe(row.packed), link,
        {slot=slot, guid=row.guid, revision=row.revision})
end)
hooksecurefunc(frame, "UpdateDisplay", RefreshControls)
frame:HookScript("OnShow", Sync)

local function HookTooltip(tooltip)
    tooltip:HookScript("OnTooltipCleared", function(self)
        self.arcanaAffixAdded, self.arcanaAffixRequest = nil, nil
    end)
    hooksecurefunc(tooltip, "SetBagItem", function(self, bag, slot) Query(self, "B", bag, slot) end)
    hooksecurefunc(tooltip, "SetInventoryItem", function(self, unit, slot)
        if UnitIsUnit(unit, "player") then Query(self, "E", slot, 0)
        elseif UnitGUID(unit) then Query(self, "I", slot, UnitGUID(unit)) end
    end)
    hooksecurefunc(tooltip, "SetTradePlayerItem", function(self, slot) Query(self, "T", 0, slot) end)
    hooksecurefunc(tooltip, "SetTradeTargetItem", function(self, slot) Query(self, "T", 1, slot) end)
    hooksecurefunc(tooltip, "SetBuybackItem", function(self, slot) Query(self, "Y", slot, 0) end)
    hooksecurefunc(tooltip, "SetLootItem", function(self, slot) SnapshotTooltip(self, 0, slot) end)
    hooksecurefunc(tooltip, "SetLootRollItem", function(self, roll)
        if P.Matches(rolls[roll], CurrentLink(self)) then AddLine(self, rolls[roll]) end
    end)
    hooksecurefunc(tooltip, "SetInboxItem", function(self, mail, attachment)
        SnapshotTooltip(self, 5, mail * 16 + (attachment or 1))
    end)
    hooksecurefunc(tooltip, "SetAuctionItem", function(self, kind, index)
        local _, _, count, _, _, _, minimum, _, buyout, bid, _, owner = GetAuctionItemInfo(kind, index)
        local key = P.AuctionKey(GetAuctionItemLink(kind, index), count, minimum, buyout, bid, owner)
        local row, ambiguous = P.AuctionRow(snapshots[({list=2, owner=3, bidder=4})[kind]], key)
        if row then AddLine(self, row)
        elseif ambiguous then
            self:AddLine("Arcana bonuses differ between matching listings.", 1, 0.7, 0.3)
            self:Show()
        end
    end)
end
HookTooltip(GameTooltip)

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "CHAT_MSG_ADDON", "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "LOOT_OPENED", "LOOT_CLOSED",
    "LOOT_SLOT_CLEARED", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "AUCTION_ITEM_LIST_UPDATE",
    "AUCTION_OWNED_LIST_UPDATE", "AUCTION_BIDDER_LIST_UPDATE", "AUCTION_HOUSE_CLOSED", "MAIL_INBOX_UPDATE",
    "MAIL_CLOSED", "PLAYER_DEAD", "PLAYER_ALIVE"}) do events:RegisterEvent(event) end
local contextEvents = { LOOT_OPENED=0, AUCTION_ITEM_LIST_UPDATE=2, AUCTION_OWNED_LIST_UPDATE=3,
    AUCTION_BIDDER_LIST_UPDATE=4, MAIL_INBOX_UPDATE=5 }
events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if type(RegisterAddonMessagePrefix) == "function" then RegisterAddonMessagePrefix("AAF") end
        Sync()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix ~= "AAF" or channel ~= "WHISPER" or sender ~= UnitName("player") then return end
        local f = P.Receive(state, message)
        if f[1] == "DONE" then ready = true; frame:SetAffixSlots(state.slots); RefreshControls()
        elseif f[1] == "RESULT" then
            paying = false
            DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffArcana:|r " .. (f[2] or "Recalibration response received."))
            RefreshControls()
        elseif f[1] == "V" then
            local id = P.UInt(f[2])
            local request = id and pending[id]
            local row = P.Row(f, 3)
            if request then
                pending[id] = nil
                if request.expires >= GetTime() and request.tooltip.arcanaAffixRequest == id and
                    request.tooltip:IsShown() and P.Matches(row, CurrentLink(request.tooltip)) and
                    row.entry == request.entry then AddLine(request.tooltip, row) end
            end
        end
    elseif contextEvents[event] ~= nil then
        local context = contextEvents[event]
        snapshots[context] = P.Take(state, context)
    elseif event == "START_LOOT_ROLL" then
        local roll = ...
        local rows = P.Take(state, 1)
        if P.Matches(rows[0], GetLootRollItemLink(roll)) then rolls[roll] = rows[0] end
    elseif event == "CANCEL_LOOT_ROLL" then rolls[(...)] = nil
    elseif event == "LOOT_CLOSED" then snapshots[0] = nil
    elseif event == "LOOT_SLOT_CLEARED" then
        if snapshots[0] then snapshots[0][(...)] = nil end
    elseif event == "MAIL_CLOSED" then snapshots[5] = nil
    elseif event == "AUCTION_HOUSE_CLOSED" then snapshots[2], snapshots[3], snapshots[4] = nil, nil, nil
    else
        refreshAt = GetTime() + 0.2
        RefreshControls()
    end
end)
events:SetScript("OnUpdate", function()
    local now = GetTime()
    if refreshAt and now >= refreshAt then refreshAt = nil; Sync() end
    for id, request in pairs(pending) do if request.expires < now then pending[id] = nil end end
end)

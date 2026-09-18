local P = ArcanaAffixProtocol
local state = P.New()
local snapshots, rolls = {}, {}
local snapshotWaiting = {}
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
-- A tooltip rebuild clears its font strings even when the hovered item has not
-- changed. Keep the resolved instance separate from the currently drawn line.
local epochs = { B=0, E=0, T=0, Y=0, I=0 }
local equipmentFresh, bagsFresh = false, false
local refreshTooltip = false
local function CurrentLink(tooltip)
    local _, link = tooltip:GetItem()
    return link
end
local function RemoveLine(tooltip)
    local line = tooltip.arcanaAffixLine
    if line and line.font:GetText() == line.rendered then
        line.font:SetText(line.original)
        if tooltip:IsShown() then tooltip:Show() end
    end
    tooltip.arcanaAffixLine = nil
end
local function Plain(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end
local function FormatPattern(format)
    -- Match localized client strings, including positional printf arguments.
    local pattern = format:gsub("%%[%d%$]*[sd]", "\001")
    return "^" .. pattern:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("\001", ".+")
end
local function IsFooter(text)
    if text == "" or text:find("^Arcana Upgrade:") then return true end
    for _, name in ipairs({"DURABILITY_TEMPLATE", "ITEM_MIN_LEVEL", "ITEM_MIN_SKILL", "ITEM_REQ_SKILL",
        "ITEM_CLASSES_ALLOWED", "ITEM_RACES_ALLOWED", "ITEM_SPELL_TRIGGER_ONEQUIP",
        "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONPROC", "ITEM_SOCKET_BONUS",
        "EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_META",
        "EMPTY_SOCKET_PRISMATIC", "ITEM_SET_NAME"}) do
        local format = _G[name]
        if format and text:find(FormatPattern(format)) then return true end
    end
    return false
end
local function PermanentEnchant(link)
    local enchant = type(link) == "string" and tonumber(link:match("item:%d+:(%-?%d+):"))
    return enchant and enchant > 0
end
local function Green(font)
    if not font or not font:GetText() then return false end
    local r, g, b = font:GetTextColor()
    return r and r < 0.2 and g and g > 0.8 and b and b < 0.2
end
local function RenderLine(tooltip, text)
    local old = tooltip.arcanaAffixLine
    if old and old.text == text and old.font:GetText() == old.rendered then return end
    RemoveLine(tooltip)
    local name, count = tooltip:GetName(), tooltip:NumLines()
    if not name or count < 1 then return end
    local anchor = count
    -- Filled sockets use gem text rather than "Red Socket". Their textures are
    -- attached to native left-hand rows, so stop before the first such row.
    for _, region in ipairs({tooltip:GetRegions()}) do
        if region:GetObjectType() == "Texture" and region:IsShown() then
            for point = 1, region:GetNumPoints() do
                local _, relative = region:GetPoint(point)
                local relativeName = type(relative) == "string" and relative or
                    (relative and relative:GetName())
                local index = relativeName and tonumber(relativeName:match("^" .. name .. "TextLeft(%d+)$"))
                if index and index > 1 and index <= count then anchor = math.min(anchor, index - 1) end
            end
        end
    end
    for i = 2, count do
        local font = _G[name .. "TextLeft" .. i]
        if font and IsFooter(Plain(font:GetText())) then anchor = math.min(anchor, i - 1); break end
    end
    local font
    if PermanentEnchant(CurrentLink(tooltip)) then
        for i = 2, anchor do
            local candidate = _G[name .. "TextLeft" .. i]
            if Green(candidate) then font = candidate; break end
        end
    end
    local before = font ~= nil
    font = font or _G[name .. "TextLeft" .. anchor]
    if not font then return end
    local original = font:GetText() or ""
    -- Extend one native left-hand row instead of copying/reordering tooltip
    -- regions. Permanent enchants retain their own row directly below Arcana.
    local bonus = text and ("|cff00ff00" .. text .. "|r") or "|c00000000 |r"
    local rendered = before and (bonus .. "\n" .. original) or (original .. "\n" .. bonus)
    font:SetText(rendered)
    tooltip.arcanaAffixLine = { font=font, original=original, rendered=rendered, text=text }
    tooltip:Show()
end
local function AddLine(tooltip, row)
    local text = row and P.Describe(row.packed)
    if not text then RemoveLine(tooltip); return end
    RenderLine(tooltip, text)
end
local function ReserveLine(tooltip)
    if type(GetItemInfo) ~= "function" then return end
    local _, _, quality, _, _, _, _, _, equip = GetItemInfo(CurrentLink(tooltip))
    if quality and quality >= 3 and quality <= 5 and equip and equip ~= "" then RenderLine(tooltip, nil) end
end
local function CancelRequest(view)
    if view and view.request then pending[view.request] = nil; view.request = nil end
end
local function Query(tooltip, context, first, second)
    local link = CurrentLink(tooltip)
    local entry = P.Entry(link)
    if not entry then return end
    second = second or 0
    local key = table.concat({context, first, second, epochs[context], link}, "\t")
    local view = tooltip.arcanaAffixCache
    if not view or view.key ~= key then
        CancelRequest(view)
        RemoveLine(tooltip)
        view = { tooltip=tooltip, context=context, first=first, second=second,
            key=key, link=link, entry=entry }
        tooltip.arcanaAffixCache = view
    end
    tooltip.arcanaAffixView = view
    if context == "E" and equipmentFresh and first <= 19 then
        local row = state.slots[first - 1]
        if P.Matches(row, link) then view.row = row; CancelRequest(view) end
    end
    if context == "B" and bagsFresh then
        local row = state.bags[P.BagKey(first, second) or ""]
        if P.Matches(row, link) then
            view.row, view.known = row, true
            CancelRequest(view)
        elseif not row then
            view.known = true
            CancelRequest(view)
        end
    end
    if view.row then AddLine(tooltip, view.row) end
    if view.known then return end
    -- Inspection has no reliable local inventory-change notification for the
    -- other player. Revalidate in the background without hiding the last reply.
    if view.row and (context ~= "I" or GetTime() < view.validUntil) then return end
    if view.retryAt and GetTime() < view.retryAt then return end
    if context == "B" then ReserveLine(tooltip) end
    if view.request and pending[view.request] then return end
    sequence = sequence + 1
    view.request, view.expires = sequence, GetTime() + 5
    pending[sequence] = view
    Send(table.concat({"Q", sequence, context, first, second, entry}, "\t"))
end
local function Invalidate(context)
    epochs[context] = epochs[context] + 1
    if context == "E" then equipmentFresh = false end
    if context == "B" then bagsFresh = false end
    local tooltip = GameTooltip
    local view = tooltip.arcanaAffixCache
    if view and view.context == context then
        CancelRequest(view)
        tooltip.arcanaAffixCache = nil
        if tooltip.arcanaAffixView == view then
            RemoveLine(tooltip)
            refreshTooltip = true
        end
    end
end
local function RefreshTooltip()
    local tooltip = GameTooltip
    local view = tooltip.arcanaAffixView
    if view and tooltip:IsShown() and CurrentLink(tooltip) == view.link then
        Query(tooltip, view.context, view.first, view.second)
    end
end
local function SnapshotTooltip(tooltip, context, index)
    local link = CurrentLink(tooltip)
    tooltip.arcanaAffixSnapshot = { context=context, index=index, link=link }
    local row = snapshots[context] and snapshots[context][index]
    if P.Matches(row, link) then AddLine(tooltip, row)
    else
        RemoveLine(tooltip)
        if snapshotWaiting[context] then ReserveLine(tooltip) end
    end
end
local auctionContexts = { list=2, owner=3, bidder=4 }
local function AuctionTooltip(tooltip, kind, index)
    local context, link = auctionContexts[kind], CurrentLink(tooltip)
    if not context then return end
    local _, _, count, _, _, _, minimum, _, buyout, bid, _, owner = GetAuctionItemInfo(kind, index)
    local key = P.AuctionKey(GetAuctionItemLink(kind, index), count, minimum, buyout, bid, owner)
    tooltip.arcanaAffixSnapshot = {
        context=context, index=index, link=link, auction=true, kind=kind,
    }
    local row, ambiguous = P.AuctionRow(snapshots[context], key)
    if row then
        AddLine(tooltip, row)
    else
        RemoveLine(tooltip)
        if ambiguous then
            tooltip:AddLine("Arcana bonuses differ between matching listings.", 1, 0.7, 0.3)
            tooltip:Show()
        elseif snapshotWaiting[context] then
            ReserveLine(tooltip)
        end
    end
end
local function RefreshSnapshotTooltip(tooltip, view)
    if view.auction then AuctionTooltip(tooltip, view.kind, view.index)
    else SnapshotTooltip(tooltip, view.context, view.index) end
end
local function PublishSnapshot(context)
    local rows, available = P.Take(state, context)
    if not available then
        -- A native result event can precede its addon-message snapshot. The
        -- previous page must not remain eligible while the replacement waits.
        snapshots[context], snapshotWaiting[context] = nil, true
    else
        snapshots[context], snapshotWaiting[context] = rows, nil
    end
    local tooltip, view = GameTooltip, GameTooltip.arcanaAffixSnapshot
    if view and view.context == context and tooltip:IsShown() and CurrentLink(tooltip) == view.link then
        RefreshSnapshotTooltip(tooltip, view)
    end
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
        self.arcanaAffixLine, self.arcanaAffixView, self.arcanaAffixSnapshot = nil, nil, nil
    end)
    tooltip:HookScript("OnHide", function(self)
        CancelRequest(self.arcanaAffixCache)
        self.arcanaAffixCache, self.arcanaAffixView, self.arcanaAffixSnapshot = nil, nil, nil
        RemoveLine(self)
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
    hooksecurefunc(tooltip, "SetAuctionItem", AuctionTooltip)
end
HookTooltip(GameTooltip)

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "CHAT_MSG_ADDON", "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "LOOT_OPENED", "LOOT_CLOSED",
    "LOOT_SLOT_CLEARED", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "AUCTION_ITEM_LIST_UPDATE",
    "AUCTION_OWNED_LIST_UPDATE", "AUCTION_BIDDER_LIST_UPDATE", "AUCTION_HOUSE_CLOSED", "MAIL_INBOX_UPDATE",
    "MAIL_CLOSED", "PLAYER_DEAD", "PLAYER_ALIVE", "UNIT_INVENTORY_CHANGED",
    "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BANKFRAME_CLOSED",
    "MERCHANT_UPDATE", "MERCHANT_CLOSED", "TRADE_SHOW", "TRADE_CLOSED",
    "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(event) end
local invalidations = {
    BAG_UPDATE={"B", "E", "Y"}, PLAYER_EQUIPMENT_CHANGED={"E", "B"},
    PLAYERBANKSLOTS_CHANGED={"B", "E"}, PLAYERBANKBAGSLOTS_CHANGED={"B", "E"},
    BANKFRAME_CLOSED={"B", "E"}, MERCHANT_UPDATE={"Y", "B", "E"}, MERCHANT_CLOSED={"Y"},
    TRADE_SHOW={"T"}, TRADE_CLOSED={"T"}, TRADE_PLAYER_ITEM_CHANGED={"T"},
    TRADE_TARGET_ITEM_CHANGED={"T"}, PLAYER_ENTERING_WORLD={"B", "E", "Y", "T", "I"},
}
local contextEvents = { LOOT_OPENED=0, AUCTION_ITEM_LIST_UPDATE=2, AUCTION_OWNED_LIST_UPDATE=3,
    AUCTION_BIDDER_LIST_UPDATE=4, MAIL_INBOX_UPDATE=5 }
events:SetScript("OnEvent", function(self, event, ...)
    for _, context in ipairs(invalidations[event] or {}) do Invalidate(context) end
    if event == "UNIT_INVENTORY_CHANGED" then
        Invalidate("I")
        if UnitIsUnit((...), "player") then Invalidate("E"); Invalidate("B") end
    end
    if event == "PLAYER_LOGIN" then
        if type(RegisterAddonMessagePrefix) == "function" then RegisterAddonMessagePrefix("AAF") end
        Sync()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix ~= "AAF" or channel ~= "WHISPER" or sender ~= UnitName("player") then return end
        local f, completedContext = P.Receive(state, message)
        if f[1] == "SYNC" then
            Invalidate("E")
        elseif f[1] == "DONE" then
            equipmentFresh, bagsFresh, ready = true, true, true
            frame:SetAffixSlots(state.slots); RefreshControls(); RefreshTooltip()
        elseif f[1] == "RESULT" then
            paying = false
            Invalidate("E"); Invalidate("B")
            DEFAULT_CHAT_FRAME:AddMessage("|cff99ccffArcana:|r " .. (f[2] or "Recalibration response received."))
            RefreshControls()
        elseif f[1] == "V" then
            local id = P.UInt(f[2])
            local request = id and pending[id]
            local row = P.Row(f, 3)
            if request then
                pending[id], request.request = nil, nil
                local tooltip = request.tooltip
                if request.expires >= GetTime() and tooltip.arcanaAffixCache == request and row then
                    if row.entry == request.entry then
                        request.row, request.validUntil, request.retryAt = row, GetTime() + 1, nil
                    else
                        -- Empty/rejected resolution must not retain an old inspection
                        -- bonus or hammer the server on every native tooltip update.
                        request.row, request.retryAt = nil, GetTime() + 1
                    end
                    if tooltip.arcanaAffixView == request and tooltip:IsShown() and
                        CurrentLink(tooltip) == request.link then AddLine(tooltip, request.row) end
                end
            end
        end
        if completedContext ~= nil and snapshotWaiting[completedContext] then
            PublishSnapshot(completedContext)
        end
    elseif contextEvents[event] ~= nil then
        local context = contextEvents[event]
        PublishSnapshot(context)
    elseif event == "START_LOOT_ROLL" then
        local roll = ...
        local rows = P.Take(state, 1)
        if P.Matches(rows[0], GetLootRollItemLink(roll)) then rolls[roll] = rows[0] end
    elseif event == "CANCEL_LOOT_ROLL" then rolls[(...)] = nil
    elseif event == "LOOT_CLOSED" then
        snapshots[0], snapshotWaiting[0] = nil, nil
        P.ClearContext(state, 0)
    elseif event == "LOOT_SLOT_CLEARED" then
        if snapshots[0] then snapshots[0][(...)] = nil end
    elseif event == "MAIL_CLOSED" then
        snapshots[5], snapshotWaiting[5] = nil, nil
        P.ClearContext(state, 5)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        for context = 2, 4 do
            snapshots[context], snapshotWaiting[context] = nil, nil
            P.ClearContext(state, context)
        end
    else
        refreshAt = GetTime() + 0.2
        RefreshControls()
    end
end)
events:SetScript("OnUpdate", function()
    local now = GetTime()
    if refreshAt and now >= refreshAt then refreshAt = nil; Sync() end
    for id, request in pairs(pending) do
        if request.expires < now then
            pending[id], request.request = nil, nil
            refreshTooltip = true
        end
    end
    if refreshTooltip then refreshTooltip = false; RefreshTooltip() end
end)

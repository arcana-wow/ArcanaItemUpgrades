local P = ArcanaAffixProtocol
local state = P.New()
local snapshots, rolls = {}, {}
local snapshotWaiting = {}
local auctionResolved, auctionPending, auctionRequestKeys = { [2]={}, [3]={}, [4]={} }, {}, {}
local auctionEpoch = { [2]=0, [3]=0, [4]=0 }
local pending, sequence = {}, 0
local frame = ArcanaItemUpgradesFrame
local ready, paying, refreshAt = false, false, nil
local lootOpen, lootEpoch, refreshLootTooltip = false, 0, false

local function Send(text)
    SendAddonMessage("AAF", text, "WHISPER", UnitName("player"))
end
local function Sync() Send("SYNC") end
local function ClearAuctionContext(context)
    auctionEpoch[context] = auctionEpoch[context] + 1
    auctionResolved[context] = {}
    for id, request in pairs(auctionPending) do
        if request.context == context then
            auctionPending[id], auctionRequestKeys[request.key] = nil, nil
        end
    end
end
local function RequestAuction(view)
    if not view.identity then return end
    local key = table.concat({view.context, view.epoch, view.identity}, "\t")
    if auctionRequestKeys[key] then return end
    sequence = sequence + 1
    local message = table.concat({"A", sequence, view.context, view.identity}, "\t")
    if #message > 240 then
        auctionResolved[view.context][view.identity] = { missing=true }
        return
    end
    auctionPending[sequence] = {
        context=view.context, epoch=view.epoch, identity=view.identity,
        entry=P.Entry(view.link), key=key,
    }
    auctionRequestKeys[key] = sequence
    Send(message)
end
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
local function EnchantRequirement(text)
    for _, name in ipairs({"ENCHANT_ITEM_MIN_SKILL", "ENCHANT_ITEM_REQ_SKILL", "ENCHANT_ITEM_REQ_LEVEL"}) do
        local format = _G[name]
        if format and text:find(FormatPattern(format)) then return true end
    end
    return false
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
        local first = 2
        local _, _, _, _, _, _, _, _, equip = GetItemInfo(CurrentLink(tooltip))
        local slotText = equip and _G[equip]
        -- Heroic and other header labels can be green too. Enchants belong
        -- below the localized equipment-type row, after the native stats.
        for i = 2, anchor do
            local candidate = _G[name .. "TextLeft" .. i]
            if slotText and candidate and Plain(candidate:GetText()) == slotText then first = i + 1; break end
        end
        for i = first, anchor do
            local candidate = _G[name .. "TextLeft" .. i]
            local following = _G[name .. "TextLeft" .. (i + 1)]
            local value = candidate and Plain(candidate:GetText())
            -- Unusable profession/runeforging enchants are red and followed
            -- by their enchant requirement. Preserve both native rows.
            if value and value ~= ITEM_HEROIC and (Green(candidate) or
                (following and EnchantRequirement(Plain(following:GetText())))) then
                font = candidate; break
            end
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
-- Only the open native inspection window owns a preload cache. Other tooltip
-- providers retain the ordinary per-hover request lifecycle.
local inspection, inspectionQueryAt = nil, 0
local function InspectionUnit()
    local window = InspectFrame
    local unit = window and window:IsShown() and window.unit
    return unit and not UnitIsUnit(unit, "player") and unit or nil
end
local function ClearInspectionViews()
    if not inspection then return end
    for _, view in pairs(inspection.views) do CancelRequest(view) end
    inspection.views = {}
    local tooltip = GameTooltip
    local view = tooltip.arcanaAffixCache
    if view and view.inspection == inspection then
        tooltip.arcanaAffixCache, tooltip.arcanaAffixHiddenInspection = nil, nil
        if tooltip.arcanaAffixView == view then RemoveLine(tooltip); refreshTooltip = true end
    end
end
local function CloseInspection()
    local view = GameTooltip.arcanaAffixView
    ClearInspectionViews()
    if inspection and view and view.inspection == inspection then GameTooltip.arcanaAffixView = nil end
    inspection = nil
end
local function CurrentInspection()
    local unit = InspectionUnit()
    local guid = unit and UnitGUID(unit)
    if not guid then CloseInspection(); return nil end
    if not inspection or inspection.guid ~= guid then
        CloseInspection()
        inspection = { unit=unit, guid=guid, views={}, remaining=17, scanUntil=GetTime() + 5 }
    end
    inspection.unit = unit
    return inspection
end
local function InspectionView(slot, link, entry, guid)
    local current = CurrentInspection()
    if not current or current.guid ~= guid or slot < 1 or slot > 19 or
        GetInventoryItemLink(current.unit, slot) ~= link then return nil end
    local view = current.views[slot]
    if not view or view.link ~= link then
        CancelRequest(view)
        view = { tooltip=GameTooltip, context="I", first=slot, second=guid,
            key=table.concat({"I", slot, guid, epochs.I, link}, "\t"),
            link=link, entry=entry, inspection=current }
        current.views[slot] = view
    end
    return view
end
local function CurrentInspectionView(view)
    local unit = InspectionUnit()
    return view and view.inspection and view.inspection == inspection and
        unit and UnitGUID(unit) == inspection.guid and
        inspection.views[view.first] == view and
        GetInventoryItemLink(inspection.unit, view.first) == view.link
end
local function DetachRequest(view)
    if not CurrentInspectionView(view) then CancelRequest(view) end
end
local function Request(view)
    if view.request and pending[view.request] then return end
    sequence = sequence + 1
    view.request, view.expires = sequence, GetTime() + 5
    pending[sequence] = view
    Send(table.concat({"Q", sequence, view.context, view.first, view.second, view.entry}, "\t"))
end
local function PreloadInspection(now)
    local current = CurrentInspection()
    if not current or now < inspectionQueryAt or now > current.scanUntil or current.remaining == 0 then return end
    inspectionQueryAt = now + 0.1
    -- At most one preload per 100 ms, 17 per opening, and no refresh sweep.
    -- Cold/missing links may appear during the first five seconds. Hovers can
    -- always query immediately and share any already pending preload.
    for slot = 1, 18 do
        if slot ~= 4 then
            local link = GetInventoryItemLink(current.unit, slot)
            local entry = P.Entry(link)
            if entry and not current.views[slot] then
                local view = InspectionView(slot, link, entry, current.guid)
                current.remaining = current.remaining - 1
                Request(view)
                return
            end
        end
    end
end
local function HookInspection()
    if not InspectFrame or InspectFrame.arcanaAffixHooked then return end
    InspectFrame.arcanaAffixHooked = true
    InspectFrame:HookScript("OnShow", function() CloseInspection(); CurrentInspection() end)
    InspectFrame:HookScript("OnHide", CloseInspection)
end
HookInspection()

local function Query(tooltip, context, first, second)
    local link = CurrentLink(tooltip)
    local entry = P.Entry(link)
    if not entry then return end
    second = second or 0
    local key = table.concat({context, first, second, epochs[context], link}, "\t")
    local view = tooltip.arcanaAffixCache
    if not view or view.key ~= key then
        DetachRequest(view)
        RemoveLine(tooltip)
        view = context == "I" and InspectionView(first, link, entry, second) or nil
        view = view or { tooltip=tooltip, context=context, first=first, second=second,
            key=key, link=link, entry=entry }
        tooltip.arcanaAffixCache = view
    end
    tooltip.arcanaAffixView = view
    tooltip.arcanaAffixHiddenInspection = nil
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
    if view.inspection and view.row and GetTime() >= view.keepUntil then view.row = nil end
    if view.row then AddLine(tooltip, view.row) end
    if view.known then return end
    -- Inspection has no reliable local inventory-change notification for the
    -- other player. Revalidate in the background without hiding the last reply.
    if view.row and (context ~= "I" or GetTime() < view.validUntil) then return end
    if view.retryAt and GetTime() < view.retryAt then return end
    if context == "B" or (context == "I" and not view.row) then ReserveLine(tooltip) end
    Request(view)
end
local function Invalidate(context)
    epochs[context] = epochs[context] + 1
    if context == "I" then ClearInspectionViews() end
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
local function ClearLootView(tooltip)
    tooltip.arcanaAffixLoot = nil
    local view = tooltip.arcanaAffixSnapshot
    if view and view.context == 0 then tooltip.arcanaAffixSnapshot = nil end
end
local function SameTooltipOwner(tooltip, view)
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    return not view.owner or not owner or view.owner == owner
end
local function CurrentLootView(tooltip)
    local view = tooltip.arcanaAffixLoot
    if not view or not lootOpen or view.epoch ~= lootEpoch or not tooltip:IsShown() or
        not SameTooltipOwner(tooltip, view) then return nil end
    local link = CurrentLink(tooltip)
    if view.link and link ~= view.link then return nil end
    return view, link
end
local function SnapshotTooltip(tooltip, context, index)
    local link = CurrentLink(tooltip)
    local view = { context=context, index=index, link=link }
    if context == 0 and lootOpen then
        view.epoch = lootEpoch
        view.owner = tooltip.GetOwner and tooltip:GetOwner()
        tooltip.arcanaAffixLoot = view
    else
        ClearLootView(tooltip)
    end
    tooltip.arcanaAffixSnapshot = view
    local row = snapshots[context] and snapshots[context][index]
    if P.Matches(row, link) then AddLine(tooltip, row)
    else
        RemoveLine(tooltip)
        if snapshotWaiting[context] then ReserveLine(tooltip) end
    end
end
local function RestoreLootTooltip(tooltip)
    local view, link = CurrentLootView(tooltip)
    if not view then return end
    if not view.link and link then view.link = link end
    SnapshotTooltip(tooltip, 0, view.index)
end
local auctionContexts = { list=2, owner=3, bidder=4 }
local function AuctionTooltip(tooltip, kind, index)
    local context, link = auctionContexts[kind], CurrentLink(tooltip)
    if not context then return end
    local _, _, count, _, _, _, minimum, _, buyout, bid, _, owner = GetAuctionItemInfo(kind, index)
    local identity = P.AuctionKey(GetAuctionItemLink(kind, index), count, minimum, buyout, bid, owner)
    local view = {
        context=context, index=index, link=link, auction=true, kind=kind,
        identity=identity, epoch=auctionEpoch[context],
    }
    tooltip.arcanaAffixSnapshot = view
    local row, ambiguous = P.AuctionRow(snapshots[context], identity)
    local direct = identity and auctionResolved[context] and auctionResolved[context][identity]
    if row then
        AddLine(tooltip, row)
    elseif ambiguous or (direct and direct.ambiguous) then
        RemoveLine(tooltip)
        tooltip:AddLine("Arcana bonuses differ between matching listings.", 1, 0.7, 0.3)
        tooltip:Show()
    elseif direct then
        if direct.row then AddLine(tooltip, direct.row) else RemoveLine(tooltip) end
    else
        RemoveLine(tooltip)
        if snapshotWaiting[context] then ReserveLine(tooltip) end
        RequestAuction(view)
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
    local tooltip = GameTooltip
    local view = tooltip.arcanaAffixSnapshot or (context == 0 and tooltip.arcanaAffixLoot)
    if view and view.context == context and tooltip:IsShown() and CurrentLink(tooltip) == view.link then
        RefreshSnapshotTooltip(tooltip, view)
    elseif context == 0 and CurrentLootView(tooltip) then
        refreshLootTooltip = true
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
    tooltip:HookScript("OnTooltipSetItem", function(self)
        if CurrentLootView(self) then refreshLootTooltip = true end
    end)
    tooltip:HookScript("OnHide", function(self)
        local view = self.arcanaAffixCache
        if view and view.context == "I" then
            -- InspectPaperDoll's OnUpdate calls SetOwner before SetInventoryItem.
            -- That intermediate hide is not a mouse leave. Retain the request
            -- until the next update; only Query with the same full identity can
            -- reattach it. A real leave retires the tooltip binding; only an
            -- open native inspection session may retain the slot's request.
            self.arcanaAffixHiddenInspection = view
        else
            CancelRequest(view)
            self.arcanaAffixCache, self.arcanaAffixHiddenInspection = nil, nil
        end
        self.arcanaAffixView, self.arcanaAffixSnapshot, self.arcanaAffixLoot = nil, nil, nil
        RemoveLine(self)
    end)
    hooksecurefunc(tooltip, "SetBagItem", function(self, bag, slot) ClearLootView(self); Query(self, "B", bag, slot) end)
    hooksecurefunc(tooltip, "SetInventoryItem", function(self, unit, slot)
        ClearLootView(self)
        if UnitIsUnit(unit, "player") then Query(self, "E", slot, 0)
        elseif UnitGUID(unit) then Query(self, "I", slot, UnitGUID(unit)) end
    end)
    hooksecurefunc(tooltip, "SetTradePlayerItem", function(self, slot) ClearLootView(self); Query(self, "T", 0, slot) end)
    hooksecurefunc(tooltip, "SetTradeTargetItem", function(self, slot) ClearLootView(self); Query(self, "T", 1, slot) end)
    hooksecurefunc(tooltip, "SetBuybackItem", function(self, slot) ClearLootView(self); Query(self, "Y", slot, 0) end)
    hooksecurefunc(tooltip, "SetLootItem", function(self, slot) SnapshotTooltip(self, 0, slot) end)
    hooksecurefunc(tooltip, "SetLootRollItem", function(self, roll)
        ClearLootView(self)
        if P.Matches(rolls[roll], CurrentLink(self)) then AddLine(self, rolls[roll]) end
    end)
    hooksecurefunc(tooltip, "SetInboxItem", function(self, mail, attachment)
        SnapshotTooltip(self, 5, mail * 16 + (attachment or 1))
    end)
    hooksecurefunc(tooltip, "SetAuctionItem", function(self, kind, index)
        ClearLootView(self)
        AuctionTooltip(self, kind, index)
    end)
end
HookTooltip(GameTooltip)

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "CHAT_MSG_ADDON", "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "LOOT_OPENED", "LOOT_CLOSED",
    "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "AUCTION_ITEM_LIST_UPDATE",
    "AUCTION_OWNED_LIST_UPDATE", "AUCTION_BIDDER_LIST_UPDATE", "AUCTION_HOUSE_CLOSED", "MAIL_INBOX_UPDATE",
    "MAIL_CLOSED", "PLAYER_DEAD", "PLAYER_ALIVE", "UNIT_INVENTORY_CHANGED",
    "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BANKFRAME_CLOSED", "ADDON_LOADED",
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
        local unit = ...
        local guid = unit and UnitGUID(unit)
        local view = GameTooltip.arcanaAffixCache
        if guid and ((inspection and guid == inspection.guid) or
            (view and view.context == "I" and guid == view.second)) then Invalidate("I") end
        if unit and UnitIsUnit(unit, "player") then Invalidate("E"); Invalidate("B") end
    end
    if event == "ADDON_LOADED" then
        if (...) == "Blizzard_InspectUI" then HookInspection() end
    elseif event == "PLAYER_LOGIN" then
        if type(RegisterAddonMessagePrefix) == "function" then RegisterAddonMessagePrefix("AAF") end
        Sync()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix ~= "AAF" or channel ~= "WHISPER" or sender ~= UnitName("player") then return end
        local f, completedContext = P.Receive(state, message)
        if f[1] == "AV" then
            local id, status = P.UInt(f[2]), P.UInt(f[3])
            local request = id and auctionPending[id]
            if request then
                auctionPending[id], auctionRequestKeys[request.key] = nil, nil
                if request.epoch == auctionEpoch[request.context] and status and status <= 2 then
                    local result = {}
                    if status == 1 then
                        local row = P.Row(f, 4)
                        if not row or row.entry ~= request.entry then return end
                        result.row = row
                    elseif status == 2 then
                        result.ambiguous = true
                    else
                        result.missing = true
                    end
                    auctionResolved[request.context][request.identity] = result
                    local tooltip, view = GameTooltip, GameTooltip.arcanaAffixSnapshot
                    if view and view.auction and view.context == request.context and
                        view.epoch == request.epoch and view.identity == request.identity and
                        tooltip:IsShown() and CurrentLink(tooltip) == view.link then
                        RefreshSnapshotTooltip(tooltip, view)
                    end
                end
            end
        elseif f[1] == "SYNC" then
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
                local current = request.inspection and CurrentInspectionView(request) or
                    (not request.inspection and tooltip.arcanaAffixCache == request)
                if request.expires >= GetTime() and current and row then
                    if row.entry == request.entry then
                        request.row, request.validUntil, request.retryAt = row, GetTime() + 1, nil
                        request.keepUntil = GetTime() + 30
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
        if context == 0 then
            lootOpen, lootEpoch = true, lootEpoch + 1
            ClearLootView(GameTooltip)
        end
        if context >= 2 and context <= 4 then ClearAuctionContext(context) end
        PublishSnapshot(context)
    elseif event == "START_LOOT_ROLL" then
        local roll = ...
        local rows = P.Take(state, 1)
        if P.Matches(rows[0], GetLootRollItemLink(roll)) then rolls[roll] = rows[0] end
    elseif event == "CANCEL_LOOT_ROLL" then rolls[(...)] = nil
    elseif event == "LOOT_CLOSED" then
        lootOpen, lootEpoch, refreshLootTooltip = false, lootEpoch + 1, false
        ClearLootView(GameTooltip)
        snapshots[0], snapshotWaiting[0] = nil, nil
        P.ClearContext(state, 0)
    elseif event == "LOOT_SLOT_CLEARED" then
        local slot = ...
        if snapshots[0] then snapshots[0][slot] = nil end
        local view = GameTooltip.arcanaAffixLoot
        if view and view.epoch == lootEpoch and view.index == slot then
            ClearLootView(GameTooltip)
            RemoveLine(GameTooltip)
        end
    elseif event == "LOOT_SLOT_CHANGED" then
        local view = GameTooltip.arcanaAffixLoot
        if view and view.epoch == lootEpoch and view.index == (...) then refreshLootTooltip = true end
    elseif event == "MAIL_CLOSED" then
        snapshots[5], snapshotWaiting[5] = nil, nil
        P.ClearContext(state, 5)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        for context = 2, 4 do
            snapshots[context], snapshotWaiting[context] = nil, nil
            ClearAuctionContext(context)
            P.ClearContext(state, context)
        end
    else
        refreshAt = GetTime() + 0.2
        RefreshControls()
    end
end)
events:SetScript("OnUpdate", function()
    local now = GetTime()
    PreloadInspection(now)
    local tooltip = GameTooltip
    local hidden = tooltip.arcanaAffixHiddenInspection
    if hidden then
        tooltip.arcanaAffixHiddenInspection = nil
        if tooltip.arcanaAffixCache == hidden then
            DetachRequest(hidden)
            tooltip.arcanaAffixCache = nil
        end
    end
    if refreshAt and now >= refreshAt then refreshAt = nil; Sync() end
    for id, request in pairs(pending) do
        if request.expires < now then
            pending[id], request.request = nil, nil
            refreshTooltip = true
        end
    end
    if refreshTooltip then refreshTooltip = false; RefreshTooltip() end
    if refreshLootTooltip then refreshLootTooltip = false; RestoreLootTooltip(GameTooltip) end
end)

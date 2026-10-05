-- Native item links do not identify Arcana instances. Resolve each owned
-- equipment/bag/bank position through the server and bind replies to its epoch.
local frame, P = ArcanaItemUpgradesFrame, ArcanaAffixProtocol
local cache, pending, sequence, epoch = {}, {}, 0, 0
local supported = false
local tooltip, refresh, redrawing = GameTooltip, false, false
local function Link() local _, link = tooltip:GetItem(); return link end
local function NativeLink(view)
    if view.context == "E" then return GetInventoryItemLink("player", view.first) end
    return GetContainerItemLink(view.first, view.second)
end
local function Current(view)
    return view and tooltip.arcanaUpgradeView == view and tooltip:IsShown() and
        tooltip:GetOwner() == view.owner and Link() == view.link and NativeLink(view) == view.link
end
local function Request(row)
    if not supported or row.request or row.done or row.attempts >= 3 then return end
    sequence = sequence + 1
    row.request, row.expires, row.attempts = sequence, GetTime() + 5, row.attempts + 1
    pending[sequence] = row
    SendAddonMessage("AUI", table.concat({"CMD", "ITEM", sequence, row.context,
        row.first, row.second, row.entry}, "\t"), "WHISPER", UnitName("player"))
end
local function Query(context, first, second)
    local link = Link()
    local entry = P.Entry(link)
    local view = {context=context, first=first, second=second, link=link, owner=tooltip:GetOwner()}
    tooltip.arcanaUpgradeView = nil
    if not entry or NativeLink(view) ~= link then return end
    local key = table.concat({context, first, second}, ":")
    local row = cache[key]
    if not row or row.link ~= link then
        if row and row.request then pending[row.request] = nil end
        row = {context=context, first=first, second=second, link=link, entry=entry, epoch=epoch, attempts=0}
        cache[key] = row
    end
    view.row = row
    tooltip.arcanaUpgradeView = view
    if row.data and not tooltip.arcanaUpgradeRendered then
        tooltip.arcanaUpgradeRendered = true
        frame:RenderUpgradeTooltip(tooltip, row.data)
    end
    Request(row)
end
local function Rebuild(view)
    if redrawing or not Current(view) then return end
    redrawing = true
    if view.context == "E" then tooltip:SetInventoryItem("player", view.first)
    else tooltip:SetBagItem(view.first, view.second) end
    redrawing = false
end
local function Invalidate()
    cache, pending, epoch = {}, {}, epoch + 1
    refresh = true
end
local function Finish(id, data)
    local row = pending[id]
    if not row or row.epoch ~= epoch or GetTime() >= row.expires then return end
    row.data, row.done, row.building, row.request = data, true, nil, nil
    pending[id] = nil
    local view = tooltip.arcanaUpgradeView
    if view and view.row == row then Rebuild(view) end
end
local function Receive(message)
    local f = P.Split(message)
    if f[1] == "BEGIN" then
        supported = (tonumber(f[5]) or 0) >= 2
        return
    end
    if f[1] == "END" then Invalidate(); return end
    local id = tonumber(f[2]) or tonumber((f[2] or ""):match("^I(%d+)$"))
    local row = id and pending[id]
    if not row or row.epoch ~= epoch or GetTime() >= row.expires then return end
    if f[1] == "IBEGIN" then
        local guid, entry, rank, maximum, percent, armor = P.UInt(f[3]), P.UInt(f[4]),
            P.UInt(f[5]), P.UInt(f[6]), P.UInt(f[7]), P.UInt(f[8])
        if guid and guid > 0 and entry == row.entry and rank and maximum and maximum >= 1 and
            maximum <= 5 and rank <= maximum and percent and percent <= 100 and armor and armor <= 100 then
            row.building = {guid=guid, entry=entry, rank=rank, maxRank=maximum,
                percent=percent, armorPercent=armor, values={}}
        else row.building = nil end
    elseif f[1] == "IMISS" then Finish(id, nil)
    elseif f[1] == "IEND" then
        if row.building then Finish(id, row.building) end
    elseif f[2] == "I" .. id and row.building then
        local values = row.building.values
        if #values >= 32 then return end
        if (f[1] == "STAT" or f[1] == "VALUE") and tonumber(f[4]) and tonumber(f[5]) then
            values[#values + 1] = {label=f[1] == "STAT" and frame:UpgradeStatLabel(tonumber(f[3])) or
                frame:UpgradeValueLabel(f[3]), base=tonumber(f[4]), effective=tonumber(f[5])}
        elseif f[1] == "DAMAGE" and tonumber(f[4]) and tonumber(f[5]) and tonumber(f[6]) and tonumber(f[7]) then
            values[#values + 1] = {label=tonumber(f[3]) == 0 and "Weapon Damage" or
                ("Weapon Damage " .. tostring((tonumber(f[3]) or 0) + 1)), damage=true,
                baseMin=tonumber(f[4]), baseMax=tonumber(f[5]), effectiveMin=tonumber(f[6]), effectiveMax=tonumber(f[7])}
        end
    end
end

tooltip:HookScript("OnTooltipCleared", function(self)
    self.arcanaUpgradeView, self.arcanaUpgradeRendered = nil, nil
end)
tooltip:HookScript("OnHide", function(self) self.arcanaUpgradeView = nil end)
hooksecurefunc(tooltip, "SetBagItem", function(_, bag, slot) Query("B", bag, slot) end)
hooksecurefunc(tooltip, "SetInventoryItem", function(_, unit, slot)
    if UnitIsUnit(unit, "player") and slot >= 1 and slot <= 74 then Query("E", slot, 0) end
end)
local events = CreateFrame("Frame")
for _, event in ipairs({"CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE",
    "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BANKFRAME_CLOSED", "UNIT_INVENTORY_CHANGED",
    "PLAYER_LEVEL_UP"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == "AUI" and channel == "WHISPER" and sender == UnitName("player") then Receive(message) end
    elseif event ~= "UNIT_INVENTORY_CHANGED" or (...) == "player" then
        if event == "PLAYER_ENTERING_WORLD" then supported = false end
        Invalidate()
    end
end)
events:SetScript("OnUpdate", function()
    local view = tooltip.arcanaUpgradeView
    if refresh then refresh = false; Rebuild(view) end
    view = tooltip.arcanaUpgradeView
    if not Current(view) then return end
    local row = view.row
    if row.request and GetTime() >= row.expires then
        pending[row.request], row.request, row.building = nil, nil, nil
    end
    Request(row)
end)

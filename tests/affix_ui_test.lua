-- WoW 3.3.5 API model. Native Set* calls really clear/rebuild the tooltip;
-- HookScript chains handlers, and both font-string columns retain their state.
local frames, named, sent, now, popup = {}, {}, {}, 1, nil
local methods = {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsShown() return self.shown ~= false end
function methods:Show() self.shown = true end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:GetItem() return "Test", self.link end
function methods:GetName() return self.name end
function methods:NumLines() return self.count or 0 end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetTextColor(...) self.color = {...} end
function methods:GetTextColor() return unpack(self.color or {1,1,1}) end
function methods:CreateFontString() return CreateFrame("Font") end
function methods:AddLine(text, ...)
    self.count = self:NumLines() + 1
    local left = _G[self.name .. "TextLeft" .. self.count] or CreateFrame("Font")
    local right = _G[self.name .. "TextRight" .. self.count] or CreateFrame("Font")
    left.name, right.name = self.name .. "TextLeft" .. self.count, self.name .. "TextRight" .. self.count
    _G[self.name .. "TextLeft" .. self.count], _G[self.name .. "TextRight" .. self.count] = left, right
    left:SetText(text); left:SetTextColor(...); left:Show()
    right:SetText(nil); right:Hide()
end
function CreateFrame(kind, name)
    local frame=setmetatable({name=name, scripts={}}, {__index=function(_, key)
        return rawget(methods,key) or (string.match(key,"^[A-Z]") and function() end)
    end})
    frames[#frames+1]=frame; if name then named[name]=frame end; return frame
end
function hooksecurefunc(object, method, hook)
    local original=object[method]
    object[method]=function(...) local result=original(...); hook(...); return result end
end
ArcanaItemUpgradesFrame=CreateFrame("Frame")
local host=ArcanaItemUpgradesFrame
host.selected=10
function host:GetSelectedEquipmentSlot() return self.selected end
function host:SetAffixSlots(slots) self.slots=slots end
GameTooltip=CreateFrame("Tooltip", "GameTooltip")
local tooltip=GameTooltip
StaticPopupDialogs={}; ACCEPT="Accept"; CANCEL="Cancel"
DURABILITY_TEMPLATE="Durability %d / %d"; ITEM_MIN_LEVEL="Requires Level %d"
ITEM_SPELL_TRIGGER_ONEQUIP="Equip:"; ITEM_SET_NAME="%s (%d/%d)"
EMPTY_SOCKET_RED="Red Socket"; ITEM_SOCKET_BONUS="Socket Bonus: %s"
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function SendAddonMessage(prefix, message, channel, who) sent[#sent+1]=message end
function UnitName() return "Tester" end
function GetTime() return now end
local inside, dead, combat, tokens=false,false,false,1
function IsInInstance() return inside end
function UnitIsDeadOrGhost() return dead end
function UnitAffectingCombat() return combat end
function GetItemCount() return tokens end
function GetItemInfo(link)
    if not link then return nil end
    return "Test", link, 3, 24, 18, "Armor", "Cloth", 1, "INVTYPE_FEET"
end
function UnitIsUnit(a,b) return a==b end
function UnitGUID() return "0x0000000000000001" end
local ring="|Hitem:45809:0:0:0:0:0:0:0:80|h[Ring]|h"
local relic="|Hitem:40711:0:0:0:0:0:0:0:80|h[Relic]|h"
local boots="|Hitem:10411:1:0:0:0:0:0:0:24|h[Footpads of the Fang]|h"
local links={[11]=ring, [18]=relic, [8]=boots}
function GetInventoryItemLink(unit, slot) return links[slot] end
function StaticPopup_Show(kind, a,b,data) popup={kind=kind,data=data} end
local layout={"Footpads of the Fang", "Soulbound", "Feet", "62 Armor", "+6 Agility", "+6 Stamina",
    "+5 Stamina", "Durability 44 / 45", "Requires Level 18", "", "Embrace of the Viper (3/5)",
    "Set: Increases nature spell power by\n7.", "Arcana Upgrade: 0/5", "GearScore: 17", "Vendor"}
local function clear()
    for i=1,tooltip:NumLines() do
        _G["GameTooltipTextLeft"..i]:SetText(nil)
        _G["GameTooltipTextRight"..i]:SetText(nil)
    end
    tooltip.count=0
    if tooltip.scripts.OnTooltipCleared then tooltip.scripts.OnTooltipCleared(tooltip) end
end
local function rebuild(link)
    clear(); tooltip.link=link; tooltip:Show()
    for i,text in ipairs(layout) do
        tooltip:AddLine(text, i==7 and 0 or 1, 1, i==7 and 0 or 1)
    end
    if #layout==15 then
        GameTooltipTextRight3:SetText("Leather"); GameTooltipTextRight3:Show()
        GameTooltipTextRight15:SetText("9 silver 45 copper"); GameTooltipTextRight15:Show()
    end
    if tooltip.scripts.OnTooltipSetItem then tooltip.scripts.OnTooltipSetItem(tooltip) end
end
function tooltip:SetInventoryItem(unit, slot) rebuild(GetInventoryItemLink(unit,slot)) end
local bagLink=boots
function tooltip:SetBagItem(bag,slot) rebuild(bagLink) end
for _, method in ipairs({"SetTradePlayerItem","SetTradeTargetItem","SetBuybackItem","SetLootItem",
    "SetLootRollItem","SetInboxItem","SetAuctionItem"}) do
    tooltip[method]=function(self) rebuild(bagLink) end
end

dofile("AffixProtocol.lua")
dofile("ArcanaItemAffixes.lua")
local events=frames[#frames]
local function event(name,...) events.scripts.OnEvent(events,name,...) end
local function receive(text) event("CHAT_MSG_ADDON","AAF",text,"WHISPER","Tester") end
local function tick(delta) now=now+(delta or 0); events.scripts.OnUpdate(events) end
local checks=0
local function check(value,label) checks=checks+1; assert(value,label) end
local function pack(stat, amount, level) return 524288+level*4096+amount*64+stat end
local packed=pack(4,20,80)
local strength, stamina=pack(4,2,18), pack(7,4,18)
local function sync(bootBonus, revision)
    receive("SYNC"); receive("E\t10\t45809\t123\t"..packed.."\t1")
    receive("E\t17\t40711\t124\t"..packed.."\t1")
    receive("E\t7\t10411\t125\t"..(bootBonus or strength).."\t"..(revision or 1))
    receive("B\t0\t1\t10411\t201\t"..stamina.."\t1")
    receive("DONE")
end
local function latestRequest()
    return tonumber(string.match(sent[#sent],"^Q\t(%d+)"))
end
local function reply(id,entry,guid,bonus,revision)
    assert(id, "expected a tooltip request")
    receive(table.concat({"V",id,entry,guid,bonus,revision or 1},"\t"))
end
local function rendered(text)
    local found=0
    for i=1,tooltip:NumLines() do
        local line=_G["GameTooltipTextLeft"..i]:GetText() or ""
        if line:find("|cff00ff00"..text.."|r",1,true) then found=found+1 end
    end
    return found
end
sync()
local button=named.ArcanaItemRecalibrateButton
check(button.enabled,"eligible selected ring enables recalibration")
check(host.slots[17].entry==40711,"relic reaches complete equipment selector")
button.scripts.OnClick()
check(popup and popup.data.guid==123,"confirmation captures exact GUID")
host.selected=17
StaticPopupDialogs.ARCANA_AFFIX_CONFIRM.OnAccept({},popup.data)
check(sent[#sent]=="R\t10\t123\t1","selection change cannot redirect confirmed payment")
check(not button.enabled,"pending payment disables repeated clicks")
local paid=#sent
StaticPopupDialogs.ARCANA_AFFIX_CONFIRM.OnAccept({},popup.data)
check(#sent==paid,"duplicate confirmation sends no second request")
receive("RESULT\tDone"); sync()
check(button.enabled,"acknowledgement releases payment lock")
inside=true; host:UpdateDisplay(); check(not button.enabled,"instance blocks remote use")
inside=false; combat=true; host:UpdateDisplay(); check(not button.enabled,"combat blocks remote use")
combat=false; dead=true; host:UpdateDisplay(); check(not button.enabled,"dead blocks remote use")
dead=false; tokens=0; host:UpdateDisplay(); check(not button.enabled,"missing token blocks payment")
tokens=1

local before=#sent
tooltip:SetInventoryItem("player",8)
check(rendered("+2 Strength")==1,"synchronized equipment renders without a network round trip")
check(#sent==before,"equipment snapshot avoids redundant tooltip requests")
check(GameTooltipTextLeft7:GetText()=="|cff00ff00+2 Strength|r\n+5 Stamina","green bonus immediately precedes native enchant")
check(GameTooltipTextLeft8:GetText()=="Durability 44 / 45","durability remains below bonus")
check(GameTooltipTextRight3:GetText()=="Leather" and GameTooltipTextRight3:IsShown(),"native right-hand type preserved")
check(GameTooltipTextRight15:GetText()=="9 silver 45 copper" and GameTooltipTextRight15:IsShown(),"third-party right-hand price preserved")
check(GameTooltipTextLeft12:GetText()==layout[12],"wrapped set effect preserved")
check(tooltip:NumLines()==15,"native font strings are not reordered")
for i=1,30 do
    tooltip:SetInventoryItem("player",8)
    check(rendered("+2 Strength")==1,"bonus survives native rebuild "..i)
end
check(#sent==before,"thirty unchanged rebuilds send no additional requests")

-- Authoritative bag sync prevents the first-hover resize on existing items.
before=#sent
tooltip:SetBagItem(0,1)
check(rendered("+4 Stamina")==1,"synchronized bag bonus renders on first hover")
check(#sent==before,"synchronized bag bonus needs no hover round trip")
tooltip:SetBagItem(0,2)
check(rendered("+4 Stamina")==0,"synchronized empty bag slot has no borrowed bonus")
check(#sent==before,"complete bag sync also caches absence")
event("BAG_UPDATE",0)
check(rendered("+4 Stamina")==0,"bag mutation removes the synchronized value")

-- Unknown/new bag instances reserve stable space and resolve once, including
-- duplicate native item links.
tooltip:SetBagItem(0,1)
local id=latestRequest()
check(rendered("+2 Strength")==0,"bag copy does not inherit equipped copy's bonus")
check(GameTooltipTextLeft7:GetText()=="|c00000000 |r\n+5 Stamina",
    "new bag item reserves one stable bonus row")
before=#sent
for i=1,10 do
    tooltip:SetBagItem(0,1)
    check(GameTooltipTextLeft7:GetText()=="|c00000000 |r\n+5 Stamina",
        "in-flight bag rebuild retains reserved row "..i)
end
check(#sent==before,"in-flight bag request is deduplicated across clears")
reply(id,10411,201,stamina)
check(rendered("+4 Stamina")==1,"bag reply renders its own instance")
for i=1,30 do tooltip:SetBagItem(0,1); check(rendered("+4 Stamina")==1,"bag bonus survives rebuild "..i) end
check(#sent==before,"resolved bag does not poll on every rebuild")
reply(id,10411,201,stamina)
check(rendered("+4 Stamina")==1,"duplicate reply cannot duplicate the line")
tooltip:SetBagItem(0,2)
local second=latestRequest()
check(second~=id and rendered("+4 Stamina")==0,"another identical bag item requires its own reply")
reply(id,10411,201,stamina)
check(rendered("+4 Stamina")==0,"old slot reply cannot annotate an identical item")
reply(second,10411,202,strength)
check(rendered("+2 Strength")==1,"second copy gets distinct bonus")

-- Inventory mutation invalidates both cached data and outstanding replies.
event("BAG_UPDATE",0)
check(rendered("+2 Strength")==0,"bag mutation removes stale bonus immediately")
tooltip:SetBagItem(0,2); id=latestRequest()
event("BAG_UPDATE",0)
reply(id,10411,202,strength)
check(rendered("+2 Strength")==0,"pre-move reply rejected even with identical entry and link")
tooltip:SetBagItem(0,2); id=latestRequest(); reply(id,10411,203,stamina)
check(rendered("+4 Stamina")==1,"replacement in same slot resolves afresh")

-- Clear unrelated tooltip / hide / delayed replies must never restore old rows.
tooltip:SetBagItem(0,3); id=latestRequest(); rebuild(relic)
reply(id,10411,204,strength)
check(rendered("+2 Strength")==0,"unrelated tooltip cannot accept delayed response")
tooltip:SetBagItem(0,4); id=latestRequest(); tooltip:Hide()
reply(id,10411,205,strength)
check(not tooltip:IsShown() and rendered("+2 Strength")==0,"late response never resurrects a hidden tooltip")
tooltip:SetBagItem(0,5); id=latestRequest(); tick(6)
reply(id,10411,206,strength)
check(rendered("+2 Strength")==0,"expired reply is rejected")
local retry=latestRequest(); check(retry~=id,"expired request can retry without a mouse move")
reply(retry,10411,206,strength); check(rendered("+2 Strength")==1,"retry recovers display")

-- Reroll while already hovered refreshes from the new authoritative sync.
sync(); tooltip:SetInventoryItem("player",8)
receive("RESULT\tRecalibrated"); sync(stamina,2)
check(rendered("+4 Stamina")==1 and rendered("+2 Strength")==0,"reroll updates open tooltip and removes old stat")
check(GameTooltipTextLeft7:GetText()=="|cff00ff00+4 Stamina|r\n+5 Stamina","native enchant remains below rerolled bonus")
event("PLAYER_EQUIPMENT_CHANGED",8)
tooltip:SetInventoryItem("player",8); id=latestRequest()
check(rendered("+4 Stamina")==0,"identical replacement does not use stale equipment sync")
reply(id,10411,300,strength)
check(rendered("+2 Strength")==1,"equipment query resolves replacement")
sync(0,3)
check(rendered("+2 Strength")==0 and GameTooltipTextLeft7:GetText()=="+5 Stamina","no-bonus sync removes only custom text")

for _, case in ipairs({{"SetBuybackItem","MERCHANT_UPDATE"},{"SetTradeTargetItem","TRADE_TARGET_ITEM_CHANGED"},
    {"SetTradePlayerItem","TRADE_PLAYER_ITEM_CHANGED"},{"SetBagItem","PLAYERBANKSLOTS_CHANGED"}}) do
    tooltip[case[1]](tooltip,1,1); id=latestRequest(); reply(id,10411,401,strength)
    check(rendered("+2 Strength")==1,case[1].." renders")
    tooltip[case[1]](tooltip,1,1)
    check(rendered("+2 Strength")==1,case[1].." survives rebuild")
    event(case[2]); tooltip[case[1]](tooltip,1,1)
    check(rendered("+2 Strength")==0,case[2].." invalidates same-entry cache")
end

-- Foreign inventory is revalidated without recurring display flicker.
tooltip:SetInventoryItem("target",8); id=latestRequest(); reply(id,10411,500,strength)
now=now+2; tooltip:SetInventoryItem("target",8); id=latestRequest()
check(rendered("+2 Strength")==1,"inspection background refresh retains last verified bonus")
reply(id,10411,500,stamina,2)
check(rendered("+4 Stamina")==1 and rendered("+2 Strength")==0,"inspection refresh replaces bonus in place")

-- Snapshot contexts use the same native-style renderer.
receive("BEGIN\t0\t101"); receive("C\t101\t1\t10411\t601\t"..strength.."\t1"); receive("END\t101")
event("LOOT_OPENED"); tooltip:SetLootItem(1)
check(rendered("+2 Strength")==1,"loot snapshot uses green enchant placement")
tooltip:SetLootItem(1); check(rendered("+2 Strength")==1,"loot snapshot survives rebuild")
event("LOOT_SLOT_CLEARED",1); tooltip:SetLootItem(1)
check(rendered("+2 Strength")==0,"removed loot has no stale bonus")

-- LOOT_OPENED may beat the addon-message END event. Completion must publish
-- into the already-open window and refresh the currently hovered slot.
event("LOOT_CLOSED")
event("LOOT_OPENED"); tooltip:SetLootItem(1)
check(rendered("+4 Stamina")==0,"early loot hover waits for its snapshot")
check(GameTooltipTextLeft7:GetText()=="|c00000000 |r\n+5 Stamina",
    "early loot hover reserves stable bonus space")
receive("BEGIN\t0\t103"); receive("C\t103\t1\t10411\t902\t"..stamina.."\t1")
check(rendered("+4 Stamina")==0,"partial loot snapshot is never displayed")
receive("END\t103")
check(rendered("+4 Stamina")==1,"late loot snapshot refreshes the active hover")

-- Closing the corpse cancels both queued and in-flight context data.
event("LOOT_CLOSED")
event("LOOT_OPENED"); tooltip:SetLootItem(1)
receive("BEGIN\t0\t104"); receive("C\t104\t1\t10411\t903\t"..strength.."\t1")
event("LOOT_CLOSED"); receive("END\t104"); tooltip:SetLootItem(1)
check(rendered("+2 Strength")==0,"closed corpse rejects a late snapshot")

-- Slot identity remains authoritative for duplicate links and paged indices.
receive("BEGIN\t0\t105")
receive("C\t105\t1\t10411\t904\t"..strength.."\t1")
receive("C\t105\t17\t10411\t905\t"..stamina.."\t1")
receive("END\t105"); event("LOOT_OPENED"); tooltip:SetLootItem(17)
check(rendered("+4 Stamina")==1 and rendered("+2 Strength")==0,
    "paged duplicate loot item uses its own snapshot row")
event("LOOT_CLOSED")

-- No-durability items, gems, localized text, and trailing addon rows.
for _, tail in ipairs({"Requires Level 80", "Equip: Increases haste.", "Red Socket", "Socket Bonus: +4 Strength", "Test Set (1/5)"}) do
    layout={"Item", "Soulbound", "+5 Stamina", tail, "Arcana Upgrade: 0/5"}
    tooltip:SetBagItem(0,1); id=latestRequest(); reply(id,10411,700,strength)
    check(GameTooltipTextLeft3:GetText()=="+5 Stamina\n|cff00ff00+2 Strength|r","bonus precedes "..tail)
    check(GameTooltipTextLeft4:GetText()==tail,"following native row retained: "..tail)
    tooltip:Hide()
end
DURABILITY_TEMPLATE="Haltbarkeit %1$d / %2$d"
layout={"Item", "+5 Stamina", "Haltbarkeit 44 / 45", "Arcana Upgrade: 0/5"}
tooltip:SetBagItem(0,1); id=latestRequest(); reply(id,10411,701,strength)
check(GameTooltipTextLeft2:GetText()=="+5 Stamina\n|cff00ff00+2 Strength|r","localized positional format locates native footer")

-- Native socket textures retain their own anchor, with the bonus before them.
DURABILITY_TEMPLATE="Durability %d / %d"
layout={"Item", "+5 Stamina", "+20 Strength", "Durability 44 / 45"}
local socket={IsShown=function() return true end, GetObjectType=function() return "Texture" end, GetNumPoints=function() return 1 end,
    GetPoint=function() return "LEFT", GameTooltipTextLeft3, "LEFT", -20, 0 end}
function tooltip:GetRegions() return socket end
tooltip:Hide(); tooltip:SetBagItem(0,1); id=latestRequest(); reply(id,10411,702,strength)
check(GameTooltipTextLeft2:GetText()=="+5 Stamina\n|cff00ff00+2 Strength|r","bonus precedes filled socket")
check(GameTooltipTextLeft3:GetText()=="+20 Strength","gem text remains on its original socket row")
socket.IsShown=function() return false end
tooltip:Hide(); tooltip:SetBagItem(0,1); id=latestRequest(); reply(id,10411,702,strength)
check(GameTooltipTextLeft3:GetText()=="+20 Strength\n|cff00ff00+2 Strength|r","hidden texture from previous item does not move the bonus")
function tooltip:GetRegions() end

-- A rejected inspection reply must clear the old bonus, with bounded retries.
tooltip:SetInventoryItem("target",8); id=latestRequest(); reply(id,10411,800,strength)
now=now+2; tooltip:SetInventoryItem("target",8); id=latestRequest(); reply(id,0,0,0,0)
check(rendered("+2 Strength")==0,"unavailable inspection clears the previous bonus")
before=#sent
for i=1,10 do tooltip:SetInventoryItem("target",8) end
check(#sent==before,"rejected inspection backs off instead of flooding")
now=now+2; tooltip:SetInventoryItem("target",8); id=latestRequest(); reply(id,10411,801,stamina)
check(rendered("+4 Stamina")==1,"inspection resumes after unavailable reply")

-- Unrelated cache invalidation must not erase a currently displayed snapshot.
sync(); tooltip:SetInventoryItem("player",8)
receive("BEGIN\t0\t102"); receive("C\t102\t1\t10411\t901\t"..strength.."\t1"); receive("END\t102")
event("LOOT_OPENED"); tooltip:SetLootItem(1); event("PLAYER_EQUIPMENT_CHANGED",8)
check(rendered("+2 Strength")==1,"equipment invalidation leaves current loot snapshot intact")

print("PASS: "..checks.." affix UI checks (Lua 5.1)")

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
-- Native inspection calls SetOwner again on every hovered-slot update.
-- SetOwner hides the tooltip before SetInventoryItem repopulates it.
function methods:SetOwner(owner)
    self:Hide()
    self.owner=owner
end
function methods:GetItem() return "Test", self.link end
function methods:GetOwner() return self.owner end
function methods:GetName() return self.name end
function methods:NumLines() return self.count or 0 end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetTextColor(...) self.color = {...} end
function methods:GetTextColor() return unpack(self.color or {1,1,1}) end
function methods:CreateTexture() return CreateFrame("Texture") end
function methods:GetRegions() return end
function methods:GetFrameLevel() return 1 end
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
function methods:AddDoubleLine(left, right)
    self:AddLine(left)
    _G[self.name .. "TextRight" .. self:NumLines()]:SetText(right)
end
function CreateFrame(kind, name)
    local frame=setmetatable({name=name, scripts={}}, {__index=function(_, key)
        return rawget(methods,key) or (string.match(key,"^[A-Z]") and function() end)
    end})
    frames[#frames+1]=frame; if name then named[name]=frame; _G[name]=frame end; return frame
end
function hooksecurefunc(object, method, hook)
    local original=object[method]
    object[method]=function(...) local result=original(...); hook(...); return result end
end
GameTooltip=CreateFrame("Tooltip", "GameTooltip")
local tooltip=GameTooltip
StaticPopupDialogs={}; ACCEPT="Accept"; CANCEL="Cancel"
DURABILITY_TEMPLATE="Durability %d / %d"; ITEM_MIN_LEVEL="Requires Level %d"
ITEM_SPELL_TRIGGER_ONEQUIP="Equip:"; ITEM_SET_NAME="%s (%d/%d)"
EMPTY_SOCKET_RED="Red Socket"; ITEM_SOCKET_BONUS="Socket Bonus: %s"
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function SendAddonMessage(prefix, message, channel, who) sent[#sent+1]={prefix=prefix,message=message} end
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
local targetGuid="0x0000000000000001"
function UnitGUID(unit) return unit=="target" and targetGuid or "0x0000000000000001" end
local belt="|Hitem:6468:0:0:0:0:0:0:0:24|h[Deviate Scale Belt]|h"
local boots=belt
local links={[6]=belt}
function GetInventoryItemLink(unit, slot) return links[slot] end
function GetContainerItemLink(bag, slot) return belt end
UISpecialFrames={}; SlashCmdList={}; UIParent=CreateFrame("Frame")
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset() return 0 end
function GetInventoryItemTexture() return "Texture" end
function StaticPopup_Show(kind, a,b,data) popup={kind=kind,data=data} end
local layoutColors
local layout={"Deviate Scale Belt", "Soulbound", "Waist", "51 Armor", "+5 Agility", "+6 Stamina",
    "Durability 30 / 30", "Requires Level 18", "Equip: Improves hit rating by 3."}
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
        local color = layoutColors and layoutColors[i] or (i==7 and {0,1,0} or {1,1,1})
        tooltip:AddLine(text, unpack(color))
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
for _, method in ipairs({"SetTradePlayerItem","SetTradeTargetItem","SetBuybackItem",
    "SetLootRollItem","SetInboxItem"}) do
    tooltip[method]=function(self) rebuild(bagLink) end
end
local lootLink, lootOwner=boots,CreateFrame("Button","TestLootButton")
function tooltip:SetLootItem(slot) self.owner=lootOwner; rebuild(lootLink) end
local auction={link=boots,count=1,minimum=100,buyout=200,bid=0,owner="Seller"}
function GetAuctionItemLink(kind,index) return auction.link end
function GetAuctionItemInfo(kind,index)
    return "Footpads of the Fang", "Texture", auction.count, 3, true, 18,
        auction.minimum, 5, auction.buyout, auction.bid, false, auction.owner, 0
end
function tooltip:SetAuctionItem(kind,index) rebuild(GetAuctionItemLink(kind,index)) end

dofile("ArcanaItemUpgrades.lua")
dofile("AffixProtocol.lua")
dofile("ArcanaItemAffixes.lua")
local affixEvents=frames[#frames]
dofile("UpgradeTooltips.lua")
local upgradeEvents=frames[#frames]
local checks=0
local function check(ok,label) checks=checks+1; assert(ok,label) end
local function event(name,...)
    upgradeEvents.scripts.OnEvent(upgradeEvents,name,...)
end
local function receive(text,sender,channel)
    event("CHAT_MSG_ADDON","AUI",text,channel or "WHISPER",sender or "Tester")
end
local function tick(delta)
    now=now+(delta or 0)
    upgradeEvents.scripts.OnUpdate(upgradeEvents)
end
local function latest()
    for i=#sent,1,-1 do
        if sent[i].prefix=="AUI" then
            return tonumber(sent[i].message:match("^CMD\tITEM\t(%d+)")),sent[i].message
        end
    end
end
local function countRequests()
    local n=0
    for _,v in ipairs(sent) do if v.prefix=="AUI" then n=n+1 end end
    return n
end
local function reply(id,guid,rank)
    receive(table.concat({"IBEGIN",id,guid,6468,rank,5,5,2},"\t"))
    if rank>0 then
        receive("STAT\tI"..id.."\t3\t5\t6")
        receive("VALUE\tI"..id.."\tARMOR\t51\t54")
    end
    receive("IEND\t"..id)
end
local function has(text)
    for i=1,tooltip:NumLines() do
        if ( _G["GameTooltipTextLeft"..i]:GetText() or ""):find(text,1,true) then return true end
    end
    return false
end
local function rank(value)
    local found=0
    for i=1,tooltip:NumLines() do
        if (_G["GameTooltipTextLeft"..i]:GetText() or ""):find("Arcana Upgrade:",1,true) then found=found+1 end
    end
    return found==(value and 1 or 0) and (not value or has("Arcana Upgrade: "..value.."/5"))
end
local owner=CreateFrame("Button","BeltOwner")
tooltip:SetOwner(owner); tooltip:SetBagItem(0,1)
check(countRequests()==0,"no unsupported requests before server capability")
receive("BEGIN\t5\t5\t2")
tick(6); check(countRequests()==0,"legacy server receives no unsupported requests")
receive("BEGIN\t5\t5\t2\t2"); receive("END"); tooltip:Hide(); tick()
tooltip:SetOwner(owner)
tooltip:SetInventoryItem("player",6)
local equipped=latest()
check(rank(nil),"cold equipment does not assume zero")
reply(equipped,101,3)
check(rank(3) and has("Stat bonus: +15%") and has("Armor bonus: +6%"),"equipped exact rank and percentages")
check(has("Agility:") and has("Armor:"),"effective values retained")
tooltip:SetBagItem(0,1)
local bag=latest()
check(bag~=equipped and rank(nil),"same-link bag item never borrows equipment rank")
reply(bag,102,0)
check(rank(0) and not has("Effective item values:"),"bag zero is authoritative")
tooltip:SetInventoryItem("player",6)
check(rank(3),"same-link equipment retains separate cache")
local before=countRequests()
for i=1,10 do tooltip:SetOwner(owner); tooltip:SetInventoryItem("player",6) end
check(rank(3) and countRequests()==before,"native SetOwner/rebuild uses one resolved instance")
event("PLAYER_EQUIPMENT_CHANGED",6); tick()
equipped=latest(); reply(equipped,102,0)
tooltip:SetBagItem(0,1);bag=latest();reply(bag,101,3)
check(rank(3),"after swap bagged upgraded belt retains 3/5")
tooltip:SetInventoryItem("player",6)
check(rank(0),"after swap equipped unupgraded belt retains 0/5")
-- Delayed response for a same-entry replacement is discarded after invalidation.
event("BAG_UPDATE",0);tooltip:SetBagItem(0,1);local old=latest()
event("BAG_UPDATE",0);tick();local replacement=latest()
reply(old,101,3)
check(rank(nil),"pre-move reply cannot annotate same-link replacement")
reply(replacement,103,1)
check(rank(1),"replacement uses own reply")
-- A reply may warm its location but cannot draw on another identical hover.
tooltip:SetBagItem(0,2);local first=latest()
tooltip:SetBagItem(0,3);local second=latest()
reply(first,104,4);check(rank(nil),"other slot reply cannot annotate hover")
reply(second,105,2);check(rank(2),"second slot resolved independently")
tooltip:SetBagItem(0,2);check(rank(4),"hidden slot cached independently")
-- Nothing equipped is required for bag/bank rank.
links[6]=nil;event("PLAYER_EQUIPMENT_CHANGED",6)
tooltip:SetBagItem(-1,1);local bank,message=latest()
check(message:find("\tB\t-1\t1\t6468",1,true),"bank uses native bank position")
reply(bank,101,3);check(rank(3),"banked upgrade visible with empty equipment")
links[40]=belt; tooltip:SetInventoryItem("player",40)
reply(latest(),101,3);check(rank(3),"native bank inventory tooltip resolves correctly")
-- Closed and unrelated tooltips are never reopened by late packets.
tooltip:SetBagItem(0,4);local hidden=latest();tooltip:Hide();reply(hidden,106,3)
check(not tooltip:IsShown(),"reply cannot reopen closed tooltip")
tooltip:SetBagItem(0,5);local other=latest();rebuild(belt);reply(other,107,3)
check(rank(nil),"unbound same-link tooltip cannot borrow rank")
tooltip:SetInventoryItem("target",6);check(rank(nil),"inspection cannot borrow player rank")
-- Sender, framing and immutable entry checks.
tooltip:SetBagItem(0,6);local untrusted=latest()
receive("IBEGIN\t"..untrusted.."\t108\t6468\t5\t5\t5\t2","Stranger")
receive("IEND\t"..untrusted);check(rank(nil),"untrusted sender ignored")
receive("IBEGIN\t"..untrusted.."\t108\t9999\t5\t5\t5\t2")
receive("IEND\t"..untrusted);check(rank(nil),"wrong entry ignored")
reply(untrusted,108,5);check(rank(5),"valid framed replacement accepted")
tooltip:SetBagItem(0,7);local partial=latest()
receive("IBEGIN\t"..partial.."\t109\t6468\t3\t5\t5\t2")
check(rank(nil),"partial snapshot never displayed")
receive("IEND\t"..partial);check(rank(3),"completed snapshot displayed once")
reply(partial,109,3);check(rank(3),"duplicate replies cannot duplicate lines")
-- Missing/ineligible is not zero; timeouts are bounded.
tooltip:SetBagItem(0,8);local missing=latest();receive("IMISS\t"..missing)
before=countRequests();for i=1,5 do tick(6) end
check(rank(nil) and countRequests()==before,"missing response remains unknown without retry loop")
tooltip:SetBagItem(0,9);local expired=latest();before=countRequests()
tick(6);reply(expired,111,5);check(rank(nil),"expired reply ignored")
for i=1,6 do tick(6) end
check(countRequests()==before+2,"timeouts stop after three attempts")
-- Upgrade sync and level changes refresh even a stationary hover.
receive("END");tick();local upgraded=latest();reply(upgraded,111,4)
check(rank(4),"completed upgrade sync invalidates hover cache")
event("PLAYER_LEVEL_UP",25);tick();check(rank(nil),"level change clears effective values")
-- Run both tooltip systems together for the exact reported belt pair.
links[6]=belt;event("PLAYER_EQUIPMENT_CHANGED",6)
local function affix(text) affixEvents.scripts.OnEvent(affixEvents,"CHAT_MSG_ADDON","AAF",text,"WHISPER","Tester") end
local arp=2*524288+18*4096+2*64+44
local haste=2*524288+18*4096+2*64+36
affix("SYNC");affix("E\t5\t6468\t101\t"..arp.."\t1")
affix("B\t0\t1\t6468\t102\t"..haste.."\t1");affix("DONE")
tooltip:SetInventoryItem("player",6);reply(latest(),101,3)
check(rank(3) and has("+2 Armor Penetration Rating"),"equipped ArP and upgrade coexist")
tooltip:SetBagItem(0,1);reply(latest(),102,0)
check(rank(0) and has("+2 Haste Rating") and not has("+2 Armor Penetration Rating"),"bag haste and zero rank coexist")
print("PASS: "..checks.." upgrade tooltip integration checks (Lua 5.1)")

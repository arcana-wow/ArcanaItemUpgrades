local frames,named,sent,hooks={},{},{},{}
local now,level,dead,combat,inside,casting,channeling=1,80,false,false,false,false,false
local cursor,popup
local methods={}
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:HookScript(event,fn)
    local old=self.scripts[event];self.scripts[event]=function(...) if old then old(...) end;fn(...) end
end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown~=false end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetText(text) self.text=text end
function methods:CreateFontString() return CreateFrame("Font",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function CreateFrame(kind,name,parent)
    local frame=setmetatable({scripts={},name=name,parent=parent,kind=kind},{__index=function(_,key)
        return methods[key] or (key:match("^[A-Z]") and function() end)
    end})
    frames[#frames+1]=frame;if name then named[name]=frame end;return frame
end
ArcanaItemUpgradesFrame=CreateFrame("Frame")
local host=ArcanaItemUpgradesFrame;host.serviceTab="Recycle";host.ServiceStatus=CreateFrame("Font")
GameTooltip=CreateFrame("Tooltip")
StaticPopupDialogs={};CANCEL="Cancel"
function StaticPopup_Hide() popup=nil end
function StaticPopup_Show(kind,a,b,data) popup={kind=kind,data=data,text=string.format(StaticPopupDialogs[kind].text,a,b)} end
function SendAddonMessage(prefix,message,channel,target) assert(prefix=="ARCY" and channel=="WHISPER" and target=="Tester");sent[#sent+1]=message end
function UnitName() return "Tester" end
function UnitLevel() return level end
function UnitIsDeadOrGhost() return dead end
function UnitAffectingCombat() return combat end
function IsInInstance() return inside end
function UnitCastingInfo() return casting end
function UnitChannelInfo() return channeling end
function GetTime() return now end
function GetItemInfo(entry) return "Item "..entry,"item:"..entry end
function GetItemIcon() return "icon" end
function GetContainerItemLink() return "item:123" end
function GetCursorInfo() if cursor then return "item",cursor end end
function hooksecurefunc(name,fn) hooks[name]=fn end
function ClearCursor() cursor=nil;if hooks.ClearCursor then hooks.ClearCursor() end end
function PickupContainerItem(bag,slot) cursor=123;hooks.PickupContainerItem(bag,slot) end
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset(scroll) return scroll.offset or 0 end
function FauxScrollFrame_OnVerticalScroll(scroll,offset,height,fn) scroll.offset=math.floor(offset/height);fn() end
dofile("RecyclingProtocol.lua");dofile("RecyclingUI.lua")
local P=ArcanaRecyclingProtocol
local events=named.ArcanaRecyclingEvents
local button=named.ArcanaRecycleButton
local checks=0
local function check(value) checks=checks+1;assert(value,"check "..checks) end
local function event(name,...) events.scripts.OnEvent(events,name,...) end
local function tick(seconds) now=now+(seconds or 1);events.scripts.OnUpdate(events) end
local function request() return P.Split(sent[#sent]) end
local function receive(text,sender) event("CHAT_MSG_ADDON","ARCY",text,"WHISPER",sender or "Tester") end
local function snapshot(count)
    local r=request();check(r[1]=="SYNC")
    receive("BEGIN\t"..r[2].."\t2\t1\t")
    for i=1,count or 11 do receive("ITEM\t"..r[2].."\t"..i.."\t0\t"..i.."\t123\t187\t101\t0") end
    receive("END\t"..r[2])
end
local function pickerRows()
    local result={}
    for _,frame in ipairs(frames) do
        if frame.parent==named.ArcanaRecyclingPicker and frame.kind=="Button" and frame.row then result[#result+1]=frame end
    end
    return result
end
local function click(index,mouse) local f=named["ArcanaRecycleSlot"..index];f.scripts.OnClick(f,mouse or "LeftButton") end
local function choose(index,guid)
    click(index);check(named.ArcanaRecyclingPicker:IsShown())
    local found
    for _,row in ipairs(pickerRows()) do if row.row.guid==guid then row.scripts.OnClick(row);found=true;break end end
    check(found and not named.ArcanaRecyclingPicker:IsShown())
end
local id="0123456789abcdef0123456789abcdef"
local function quote(requestId)
    local r=request();check(r[1]=="QUOTE2")
    receive("QUOTE\t"..(requestId or r[2]).."\t"..id.."\t30\t1010\t505\t505\t1870\t0.2\t0.2\t0.2\t0.2\t0.2\t0")
    check(not button.enabled)
    for category=0,1 do for part=0,1 do
        receive("GEAR\t"..(requestId or r[2]).."\t"..id.."\t"..category.."\t"..part.."\t"..(part==0 and "1.0" or "0.0").."\t0.0\t0.0\t0.0\t0.0\t0.0")
        check(not button.enabled)
    end end
    receive("QEND\t"..(requestId or r[2]).."\t"..id)
end
host:RecyclingTabChanged("Recycle");snapshot()
check(not button.enabled)
-- Picker preserves instance identity for duplicate entries and omits selected ones.
choose(1,1);click(2)
for _,row in ipairs(pickerRows()) do check(row.row.guid~=1) end
named.ArcanaRecyclingPicker:Hide()
-- Drag captures the exact bag slot; a link without a captured origin is rejected.
cursor=123;click(2);check(cursor==123)
PickupContainerItem(0,2);named.ArcanaRecycleSlot2.scripts.OnReceiveDrag();check(not cursor)
PickupContainerItem(0,3);named.ArcanaRecycleSlot2.scripts.OnReceiveDrag();check(cursor==123)
named.ArcanaRecycleSlot3.scripts.OnReceiveDrag();check(not cursor)
for i=4,10 do choose(i,i) end
tick();local old=request()[2]
quote(tostring(tonumber(old)+1));check(not button.enabled) -- Out-of-order reply.
receive("QUOTE\t"..old.."\t"..id.."\t30\t1010\t505\t505\t1870\t0.2\t0.2\t0.2\t0.2\t0.2\t0","Spoofer")
check(not button.enabled)
quote();check(button.enabled)
button.scripts.OnClick();check(popup and popup.text:find("0g 10s 10c",1,true) and popup.text:find("0g 5s 5c",1,true))
-- A replacement with identical entry/value invalidates both popup and old request.
click(10,"RightButton");check(not popup and not button.enabled);choose(10,11);tick()
old=request()[2];click(10,"RightButton");choose(10,10)
quote(old);check(not button.enabled);tick();quote();check(button.enabled)
button.scripts.OnClick();local data=popup.data
StaticPopupDialogs.ARCANA_RECYCLE_CONFIRM.OnAccept({},data)
check(request()[1]=="COMMIT" and ArcanaItemUpgradesDB.recyclingPending==id and not button.enabled)
local count=#sent;StaticPopupDialogs.ARCANA_RECYCLE_CONFIRM.OnAccept({},data);check(#sent==count)
event("BAG_UPDATE");tick(6);tick(2);check(request()[1]=="STATUS")
local r=request();receive("RESULT\t"..r[2].."\t"..id.."\t1000\t0")
check(not ArcanaItemUpgradesDB.recyclingPending);tick(2);snapshot()
-- Reload recovery queries the durable receipt, never automatically commits again.
ArcanaItemUpgradesDB.recyclingPending=id;event("PLAYER_ENTERING_WORLD");tick(2)
check(request()[1]=="STATUS");r=request();receive("MISSING\t"..r[2].."\t"..id)
check(not ArcanaItemUpgradesDB.recyclingPending);tick();snapshot()
for _,restriction in ipairs({"level","dead","combat","inside","casting","channeling"}) do
    level=restriction=="level" and 79 or 80;dead=restriction=="dead";combat=restriction=="combat";inside=restriction=="inside"
    casting=restriction=="casting";channeling=restriction=="channeling"
    click(1);check(not named.ArcanaRecyclingPicker:IsShown() and not button.enabled)
end
level=80;dead=false;combat=false;inside=false;casting=false;channeling=false
choose(1,1);event("BAG_UPDATE");check(not button.enabled);PickupContainerItem(0,2);click(2);check(cursor==123);ClearCursor()
tick();snapshot()
-- Incomplete, malformed and duplicate snapshots cannot re-enable consumption.
tick();host:RefreshRecycling();r=request();receive("BEGIN\t"..r[2].."\t2\t1\t")
receive("ITEM\t"..r[2].."\t1\t0\t1\t123\t187\t101\t0")
receive("ITEM\t"..r[2].."\t1\t0\t2\t123\t187\t101\t0")
receive("END\t"..r[2]);click(2);check(not named.ArcanaRecyclingPicker:IsShown())
tick();host:RefreshRecycling();tick(6);check(not button.enabled)
host.serviceTab="Tempering";host:RecyclingTabChanged("Tempering");check(not named.ArcanaRecyclingPanel:IsShown())
host.serviceTab="Recycle";tick();host:RecyclingTabChanged("Recycle");snapshot()
for i=1,10 do if i==1 then click(1,"RightButton") end;choose(i,i) end
tick();quote();button.scripts.OnClick();check(popup~=nil)
tick(31);check(not button.enabled and not popup)
print("PASS: "..checks.." recycling drag/picker, duplicate identity, stale quotes, retry/reload and restriction checks")

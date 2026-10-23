local frames,sent,menus,created={},{},{},{}
local bagItems
local now,combat,dead,level=1,false,false,30
local money,materials,bagLink=100000000,100,"item:16905:123:456"
local methods={}
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:HookScript(event,fn)
    local old=self.scripts[event]
    self.scripts[event]=function(...) if old then old(...) end;fn(...) end
end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown~=false end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetText(text)
    self.text=tostring(text)
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetStringWidth() return #(self.text or "")*6 end
function methods:GetText() return self.text or "" end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function methods:SetHeight(value) self.height=value;self.resizes=(self.resizes or 0)+1 end
function methods:SetPoint(...) self.point={...} end
function methods:SetTexture(value) self.texture=value end
function methods:SetTextColor(...) self.color={...} end
function methods:SetBagItem(bag,slot) self.bag,self.slot=bag,slot end
function methods:SetHyperlink(link) self.link=link end
function methods:LockHighlight() self.highlight=true end
function methods:UnlockHighlight() self.highlight=false end
function methods:CreateFontString() return CreateFrame("Font",nil,self) end
function CreateFrame(kind,name,parent,template)
    local frame=setmetatable({kind=kind,name=name,parent=parent,template=template,scripts={}},{__index=function(_,key)
        return methods[key] or (key:match("^[A-Z]") and function() end)
    end})
    created[#created+1]=frame
    if name then frames[name]=frame;_G[name]=frame end
    return frame
end
UIParent=CreateFrame("Frame")
ArcanaItemUpgradesFrame=CreateFrame("Frame")
ArcanaItemUpgradesFrame.serviceTab="Heirloom"
ArcanaItemUpgradesDB={}
GameTooltip=CreateFrame("Tooltip")
CANCEL="Cancel"
function UIDropDownMenu_Initialize(frame,fn) frame.initialize=fn end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText(frame,text) frame.text=text end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info)
    menus[#menus+1]=info
    DropDownList1=DropDownList1 or CreateFrame("Frame","DropDownList1")
    DropDownList1.numButtons=#menus
    local name="DropDownList1Button"..#menus
    _G[name]=_G[name] or CreateFrame("Button",name,DropDownList1)
end
function FauxScrollFrame_Update() end
function FauxScrollFrame_SetOffset(frame,offset) frame.offset=offset end
function CloseDropDownMenus() end
function FauxScrollFrame_GetOffset(frame) return frame.offset or 0 end
function FauxScrollFrame_OnVerticalScroll(frame,offset,height,render) frame.offset=math.floor(offset/height);render() end
function IsInInstance() return false,"none" end
function UnitIsDeadOrGhost() return dead end
function UnitAffectingCombat() return combat end
function UnitCastingInfo() end
function UnitChannelInfo() end
function UnitLevel() return level end
function UnitName() return "Tester" end
function GetRealmName() return "Test" end
function GetTime() return now end
function GetItemInfo(entry) return "Item "..entry,"|cffffffff|Hitem:"..entry..":0:0:0:0:0:0:0|h[Item "..entry.."]|h|r" end
function GetContainerItemLink(bag,slot)
    if bagItems then return bagItems[bag] and bagItems[bag][slot] end
    return bagLink
end
function GetMoney() return money end
function GetItemCount(_,bank) assert(bank==false);return materials end
function SendAddonMessage(prefix,message,channel,target)
    assert(prefix=="ARHL" and channel=="WHISPER" and target=="Tester")
    sent[#sent+1]=message
end
ArcanaHeirloomCatalogue={
    [700001]={name="Bloodfang Chestpiece",source=16905,class=4,subclass=2,slot=5,tier="Tier 2",origin="Blackwing Lair: Nefarian",icon="INV_Chest_Leather_01"},
    [700002]={name="Thunderfury",source=19019,class=2,subclass=7,slot=21,tier="",origin="Molten Core: Bindings",icon="INV_Sword_39"},
}
dofile("HeirloomProtocol.lua");dofile("HeirloomUI.lua")
local P=ArcanaHeirloomProtocol
local host=ArcanaItemUpgradesFrame
local events=frames.ArcanaHeirloomEvents
local forge=frames.ArcanaHeirloomForge
local confirmation=frames.ArcanaHeirloomConfirmation
local checks=0
local function check(value) checks=checks+1;assert(value,"check "..checks) end
local function click(name) local frame=frames[name];frame.scripts.OnClick(frame) end
local function event(name,...) events.scripts.OnEvent(events,name,...) end
local function tick(seconds) now=now+(seconds or 1);events.scripts.OnUpdate(events) end
local function request() return P.Split(sent[#sent]) end
local function receive(message,sender) event("CHAT_MSG_ADDON","ARHL",message,"WHISPER",sender or "Tester") end
local function snapshot(progress)
    local req=request();check(req[1]=="SYNC")
    receive("BEGIN\t"..req[2].."\t1\t1")
    receive("ROW\t"..req[2].."\t700001\t"..(progress or 0).."\t0")
    receive("ORIGINAL\t"..req[2].."\t700001\t42\t0\t1\t16905")
    receive("END\t"..req[2])
end
local id=string.rep("a",32)
local function quote()
    click("ArcanaHeirloomForge")
    local req=request();check(req[1]=="QUOTE")
    receive("QUOTE\t"..req[2].."\t"..id.."\t1\t700001\t0\t6\t10\t2\t0\t0\t30")
    check(confirmation:IsShown())
end
host:HeirloomTabChanged("Heirloom");snapshot();click("ArcanaHeirloomRow1")
check(forge.enabled)
frames.ArcanaHeirloomQuantity:SetText("0");check(not forge.enabled)
frames.ArcanaHeirloomQuantity:SetText("101");check(not forge.enabled)
frames.ArcanaHeirloomQuantity:SetText("2");check(forge.enabled)
quote();check(frames.ArcanaHeirloomPaymentLink.label.text:find("UI-GoldIcon",1,true))
check(frames.ArcanaHeirloomPaymentLink.label.text:find("Are you sure you want to spend 200",1,true))
local count=#sent
click("ArcanaHeirloomConfirmCancel");check(not confirmation:IsShown() and #sent==count)
quote();host:HeirloomTabChanged("Tempering");check(not confirmation:IsShown())
host.serviceTab="Heirloom";tick();host:HeirloomTabChanged("Heirloom");snapshot()
quote();tick(31);check(not confirmation:IsShown())
quote();combat=true;event("PLAYER_REGEN_DISABLED");check(not confirmation:IsShown() and not forge.enabled)
combat=false;tick();snapshot();check(forge.enabled)
quote();click("ArcanaHeirloomConfirmAccept")
check(request()[1]=="COMMIT" and ArcanaItemUpgradesDB.heirloomPending["Test:Tester"]==id)
check(not forge.enabled and not confirmation:IsShown())
event("BAG_UPDATE");check(request()[1]=="COMMIT")
tick(13);tick(2);check(request()[1]=="STATUS")
local req=request()
receive("ERROR\t"..req[2].."\tYour transaction history could not be read.")
check(ArcanaItemUpgradesDB.heirloomPending["Test:Tester"]==id and not forge.enabled)
tick(6);req=request();check(req[1]=="STATUS")
receive("DONE\t"..req[2].."\t1\t700001\t6\t2\t0","Spoofed")
check(ArcanaItemUpgradesDB.heirloomPending["Test:Tester"]==id)
receive("DONE\t"..req[2].."\t1\t700001\t6\t2\t0")
check(not ArcanaItemUpgradesDB.heirloomPending["Test:Tester"])
check(ArcanaHeirloomGain.text=="+6%")
receive("DONE\t"..req[2].."\t1\t700001\t6\t2\t0")
check(ArcanaHeirloomGain.text=="+6%")
tick(4.1);check(ArcanaHeirloomGain.text=="")
snapshot(100);click("ArcanaHeirloomCompleted");click("ArcanaHeirloomRow1")
check(forge.text=="Conjure" and forge.enabled)
click("ArcanaHeirloomForge");req=request();check(req[1]=="CONJURE")
receive("QUOTE\t"..req[2].."\t"..id.."\t2\t700001\t100\t0\t0\t1\t0\t0\t30")
check(not confirmation:IsShown() and request()[1]=="COMMIT")
local autoCommitCount=#sent
click("ArcanaHeirloomForge");check(#sent==autoCommitCount)
req=request()
receive("ERROR\t"..req[2].."\tMake room in your bags before conjuring.")
check(ArcanaItemUpgradesDB.heirloomPending["Test:Tester"]==id)
tick(2);req=request();check(req[1]=="STATUS")
receive("MISSING\t"..req[2]);check(not ArcanaItemUpgradesDB.heirloomPending["Test:Tester"])
tick();snapshot(0);click("ArcanaHeirloomUnlocked");click("ArcanaHeirloomRow1")
menus={};frames.ArcanaHeirloomMaterial.initialize();menus[6].func()
check(frames.ArcanaHeirloomQuantity:GetText()=="1" and not forge.enabled)
menus={};frames.ArcanaHeirloomOriginal.initialize();check(#menus==1);menus[1].func()
check(forge.enabled);click("ArcanaHeirloomForge");req=request()
check(req[4]=="5" and req[5]=="1" and req[6]=="42")
receive("QUOTE\t"..req[2].."\t"..id.."\t1\t700001\t0\t20\t20\t1\t5\t42\t30")
check(confirmation:IsShown())
check(frames.ArcanaHeirloomPaymentLink.label.text:find("want to destroy 1 × item:16905",1,true))
event("BAG_UPDATE");check(not confirmation:IsShown() and not forge.enabled)
tick();snapshot()
click("ArcanaHeirloomAll");frames.ArcanaHeirloomSearch:SetText("thunder");tick(0.3);check(frames.ArcanaHeirloomRow1.entry==700002)
click("ArcanaHeirloomRow1");check(not forge.enabled)
dead=true;event("PLAYER_REGEN_ENABLED");check(not forge.enabled)
check(not frames.ArcanaHeirloomOrigin and not frames.ArcanaHeirloomType and not frames.ArcanaHeirloomSlot)
check(frames.ArcanaHeirloomRow1.template==nil and frames.ArcanaHeirloomRow1.icon.texture~=nil)
check(frames.ArcanaHeirloomRow1.name.text:find("Thunderfury",1,true))
check(frames.ArcanaHeirloomRow1.progress.text=="Preview")
menus={};frames.ArcanaHeirloomFilter.initialize(nil,1);check(#menus==4)
UIDROPDOWNMENU_MENU_VALUE=1
menus={};frames.ArcanaHeirloomFilter.initialize(nil,2);check(#menus==13)
menus[3].func();check(frames.ArcanaHeirloomRow1.entry==nil)
frames.ArcanaHeirloomSearch:SetText("");tick(0.3);check(frames.ArcanaHeirloomRow1.entry==700001)
check(frames.ArcanaHeirloomClearFilter.enabled)
menus={};frames.ArcanaHeirloomFilter.initialize(nil,2);menus[8].func()
check(frames.ArcanaHeirloomFilter.text=="Filter: Leather / Chest" and frames.ArcanaHeirloomRow1.entry==700001)
menus={};frames.ArcanaHeirloomFilter.initialize(nil,2);menus[2].func()
check(frames.ArcanaHeirloomFilter.text=="Filter: Cloth / Chest" and frames.ArcanaHeirloomRow1.entry==nil)
frames.ArcanaHeirloomScroll.offset=99;click("ArcanaHeirloomClearFilter")
check(frames.ArcanaHeirloomScroll.offset==0 and not frames.ArcanaHeirloomClearFilter.enabled)
-- Search is debounced, local, literal and scoped to the selected collection.
click("ArcanaHeirloomUnlocked");dead=false
tick(1);snapshot()
menus={};frames.ArcanaHeirloomMaterial.initialize();menus[1].func()
frames.ArcanaHeirloomSearch:SetText("");tick(0.3)
click("ArcanaHeirloomRow1");check(forge.enabled)
local requestsBefore=#sent
frames.ArcanaHeirloomSearch:SetText("t")
frames.ArcanaHeirloomSearch:SetText("thunder")
check(not forge.enabled and frames.ArcanaHeirloomRow1.entry==700001)
tick(0.2);check(frames.ArcanaHeirloomRow1.entry==700001)
tick(0.1);check(frames.ArcanaHeirloomRow1.entry==nil and not forge:IsShown())
check(#sent==requestsBefore)
check(frames.ArcanaHeirloomUnlocked.marker:IsShown())
check(not frames.ArcanaHeirloomCompleted.marker:IsShown() and not frames.ArcanaHeirloomAll.marker:IsShown())
click("ArcanaHeirloomAll");check(frames.ArcanaHeirloomRow1.entry==700002)
check(frames.ArcanaHeirloomRow1.icon.texture=="Interface\\Icons\\INV_Sword_39")
check(frames.ArcanaHeirloomAll.marker:IsShown() and not frames.ArcanaHeirloomUnlocked.marker:IsShown())
check(frames.ArcanaHeirloomSearch.point[3]<frames.ArcanaHeirloomFilter.point[3])
check(host.height==685)
local fixedHeight=host.height
for _,name in ipairs({"Unlocked","Completed","All"}) do
    click("ArcanaHeirloom"..name);check(host.height==fixedHeight)
end
check(ArcanaHeirloomGain.point[2].kind=="Font")
check(ArcanaHeirloomGain.point[3]=="RIGHT" and ArcanaHeirloomGain.point[4]==8)
-- Payment is checked before quoting and again at confirmation; money updates
-- never trigger a database refresh. Bag changes invalidate exact-copy identity.
frames.ArcanaHeirloomSearch:SetText("");tick(0.3)
click("ArcanaHeirloomUnlocked");click("ArcanaHeirloomRow1")
frames.ArcanaHeirloomQuantity:SetText("2")
local beforeMoney=#sent
money=1999999;event("PLAYER_MONEY")
check(not forge.enabled and ArcanaHeirloomStatus.text=="You do not have the required item/currency.")
check(ArcanaHeirloomStatus.color[1]==1 and ArcanaHeirloomStatus.color[2]<0.2)
click("ArcanaHeirloomForge");check(#sent==beforeMoney)
money=2000000;event("PLAYER_MONEY");check(forge.enabled and #sent==beforeMoney)
quote();money=0;click("ArcanaHeirloomConfirmAccept")
check(not confirmation:IsShown() and request()[1]=="QUOTE" and not forge.enabled)
money=100000000;event("PLAYER_MONEY")
menus={};frames.ArcanaHeirloomMaterial.initialize();menus[2].func()
materials=1;event("BAG_UPDATE");tick();snapshot();check(not forge.enabled)
materials=2;event("BAG_UPDATE");tick();snapshot();check(forge.enabled)
click("ArcanaHeirloomForge");req=request()
receive("QUOTE\t"..req[2].."\t"..id.."\t1\t700001\t0\t2\t6\t2\t1\t0\t30")
check(confirmation:IsShown() and frames.ArcanaHeirloomPaymentLink.label.text:find("|Hitem:47241:",1,true))
frames.ArcanaHeirloomPaymentLink.scripts.OnEnter(frames.ArcanaHeirloomPaymentLink)
check(GameTooltip.link:find("|Hitem:47241:",1,true))
click("ArcanaHeirloomConfirmCancel")
menus={};frames.ArcanaHeirloomMaterial.initialize();menus[6].func()
menus={};frames.ArcanaHeirloomOriginal.initialize();menus[1].func()
UIDROPDOWNMENU_OPEN_MENU=frames.ArcanaHeirloomOriginal
DropDownList1Button1.scripts.OnEnter(DropDownList1Button1)
check(GameTooltip.bag==0 and GameTooltip.slot==1)
GameTooltip.bag=nil;UIDROPDOWNMENU_OPEN_MENU=frames.ArcanaHeirloomFilter
DropDownList1Button1.scripts.OnEnter(DropDownList1Button1);check(GameTooltip.bag==nil)
frames.ArcanaHeirloomOriginalHover.scripts.OnEnter(frames.ArcanaHeirloomOriginalHover)
check(GameTooltip.bag==0 and GameTooltip.slot==1)
bagLink="item:999";event("BAG_UPDATE")
GameTooltip:Show();frames.ArcanaHeirloomOriginalHover.scripts.OnEnter(frames.ArcanaHeirloomOriginalHover)
check(not GameTooltip:IsShown() and not forge.enabled)
-- A collection packet burst redraws once, and its discovery notification
-- does not schedule an unnecessary second database snapshot.
bagLink="item:16905";tick();snapshot();tick(1)
host:RefreshHeirlooms();req=request();local beforeRows=host.resizes
receive("BEGIN\t"..req[2].."\t1\t200")
receive("CHANGED\t0\t700001")
receive("ROW\t"..req[2].."\t700001\t20\t3")
for guid=1,200 do receive("ORIGINAL\t"..req[2].."\t700001\t"..guid.."\t0\t1\t16905") end
check(host.resizes==beforeRows)
receive("END\t"..req[2]);check(host.resizes==beforeRows+1)
local afterSnapshot=#sent;tick(1);check(#sent==afterSnapshot)
-- Original copies are explicitly selected for the current family. A stale
-- dropdown callback/quote cannot carry an item into another family's Forge.
local function twoFamilies()
    local r=request();check(r[1]=="SYNC")
    receive("BEGIN\t"..r[2].."\t2\t2")
    receive("ROW\t"..r[2].."\t700001\t20\t3")
    receive("ROW\t"..r[2].."\t700002\t0\t0")
    receive("ORIGINAL\t"..r[2].."\t700001\t42\t2\t1\t16905")
    receive("ORIGINAL\t"..r[2].."\t700002\t43\t2\t2\t19019")
    receive("END\t"..r[2])
end
bagItems={[2]={[1]="item:16905:123:456",[2]="item:19019:0:0"}}
event("BAG_UPDATE");tick();twoFamilies()
click("ArcanaHeirloomRow2")
local amount
for _,frame in ipairs(created) do if frame.text=="Amount" then amount=frame end end
check(amount and not amount:IsShown() and not frames.ArcanaHeirloomQuantity:IsShown())
local staticQuantity
for _,frame in ipairs(created) do
    if frame.kind=="Font" and frame.text=="1" and frame:IsShown() then staticQuantity=frame end
end
check(not staticQuantity)
check(frames.ArcanaHeirloomOriginal.text=="Choose an original from your bags")
check(not forge.enabled and ArcanaHeirloomStatus.text=="Choose an original from your bags.")
check(ArcanaHeirloomStatus.color[2]==1)
local noSelectionRequests=#sent
click("ArcanaHeirloomForge");check(#sent==noSelectionRequests)
menus={};frames.ArcanaHeirloomOriginal.initialize();check(#menus==1)
menus[1].func();check(forge.enabled and ArcanaHeirloomStatus.text=="")
check(frames.ArcanaHeirloomOriginal.text:find("item:19019",1,true))
local staleChoice=menus[1].func
click("ArcanaHeirloomForge");local staleRequest=request()
check(staleRequest[3]=="700002" and staleRequest[6]=="43")
click("ArcanaHeirloomRow1")
check(not forge.enabled and frames.ArcanaHeirloomOriginal.text=="Choose an original from your bags")
staleChoice();check(not forge.enabled and frames.ArcanaHeirloomOriginal.text=="Choose an original from your bags")
receive("QUOTE\t"..staleRequest[2].."\t"..id.."\t1\t700002\t0\t20\t20\t1\t5\t43\t30")
check(not confirmation:IsShown())
menus={};frames.ArcanaHeirloomOriginal.initialize();check(#menus==1);menus[1].func()
check(forge.enabled and ArcanaHeirloomStatus.text=="")
frames.ArcanaHeirloomQuantity:SetText("99") -- hidden input cannot change original-copy quantity
check(forge.enabled)
click("ArcanaHeirloomForge");req=request()
check(req[3]=="700001" and req[4]=="5" and req[5]=="1" and req[6]=="42")
receive("QUOTE\t"..req[2].."\t"..id.."\t1\t700001\t20\t20\t20\t1\t5\t42\t30")
check(confirmation:IsShown())
check(frames.ArcanaHeirloomPaymentLink.label.text=="Are you sure you want to destroy 1 × item:16905:123:456?")
-- Local slot replacement is rejected even before BAG_UPDATE arrives.
bagItems[2][1]="item:999"
local beforeInvalidCommit=#sent
click("ArcanaHeirloomConfirmAccept")
check(#sent==beforeInvalidCommit and not confirmation:IsShown() and not forge.enabled)
check(frames.ArcanaHeirloomOriginal.text=="Choose an original from your bags")
check(ArcanaHeirloomStatus.text=="You do not have the required item/currency.")
menus={};frames.ArcanaHeirloomOriginal.initialize();check(#menus==0)
-- During snapshot refresh do not claim that inventory is missing. Restoring a
-- valid bag copy enables explicit selection without additional requests.
event("BAG_UPDATE")
check(ArcanaHeirloomStatus.text~="You do not have the required item/currency.")
bagItems[2][1]="item:16905:123:456";tick();twoFamilies()
local beforeSelection=#sent
menus={};frames.ArcanaHeirloomOriginal.initialize();menus[1].func()
check(forge.enabled and ArcanaHeirloomStatus.text=="")
click("ArcanaHeirloomRow2");menus={};frames.ArcanaHeirloomOriginal.initialize();menus[1].func()
check(forge.enabled and frames.ArcanaHeirloomOriginal.text:find("item:19019",1,true))
frames.ArcanaHeirloomOriginalHover.scripts.OnEnter(frames.ArcanaHeirloomOriginalHover)
check(GameTooltip.bag==2 and GameTooltip.slot==2)
check(#sent==beforeSelection)
-- A bag move retains the explicitly chosen GUID only after the new snapshot
-- validates its location. The label and hover must follow the moved copy.
bagItems[2][2]=nil;bagItems[2][3]="item:19019:0:0"
event("BAG_UPDATE");check(not forge.enabled)
tick();req=request();check(req[1]=="SYNC")
receive("BEGIN\t"..req[2].."\t2\t2")
receive("ROW\t"..req[2].."\t700001\t20\t3")
receive("ROW\t"..req[2].."\t700002\t0\t0")
receive("ORIGINAL\t"..req[2].."\t700001\t42\t2\t1\t16905")
receive("ORIGINAL\t"..req[2].."\t700002\t43\t2\t3\t19019")
receive("END\t"..req[2])
check(forge.enabled and frames.ArcanaHeirloomOriginal.text:find("bag 2, slot 3",1,true))
frames.ArcanaHeirloomOriginalHover.scripts.OnEnter(frames.ArcanaHeirloomOriginalHover)
check(GameTooltip.bag==2 and GameTooltip.slot==3)
-- Currency quantities return normally; confirmation wording remains "use".
menus={};frames.ArcanaHeirloomMaterial.initialize();menus[2].func()
frames.ArcanaHeirloomQuantity:SetText("1")
check(frames.ArcanaHeirloomQuantity:IsShown() and amount:IsShown() and forge.enabled)
click("ArcanaHeirloomForge");req=request()
receive("QUOTE\t"..req[2].."\t"..id.."\t1\t700002\t0\t1\t3\t1\t1\t0\t30")
check(confirmation:IsShown() and frames.ArcanaHeirloomPaymentLink.label.text:find("want to use 1 ×",1,true))
print("PASS "..checks.." heirloom UI confirmation, stale inventory, timeout, ambiguous receipt, spoof, discovery and filtering checks")

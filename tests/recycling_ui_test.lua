local frames,named,sent,hooks={},{},{},{}
local now,level,dead,combat,inside,casting,channeling=1,80,false,false,false,false,false
local cursor
local methods={}
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:HookScript(event,fn)
    local old=self.scripts[event];self.scripts[event]=function(...) if old then old(...) end;fn(...) end
end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown~=false end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:GetName() return self.name end
function methods:SetMovable(value) self.movable=value end
function methods:SetClampedToScreen(value) self.clamped=value end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetText(text) self.text=text end
function methods:SetPoint(...) self.point={...} end
function methods:SetWidth(width) self.width=width end
function methods:SetTexture(...) self.texture={...} end
function methods:SetAlpha(alpha) self.alpha=alpha end
function methods:SetSize(width,height) self.width,self.height=width,height end
function methods:SetHeight(height) self.height=height end
function methods:SetAllPoints(target) self.allPoints=target or true end
function methods:EnableMouse(value) self.mouse=value end
function methods:EnableKeyboard(value) self.keyboard=value end
function methods:GetStringHeight() local _,lines=(self.text or ""):gsub("\n","");return (lines+1)*14 end
function methods:CreateFontString(_,_,font) local f=CreateFrame("Font",nil,self);f.font=font;return f end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function CreateFrame(kind,name,parent)
    local frame=setmetatable({scripts={},name=name,parent=parent,kind=kind},{__index=function(_,key)
        return methods[key] or (key:match("^[A-Z]") and function() end)
    end})
    frames[#frames+1]=frame;if name then named[name]=frame end;return frame
end
UIParent=CreateFrame("Frame")
ArcanaItemUpgradesFrame=CreateFrame("Frame")
local host=ArcanaItemUpgradesFrame;host.serviceTab="Recycle";host.ServiceStatus=CreateFrame("Font")
GameTooltip=CreateFrame("Tooltip")
StaticPopupDialogs={};CANCEL="Cancel"
UIErrorsFrame={messages={},AddMessage=function(self,text) self.messages[#self.messages+1]=text end}
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
local confirmation=named.ArcanaRecyclingConfirmation
local accept=named.ArcanaRecycleConfirmAccept
local cancel=named.ArcanaRecycleConfirmCancel
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
    check(found)
    local empty=false
    for i=1,10 do if named["ArcanaRecycleSlot"..i].label.text=="Click to choose" then empty=true end end
    check(named.ArcanaRecyclingPicker:IsShown()==empty)
    named.ArcanaRecyclingPicker:Hide()
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
-- Specific restrictions take precedence even before the first server response.
level=60;host:RecyclingTabChanged("Recycle")
local requestsBefore=#sent
click(1)
check(UIErrorsFrame.messages[#UIErrorsFrame.messages]=="Recycling requires level 80.")
check(not named.ArcanaRecyclingPicker:IsShown() and not button.enabled and #sent==requestsBefore)
local function deniedSnapshot(message)
    tick(2);host:RefreshRecycling()
    local r=request();check(r[1]=="SYNC")
    receive("BEGIN\t"..r[2].."\t2\t0\t"..message)
    receive("END\t"..r[2])
end
for _,case in ipairs({
    {level=60,message="Recycling requires level 80."},
    {level=79,message="Recycling requires level 80."},
    {dead=true,message="You must be alive and out of combat."},
    {combat=true,message="You must be alive and out of combat."},
    {casting=true,message="Finish your current cast before recycling."},
    {channeling=true,message="Finish your current cast before recycling."},
    {inside=true,message="Leave the instance before recycling."},
    {message="Close the trade window before recycling."},
    {message="Recycling is temporarily unavailable."},
    {message="Recycling is unavailable during login or teleportation."},
}) do
    level=case.level or 80;dead=case.dead or false;combat=case.combat or false
    inside=case.inside or false;casting=case.casting or false;channeling=case.channeling or false
    deniedSnapshot(case.message)
    local before=#sent
    for i=1,3 do
        click(1)
        check(UIErrorsFrame.messages[#UIErrorsFrame.messages]==case.message)
        check(not named.ArcanaRecyclingPicker:IsShown() and not button.enabled and #sent==before)
    end
end
-- A missing reason has a safe fallback; invalid inventory never reuses a stale denial.
deniedSnapshot("");click(1)
check(UIErrorsFrame.messages[#UIErrorsFrame.messages]=="Recycling is temporarily unavailable.")
deniedSnapshot("Close the trade window before recycling.")
event("BAG_UPDATE");click(1)
check(UIErrorsFrame.messages[#UIErrorsFrame.messages]=="Refresh your inventory before choosing items.")
check(not named.ArcanaRecyclingPicker:IsShown() and not button.enabled)
-- The player's current state wins over a previously ready server snapshot.
tick(2);snapshot();level=60;click(1)
check(UIErrorsFrame.messages[#UIErrorsFrame.messages]=="Recycling requires level 80.")
check(not named.ArcanaRecyclingPicker:IsShown() and not button.enabled)
deniedSnapshot("Recycling requires level 80.")
level=80;event("PLAYER_LEVEL_UP",80);tick(2);snapshot()
local messagesBefore=#UIErrorsFrame.messages
click(1);check(named.ArcanaRecyclingPicker:IsShown() and #UIErrorsFrame.messages==messagesBefore)
named.ArcanaRecyclingPicker:Hide()
-- Casting after a ready response still reports its immediate local restriction.
casting=true;click(1)
check(UIErrorsFrame.messages[#UIErrorsFrame.messages]=="Finish your current cast before recycling.")
check(not named.ArcanaRecyclingPicker:IsShown() and not button.enabled)
casting=false
tick(2);host:RecyclingTabChanged("Recycle");snapshot()
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
button.scripts.OnClick();check(confirmation:IsShown() and confirmation.quoteId==id)
check(not host.ServiceStatus:IsShown() and host.ServiceStatus.text=="")
local title,question,list,solid,description
for _,f in ipairs(frames) do
    if f.parent==named.ArcanaRecycleConfirmDialog then
        if f.text=="These 10 items will be permanently destroyed." then title=true end
        if f.text=="Are you sure you want to proceed?" then question=true end
        if f.text==table.concat({"item:123","item:123","item:123","item:123","item:123","item:123","item:123","item:123","item:123","item:123"},"\n") then list=true end
        if f.kind=="Texture" and f.texture and f.texture[4]==1 and f.allPoints then solid=true end
    elseif f.parent==named.ArcanaRecyclingPanel and f.kind=="Font" then
        if f.text:find("• The item you receive",1,true) then description=f.text;check(f.font=="GameFontHighlightSmall" and f.point[3]==-229)
        elseif f.text:find("Average ilvl:",1,true) then check(f.text=="Average ilvl: 187.0" and f.point[3]==-204)
        else check(f.text=="Drag gear into an empty slot, or click a slot to choose an item.") end
    end
end
check(title and question and list and solid and confirmation.mouse and named.ArcanaRecycleConfirmDialog.alpha==1)
check(description and description:find("return you 50% of the total vendor value of all items.",1,true))
for i=1,10 do check(named["ArcanaRecycleSlot"..i].label.text=="Item 123") end
-- Cancel and Escape are purely local: keep the ten items and the usable quote.
local cancelCount=#sent
cancel.scripts.OnClick();check(not confirmation:IsShown() and button.enabled and #sent==cancelCount)
button.scripts.OnClick();check(confirmation:IsShown())
check(confirmation.keyboard)
confirmation.scripts.OnKeyDown(confirmation,"ENTER");check(confirmation:IsShown() and #sent==cancelCount)
confirmation.scripts.OnKeyDown(confirmation,"ESCAPE");check(not confirmation:IsShown() and host:IsShown() and button.enabled and #sent==cancelCount)
button.scripts.OnClick()
-- A replacement with identical entry/value invalidates both popup and old request.
click(10,"RightButton");check(not confirmation:IsShown() and not button.enabled);choose(10,11);tick()
old=request()[2];click(10,"RightButton");choose(10,10)
quote(old);check(not button.enabled);tick();quote();check(button.enabled)
button.scripts.OnClick();accept.scripts.OnClick()
check(request()[1]=="COMMIT" and ArcanaItemUpgradesDB.recyclingPending==id and not button.enabled)
local count=#sent;accept.scripts.OnClick();check(#sent==count)
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
tick();quote();button.scripts.OnClick();check(confirmation:IsShown())
tick(31);check(not button.enabled and not confirmation:IsShown())
local expiryCount=#sent
accept.scripts.OnClick();check(#sent==expiryCount) -- Expired confirmation cannot commit.
tick();check(request()[1]=="QUOTE2");quote();check(button.enabled and not confirmation:IsShown())
check(request()[3]=="1,2,3,4,5,6,7,8,9,10")
-- Repeated renewal stays bounded, retains selection and never auto-confirms.
for i=1,3 do
    local countBefore=#sent
    button.scripts.OnClick();cancel.scripts.OnClick();tick(31);tick()
    check(#sent==countBefore+1 and request()[1]=="QUOTE2")
    quote();check(button.enabled and not confirmation:IsShown())
end
-- Cancel on the expiry boundary before the next update also schedules renewal.
button.scripts.OnClick();now=now+31;cancel.scripts.OnClick()
check(not button.enabled);tick();quote();check(button.enabled)
-- Delayed renewal after a bag mutation must not revive a stale selection.
tick(31);tick();local staleRenewal=request()[2]
event("BAG_UPDATE");quote(staleRenewal);check(not button.enabled)
tick();snapshot();tick();quote();check(button.enabled)
-- Safety can change while the dialog is open, before its event arrives.
for _,restriction in ipairs({"level","dead","combat","inside","casting","channeling"}) do
    button.scripts.OnClick();check(confirmation:IsShown())
    level=restriction=="level" and 79 or 80;dead=restriction=="dead";combat=restriction=="combat";inside=restriction=="inside"
    casting=restriction=="casting";channeling=restriction=="channeling"
    local countBefore=#sent;accept.scripts.OnClick();check(#sent==countBefore and not ArcanaItemUpgradesDB.recyclingPending)
    level=80;dead=false;combat=false;inside=false;casting=false;channeling=false
    cancel.scripts.OnClick()
end
-- Closing/switching tabs never commits or renews in the background.
button.scripts.OnClick();host.serviceTab="Affixes";host:RecyclingTabChanged("Affixes")
check(not confirmation:IsShown() and host.ServiceStatus:IsShown())
local closedCount=#sent;accept.scripts.OnClick();tick(60);check(#sent==closedCount)
host.serviceTab="Recycle";host:RecyclingTabChanged("Recycle");snapshot();tick();quote();button.scripts.OnClick()
host:Hide();check(not confirmation:IsShown());closedCount=#sent;tick(60);check(#sent==closedCount)
host:Show();host.scripts.OnShow(host);snapshot();tick();quote();button.scripts.OnClick()
-- Duplicate acknowledgement cannot cause another commit or create a new batch.
accept.scripts.OnClick();local committed=request();receive("RESULT\t"..committed[2].."\t"..id.."\t1000\t0")
local completedCount=#sent;receive("RESULT\t"..committed[2].."\t"..id.."\t1000\t0")
accept.scripts.OnClick();check(#sent==completedCount and not ArcanaItemUpgradesDB.recyclingPending)
check(not host.ServiceStatus:IsShown() and host.ServiceStatus.text=="")
-- Continuous picker fills from the requested slot, wraps and closes only at ten.
local picker=named.ArcanaRecyclingPicker
local clear=named.ArcanaRecycleClearAll
local autofill=named.ArcanaRecycleAutofill
local scroll=named.ArcanaRecyclingPickerScroll
local function loadRows(levels)
    clear.scripts.OnClick();host:RefreshRecycling();tick(2)
    local current=request();check(current[1]=="SYNC")
    receive("BEGIN\t"..current[2].."\t2\t1\t")
    for i,ilvl in ipairs(levels) do
        receive(table.concat({"ITEM",current[2],i,math.floor((i-1)/16),(i-1)%16+1,123,ilvl,101,0},"\t"))
    end
    receive("END\t"..current[2])
end
local levels={};for i=1,20 do levels[i]=187 end
loadRows(levels);check(not clear:IsShown());click(7)
check(picker.movable and picker.clamped and autofill.text=="Autofill highest ilvl")
check(not autofill.scripts.OnEnter) -- No tooltip.
named.ArcanaRecyclingPickerDrag.scripts.OnDragStart();check(picker.moving)
named.ArcanaRecyclingPickerDrag.scripts.OnDragStop();check(not picker.moving)
for i=1,10 do
    local row=pickerRows()[1];check(row.row.guid==i and row.value.text=="ilvl 187")
    row.scripts.OnClick(row);check(clear:IsShown());check(picker:IsShown()==(i<10))
end
tick();check(request()[3]=="5,6,7,8,9,10,1,2,3,4")
local stale=request()[2];clear.scripts.OnClick();check(not clear:IsShown() and not button.enabled)
quote(stale);check(not button.enabled);local noQuote=#sent;tick(1);check(#sent==noQuote)
-- Shrinking the scrollable list preserves the offset and clamps at its end.
loadRows(levels);click(1);scroll.scripts.OnVerticalScroll(scroll,11*27)
check(scroll.offset==11 and pickerRows()[1].row.guid==12)
local row=pickerRows()[1];row.scripts.OnClick(row)
check(scroll.offset==10 and picker:IsShown() and pickerRows()[1].row.guid==11)
-- Autofill replaces manual choices, sorts descending, and keeps identical copies distinct.
for i=1,20 do levels[i]=187+i end
loadRows(levels);choose(1,1);click(2);autofill.scripts.OnClick()
check(not picker:IsShown() and clear:IsShown());tick()
check(request()[3]=="20,19,18,17,16,15,14,13,12,11")
-- Equal levels have deterministic bag/slot ordering; fewer than ten stay unconfirmed.
loadRows({200,200,200,200,200,200,200,200,200,200,200});click(1);autofill.scripts.OnClick();tick()
check(request()[3]=="1,2,3,4,5,6,7,8,9,10")
loadRows({187,245,200});click(2);local beforeAutofill=#sent;autofill.scripts.OnClick();tick()
check(picker:IsShown() and clear:IsShown() and not button.enabled and #sent==beforeAutofill)
local emptyLabel
for _,frame in ipairs(frames) do if frame.parent==picker and frame.text=="No compatible unselected items in your bags." then emptyLabel=frame end end
check(emptyLabel:IsShown())
clear.scripts.OnClick();check(not picker:IsShown() and not clear:IsShown())
loadRows({});click(1);check(not autofill.enabled);autofill.scripts.OnClick();check(not clear:IsShown())
-- Live inventory invalidation and restrictions cannot revive an autofill selection.
loadRows(levels);click(1);event("BAG_UPDATE");autofill.scripts.OnClick();check(not clear:IsShown() and not button.enabled)
loadRows(levels);click(1);combat=true;autofill.scripts.OnClick();check(not clear:IsShown());combat=false
-- Neither Clear all nor autofill can alter a committed batch awaiting its receipt.
loadRows({187,187,187,187,187,187,187,187,187,187});click(1);autofill.scripts.OnClick();tick();quote()
button.scripts.OnClick();accept.scripts.OnClick();check(not clear.enabled)
local pendingCount=#sent;clear.scripts.OnClick();autofill.scripts.OnClick()
check(clear:IsShown() and #sent==pendingCount and ArcanaItemUpgradesDB.recyclingPending==id)
print("PASS: "..checks.." recycling drag/picker, duplicate identity, stale quotes, retry/reload and restriction checks")

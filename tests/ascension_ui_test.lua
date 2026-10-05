local frames, named, sent = {}, {}, {}
local now, level, inside, dead, combat = 1, 80, false, false, false
local popup, link = nil, "|Hitem:9425:0:0:0:0:0:0:0:80|h[Pendum]|h"
local methods={}
function methods:SetScript(e,f) self.scripts[e]=f end
function methods:HookScript(e,f)
    local old=self.scripts[e];self.scripts[e]=function(...) if old then old(...) end;f(...) end
end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown~=false end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetText(text) self.text=text end
function methods:CreateFontString() return CreateFrame("Font") end
function CreateFrame(kind,name)
    local f=setmetatable({scripts={},name=name},{__index=function(_,key)
        return methods[key] or (key:match("^[A-Z]") and function() end)
    end})
    frames[#frames+1]=f;if name then named[name]=f end;return f
end
ArcanaItemUpgradesFrame=CreateFrame("Frame")
local host=ArcanaItemUpgradesFrame
host.TemperingButton=CreateFrame("Button");host.ServiceSubtitle=CreateFrame("Font")
host.AffixControls={CreateFrame("Button"),CreateFrame("Font")}
function host:GetSelectedEquipmentSlot() return 15 end
function host:UpdateDisplay() if self.ApplyServiceVisibility then self:ApplyServiceVisibility() end end
function host:RefreshTempering() self.temperingRefreshed=true end
function host:RefreshAffixes() self.affixesRefreshed=true end
GameTooltip=CreateFrame("Tooltip")
StaticPopupDialogs={};ACCEPT="Accept";CANCEL="Cancel"
function StaticPopup_Hide() popup=nil end
function StaticPopup_Show(kind,a,b,data) popup={kind=kind,data=data} end
function SendAddonMessage(prefix,message,channel,sender) sent[#sent+1]={prefix,message,channel,sender} end
function UnitName() return "Tester" end
function UnitLevel() return level end
function UnitIsDeadOrGhost() return dead end
function UnitAffectingCombat() return combat end
function IsInInstance() return inside end
function GetInventoryItemLink() return link end
function GetTime() return now end
dofile("AscensionProtocol.lua");dofile("AscensionUI.lua")
local events=frames[#frames]
local button=named.ArcanaAscendButton
local checks=0
local function check(value) checks=checks+1;assert(value,"check "..checks) end
local function receive(text,sender)
    events.scripts.OnEvent(events,"CHAT_MSG_ADDON","AAS",text,"WHISPER",sender or "Tester")
end
local function snapshot(row)
    receive("BEGIN");receive(row or "ITEM\t15\t123\t9425\t44\t500000\t194700\t2");receive("END")
end
check(host.serviceTab=="Tempering" and host.TemperingButton:IsShown())
check(not host.AffixControls[1]:IsShown() and not button:IsShown())
host:SetServiceTab("Affixes")
check(host.AffixControls[1]:IsShown() and not host.TemperingButton:IsShown() and not button:IsShown())
host:SetServiceTab("Ascension")
check(button:IsShown() and not host.AffixControls[1]:IsShown() and not host.TemperingButton:IsShown())
check(not button.enabled and sent[#sent][2]=="SYNC")
receive("BEGIN","AnotherPlayer");receive("END","AnotherPlayer")
check(not button.enabled)
snapshot();check(button.enabled)
button.scripts.OnClick();check(popup and popup.kind=="ARCANA_ASCENSION_CONFIRM")
local selected=popup.data
StaticPopupDialogs.ARCANA_ASCENSION_CONFIRM.OnAccept({},selected)
check(sent[#sent][2]=="ASCEND\t15\t123\t9425\t500000" and not button.enabled)
local count=#sent
StaticPopupDialogs.ARCANA_ASCENSION_CONFIRM.OnAccept({},selected)
check(#sent==count) -- Double acceptance cannot spend again.
receive("RESULT\tAscended");snapshot()
check(host.temperingRefreshed and host.affixesRefreshed)
link="|Hitem:1234:0|h[Replacement]|h";host:UpdateDisplay();check(not button.enabled)
link="|Hitem:9425:0|h[Pendum]|h";snapshot();check(button.enabled)
for _,restriction in ipairs({"level","inside","dead","combat"}) do
    if restriction=="level" then level=79 elseif restriction=="inside" then inside=true
    elseif restriction=="dead" then dead=true else combat=true end
    host:UpdateDisplay();check(not button.enabled)
    level=80;inside=false;dead=false;combat=false
end
snapshot("ITEM\t15\t123\t9425\t44\t500000\t194700\t0");check(not button.enabled)
snapshot("ITEM\t15\t123\t9425\t284\t0\t0\t0");check(not button.enabled)
now=2;host:SetServiceTab("Ascension")
receive("BEGIN");receive("ITEM\t15\t123\t9425\t44\t500000\t194700\tnan");receive("END")
check(not button.enabled)
now=3;host:SetServiceTab("Ascension");now=9;events.scripts.OnUpdate(events)
check(not button.enabled and not next(host.ascensionSlots))
now=10;host:SetServiceTab("Ascension");snapshot();check(button.enabled)
button.scripts.OnClick();check(popup~=nil);host:SetServiceTab("Affixes");check(popup==nil)
print("PASS: "..checks.." three-tab, confirmation, stale item, level/combat/location, malformed reply and timeout checks")

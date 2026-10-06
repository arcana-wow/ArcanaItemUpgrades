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
function methods:GetStringWidth() return #(self.text or "")*5 end
function methods:SetPoint(...) self.point={...} end
function methods:SetWidth(width) self.width=width end
function methods:SetHeight(height) self.height=height end
function methods:SetChecked(value) self.checked=value end
function methods:GetChecked() return self.checked end
function methods:GetWidth() return self.name=="UIParent" and 1200 or 250 end
function methods:GetHeight() return self.name=="UIParent" and 900 or 400 end
function methods:GetCenter() return 600,500 end
function methods:GetTop() return 400 end
function methods:SetHyperlink(link) self.link=link;self.inventory=nil end
function methods:SetInventoryItem(unit,slot) self.inventory={unit,slot};self.link=nil end
function methods:CreateFontString() return CreateFrame("Font") end
function CreateFrame(kind,name)
    local f=setmetatable({scripts={},name=name},{__index=function(_,key)
        return methods[key] or (key:match("^[A-Z]") and function() end)
    end})
    frames[#frames+1]=f;if name then named[name]=f end;return f
end
UIParent=CreateFrame("Frame","UIParent")
ArcanaItemUpgradesFrame=CreateFrame("Frame")
local host=ArcanaItemUpgradesFrame
host.TemperingButton=CreateFrame("Button");host.ServiceSubtitle=CreateFrame("Font")
host.AffixControls={CreateFrame("Button"),CreateFrame("Font")}
host.ServiceEligibilityText=CreateFrame("Font")
function host:GetAffixDescription() return nil end
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
local clickedLink
function SetItemRef(link) clickedLink=link end
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
local preview=named.ArcanaAscensionPreviewButton
local compare=named.ArcanaAscensionCompareItems
local nextTip=named.ArcanaAscensionNextTooltip
check(not compare:GetChecked())
preview.scripts.OnEnter(preview)
check(GameTooltip.link=="item:500000" and not nextTip:IsShown())
preview.scripts.OnLeave();check(not GameTooltip:IsShown() and not nextTip:IsShown())
compare:SetChecked(true);preview.scripts.OnEnter(preview)
check(GameTooltip.inventory[2]==16 and nextTip.link=="item:500000" and nextTip:IsShown())
check(GameTooltip.point[1]=="BOTTOMLEFT" and nextTip.point[2]==GameTooltip and nextTip.point[3]=="TOPRIGHT")
host:UpdateDisplay();check(GameTooltip:IsShown() and nextTip:IsShown())
local beforePreviewRequests=#sent
preview.scripts.OnUpdate();check(#sent==beforePreviewRequests)

preview.scripts.OnLeave();check(not GameTooltip:IsShown() and not nextTip:IsShown())
compare:SetChecked(false)

check(host:ServiceRowStatus({slot=15})=="ilvl 44")
check(host.ServiceSubtitle.text=="Ascend your equipment using the appropriate Ascension token. Requires level 80.")
local token=named.ArcanaAscensionTokenLink
check(token.link:find("|Hitem:194700|h",1,true) and token.width>0)
check(not token.scripts.OnEnter and not named.ArcanaAscensionInstruction.scripts.OnEnter)
token.scripts.OnClick(token);check(clickedLink=="item:194700")
check(host:ServiceEligibility({slot=15},true,nil,5)=="Eligible for ascension to ilvl 200")
check(host:GetAscensionCatalogueEntry(15)==500000)
check(host.height==640 and button.point[2]==named.ArcanaAscensionPreviewButton)
function host:GetAffixDescription(slot) return slot==15 and "+18 Intellect" end
host:SetServiceTab("Affixes")
check(host:ServiceRowStatus({slot=15})=="+18 Intellect" and host:ServiceRowStatus({slot=0})=="No affix")
check(host:ServiceEligibility({slot=15},true,nil,5)=="Eligible for recalibration")
check(host:ServiceEligibility({slot=0},true,nil,5)=="Unavailable for recalibration.")
check(host.ServiceSubtitle.text=="Reroll an item's bonus stat using a Recalibration Sigil.")
host:SetServiceTab("Tempering")
check(host:ServiceEligibility({slot=15,rank=1},true,nil,5)=="Eligible for tempering to rank 2/5")
check(host:ServiceEligibility({slot=15,affixOnly=true},true,nil,5)=="Unavailable for tempering.")
check(host:ServiceEligibility({slot=15,rank=5},true,nil,5)=="Maximum tempering rank reached (5/5).")
check(host:ServiceEligibility({slot=15,rank=1},false,"You must be alive.",5)=="You must be alive.")
now=1.3;host:SetServiceTab("Ascension");snapshot()
button.scripts.OnClick();check(popup and popup.kind=="ARCANA_ASCENSION_CONFIRM")
local selected=popup.data
StaticPopupDialogs.ARCANA_ASCENSION_CONFIRM.OnAccept({},selected)
check(sent[#sent][2]=="ASCEND\t15\t123\t9425\t500000" and not button.enabled)
local count=#sent
StaticPopupDialogs.ARCANA_ASCENSION_CONFIRM.OnAccept({},selected)
check(#sent==count) -- Double acceptance cannot spend again.
receive("RESULT\tAscended");snapshot()
check(host.temperingRefreshed and host.affixesRefreshed)
link="|Hitem:1234:0|h[Replacement]|h";host:UpdateDisplay();check(not button.enabled and not host:GetAscensionCatalogueEntry(15))
link="|Hitem:9425:0|h[Pendum]|h";snapshot();check(button.enabled)
for _,restriction in ipairs({"level","inside","dead","combat"}) do
    if restriction=="level" then level=79 elseif restriction=="inside" then inside=true
    elseif restriction=="dead" then dead=true else combat=true end
    host:UpdateDisplay();check(not button.enabled)
    level=80;inside=false;dead=false;combat=false
end
snapshot("ITEM\t15\t123\t9425\t44\t500000\t194700\t0");check(not button.enabled)
snapshot("ITEM\t15\t123\t9425\t284\t0\t0\t0");check(not button.enabled and not token:IsShown())
check(host:GetAscensionCatalogueEntry(15)==9425)
check(host:ServiceEligibility({slot=15},true,nil,5)=="Maximum Ascension level reached (ilvl 284).")
now=2;host:SetServiceTab("Ascension")
receive("BEGIN");receive("ITEM\t15\t123\t9425\t44\t500000\t194700\tnan");receive("END")
check(not button.enabled)
now=3;host:SetServiceTab("Ascension");now=9;events.scripts.OnUpdate(events)
check(not button.enabled and not next(host.ascensionSlots))
now=10;host:SetServiceTab("Ascension");snapshot();check(button.enabled)
button.scripts.OnClick();check(popup~=nil);host:SetServiceTab("Affixes");check(popup==nil)
print("PASS: "..checks.." three-tab, confirmation, stale item, level/combat/location, malformed reply and timeout checks")

local frames,sent={},{}
local time=1
local guid="0x00000000000000FF"
local link="|Hitem:500010:0|h[Warglaive]|h"
local methods={}
function methods:GetName() return self.name end
function methods:GetText() return self.text end
function methods:SetText(t) self.text=t end
function methods:SetTextColor(...) self.color={...} end
function methods:SetScript(e,f) self.scripts[e]=f end
function methods:HookScript(e,f) local old=self.scripts[e];self.scripts[e]=function(...) if old then old(...) end;f(...) end end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown~=false end
function methods:SetOwner(owner) self.owner=owner end
function methods:GetOwner() return self.owner end
function methods:NumLines() return self.count or 0 end
function methods:AddLine(text,r,g,b)
    self.count=self:NumLines()+1
    local font=CreateFrame("Font",self.name.."TextLeft"..self.count)
    font:SetText(text);font:SetTextColor(r,g,b)
end
function methods:SetInventoryItem()
    self.count=0
    if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
    self:AddLine("Warglaive");self:AddLine("Twin Blades (0/2)")
    self:AddLine("(2) Set: Native haste");self:AddLine("(2) Set: Native demon damage")
end
function methods:SetHyperlink(value)
    self.count=0;self:AddLine("Spell");self:AddLine(value=="spell:200000" and "Increases haste by 900." or "Increases demon attack power by 400.")
end
function CreateFrame(kind,name)
    local f=setmetatable({name=name,scripts={}},{__index=function(_,k)return methods[k] or (k:match("^[A-Z]") and function()end)end})
    if name then _G[name]=f end;frames[#frames+1]=f;return f
end
function hooksecurefunc(o,key,fn) local old=o[key];o[key]=function(...) old(...);fn(...) end end
function GetTime()return time end
function UnitGUID()return guid end
function UnitName()return "Tester" end
function GetInventoryItemLink()return link end
function SendAddonMessage(prefix,text) sent[#sent+1]=text end
function GetSpellInfo()return "Spell"end
UIParent=CreateFrame("Frame","UIParent")
GameTooltip=CreateFrame("GameTooltip","GameTooltip");GameTooltip:SetOwner(UIParent)
dofile("AscensionProtocol.lua");dofile("AscensionSetTooltips.lua")
local events=frames[#frames]
local function receive(text,sender)events.scripts.OnEvent(events,"CHAT_MSG_ADDON","AAS",text,"WHISPER",sender or "Tester")end
GameTooltip:SetInventoryItem("target",16)
assert(sent[1]=="SETS\t1\t255\t15\t500010")
receive("SETSBEGIN\t1","Spoof");receive("SET\t1\t699\t2\t2\t1\t200000","Spoof");receive("SETSEND\t1","Spoof")
assert(GameTooltipTextLeft3:GetText()=="(2) Set: Native haste")
receive("SETSBEGIN\t1");receive("SET\t1\t699\t2\t2\t1\t200000");receive("SET\t1\t699\t2\t2\t1\t200001");receive("SETSEND\t1")
assert(GameTooltipTextLeft2:GetText()=="Twin Blades (2/2)")
assert(GameTooltipTextLeft3:GetText()=="(2) Set: Increases haste by 900.")
assert(GameTooltipTextLeft4:GetText()=="(2) Set: Increases demon attack power by 400.")
assert(GameTooltipTextLeft3.color[2]==1 and GameTooltipTextLeft3.color[1]==0)
GameTooltip:SetInventoryItem("target",16);assert(#sent==1)
events.scripts.OnEvent(events,"UNIT_INVENTORY_CHANGED","target")
GameTooltip:SetInventoryItem("target",16);assert(#sent==2)
guid="0x00000000000000EE"
receive("SETSBEGIN\t2");receive("SET\t2\t699\t2\t2\t1\t200000");receive("SETSEND\t2")
assert(GameTooltipTextLeft3:GetText()=="(2) Set: Native haste") -- Different inspected character.
GameTooltip:SetInventoryItem("target",16)
receive("SETSBEGIN\t3");receive("SET\t3\t699\t1\t2\t0\t200000");receive("SET\t3\t699\t1\t2\t0\t200001");receive("SETSEND\t3")
assert(GameTooltipTextLeft2:GetText()=="Twin Blades (1/2)")
assert(GameTooltipTextLeft3.color[1]==0.5 and GameTooltipTextLeft3.color[2]==0.5)
print("PASS: scaled set descriptions, exact counts, active/inactive colors, cache, spoof and stale-inspection rejection")

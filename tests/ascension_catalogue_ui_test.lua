local frames,named,sent={}, {}, {}
local now=0
local methods={}
function methods:SetScript(e,f) self.scripts[e]=f end
function methods:HookScript(e,f) local old=self.scripts[e];self.scripts[e]=function(...) if old then old(...) end;f(...) end end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown~=false end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetText(text) self.text=text;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,true) end end
function methods:GetText() return self.text or "" end
function methods:SetTextColor(...) self.color={...} end
function methods:GetTextColor() return unpack(self.color or {1,1,1}) end
function methods:GetStringHeight() return 12 end
function methods:GetName() return self.name end
function methods:GetFrameLevel() return 5 end
function methods:CreateFontString() return CreateFrame("Font",nil,self) end
function methods:SetOwner(owner) self.owner=owner end
function methods:NumLines() return self.count or 0 end
function methods:AddLine(text)
    self.count=self:NumLines()+1
    local line=CreateFrame("Font",self.name.."TextLeft"..self.count,self);line:SetText(text)
end
function methods:SetHyperlink(link)
    self.link=link;self.count=0
    self:AddLine("Item "..link:match("item:(%d+)"));self:AddLine("+100 Intellect");self:AddLine("Red Socket")
end
function CreateFrame(kind,name,parent)
    local f=setmetatable({name=name,parent=parent,scripts={}},{__index=function(_,key)
        return methods[key] or (key:match("^[A-Z]") and function() end)
    end})
    frames[#frames+1]=f;if name then named[name]=f;_G[name]=f end;return f
end
function hooksecurefunc(o,k,f) local old=o[k];o[k]=function(...) old(...);f(...) end end
function GetTime() return now end
function GetItemInfo(id) return "Item "..id end
function UnitName() return "Tester" end
function SendAddonMessage(prefix,text,channel,sender) sent[#sent+1]={prefix,text,channel,sender} end
UIParent=CreateFrame("Frame","UIParent")
GameTooltip=CreateFrame("Tooltip","GameTooltip")
ITEM_QUALITY_COLORS={[3]={r=0,g=0.4,b=1},[4]={r=0.7,g=0,b=1},[5]={r=1,g=0.5,b=0}}
local host=CreateFrame("Frame","ArcanaItemUpgradesFrame")
host.serviceTab="Ascension";host.ServiceStatus=CreateFrame("Font")
function host:ApplyServiceVisibility() end
local previews={}
function ArcanaAscensionSetPreview(tooltip,rows) previews[#previews+1]={tooltip=tooltip,rows=rows} end
dofile("AscensionProtocol.lua");dofile("AscensionCatalogueProtocol.lua");dofile("AscensionCatalogue.lua")
local events=frames[#frames]
local pane,search=named.ArcanaAscensionCatalogue,named.ArcanaAscensionSearch
local checks=0
local function check(v) checks=checks+1;assert(v,"check "..checks) end
local function tick(time) now=time;events.scripts.OnUpdate(events) end
local function receive(message,sender) events.scripts.OnEvent(events,"CHAT_MSG_ADDON","AAS",message,"WHISPER",sender or "Tester") end
local function result(id)
    receive("CATBEGIN\t"..id.."\t0\t1")
    receive("CATROW\t"..id.."\t873\t0\t0\t40\t4\tStaff of Jordan\t500001\t500002\t500003\t500004\t500005")
    receive("CATEND\t"..id)
end
check(search:IsShown() and not pane:IsShown())
search:SetText("s");check(pane:IsShown() and #sent==0)
tick(0.49);check(#sent==0)
search:SetText("st");tick(0.99);check(#sent==1 and sent[1][2]=="SEARCH\t1\t0\tst")
receive("CATBEGIN\t1\t0\t0","Spoof");receive("CATEND\t1","Spoof")
local row
for _,candidate in ipairs(frames) do if candidate.parent==pane and candidate.scripts.OnEnter then row=candidate;break end end
check(row and not row:IsShown())
result(1);check(row:IsShown() and row.row.source==873 and row.name.text=="Staff of Jordan")
row.scripts.OnEnter(row)
check(GameTooltip.link=="item:500001:0:0:0:0:0:0:0:80") -- Hover previews the next tier, not the original.
row.scripts.OnClick(row)
check(named.ArcanaCatalogueComparisonScroll:IsShown() and not row:IsShown())
local headings={}
for _,candidate in ipairs(frames) do
    if candidate.heading then headings[#headings+1]=candidate.heading.text end
end
check(#headings==6 and headings[1]=="Original (ilvl 40)" and headings[6]=="Ascended - ilvl 284")
tick(1.6);check(sent[#sent][2]=="DETAIL\t2\t873\t0")
receive("CATDETAILBEGIN\t2");receive("CATDETAILEND\t2")
check(previews[#previews].rows~=nil)
named.ArcanaCatalogueBack.scripts.OnClick();check(row:IsShown())
named.ArcanaCatalogueBack.scripts.OnClick();check(not pane:IsShown())
named.ArcanaAscensionBrowse.scripts.OnClick();check(row:IsShown()) -- Cached query.
search:SetText("");tick(2.2);check(sent[#sent][2]=="SEARCH\t3\t0\t")
host.serviceTab="Affixes";host:ApplyServiceVisibility();check(not pane:IsShown() and not search:IsShown())
result(3);check(not pane:IsShown())
host.serviceTab="Ascension";host:ApplyServiceVisibility();check(search:IsShown())
named.ArcanaAscensionBrowse.scripts.OnClick();tick(2.8)
host:Hide();check(not pane:IsShown());tick(10);check(not pane:IsShown())
print("PASS: "..checks.." catalogue UI typing, spoof rejection, original results, ascended hover, six-version comparison, cache and visibility checks")

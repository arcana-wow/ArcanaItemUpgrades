local frames,named,sent={}, {}, {}
local now=0
local mouseDown,mouseOver,chatInsert=false,true,0
function IsMouseButtonDown() return mouseDown end
function MouseIsOver() return mouseOver end
function ChatEdit_InsertLink() chatInsert=chatInsert+1;return "chat" end
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
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint() return unpack(self.point or {}) end
function methods:GetNumPoints() return self.point and 1 or 0 end
function methods:SetSize(width,height) self.width=width;self.height=height end
function methods:SetWidth(width) self.width=width end
function methods:GetObjectType() return self.kind end
function methods:SetTexture(path) self.texture=path end
function methods:GetTexture() return self.texture end
function methods:SetTexCoord(...) self.coords={...} end
function methods:GetTexCoord() return unpack(self.coords or {0,1,0,1}) end
function methods:GetRegions() return unpack(self.regions or {}) end
function methods:GetName() return self.name end
function methods:GetFrameLevel() return 5 end
function methods:CreateFontString() return CreateFrame("Font",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function methods:SetBackdrop(backdrop) self.backdrop=backdrop end
function methods:SetFocus() self.focus=true end
function methods:HasFocus() return self.focus end
function methods:ClearFocus() self.focus=false end
function methods:SetOwner(owner) self.owner=owner end
function methods:NumLines() return self.count or 0 end
function methods:AddLine(text)
    self.count=self:NumLines()+1
    local line=CreateFrame("Font",self.name.."TextLeft"..self.count,self);line:SetText(text)
end
function methods:SetHyperlink(link)
    self.link=link;self.count=0
    self:AddLine("Item "..link:match("item:(%d+)"));self:AddLine("+100 Intellect")
    self.regions={}
    -- Localized text; art comes from native texture anchors, not an English match.
    for index,color in ipairs({"Red","Meta","Blue"}) do
        self:AddLine("Localized socket "..index)
        local texture=self:CreateTexture()
        texture:SetTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-"..color)
        texture:SetPoint("LEFT",_G[self.name.."TextLeft"..self.count],"LEFT",-20,0)
        self.regions[index]=texture
    end
    self.regions[3]:Hide() -- A pooled, hidden texture must not leak into the card.
end
function CreateFrame(kind,name,parent)
    local f=setmetatable({name=name,parent=parent,kind=kind,scripts={}},{__index=function(_,key)
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
host.AscensionButton=CreateFrame("Button")
local equipmentEntry=500004
function host:GetAscensionCatalogueEntry() return equipmentEntry end
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
check(pane.backdrop.bgFile=="Interface\\Buttons\\WHITE8X8" and not named.ArcanaCatalogueBack:IsShown())
check(search.point[2]==host.AscensionButton and search.point[3]=="BOTTOM")
check(not named.ArcanaAscensionBrowse.enabled)
named.ArcanaAscensionBrowse.scripts.OnClick();tick(0.6);check(#sent==0 and not pane:IsShown())
now=0
search:SetText("s");check(pane:IsShown() and #sent==0)
tick(0.49);check(#sent==0)
search:SetText("st");tick(0.99);check(#sent==1 and sent[1][2]=="SEARCH\t1\t0\tst")
receive("CATBEGIN\t1\t0\t0","Spoof");receive("CATEND\t1","Spoof")
local row
for _,candidate in ipairs(frames) do if candidate.parent==pane and candidate.scripts.OnEnter then row=candidate;break end end
check(row and not row:IsShown())
result(1);check(row:IsShown() and row.row.source==873 and row.name.text=="Staff of Jordan" and not row.level)
row.scripts.OnEnter(row)
check(GameTooltip.link=="item:873:0:0:0:0:0:0:0:80") -- Hover previews the original item.
row.scripts.OnClick(row)
check(named.ArcanaCatalogueComparisonScroll:IsShown() and not row:IsShown())
local headings={}
for _,candidate in ipairs(frames) do
    if candidate.heading then headings[#headings+1]=candidate.heading.text end
end
check(#headings==6 and headings[1]=="Original (ilvl 40)" and headings[6]=="Ascended - ilvl 284")
local copied=0
for _,candidate in ipairs(frames) do
    if candidate.heading then
        check(candidate.sockets[3].texture=="Interface\\ItemSocketingFrame\\UI-EmptySocket-Red")
        check(candidate.sockets[4].texture=="Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta")
        check(not candidate.sockets[5] and candidate.lines[3].point[2]==28)
        copied=copied+1
    end
end
check(copied==6)
tick(1.6);check(sent[#sent][2]=="DETAIL\t2\t873\t0")
receive("CATDETAILBEGIN\t2");receive("CATDETAILEND\t2")
check(previews[#previews].rows~=nil)
named.ArcanaCatalogueBack.scripts.OnClick();check(row:IsShown())
named.ArcanaCatalogueClose.scripts.OnClick();check(not pane:IsShown())
named.ArcanaAscensionBrowse.scripts.OnClick();check(row:IsShown()) -- Cached query.
row.scripts.OnClick(row);named.ArcanaCatalogueClose.scripts.OnClick();check(not pane:IsShown())
local count=#sent
search:SetFocus();search:SetText("");tick(2.2);check(#sent==count and not pane:IsShown() and search:HasFocus())
mouseDown=true;mouseOver=false;tick(2.3);check(not search:HasFocus());mouseDown=false
search:SetText("   ");tick(3);check(#sent==count and not pane:IsShown() and not named.ArcanaAscensionBrowse.enabled)
host:OpenAscensionEquipment(15);check(search:GetText()=="   " and not row:IsShown());tick(3.49);check(#sent==count)
tick(3.51);check(sent[#sent][2]=="SEARCH\t3\t0\t500004")
result(3);check(named.ArcanaCatalogueComparisonScroll:IsShown() and not row:IsShown())
check(named.ArcanaCatalogueClose:IsShown() and not named.ArcanaCatalogueBack:IsShown())
check(search:GetText()=="   ")
named.ArcanaCatalogueClose.scripts.OnClick();tick(4.1);check(#sent==count+1) -- Closing cancels the detail request.
search:SetText("cancel before response");tick(4.7)
named.ArcanaCatalogueClose.scripts.OnClick();result(4);check(not pane:IsShown())
host.serviceTab="Affixes";host:ApplyServiceVisibility();check(not pane:IsShown() and not search:IsShown())
GameTooltip:Show();host:ApplyServiceVisibility();check(GameTooltip:IsShown()) -- Hidden catalogue must not close an unrelated equipment tooltip during affix sync.
result(4);check(not pane:IsShown())
host.serviceTab="Ascension";host:ApplyServiceVisibility();check(search:IsShown())
named.ArcanaAscensionBrowse.scripts.OnClick();tick(5.3)
host:Hide();check(not pane:IsShown());tick(10);check(not pane:IsShown())
host:Show();host.serviceTab="Ascension";host:ApplyServiceVisibility()
search:SetFocus()
local itemLink="|cff0070dd|Hitem:873:0:0:0:0:0:0:0:80|h[Staff of Jordan]|h|r"
check(ChatEdit_InsertLink(itemLink)==true and chatInsert==0 and search:GetText()=="Staff of Jordan" and search:HasFocus())
tick(11);check(sent[#sent][2]:match("\t873$"))
search:SetText("Staff of Jorda");tick(12);check(sent[#sent][2]:match("\tstaff of jorda$"))
search:ClearFocus();check(ChatEdit_InsertLink(itemLink)=="chat" and chatInsert==1)
search:SetFocus();check(ChatEdit_InsertLink("|Hspell:1|h[Spell]|h")=="chat" and chatInsert==2)
search:SetText("");check(search:HasFocus());search.scripts.OnEscapePressed();check(not search:HasFocus())
print("PASS: "..checks.." catalogue UI typing, spoof rejection, original results, original hover, opaque layers, direct equipment comparison, shift-click and focus, six-version comparison, cache and visibility checks")

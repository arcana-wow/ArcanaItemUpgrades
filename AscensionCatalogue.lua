local host, P = ArcanaItemUpgradesFrame, ArcanaAscensionCatalogueProtocol
if not host or not P then return end
local state=P.New()
state.serial=math.floor(GetTime()*1000)%1000000000
local selected,hovered,retryUntil,retryAt
local pane=CreateFrame("Frame","ArcanaAscensionCatalogue",host)
pane:SetPoint("TOPLEFT",19,-120);pane:SetPoint("BOTTOMRIGHT",-19,15)
pane:SetFrameLevel(host:GetFrameLevel()+20)
pane:EnableMouse(true)
pane:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
pane:SetBackdropColor(0.03,0.03,0.03,1);pane:Hide()
local search=CreateFrame("EditBox","ArcanaAscensionSearch",host,"InputBoxTemplate")
search:SetSize(225,22);search:SetPoint("TOPLEFT",167,-91)
search:SetAutoFocus(false);search:SetMaxLetters(80)
local placeholder=search:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
placeholder:SetPoint("LEFT",3,0);placeholder:SetText("Search items by name or ID")
local browse=CreateFrame("Button","ArcanaAscensionBrowse",host,"UIPanelButtonTemplate")
browse:SetSize(75,22);browse:SetPoint("TOPLEFT",403,-91);browse:SetText("Browse")
host.ServiceStatus:ClearAllPoints();host.ServiceStatus:SetPoint("TOPLEFT",23,-96);host.ServiceStatus:SetWidth(128)
local title=pane:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
title:SetPoint("TOPLEFT",12,-13);title:SetWidth(538);title:SetJustifyH("LEFT")
local message=pane:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
message:SetPoint("CENTER",0,0);message:SetWidth(490)
local footer=pane:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
footer:SetPoint("BOTTOM",15,19)
local function Button(name,text,x)
    local button=CreateFrame("Button",name,pane,"UIPanelButtonTemplate")
    button:SetSize(96,24);button:SetPoint("BOTTOMLEFT",x,10);button:SetText(text)
    return button
end
local back=Button("ArcanaCatalogueBack","My equipment",12)
local previous=Button("ArcanaCataloguePrevious","Previous",344)
local nextPage=Button("ArcanaCatalogueNext","Next",444)
local scroll=CreateFrame("ScrollFrame","ArcanaCatalogueComparisonScroll",pane,"UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",10,-36);scroll:SetPoint("BOTTOMRIGHT",-31,43)
local child=CreateFrame("Frame",nil,scroll);child:SetSize(514,1);scroll:SetScrollChild(child);scroll:Hide()
local probe=CreateFrame("GameTooltip","ArcanaCatalogueProbe",UIParent,"GameTooltipTemplate")
local rows,cards={},{}
local Render,Compare,Preview
local function Details(row) return P.Detail(state,row,GetTime()) end
local function SetPreview(tooltip,row,entry)
    local data=Details(row)
    if ArcanaAscensionSetPreview then ArcanaAscensionSetPreview(tooltip,data and (data[entry] or {}) or nil) end
end
Preview=function(button)
    if not button.row then return end
    local row=button.row
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(P.Link(row,P.Next(row)))
    SetPreview(GameTooltip,row,P.Next(row))
    GameTooltip:AddLine("Next Ascension - click to compare all versions",1,0.82,0,true)
    GameTooltip:Show()
end
local function TooltipLines(row,entry)
    probe:SetOwner(UIParent,"ANCHOR_NONE");probe:SetHyperlink(P.Link(row,entry))
    SetPreview(probe,row,entry)
    local lines={}
    for index=1,math.min(probe:NumLines(),100) do
        local left=_G["ArcanaCatalogueProbeTextLeft"..index]
        local right=_G["ArcanaCatalogueProbeTextRight"..index]
        local text=left and left:GetText()
        if text and text~="" then
            local r,g,b=left:GetTextColor()
            local other=right and right:GetText()
            lines[#lines+1]={text=text..(other and other~="" and ("   "..other) or ""),r=r,g=g,b=b}
        end
    end
    probe:Hide()
    return lines
end
Compare=function()
    if not selected then return end
    for _,row in ipairs(rows) do row:Hide() end
    message:SetText("");previous:Hide();nextPage:Hide();back:SetText("Results")
    title:SetText(selected.name.." - all available versions")
    footer:SetText(state.error or "Base item previews; personal Affixes and Tempering vary.")
    footer:ClearAllPoints();footer:SetPoint("BOTTOMLEFT",116,15);footer:SetWidth(432)
    scroll:Show()
    local versions={{entry=selected.source,label="Original (ilvl "..selected.ilvl..")"}}
    for index,entry in ipairs(selected.targets) do
        if entry>0 then versions[#versions+1]={entry=entry,label="Ascended - ilvl "..P.Levels[index]} end
    end
    local y,rowHeight,missing=0,0,false
    for index,version in ipairs(versions) do
        local card=cards[index]
        if not card then
            card=CreateFrame("Frame",nil,child);card:SetWidth(252);card.lines={}
            card:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
            card:SetBackdropColor(0.05,0.05,0.08,1)
            card.heading=card:CreateFontString(nil,"OVERLAY","GameFontNormal")
            card.heading:SetPoint("TOPLEFT",9,-10);card.heading:SetWidth(234);card.heading:SetJustifyH("LEFT")
            cards[index]=card
        end
        card:ClearAllPoints();card:SetPoint("TOPLEFT",(index-1)%2*262,-y)
        card.heading:SetText(version.label)
        local lines=TooltipLines(selected,version.entry)
        missing=not GetItemInfo(version.entry) or missing
        local height=34
        for lineIndex,line in ipairs(lines) do
            local label=card.lines[lineIndex]
            if not label then label=card:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");card.lines[lineIndex]=label end
            label:ClearAllPoints();label:SetPoint("TOPLEFT",9,-height);label:SetWidth(234)
            label:SetJustifyH("LEFT");label:SetTextColor(line.r,line.g,line.b)
            label:SetText(line.text);label:Show()
            height=height+math.max(12,label:GetStringHeight())+3
        end
        for lineIndex=#lines+1,#card.lines do card.lines[lineIndex]:Hide() end
        height=height+9;card:SetHeight(height);card:Show();rowHeight=math.max(rowHeight,height)
        if index%2==0 or index==#versions then y=y+rowHeight+10;rowHeight=0 end
    end
    for index=#versions+1,#cards do cards[index]:Hide() end
    child:SetHeight(math.max(1,y))
    if missing and GetTime()<(retryUntil or 0) then retryAt=GetTime()+0.5 end
end
Render=function()
    if not pane:IsShown() then return end
    if selected then Compare();return end
    scroll:Hide();previous:Show();nextPage:Show();back:SetText("My equipment")
    footer:ClearAllPoints();footer:SetPoint("BOTTOMLEFT",113,18);footer:SetWidth(226)
    title:SetText("Original items - hover to preview; click to compare all versions.")
    local result=state.result
    message:SetText(state.error or (not result and "Searching..." or result.total==0 and "No matching Ascension items." or ""))
    for index,button in ipairs(rows) do
        local row=result and result.rows[index]
        button.row=row
        if row then
            local color=ITEM_QUALITY_COLORS[row.quality]
            button.name:SetText(row.name);button.name:SetTextColor(color.r,color.g,color.b)
            button.level:SetText("ilvl "..row.ilvl);button:Show()
        else button:Hide() end
    end
    if result then
        footer:SetText("Page "..(result.page+1).." / "..math.max(1,math.ceil(result.total/20)).." ("..result.total.." items)")
    else footer:SetText("") end
    if result and result.page>0 then previous:Enable() else previous:Disable() end
    if result and (result.page+1)*20<result.total then nextPage:Enable() else nextPage:Disable() end
end
for index=1,20 do
    local button=CreateFrame("Button",nil,pane);button:SetSize(532,18);button:SetPoint("TOPLEFT",13,-36-(index-1)*19)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    button.name=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    button.name:SetPoint("LEFT",3,0);button.name:SetWidth(443);button.name:SetJustifyH("LEFT")
    button.level=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    button.level:SetPoint("RIGHT",-3,0)
    button:SetScript("OnEnter",function(self) hovered=self;Preview(self) end)
    button:SetScript("OnLeave",function(self)
        if hovered==self then hovered=nil;GameTooltip:Hide() end
        if self.row and not selected then P.Leave(state,self.row) end
    end)
    button:SetScript("OnClick",function(self)
        if not self.row then return end
        hovered=nil;GameTooltip:Hide();selected=self.row;retryUntil=GetTime()+5
        scroll:SetVerticalScroll(0);search:ClearFocus();Compare()
    end)
    rows[index]=button
end
local function Search(page)
    selected=nil;hovered=nil;GameTooltip:Hide();retryAt=nil
    P.Query(state,search:GetText(),GetTime(),page)
    pane:Show();Render()
end
search:SetScript("OnTextChanged",function(self)
    if self:GetText()=="" then placeholder:Show() else placeholder:Hide() end
    if host:IsShown() and host.serviceTab=="Ascension" then Search(0) end
end)
search:SetScript("OnEnterPressed",function(self) self:ClearFocus();Search(0) end)
search:SetScript("OnEscapePressed",function(self) self:ClearFocus();pane:Hide();P.Cancel(state) end)
browse:SetScript("OnClick",function() search:ClearFocus();Search(0) end)
back:SetScript("OnClick",function()
    hovered=nil;GameTooltip:Hide()
    if selected then selected=nil;Render() else pane:Hide();P.Cancel(state) end
end)
previous:SetScript("OnClick",function() if state.result and state.result.page>0 then Search(state.result.page-1) end end)
nextPage:SetScript("OnClick",function() if state.result and (state.result.page+1)*20<state.result.total then Search(state.result.page+1) end end)
local function Visibility()
    if host.serviceTab=="Ascension" then search:Show();browse:Show()
    else search:Hide();browse:Hide();pane:Hide();P.Cancel(state);search:ClearFocus() end
end
hooksecurefunc(host,"ApplyServiceVisibility",Visibility)
host:HookScript("OnHide",function() pane:Hide();P.Cancel(state);hovered=nil end)
local events=CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON");events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function(_,event,prefix,message,channel,sender)
    if event=="PLAYER_ENTERING_WORLD" then
        local serial=state.serial
        state=P.New();state.serial=serial;selected=nil;pane:Hide();return
    end
    if prefix~="AAS" or channel~="WHISPER" or sender~=UnitName("player") then return end
    if P.Receive(state,message) then
        Render()
        if hovered and hovered.row and pane:IsShown() then Preview(hovered) end
    end
end)
events:SetScript("OnUpdate",function()
    if not pane:IsShown() or not host:IsShown() then return end
    local request,changed=P.Tick(state,GetTime())
    if request then SendAddonMessage("AAS",request,"WHISPER",UnitName("player")) end
    if changed then Render() end
    if retryAt and GetTime()>=retryAt then retryAt=nil;Compare() end
end)
Visibility()

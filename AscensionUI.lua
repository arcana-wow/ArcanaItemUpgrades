local frame, P = ArcanaItemUpgradesFrame, ArcanaAscensionProtocol
if not frame or not P then return end
local snapshot, pending, paying = {}, nil, false
local deadline, lastSync = nil, -1
local tabs = {}
local explanations = {
    Tempering = "Improve your equipped item's stats by 5% per rank, up to 5 ranks.",
    Affixes = "Reroll an item's bonus stat using a Recalibration Sigil.",
    Ascension = "Ascend your equipment using the appropriate Ascension token. Requires level 80.",
}
local function TokenItemLink(token)
    local color=token==194704 and "ffff8000" or "ffa335ee"
    return "|c"..color.."|Hitem:"..token.."|h["..P.Names[token].." Ascension Token]|h|r"
end
local function Send(text) SendAddonMessage("AAS",text,"WHISPER",UnitName("player")) end
local function Sync()
    if GetTime()-lastSync<0.2 then return end
    lastSync=GetTime();deadline=lastSync+5;pending={};Send("SYNC")
end
local function Current(slot)
    local row=snapshot[slot or frame:GetSelectedEquipmentSlot()]
    local link=row and GetInventoryItemLink("player",row.slot+1)
    local entry=link and tonumber(link:match("item:(%d+)"))
    return row and entry==row.entry and row or nil
end
local details=CreateFrame("Frame","ArcanaAscensionInstruction",frame)
details:SetPoint("TOP",frame.ServiceEligibilityText,"BOTTOM",0,-12);details:SetSize(550,18)
local instruction=details:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
local tokenLink=CreateFrame("Button","ArcanaAscensionTokenLink",details)
tokenLink:SetHeight(18)
local tokenLabel=tokenLink:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
tokenLabel:SetPoint("CENTER")
local period=details:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
period:SetText(".");period:SetPoint("LEFT",tokenLink,"RIGHT",0,0)
tokenLink:SetScript("OnClick",function(self)
    if self.token then SetItemRef("item:"..self.token,self.link,"LeftButton") end
end)
local result=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
local ascend=CreateFrame("Button","ArcanaAscendButton",frame,"UIPanelButtonTemplate")
ascend:SetSize(190,26);ascend:SetText("Ascend Item")
local preview=CreateFrame("Button","ArcanaAscensionPreviewButton",frame,"UIPanelButtonTemplate")
preview:SetSize(190,22);preview:SetPoint("TOP",details,"BOTTOM",0,-8);preview:SetText("Preview ascended item")
ascend:SetPoint("TOP",preview,"BOTTOM",0,-6)
result:SetPoint("TOP",ascend,"BOTTOM",0,-42);result:SetWidth(550)
frame.AscensionButton=ascend
local compare=CreateFrame("CheckButton","ArcanaAscensionCompareItems",frame,"UICheckButtonTemplate")
compare:SetSize(24,24);compare:SetPoint("LEFT",preview,"RIGHT",6,0);compare:SetChecked(false)
local compareLabel=compare:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
compareLabel:SetPoint("LEFT",compare,"RIGHT",0,0);compareLabel:SetText("Compare items")
local nextTooltip=CreateFrame("GameTooltip","ArcanaAscensionNextTooltip",UIParent,"GameTooltipTemplate")
nextTooltip:SetClampedToScreen(true)
local previewing=false
local previewGuid,previewTarget
local function HidePreview()
    if previewing then GameTooltip:Hide() end
    previewing=false;nextTooltip:Hide()
end
local function PositionPair()
    local width=GameTooltip:GetWidth()+nextTooltip:GetWidth()+12
    local left=math.max(8,math.min(preview:GetCenter()-width/2,UIParent:GetWidth()-width-8))
    local bottom=math.max(8,math.min(preview:GetTop()+8,
        UIParent:GetHeight()-math.max(GameTooltip:GetHeight(),nextTooltip:GetHeight())-8))
    GameTooltip:ClearAllPoints();nextTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left,bottom)
    nextTooltip:SetPoint("TOPLEFT",GameTooltip,"TOPRIGHT",12,0)
end
local function ShowPreview()
    local row=Current()
    if not row or row.target==0 then HidePreview();return end
    previewing=true
    previewGuid=row.guid;previewTarget=row.target
    if compare:GetChecked() then
        -- Use the native equipment tooltip so the current copy includes its
        -- enchants, gems, affix and server-authoritative Tempering overlay.
        GameTooltip:SetOwner(preview,"ANCHOR_NONE")
        GameTooltip:SetInventoryItem("player",row.slot+1)
        nextTooltip:SetOwner(preview,"ANCHOR_NONE")
        nextTooltip:SetHyperlink("item:"..row.target)
        -- Centre the pair above the button and clamp the pair as a unit.
        PositionPair()
        GameTooltip:Show();nextTooltip:Show()
    else
        nextTooltip:Hide()
        GameTooltip:SetOwner(preview,"ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:"..row.target);GameTooltip:Show()
    end
end
preview:SetScript("OnEnter",function(self)
    ShowPreview()
end)
preview:SetScript("OnLeave",HidePreview)
preview:SetScript("OnHide",HidePreview)
compare:SetScript("OnClick",HidePreview)
local positionAt=0
preview:SetScript("OnUpdate",function()
    if previewing and compare:GetChecked() and GetTime()>=positionAt then
        positionAt=GetTime()+0.1
        -- Owned-item tooltip replies can change its dimensions after hover.
        -- Reposition without rebuilding or issuing another backend request.
        PositionPair()
    end
end)
local function Available(row)
    local inside=IsInInstance()
    return row and row.target>0 and row.count>0 and UnitLevel("player")==80 and
        not UnitIsDeadOrGhost("player") and not UnitAffectingCombat("player") and not inside and not paying and not pending
end
function frame:ApplyServiceVisibility()
    self:SetHeight(self.serviceTab=="Ascension" and 640 or self.serviceTab=="Affixes" and 558 or 532)
    if self.serviceTab=="Tempering" then self.TemperingButton:Show() else self.TemperingButton:Hide() end
    for _,control in ipairs(self.AffixControls or {}) do
        if self.serviceTab=="Affixes" then control:Show() else control:Hide() end
    end
    for _,control in ipairs({details,result,ascend,preview,compare}) do
        if self.serviceTab=="Ascension" then control:Show() else control:Hide() end
    end
    local row=Current()
    if previewing and (self.serviceTab~="Ascension" or not row or row.guid~=previewGuid or row.target~=previewTarget) then HidePreview() end
    tokenLink.token=nil
    instruction:ClearAllPoints()
    if row and row.target>0 then
        tokenLink.token=row.token
        tokenLink.link=TokenItemLink(row.token)
        instruction:SetText("This item can be ascended using ")
        tokenLabel:SetText(tokenLink.link)
        local width=tokenLabel:GetStringWidth()
        instruction:SetPoint("LEFT",details,"LEFT",(550-instruction:GetStringWidth()-width-period:GetStringWidth())/2,0)
        tokenLink:ClearAllPoints();tokenLink:SetPoint("LEFT",instruction,"RIGHT",0,0);tokenLink:SetWidth(width)
        tokenLink:Show();period:Show()
        preview:Enable()
    else
        instruction:SetPoint("CENTER")
        instruction:SetText(row and (row.ilvl>=284 and "This item is already at the Ascension cap." or "This item has no eligible Ascension upgrade.") or "Select an equipped item to see its next Ascension.")
        tokenLink:Hide();period:Hide()
        preview:Disable()
    end
    if Available(row) then ascend:Enable() else ascend:Disable() end
end
function frame:GetAscensionCatalogueEntry(slot)
    local row=Current(slot)
    -- The next template identifies the exact native suffix family. At the cap,
    -- the equipped Ascension template itself resolves that same family.
    return row and (row.target>0 and row.target or row.entry)
end
function frame:ServiceEligibility(selected,allowed,reason,maxRank)
    if not selected then return "Select an equipped item.",false end
    if not allowed then return reason,false end
    if self.serviceTab=="Ascension" then
        local row=Current()
        if not row or pending then return "Waiting for item details...",false end
        if row.ilvl>=284 then return "Maximum Ascension level reached (ilvl 284).",false end
        if row.target==0 then return "Unavailable for ascension.",false end
        if UnitLevel("player")~=80 then return "Ascension requires level 80.",false end
        return "Eligible for ascension to ilvl "..P.Levels[row.token],true
    elseif self.serviceTab=="Affixes" then
        local text,loading=self:GetAffixDescription(selected.slot)
        if loading then return "Loading bonus stat...",false end
        return text and "Eligible for recalibration" or "Unavailable for recalibration.",text~=nil
    end
    if selected.affixOnly or selected.rank==nil then return "Unavailable for tempering.",false end
    if selected.rank>=maxRank then return string.format("Maximum tempering rank reached (%d/%d).",maxRank,maxRank),false end
    return string.format("Eligible for tempering to rank %d/%d",selected.rank+1,maxRank),true
end
function frame:ServiceRowStatus(slot)
    if self.serviceTab=="Ascension" then
        local row=snapshot[slot.slot]
        return row and ("ilvl "..row.ilvl) or "Waiting..."
    elseif self.serviceTab=="Affixes" then
        if self.GetAffixDescription then
            local text,loading=self:GetAffixDescription(slot.slot)
            return text or (loading and "Loading..." or "No affix")
        end
        return "No affix"
    end
    return slot.affixOnly and "Unavailable" or string.format("%d/5",slot.rank or 0)
end
function frame:SetServiceTab(tab)
    if not explanations[tab] then return end
    self.serviceTab=tab
    self.ServiceSubtitle:SetText(explanations[tab])
    if ArcanaItemUpgradeSourceFrame then ArcanaItemUpgradeSourceFrame:Hide() end
    StaticPopup_Hide("ARCANA_AFFIX_CONFIRM");StaticPopup_Hide("ARCANA_ASCENSION_CONFIRM")
    StaticPopup_Hide("ARCANA_ITEM_UPGRADE_CONFIRM");StaticPopup_Hide("ARCANA_ITEM_UPGRADE_LEGENDARY_CONFIRM")
    for name,button in pairs(tabs) do if name==tab then button:Disable() else button:Enable() end end
    self:UpdateDisplay()
    if tab=="Ascension" then Sync() end
end
for i,name in ipairs({"Tempering","Affixes","Ascension"}) do
    local button=CreateFrame("Button","ArcanaUpgradeTab"..i,frame,"UIPanelButtonTemplate")
    button:SetSize(170,26);button:SetPoint("TOPLEFT",31+(i-1)*184,-47);button:SetText(name)
    button:SetScript("OnClick",function() frame:SetServiceTab(name) end);tabs[name]=button
end
StaticPopupDialogs.ARCANA_ASCENSION_CONFIRM={
    text="Ascend %s?\nConsumes one %s.",
    button1=ACCEPT,button2=CANCEL,timeout=0,whileDead=false,hideOnEscape=true,preferredIndex=3,
    OnAccept=function(self,row)
        local current=Current()
        if not row or not Available(current) or row.guid~=current.guid or row.entry~=current.entry or row.target~=current.target then Sync();return end
        paying=true;deadline=GetTime()+5;Send(P.Request(row));frame:ApplyServiceVisibility()
    end,
}
ascend:SetScript("OnClick",function()
    local row=Current()
    if Available(row) then
        local item=GetInventoryItemLink("player",row.slot+1).." to item level "..P.Levels[row.token]
        StaticPopup_Show("ARCANA_ASCENSION_CONFIRM",item,TokenItemLink(row.token),row)
    end
end)
local events=CreateFrame("Frame")
for _,event in ipairs({"CHAT_MSG_ADDON","PLAYER_EQUIPMENT_CHANGED","BAG_UPDATE","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(self,event,prefix,message,channel,sender)
    if event=="CHAT_MSG_ADDON" then
        if prefix=="AUI" and message=="END" and channel=="WHISPER" and sender==UnitName("player") then
            if frame:IsShown() and frame.serviceTab=="Ascension" then self.refreshAt=GetTime()+0.3 end
            return
        end
        if prefix~="AAS" or channel~="WHISPER" or sender~=UnitName("player") then return end
        local fields=P.Split(message)
        if fields[1]=="BEGIN" then pending={}
        elseif fields[1]=="ITEM" and pending then
            local row=P.Row(fields)
            if row then pending[row.slot]=row else pending.invalid=true end
        elseif fields[1]=="END" and pending then
            if not pending.invalid then snapshot=pending;frame.ascensionSlots=snapshot;paying=false end
            pending=nil;deadline=nil;frame:UpdateDisplay()
        elseif fields[1]=="RESULT" or fields[1]=="ERROR" then
            paying=false;result:SetText(fields[2] or "");frame:ApplyServiceVisibility()
            frame:RefreshTempering();frame:RefreshAffixes()
        end
    elseif event=="PLAYER_EQUIPMENT_CHANGED" or event=="BAG_UPDATE" then
        if event=="PLAYER_EQUIPMENT_CHANGED" then HidePreview() end
        if frame:IsShown() and frame.serviceTab=="Ascension" then self.refreshAt=GetTime()+0.3 end
    else frame:UpdateDisplay() end
end)
events:SetScript("OnUpdate",function(self)
    if self.refreshAt and GetTime()>=self.refreshAt then self.refreshAt=nil;Sync() end
    if deadline and GetTime()>=deadline then
        deadline=nil;pending=nil;paying=false;snapshot={};frame.ascensionSlots=snapshot
        result:SetText("No response from the server. Use Refresh to try again.");frame:UpdateDisplay()
    end
end)
frame:HookScript("OnShow",function() if frame.serviceTab=="Ascension" then Sync() end end)
frame:SetServiceTab("Tempering")

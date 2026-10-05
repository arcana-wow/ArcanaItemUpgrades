local frame, P = ArcanaItemUpgradesFrame, ArcanaAscensionProtocol
if not frame or not P then return end
local snapshot, pending, paying = {}, nil, false
local deadline, lastSync = nil, -1
local tabs = {}
local explanations = {
    Tempering = "Improve your equipped item's stats by 5% per rank, up to 5 ranks.",
    Affixes = "Replace an item's bonus stat using a Recalibration Sigil.",
    Ascension = "Raise item level to 200, 226, 245, 264, then 284. Requires level 80.",
}
local function Send(text) SendAddonMessage("AAS",text,"WHISPER",UnitName("player")) end
local function Sync()
    if GetTime()-lastSync<0.2 then return end
    lastSync=GetTime();deadline=lastSync+5;pending={};Send("SYNC")
end
local function Current()
    local row=snapshot[frame:GetSelectedEquipmentSlot()]
    local link=row and GetInventoryItemLink("player",row.slot+1)
    local entry=link and tonumber(link:match("item:(%d+)"))
    return row and entry==row.entry and row or nil
end
local details=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
details:SetPoint("BOTTOM",0,86);details:SetWidth(550);details:SetJustifyH("CENTER")
local result=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
result:SetPoint("BOTTOM",0,126);result:SetWidth(550)
local ascend=CreateFrame("Button","ArcanaAscendButton",frame,"UIPanelButtonTemplate")
ascend:SetSize(190,26);ascend:SetPoint("BOTTOM",0,23);ascend:SetText("Ascend Item")
local preview=CreateFrame("Button","ArcanaAscensionPreviewButton",frame,"UIPanelButtonTemplate")
preview:SetSize(190,22);preview:SetPoint("BOTTOM",0,54);preview:SetText("Preview ascended item")
preview:SetScript("OnEnter",function(self)
    local row=Current()
    if row and row.target>0 then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("item:"..row.target);GameTooltip:Show() end
end)
preview:SetScript("OnLeave",function() GameTooltip:Hide() end)
local function Available(row)
    local inside=IsInInstance()
    return row and row.target>0 and row.count>0 and UnitLevel("player")==80 and
        not UnitIsDeadOrGhost("player") and not UnitAffectingCombat("player") and not inside and not paying and not pending
end
function frame:ApplyServiceVisibility()
    if self.serviceTab=="Tempering" then self.TemperingButton:Show() else self.TemperingButton:Hide() end
    for _,control in ipairs(self.AffixControls or {}) do
        if self.serviceTab=="Affixes" then control:Show() else control:Hide() end
    end
    for _,control in ipairs({details,result,ascend,preview}) do
        if self.serviceTab=="Ascension" then control:Show() else control:Hide() end
    end
    local row=Current()
    if row and row.target>0 then
        details:SetText(string.format("Item level %d → %d   •   1 %s Ascension token (%d owned)\nKeeps Tempering, Affixes, enchants and compatible gems.",
            row.ilvl,P.Levels[row.token],P.Names[row.token],row.count))
        preview:Enable()
    else
        details:SetText(row and (row.ilvl>=284 and "This item is already at the Ascension cap." or "This item has no eligible Ascension upgrade.") or "Select an equipped item to see its next Ascension.")
        preview:Disable()
    end
    if Available(row) then ascend:Enable() else ascend:Disable() end
end
function frame:ServiceRowStatus(slot)
    if self.serviceTab=="Ascension" then
        local row=snapshot[slot.slot]
        return row and ("ilvl "..row.ilvl..(row.target>0 and (" → "..P.Levels[row.token]) or "")) or "Waiting..."
    elseif self.serviceTab=="Affixes" then return "Bonus stat" end
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
    text="Ascend %s to item level %s?\nConsumes one Ascension token. Existing upgrade progress is kept.",
    button1=ACCEPT,button2=CANCEL,timeout=0,whileDead=false,hideOnEscape=true,preferredIndex=3,
    OnAccept=function(self,row)
        local current=Current()
        if not row or not Available(current) or row.guid~=current.guid or row.entry~=current.entry or row.target~=current.target then Sync();return end
        paying=true;deadline=GetTime()+5;Send(P.Request(row));frame:ApplyServiceVisibility()
    end,
}
ascend:SetScript("OnClick",function()
    local row=Current()
    if Available(row) then StaticPopup_Show("ARCANA_ASCENSION_CONFIRM",GetInventoryItemLink("player",row.slot+1),P.Levels[row.token],row) end
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
        if frame:IsShown() and frame.serviceTab=="Ascension" then self.refreshAt=GetTime()+0.3 end
    else frame:ApplyServiceVisibility() end
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

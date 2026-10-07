local host,P=ArcanaItemUpgradesFrame,ArcanaRecyclingProtocol
if not host or not P then return end
local rows,selected,positions={},{},{}
local valid,ready,reason=false,false,"Waiting for the realm..."
local serial,generation,lastRequest=0,0,-1
local pending,quote,operation,drag,refreshAt,quoteAt
local buttons,pickerRows={},{}
local Render,Sync,Invalidate,OpenPicker,QueueQuote
local panel=CreateFrame("Frame","ArcanaRecyclingPanel",host)
panel:SetPoint("TOPLEFT",20,-120);panel:SetSize(560,400);panel:Hide()
local function Label(parent,text,x,y,width,font)
    local label=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    label:SetPoint("TOPLEFT",x,y);label:SetWidth(width);label:SetJustifyH("LEFT");label:SetText(text)
    return label
end
local instruction=Label(panel,"Drag gear into an empty slot, or click a slot to choose an item.",8,-2,544,"GameFontHighlightSmall")
local average=Label(panel,"Average ilvl: --",8,-204,544,"GameFontHighlight")
local description=Label(panel,table.concat({
    "• The item you receive will most likely be close to the average ilvl, sometimes higher or lower.",
    "• More PvP gear means better PvP odds. More PvE gear means better PvE odds.",
    "• Bonus items are also possible.",
    "• Recycling will also return you 50% of the total vendor value of all items.",
},"\n\n"),8,-229,544,"GameFontHighlightSmall")
local recycle=CreateFrame("Button","ArcanaRecycleButton",panel,"UIPanelButtonTemplate")
recycle:SetPoint("BOTTOM",0,2);recycle:SetSize(175,28);recycle:SetText("Recycle");recycle:Disable()
-- A separate opaque dialog and mouse shield prevent the underlying addon
-- from showing through or changing the selected batch during confirmation.
local confirmation=CreateFrame("Frame","ArcanaRecyclingConfirmation",UIParent)
confirmation:SetAllPoints(host);confirmation:SetFrameStrata("FULLSCREEN_DIALOG")
confirmation:EnableMouse(true);confirmation:EnableKeyboard(true);confirmation:Hide()
local dialog=CreateFrame("Frame","ArcanaRecycleConfirmDialog",confirmation)
dialog:SetPoint("CENTER");dialog:SetSize(520,330);dialog:EnableMouse(true);dialog:SetAlpha(1)
dialog:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
local background=dialog:CreateTexture(nil,"BACKGROUND")
background:SetAllPoints();background:SetTexture(0.025,0.025,0.035,1)
local confirmTitle=Label(dialog,"These 10 items will be permanently destroyed.",20,-20,480,"GameFontNormalLarge")
local confirmItems=Label(dialog,"",20,-62,480)
local confirmQuestion=Label(dialog,"Are you sure you want to proceed?",20,-260,480)
confirmQuestion:ClearAllPoints();confirmQuestion:SetPoint("BOTTOM",0,66);confirmQuestion:SetJustifyH("CENTER")
local accept=CreateFrame("Button","ArcanaRecycleConfirmAccept",dialog,"UIPanelButtonTemplate")
accept:SetPoint("BOTTOM",-110,22);accept:SetSize(200,26);accept:SetText("Recycle")
local cancel=CreateFrame("Button","ArcanaRecycleConfirmCancel",dialog,"UIPanelButtonTemplate")
cancel:SetPoint("BOTTOM",110,22);cancel:SetSize(200,26);cancel:SetText(CANCEL)
confirmation:SetScript("OnHide",function() confirmation.quoteId=nil end)
local function DismissConfirmation()
    confirmation:Hide()
    if quote and quote.expires<=GetTime() then Invalidate();QueueQuote() end
    Render()
end
cancel:SetScript("OnClick",DismissConfirmation)
-- Consume Escape here before CloseSpecialWindows closes the host addon too.
confirmation:SetScript("OnKeyDown",function(_,key) if key=="ESCAPE" then DismissConfirmation() end end)
local picker=CreateFrame("Frame","ArcanaRecyclingPicker",host)
picker:SetPoint("CENTER");picker:SetSize(520,355);picker:SetFrameStrata("FULLSCREEN_DIALOG");picker:EnableMouse(true)
picker:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
picker:SetBackdropColor(0.03,0.03,0.03,1);picker:Hide()
local pickerTitle=Label(picker,"Choose an item",18,-18,450,"GameFontNormalLarge")
local pickerEmpty=Label(picker,"No compatible unselected items in your bags.",18,-75,470)
local pickerClose=CreateFrame("Button",nil,picker,"UIPanelCloseButton");pickerClose:SetPoint("TOPRIGHT",-3,-3)
pickerClose:SetScript("OnClick",function() picker:Hide() end)
local scroll=CreateFrame("ScrollFrame","ArcanaRecyclingPickerScroll",picker,"FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",14,-52);scroll:SetPoint("BOTTOMRIGHT",-34,18)
local pickerIndex,pickerItems=nil,{}
local function Active() return host:IsShown() and host.serviceTab=="Recycle" end
local function LocalAllowed()
    return UnitLevel("player")==80 and not UnitIsDeadOrGhost("player") and not UnitAffectingCombat("player") and
        not IsInInstance() and not UnitCastingInfo("player") and not UnitChannelInfo("player")
end
local function NotifyError(message)
    if Active() and UIErrorsFrame then UIErrorsFrame:AddMessage(message,1,0.2,0.2) end
end
local function Request(kind,extra)
    serial=serial%2147483647+1;lastRequest=GetTime()
    pending={kind=kind,request=serial,deadline=GetTime()+5,selection=extra,generation=generation}
    SendAddonMessage("ARCY",kind.."\t"..serial..(extra and "\t"..extra or ""),"WHISPER",UnitName("player"))
    return pending
end
local function ClearOperation()
    operation=nil
    if ArcanaItemUpgradesDB then ArcanaItemUpgradesDB.recyclingPending=nil end
end
Invalidate=function()
    quote=nil;quoteAt=nil
    if pending and pending.kind=="QUOTE2" then pending=nil end
    confirmation:Hide()
end
Sync=function()
    if GetTime()-lastRequest<0.55 then refreshAt=lastRequest+0.55;return end
    Invalidate();picker:Hide();drag=nil
    if operation then Request("STATUS",operation)
    else valid=false;Request("SYNC") end
    Render()
end
local function ItemName(row)
    local link=GetContainerItemLink(row.bag,row.slot)
    return link or GetItemInfo(row.entry) or ("Item "..row.entry)
end
QueueQuote=function()
    if valid and not operation and P.Selection(selected,rows) then quoteAt=GetTime()+0.55 end
end
local function Changed()
    Invalidate();QueueQuote();Render()
end
local function Add(index,guid)
    if not valid or not ready or operation or not LocalAllowed() then return false end
    if not P.Add(selected,rows,index,guid) then reason="Choose an empty slot and an item not already selected.";NotifyError(reason);Render();return false end
    picker:Hide();Changed();return true
end
local function Drop(index)
    local kind,entry=GetCursorInfo()
    if kind~="item" then reason="Drag an eligible item from one of your carried bags.";NotifyError(reason);Render();return end
    local origin=drag
    if not origin or origin.generation~=generation or not valid or not rows[origin.guid] or
        rows[origin.guid].entry~=entry or positions[origin.bag..":"..origin.slot]~=origin.guid then
        reason="That item's bag position could not be verified. Refresh and drag it again.";NotifyError(reason);Render();return
    end
    if Add(index,origin.guid) then ClearCursor();drag=nil end
end
for index=1,10 do
    local slot=index
    local button=CreateFrame("Button","ArcanaRecycleSlot"..index,panel)
    button:SetSize(102,78);button:SetPoint("TOPLEFT",8+((index-1)%5)*110,-30-math.floor((index-1)/5)*81)
    button:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    button:SetBackdropColor(0.07,0.07,0.1,1)
    button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("TOP",0,-6);button.icon:SetSize(30,30)
    button.label=Label(button,"+",5,-40,92,"GameFontHighlightSmall");button.label:SetJustifyH("CENTER");button.label:SetHeight(33)
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button:SetScript("OnReceiveDrag",function() Drop(slot) end)
    button:SetScript("OnClick",function(_,mouse)
        if operation then return end
        if mouse=="RightButton" and selected[slot] then selected[slot]=nil;Changed()
        elseif GetCursorInfo() then Drop(slot)
        elseif not selected[slot] then OpenPicker(slot) end
    end)
    button:SetScript("OnEnter",function(self)
        local row=valid and rows[selected[slot]]
        if row then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetBagItem(row.bag,row.slot);GameTooltip:Show() end
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    buttons[slot]=button
end
local function RenderPicker()
    pickerItems={}
    local used={};for i=1,10 do if selected[i] then used[selected[i]]=true end end
    for guid,row in pairs(rows) do if not used[guid] then pickerItems[#pickerItems+1]=row end end
    table.sort(pickerItems,function(a,b) return a.bag==b.bag and a.slot<b.slot or a.bag<b.bag end)
    FauxScrollFrame_Update(scroll,#pickerItems,10,27)
    local offset=FauxScrollFrame_GetOffset(scroll)
    if #pickerItems==0 then pickerEmpty:Show() else pickerEmpty:Hide() end
    for index,button in ipairs(pickerRows) do
        local row=pickerItems[index+offset];button.row=row
        if row then
            button.icon:SetTexture(GetItemIcon(row.entry));button.label:SetText(ItemName(row))
            button.value:SetText("ilvl "..row.ilvl..(row.pvp==1 and " PvP " or " PvE ")..P.Money(row.price));button:Show()
        else button:Hide() end
    end
end
for index=1,10 do
    local button=CreateFrame("Button",nil,picker)
    button:SetSize(472,26);button:SetPoint("TOPLEFT",18,-54-(index-1)*27)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("LEFT");button.icon:SetSize(22,22)
    button.label=Label(button,"",28,-1,246,"GameFontHighlightSmall")
    button.value=Label(button,"",278,-5,194,"GameFontHighlightSmall");button.value:SetJustifyH("RIGHT")
    button:SetScript("OnClick",function(self) if self.row then Add(pickerIndex,self.row.guid) end end)
    button:SetScript("OnEnter",function(self)
        if self.row and valid then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetBagItem(self.row.bag,self.row.slot);GameTooltip:Show() end
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    pickerRows[index]=button
end
scroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,27,RenderPicker) end)
OpenPicker=function(index)
    if not valid or not ready or operation or not LocalAllowed() then reason="Refresh in a safe location before choosing items.";NotifyError(reason);Render();return end
    pickerIndex=index;pickerTitle:SetText("Choose an item for slot "..index)
    scroll.offset=0;RenderPicker();picker:Show()
end
Render=function()
    local totals=valid and P.Totals(selected,rows)
    average:SetText("Average ilvl: "..(totals and totals.count>0 and string.format("%.1f",totals.levels/totals.count) or "--"))
    for index,button in ipairs(buttons) do
        local row=rows[selected[index]]
        button.icon:SetTexture(row and GetItemIcon(row.entry) or "Interface\\Buttons\\UI-PlusButton-Up")
        button.label:SetText(row and (GetItemInfo(row.entry) or "Item "..row.entry) or "Click to choose")
    end
    local enabled=Active() and valid and ready and LocalAllowed() and quote and quote.expires>GetTime() and not operation and not pending
    if enabled then recycle:Enable() else recycle:Disable() end
    if Active() then host.ServiceStatus:SetText("");host.ServiceStatus:Hide() end
end
host.RenderRecycling=Render
function host:RefreshRecycling() Sync() end
function host:RecyclingTabChanged(tab)
    picker:Hide();Invalidate();drag=nil
    if not operation then pending=nil end
    if tab=="Recycle" then panel:Show();Sync() else panel:Hide();host.ServiceStatus:Show();refreshAt=nil end
end
local function CanRecycle()
    return quote and valid and ready and Active() and LocalAllowed() and not pending and not operation and quote.expires>GetTime()
end
accept:SetScript("OnClick",function()
    local id=confirmation.quoteId
    if not confirmation:IsShown() or not CanRecycle() or quote.id~=id then return end
    operation=id;ArcanaItemUpgradesDB=ArcanaItemUpgradesDB or {};ArcanaItemUpgradesDB.recyclingPending=id
    Invalidate();Request("COMMIT",id);Render()
end)
recycle:SetScript("OnClick",function()
    if not CanRecycle() then return end
    local names={};for i=1,10 do names[i]=ItemName(rows[selected[i]]) end
    confirmItems:SetText(table.concat(names,"\n"))
    dialog:SetHeight(math.max(330,confirmItems:GetStringHeight()+160))
    confirmation.quoteId=quote.id;confirmation:Show()
end)
-- Secure post-hooks preserve native bag controls and also support bag addons that
-- use the standard PickupContainerItem API. A cursor link alone is never identity.
hooksecurefunc("PickupContainerItem",function(bag,slot)
    drag=nil
    local kind,entry=GetCursorInfo()
    local guid=valid and positions[tostring(bag)..":"..tostring(slot)]
    if kind=="item" and guid and rows[guid].entry==entry then drag={guid=guid,bag=bag,slot=slot,generation=generation} end
end)
hooksecurefunc("ClearCursor",function() drag=nil end)
local events=CreateFrame("Frame","ArcanaRecyclingEvents")
for _,event in ipairs({"CHAT_MSG_ADDON","BAG_UPDATE","PLAYER_EQUIPMENT_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","ZONE_CHANGED_NEW_AREA","GET_ITEM_INFO_RECEIVED","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,prefix,message,channel,sender)
    if event:find("^UNIT_SPELLCAST_") and prefix~="player" then return end
    if event=="CHAT_MSG_ADDON" then
        if prefix~="ARCY" or channel~="WHISPER" or sender~=UnitName("player") or not pending then return end
        local f=P.Split(message)
        if tonumber(f[2])~=pending.request then return end
        if pending.kind=="SYNC" and f[1]=="BEGIN" then
            pending.rows={};pending.positions={};pending.count=0;pending.invalid=#f~=5 or f[3]~="2" or (f[4]~="0" and f[4]~="1")
            pending.ready=f[4]=="1";pending.reason=f[5] or ""
        elseif pending.kind=="SYNC" and f[1]=="ITEM" and pending.rows then
            local row=P.Row(f)
            local key=row and (row.bag..":"..row.slot)
            pending.count=pending.count+1
            if not row or pending.count>160 or pending.rows[row.guid] or pending.positions[key] then pending.invalid=true
            else pending.rows[row.guid]=row;pending.positions[key]=row.guid end
        elseif pending.kind=="SYNC" and f[1]=="END" then
            if #f~=2 or not pending.rows or pending.invalid then valid=false;reason="Invalid inventory response. Refresh to try again.";NotifyError(reason)
            else
                rows=pending.rows;positions=pending.positions;ready=pending.ready;reason=pending.reason;valid=true;generation=generation+1
                for i=1,10 do if selected[i] and not rows[selected[i]] then selected[i]=nil end end
                if reason=="" then reason="Select ten items to recycle." end
            end
            pending=nil;Changed()
        elseif pending.kind=="QUOTE2" and f[1]=="QUOTE" then
            if pending.generation==generation and pending.selection==P.Selection(selected,rows) and not pending.quote then
                pending.quote=P.Quote(f,selected,rows,GetTime())
            else pending.invalid=true end
            if not pending.quote then pending.invalid=true end
        elseif pending.kind=="QUOTE2" and f[1]=="GEAR" then
            if not P.Gear(pending.quote,f) then pending.invalid=true end
        elseif pending.kind=="QUOTE2" and f[1]=="QEND" then
            if not pending.invalid and pending.generation==generation and pending.selection==P.Selection(selected,rows) then
                quote=P.Complete(pending.quote,f,GetTime())
            end
            pending=nil
            if not quote then NotifyError("Invalid quote. Refresh to try again.") end
        elseif (pending.kind=="COMMIT" or pending.kind=="STATUS") and f[1]=="RESULT" and #f==5 and f[3]==operation and
            P.Integer(f[4],4294967295) and tonumber(f[4])>0 and (f[5]=="0" or f[5]=="1") then
            ClearOperation();pending=nil;selected={};Invalidate();valid=false
            reason="Arcana Salvage Satchel created. Right-click it in your bags to collect the saved contents."
            if f[5]=="1" then reason="This recycling batch has already been collected." end
            refreshAt=GetTime()+1
        elseif pending.kind=="STATUS" and f[1]=="MISSING" and #f==3 and f[3]==operation then
            ClearOperation();pending=nil;Invalidate();reason="No saved recycle was found. Refresh and review your items.";refreshAt=GetTime()+0.6
        elseif f[1]=="ERROR" and #f==3 then
            pending=nil;Invalidate();reason=f[3];NotifyError(reason)
            if operation then refreshAt=GetTime()+5 end
        end
        Render();return
    end
    if event=="GET_ITEM_INFO_RECEIVED" then if Active() then Render();if picker:IsShown() then RenderPicker() end end;return end
    if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LOGOUT" then
        selected={};rows={};positions={};pending=nil;valid=false;Invalidate();picker:Hide();drag=nil
        if event=="PLAYER_ENTERING_WORLD" then
            operation=ArcanaItemUpgradesDB and ArcanaItemUpgradesDB.recyclingPending
            if not P.Id(operation) then ClearOperation() end
            if operation or Active() then refreshAt=GetTime()+1 end
        end
    elseif event=="BAG_UPDATE" or event=="PLAYER_EQUIPMENT_CHANGED" then
        valid=false;Invalidate();picker:Hide();drag=nil
        if pending and pending.kind~="COMMIT" and pending.kind~="STATUS" then pending=nil end
        if Active() or operation then refreshAt=GetTime()+0.55 end
    else
        Invalidate();picker:Hide();drag=nil
        if Active() then refreshAt=GetTime()+0.55 end
    end
    Render()
end)
events:SetScript("OnUpdate",function()
    local now=GetTime()
    if quote and now>=quote.expires then Invalidate();QueueQuote();Render() end
    if pending and now>=pending.deadline then
        pending=nil;Invalidate();valid=false;reason="No response from the realm. Use Refresh to check again."
        NotifyError(reason)
        if operation then refreshAt=now+1 end
        Render()
    end
    if refreshAt and now>=refreshAt and not pending then refreshAt=nil;Sync() end
    if quoteAt and now>=quoteAt and not pending and not operation and Active() and valid and ready and LocalAllowed() then
        if now-lastRequest<0.55 then quoteAt=lastRequest+0.55;return end
        quoteAt=nil;local selection=P.Selection(selected,rows)
        if selection then Request("QUOTE2",selection);Render() end
    end
end)
host:HookScript("OnHide",function() picker:Hide();Invalidate();drag=nil;if not operation then pending=nil;refreshAt=nil end end)
host:HookScript("OnShow",function() if host.serviceTab=="Recycle" then panel:Show();Sync() end end)

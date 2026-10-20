local host,P,catalogue=ArcanaItemUpgradesFrame,ArcanaHeirloomProtocol,ArcanaHeirloomCatalogue
if not host or not P or not catalogue then return end
local progress,originals,filtered={},{},{}
local selected,quote,pending,operation,snapshot,refreshAt
local serial,lastRequest=0,-1
local mode,source,original="Progressing",0,0
local itemClass,subclass,slotFilter
local valid,reason=false,"Loading your account's heirlooms..."
local Render,Sync,Invalidate
local panel=CreateFrame("Frame","ArcanaHeirloomPanel",host)
panel:SetPoint("TOPLEFT",20,-120);panel:SetSize(560,520);panel:Hide()
local function Label(parent,text,x,y,width,font)
    local label=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    label:SetPoint("TOPLEFT",x,y);label:SetWidth(width);label:SetJustifyH("LEFT");label:SetText(text)
    return label
end
local function Button(name,parent,text,x,y,width,callback)
    local button=CreateFrame("Button",name,parent,"UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT",x,y);button:SetSize(width,24);button:SetText(text)
    button:SetScript("OnClick",callback)
    return button
end
local function Active() return host:IsShown() and host.serviceTab=="Heirloom" end
local function Allowed()
    local _,kind=IsInInstance()
    return not UnitIsDeadOrGhost("player") and not UnitAffectingCombat("player") and
        not UnitCastingInfo("player") and not UnitChannelInfo("player") and kind~="pvp" and kind~="arena"
end
local function Key() return (GetRealmName() or "")..":"..UnitName("player") end
local function SaveOperation(id)
    operation=id
    ArcanaItemUpgradesDB=ArcanaItemUpgradesDB or {}
    ArcanaItemUpgradesDB.heirloomPending=ArcanaItemUpgradesDB.heirloomPending or {}
    ArcanaItemUpgradesDB.heirloomPending[Key()]=id
end
local function Request(kind,extra,selection)
    serial=serial%2147483647+1;lastRequest=GetTime()
    pending={request=serial,kind=kind,deadline=GetTime()+7,selection=selection}
    if selection then selection.request=serial end
    SendAddonMessage("ARHL",kind.."\t"..serial..(extra and "\t"..extra or ""),"WHISPER",UnitName("player"))
end
local progressing=Button("ArcanaHeirloomProgressing",panel,"Progressing",0,0,125,function()
    mode="Progressing";Invalidate();Render()
end)
local unlocked=Button("ArcanaHeirloomUnlocked",panel,"Unlocked",130,0,125,function()
    mode="Unlocked";Invalidate();Render()
end)
local search=CreateFrame("EditBox","ArcanaHeirloomSearch",panel,"InputBoxTemplate")
search:SetPoint("TOPLEFT",278,-2);search:SetSize(272,22);search:SetAutoFocus(false);search:SetMaxLetters(80)
search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged",function() if Invalidate then Invalidate();Render() end end)
Label(panel,"Search all eligible heirlooms",278,-27,275,"GameFontHighlightSmall")
local typeDrop=CreateFrame("Frame","ArcanaHeirloomType",panel,"UIDropDownMenuTemplate")
typeDrop:SetPoint("TOPLEFT",-16,-44);UIDropDownMenu_SetWidth(typeDrop,240)
local slotDrop=CreateFrame("Frame","ArcanaHeirloomSlot",panel,"UIDropDownMenuTemplate")
slotDrop:SetPoint("TOPLEFT",265,-44);UIDropDownMenu_SetWidth(slotDrop,240)
local types={{"All armor and weapons"},{"Cloth",4,1},{"Leather",4,2},{"Mail",4,3},{"Plate",4,4},
    {"Shield",4,6},{"Jewellery, cloaks and trinkets",4,0},{"Relics",4,nil},
    {"One-hand axe",2,0},{"Two-hand axe",2,1},{"Bow",2,2},{"Gun",2,3},{"One-hand mace",2,4},
    {"Two-hand mace",2,5},{"Polearm",2,6},{"One-hand sword",2,7},{"Two-hand sword",2,8},
    {"Staff",2,10},{"Fist weapon",2,13},{"Dagger",2,15},{"Thrown",2,16},{"Crossbow",2,18},{"Wand",2,19}}
local slots={{"All slots"},{"Head",1},{"Neck",2},{"Shoulders",3},{"Chest",5},{"Waist",6},{"Legs",7},
    {"Feet",8},{"Wrists",9},{"Hands",10},{"Finger",11},{"Trinket",12},{"One-hand",13},
    {"Shield",14},{"Ranged",15},{"Cloak",16},{"Two-hand",17},{"Robe",20},{"Main hand",21},
    {"Off hand",22},{"Held off-hand",23},{"Thrown",25},{"Ranged weapon",26},{"Relic",28}}
UIDropDownMenu_Initialize(typeDrop,function()
    for _,definition in ipairs(types) do
        local row=definition
        local info=UIDropDownMenu_CreateInfo();info.text=row[1]
        info.func=function()
            itemClass,subclass=row[2],row[3]
            if row[1]=="Relics" then slotFilter=28;UIDropDownMenu_SetText(slotDrop,"Relic") end
            UIDropDownMenu_SetText(typeDrop,row[1]);Invalidate();Render()
        end
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_Initialize(slotDrop,function()
    for _,definition in ipairs(slots) do
        local row=definition
        local info=UIDropDownMenu_CreateInfo();info.text=row[1]
        info.func=function() slotFilter=row[2];UIDropDownMenu_SetText(slotDrop,row[1]);Invalidate();Render() end
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetText(typeDrop,"All armor and weapons");UIDropDownMenu_SetText(slotDrop,"All slots")
local scroll=CreateFrame("ScrollFrame","ArcanaHeirloomScroll",panel,"FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",0,-83);scroll:SetPoint("BOTTOMRIGHT",-24,248)
local buttons={}
for index=1,8 do
    local button=Button("ArcanaHeirloomRow"..index,panel,"",0,-83-(index-1)*24,532,function(self)
        selected=selected~=self.entry and self.entry or nil;original=0;Invalidate();Render()
    end)
    button:SetScript("OnEnter",function(self)
        if self.entry then
            ArcanaHeirloomPreview(self,self.entry)
        end
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    buttons[index]=button
end
scroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,24,Render) end)
local title=Label(panel,"Select a heirloom to view its details.",0,-285,550,"GameFontNormalLarge")
local origin=Button("ArcanaHeirloomOrigin",panel,"View drop sources",0,-313,170,function(self)
    if not selected then return end
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:ClearLines()
    GameTooltip:AddLine(catalogue[selected].name,0.9,0.8,0.5)
    for text in catalogue[selected].origin:gmatch("[^;]+") do GameTooltip:AddLine(text,1,1,1,true) end
    GameTooltip:Show()
end)
origin:SetScript("OnLeave",function() GameTooltip:Hide() end)
local stateLabel=Label(panel,"",188,-317,365)
local material=CreateFrame("Frame","ArcanaHeirloomMaterial",panel,"UIDropDownMenuTemplate")
material:SetPoint("TOPLEFT",-16,-349);UIDropDownMenu_SetWidth(material,270)
local quantity=CreateFrame("EditBox","ArcanaHeirloomQuantity",panel,"InputBoxTemplate")
quantity:SetPoint("TOPLEFT",332,-351);quantity:SetSize(58,22);quantity:SetNumeric(true);quantity:SetAutoFocus(false)
quantity:SetMaxLetters(3);quantity:SetText("1")
local singleQuantity=Label(panel,"1",332,-351,58)
singleQuantity:Hide()
Label(panel,"Amount",398,-356,100,"GameFontHighlightSmall")
quantity:SetScript("OnTextChanged",function() if Invalidate then Invalidate();Render() end end)
quantity:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
local originalDrop=CreateFrame("Frame","ArcanaHeirloomOriginal",panel,"UIDropDownMenuTemplate")
originalDrop:SetPoint("TOPLEFT",-16,-383);UIDropDownMenu_SetWidth(originalDrop,510)
UIDropDownMenu_SetText(originalDrop,"Choose an original from your bags")
UIDropDownMenu_Initialize(material,function()
    for index,definition in ipairs(P.Materials) do
        local choice,name=index-1,definition.name
        local info=UIDropDownMenu_CreateInfo();info.text=name
        info.func=function()
            source=choice;original=0
            if source==5 then quantity:SetText("1") end
            UIDropDownMenu_SetText(material,name);Invalidate();Render()
        end
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetText(material,P.Materials[1].name)
UIDropDownMenu_Initialize(originalDrop,function()
    local choices={}
    for guid,row in pairs(originals) do if row.family==selected then choices[#choices+1]=guid end end
    table.sort(choices)
    for _,guid in ipairs(choices) do
        local choice,row=guid,originals[guid]
        local link=GetContainerItemLink(row.bag,row.slot)
        local info=UIDropDownMenu_CreateInfo()
        info.text=(link or GetItemInfo(row.entry) or ("Item "..row.entry)).." — bag "..row.bag..", slot "..row.slot
        local text=info.text
        info.func=function() original=choice;UIDropDownMenu_SetText(originalDrop,text);Invalidate();Render() end
        UIDropDownMenu_AddButton(info)
    end
end)
local estimate=Label(panel,"",0,-421,550,"GameFontHighlightSmall")
local forge=Button("ArcanaHeirloomForge",panel,"Forge",175,-456,200,function()
    if not selected or pending or operation or not valid or not Allowed() then return end
    local state=progress[selected]
    if not state then return end
    local count=P.Number(quantity:GetText(),100)
    if state.progress==100 then
        Request("CONJURE",tostring(selected),{kind=2,family=selected,quantity=1,source=0,original=0})
    elseif count and P.Preview(state.progress,source,count) and (source~=5 or originals[original]) then
        local chosen=source==5 and original or 0
        Request("QUOTE",table.concat({selected,source,count,chosen},"\t"),
            {kind=1,family=selected,quantity=count,source=source,original=chosen})
    end
    Render()
end)
local status=Label(panel,"",0,-490,550,"GameFontHighlightSmall")
local confirmation=CreateFrame("Frame","ArcanaHeirloomConfirmation",UIParent)
confirmation:SetAllPoints(host);confirmation:SetFrameStrata("FULLSCREEN_DIALOG")
confirmation:EnableMouse(true);confirmation:EnableKeyboard(true);confirmation:Hide()
local dialog=CreateFrame("Frame","ArcanaHeirloomConfirmDialog",confirmation)
dialog:SetPoint("CENTER");dialog:SetSize(510,260);dialog:EnableMouse(true)
dialog:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=16,edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
dialog:SetBackdropColor(0.02,0.02,0.03,1)
local question=Label(dialog,"",24,-24,462)
local accept=Button("ArcanaHeirloomConfirmAccept",dialog,"Forge",35,-210,210,function()
    if not quote or quote.expires<=GetTime() or pending or operation or not Allowed() then Invalidate();Render();return end
    local id=quote.id;SaveOperation(id);Invalidate();Request("COMMIT",id);reason="Saving your heirloom...";Render()
end)
Button("ArcanaHeirloomConfirmCancel",dialog,CANCEL,265,-210,210,function() Invalidate();Render() end)
confirmation:SetScript("OnKeyDown",function(_,key) if key=="ESCAPE" then Invalidate();Render() end end)
Invalidate=function()
    quote=nil;confirmation:Hide()
    if pending and (pending.kind=="QUOTE" or pending.kind=="CONJURE") then pending=nil end
end
Sync=function()
    if GetTime()-lastRequest<0.6 then refreshAt=lastRequest+0.6;return end
    Invalidate();snapshot=nil;refreshAt=nil
    if operation then Request("STATUS",operation) else valid=false;Request("SYNC") end
    Render()
end
Render=function()
    if mode=="Progressing" then progressing:Disable();unlocked:Enable() else progressing:Enable();unlocked:Disable() end
    filtered=P.Filter(catalogue,progress,mode,search:GetText(),itemClass,subclass,slotFilter)
    FauxScrollFrame_Update(scroll,#filtered,8,24)
    local offset=FauxScrollFrame_GetOffset(scroll)
    for index,button in ipairs(buttons) do
        local entry=filtered[index+offset];button.entry=entry
        if entry then
            local state=progress[entry]
            local suffix=state and (state.progress==100 and "Unlocked" or state.progress.."%") or "Preview"
            button:SetText((selected==entry and "▼ " or "").."|cffe6cc80"..catalogue[entry].name.."|r  — "..suffix)
            button:Show()
        else button:Hide() end
    end
    local item=selected and catalogue[selected]
    local state=item and progress[selected]
    title:SetText(item and item.name or "Select a heirloom to view its details.")
    stateLabel:SetText(state and (state.progress==100 and "Unlocked account-wide" or "Unlock progress: "..state.progress.."%") or
        (item and "Obtain an original to begin at 0%." or ""))
    for _,control in ipairs({origin,stateLabel}) do if item then control:Show() else control:Hide() end end
    local progressingItem=state and state.progress<100
    for _,control in ipairs({material,quantity}) do if progressingItem then control:Show() else control:Hide() end end
    if progressingItem and source==5 then
        originalDrop:Show();quantity:ClearFocus();quantity:Hide();singleQuantity:Show()
    else
        originalDrop:Hide();singleQuantity:Hide()
        if progressingItem then quantity:Show() else quantity:Hide() end
    end
    local count=P.Number(quantity:GetText(),100)
    local low,high
    if progressingItem and count then low,high=P.Preview(state.progress,source,count) end
    estimate:SetText(low and ("Potential progress: +"..low.."–"..high.."%."..
        (source==5 and " The selected original will be destroyed." or " Unused materials remain when you reach 100%.")) or
        (state and state.progress==100 and "Conjure a permanent, unique copy for this character. Free." or ""))
    forge:SetText(state and state.progress==100 and "Conjure" or "Forge")
    local can=state and valid and not pending and not operation and Allowed() and
        (state.progress==100 or (low and (source~=5 or originals[original] and originals[original].family==selected)))
    if can then forge:Enable() else forge:Disable() end
    status:SetText(reason)
end
function host:RenderHeirlooms() Render() end
function host:RefreshHeirlooms() Sync() end
function host:HeirloomTabChanged(tab)
    Invalidate()
    if tab=="Heirloom" then panel:Show();Sync() else panel:Hide() end
end
local events=CreateFrame("Frame","ArcanaHeirloomEvents")
for _,event in ipairs({"CHAT_MSG_ADDON","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","BAG_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,prefix,message,channel,sender)
    if event=="CHAT_MSG_ADDON" then
        if prefix~="ARHL" or channel~="WHISPER" or sender~=UnitName("player") then return end
        local fields=P.Split(message)
        if fields[1]=="CHANGED" then if Active() then refreshAt=GetTime()+0.7 end;return end
        if not pending or tonumber(fields[2])~=pending.request then return end
        if fields[1]=="BEGIN" and pending.kind=="SYNC" then
            snapshot=P.Begin(fields,pending.request)
        elseif fields[1]=="ROW" or fields[1]=="ORIGINAL" then
            if not P.Append(snapshot,fields,catalogue) then snapshot=nil end
        elseif fields[1]=="END" and pending.kind=="SYNC" then
            if P.Complete(snapshot,fields) then
                progress,originals=snapshot.rows,snapshot.originals;valid=true;reason=""
            else valid=false;reason="The collection response was incomplete. Refresh to try again." end
            pending=nil;snapshot=nil
        elseif fields[1]=="QUOTE" and pending.selection then
            quote=P.Quote(fields,pending.selection,GetTime());pending=nil
            if quote and selected==quote.family and Active() and Allowed() then
                local name=catalogue[quote.family].name
                local cost=quote.source==5 and "Permanently destroy the selected original item" or
                    ("Use up to "..quote.quantity.." × "..P.Materials[quote.source+1].name)
                question:SetText(quote.kind==2 and ("Conjure "..name.."?\n\nFree, permanent and unique to this character.") or
                    (name.."\n\n"..cost..".\n\nGain "..quote.minimum.."–"..quote.maximum..
                    "% unlock progress.\nUnused units remain when the heirloom reaches 100%."))
                accept:SetText(quote.kind==2 and "Conjure" or "Forge");confirmation:Show()
            else Invalidate();reason="The confirmation changed. Please try again." end
        elseif P.Done(fields,catalogue) and (pending.kind=="COMMIT" or pending.kind=="STATUS") then
            SaveOperation(nil);pending=nil;valid=false;Invalidate();reason="Heirloom saved.";refreshAt=GetTime()+0.65
        elseif fields[1]=="MISSING" and #fields==2 and pending.kind=="STATUS" then
            SaveOperation(nil);pending=nil;valid=false;reason="No payment was saved. You can request a new confirmation."
            refreshAt=GetTime()+0.7
        elseif fields[1]=="ERROR" and #fields==3 then
            local kind=pending.kind;pending=nil;Invalidate();reason=fields[3]
            if kind=="COMMIT" then refreshAt=GetTime()+1
            elseif kind=="STATUS" then refreshAt=GetTime()+5 end
        end
        Render();return
    end
    Invalidate()
    if event=="PLAYER_ENTERING_WORLD" then
        progress,originals={},{};valid=false;pending=nil
        operation=ArcanaItemUpgradesDB and ArcanaItemUpgradesDB.heirloomPending and ArcanaItemUpgradesDB.heirloomPending[Key()]
        if not P.Id(operation) then operation=nil end
    elseif event=="PLAYER_LOGOUT" then pending=nil;return
    elseif event=="BAG_UPDATE" or event=="PLAYER_EQUIPMENT_CHANGED" then valid=false end
    if Active() or operation then refreshAt=GetTime()+0.7 end
    Render()
end)
events:SetScript("OnUpdate",function()
    local now=GetTime()
    if quote and now>=quote.expires then Invalidate();reason="Confirmation expired.";Render() end
    if pending and now>=pending.deadline then
        pending=nil;Invalidate();valid=false;reason="No response from the realm. Refresh to check again."
        if operation then refreshAt=now+1 end
        Render()
    end
    if refreshAt and now>=refreshAt and not pending then Sync() end
end)
host:HookScript("OnHide",function() panel:Hide();Invalidate();if not operation then pending=nil;refreshAt=nil end end)
host:HookScript("OnShow",function() if host.serviceTab=="Heirloom" then panel:Show();Sync() end end)

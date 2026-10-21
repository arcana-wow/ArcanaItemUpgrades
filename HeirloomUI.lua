local host,P,catalogue=ArcanaItemUpgradesFrame,ArcanaHeirloomProtocol,ArcanaHeirloomCatalogue
if not host or not P or not catalogue then return end
local progress,originals,filtered={},{},{}
local selected,quote,pending,operation,snapshot,refreshAt
local serial,lastRequest=0,-1
local mode,source,original="Progressing",0,0
local itemClass,subclass,slotFilter,filterName
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
local function ResetScroll()
    local frame=_G["ArcanaHeirloomScroll"]
    if frame then FauxScrollFrame_SetOffset(frame,0) end
end
local progressing=Button("ArcanaHeirloomProgressing",panel,"Progressing",0,0,125,function()
    mode="Progressing";ResetScroll();Invalidate();Render()
end)
local unlocked=Button("ArcanaHeirloomUnlocked",panel,"Unlocked",130,0,125,function()
    mode="Unlocked";ResetScroll();Invalidate();Render()
end)
local search=CreateFrame("EditBox","ArcanaHeirloomSearch",panel,"InputBoxTemplate")
search:SetPoint("TOPLEFT",278,-2);search:SetSize(272,22);search:SetAutoFocus(false);search:SetMaxLetters(80)
search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged",function() if Invalidate then ResetScroll();Invalidate();Render() end end)
Label(panel,"Search all eligible heirlooms",278,-27,275,"GameFontHighlightSmall")
local filter=CreateFrame("Frame","ArcanaHeirloomFilter",panel,"UIDropDownMenuTemplate")
filter:SetPoint("TOPLEFT",-16,-44);UIDropDownMenu_SetWidth(filter,240)
local filterSummary=Label(panel,"All items",278,-53,210,"GameFontHighlightSmall")
local function ChooseFilter(name,kind,sub,slot)
    filterName,itemClass,subclass,slotFilter=name,kind,sub,slot
    UIDropDownMenu_SetText(filter,"Filter: "..name)
    filterSummary:SetText(name)
    ResetScroll()
    Invalidate();Render()
end
local clearFilter=Button("ArcanaHeirloomClearFilter",panel,"Clear",490,-47,60,function()
    ChooseFilter("All items")
end)
local filterGroups={
    {"Armor",{{"All armor",4,"armor"},{"Cloth",4,1},{"Leather",4,2},{"Mail",4,3},{"Plate",4,4},
        {"Head",4,"armor",1},{"Shoulders",4,"armor",3},{"Chest",4,"armor","chest"},
        {"Wrists",4,"armor",9},{"Hands",4,"armor",10},{"Waist",4,"armor",6},
        {"Legs",4,"armor",7},{"Feet",4,"armor",8}}},
    {"Weapons",{{"All weapons",2},{"One-hand axes",2,0},{"Two-hand axes",2,1},{"Bows",2,2},
        {"Guns",2,3},{"One-hand maces",2,4},{"Two-hand maces",2,5},{"Polearms",2,6},
        {"One-hand swords",2,7},{"Two-hand swords",2,8},{"Staves",2,10},{"Fist weapons",2,13},
        {"Daggers",2,15},{"Thrown",2,16},{"Crossbows",2,18},{"Wands",2,19}}},
    {"Accessories",{{"Necks",4,nil,2},{"Rings",4,nil,11},{"Trinkets",4,nil,12},
        {"Cloaks",4,nil,16},{"Shields",4,6},{"Held off-hands",4,nil,23},{"Relics",4,nil,28}}},
}
UIDropDownMenu_Initialize(filter,function(_,level)
    level=level or 1
    local function AddChoice(row)
        local info=UIDropDownMenu_CreateInfo();info.text=row[1]
        info.checked=filterName==row[1]
        info.func=function()
            local name,kind,sub,slot=row[1],row[2],row[3],row[4]
            if kind==4 and (sub=="armor" or type(sub)=="number" and sub>=1 and sub<=4) and name~="All armor" then
                if slot and itemClass==4 and type(subclass)=="number" and subclass>=1 and subclass<=4 then sub=subclass end
                if not slot and itemClass==4 and slotFilter and (subclass=="armor" or type(subclass)=="number" and subclass>=1 and subclass<=4) then slot=slotFilter end
                if slot and type(sub)=="number" then
                    local materialNames={"Cloth","Leather","Mail","Plate"}
                    local slotNames={[1]="Head",[3]="Shoulders",chest="Chest",[9]="Wrists",[10]="Hands",[6]="Waist",[7]="Legs",[8]="Feet"}
                    name=materialNames[sub].." / "..slotNames[slot]
                end
            end
            ChooseFilter(name,kind,sub,slot);CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info,level)
    end
    if level==1 then
        AddChoice({"All items"})
        for index,group in ipairs(filterGroups) do
            local info=UIDropDownMenu_CreateInfo();info.text=group[1]
            info.hasArrow=true;info.notCheckable=true;info.value=index
            UIDropDownMenu_AddButton(info,level)
        end
    else
        local group=filterGroups[UIDROPDOWNMENU_MENU_VALUE]
        if group then for _,row in ipairs(group[2]) do AddChoice(row) end end
    end
end)
UIDropDownMenu_SetText(filter,"Filter: All items")
local scroll=CreateFrame("ScrollFrame","ArcanaHeirloomScroll",panel,"FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",0,-83);scroll:SetPoint("BOTTOMRIGHT",-24,248)
local listBackdrop=CreateFrame("Frame",nil,panel)
listBackdrop:SetPoint("TOPLEFT",0,-81);listBackdrop:SetSize(556,198)
listBackdrop:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,
    insets={left=3,right=3,top=3,bottom=3}})
listBackdrop:SetBackdropColor(0.03,0.03,0.03,0.92)
local buttons={}
for index=1,8 do
    local button=CreateFrame("Button","ArcanaHeirloomRow"..index,listBackdrop)
    button:SetPoint("TOPLEFT",8,-3-(index-1)*24);button:SetSize(520,24)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetSize(18,18);button.icon:SetPoint("LEFT",1,0)
    button.name=Label(button,"",26,-5,385,"GameFontHighlightSmall");button.name:SetHeight(16)
    button.progress=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    button.progress:SetPoint("RIGHT",-5,0);button.progress:SetWidth(95);button.progress:SetJustifyH("RIGHT")
    button:SetScript("OnClick",function(self)
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
local stateLabel=Label(panel,"",0,-317,550)
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
            local _,_,_,_,_,_,_,_,_,texture=GetItemInfo(entry)
            if not texture then _,_,_,_,_,_,_,_,_,texture=GetItemInfo(catalogue[entry].source) end
            button.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.name:SetText("|cffe6cc80"..catalogue[entry].name.."|r")
            button.progress:SetText(suffix)
            if selected==entry then button:LockHighlight() else button:UnlockHighlight() end
            button:Show()
        else button:Hide() end
    end
    local item=selected and catalogue[selected]
    local state=item and progress[selected]
    title:SetText(item and item.name or "Select a heirloom to view its details.")
    stateLabel:SetText(state and (state.progress==100 and "Unlocked account-wide" or "Unlock progress: "..state.progress.."%") or
        (item and "Obtain an original to begin at 0%." or ""))
    if item then stateLabel:Show() else stateLabel:Hide() end
    if itemClass or subclass or slotFilter then clearFilter:Enable() else clearFilter:Disable() end
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

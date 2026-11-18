-- Native ItemSet.dbc describes the original tier. Ask the realm which one
-- threshold is active, including mixed-tier sets and inspected characters.
local tooltip, serial, cache = GameTooltip, 0, {}
local view, rendering = nil, false
local probe=CreateFrame("GameTooltip","ArcanaSetSpellTooltip",UIParent,"GameTooltipTemplate")
local function Description(spell)
    probe:SetOwner(UIParent,"ANCHOR_NONE")
    probe:SetHyperlink("spell:"..spell)
    local text={}
    for i=2,probe:NumLines() do
        local line=_G["ArcanaSetSpellTooltipTextLeft"..i]
        local value=line and line:GetText()
        if value and value~="" then text[#text+1]=value end
    end
    probe:Hide()
    return #text>0 and table.concat(text," ") or (GetSpellInfo(spell) or "Set bonus")
end
-- These released preview spells require more distinct same-tier pieces than exist.
local previewFallbacks = {
    [203888] = {51274, 0},
    [203889] = {51274, 0},
    [203890] = {51274, 0},
    [203891] = {51274, 0},
    [203892] = {51274, 0},
    [203933] = {41685, 0},
    [203934] = {41685, 0},
    [203935] = {41685, 0},
    [203936] = {41685, 0},
    [203937] = {41685, 0},
    [204188] = {41733, 0},
    [204189] = {41733, 0},
    [204190] = {41733, 0},
    [204191] = {41733, 0},
    [204192] = {41733, 0},
    [204193] = {41732, 0},
    [204194] = {41732, 0},
    [204195] = {41732, 0},
    [204196] = {41732, 0},
    [204197] = {41732, 0},
    [204203] = {41730, 0},
    [204204] = {41730, 0},
    [204205] = {41730, 0},
    [204206] = {41730, 0},
    [204207] = {41730, 0},
    [204283] = {55596, 0},
    [204284] = {55596, 0},
    [204285] = {55596, 0},
    [204286] = {55596, 0},
    [204287] = {55596, 0},
    [204483] = {51225, 0},
    [204484] = {51225, 0},
    [204485] = {51225, 0},
    [204486] = {51225, 0},
    [204487] = {51225, 0},
    [204488] = {55564, 0},
    [204489] = {55564, 0},
    [204490] = {55564, 0},
    [204491] = {55564, 0},
    [204492] = {55564, 0},
    [204826] = {61633, 0},
    [204827] = {61633, 0},
    [204828] = {61633, 0},
    [204829] = {61633, 0},
    [204830] = {61633, 0},
    [205196] = {51263, 0},
    [205197] = {51263, 0},
    [205198] = {51263, 0},
    [205199] = {51263, 0},
    [205200] = {51263, 0},
}
local function Render(rows, target)
    local tooltip = target or tooltip
    if #rows==0 then return end
    local native={}
    for i=1,tooltip:NumLines() do
        local line=_G[tooltip:GetName().."TextLeft"..i]
        local text=line and line:GetText()
        if text and (text:match("^%(%d+%) Set:") or text:match("^Set:")) then
            native[#native+1]=line
        elseif text then
            local name,total=text:match("^(.-) %(%d+/(%d+)%)$")
            if name then line:SetText(name.." ("..rows[1].count.."/"..total..")") end
        end
    end
    for i,row in ipairs(rows) do
        local fallback = target and previewFallbacks[row.spell]
        local spell = fallback and fallback[1] or row.spell
        local label = ""
        if fallback then
            label = fallback[2] > 0 and (" (reachable at item level "..fallback[2]..")")
                or " (native bonus with a mixed set)"
        end
        local text="("..row.required..") Set: "..Description(spell)..label
        local r,g,b=0.5,0.5,0.5
        if row.active then r,g,b=0,1,0 end
        if native[i] then native[i]:SetText(text);native[i]:SetTextColor(r,g,b)
        else tooltip:AddLine(text,r,g,b,true) end
    end
    for i=#rows+1,#native do native[i]:SetText("") end
    tooltip:Show()
end
-- Catalogue previews describe a complete set at the selected tier. They must
-- not inherit the current player's equipped set count or active bonus color.
function ArcanaAscensionSetPreview(target, rows)
    if not rows then
        for index=1,target:NumLines() do
            local line=_G[target:GetName().."TextLeft"..index]
            local text=line and line:GetText()
            if text and (text:match("^%(%d+%) Set:") or text:match("^Set:")) then
                line:SetText("Set bonus: loading preview...");line:SetTextColor(0.5,0.5,0.5)
            end
        end
        return
    end
    Render(rows, target)
end
local function Current(v)
    return v and tooltip:IsShown() and tooltip:GetOwner()==v.owner and
        GetInventoryItemLink(v.unit,v.slot)==v.link and UnitGUID(v.unit)==v.guid
end
hooksecurefunc(tooltip,"SetInventoryItem",function(_,unit,slot)
    if rendering or slot<1 or slot>19 then return end
    local link=GetInventoryItemLink(unit,slot)
    local guid=UnitGUID(unit)
    local entry=link and tonumber(link:match("item:(%d+)"))
    if entry and ArcanaHeirloomCatalogue and ArcanaHeirloomCatalogue[entry] then view=nil;return end
    if not entry or not guid then view=nil;return end
    local key=guid..":"..slot..":"..link
    local size=0
    for oldKey,row in pairs(cache) do
        if GetTime()>=row.expires then cache[oldKey]=nil else size=size+1 end
    end
    if size>=64 and not cache[key] then cache={} end
    local row=cache[key]
    if not row or GetTime()>=row.expires then
        serial=serial+1
        row={id=serial,expires=GetTime()+5,building=nil};cache[key]=row
        SendAddonMessage("AAS",table.concat({"SETS",serial,tonumber(guid:sub(-8),16),slot-1,entry},"\t"),"WHISPER",UnitName("player"))
    end
    view={unit=unit,slot=slot,guid=guid,entry=entry,link=link,owner=tooltip:GetOwner(),row=row}
    if row.data then Render(row.data) end
end)
tooltip:HookScript("OnHide",function() if not rendering then view=nil end end)
tooltip:HookScript("OnTooltipCleared",function() if not rendering then view=nil end end)
local events=CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON");events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function(_,event,prefix,message,channel,sender)
    if event~="CHAT_MSG_ADDON" then cache={};return end
    if prefix~="AAS" or channel~="WHISPER" or sender~=UnitName("player") then return end
    local f=ArcanaAscensionProtocol.Split(message)
    local id=tonumber(f[2]);local row
    for _,candidate in pairs(cache) do if candidate.id==id then row=candidate;break end end
    if not row or GetTime()>=row.expires then return end
    if f[1]=="SETSBEGIN" then row.building={}
    elseif f[1]=="SET" and row.building and #row.building<8 then
        local set,count,required,active,spell=tonumber(f[3]),tonumber(f[4]),tonumber(f[5]),tonumber(f[6]),tonumber(f[7])
        if #f~=7 or not set or not count or not required or not spell or spell<1 or required<1 or required>8 or
            count<1 or count>19 or set%1~=0 or count%1~=0 or required%1~=0 or spell%1~=0 or
            (active~=0 and active~=1) then row.invalid=true;return end
        row.building[#row.building+1]={set=set,count=count,required=required,active=active==1,spell=spell}
    elseif f[1]=="SETSEND" and row.building and not row.invalid then
        row.data=row.building;row.building=nil
        if Current(view) and view.row==row then
            local saved=view
            rendering=true;tooltip:SetInventoryItem(saved.unit,saved.slot);Render(row.data);rendering=false
            view=saved
        end
    end
end)

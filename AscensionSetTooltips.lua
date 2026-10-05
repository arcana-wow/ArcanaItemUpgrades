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
local function Render(rows)
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
        local text="("..row.required..") Set: "..Description(row.spell)
        local r,g,b=0.5,0.5,0.5
        if row.active then r,g,b=0,1,0 end
        if native[i] then native[i]:SetText(text);native[i]:SetTextColor(r,g,b)
        else tooltip:AddLine(text,r,g,b,true) end
    end
    for i=#rows+1,#native do native[i]:SetText("") end
    tooltip:Show()
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

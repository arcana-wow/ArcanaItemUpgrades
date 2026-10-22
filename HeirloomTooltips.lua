-- Item queries carry scaled equipment stats. Spell.dbc is immutable, so replace
-- its level-80 proc text with descriptions generated from the same server curves.
local D=ArcanaHeirloomEffects
if not D then return end
local function Entry(link) return link and tonumber(link:match("item:(%d+)")) end
local function Description(spell,level)
    local row=D.spells[spell]
    return row and D.text[row[#row==1 and 1 or level]]
end
local function Plain(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("%s+"," "):match("^%s*(.-)%s*$")
end
-- Rating stats also begin with "Equip:". Identify the actual native spell
-- description through a private spell tooltip instead of consuming those rows
-- by position. This also preserves unrelated enchant/affix/addon text.
local probe=CreateFrame("GameTooltip","ArcanaHeirloomSpellTooltip",UIParent,"GameTooltipTemplate")
local nativeCache={}
local itemProbe=CreateFrame("GameTooltip","ArcanaHeirloomNativeItemTooltip",UIParent,"GameTooltipTemplate")
local itemCache={}
local function NativeDescriptions(spell)
    if nativeCache[spell] then return nativeCache[spell] end
    local descriptions,lines={},{}
    probe:SetOwner(UIParent,"ANCHOR_NONE")
    if pcall(probe.SetHyperlink,probe,"spell:"..spell) then
        for index=2,math.min(32,probe:NumLines()) do
            local line=_G[probe:GetName().."TextLeft"..index]
            local text=Plain(line and line:GetText())
            if text~="" then lines[#lines+1]=text end
        end
        -- A description can occupy multiple native font rows. Other spell
        -- metadata is harmless: only exact item-effect text can match it.
        for first=1,#lines do
            local text=""
            for last=first,#lines do
                text=text=="" and lines[last] or text.." "..lines[last]
                descriptions[text]=true
            end
        end
    end
    probe:Hide()
    if next(descriptions) then nativeCache[spell]=descriptions end
    return descriptions
end
local function SetCount(set,unit)
    if not unit then return 0 end
    local members,seen,count={},{},0
    for _,entry in ipairs(set.items) do members[entry]=true end
    for slot=1,19 do
        local entry=Entry(GetInventoryItemLink(unit,slot))
        if entry and members[entry] and not seen[entry] then seen[entry]=true;count=count+1 end
    end
    return count
end
local prefixes={[0]="Use: ",[1]="Equip: ",[2]="Chance on hit: "}
-- Native item effects follow native rating/stat rows. Read their actual item
-- wording from an undecorated tooltip, rather than guessing from spell tooltips
-- (which can use different wording for the same spell).
local function NativeEffects(link,entry,level,effects)
    local key=entry..":"..level
    if itemCache[key] then return itemCache[key] end
    itemProbe:SetOwner(UIParent,"ANCHOR_NONE")
    local groups={}
    if pcall(itemProbe.SetHyperlink,itemProbe,link) then
        for index=2,itemProbe:NumLines() do
            local line=_G[itemProbe:GetName().."TextLeft"..index]
            local text=Plain(line and line:GetText())
            for _,prefix in pairs(prefixes) do
                if text:sub(1,#prefix)==prefix then
                    groups[prefix]=groups[prefix] or {}
                    table.insert(groups[prefix],text)
                end
            end
        end
    end
    itemProbe:Hide()
    local result,offsets={},{}
    for index=#effects,1,-1 do
        local effect=effects[index]
        local group=groups[effect.prefix] or {}
        local offset=offsets[effect.prefix] or 0
        if #group<=offset then return {} end -- Do not cache incomplete item queries.
        result[index]=group[#group-offset]
        offsets[effect.prefix]=offset+1
    end
    itemCache[key]=result
    return result
end
function ArcanaRenderHeirloomTooltip(tooltip,unit)
    local _,link=tooltip:GetItem()
    local entry=Entry(link)
    local item=entry and D.items[entry]
    if not item and not (entry and ArcanaHeirloomCatalogue and ArcanaHeirloomCatalogue[entry]) then return end
    item=item or {effects={}}
    -- The native item cache is scoped to the viewer's level, including when
    -- inspecting another character. Keep equipment and effect previews at the
    -- same level; the server still applies combat values at the wearer's level.
    local level=math.max(1,math.min(80,UnitLevel("player") or 1))
    local key=tostring(entry)..":"..level..":"..tostring(unit)
    tooltip.arcanaHeirloomText=key
    local effects,bonuses={},{}
    for _,effect in ipairs(item.effects) do
        local text=Description(effect[2],level)
        if text and text~="" then
            local prefix=prefixes[effect[1]] or "Effect: "
            effects[#effects+1]={prefix=prefix,text=prefix..text,spell=effect[2]}
        end
    end
    local native=NativeEffects(link,entry,level,effects)
    local set=D.sets[item.set]
    local count=set and SetCount(set,unit) or 0
    if set then
        for _,bonus in ipairs(set.bonuses) do
            local text=Description(bonus[2],level)
            if text then bonuses[#bonuses+1]={text="("..bonus[1]..") Set: "..text,active=count>=bonus[1]} end
        end
    end
    local setIndex=0
    local previewText="Requires level 1 to 80 ("..level..")"
    local previewShown=false
    for index=1,tooltip:NumLines() do
        local line=_G[tooltip:GetName().."TextLeft"..index]
        local text=line and Plain(line:GetText())
        if text and (text:match("^Heirloom preview: level %d+%.") or text:match("^Requires level 1 to 80 %(%d+%)$") or text=="Requires Level 1") then
            line:SetText(previewText);previewShown=true
        elseif text and (text:match("^Equip:") or text:match("^Use:") or text:match("^Chance on hit:")) then
            for effectIndex,effect in ipairs(effects) do
                if not effect.seen and text:sub(1,#effect.prefix)==effect.prefix and
                    (text==Plain(effect.text) or text==native[effectIndex] or NativeDescriptions(effect.spell)[text:sub(#effect.prefix+1)]) then
                    line:SetText(effect.text);line:SetTextColor(0,1,0)
                    effect.seen=true
                    break
                end
            end
        elseif text and (text:match("^%(%d+%) Set:") or text:match("^Set:")) then
            setIndex=setIndex+1
            local bonus=bonuses[setIndex]
            line:SetText(bonus and bonus.text or "")
            if bonus and bonus.active then line:SetTextColor(0,1,0) else line:SetTextColor(0.5,0.5,0.5) end
        elseif set and text then
            local name,total=text:match("^(.-) %(%d+/(%d+)%)$")
            if name then line:SetText(name.." ("..count.."/"..total..")") end
        end
    end
    for _,effect in ipairs(effects) do
        if not effect.seen then tooltip:AddLine(effect.text,0,1,0,true) end
    end
    for index=setIndex+1,#bonuses do
        local bonus=bonuses[index]
        tooltip:AddLine(bonus.text,bonus.active and 0 or 0.5,bonus.active and 1 or 0.5,bonus.active and 0 or 0.5,true)
    end
    if not previewShown then tooltip:AddLine(previewText,1,1,1,true) end
    tooltip:Show()
end
local tooltip=GameTooltip
for _,frame in ipairs({GameTooltip,ItemRefTooltip,ShoppingTooltip1,ShoppingTooltip2}) do
    frame:HookScript("OnTooltipCleared",function(self) self.arcanaHeirloomText=nil end)
    frame:HookScript("OnTooltipSetItem",function(self) ArcanaRenderHeirloomTooltip(self,self.arcanaHeirloomUnit) end)
    hooksecurefunc(frame,"SetHyperlink",function(self) self.arcanaHeirloomUnit=nil;ArcanaRenderHeirloomTooltip(self,nil) end)
    hooksecurefunc(frame,"SetBagItem",function(self) self.arcanaHeirloomUnit="player";ArcanaRenderHeirloomTooltip(self,"player") end)
    hooksecurefunc(frame,"SetInventoryItem",function(self,unit) self.arcanaHeirloomUnit=unit;ArcanaRenderHeirloomTooltip(self,unit) end)
end

-- A preview is shown only after the server has refreshed that entry for this
-- viewer's level. The ordered acknowledgement follows its item-query packet.
-- Cache successful refreshes per level and coalesce fast hover changes locally.
local preview,sequence,nextRequest=nil,0,0
local refreshed={}
local function ShowPreview()
    if not preview or not tooltip:IsShown() or tooltip:GetOwner()~=preview.owner then return end
    if refreshed[preview.entry]~=UnitLevel("player") then return end
    tooltip:SetHyperlink("item:"..preview.entry..":0:0:0:0:0:0:0")
    tooltip:Show()
    preview=nil
end
local function RequestPreview()
    if not preview or preview.request or GetTime()<nextRequest then return end
    sequence=sequence%2147483647+1;nextRequest=GetTime()+0.35
    preview.request=sequence
    SendAddonMessage("ARHL","PREVIEW\t"..sequence.."\t"..preview.entry,"WHISPER",UnitName("player"))
end
function ArcanaHeirloomPreview(owner,entry)
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    if refreshed[entry]==UnitLevel("player") then
        preview=nil
        GameTooltip:SetHyperlink("item:"..entry..":0:0:0:0:0:0:0");GameTooltip:Show();return
    end
    GameTooltip:ClearLines();GameTooltip:AddLine("Loading heirloom...",1,1,1);GameTooltip:Show()
    preview={owner=owner,entry=entry,expires=GetTime()+5}
    RequestPreview()
end
local events=CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent",function(_,event,entry,message,channel,sender)
    if event=="PLAYER_LEVEL_UP" then
        preview=nil;refreshed={};nativeCache={};itemCache={};return
    end
    if event=="GET_ITEM_INFO_RECEIVED" then
        if entry then itemCache[entry..":"..UnitLevel("player")]=nil end
        return
    end
    if entry~="ARHL" or channel~="WHISPER" or sender~=UnitName("player") then return end
    local request,item,level=message:match("^PREVIEW\t(%d+)\t(%d+)\t(%d+)$")
    if not preview or tonumber(request)~=preview.request or tonumber(item)~=preview.entry or
        tonumber(level)~=UnitLevel("player") or GetTime()>preview.expires then return end
    refreshed[preview.entry]=tonumber(level)
    itemCache[preview.entry..":"..level]=nil
    ShowPreview()
end)
events:SetScript("OnUpdate",function()
    if not preview then return end
    if not tooltip:IsShown() or tooltip:GetOwner()~=preview.owner then preview=nil;return end
    if GetTime()>preview.expires then
        tooltip:ClearLines();tooltip:AddLine("Preview unavailable. Hover again to retry.",1,0.3,0.3)
        preview=nil;return
    end
    RequestPreview()
end)

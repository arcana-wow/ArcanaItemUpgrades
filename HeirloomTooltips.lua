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
    nativeCache[spell]=descriptions
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
function ArcanaRenderHeirloomTooltip(tooltip,unit)
    local _,link=tooltip:GetItem()
    local entry=Entry(link)
    local item=entry and D.items[entry]
    if not item then return end
    -- The native item cache is scoped to the viewer's level, including when
    -- inspecting another character. Keep equipment and effect previews at the
    -- same level; the server still applies combat values at the wearer's level.
    local level=math.max(1,math.min(80,UnitLevel("player") or 1))
    local key=tostring(entry)..":"..level..":"..tostring(unit)
    if tooltip.arcanaHeirloomText==key then return end
    tooltip.arcanaHeirloomText=key
    local effects,bonuses={},{}
    for _,effect in ipairs(item.effects) do
        local text=Description(effect[2],level)
        if text and text~="" then
            local prefix=prefixes[effect[1]] or "Effect: "
            effects[#effects+1]={prefix=prefix,text=prefix..text,spell=effect[2]}
        end
    end
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
            for _,effect in ipairs(effects) do
                if not effect.seen and text:sub(1,#effect.prefix)==effect.prefix and
                    (text==Plain(effect.text) or NativeDescriptions(effect.spell)[text:sub(#effect.prefix+1)]) then
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
tooltip:HookScript("OnTooltipCleared",function(self) self.arcanaHeirloomText=nil end)
hooksecurefunc(tooltip,"SetHyperlink",function() ArcanaRenderHeirloomTooltip(tooltip,nil) end)
hooksecurefunc(tooltip,"SetBagItem",function() ArcanaRenderHeirloomTooltip(tooltip,"player") end)
hooksecurefunc(tooltip,"SetInventoryItem",function(_,unit) ArcanaRenderHeirloomTooltip(tooltip,unit) end)

-- Preview queries refresh the client's item cache for the viewer's level.
-- A hover waits for the matching response; late responses never steal another
-- tooltip or disturb Forge's outstanding confirmation/request.
local preview,sequence,nextRequest=nil,0,0
function ArcanaHeirloomPreview(owner,entry)
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:"..entry..":0:0:0:0:0:0:0")
    GameTooltip:Show()
    preview={owner=owner,entry=entry,expires=GetTime()+3}
    if GetTime()>=nextRequest then
        sequence=sequence%2147483647+1;nextRequest=GetTime()+0.3
        SendAddonMessage("ARHL","PREVIEW\t"..sequence.."\t"..entry,"WHISPER",UnitName("player"))
    end
end
local events=CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent",function(_,event,entry)
    if event=="PLAYER_LEVEL_UP" then
        preview=nil;nativeCache={};tooltip.arcanaHeirloomText=nil;return
    end
    if not preview or entry~=preview.entry or GetTime()>preview.expires or
        not tooltip:IsShown() or tooltip:GetOwner()~=preview.owner then return end
    local _,link=tooltip:GetItem()
    if Entry(link)~=entry then return end
    preview=nil
    tooltip:SetHyperlink("item:"..entry..":0:0:0:0:0:0:0")
end)

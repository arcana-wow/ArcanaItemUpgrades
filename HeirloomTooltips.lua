-- Item queries carry scaled equipment stats. Spell.dbc is immutable, so replace
-- its level-80 proc text with descriptions generated from the same server curves.
local D=ArcanaHeirloomEffects
if not D then return end
local function Entry(link) return link and tonumber(link:match("item:(%d+)")) end
local function Description(spell,level)
    local row=D.spells[spell]
    return row and D.text[row[#row==1 and 1 or level]]
end
local function Plain(text) return (text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") end
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
    local level=math.max(1,math.min(80,UnitLevel(unit or "player") or 1))
    local key=tostring(entry)..":"..level..":"..tostring(unit)
    if tooltip.arcanaHeirloomText==key then return end
    tooltip.arcanaHeirloomText=key
    local effects,bonuses={},{}
    for _,effect in ipairs(item.effects) do
        local text=Description(effect[2],level)
        if text and text~="" then effects[#effects+1]=(prefixes[effect[1]] or "Effect: ")..text end
    end
    local set=D.sets[item.set]
    local count=set and SetCount(set,unit) or 0
    if set then
        for _,bonus in ipairs(set.bonuses) do
            local text=Description(bonus[2],level)
            if text then bonuses[#bonuses+1]={text="("..bonus[1]..") Set: "..text,active=count>=bonus[1]} end
        end
    end
    local effectIndex,setIndex=0,0
    for index=1,tooltip:NumLines() do
        local line=_G[tooltip:GetName().."TextLeft"..index]
        local text=line and Plain(line:GetText())
        if text and (text:match("^Equip:") or text:match("^Use:") or text:match("^Chance on hit:")) then
            effectIndex=effectIndex+1
            line:SetText(effects[effectIndex] or "");line:SetTextColor(0,1,0)
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
    for index=effectIndex+1,#effects do tooltip:AddLine(effects[index],0,1,0,true) end
    for index=setIndex+1,#bonuses do
        local bonus=bonuses[index]
        tooltip:AddLine(bonus.text,bonus.active and 0 or 0.5,bonus.active and 1 or 0.5,bonus.active and 0 or 0.5,true)
    end
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
    if event=="PLAYER_LEVEL_UP" then preview=nil;tooltip.arcanaHeirloomText=nil;return end
    if not preview or entry~=preview.entry or GetTime()>preview.expires or
        not tooltip:IsShown() or tooltip:GetOwner()~=preview.owner then return end
    local _,link=tooltip:GetItem()
    if Entry(link)~=entry then return end
    preview=nil
    tooltip:SetHyperlink("item:"..entry..":0:0:0:0:0:0:0")
end)

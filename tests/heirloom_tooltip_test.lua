local frames,sent={},{}
local now,level=1,30
local equipment={[16]=700001,[17]=700002}
local extraLines={}
local nativeEffectText="Chance on hit: Native level 80 amount"
local probeReads={}
local methods={}
function methods:GetName()return self.name end
function methods:GetText()return self.text end
function methods:SetText(text)self.text=text end
function methods:SetTextColor(...)self.color={...}end
function methods:SetScript(event,fn)self.scripts[event]=fn end
function methods:HookScript(event,fn)
    local old=self.scripts[event];self.scripts[event]=function(...)if old then old(...)end;fn(...)end
end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:IsShown()return self.shown end
function methods:SetOwner(owner)self.owner=owner end
function methods:GetOwner()return self.owner end
function methods:GetItem()return "Test",self.link end
function methods:NumLines()return self.count or 0 end
function methods:AddLine(text,r,g,b)
    self.count=self:NumLines()+1
    local line=CreateFrame("Font",self.name.."TextLeft"..self.count)
    line:SetText(text);line:SetTextColor(r,g,b)
end
function methods:SetHyperlink(link)
    self.link=link;self.count=0
    if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self)end
    if self.name=="ArcanaHeirloomSpellTooltip" then
        local spell=tonumber(link:match("spell:(%d+)"))
        probeReads[spell]=(probeReads[spell] or 0)+1
        self:AddLine("Native spell");self:AddLine("Instant")
        if spell==12 then self:AddLine("Native equip");self:AddLine("proc")
        else self:AddLine("Native level 80 amount") end
        return
    end
    self:AddLine("Test weapon")
    for _,text in ipairs(extraLines)do self:AddLine(text)end
    if nativeEffectText then self:AddLine(nativeEffectText)end
    self:AddLine("Twin Blades (0/2)");self:AddLine("(2) Set: Native haste")
end
function methods:SetInventoryItem(unit,slot)self:SetHyperlink(GetInventoryItemLink(unit,slot))end
function methods:SetBagItem()self:SetHyperlink("item:700001")end
function CreateFrame(kind,name)
    local frame=setmetatable({name=name,scripts={}},{__index=function(_,key)
        return methods[key] or (key:match("^[A-Z]") and function()end)
    end})
    if name then _G[name]=frame end;frames[#frames+1]=frame;return frame
end
function hooksecurefunc(object,name,fn)local old=object[name];object[name]=function(...)old(...);fn(...)end end
function UnitLevel(unit)return unit=="target" and 20 or level end
function GetInventoryItemLink(_,slot)return equipment[slot] and "item:"..equipment[slot]end
function UnitName()return "Tester"end
function GetTime()return now end
function SendAddonMessage(prefix,message,channel,target)
    assert(prefix=="ARHL" and channel=="WHISPER" and target=="Tester");sent[#sent+1]=message
end
UIParent=CreateFrame("Frame","UIParent")
GameTooltip=CreateFrame("GameTooltip","GameTooltip");GameTooltip:SetOwner(UIParent)
ArcanaHeirloomEffects={text={},spells={[10]={},[11]={},[12]={}},items={
    [700001]={set=10000,effects={{2,10}}},
    [700002]={set=10000,effects={}},
    [700003]={set=0,effects={{1,12}}},
},sets={[10000]={items={700001,700002},bonuses={{2,11}}}}}
for i=1,80 do
    ArcanaHeirloomEffects.text[i]="Deals "..i.." damage."
    ArcanaHeirloomEffects.text[80+i]="Grants "..i.." haste."
    ArcanaHeirloomEffects.spells[10][i]=i;ArcanaHeirloomEffects.spells[11][i]=80+i
    ArcanaHeirloomEffects.text[160+i]="Raises power by "..i.."."
    ArcanaHeirloomEffects.spells[12][i]=160+i
end
dofile("HeirloomTooltips.lua")
local events=frames[#frames]
local checks=0
local function check(condition)checks=checks+1;assert(condition,"check "..checks)end
for i=1,80 do
    level=i;GameTooltip:SetInventoryItem("player",16)
    check(GameTooltipTextLeft2:GetText()=="Chance on hit: Deals "..i.." damage.")
    check(GameTooltipTextLeft4:GetText()=="(2) Set: Grants "..i.." haste.")
    check(GameTooltipTextLeft3:GetText()=="Twin Blades (2/2)")
    check(GameTooltipTextLeft4.color[2]==1 and GameTooltipTextLeft4.color[1]==0)
    check(GameTooltip:NumLines()==5 and GameTooltipTextLeft5:GetText()==
        "Heirloom preview: level "..i..". Scales with wearer.")
end
-- The inspected target is level 20; native item-query stats still describe the
-- level-80 viewer. All effect/set amounts must use that same explicit preview.
GameTooltip:SetInventoryItem("target",16)
check(GameTooltipTextLeft2:GetText()=="Chance on hit: Deals 80 damage.")
check(GameTooltipTextLeft4:GetText()=="(2) Set: Grants 80 haste.")
check(GameTooltip:NumLines()==5 and GameTooltipTextLeft5:GetText()==
    "Heirloom preview: level 80. Scales with wearer.")
ArcanaRenderHeirloomTooltip(GameTooltip,"target")
check(GameTooltip:NumLines()==5) -- Nested hooks and repeated renders do not duplicate the label.
extraLines={"Equip: Improves critical strike rating by 12.",
    "|cff00ff00Equip: Increases attack power by 24.|r","Equip: Unrelated addon text"}
GameTooltip:SetInventoryItem("target",16)
check(GameTooltipTextLeft2:GetText()==extraLines[1] and GameTooltipTextLeft3:GetText()==extraLines[2])
check(GameTooltipTextLeft4:GetText()==extraLines[3])
check(GameTooltipTextLeft5:GetText()=="Chance on hit: Deals 80 damage." and GameTooltip:NumLines()==8)
nativeEffectText="Equip: Native equip proc"
GameTooltip:SetHyperlink("item:700003")
check(GameTooltipTextLeft2:GetText()==extraLines[1] and GameTooltipTextLeft3:GetText()==extraLines[2])
check(GameTooltipTextLeft4:GetText()==extraLines[3] and GameTooltipTextLeft5:GetText()=="Equip: Raises power by 80.")
local reads=probeReads[12]
GameTooltip:SetHyperlink("item:700003");check(probeReads[12]==reads)
events.scripts.OnEvent(events,"PLAYER_LEVEL_UP")
GameTooltip:SetHyperlink("item:700003");check(probeReads[12]==reads+1)
nativeEffectText=nil
GameTooltip:SetHyperlink("item:700002") -- Tier pieces with no proc retain native stats.
check(GameTooltipTextLeft2:GetText()==extraLines[1] and GameTooltipTextLeft3:GetText()==extraLines[2])
check(GameTooltipTextLeft4:GetText()==extraLines[3] and GameTooltip:NumLines()==7)
extraLines={};nativeEffectText="Chance on hit: Native level 80 amount"
equipment[17]=32838;GameTooltip:SetInventoryItem("player",16)
check(GameTooltipTextLeft3:GetText()=="Twin Blades (1/2)" and GameTooltipTextLeft4.color[1]==0.5)
GameTooltip:SetHyperlink("item:700001")
check(GameTooltipTextLeft3:GetText()=="Twin Blades (0/2)" and GameTooltipTextLeft4.color[1]==0.5)
GameTooltip:SetHyperlink("item:19019")
check(GameTooltipTextLeft2:GetText()=="Chance on hit: Native level 80 amount" and GameTooltip:NumLines()==4)
ArcanaHeirloomPreview(UIParent,700001);check(#sent==1 and sent[1]:find("PREVIEW",1,true))
GameTooltip:SetHyperlink("item:19019")
events.scripts.OnEvent(events,"GET_ITEM_INFO_RECEIVED",700001)
check(GameTooltip.link=="item:19019") -- Late response cannot overwrite another tooltip.
dofile("HeirloomEffects.lua")
local D=ArcanaHeirloomEffects
for _,row in pairs(D.spells)do
    check(#row==1 or #row==80)
    for _,id in ipairs(row)do check(id==0 or (D.text[id] and not D.text[id]:find("$",1,true)))end
end
local haste=D.spells[300315]
check(D.text[haste[1]]:find("5 for 10 sec",1,true) and D.text[haste[80]]:find("450 for 10 sec",1,true))
check(D.text[haste[30]]:find("Requires both heirloom Warglaives",1,true))
local valanyr=D.spells[300857]
check(D.text[valanyr[1]]:find("20% of the recipient",1,true))
check(D.text[valanyr[1]]~=D.text[valanyr[80]])
print("PASS "..checks.." heirloom tooltip checks: all levels, set isolation, inspection, previews and generated descriptions")

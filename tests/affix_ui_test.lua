-- Headless WoW 3.3.5 API model: exercise the actual event/tooltip/payment handlers.
local frames, named, sent, now, popup = {}, {}, {}, 1, nil
local methods = {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn) self.scripts[event] = fn end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsShown() return self.shown ~= false end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:AddLine(text) self.lines[#self.lines+1] = text end
function methods:GetItem() return "Test", self.link end
function methods:SetText(text) self.text = text end
function methods:CreateFontString() return CreateFrame("Font") end

function CreateFrame(kind, name)
    local frame=setmetatable({scripts={}, lines={}}, {__index=function(_, key) return rawget(methods,key) or (string.match(key,"^[A-Z]") and function() end) end})
    frames[#frames+1]=frame; if name then named[name]=frame end; return frame
end
function hooksecurefunc(object, method, hook)
    local original=object[method]
    object[method]=function(...) local result=original(...); hook(...); return result end
end
ArcanaItemUpgradesFrame=CreateFrame("Frame")
local host=ArcanaItemUpgradesFrame
host.selected=10
function host:GetSelectedEquipmentSlot() return self.selected end
function host:SetAffixSlots(slots) self.slots=slots end
GameTooltip=CreateFrame("Tooltip")
StaticPopupDialogs={}; ACCEPT="Accept"; CANCEL="Cancel"
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function SendAddonMessage(prefix, message, channel, who) sent[#sent+1]=message end
function UnitName() return "Tester" end
function GetTime() return now end
local inside, dead, combat, tokens=false,false,false,1
function IsInInstance() return inside end
function UnitIsDeadOrGhost() return dead end
function UnitAffectingCombat() return combat end
function GetItemCount() return tokens end
function UnitIsUnit(a,b) return a==b end
function UnitGUID() return "0x0000000000000001" end
local links={[11]="|Hitem:45809:0:0:0:0:0:0:0:80|h[Ring]|h", [18]="|Hitem:40711:0:0:0:0:0:0:0:80|h[Relic]|h"}
function GetInventoryItemLink(unit, slot) return links[slot] end
function StaticPopup_Show(kind, a,b,data) popup={kind=kind,data=data} end

dofile("AffixProtocol.lua")
dofile("ArcanaItemAffixes.lua")
local events=frames[#frames]
local function event(name,...) events.scripts.OnEvent(events,name,...) end
local function receive(text) event("CHAT_MSG_ADDON","AAF",text,"WHISPER","Tester") end
local checks=0
local function check(value,label) checks=checks+1; assert(value,label) end
local packed=524288+80*4096+20*64+4
receive("SYNC"); receive("E\t10\t45809\t123\t"..packed.."\t1")
receive("E\t17\t40711\t124\t"..packed.."\t1"); receive("DONE")
local button=named.ArcanaItemRecalibrateButton
check(button.enabled,"eligible selected ring enables recalibration")
check(host.slots[17].entry==40711,"relic reaches complete equipment selector")
button.scripts.OnClick()
check(popup and popup.data.guid==123,"confirmation captures exact GUID")
host.selected=17
StaticPopupDialogs.ARCANA_AFFIX_CONFIRM.OnAccept({},popup.data)
check(sent[#sent]=="R\t10\t123\t1","selection change cannot redirect confirmed payment")
check(not button.enabled,"pending payment disables repeated clicks")
local paid=#sent
StaticPopupDialogs.ARCANA_AFFIX_CONFIRM.OnAccept({},popup.data)
check(#sent==paid,"duplicate confirmation sends no second request")
receive("RESULT\tDone")
check(button.enabled,"acknowledgement releases payment lock")
inside=true; host:UpdateDisplay(); check(not button.enabled,"instance blocks remote use")
inside=false; combat=true; host:UpdateDisplay(); check(not button.enabled,"combat blocks remote use")
combat=false; dead=true; host:UpdateDisplay(); check(not button.enabled,"dead blocks remote use")
dead=false; tokens=0; host:UpdateDisplay(); check(not button.enabled,"missing token blocks payment")
tokens=1
local tooltip=GameTooltip
tooltip.link=links[11]; tooltip:SetInventoryItem("player",11)
local id=tonumber(string.match(sent[#sent],"Q\t(%d+)"))
tooltip.scripts.OnTooltipCleared(tooltip); tooltip.link=links[18]
receive("V\t"..id.."\t45809\t123\t"..packed.."\t1")
check(#tooltip.lines==0,"stale reply cannot annotate another item")
tooltip:SetInventoryItem("player",18)
id=tonumber(string.match(sent[#sent],"Q\t(%d+)"))
receive("V\t"..id.."\t40711\t124\t"..packed.."\t1")
check(#tooltip.lines==1 and string.find(tooltip.lines[1],"20 Strength"),"correct instance reply renders bonus")
receive("V\t"..id.."\t40711\t124\t"..packed.."\t1")
check(#tooltip.lines==1,"duplicate reply adds no duplicate line")
tooltip.scripts.OnTooltipCleared(tooltip); tooltip:SetInventoryItem("player",18)
id=tonumber(string.match(sent[#sent],"Q\t(%d+)")); now=10
receive("V\t"..id.."\t40711\t124\t"..packed.."\t1")
check(#tooltip.lines==1,"expired reply is ignored")
print("PASS: "..checks.." affix UI checks (Lua 5.1)")

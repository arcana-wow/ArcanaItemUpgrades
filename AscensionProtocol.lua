-- No UI dependencies: malformed and incomplete snapshots never enable payment.
ArcanaAscensionProtocol = {}
local P = ArcanaAscensionProtocol
P.Levels = {[194700]=200,[194701]=226,[194702]=245,[194703]=264,[194704]=284}
P.Names = {[194700]="Heroic",[194701]="Runic",[194702]="Crusader",[194703]="Icecrown",[194704]="Apex"}
function P.Split(text)
    local out = {}
    for part in (text .. "\t"):gmatch("(.-)\t") do out[#out+1] = part end
    return out
end
local function integer(text, maximum)
    if type(text) ~= "string" or not text:match("^%d+$") then return nil end
    local value = tonumber(text)
    return value and value <= maximum and value or nil
end
function P.Row(fields)
    if #fields ~= 8 or fields[1] ~= "ITEM" then return nil end
    local slot = integer(fields[2],18)
    local guid, entry = integer(fields[3],4294967295), integer(fields[4],2147483647)
    local ilvl, target = integer(fields[5],65535), integer(fields[6],2147483647)
    local token, count = integer(fields[7],2147483647), integer(fields[8],4294967295)
    if not slot or not guid or guid == 0 or not entry or entry == 0 or not ilvl or
        not target or not token or not count then return nil end
    if (target == 0) ~= (token == 0) or (token ~= 0 and not P.Levels[token]) then return nil end
    if token ~= 0 and ilvl >= P.Levels[token] then return nil end
    return {slot=slot,guid=guid,entry=entry,ilvl=ilvl,target=target,token=token,count=count,affixOnly=true}
end
function P.Request(row)
    return table.concat({"ASCEND",row.slot,row.guid,row.entry,row.target},"\t")
end

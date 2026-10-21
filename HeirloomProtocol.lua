-- Lua 5.1. Server-owned progress and quotes; no saved client unlock authority.
ArcanaHeirloomProtocol = {}
local P = ArcanaHeirloomProtocol
P.Materials = {
    {name="100 gold",minimum=3,maximum=5},
    {name="Emblem of Triumph",entry=47241,minimum=1,maximum=3},
    {name="Emblem of Frost",entry=49426,minimum=3,maximum=5},
    {name="Wintergrasp Mark",entry=43589,minimum=3,maximum=5},
    {name="Arcana Dogtag",entry=194400,minimum=1,maximum=3},
    {name="Original item",minimum=20,maximum=20},
}
function P.Split(text)
    if type(text)~="string" or #text>249 then return {} end
    local fields={}
    for field in (text.."\t"):gmatch("(.-)\t") do fields[#fields+1]=field end
    return fields
end
function P.Number(text,maximum)
    if type(text)~="string" or not text:match("^%d+$") then return nil end
    local number=tonumber(text)
    return number and number<=maximum and number or nil
end
function P.Id(text)
    return type(text)=="string" and #text==32 and text:match("^[0-9a-f]+$")~=nil
end
function P.Preview(progress,source,quantity)
    local material=P.Materials[source+1]
    if not material or progress<0 or progress>=100 or quantity<1 or quantity>100 or
        quantity~=math.floor(quantity) or (source==5 and quantity~=1) then return nil end
    return math.min(100-progress,material.minimum*quantity),math.min(100-progress,material.maximum*quantity)
end
function P.Quote(fields,selection,now)
    if #fields~=12 or fields[1]~="QUOTE" or not P.Id(fields[3]) or not selection then return nil end
    local values={}
    for i=4,12 do
        values[i]=P.Number(fields[i],4294967295)
        if not values[i] then return nil end
    end
    local request=P.Number(fields[2],4294967295)
    if not request or request==0 or request~=selection.request or
        values[4]~=selection.kind or values[5]~=selection.family or
        values[9]~=selection.quantity or values[10]~=selection.source or values[11]~=selection.original or
        values[12]<1 or values[12]>30 then return nil end
    local minimum,maximum=0,0
    if values[4]==1 then
        minimum,maximum=P.Preview(values[6],values[10],values[9])
        if not minimum then return nil end
    elseif values[4]~=2 or values[6]~=100 or values[9]~=1 or values[10]~=0 or values[11]~=0 then
        return nil
    end
    if minimum~=values[7] or maximum~=values[8] then return nil end
    return {id=fields[3],kind=values[4],family=values[5],progress=values[6],
        minimum=minimum,maximum=maximum,quantity=values[9],source=values[10],
        original=values[11],expires=now+values[12]}
end
function P.Begin(fields,request)
    if #fields~=4 or fields[1]~="BEGIN" or tonumber(fields[2])~=request then return nil end
    local count,originals=P.Number(fields[3],3793),P.Number(fields[4],256)
    if not count or not originals then return nil end
    return {request=request,expected=count,expectedOriginals=originals,rows={},originals={},count=0,originalCount=0}
end
function P.Append(snapshot,fields,catalogue)
    if not snapshot or tonumber(fields[2])~=snapshot.request then return false end
    if fields[1]=="ROW" and #fields==5 then
        local family=P.Number(fields[3],4294967295)
        local progress,version=P.Number(fields[4],100),P.Number(fields[5],4294967295)
        if not family or not catalogue[family] or progress==nil or not version or snapshot.rows[family] then return false end
        snapshot.rows[family]={progress=progress,version=version}
        snapshot.count=snapshot.count+1
        return snapshot.count<=snapshot.expected
    elseif fields[1]=="ORIGINAL" and #fields==7 then
        local family,guid=P.Number(fields[3],4294967295),P.Number(fields[4],4294967295)
        local bag,slot=P.Number(fields[5],4),P.Number(fields[6],36)
        local entry=P.Number(fields[7],4294967295)
        if not family or not catalogue[family] or not guid or guid==0 or not bag or not slot or slot==0 or
            (bag==0 and slot>16) or not entry or entry==0 or snapshot.originals[guid] then return false end
        snapshot.originals[guid]={family=family,guid=guid,bag=bag,slot=slot,entry=entry}
        snapshot.originalCount=snapshot.originalCount+1
        return snapshot.originalCount<=snapshot.expectedOriginals
    end
    return false
end
function P.Complete(snapshot,fields)
    return snapshot and #fields==2 and fields[1]=="END" and tonumber(fields[2])==snapshot.request and
        snapshot.count==snapshot.expected and snapshot.originalCount==snapshot.expectedOriginals
end
function P.Done(fields,catalogue)
    if #fields~=7 or fields[1]~="DONE" then return false end
    local kind,family,progress,consumed,item=P.Number(fields[3],2),P.Number(fields[4],4294967295),
        P.Number(fields[5],100),P.Number(fields[6],100),P.Number(fields[7],4294967295)
    if not kind or kind<1 or not family or not catalogue[family] or
        not progress or not consumed or not item then return false end
    return (kind==1 and consumed>0 and progress>0 and item==0) or
        (kind==2 and consumed==0 and progress==100 and item>0)
end
function P.Filter(catalogue,progress,mode,query,itemClass,subclass,slot)
    query=(query or ""):lower():match("^%s*(.-)%s*$")
    local rows={}
    for entry,item in pairs(catalogue) do
        local state=progress[entry]
        local visible=query~="" or (state and ((mode=="Unlocked")==(state.progress==100)))
        if visible and (query=="" or item.name:lower():find(query,1,true) or tostring(entry)==query or tostring(item.source)==query) and
            (not itemClass or item.class==itemClass) and (not subclass or item.subclass==subclass or
                (subclass=="armor" and item.subclass>=1 and item.subclass<=4)) and
            (not slot or item.slot==slot or (slot=="chest" and (item.slot==5 or item.slot==20))) then rows[#rows+1]=entry end
    end
    table.sort(rows,function(a,b)
        local x,y=catalogue[a].name:lower(),catalogue[b].name:lower()
        return x==y and a<b or x<y
    end)
    return rows
end

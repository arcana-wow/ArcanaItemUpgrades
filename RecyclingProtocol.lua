-- Pure 3.3.5/Lua 5.1 protocol and selection rules; the server owns eligibility and payment.
ArcanaRecyclingProtocol = {}
local P = ArcanaRecyclingProtocol
function P.Split(text)
    local fields = {}
    for field in (text .. "\t"):gmatch("(.-)\t") do fields[#fields+1] = field end
    return fields
end
function P.Integer(text, maximum)
    if type(text)~="string" or not text:match("^%d+$") then return nil end
    local value=tonumber(text)
    return value and value<=maximum and value or nil
end
function P.Id(text) return type(text)=="string" and #text==32 and text:match("^[0-9a-f]+$")~=nil end
function P.Row(f)
    if #f~=9 or f[1]~="ITEM" then return nil end
    local request=P.Integer(f[2],4294967295)
    local guid=P.Integer(f[3],4294967295)
    local bag=P.Integer(f[4],4)
    local slot=P.Integer(f[5],36)
    local entry=P.Integer(f[6],2147483647)
    local ilvl=P.Integer(f[7],65535)
    local price=P.Integer(f[8],4294967295)
    local pvp=P.Integer(f[9],1)
    if not request or request==0 or not guid or guid==0 or not bag or not slot or slot==0 or
        (bag==0 and slot>16) or not entry or entry==0 or not ilvl or ilvl<187 or not price or not pvp then return nil end
    return {request=request,guid=guid,bag=bag,slot=slot,entry=entry,ilvl=ilvl,price=price,pvp=pvp}
end
function P.Totals(selected, rows)
    local count,gross,levels,pvp,seen=0,0,0,0,{}
    for index=1,10 do
        local guid=selected[index]
        if guid then
            local row=rows[guid]
            if not row or seen[guid] then return nil end
            seen[guid]=true;count=count+1;gross=gross+row.price;levels=levels+row.ilvl;pvp=pvp+row.pvp
        end
    end
    local gold=math.floor(gross/2)
    return {count=count,gross=gross,tax=gross-gold,gold=gold,levels=levels,pvp=pvp}
end
function P.Quote(f, selected, rows, now)
    if #f~=14 or f[1]~="QUOTE" or not P.Id(f[3]) then return nil end
    local request=P.Integer(f[2],4294967295)
    local lifetime=P.Integer(f[4],30)
    local gross=P.Integer(f[5],42949672950)
    local tax=P.Integer(f[6],42949672950)
    local gold=P.Integer(f[7],2147483646)
    local levels=P.Integer(f[8],655350)
    local pvp=P.Integer(f[14],10)
    local totals=P.Totals(selected,rows)
    if not pvp or not request or request==0 or not lifetime or lifetime==0 or not gross or not tax or not gold or not levels or
        not totals or totals.count~=10 or gross~=totals.gross or gold~=totals.gold or tax~=totals.tax or levels~=totals.levels or pvp~=totals.pvp then return nil end
    local probabilities,sum={},0
    for i=1,5 do
        local text=f[8+i]
        local value=text:match("^%d+%.%d+$") and tonumber(text)
        if not value or value<0.01 or value>0.96 then return nil end
        probabilities[i]=value;sum=sum+value
    end
    if math.abs(sum-1)>0.000005 then return nil end
    return {request=request,id=f[3],expires=now+lifetime,gross=gross,tax=tax,gold=gold,levels=levels,pvp=pvp,probabilities=probabilities,gear={[0]={},[1]={}},parts={}}
end
P.Levels={200,213,219,226,232,239,245,251,258,264,277,284}
function P.Gear(quote,f)
    if not quote or #f~=11 or f[1]~="GEAR" or tonumber(f[2])~=quote.request or f[3]~=quote.id then return false end
    local category,part=P.Integer(f[4],1),P.Integer(f[5],1)
    if not category or not part then return false end
    local key=category*2+part
    if quote.parts[key] then return false end
    local values={}
    for i=1,6 do
        local text=f[5+i]
        local value=#text<=20 and text:match("^%d+%.%d+$") and tonumber(text)
        if not value or value<0 or value>1 then return false end
        values[i]=value
    end
    for i=1,6 do quote.gear[category][part*6+i]=values[i] end
    quote.parts[key]=true
    return true
end
function P.Complete(quote,f,now)
    if not quote or #f~=3 or f[1]~="QEND" or tonumber(f[2])~=quote.request or f[3]~=quote.id or quote.expires<=now then return nil end
    for i=0,3 do if not quote.parts[i] then return nil end end
    for category=0,1 do
        local sum=0
        for i=1,12 do
            local value=quote.gear[category][i];sum=sum+value
            if quote.levels<2000 and i~=1 and value~=0 then return nil end
            if category==1 and (i==3 or i==12) and value~=0 then return nil end
        end
        local active=category==1 and quote.pvp>0 or category==0 and quote.pvp<10
        if active and math.abs(sum-1)>0.000000001 then return nil end
        if not active and sum~=0 and math.abs(sum-1)>0.000000001 then return nil end
    end
    return quote
end
function P.Add(selected, rows, index, guid)
    if not index or index<1 or index>10 or index~=math.floor(index) or selected[index] or not rows[guid] then return false end
    for i=1,10 do if selected[i]==guid then return false end end
    selected[index]=guid;return true
end
function P.Selection(selected, rows)
    local totals=P.Totals(selected,rows)
    if not totals or totals.count~=10 then return nil end
    local guids={}
    for i=1,10 do guids[i]=tostring(selected[i]) end
    return table.concat(guids,",")
end
function P.NextEmpty(selected, after)
    for offset=1,10 do
        local index=((after or 0)+offset-1)%10+1
        if not selected[index] then return index end
    end
end
function P.Autofill(rows)
    local items={}
    for _,row in pairs(rows) do items[#items+1]=row end
    table.sort(items,function(a,b)
        if a.ilvl~=b.ilvl then return a.ilvl>b.ilvl end
        if a.bag~=b.bag then return a.bag<b.bag end
        if a.slot~=b.slot then return a.slot<b.slot end
        return a.guid<b.guid
    end)
    local selected={}
    for index=1,math.min(10,#items) do selected[index]=items[index].guid end
    return selected
end
function P.Money(copper)
    return string.format("%dg %ds %dc",math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
end

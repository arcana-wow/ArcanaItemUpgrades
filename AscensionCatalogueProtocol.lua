-- Bounded, read-only catalogue requests. UI input invalidates old replies
-- immediately; only a completed snapshot may replace the visible results.
ArcanaAscensionCatalogueProtocol = {}
local P = ArcanaAscensionCatalogueProtocol
P.Levels = {200,226,245,264,284}
local function UInt(value, maximum)
    if type(value)~="string" or not value:match("^%d+$") then return nil end
    local n=tonumber(value)
    return n and n<=(maximum or 2147483647) and n or nil
end
local function Int(value)
    if type(value)~="string" or not value:match("^%-?%d+$") then return nil end
    local n=tonumber(value)
    return n and n>=-2147483647 and n<=2147483647 and n or nil
end
local function Clean(text) return type(text)=="string" and not text:find("[%c|]") end
function P.Key(row) return row.source..":"..row.property end
function P.Link(row, entry)
    local original=entry==row.source
    return "item:"..entry..":0:0:0:0:0:"..(original and row.property or 0)..":"..
        (original and row.factor or 0)..":80"
end
function P.Next(row)
    for _,entry in ipairs(row.targets) do if entry>0 then return entry end end
end
function P.New()
    return {serial=0,query="",page=0,lastSend=-1,cache={},detailCache={},cacheOrder={},detailOrder={}}
end
local function Put(cache,order,key,value)
    if not cache[key] then
        order[#order+1]=key
        if #order>64 then cache[table.remove(order,1)]=nil end
    end
    cache[key]=value
end
function P.Query(state, text, now, page)
    text=(text or ""):lower():match("^%s*(.-)%s*$")
    state.pending=nil;state.wanted=nil;state.error=nil;state.result=nil;state.detailErrorKey=nil
    state.query=text;state.page=page or 0
    state.key=text.."\t"..state.page
    state.due=nil
    if #text>80 or not Clean(text) then state.error="Enter an item name or item ID.";return end
    state.result=state.cache[state.key]
    if not state.result then state.due=now+0.5 end
end
function P.Cancel(state)
    state.pending=nil;state.wanted=nil;state.due=nil
end
function P.Detail(state,row,now)
    local key=P.Key(row)
    if state.detailCache[key] then return state.detailCache[key] end
    if state.detailErrorKey==key then return nil end
    if state.pending and state.pending.kind=="detail" and state.pending.key==key then return nil end
    if not state.wanted or state.wanted.key~=key then state.wanted={key=key,row=row,due=now+0.15} end
end
function P.Leave(state,row)
    if state.wanted and state.wanted.key==P.Key(row) then state.wanted=nil end
end
function P.Tick(state,now)
    if state.pending and now>=state.pending.deadline then
        if state.pending.kind=="detail" then state.detailErrorKey=state.pending.key end
        state.error="No response from the server. Search again to retry."
        state.pending=nil;state.wanted=nil;return nil,true
    end
    if state.pending or now-state.lastSend<0.55 then return end
    local request
    if state.due and now>=state.due then
        request={kind="search",key=state.key,page=state.page}
        state.due=nil
    elseif state.wanted and now>=state.wanted.due and not state.due then
        request={kind="detail",key=state.wanted.key,row=state.wanted.row}
        state.wanted=nil
    end
    if not request then return end
    state.serial=state.serial+1;request.id=state.serial;request.deadline=now+5
    state.pending=request;state.lastSend=now
    if request.kind=="search" then
        return table.concat({"SEARCH",request.id,request.page,state.query},"\t")
    end
    return table.concat({"DETAIL",request.id,request.row.source,request.row.property},"\t")
end
function P.Row(fields)
    if #fields~=13 then return nil end
    local row={source=UInt(fields[3]),property=Int(fields[4]),factor=UInt(fields[5],4294967295),
        ilvl=UInt(fields[6],283),quality=UInt(fields[7],5),name=fields[8],targets={}}
    if not row.source or row.source==0 or not row.property or not row.factor or not row.ilvl or
        not row.quality or row.quality<3 or not Clean(row.name) or #row.name==0 or #row.name>150 then return end
    local any=false
    for index,level in ipairs(P.Levels) do
        local entry=UInt(fields[8+index])
        if not entry or ((level>row.ilvl)~=(entry>0)) then return nil end
        row.targets[index]=entry;any=any or entry>0
    end
    return any and row or nil
end
function P.Receive(state,message)
    local fields=ArcanaAscensionProtocol.Split(message)
    local request=state.pending
    if not request or UInt(fields[2])~=request.id then return false end
    local kind=fields[1]
    if kind=="CATERROR" then
        if request.kind=="detail" then state.detailErrorKey=request.key end
        state.error=Clean(fields[3]) and fields[3] or "Catalogue request failed."
        state.pending=nil;state.wanted=nil;return true
    end
    if request.kind=="search" then
        if kind=="CATBEGIN" then
            local page,total=UInt(fields[3],100000),UInt(fields[4],1000000)
            if #fields~=4 or page~=request.page or not total then request.invalid=true;return false end
            request.data={page=page,total=total,rows={}};request.seen={}
        elseif kind=="CATROW" and request.data then
            local row=P.Row(fields)
            if not row or #request.data.rows>=20 or request.seen[P.Key(row)] then request.invalid=true;return false end
            request.seen[P.Key(row)]=true;table.insert(request.data.rows,row)
        elseif kind=="CATEND" and request.data then
            local expected=math.max(0,math.min(20,request.data.total-request.data.page*20))
            if #fields~=2 or request.invalid or #request.data.rows~=expected then
                state.error="Incomplete catalogue results. Search again to retry."
            else
                Put(state.cache,state.cacheOrder,request.key,request.data)
                state.result=request.data;state.error=nil
            end
            state.pending=nil;return true
        end
    else
        if kind=="CATDETAILBEGIN" then
            request.data={};request.seen={};request.count=0
        elseif kind=="CATSET" and request.data then
            local entry,required,spell=UInt(fields[3]),UInt(fields[4],8),UInt(fields[5])
            local allowed=entry==request.row.source
            for _,candidate in ipairs(request.row.targets) do allowed=allowed or (entry and entry>0 and entry==candidate) end
            local key=tostring(entry)..":"..tostring(required)..":"..tostring(spell)
            if #fields~=5 or not allowed or not entry or not required or required<1 or not spell or spell<1 or
                request.count>=48 or request.seen[key] then request.invalid=true;return false end
            request.seen[key]=true;request.count=request.count+1
            request.data[entry]=request.data[entry] or {}
            table.insert(request.data[entry],{count=0,required=required,spell=spell,active=false})
        elseif kind=="CATDETAILEND" and request.data then
            if #fields==2 and not request.invalid then
                Put(state.detailCache,state.detailOrder,request.key,request.data)
            else
                state.error="Incomplete set preview. Search again to retry."
                state.detailErrorKey=request.key
            end
            state.pending=nil;return true
        end
    end
    return false
end

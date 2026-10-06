dofile("AscensionProtocol.lua")
dofile("AscensionCatalogueProtocol.lua")
local P=ArcanaAscensionCatalogueProtocol
local state=P.New()
local checks=0
local function check(value) checks=checks+1;assert(value,"check "..checks) end
local function receive(text) return P.Receive(state,text) end
local function row(id,source,name,ilvl,targets,property)
    return table.concat({"CATROW",id,source,property or 0,0,ilvl,4,name,unpack(targets)},"\t")
end
local function finish(id,page,total,rows)
    receive("CATBEGIN\t"..id.."\t"..page.."\t"..total)
    for _,text in ipairs(rows or {}) do receive(text) end
    return receive("CATEND\t"..id)
end
P.Query(state,"s",0)
check(not P.Tick(state,0.49))
P.Query(state,"st",0.49);P.Query(state,"sta",0.8)
check(not P.Tick(state,1.29))
check(P.Tick(state,1.3)=="SEARCH\t1\t0\tsta")
P.Query(state,"",1.31)
check(not finish(1,0,0) and not state.result) -- Late reply rejected before the next request.
check(not P.Tick(state,1.84)) -- Global send spacing also bounds typing bursts.
check(not P.Tick(state,1.86) and not state.due) -- Empty input never reaches the server.
P.Query(state,"  \t ",1.9);check(not P.Tick(state,10)) -- Whitespace is also empty.
P.Query(state,"873",1.9);check(P.Tick(state,2.45)=="SEARCH\t2\t0\t873")
local targets={500001,500002,500003,500004,500005}
check(finish(2,0,1,{row(2,873,"Staff of Jordan",40,targets)}))
check(state.result.total==1 and state.result.rows[1].name=="Staff of Jordan")
local staff=state.result.rows[1]
check(P.Next(staff)==500001)
check(P.Link(staff,873)=="item:873:0:0:0:0:0:0:0:80")
P.Query(state,"873",2.5);check(state.result and not P.Tick(state,3)) -- Cache.
P.Query(state,"s",3);check(P.Tick(state,3.5)=="SEARCH\t3\t0\ts") -- One character allowed.
finish(3,0,1,{row(3,873,"Staff of Jordan",40,targets)})
P.Detail(state,staff,3.6);check(not P.Tick(state,3.76))
check(P.Tick(state,4.1)=="DETAIL\t4\t873\t0")
receive("CATDETAILBEGIN\t4");receive("CATSET\t4\t500001\t2\t200001")
receive("CATSET\t4\t500001\t2\t200002");receive("CATDETAILEND\t4")
check(P.Detail(state,staff,4.2)[500001][1].spell==200001)
check(#P.Detail(state,staff,4.2)[500001]==2) -- Warglaives have two bonuses at the same threshold.
check(not P.Tick(state,5))
P.Query(state,"wrath",5);check(P.Tick(state,5.5)=="SEARCH\t5\t0\twrath")
finish(5,0,1,{row(5,52000,"Wrath Weapon",277,{0,0,0,0,500006})})
check(P.Next(state.result.rows[1])==500006 and state.result.rows[1].targets[1]==0)
P.Query(state,"missing",6);P.Tick(state,6.6)
finish(6,0,1,{row(6,873,"Bad|Hlink",40,targets)})
check(not state.result and state.error)
P.Query(state,"duplicate",7);P.Tick(state,7.6)
finish(7,0,2,{row(7,873,"Staff",40,targets),row(7,873,"Staff",40,targets)})
check(not state.result and state.error)
P.Query(state,"incomplete",8);P.Tick(state,8.6);finish(8,0,2,{row(8,873,"Staff",40,targets)})
check(not state.result and state.error)
P.Query(state,"timeout",9);P.Tick(state,9.6);P.Tick(state,14.61)
check(not state.pending and state.error)
P.Query(state,"cancel",15);P.Cancel(state);check(not P.Tick(state,16))
P.Query(state,string.rep("x",81),17);check(state.error and not P.Tick(state,18))
P.Query(state,"a\tb",19);check(state.error and not P.Tick(state,20))
P.Query(state,"873",21,1);check(P.Tick(state,21.6)=="SEARCH\t10\t1\t873")
finish(10,1,0);check(state.result and state.result.page==1)
local suffix=P.Row(ArcanaAscensionProtocol.Split(row(1,31172,"Hide of Strength",100,targets,-5)))
suffix.factor=123
check(P.Link(suffix,31172)=="item:31172:0:0:0:0:0:-5:123:80")
check(P.Link(suffix,500001)=="item:500001:0:0:0:0:0:0:0:80")
for n=1,70 do
    P.Query(state,"cache "..n,30+n*2)
    P.Tick(state,30+n*2+0.6)
    finish(state.serial,0,0)
end
local size=0;for _ in pairs(state.cache) do size=size+1 end
check(size==64 and #state.cacheOrder==64)
state=P.New()
P.Detail(state,staff,0);P.Leave(state,staff);check(not P.Tick(state,1))
P.Detail(state,staff,2);check(P.Tick(state,2.2)=="DETAIL\t1\t873\t0")
receive("CATERROR\t1\tPlease wait.")
P.Detail(state,staff,3);check(not P.Tick(state,4)) -- Rendering an error cannot start a retry loop.
P.Query(state,"staff",5);P.Tick(state,5.6)
finish(2,0,1,{row(2,873,"Staff of Jordan",40,targets)})
P.Detail(state,staff,6);check(P.Tick(state,6.2)=="DETAIL\t3\t873\t0")
P.Tick(state,12);P.Detail(state,staff,13);check(not P.Tick(state,14))
print("PASS: "..checks.." catalogue debounce, empty/single-character input, cache bounds, stale/malformed replies, suffixes and tier checks")

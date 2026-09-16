dofile("AffixProtocol.lua")
local P = ArcanaAffixProtocol
local checks = 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function pack(stat, amount, level) return stat + amount*64 + level*4096 + 524288 end
local strength, intellect = pack(4,20,80), pack(5,16,80)
eq(P.Describe(strength), "+20 Strength", "maximum Strength")
eq(P.Describe(pack(7,30,80)), "+30 Stamina", "maximum Stamina")
eq(P.Describe(pack(38,40,80)), "+40 Attack Power", "maximum AP")
eq(P.Describe(pack(36,8,70)), "+8 Haste Rating", "TBC haste")
eq(P.Describe(pack(44,10,79)), "+10 Armor Penetration Rating", "TBC custom ArP")
for _, bad in ipairs({0, -1, 0.5, 1048576+20*64+4, 524288+63+20*64, 4294967296, "bad"}) do
    eq(P.Describe(bad), nil, "invalid encoding")
end
local state = P.New()
P.Receive(state,"SYNC")
P.Receive(state,"E\t0\t50375\t10\t"..strength.."\t2")
eq(state.slots[0],nil,"partial sync not published")
P.Receive(state,"DONE")
eq(state.slots[0].packed,strength,"sync publish")
P.Receive(state,"E\t0\t50375\t99\t"..intellect.."\t4")
eq(state.slots[0].guid,10,"out-of-sync row ignored")
P.Receive(state,"SYNC"); P.Receive(state,"DONE")
eq(state.slots[0],nil,"removed equipment clears state")
P.Receive(state,"BEGIN\t0\t10")
P.Receive(state,"C\t10\t1\t50375\t101\t"..strength.."\t1")
P.Receive(state,"BEGIN\t5\t11")
P.Receive(state,"C\t11\t17\t50375\t102\t"..intellect.."\t1")
P.Receive(state,"END\t11"); P.Receive(state,"END\t10")
local loot, mail = P.Take(state,0), P.Take(state,5)
eq(loot[1].guid,101,"interleaved loot snapshot")
eq(mail[17].guid,102,"interleaved mail snapshot")
eq(P.Take(state,0)[1],nil,"snapshot consumed once")
eq(P.Matches(loot[1],"|Hitem:50375:0:0:0:0:0:0:0|h[Ring]|h"),true,"correct entry")
eq(P.Matches(loot[1],"|Hitem:50400:0:0:0:0:0:0:0|h[Other]|h"),false,"stale entry rejected")
P.Receive(state,"BEGIN\t99\t12"); P.Receive(state,"END\t12")
eq(state.queues[99],nil,"unknown context ignored")
local key=P.AuctionKey("|Hitem:50375:0:0:0:0:0:0:0:80|h[Ring]|h",1,100,200,0,"Owner")
eq(key,"50375:0:0:0:0:0:0:0:1:100:200:0:Owner","auction identity")
local rows={ [1]={identity=key,packed=strength,guid=101}, [2]={identity="other",packed=intellect,guid=102} }
eq(P.AuctionRow(rows,key).guid,101,"auction ignores reordered index")
rows[2].identity=key
local row, ambiguous=P.AuctionRow(rows,key)
eq(row,nil,"indistinguishable different bonuses never guessed")
eq(ambiguous,true,"ambiguity surfaced")
rows[2].packed=strength
eq(P.AuctionRow(rows,key).packed,strength,"identical bonuses safe")
for i=1,100 do P.Receive(state,"BEGIN\t1\t"..i); P.Receive(state,"END\t"..i) end
eq(#state.queues[1],64,"bounded roll backlog")
print("PASS: "..checks.." affix protocol checks (Lua 5.1)")

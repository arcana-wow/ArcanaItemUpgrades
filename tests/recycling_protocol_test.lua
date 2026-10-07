dofile("RecyclingProtocol.lua")
local P=ArcanaRecyclingProtocol
local checks=0
local function check(value) checks=checks+1;assert(value,"check "..checks) end
local rows,selected={},{}
for i=1,10 do
    rows[i]=P.Row(P.Split("ITEM\t1\t"..i.."\t0\t"..i.."\t123\t187\t101"))
    check(rows[i] and P.Add(selected,rows,i,i))
end
check(P.Selection(selected,rows)=="1,2,3,4,5,6,7,8,9,10")
check(not P.Add(selected,rows,1,1));selected[10]=nil
check(not P.Add(selected,rows,10,1));check(not P.Selection(selected,rows))
check(P.Add(selected,rows,10,10))
local quote="QUOTE\t1\t0123456789abcdef0123456789abcdef\t30\t1010\t505\t505\t1870\t0.2\t0.2\t0.2\t0.2\t0.2"
check(P.Quote(P.Split(quote),selected,rows,5).expires==35)
for _,bad in ipairs({"", "-1", "1x", "nan", "1e2", "4294967296"}) do
    check(not P.Integer(bad,4294967295))
end
for index=1,13 do
    local fields=P.Split(quote);fields[index]="invalid"
    check(not P.Quote(fields,selected,rows,0))
end
for index=1,8 do
    local fields=P.Split("ITEM\t1\t1\t0\t1\t123\t187\t0");fields[index]="invalid"
    check(not P.Row(fields))
end
for _,bad in ipairs({"ITEM\t1\t1\t0\t17\t123\t187\t0","ITEM\t1\t1\t5\t1\t123\t187\t0",
    "ITEM\t1\t1\t0\t1\t123\t186\t0","ITEM\t1\t0\t0\t1\t123\t187\t0"}) do check(not P.Row(P.Split(bad))) end
for copper=0,10001 do
    for i=1,10 do rows[i].price=0 end
    rows[1].price=copper
    local t=P.Totals(selected,rows)
    check(t.gold==math.floor(copper/2) and t.tax+t.gold==t.gross)
end
check(P.Money(123456)=="12g 34s 56c")
selected[10]=1;check(not P.Totals(selected,rows))
print("PASS: "..checks.." recycling protocol, identity, boundary and monetary checks")

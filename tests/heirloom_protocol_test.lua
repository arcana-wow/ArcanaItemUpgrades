dofile("HeirloomProtocol.lua")
local P=ArcanaHeirloomProtocol
local catalogue={
    [700001]={name="Bloodfang Chestpiece",source=16905,class=4,subclass=2,slot=5},
    [700002]={name="Thunderfury",source=19019,class=2,subclass=7,slot=21},
    [700003]={name="Warglaive",source=32837,class=2,subclass=7,slot=21},
}
local progress={[700001]={progress=0},[700002]={progress=100}}
assert(#P.Filter(catalogue,progress,"Unlocked","")==1)
assert(P.Filter(catalogue,progress,"Completed","")[1]==700002)
assert(P.Filter(catalogue,progress,"All","war")[1]==700003)
assert(#P.Filter(catalogue,progress,"Unlocked","",2)==0)
assert(P.Filter(catalogue,progress,"Unlocked","16905",4,2,5)[1]==700001)
local armor={
    [1]={name="Robe",source=1,class=4,subclass=1,slot=20},
    [2]={name="Vest",source=2,class=4,subclass=2,slot=5},
    [3]={name="Cloak",source=3,class=4,subclass=1,slot=16},
}
local discovered={[1]={progress=0},[2]={progress=0},[3]={progress=0}}
assert(#P.Filter(armor,discovered,"Unlocked","",4,"armor","chest")==2)
assert(P.Filter(armor,discovered,"Unlocked","",4,1,"chest")[1]==1)
assert(P.Filter(armor,discovered,"Unlocked","",4,nil,16)[1]==3)
assert(#P.Filter(catalogue,progress,"Unlocked","thunder")==0)
assert(#P.Filter(catalogue,progress,"Completed","blood")==0)
assert(#P.Filter(catalogue,progress,"All","")==3)
assert(#P.Filter(catalogue,progress,"All","%[")==0)
assert(P.Filter(catalogue,progress,"All","  ThUnDeR  ")[1]==700002)
local a,b=P.Preview(0,0,2);assert(a==6 and b==10)
a,b=P.Preview(99,0,100);assert(a==1 and b==1)
assert(not P.Preview(100,0,1))
assert(not P.Preview(0,5,2))
assert(not P.Preview(0,0,0))
assert(not P.Preview(0,0,1.5))
local id=string.rep("a",32)
local selection={request=2,kind=1,family=700001,quantity=2,source=0,original=0}
local fields=P.Split("QUOTE\t2\t"..id.."\t1\t700001\t0\t6\t10\t2\t0\t0\t30")
assert(P.Quote(fields,selection,10).expires==40)
for _,index in ipairs({2,4,5,7,8,9,10,11,12}) do
    local old=fields[index];fields[index]="9999999999"
    assert(not P.Quote(fields,selection,10));fields[index]=old
end
fields[3]="wrong";assert(not P.Quote(fields,selection,10))
local snapshot=P.Begin(P.Split("BEGIN\t5\t2\t1"),5)
assert(snapshot)
assert(P.Append(snapshot,P.Split("ROW\t5\t700001\t0\t0"),catalogue))
assert(not P.Append(snapshot,P.Split("ROW\t5\t700001\t0\t0"),catalogue))
assert(not P.Append(snapshot,P.Split("ROW\t5\t700002\t101\t1"),catalogue))
assert(P.Append(snapshot,P.Split("ROW\t5\t700002\t100\t1"),catalogue))
assert(not P.Complete(snapshot,P.Split("END\t5")))
assert(P.Append(snapshot,P.Split("ORIGINAL\t5\t700001\t42\t0\t1\t16905"),catalogue))
assert(P.Complete(snapshot,P.Split("END\t5")))
assert(not P.Complete(snapshot,P.Split("END\t6")))
assert(not P.Begin(P.Split("BEGIN\t5\t3794\t0"),5))
assert(not P.Id(string.rep("G",32)))
assert(P.Done(P.Split("DONE\t8\t1\t700001\t6\t2\t0"),catalogue))
assert(P.Done(P.Split("DONE\t8\t2\t700001\t100\t0\t123"),catalogue))
for _,message in ipairs({
    "DONE\t8\t1\t700001\t101\t2\t0",
    "DONE\t8\t1\t700001\t6\t0\t0",
    "DONE\t8\t2\t700001\t100\t1\t123",
    "DONE\t8\t2\t700001\t100\t0\t0",
    "DONE\t8\t1\t999999\t6\t2\t0",
    "DONE\t8\t1\t700001\tnan\t2\t0",
}) do assert(not P.Done(P.Split(message),catalogue)) end
print("Heirloom protocol: filtering, capped previews, quote binding and atomic snapshots passed")

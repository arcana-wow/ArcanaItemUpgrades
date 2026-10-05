dofile("AscensionProtocol.lua")
local P=ArcanaAscensionProtocol
local row=P.Row(P.Split("ITEM\t15\t12345\t9425\t44\t500000\t194700\t1"))
assert(row and row.slot==15 and row.ilvl==44 and row.count==1)
assert(P.Request(row)=="ASCEND\t15\t12345\t9425\t500000")
assert(P.Row(P.Split("ITEM\t0\t12345\t500001\t284\t0\t0\t0")))
for _,text in ipairs({
    "ITEM\t19\t12345\t9425\t44\t500000\t194700\t1",
    "ITEM\t-1\t12345\t9425\t44\t500000\t194700\t1",
    "ITEM\t15\t0\t9425\t44\t500000\t194700\t1",
    "ITEM\t15\t12345\t9425\t200\t500000\t194700\t1",
    "ITEM\t15\t12345\t9425\t44\t500000\t194705\t1",
    "ITEM\t15\t12345\t9425\t44\t0\t194700\t1",
    "ITEM\t15\t12345\t9425\t44\t500000\t0\t1",
    "ITEM\t15\t12345\t9425\t44\t500000\t194700\tnan",
    "ITEM\t15\t12345\t9425\t44\t500000\t194700\t1\textra",
}) do assert(not P.Row(P.Split(text)),text) end
for _,token in ipairs({194700,194701,194702,194703,194704}) do
    assert(P.Row(P.Split("ITEM\t0\t1\t2\t"..(P.Levels[token]-1).."\t500000\t"..token.."\t0")))
end
print("PASS: Ascension protocol, all tiers, invalid fields and exact instance requests")

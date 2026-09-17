-- The protocol keeps snapshots separate from item-entry caches. Two identical
-- item links can have different bonuses and must never share a cached result.
ArcanaAffixProtocol = {}
local P = ArcanaAffixProtocol
P.names = { [4]="Strength", [3]="Agility", [5]="Intellect", [6]="Spirit", [7]="Stamina",
    [38]="Attack Power", [45]="Spell Power", [32]="Crit Rating", [36]="Haste Rating", [44]="Armor Penetration Rating" }

function P.Split(text)
    local fields = {}
    for field in string.gmatch(text .. "\t", "([^\t]*)\t") do fields[#fields + 1] = field end
    return fields
end
function P.UInt(value)
    local n = tonumber(value)
    if n and n >= 0 and n <= 4294967295 and n == math.floor(n) then return n end
end
function P.Bag(value)
    local n = tonumber(value)
    if n and n >= -1 and n <= 11 and n == math.floor(n) then return n end
end
function P.BagKey(bag, slot)
    bag, slot = P.Bag(bag), P.UInt(slot)
    if bag and slot and slot >= 1 and slot <= 36 then return bag .. ":" .. slot end
end
function P.Entry(link)
    return type(link) == "string" and tonumber(string.match(link, "item:(%d+):")) or nil
end
function P.Describe(packed)
    packed = P.UInt(packed)
    if not packed or packed == 0 or math.floor(packed / 524288) ~= 1 then return nil end
    local stat, amount = packed % 64, math.floor(packed / 64) % 64
    if not P.names[stat] or amount == 0 then return nil end
    return "+" .. amount .. " " .. P.names[stat]
end
function P.Row(fields, offset)
    local row = { entry=P.UInt(fields[offset]), guid=P.UInt(fields[offset+1]),
        packed=P.UInt(fields[offset+2]), revision=P.UInt(fields[offset+3]) }
    if row.entry and row.guid and row.packed and row.revision then return row end
end
function P.New()
    return { building={}, queues={}, slots={}, bags={}, syncSlots=nil, syncBags=nil }
end
function P.Receive(state, message)
    local f = P.Split(message)
    local completedContext
    if f[1] == "BEGIN" then
        local context, sequence = P.UInt(f[2]), P.UInt(f[3])
        if context and context <= 5 and sequence then
            -- One snapshot per context can be in flight on the ordered chat stream.
            for oldSequence, old in pairs(state.building) do
                if old.context == context then state.building[oldSequence] = nil end
            end
            state.building[sequence] = { context=context, rows={}, count=0 }
        end
    elseif f[1] == "C" then
        local snapshot, index = state.building[P.UInt(f[2]) or -1], P.UInt(f[3])
        local row = P.Row(f, 4)
        if snapshot and index and index <= 20000 and row and snapshot.count < 1000 then
            row.identity = f[8]
            snapshot.rows[index] = row
            snapshot.count = snapshot.count + 1
        end
    elseif f[1] == "END" then
        local sequence = P.UInt(f[2]) or -1
        local snapshot = state.building[sequence]
        if snapshot then
            state.building[sequence] = nil
            local queue = state.queues[snapshot.context] or {}
            state.queues[snapshot.context] = queue
            queue[#queue+1] = snapshot.rows
            if #queue > 64 then table.remove(queue, 1) end
            completedContext = snapshot.context
        end
    elseif f[1] == "SYNC" then
        state.syncSlots, state.syncBags = {}, {}
    elseif f[1] == "E" and state.syncSlots then
        local slot, row = P.UInt(f[2]), P.Row(f, 3)
        if slot and slot <= 18 and row then state.syncSlots[slot] = row end
    elseif f[1] == "B" and state.syncBags then
        local key, row = P.BagKey(f[2], f[3]), P.Row(f, 4)
        if key and row then state.syncBags[key] = row end
    elseif f[1] == "DONE" and state.syncSlots then
        state.slots, state.bags = state.syncSlots, state.syncBags
        state.syncSlots, state.syncBags = nil, nil
    end
    return f, completedContext
end
function P.Take(state, context)
    local queue = state.queues[context]
    if queue and #queue > 0 then return table.remove(queue, 1), true end
    return {}, false
end
function P.ClearContext(state, context)
    state.queues[context] = nil
    for sequence, snapshot in pairs(state.building) do
        if snapshot.context == context then state.building[sequence] = nil end
    end
end
function P.Matches(row, link)
    return row and row.entry ~= 0 and row.entry == P.Entry(link)
end

-- The native client may sort its auction page locally. Match the complete
-- visible identity; an indistinguishable pair with different bonuses is never
-- assigned another row's value merely because its list index matches.
function P.AuctionKey(link, count, minimum, buyout, bid, owner)
    if not link or not owner then return nil end
    local payload = string.match(link, "item:([^|]+)")
    if not payload then return nil end
    local key, n = {}, 0
    for field in string.gmatch(payload .. ":", "([^:]*):") do
        n = n + 1
        if n <= 8 then key[n] = tostring(tonumber(field) or 0) end
    end
    if n < 8 then return nil end
    key[9], key[10], key[11], key[12], key[13] = count, minimum, buyout, bid, owner
    return table.concat(key, ":")
end
function P.AuctionRow(rows, identity)
    if not identity then return nil end
    local match
    for _, row in pairs(rows or {}) do
        if row.identity == identity then
            if match and match.packed ~= row.packed then return nil, true end
            match = row
        end
    end
    return match, false
end

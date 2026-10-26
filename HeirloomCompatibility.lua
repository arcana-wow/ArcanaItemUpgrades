-- Wrath's Lua color table stops at quality 6, although the client supports
-- heirlooms (7). Native LootFrame needs this entry before it can finish drawing
-- the reward and assign its clickable slot. Preserve any existing UI override.
if not ITEM_QUALITY_COLORS[7] then
    local r, g, b, hex = GetItemQualityColor(7)
    ITEM_QUALITY_COLORS[7] = { r = r, g = g, b = b, hex = hex }
end

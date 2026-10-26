-- Exercise the native loot-window ordering that caused the recorded failure:
-- icon/name first, color lookup, click slot/show, then unused buttons/pagination.
-- Reference: https://github.com/tekkub/wow-ui-source/blob/3.3.5/FrameXML/LootFrame.lua
local checks = 0
local function check(value, label)
    checks = checks + 1
    assert(value, label)
end
ITEM_QUALITY_COLORS = {}
for quality = -1, 6 do
    ITEM_QUALITY_COLORS[quality] = { r = quality, g = 0, b = 0, hex = "existing" }
end
local originalColors = {}
for quality, color in pairs(ITEM_QUALITY_COLORS) do originalColors[quality] = color end
local queries = 0
function GetItemQualityColor(quality)
    check(quality == 7, "query the native heirloom color")
    queries = queries + 1
    return 0.9, 0.8, 0.5, "ffe6cc80"
end
local window
local function ResetWindow()
    window = { page = 1, previous = true, next = true, buttons = {} }
    for index = 1, 4 do window.buttons[index] = { shown = true } end
end
local function Render(quality)
    for index, button in ipairs(window.buttons) do
        local slot = (window.page - 1) * 4 + index
        if slot == 1 then
            button.icon, button.name = "reward-icon", "Heirloom reward"
            local color = ITEM_QUALITY_COLORS[quality]
            button.color = { color.r, color.g, color.b }
            button.slot, button.quality, button.shown = slot, quality, true
        else
            button.shown = false
        end
    end
    window.previous = window.page ~= 1
    window.next = window.page ~= 1
end
ResetWindow()
check(not pcall(Render, 7), "stock quality table reproduces the Lua error")
check(window.buttons[1].name == "Heirloom reward" and not window.buttons[1].slot,
    "partly drawn reward has no click slot")
check(window.buttons[2].shown and window.next, "error leaves phantom controls")
window.page = 2; Render(7)
window.page = 1
check(not pcall(Render, 7) and not window.buttons[1].shown,
    "paging hides the item and returning cannot restore it")

-- Load through the real manifest so omission/load-order regressions fail too.
local toc = assert(io.open("ArcanaItemUpgrades.toc"))
local first
for line in toc:lines() do
    if line:match("%.lua$") then first = line; break end
end
toc:close()
check(first == "HeirloomCompatibility.lua", "compatibility loads before addon UI")
dofile(first)
check(queries == 1 and ITEM_QUALITY_COLORS[7].hex == "ffe6cc80", "use the full native color")
for quality, color in pairs(originalColors) do
    check(ITEM_QUALITY_COLORS[quality] == color, "preserve ordinary quality colors")
end
local nativeColor = ITEM_QUALITY_COLORS[7]
dofile(first)
check(queries == 1 and ITEM_QUALITY_COLORS[7] == nativeColor, "idempotent loading")
for _,action in ipairs({"recover hidden reward", "reopen", "next satchel", "relog"}) do
    if action == "relog" then ResetWindow() end
    window.page = 1
    Render(7)
    check(window.buttons[1].shown and window.buttons[1].slot == 1, action .. " stays lootable")
    check(window.buttons[1].quality == 7 and window.buttons[1].color[1] == 0.9,
        action .. " preserves real heirloom quality and native color")
    check(not window.buttons[2].shown and not window.previous and not window.next,
        action .. " hides unused controls")
end
-- If another addon already supplies the color, respect that exact object.
local custom = { r = 0.2, g = 0.3, b = 0.4, hex = "ff334d66" }
ITEM_QUALITY_COLORS[7] = custom
dofile(first)
check(queries == 1 and ITEM_QUALITY_COLORS[7] == custom, "preserve another addon's color")
Render(3)
check(window.buttons[1].quality == 3 and window.buttons[1].color[1] == 3,
    "ordinary rare loot is unchanged")
print("Heirloom loot compatibility: " .. checks .. " checks passed")

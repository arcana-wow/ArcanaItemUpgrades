# ArcanaItemUpgrades

## Recycling (1.11.0)

The Recycle tab accepts exactly ten carried equipment items of current ilvl 187
or higher at level 80. Drag an item from a bag into an empty slot, or click an
empty slot to choose from compatible inventory items. Right-click a filled slot
to remove it. Different copies of the same item are tracked separately.

Total vendor value, the 50% recycling tax and the gold returned are displayed
before confirmation. Rewards arrive inside an **Arcana Salvage Satchel**. Open it
from your bags to collect gold and any successful independent bonus rolls:
50% Tempering, 15% Recalibration and 15% Ascension. Expand the Ascension tier odds
to see how the selected items' average ilvl affects the five possible tiers.

Recycling destroys the selected items and their gems, enchants, Tempering and
Affixes. A quote lasts 30 seconds and is invalidated by inventory changes.
The addon checks the saved result after a missed reply or reload, so reconnecting
does not submit another batch. Timed Tempering rewards expire 24 hours after
recycling even while the satchel is unopened. Full bags or the gold cap leave
unclaimed contents inside the satchel.

Run `lua5.1 tests/recycling_protocol_test.lua` and
`lua5.1 tests/recycling_ui_test.lua` from this addon directory. CI also runs all
existing item-service Lua suites. Actual UI scale and native bag-addon dragging
still require review in the 3.3.5a client.

The optional World of Warcraft 3.3.5a companion UI for Arcana's server-side
item upgrade system.

## Features

- Adds a draggable Arcane Focus minimap shortcut and saves its position.
- Uses a 3.3.5a-compatible addon-message initialization path and retries
  minimap-button installation after entering the world.
- Adds a compact, top-layer **Upgrades** shortcut to the character sheet.
- Lists eligible equipped items and their server-owned rank from 0/5 to 5/5.
- Uses a bounded scrolling list that cannot overlap the footer at maximum
  equipment capacity.
- Provides one **Upgrade** button, followed by an exact choice between every
  available payment item. Each choice shows the consumed item's full server
  name, quality color, icon, count, and normal item tooltip. The always-visible
  icon and full source name are centered together within the choice button, and
  an open chooser follows selection changes.
- Confirms every consumption, with a stronger confirmation for a Legendary
  token that jumps an item directly to 5/5.
- Adds the rank, distinct stat and armor bonuses, and server-calculated
  effective armor, stats, resistances, block, and weapon damage to upgraded
  equipped-item tooltips.
- Synchronizes automatically after entering the world, equipment changes, and
  successful addon or NPC upgrades, with bounded retries so tooltips do not
  depend on opening the upgrade panel.
- Supports `/upgrades` and `/itemupgrades`.

The addon never calculates or writes a rank. It sends a request to the realm,
which revalidates the equipped item, payment item, expiry, rank, combat state,
and location before applying an upgrade.

Remote upgrades are available only while the character is alive, out of
combat, and outside dungeons, raids, battlegrounds, and arenas. The Item
Upgrader NPC in major cities is the full fallback and does not require this
addon.

## Install

Copy the `ArcanaItemUpgrades` directory into the client's `Interface/AddOns`
directory so this file exists:

```text
Interface/AddOns/ArcanaItemUpgrades/ArcanaItemUpgrades.toc
```

Fully restart the client after first installation. Open the panel with the
minimap button, character-sheet button, or `/upgrades`.

## Compatibility

- Client interface: `30300` (Wrath of the Lich King 3.3.5a).
- Server: Arcana's `arcana-mod-item-upgrader` module and its addon bridge.
- Protocol prefix: `AUI` over a self-whisper addon message.

Ordinary clients without this addon remain fully supported through the NPC.

## Protocol

Client requests:

```text
CMD<TAB>SYNC
CMD<TAB>UPGRADE<TAB>equipment-slot<TAB>UNCOMMON_MATCH|RARE_WILD|EPIC_MATCH|EPIC_WILD|DUP|LEGEND
```

Server replies are framed with `BEGIN` and `END`; `BEGIN` carries the maximum
rank plus the distinct general-stat and armor percentages per rank. Each `SLOT`
line contains the equipped entry, authoritative rank, family, exact payment
counts, and the item entry represented by each payment choice. `STAT`, `VALUE`,
and `DAMAGE` lines
contain authoritative base and effective item values. `RESULT` and `ERROR`
carry the player-facing outcome. The server consumes the control messages so
they are never relayed as chat.

## Repository and releases

This addon intentionally lives in its own private repository in the Arcana
GitHub organization. Tagged release archives must contain one top-level
`ArcanaItemUpgrades` directory ready to extract into `Interface/AddOns`.

## Security boundary

The UI is convenience only. Editing Lua state or crafting addon messages does
not bypass server checks. The module is the sole authority for ranks, token
ownership, token expiry, eligible slots, and payment consumption.

## Arcana bonuses and recalibration (1.6)

The equipment panel includes a Recalibrate button for the separate random
bonus, including bonus-eligible relics with no native upgradable stats. A
confirmation captures the exact equipped item and its bonus revision. The
server consumes one permanent Arcana Recalibration Sigil after committing the
replacement. The next stat is different and its amount may be lower.

The AAF self-whisper protocol supplies per-instance bonuses for bags,
equipment, bank, buyback, trade, inspection, loot, rolls, mail and auctions.
Bonuses appear as green `+N Stat` text in the enchant area, immediately above
a permanent native enchant when present and before sockets, durability or
requirements. Enchant placement starts below the localized equipment-type row,
so green Heroic/header labels stay at the top. Red profession/runeforging
enchants are recognized by their localized enchant requirement. The renderer
extends a native left-hand text row; existing right-hand prices, wrapped set
text and socket font strings retain their contents and anchors.

An unchanged hover reuses its resolved bonus through native tooltip rebuilds.
Equipment, bags and bank slots use one current authoritative synchronization.
If a newly moved bag item is hovered before that synchronization completes, an
invisible reserved line prevents the tooltip from changing height while its
exact instance reply arrives. Cold inspection hovers reserve the same space.
Other items are cached only for the exact tooltip context and slot, never by
item entry or link alone. Inventory, equipment, bank, buyback and trade events
invalidate those contexts; rerolls refresh an open tooltip. In-flight requests
are deduplicated and expire after five seconds.

Opening the native inspection window preloads at most 17 equipped slots,
excluding shirt and tabard, at one request per 100 ms. Native links that arrive
late can join this initial pass for five seconds; there is no repeated full-gear
refresh. The existing AAF server protocol supplies authoritative bonuses from
memory without a new server build or database query. Preloads and hovers share
requests and a cache bound to the open window, character GUID, equipment slot,
and complete item link. A reply may warm an unhovered slot but cannot draw on
another item or reopen a hidden tooltip. Closing inspection, changing character,
or an inventory event for the inspected character clears those cached instances.
Inventory events cannot reset that opening's 17-request preload budget.

Inspection retains its binding through native `SetOwner` hide/rebuild cycles.
Leaving a slot clears the tooltip binding while the open window can retain its
reply for up to 30 seconds. Hovering a cached slot displays the last confirmed
value immediately and revalidates it after one second; rejected replies clear
it with bounded retry backoff. Other inspection providers without a native
window use the existing per-hover lifecycle. A cold first hover can still wait
for a server round trip. Snapshot publication is order-independent:
a complete loot, mail or auction snapshot is paired with its native window
whether the addon message or the native UI event arrives first. Loot tooltips
retain an owner- and window-bound slot across native tooltip clears, asynchronous
item-data completion, page updates, and loot-slot changes. A delayed redraw can
therefore restore the same bonus without another mouse movement, while closing
the corpse, clearing the slot, or changing tooltip context invalidates that
retained view. If another auction addon raises an extra or delayed result event
after that one-shot snapshot has been consumed, hovering a listing requests
that exact visible identity from the server's bounded current-page cache.
Replies are tied to the current auction-page epoch, so a delayed reply cannot annotate a replacement
page.

The stock auction API cannot distinguish listings with identical native item
links, seller and prices. If their bonuses differ, the addon displays an
ambiguity message rather than another listing's bonus.

Run lua5.1 tests/affix_protocol_test.lua and lua5.1 tests/affix_ui_test.lua from
this repository. Actual client rendering requires an in-game check.

### Tooltip regression checks (1.6.8)

CI runs the protocol and UI suites under Lua 5.1 and includes all three Lua
files in the install archive. The UI model clears and rebuilds native tooltip
font strings on every `Set*` call. It covers enchant placement, repeated
rebuilds, same-link items in different slots, inventory invalidation, rerolls,
stale/duplicate/expired replies, request deduplication, inspection, snapshots,
localized boundaries, socket anchors, permanent-enchant ordering, synchronized
bag and bank bonuses, late loot completion, closed-context rejection, paged
duplicate loot items, native loot-tooltip rebuilds, cold-cache item data,
loot-slot changes, owner and same-link context isolation, early and late auction
snapshots, replacement auction pages, exact auction recovery after duplicate
result events, stale recovery rejection, both persisted stat-policy versions,
and native/third-party text preservation. Inspection regressions also model
`SetOwner` hide/rebuild cycles, delayed replies at low level and level 80,
background revalidation and rejection backoff, genuine leave/close, hidden
replies, identical links on different bots or slots, inventory replacement,
timeouts and transitions back to the owner's equipment. Coverage also includes
Heroic/localized headers, red enchants, reserved inspection space, shared preload
requests, immediate warm hovers, cache age, identical links in separate slots,
window/character/equipment invalidation, cold links, expired preload replies,
and the 17-slot/rate/startup bounds. Actual tooltip sizing
and interaction with installed addons still require an in-game check. Restart
the client after installing an update.

### 1.6.9: colored armor tooltip placement

Native armor values stay with the base item stats even when shown in green.
Arcana bonus lines appear after those stats and before enchantments. Localized
armor templates, cold-cache placeholders and repeated tooltip rebuilds are
covered by the Lua 5.1 UI regressions.

### 1.7.0: exact-instance upgrade tooltips

Equipment, bag and bank upgrade tooltips request the exact owned position with
`CMD<TAB>ITEM<TAB>request<TAB>E|B<TAB>first<TAB>second<TAB>expected-entry`.
Inventory positions are native client slots 1–74 with second=0; bag positions use the
native bag ID and one-based slot (including bank bag -1). The server resolves
ownership and eligibility, reads the rank by GUID, and returns `IBEGIN` with
request, GUID, entry, rank, maximum rank, stat percent and armor percent.
Existing STAT/VALUE/DAMAGE rows use `I<request>` instead of equipment slot;
`IEND` publishes the complete result. `IMISS` represents unavailable/ineligible
items, not rank zero. Requests are limited to 20 per second per player.

Identical native links never share results across positions. Equipment/bag/bank
changes, upgrade syncs and level changes invalidate pending and cached values.
Delayed replies cannot annotate a moved item, another hover, or a closed tooltip.
Requests expire after five seconds with at most three attempts per unchanged
position. Unknown tooltips and other players do not borrow owned-item ranks.
BEGIN advertises tooltip protocol version 2 in its fifth field. No hover
requests are sent before that capability is received. This requires the
corresponding server module update; old servers safely leave
upgrade tooltip information unavailable. The equipped-item upgrade panel and
NPC operations retain their existing protocol. Run `lua5.1 tests/upgrade_tooltip_test.lua`
alongside the existing affix suites before packaging.


## Three upgrade tabs (1.8.0)

Open `/upgrades`, or choose **Item Upgrades** in ArcanaPartyDraft. **Tempering**
raises the existing rank; **Affixes** recalibrates the independent bonus;
**Ascension** raises item level through 200, 226, 245, 264 and 284. Select an
equipped item, hover the next-tier preview, then confirm its token cost.
Ascension requires level 80 and a safe location outside instances and combat.
The Item Upgrades NPC supplies all three services and sells the tokens.

Install the matching Ascension `patch-4.MPQ` while the client is closed. Native
item links and inspection then show ascended stats, art, sockets and procs.
The addon also resolves mixed-tier set bonuses from the realm for self and
nearby inspection tooltips; cached responses are bounded and stale/spoofed
responses are discarded. Server confirmation always validates the exact item.

Run all `tests/*_test.lua` with Lua 5.1. The Ascension tests cover all tiers,
three-tab behavior, confirmation, eligibility, stale selection/replies,
timeouts, mixed-set descriptions and inspection ownership.

## Catalogue and clarity update (1.9.0)

The Affixes list shows the actual bonus and Ascension shows only each equipped
item's current ilvl. Its token instruction is a clickable item link, with no
owned-count label. Missing payment still disables Ascend Item.

In Ascension, type a name or item ID in Search. As of 1.9.1, at least one
non-whitespace character is required; an empty field sends no request. Results show
original items, including named native suffix variants. Hover previews the next
eligible tier; click opens a scrollable original/all-tier comparison. Set
descriptions come from the server's scaled set mapping. Previews omit personal
Tempering and Arcana affixes. Use Results to return to the list and My equipment
to return to the upgrade controls.

Search waits 500 ms after typing stops. Pages contain 20 results. Search and
detail requests share a 550 ms client spacing and an independent server limit
of two requests per second. Both caches are limited to 64 entries and reset on
world entry; stale, partial and foreign replies never populate the view.

Requires the matching catalogue-enabled server modules. The Ascension MPQ and
ArcanaPartyDraft 0.19.1 are unchanged. All eight Lua test scripts run in CI.

### 1.9.1: compact upgrade controls and catalogue navigation

Each tab describes the selected item's eligibility. Temper Item and Recalibrate
Item are centered directly beneath those details; Affixes shows only its sigil
counter there, while the equipment rows retain their actual bonus values.
Unavailable Tempering items are labeled consistently in the row and selection.

Search is below Ascend Item. Its results contain original item names only, with
an X to return to equipment from either the results or comparison. Double-click
an equipped item in Ascension to open its original/all-tier comparison directly;
the exact native suffix family is retained. Comparison cards copy native socket
graphics, including meta sockets, beside the localized socket labels. Search
retains its 500 ms debounce, shared rate limit, bounded caches and stale-response
checks. Clearing/closing the search cancels pending requests and previews.
Background refreshes leave unrelated equipment tooltips open.

Only clicking the required token's name opens its item tooltip. Hovering that
name or the surrounding instruction does nothing. Payment confirmations and
server validation remain authoritative. Actual rendering still needs in-game
review at the owner's UI scale.

### 1.10.0 — comparisons and permanent equip stats

Search results and comparison cards use solid backgrounds. Results preview the
original item on hover; click to view all versions. Double-clicking equipped
items opens comparison directly without changing the search field. Clearing
the field cancels the search while preserving focus; clicking outside or Escape
releases it. Shift-clicking an item while focused inserts its name and performs
an exact item-ID lookup through the existing 500 ms debounce and bounded cache.
Focus survives the native Shift-click mouse press until the item link is inserted
on release; modified clicks outside that insert no item still release focus.

The unchecked-by-default **Compare items** box beside the preview button enables
current equipment on the left and the next Ascension template on the right. The
current tooltip includes personal enchants, gems, Affixes and Tempering; the next
version is a base template preview. Closing, switching tabs or leaving the button
hides both. Selected headings contain only the item name, with feature-specific
eligibility and explicit rank-5/item-level-284 completion messages below.

Tempering tooltips accept the realm's permanent equip-stat projection, including
Attack Power effects on original trinkets. The server applies the same cached
effect mask to eligibility, effective-value reporting and aura scaling.

### 1.10.1 — concise confirmations

Ascension confirmation shows the selected item, destination item level and exact
Ascension token consumed. Recalibration confirmation shows the selected item and
its current bonus stat and amount. This is an addon-only text update; the server
protocol and payment validation are unchanged.

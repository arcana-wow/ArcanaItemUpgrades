# ArcanaItemUpgrades

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
requirements. The renderer
extends a native left-hand text row; existing right-hand prices, wrapped set
text and socket font strings retain their contents and anchors.

An unchanged hover reuses its resolved bonus through native tooltip rebuilds.
Equipment, bags and bank slots use one current authoritative synchronization.
If a newly moved bag item is hovered before that synchronization completes, an
invisible reserved line prevents the tooltip from changing height while its
exact instance reply arrives. Other items are cached only for the exact tooltip
context and slot, never by item entry or link alone. Inventory, equipment, bank,
buyback and trade events
invalidate those contexts; rerolls refresh an open tooltip. In-flight requests
are deduplicated, expire after five seconds and reject replies for replaced or
hidden tooltips. Inspection revalidates after one second while retaining the
previous reply during the request. Snapshot publication is order-independent:
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

### Tooltip regression checks (1.6.6)

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
and native/third-party text preservation. Actual tooltip sizing and interaction
with installed addons still require an in-game check. Restart the client after installing an update.

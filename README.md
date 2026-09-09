# ArcanaItemUpgrades

The optional World of Warcraft 3.3.5a companion UI for Arcana's server-side
item upgrade system.

## Features

- Adds an **Item Upgrades** shortcut to the character sheet.
- Lists eligible equipped items and their server-owned rank from 0/5 to 5/5.
- Shows matching-token, wildcard-token, duplicate, and Legendary-token counts.
- Confirms every consumption, with a stronger confirmation for a Legendary
  token that jumps an item directly to 5/5.
- Adds `Arcana Upgrade: 3/5 (+15%)` to equipped-item tooltips.
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
character-sheet button or `/upgrades`.

## Compatibility

- Client interface: `30300` (Wrath of the Lich King 3.3.5a).
- Server: Arcana's `arcana-mod-item-upgrader` module and its addon bridge.
- Protocol prefix: `AUI` over a self-whisper addon message.

Ordinary clients without this addon remain fully supported through the NPC.

## Protocol

Client requests:

```text
CMD<TAB>SYNC
CMD<TAB>UPGRADE<TAB>equipment-slot<TAB>MATCH|WILD|DUP|LEGEND
```

Server replies are framed with `BEGIN` and `END`; each `SLOT` line contains the
equipped entry, authoritative rank, family, and available payment counts.
`RESULT` and `ERROR` carry the player-facing outcome. The server consumes the
control messages so they are never relayed as chat.

## Repository and releases

This addon intentionally lives in its own private repository in the Arcana
GitHub organization. Tagged release archives must contain one top-level
`ArcanaItemUpgrades` directory ready to extract into `Interface/AddOns`.

## Security boundary

The UI is convenience only. Editing Lua state or crafting addon messages does
not bypass server checks. The module is the sole authority for ranks, token
ownership, token expiry, eligible slots, and payment consumption.

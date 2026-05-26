# Nightwatch — Changelog

## [2026.05.26] — Alpha

### Fixed
- **Config → Settings** — Font size slider no longer crashes on repeated Settings panel visits; lazy-init via `EnsureFontSizeSlider` with unnamed frame
- **Config → Settings** — Font dropdown list now reserves full list height below the button so font size slider is never overlapped
- **Config → Bottom bar** — Total Gold now correctly reflects the active realm filter (`All Realms` / `This Realm`)
- **Config → Character Summary** — Removed duplicate character count label from panel header (count shown in bottom bar only)
- **Config → Profession Skills tooltip** — Expansion sort order now uses explicit priority table (Midnight → Khaz Algar → Dragon Isles → … → Classic) instead of unreliable skillLine ID ordering

### Changed
- **Config → Nav sidebar** — Arrow symbols removed from parent nav buttons
- **Config → Nav sidebar** — Parent nav items styled gold (`FFD200`), child items white; AuctionHouse atlas textures (`auctionhouse-nav-button`, `auctionhouse-nav-button-secondary`) used for background and selection states
- **Config → Nav sidebar** — All label, header, and bottom bar text brightened for legibility
- **Config → Currencies** — Rebuilt entirely: nav now has `Midnight`, `Miscellaneous`, and `PvP` children; each loads a dedicated panel
- **Config → Currencies → Midnight** — Dawncrest crest panel: faction icon, class color bar, Name, Lvl, then one icon column per crest tier (Adventurer → Veteran → Champion → Hero → Myth). No cap display (cap removed by Blizzard). Column icons and amounts centered within each column.
- **Config → Currencies → Miscellaneous** — Trader's Tender, Timewarped Badge. Same row layout as Midnight panel.
- **Config → Currencies → PvP** — Honor, Conquest. Same row layout as Midnight panel.
- **Collector** — Currency snapshot replaced: static `TRACKED_CURRENCIES` table removed; now performs a full dynamic scan via `C_CurrencyInfo.GetCurrencyListSize()` + `C_CurrencyInfo.GetCurrencyListInfo(index)`. Captures all current and future currencies automatically with no maintenance.
- **Collector** — Added `CURRENCY_DISPLAY_UPDATE` event handler to re-snapshot currencies immediately when any currency amount changes in-game

## [2026.05.24] — Alpha

### Added
- **Core** — NW namespace, DB init, login callback chain, slash commands (`/nw`, `/nw debug`, `/nw prof`)
- **Collector** — Per-character snapshot on login: inventory (bags 0-4), reagent bag, character bank, warbank, currencies, gold, level, iLevel, zone, faction, rested XP
- **Collector** — Profession snapshot using `GetProfessions()` as primary source with full expansion breakdown via `GetAllProfessionTradeSkillLines()`. Totals pre-computed at snapshot time. Expansion data refreshed on `TRADE_SKILL_SHOW` (debounced via `SKILL_LINES_CHANGED`)
- **Minimap** — Minimap button with drag, right-click menu, angle persistence
- **Debug** — Scrollable debug log frame (`/nwdebug`), Clear and Select All buttons
- **Tooltip** — Item tooltip injection via `TooltipDataProcessor` showing per-character counts (bags, reagent bag, bank, warbank) with modifier key gate (ALT/CTRL/SHIFT, configurable in Settings)
- **Config** — Main UI (820×570) with expandable sidebar nav, realm filter toggle, bottom status bar (Characters / Realms / Total Gold)
- **Config → Character Summary** — Faction icon, class-colored name, level, rested XP %, equipped iLevel, gold, last login date. Zebra striping, class color bar.
- **Config → Profession Skills** — Per-character row with faction icon, name, level, primary prof 1 & 2 (icon + total skill/max), secondary profs (Cooking/Fishing/Archaeology) as icon-only columns. Hover tooltip shows full expansion breakdown (live for current character, stored snapshot for offline characters).
- **Config → Currencies** — Grouped by expansion. Icon per currency, account-wide shown once, capped highlighted red.
- **Config → Inventory** — Search box with 0.4s debounce, searches bags/reagent/bank/warbank across all characters.
- **Config → Settings** — Theme swatches (7 themes), font dropdown (LibSharedMedia), font size slider, tooltip modifier radio buttons (ALT/CTRL/SHIFT), minimap toggle, character visibility management.
- **Nav state** — Expand/collapse persisted in `NightwatchDB.settings.navExpanded`

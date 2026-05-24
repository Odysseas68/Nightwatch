# Nightwatch — Changelog

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

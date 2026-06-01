# Nightwatch — Changelog

## [2026.06.01] — Alpha

### Added
- **Tooltip** — Guild bank counts in item tooltip: per-guild section in orange (`F6AD55`) with per-tab breakdown, included in grand total
- **Tooltip** — `NONE` modifier option added — tooltip always shows without requiring a key held
- **Collector** — Guild bank scanning: `SnapshotGuildBank()` scans all viewable tabs on `GUILDBANKFRAME_OPENED` (0.5s delay) and `GUILDBANKBAGSLOTS_CHANGED`. Stored at `NW.db.guildbanks["GuildName-Realm"]`
- **Collector** — Live personal bank updates: `BAG_UPDATE` for character bank bag IDs (6-11) triggers `SnapshotBank()` (debounced 0.5s)
- **Collector** — `guild` field added to character snapshot — stores guild name at login via `IsInGuild()` + `GetGuildInfo("player")`
- **Config → Settings** — `NONE` added to tooltip modifier radio buttons
- **Config → Settings** — Split into three sub-panels: `General`, `Characters`, `Guilds`
- **Config → Settings → General** — Theme swatches, font dropdown + size slider, tooltip modifier, minimap toggle
- **Config → Settings → Characters** — Checkbox show/hide per character + Remove button (deletes character from DB, updates totals live)
- **Config → Settings → Guilds** — Checkbox show/hide guild bank data + Remove button with `StaticPopup` confirmation (wipes guild bank + all characters from that guild)
- **Config → Inventory** — Column headers (Item / Location / Type / Count) with divider line; guild bank included in search results; `NONE` modifier in Settings
- **Core** — `hiddenGuilds` added to settings defaults: `{ ["GuildName-Realm"] = true }` to hide guild bank from tooltip and inventory search

### Fixed
- **Collector** — Warbank data wiped on reload: `BAG_UPDATE` fires for warbank bag IDs at login even when bank is closed; now gated with `C_Bank.AreAnyBankTypesViewable()`
- **Collector** — `BANKFRAME_OPENED` incorrectly triggered warbank rescan when guild bank opened; now uses `C_Bank.FetchViewableBankTypes()` to confirm warbank is viewable
- **Tooltip** — Warbank showing stale/wrong counts from old per-character data; now reads from account-level `NW.db.warbank`
- **Tooltip** — Personal bank counts not updating live; now updates on `BAG_UPDATE` for bank bag IDs
- **Config → Settings → General** — Selecting a tooltip modifier or theme swatch was navigating back to the Settings placeholder instead of staying on General

### Changed
- **Core** — `warbank`/`warbankTabs` moved to top-level `NightwatchDB` (account-wide). Migration on first load. `trackedCurrencies` stale key removed. `navExpanded` added to defaults.
- **Collector** — `SnapshotWarbank()` writes to `NW.db.warbank`/`NW.db.warbankTabs`; removed from `NewCharEntry` skeleton
- **Tooltip** — `GetItemCounts()` reads warbank from `NW.db.warbank`; guild bank from `NW.db.guildbanks`; blank separator lines before Account Warbank and Guild Bank sections; respects `hiddenGuilds`
- **Config → Inventory** — Custom `EditBox` replaces `SearchBoxTemplate` — larger, midnight-themed, focus glow, `Esc` to clear and unfocus; warbank shows as `Account Warbank` in cyan; guild bank rows in orange; realm shown in Location column when All Realms active; warbank search reads from `NW.db.warbank`; guild bank search respects `hiddenGuilds`
- **Config → Settings → General** — Removed wasted space below font dropdown (list is a floating overlay, no layout reservation needed)

---

## [2026.05.26] — Alpha

### Fixed
- **Config → Settings** — Font size slider no longer crashes on repeated Settings panel visits; lazy-init via `EnsureFontSizeSlider` with unnamed frame
- **Config → Settings** — Font dropdown list now reserves full list height below the button so font size slider is never overlapped
- **Config → Bottom bar** — Total Gold now correctly reflects the active realm filter (`All Realms` / `This Realm`)
- **Config → Character Summary** — Removed duplicate character count label from panel header (count shown in bottom bar only)
- **Config → Profession Skills tooltip** — Expansion sort order now uses explicit priority table (Midnight → Khaz Algar → Dragon Isles → … → Classic) instead of unreliable skillLine ID ordering

### Changed
- **Config → Nav sidebar** — Arrow symbols removed from parent nav buttons
- **Config → Nav sidebar** — Parent nav items styled gold (`FFD200`), child items white; AuctionHouse atlas textures used for background and selection states
- **Config → Nav sidebar** — All label, header, and bottom bar text brightened for legibility
- **Config → Currencies** — Rebuilt entirely: nav now has `Midnight`, `Miscellaneous`, and `PvP` children; each loads a dedicated panel
- **Config → Currencies → Midnight** — Dawncrest crest panel: faction icon, class color bar, Name, Lvl, then one icon column per crest tier (Adventurer → Veteran → Champion → Hero → Myth). No cap display. Column icons and amounts centered.
- **Config → Currencies → Miscellaneous** — Trader's Tender, Timewarped Badge. Same row layout as Midnight panel.
- **Config → Currencies → PvP** — Honor, Conquest. Same row layout as Midnight panel.
- **Collector** — Currency snapshot replaced: static `TRACKED_CURRENCIES` table removed; full dynamic scan via `C_CurrencyInfo.GetCurrencyListSize()` + `GetCurrencyListInfo()`. Captures all current and future currencies automatically.
- **Collector** — Added `CURRENCY_DISPLAY_UPDATE` event handler to re-snapshot currencies immediately when any amount changes

---

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
- **Config → Profession Skills** — Per-character row with faction icon, name, level, primary prof 1 & 2 (icon + total skill/max), secondary profs (Cooking/Fishing/Archaeology) as icon-only columns. Hover tooltip shows full expansion breakdown.
- **Config → Currencies** — Grouped by expansion. Icon per currency, account-wide shown once, capped highlighted red.
- **Config → Inventory** — Search box with 0.4s debounce, searches bags/reagent/bank/warbank across all characters.
- **Config → Settings** — Theme swatches (7 themes), font dropdown (LibSharedMedia), font size slider, tooltip modifier radio buttons (ALT/CTRL/SHIFT), minimap toggle, character visibility management.
- **Nav state** — Expand/collapse persisted in `NightwatchDB.settings.navExpanded`

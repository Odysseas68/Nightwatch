# Nightwatch — Claude Code Context

## Project Overview
A WoW Retail addon (Retail 12.0+) for tracking characters, currencies, gold, and inventory across all alts and realms. Data is collected per-character on login and stored in a shared AccountWide SavedVariables table for browsing from any character.

**Tagline:** "All your alts, under one moon"
**SavedVariables:** `NightwatchDB`
**Namespace:** `local addonName, NW = ...` — the `NW` table is the global shared namespace.

---

## TOC Load Order (strict — do not reorder)
1. `Libs\LibStub\LibStub.lua`
2. `Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua`
3. `Libs\LibSharedMedia-3.0\LibSharedMedia-3.0.lua`
4. `Core.lua` — creates NW namespace, DB init, debug engine, slash commands
5. `Collector.lua` — per-character data snapshot (inventory, bank, currencies, gold)
6. `Minimap.lua` — minimap button, drag logic, right-click menu
7. `Debug.lua` — /nwdebug scrollable log frame
8. `Tooltip.lua` — item tooltip injection via TooltipDataProcessor
9. `Config.lua` — main UI panel (loads last)

---

## Database Structure
```lua
NightwatchDB = {
    characters = {
        ["CharName-Realm"] = {
            name         = "CharName",
            realm        = "Realm",
            class        = "WARRIOR",      -- uppercase English locale key
            level        = 80,
            equippedIlvl = 620,            -- math.floor of GetAverageItemLevel() second return
            zone         = "Valdrakken",
            gold         = 150000,         -- in copper
            lastSeen     = 0,              -- time() Unix timestamp
            faction      = "Alliance",     -- "Horde", "Alliance", or "Neutral"
            restedXP     = 0,              -- percent (0-100) of current level bar
            currencies   = {
                [2032] = { amount = 500, cap = 2000 },
            },
            inventory    = {},             -- bags 0-4, itemID = count
            reagentbag   = {},             -- bag 5 only, itemID = count
            bank         = {},             -- character bank tabs, itemID = count
            -- warbank and warbankTabs moved to account level (see below)
            professions  = {},             -- { [parentSkillLine] = { name, icon, skillLevel, maxSkillLevel, isPrimary, enumProfession, totalSkill, totalMaxSkill, expansions={} } }
        }
    },
    warbank     = {},              -- account-wide: { [itemID] = { [bagID] = count } }
    warbankTabs = {},              -- account-wide: { [bagID] = "Tab Name" } — updated on BANKFRAME_OPENED
    guildbanks  = {},              -- per-guild: { ["GuildName-Realm"] = { items={[itemID]={[tabIndex]=count}}, tabs={[tabIndex]="Tab Name"} } }
    settings = {
        showAllRealms  = true,
        theme          = "midnight",
        font           = nil,             -- nil = GameFontNormal fallback
        fontSize       = 12,
        minimapButton  = {
            show  = true,
            angle = 45,                   -- degrees around minimap, 0-360
        },
        hiddenChars        = {},          -- ["Name-Realm"] = true to hide
        navExpanded        = {},          -- ["navItemId"] = true when expanded — persisted across sessions
        tooltipModifier    = "ALT",       -- modifier key for item tooltip counts: ALT / CTRL / SHIFT
    }
}
```

---

## Architecture Rules

**Namespace:** All module functions and state live on the `NW` table. Never use bare globals.

**Data collection:** Each character writes its own snapshot to `NightwatchDB.characters["Name-Realm"]` on login, logout, and relevant events. The UI reads from all snapshots.

**Event-driven:** Use `CreateFrame("Frame")` + `:RegisterEvent()` + `:SetScript("OnEvent", ...)`. No polling loops. No `OnUpdate` for state checks (exception: minimap drag uses `OnUpdate` only while mouse button is held — this is safe).

**Login callback chain:** Use `NW.RegisterOnLogin(fn)` to register any function that needs to run on `PLAYER_LOGIN`. Never assign `NW.OnLogin` directly — it was replaced by a callback table in Core.lua.

**UI contracts:** Modules must not call sibling module functions directly. Use the NW table:
- `NW.ToggleUI()` — fulfilled by Config.lua
- `NW.RefreshUI()` — fulfilled by Config.lua, called by Collector after any snapshot
- `NW.MinimapButton.Show()` / `.Hide()` — fulfilled by Minimap.lua
- `NW.RegisterOnLogin(fn)` — fulfilled by Core.lua

**Bank scanning:** Character bank and warbank both use `C_Bank.FetchNumPurchasedBankTabs` + `C_Container` with `Enum.BagIndex` lookup tables. Bank is only scannable on `BANKFRAME_OPENED`. Never use arithmetic offsets on Enum values — always use explicit lookup tables.

**Bag scanning:** Bags 0-4 → `entry.inventory`. Bag 5 (reagent bag, `Enum.BagIndex.ReagentBag`) → `entry.reagentbag`. Always scan separately. `BAG_UPDATE` is debounced at 1.5s via `C_Timer.After` — this is intentional, do not remove or add a combat gate.

**Warbank:** Account-wide — stored at `NW.db.warbank` and `NW.db.warbankTabs` (top-level, not per-character). Never store warbank data under character entries. Structure is `warbank[itemID][bagID] = count` and `warbankTabs[bagID] = "Tab Name"`. Scanned on `BANKFRAME_OPENED` using `C_Bank.FetchViewableBankTypes()` to confirm warbank is actually open (not guild bank). `BAG_UPDATE` for warbank bag IDs is gated with `C_Bank.AreAnyBankTypesViewable()` — WoW fires `BAG_UPDATE` for warbank IDs at login even when bank is closed, which would wipe saved data. Tab names fetched via `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)` — only available while bank frame is open.

**Guild bank:** Per-guild — stored at `NW.db.guildbanks["GuildName-Realm"]`. Structure: `{ items = { [itemID] = { [tabIndex] = count } }, tabs = { [tabIndex] = "Tab Name" } }`. Only viewable tabs scanned (`isViewable` from `GetGuildBankTabInfo`). Scanned on `GUILDBANKFRAME_OPENED` (0.5s delay) and `GUILDBANKBAGSLOTS_CHANGED`. Use `C_Item.GetItemInfoInstant(itemLink)` to extract itemID from `GetGuildBankItemLink`. Use `GetGuildInfo("player")` for guild name — guard with `IsInGuild()` first as it can return nil on login.

**Tooltip:** Hooked via `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`. This is taint-free and combat-safe. Do NOT gate tooltip logic with `InCombatLockdown()` — it incorrectly suppresses counts during open world combat.

**Class colors:** Defined locally in both Config.lua and Tooltip.lua — this is intentional (avoids cross-module dependency for a static table). If a new class is added, update both files.

**Debug logging:** Use `NW.LogDebug("ModuleName", "message")` — never `print()` for debug output.

**Config wiring:** UI panel built in `Config.lua` which loads last so it can reference any module's state.

---

## API Reference (verify before implementing)
- Before using any uncertain WoW API, verify the correct Retail 12.0+ signature at https://warcraft.wiki.gg first
- Cross-reference `../../WoWAddonDevGuide/` for Midnight 12.0+ API patterns and secret values documentation
- Then https://github.com/JBurlison/WoWAddonAPIAgents

## Confirmed API Notes (12.0+)
- `GetAverageItemLevel()` returns `(overall, equipped)` — use second value for equipped iLevel
- `UnitClass("player")` returns `(localizedName, englishKey)` — always use the second value for storage
- `GetProfessions()` returns up to 6 slot indices (prof1, prof2, archaeology, fishing, cooking, firstAid) — iterate with `ipairs({ GetProfessions() })`
- `GetProfessionInfo(slot)` returns `name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine` — use `skillLine` as the stable DB key (not name, which is localized). This is the **primary reliable source** for profession skill data — always use it as the root snapshot
- `GetAllProfessionTradeSkillLines()` returns ALL 150+ skillLineIDs across all expansions for all professions — most return `0/0` until the tradeskill window is opened. Filter by `maxSkillLevel > 0` to get only leveled expansion lines
- `GetProfessionInfoBySkillLineID(skillLineID)` returns `professionName, parentProfessionID, skillLevel, maxSkillLevel, isPrimaryProfession, enumProfession` — use `parentProfessionID` to group expansion children under their root profession
- `GetChildProfessionInfos(skillLine)` only returns populated skill data when the tradeskill frame is open for that profession — do NOT use for background scanning
- `C_TradeSkillUI.GetProfessionInfoBySkillLineID` `expansionName` field is always `"Unknown"` in 12.0+ — strip parent profession name from `professionName` to derive expansion label (e.g. `"Khaz Algar Alchemy"` → strip `"Alchemy"` → `"Khaz Algar"`)
- Profession DB structure: `professions[parentSkillLine] = { name, icon, skillLevel, maxSkillLevel, isPrimary, enumProfession, totalSkill, totalMaxSkill, expansions = { [childSkillLine] = { skillLevel, maxSkillLevel } } }` — root values from `GetProfessions()`, `totalSkill`/`totalMaxSkill` computed at snapshot time by summing expansions, expansions filled when tradeskill window is opened
- `SKILL_LINES_CHANGED` fires multiple times at login (up to 8x) — always debounce with a pending flag, never schedule multiple timers
- `TRADE_SKILL_SHOW` fires when player opens a profession window — this is the reliable event for getting expansion skill data. Use 0.2s delay after this event before querying `GetAllProfessionTradeSkillLines()`
- `GetAllProfessionTradeSkillLines()` returns 0/0 for all expansion lines at cold login — data only populates after the tradeskill frame is opened. Use `TRADE_SKILL_SHOW` to trigger re-snapshot
- For profession tooltips: query live via `GetAllProfessionTradeSkillLines()` for current character; fall back to stored `prof.expansions` for offline characters (expansion labels still available via `GetProfessionInfoBySkillLineID` without frame open)
- Secondary profession Enum values: Cooking=5, Fishing=10, Archaeology=14 (from `Enum.Profession`)
- `GetNumBankSlots()` does not exist in 12.0+ — use `C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character)`
- `NUM_BANKGENERIC_SLOTS` / `BANK_CONTAINER` do not exist in 12.0+
- Character bank bag IDs: `Enum.BagIndex.CharacterBankTab_1` (6) through `CharacterBankTab_6` (11)
- Warbank bag IDs: `Enum.BagIndex.AccountBankTab_1` (12) through `AccountBankTab_5` (16)
- Each bank/warbank tab has 98 slots (confirmed in-game)
- `C_Item.GetItemNameByID` does not exist — use `C_Item.GetItemInfo(itemID)`
- `UIDropDownMenu` / `ToggleDropDownMenu` are deprecated — use `Menu.CreateContextMenu`
- `time()` is correct for persistent timestamps — `GetTime()` is session-only uptime
- `C_CurrencyInfo.GetCurrencyListSize()` — returns total count of entries (currencies + section headers) in the player's currency tab. Valid in 12.0+.
- `C_CurrencyInfo.GetCurrencyListInfo(index)` — returns a `CurrencyInfo` struct for each entry. Filter with `not info.isHeader` to skip section headers; use `info.currencyID` as DB key; `info.quantity` for current amount; `info.maxQuantity` for cap (0 = no cap). Valid in 12.0+.
- `CURRENCY_DISPLAY_UPDATE` — fires whenever any currency amount changes. Use to re-snapshot currencies in real time. Safe to call `SnapshotCurrencies` directly in the handler (no debounce needed — it's a lightweight list scan).
- Currency snapshot is fully dynamic — no hardcoded ID list. `SnapshotCurrencies` scans the full currency list and stores all with `quantity > 0`. The display panels (Config.lua) define which IDs to show and where.
- `C_Bank.GetBankTabInfo` does not exist — use `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)`
- Guild bank globals (still valid in 12.0+): `GetNumGuildBankTabs()`, `GetGuildBankTabInfo(tab)` returns `name, icon, isViewable, canDeposit, ...`, `GetGuildBankItemInfo(tab, slot)` returns `texture, count, locked`, `GetGuildBankItemLink(tab, slot)`. Use `C_Item.GetItemInfoInstant(itemLink)` to extract itemID. `MAX_GUILDBANK_SLOTS_PER_TAB = 98` (confirmed from Blizzard source). `GUILDBANKFRAME_OPENED` and `GUILDBANKBAGSLOTS_CHANGED` are the correct events.
- `GetGuildInfo("player")` returns `guildName, rankName, rankIndex, realm` — can return nil on login even if in guild; always guard with `IsInGuild()` first
- `C_Bank.FetchPurchasedBankTabData` returns `{ [i] = { ID, name, icon, bankType, depositFlags, ... } }`
- `ID` in tab data matches `Enum.BagIndex` values (12-16 for warbank) — use as the key for `warbankTabs`
- `C_Bank.FetchViewableBankTypes()` — returns array of `Enum.BankType` values currently viewable. Use to detect if warbank vs guild bank is open on `BANKFRAME_OPENED`.
- `C_Bank.AreAnyBankTypesViewable()` — returns true if any bank frame is currently open. Use to guard `BAG_UPDATE` warbank rescans against login false positives.
- Full `C_Bank` function list (12.0): FetchNumPurchasedBankTabs, FetchPurchasedBankTabData, FetchPurchasedBankTabIDs, FetchNextPurchasableBankTabData, FetchDepositedMoney, FetchBankLockedReason, FetchViewableBankTypes, CanUseBank, CanViewBank, CanDepositMoney, CanWithdrawMoney, WithdrawMoney, DepositMoney, PurchaseBankTab, HasMaxBankTabs, IsItemAllowedInBankType, AreAnyBankTypesViewable, DoesBankTypeSupportMoneyTransfer, DoesBankTypeSupportAutoDeposit, AutoDepositItemsIntoBank, UpdateBankTabSettings, CloseBankFrame

---

## Hard Constraints (never violate)
- WoW Retail 12.0+ API only
- No deprecated functions
- No taint — never hook or replace protected Blizzard frames/functions directly
- No `loadstring`, no `pcall` wrappers around core logic
- No multi-file changes in a single task — work one file at a time
- Preserve modular architecture — modules must not directly call functions from sibling modules (go through NW table)
- Minimal comments only — never narrate what code is doing; only comment *why* when genuinely non-obvious; section headers encouraged; short one-line description on functions, helpers, tables, and constants
- Never use `InCombatLockdown()` to gate tooltip or bag scan logic
- Never use arithmetic offsets on `Enum.BagIndex` values — always use explicit lookup tables
- Warbank is account-wide — always read/write from `NW.db.warbank` and `NW.db.warbankTabs`, never from character entries
- warbank DB structure is `warbank[itemID][bagID] = count` — never flatten to `warbank[itemID] = count`
- Guild bank is per-guild — stored at `NW.db.guildbanks["GuildName-Realm"]`; never store under character entries
- **No `goto` or `::label::` syntax** — WoW uses Lua 5.1 which does not support these; use nested `if` guards instead
- `GetXPExhaustion()` is valid in Retail 12.0+ — returns rested XP or `nil` when not rested; always use safe pattern: `(GetXPExhaustion and GetXPExhaustion()) or 0`. `C_XP` namespace does not exist.
- All files must have a standard header comment block: `-- Addon : Nightwatch / -- File : FileName.lua / -- Version : YYYY.MM.DD / -- Desc : brief description`
- Before every commit, update the TOC `## Version:` field to the current date in `YYYY.MM.DD` format — no commit without a version bump

---

## Slash Commands
- `/nw` — toggle main UI
- `/nw debug` — toggle debug mode
- `/nw prof` — dump all profession skillLineIDs to chat (debug tool)
- `/nwdebug` — toggle debug log frame

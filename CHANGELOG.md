# Wick's Quest Key — Changelog

## 1.1.0 - 2026-10-03

### Added

- The button draws in WickCore's chrome: its colours, border and corner
  marks come from the look and theme chosen under Wick's Mods in the
  game's Options, and follow a change at once.
- A settings page of its own under Wick's Mods: unlock and drag, or put
  the button back in the middle. With Wick's UI loaded the page says
  its movers place it instead. The suite's launcher opens the page.
- Chat lines carry the theme's accent colour.

### Changed

- Wick's Quest Key now needs WickCore, which is in the same download as
  the rest of the suite. Without it the addon says so once at login and
  does nothing else.
- With Wick's UI loaded, the button is one of its movers: /wui move
  drags it with everything else, and it starts where you had it. The
  addon's own unlock, move and reset commands point there while it is.

## 1.0.4 - 2026-10-01

### Fixed

- Loads on the 2.5.6 client without being marked out of date. The addon
  now lists interface 20506 alongside 20505.

## 1.0.3 - 2026-05-07

### Fix: cooldown text was throwing 24,000+ silent errors per session

`GetItemCooldown` was moved into the `C_Container` namespace in TBC Anniversary 2.5.5. The cooldown OnUpdate was calling the old global, which is now nil, and the resulting error fired ten times a second whenever a quest item was armed. Resolved at load time with a fallback to the legacy global so older clients still work.

Symptom you may have noticed: BugSack filling up with `attempt to call global 'GetItemCooldown' (a nil value)` entries, and a small but real CPU drag from the error capture path itself.

## 1.0.2 - 2026-05-07

### Cooldown timer on the button

The armed item's remaining cooldown now shows in warm yellow at the bottom-center of the icon. Format follows the conventional Blizzard-style action bar:

- `Xm` once the cooldown is over a minute
- whole seconds in the 10s to 60s range
- one-decimal seconds under 10s

A 1.5s floor hides the text on global-cooldown nudges so the field stays quiet between real cooldowns. Refreshes ten times a second via a throttled OnUpdate, and snaps fresh whenever you cycle items or fire the bind.

## 1.0.1 - 2026-05-06

### The keybind actually fires the item now

The 1.0.0 button looked right, the icon armed correctly, the keybind registered, and the click chain reached the button on press. But the secure action that turns "click" into "use this item" never fired, so pressing the bind did nothing visible.

Two root causes:

- **Bindings.xml was listed in the `.toc`**, which routed it through WoW's UI XML parser instead of the Bindings parser. The parser silently dropped every `<Binding>` element, so the keybinding was never registered with the engine. Removed from the `.toc`; Blizzard auto-loads `Bindings.xml` from the addon root through the correct parser.
- **The secure click setup didn't match the working sibling pattern.** Switched the click registration to `AnyUp` + `AnyDown` and set both `macrotext` and `macrotext1` (mirroring the WicksTotemsAndThings totem buttons, which use the same Wick-style SAB pattern). This routes the press through the SAB's internal macro processor, which works on this client even though the global `RunMacroText` Lua function is missing.

### Behavior changes

- **Pressing the bind or left-clicking the button uses the armed item** and leaves it armed, so quests that want the item used several times in a row stay on a single key.
- **Right-click switches to the next quest item** without firing it (single advance per click; no longer double-advances back to where it started).
- Cleaned up the diagnostic chat output that 1.0.0-betas were printing.

## 1.0.0 - 2026-05-03

### Initial release

Retail-style ExtraActionButton for TBC Classic. One bind cycles through every active quest item, auto-detected from your quest log. Brand-consistent with the rest of the [Wick suite](https://github.com/Wicks-mods/WickSuite).

- Single 52x52 secure-action button with the Wick chrome (flat purple-black panel, 1px border, fel-green L-bracket corners)
- Auto-detects quest items via `GetQuestLogSpecialItemInfo`
- Left-click or binding fires the armed item; cycles to the next on each press
- Right-click cycles without firing (skip the current item)
- Keybind label shown in the top-right corner of the button, updates on `UPDATE_BINDINGS`
- Stack count rendered bottom-right when count > 1
- Hides when no usable quest items are loaded; reappears on `QUEST_LOG_UPDATE` / `BAG_UPDATE_DELAYED`
- Slash commands: `/wqk`, `/wqk unlock`, `/wqk lock`, `/wqk reset`
- Position saved to `WicksQuestKeyDB`

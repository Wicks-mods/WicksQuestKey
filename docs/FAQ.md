# FAQ

### How does it know which item is the quest item?

It calls `GetQuestLogSpecialItemInfo` on every entry in your quest log — the same API Blizzard's own auto-quest-item button uses. If a quest has a usable item, it shows up.

### Why does the icon change after I press the key?

If you have more than one quest item loaded, the button cycles through them on each press so a single bind covers them all. The icon shows what is armed for the next press.

### What if the wrong item is armed?

Right-click the button to skip to the next item without firing. You can keep right-clicking until the icon shows what you want.

### Why is the button hidden?

You don't have any usable quest items in your log right now. Pick up a relevant quest and the button reappears automatically.

### Can I change the bind?

Yes. Go to *Esc → Key Bindings → Wick's Quest Key → Use current quest item*. The label on the button updates to match.

### The button is in the way / I want to move it

`/wqk unlock`, drag it, `/wqk lock`. Position is saved per character. `/wqk reset` returns it to the default spot.

### Does it work in combat?

Yes — pressing the bind in combat fires the armed item normally. The cycle and lock state cannot change mid-combat (a Blizzard secure-action restriction), but they catch up the moment combat ends.

### Is this for Era / Season of Discovery / Retail?

TBC Classic only (Interface 20505). Retail already has the ExtraActionButton built in.

### Does it have a config UI?

No — just slash commands and the keybind. The whole point is "one button, one bind, no config." If you want a config UI, [open an issue](https://github.com/Wicks-mods/WicksQuestKey/issues) and pitch what you'd want in it.

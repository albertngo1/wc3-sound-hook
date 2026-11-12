# Sound packs

| pack | clips | contents |
|---|---:|---|
| `wc3` | 91 | Reign of Chaos and The Frozen Throne unit and hero "Ready" lines: four races plus neutral, including TFT heroes (Illidan, Arthas, Thrall, Kael'thas, Sylvanas, Maiev, Crypt Lord, Warden and others) |
| `starcraft` | 107 | Terran, Protoss and Zerg unit ready and acknowledgement lines |
| `hearthstone` | 29 | One line per well-known card, picked for short, funny or often-misheard lines |

## Hearthstone lines

Some of the cards in the Hearthstone pack:

- Grim Patron ("Everyone, get in here!")
- SI:7 Agent ("This guy's toast!", often heard as "Disguised Toast")
- Mal'Ganis ("I am a turtle!")
- Frothing Berserker ("My blade be thirsty!")
- Annoy-o-Tron ("Hello hello hello!")
- Reno Jackson ("We're gonna be rich!")

Also: Abusive Sergeant, Leeroy Jenkins, Millhouse, Kel'Thuzad, Tirion, Al'Akir, Undertaker,
Loot Hoarder, Quartermaster, Doomsayer and more. See `sounds/hearthstone/complete/` for the full list.

## Adding your own

Any folder at `~/.claude/sounds/<name>/complete/` with `.wav` or `.mp3` files becomes a pack named
`<name>`. Subfolders below `complete/` are fine. The hook picks a clip at random from every file in
the pack.

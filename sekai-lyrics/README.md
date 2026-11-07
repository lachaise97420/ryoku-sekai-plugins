# Sekai Lyrics

SekaiPop's desktop lyrics widget, ported to Ryoku as a native `desktopWidget`
plugin. The words of the song that is playing, sung along on the wallpaper:
SekaiPop's exact sticker look, karaoke timing and animations, not a Ryoku
re-style.

## What it does

- **The stack** — the line being sung is big in the middle; the line before has
  slid up and faded, the next one waits below, small and tilted.
- **Karaoke** — each word fills with cyan as it is sung, and a mint diamond
  bounces from word to word, landing exactly as each one starts. The word it
  lands on squashes, and a puff of diamonds flies off it.
- **Word by word** — when a provider has word timing, the words hop up one after
  another just before their line starts, and the fill follows each word. With
  line-only lyrics the whole line lights at once.
- **Takeover** — when the next line begins while the current one is still being
  sung, the old line is held just above the new one and keeps singing, then
  lets go.
- **Gaps** — an intro or instrumental is three diamonds that light one by one.
- **Ad-libs and backing voices** — smaller, raised, mint words inside the line,
  and a second small row when the track has a voice that sings along.
- **Sync keys** — point at the lyrics: `<< earlier`, the song's nudge, `later >>`
  and `sources` appear as sticker words.
- **Source picker** — `sources` opens SekaiPop's card: Auto, or one provider per
  row, each showing `WORD BY WORD`, `SYNCED`, `Not found` or
  `Unreachable / Try again`.
- **Pause** — the lyrics dim while the player is paused and come back with the
  music.

There is no card behind the words: the lyrics are stickers (navy outline, hard
shadow) lying straight on the wallpaper, and the widget is transparent
everywhere else. Ryoku owns placement, dragging, scaling, locking and the
enabled switch; SekaiPop's own edit mode and clone/demo mode are not ported.

## Files

- `service/Main.qml` — the vendored `LyricsService`: MPRIS track, clock,
  providers, caching, saved position/nudge, source state.
- `content/Widget.qml` — the view: player clock, line stack, keys, tag.
- `content/LyricsLine.qml`, `LyricsWord.qml`, `LyricsKey.qml` — the sticker line
  and its parts (karaoke fill, marker, bursts, takeover, ad-libs, gaps).
- `content/LyricsSources.qml`, `Pill.qml` — the source-picker card. SekaiPop
  opens it in a full-screen overlay; a Ryoku plugin cannot add a layer surface,
  so it is a `QtQuick.Controls` popup with the same card, rows and motion.
- `content/SekaiTheme.qml` — SekaiPop's palette and sizes, read from SekaiPop's
  own state instead of Ryoku's theme.
- `content/MediaSource.qml` — the MPRIS player picker.
- `content/LyricsMath.js` — SekaiPop's timing and layout maths.
- `bin/lyrics-cache.sh`, `bin/lyrics-state.sh` — the cache and state helpers.

## What it reads

- MPRIS players through Quickshell (`title`, `artist`, `album`, `length`,
  `position`, `artUrl`).
- SekaiPop's theme state, read-only, to reproduce its exact colours:
  `~/.local/state/sekaipop/theme`, `dark`, `darker`, and
  `~/.cache/sekaipop/matugen/colors.json` when the matugen theme is selected.
- Its own saved state and cache (below).

## What it writes

Only its own state and cache:

- `$XDG_STATE_HOME/ryoku/plugins/sekai-lyrics/lyrics.json` — placement, sync
  nudge, word-by-word switch, preferred source, per-track offsets.
- `$XDG_CACHE_HOME/ryoku/plugins/sekai-lyrics/` — fetched lyrics, so a track
  that was already looked up does not hit the network again.

Nothing else on the machine is modified. No settings are declared, so nothing is
written to `shell.json`.

## Commands and network

The plugin runs `sh` with its own two scripts in `bin/`, and those scripts use
`curl`, `awk`, `base64`, `cat`, `mkdir`, `mv`, `printf` and `sleep`. It also
uses `ryoku-plugins-place` for placement from the Ryoku side. No privileged
command, no `sudo`, no downloaded-and-executed code.

Hosts contacted (all listed in `manifest.json` → `capabilities.network`):

- `lyrics-api.boidu.dev`
- `api.betterlyrics.org`
- `lyricsplus.prjktla.workers.dev`
- `lrclib.net`
- `music.youtube.com`
- `api-lyrics.simpmusic.org`
- `music.163.com`
- `c.y.qq.com`, `y.qq.com`, `lyrics.kugou.com`, `mobileservice.kugou.com`
- `i.ytimg.com` (YouTube thumbnail fallback for the player art)

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --yes
```

Then enable and place it under **Ryoku Settings > Add-ons**. It is a
`desktopWidget`: left-drag to move, right-click for the desktop menu, Ctrl+wheel
or the corner bracket to resize.

## Author

Warren <warren@local>. Community plugin (`official` is false).

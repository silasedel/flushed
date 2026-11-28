# Pixel-exact port of the website to Roblox: how it's done

Goal: the Roblox game looks and plays exactly like https://silasedel.github.io/flushed/ on computers and phones.

## Method
- **Scene**: `src/client/Ocean.luau` is a line-for-line port of `js/ocean.js` drawing into a Luau pixel buffer
  (`Canvas.luau`), shown with an EditableImage. `tools/roblox-scene-diff.js` renders the same scenario with the
  website's code (node-canvas) and the Luau port and diffs them (title/flush/results identical, deep zones <10%
  of pixels differ by tiny amounts). Under 4 ms/frame with `--!native`.
- **Fonts**: all website text is IBM Plex Mono (css line 616 redefines --px to Plex Mono); the logo is VT323.
  Outlines exported by `tools/roblox-fonts.js` into `FontData.luau`; `TextRaster.luau` fills them crisp like
  macOS Chrome with -webkit-font-smoothing:none. Calibrated with `tools/roblox-text-diff.js`.
- **Layout**: each screen's CSS cascade is ported as maths on the viewport size (`Kit.Css`): rem=16px,
  --u = clamp(.82rem, .55rem+.55vw, 1.12rem) (narrow <=760px: .92rem). Verified against Chrome's computed
  layout dumps (scratch `dump.js`) at 1440x900, 1280x720, 1024x768 and 390x844.
- **Reference images**: headless Chrome (`shots.js`, `dump.js`) against a local server of the website.

## Status
- [x] Scene renderer (exact), fonts + text rasterizer, UI kit
- [x] Title, dive screen, reveal, sink card, depth labels, ruler
- [x] Results (score, flush log chart, stack chart, vibe check, clog with every answer, logbook, actions)
- [x] Menu drawer, shop, stats, packs, settings, help, play-again, confirm, toasts (checked against Chrome dumps)
- [x] New client (Main.client.luau): EditableImage scene + UI, server wiring, relayout on resize/rotate
- [x] Economy: start at 0 coins; looks cost real Robux (Developer Products, Config.ROBUX_PRODUCTS); coins earned only
- [x] Studio play-test (desktop): title -> 10-prompt game -> results works end to end

## Deliberate differences from the website
- Small text (<20px) is drawn at 2x and smoothed; nothing is drawn under 10px (Kit.minTextSize) so fine print is readable on phones.
- Small phones: the answer dock spans the full width (the website squeezes the input to ~100px).
- The DEPTH box sits right of Roblox's own top-left buttons; HUD boxes grow with their numbers; the timer blinks red for the last 5s.
- Deep zones are calmer: fewer mice crossing, mice in burrows in the brick walls, graffiti words on the bricks.
- Toasts slide/fade in and out; menus fade/scale in.
- Sound: the website's synthesized effects rendered by tools/roblox-sounds.js into one file (roblox/audio/flushed-sfx.ogg),
  played as slices. Upload it once and set Config.SFX_ID.

## To do before launch
- Publish the place, turn on Game Settings > Security > "Allow Mesh / Image APIs" (EditableImage; creator must be ID-verified 13+).
- Create one Developer Product per shop price and paste the ids into Config.ROBUX_PRODUCTS.
- Upload roblox/audio/flushed-sfx.ogg and set Config.SFX_ID.

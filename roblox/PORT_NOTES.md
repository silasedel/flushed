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
- [x] Scene renderer (exact)
- [x] Fonts + text rasterizer
- [x] UI kit (boxes, text with stroke/shadows/glow, icons, scanlines)
- [ ] Title screen
- [ ] Game screen (HUD, prompt box, dock: timer ring / input / FLUSH, feedback, suggest, tried, skip)
- [ ] Reveal panel, sinking answer card, depth labels, tier lines, gauge, zone banner
- [ ] Results (score, flush log chart, stack chart, vibe check, clog, logbook, actions)
- [ ] Modals: shop, stats, settings, help, play-again chooser; menu drawer; packs sheet; toast
- [ ] Economy: start at 0 coins; Robux only for cosmetics (Roblox rules)
- [ ] Studio play-test on desktop + phone emulator

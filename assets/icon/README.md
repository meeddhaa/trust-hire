# App icon source files

Generation-time inputs for `flutter_launcher_icons` (see the
`flutter_launcher_icons:` config in `pubspec.yaml`) — neither file is
bundled into the running app itself, only read by the icon generator.

Both are derived from the user-supplied "TrustHire — Get. Hired." logo
(a laptop/"JOB" glyph next to a wordmark on black), not used as-is: a
launcher icon needs to read as a mark at ~48px, where the wordmark text
would be illegible, so only the glyph was kept, cropped square and
re-processed:

- **`icon_base.png`** — the glyph tightly cropped to a square, opaque
  black background intact. Used as the legacy/pre-adaptive-icon fallback
  and the Play Store listing icon source.
- **`icon_foreground.png`** — the same glyph with its black background
  made transparent (alpha = per-pixel brightness, since the source is a
  bright glyph on a pure-black background — this keeps the amber color
  and anti-aliased edges intact rather than a hard cutout), then pasted
  centered onto a larger transparent canvas so the glyph sits at ~62% of
  the canvas width. That extra padding matters: adaptive icons get
  masked into a circle/squircle/rounded-square depending on the launcher,
  and content outside the mask's ~66%-diameter "safe zone" gets clipped —
  the tighter `icon_base.png` crop would lose the laptop's corners on a
  circular mask.

Regenerate after replacing either file:

```
flutter pub get
dart run flutter_launcher_icons
```

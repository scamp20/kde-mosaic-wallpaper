# Huangjin Mosaic — animated photo-mosaic wallpaper

A lightweight **KDE Plasma** wallpaper that turns a folder of your own photos
into a living mosaic. Photos are sorted by shape and dropped into matching
frames so nothing gets cropped, each one slowly pans/zooms (Ken Burns), they
quietly crossfade to new photos, and the whole grid re-arranges itself every
20–30 minutes.

- 📐 **Shape-aware** — every frame is filled with the photo that fits it best, so there's minimal blurred space.
- 🖼️ **Never crops your subjects** — the whole photo is always shown; gaps are filled with a soft blurred version of the same image.
- 🎞️ **Gentle motion** — a slow zoom that only ever zooms *in*, so it never reveals empty space.
- 🪶 **Lightweight** — small image decodes, no growing image cache, and on Wayland the animation pauses itself when the desktop is fully covered by a window.
- 🔀 **Self-shuffling** — a balanced layout with a featured center "hero" photo that changes shape and re-arranges over time.

> **Note:** It uses your photos, not the ones in this repo. The `photos/` folder
> is intentionally empty here — you add your own (see below).

---

> **You are on the `plasma6` branch** — the Plasma 6 / Qt 6 port. For Plasma 5,
> use the `main` branch instead.

## Requirements

- **KDE Plasma 6**, on **Linux**.
- Qt 6 with the `Qt5Compat.GraphicalEffects` QML module (provides the blur and
  rounded-corner mask). On most distros it's in a package such as
  `qt6-5compat` / `qt6-qt5compat` / `qml6-module-qt5compat-graphicaleffects`,
  and is normally already present on a full Plasma 6 install. If the wallpaper
  loads but photos show no rounded corners / no blurred backdrop, install that
  package.

> **Heads-up:** this Plasma 6 port is a best-effort translation of the Plasma 5
> version and hasn't been runtime-tested on Plasma 6 yet. If something looks
> off, please open an issue — the Plasma 5 version (`main` branch) is the
> tested one.

---

## Install

Plasma loads wallpaper plugins from `~/.local/share/plasma/wallpapers/`, and the
folder name **must match** the plugin id (`huangjin.mosaic`).

```bash
# Plasma 5:
git clone https://github.com/scamp20/kde-mosaic-wallpaper ~/.local/share/plasma/wallpapers/huangjin.mosaic

# Plasma 6 (use the plasma6 branch):
git clone -b plasma6 https://github.com/scamp20/kde-mosaic-wallpaper ~/.local/share/plasma/wallpapers/huangjin.mosaic
```

(If you download a zip instead, just make sure the final folder is named
`huangjin.mosaic` and sits directly inside `~/.local/share/plasma/wallpapers/`.)

## Add your photos

Drop your images into the `photos/` folder:

```bash
cp ~/Pictures/favourites/*.jpg ~/.local/share/plasma/wallpapers/huangjin.mosaic/contents/photos/
```

- Supported: `.jpg`, `.jpeg`, `.png`, `.webp` (case-insensitive).
- Any mix of portrait / landscape / square is fine — the wallpaper measures each
  one and places it accordingly.
- **Tip:** if a photo shows up sideways, it has a rotation stored in its EXIF tag
  that your tools aren't honoring. Bake the rotation into the pixels once with
  ImageMagick: `mogrify -auto-orient contents/photos/*` (this rewrites the files,
  so keep originals elsewhere if you care about them).

## Select it

1. Right-click the desktop → **Configure Desktop and Wallpaper…**
2. **Wallpaper type:** *Huangjin Mosaic*
3. **Apply.**

If you just changed the code (or it doesn't show up), Plasma caches compiled QML —
reload the shell:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

---

## Customize

Everything lives in `contents/ui/`. The common knobs are at the top of
[`contents/ui/main.qml`](contents/ui/main.qml):

| What | Where | Default |
|------|-------|---------|
| Background color | `gradient` stops | warm greige `#9C9388 → #6E665C` |
| Gap between photos | `property int gap` | `12` |
| Corner rounding | `property real cornerRadius` | `22` |
| How often a single photo changes | `swapMin` / `swapMax` (ms) | ~every 4 s |
| How often the whole grid re-arranges | `layoutMin` / `layoutMax` (ms) | every 20–30 min |
| Disable re-arranging entirely | `property bool relayoutEnabled` | `true` |
| The frame layouts | `property var layouts` | 4 portrait-leaning layouts |

- **Motion:** the Ken Burns zoom/pan lives in
  [`contents/ui/HuangjinPhoto.qml`](contents/ui/HuangjinPhoto.qml). To make it
  fully static, set the animation block's `running:` to `false`.
- **Image sharpness vs. RAM:** also in `HuangjinPhoto.qml`, `sourceSize` on the
  `fg` image (default `800`) caps decode resolution. Raise for sharper photos on
  large screens, lower to use less memory.

### Tuning it for *your* photos and screen

The bundled layouts were authored for a **16:10** screen (1920×1200) and a photo
collection that's **mostly 3:4 portraits**. It still works on any screen and any
mix of photos — the shape-matching keeps blur low — but the *arrangement* looks
its best when the layouts match your situation.

If your library leans landscape, or your screen is 16:9 / ultrawide / a different
shape, you can adjust the `layouts` array. The easy way: **paste
`contents/ui/main.qml` into an AI assistant** (ChatGPT, Claude, etc.) and ask
something like:

> "This is a KDE Plasma QML photo-mosaic wallpaper. The `layouts` array holds
> mosaic layouts as cells `{x, y, w, h}` in 0–1 fractions of the screen. My
> screen is **1920×1080 (16:9)** and most of my photos are **landscape**.
> Rewrite the `layouts` to be landscape-dominant and tuned to my screen, keeping
> a featured center hero."

Each cell is just a rectangle in fractions of the usable area, and every frame is
auto-filled with the best-fitting photo, so you can rearrange freely.

---

## Uninstall

```bash
rm -rf ~/.local/share/plasma/wallpapers/huangjin.mosaic
```

## Platform support

| Platform | Works? |
|----------|--------|
| Linux + **KDE Plasma 5** (Kubuntu, Fedora KDE, openSUSE, Arch, etc.) | ✅ Yes — `main` branch |
| Linux + **KDE Plasma 6** | ✅ Yes — `plasma6` branch (see [Install](#install)) |
| Other Linux desktops (GNOME, XFCE…) | ❌ No — this is a Plasma wallpaper plugin |
| Windows / macOS | ❌ No |

It is **not** Kubuntu-specific: any Linux distribution running KDE Plasma 5 works.
It is tied to **KDE Plasma**, not to a particular distro.

## License

MIT — see [LICENSE](LICENSE).

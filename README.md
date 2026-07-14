# Huangjin Mosaic — animated photo-mosaic wallpaper

A lightweight **KDE Plasma** wallpaper that turns a folder of your own photos
into a living mosaic. Photos are sorted by shape and dropped into matching
frames so nothing gets cropped, each one slowly pans/zooms (Ken Burns), they
quietly crossfade to new photos, and the grid periodically re-arranges itself
into a different layout.

- 📐 **Shape-aware** — every frame is filled with the photo that fits it best, so there's minimal blurred space.
- 🖼️ **Never crops your subjects** — the whole photo is always shown; gaps are filled with a soft blurred version of the same image.
- 🎞️ **Gentle motion** — a slow zoom that only ever zooms *in*, so it never reveals empty space.
- 🪶 **Lightweight** — small image decodes, no growing image cache, and on Wayland the animation pauses itself when the desktop is fully covered by a window.
- 🔀 **Eighteen layouts** — portrait walls, landscape bands, off-centre heroes, asymmetric quilts, staircases, tall side-columns with panorama bands, and more.
- 🚫 **No repeats** — a photo is never shown twice while a layout is up, so a session works through *distinct* photos instead of recycling the same favourites.
- ⏳ **Self-timed** — a layout stays up for as long as it has fresh photos that suit its frames, so its length varies: a wall of portraits can draw on hundreds and runs to the cap, while a layout of square frames exhausts the few square photos and moves on early.
- ⚖️ **Even-handed** — the next layout is chosen to be *unlike* the current one, and biased towards whichever photos have had the least screen time, so the wallpaper stays fresh while every photo works its way round.
- ⏱️ **Oldest goes first** — the photo replaced next is the one that has been up longest (weighted, so it stays unpredictable). A photo that has only just appeared is almost never snatched straight back off.
- ✨ **Seamless re-arranges** — the next layout is built and fully decoded *off-screen* first, then crossfaded in, so you never watch empty frames pop in one by one.

> **Note:** It uses your photos, not the ones in this repo. The `photos/` folder
> is intentionally empty here — you add your own (see below).

---

## Requirements

- **KDE Plasma 5** (Plasma 5.27 tested), on **Linux**.
- Qt 5 with the `QtGraphicalEffects` and `Qt.labs.folderlistmodel` QML modules
  (these ship with a standard Plasma desktop).

This is the **Plasma 5** version, on the `main` branch. For **Plasma 6** there
is a port on the [`plasma6` branch](#platform-support) — clone that branch
instead (see below).

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
kquitapp5 plasmashell && kstart5 plasmashell
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
| Longest a layout may stay up | `layoutMin` / `layoutMax` (ms) | 5–7 min (a *cap*, see below) |
| Shortest a layout may stay up | `layoutMinDwell` (ms) | 1 min |
| When a photo counts as a fit | `fitTolerance` | `0.18` (within 18% of the frame's ratio) |
| How strongly the next layout must differ | `freshnessBias` | `2.0` (0 = ignore, higher = more contrast) |
| Disable re-arranging entirely | `property bool relayoutEnabled` | `true` |
| The frame layouts | `property var layouts` | 18 layouts (see below) |

**How a photo is chosen.** A frame draws, at random and with equal chance, from
*every* photo whose aspect ratio is within `fitTolerance` of its own — not from
the N closest. That distinction matters more than it looks. Photo libraries are
full of exact ties (189 of the author's are *precisely* 3:4), and a fixed
"closest N" window is permanently occupied by them, so a 2:3 camera portrait —
which suits a 3:4 frame perfectly well — ranks just outside the window and is
**never shown, ever**. Widening `fitTolerance` lets more shapes into each frame at
the cost of a little more blur; tightening it does the reverse.

**Which photo changes next.** The tile whose photo has been up longest, chosen by
a weighted draw (age cubed) rather than strictly, so it never settles into a
visible order. A uniform random pick — the obvious implementation — replaced 29%
of photos within ten seconds of them appearing; this brings that down to 4%.

**Which layout comes next.** Weighted by two things at once. *Freshness*: layouts
whose mix of frame shapes is unlike the one on screen are favoured
(`freshnessBias`), so the wallpaper changes character rather than just
reshuffling. *Hunger*: layouts whose frames draw on the least-shown photos are
favoured. The second one is what evens out individual photos — a 3:4 portrait
competing with 190 others inevitably gets less screen time each than a square
competing with 25, so it's the *common* shapes that are starved per photo.
Weighting by hunger pulls layout time back toward whoever is behind, which hands
the popular shapes more layouts *and* more time without any of it being
hard-coded. Across the author's library this cut the gap between the most- and
least-shown photo from **8.7× to 2.7×**.

**How long a layout lasts.** No photo repeats while a layout is up. So a layout
runs until it can no longer fill one of its frames with a photo that is both
fresh and a fit — then it re-arranges. That makes its length depend on how much of
*your* library suits its frames, which is the point: it stops common shapes
hogging the screen and gives rarer ones a turn. `layoutMin`/`layoutMax` are only
the **upper bound**, for layouts broad enough to otherwise run for a quarter of an
hour. With the author's library the spread is roughly 2.5–7 minutes.

- **Motion:** the Ken Burns zoom/pan lives in
  [`contents/ui/HuangjinPhoto.qml`](contents/ui/HuangjinPhoto.qml). To make it
  fully static, set the animation block's `running:` to `false`.
- **Image sharpness vs. RAM:** also in `HuangjinPhoto.qml`, `sourceSize` on the
  `fg` image (default `800`) caps decode resolution. Raise for sharper photos on
  large screens, lower to use less memory.

### Tuning it for *your* photos and screen

The bundled layouts were authored for a **16:10** screen (1920×1200) and a
library that's mostly **3:4 portraits** with a good number of **4:3 landscapes**.

There's one rule that matters far more than the rest:

> **A frame must be shaped like a photo you actually own.**

A cell's `{w, h}` is *not* its shape. On a 16:10 screen the frame's aspect ratio
is `w * 1.6 / h` (in general, `w / h * screen_width / screen_height`). So a
"square-looking" cell of `w:0.5, h:0.5` is really a **1.6:1** frame — and if you
own no 1.6:1 photos, it can only ever be filled with blur, no matter how good the
shape-matching is. Frames are sized so that ratio lands on shapes the library
actually contains (0.5, 0.67, 0.75, 1.0, 1.33, 1.5, 2.0).

The corollary bites too: **a photo whose shape no frame matches is never shown at
all.** Not rarely — never, however long the wallpaper runs. That's why there's a
very-tall layout (frames at 0.5) and a panorama one (2.0): without them, vertical
panoramas and wide shots simply never appear.

Measure your own library first:

```bash
identify -format "%w %h\n" contents/photos/* \
  | awk '{ printf "%.2f\n", $1/$2 }' | sort -n | uniq -c | sort -rn | head
```

Every cluster in that list wants a frame within ~18% (`fitTolerance`) of it
somewhere in `layouts`, or those photos are dead weight.

**Watch for accidental squares.** The reverse mistake is just as easy: a shape you
own *few* of, appearing in *many* layouts. Near-square frames are the classic
offender — they fall out of almost any tiling by accident, and if only ~25 of your
photos are square, that handful ends up on screen several times as often as an
ordinary portrait. Layouts 15–18 exist purely as ballast against this: they
contain no square and no panorama frame at all, only the shapes most photos
actually are. If you rewrite the layouts, check how many frames land in each shape
bucket and compare that against how many photos you own of it.

Then **paste `contents/ui/main.qml` into an AI assistant** (ChatGPT, Claude, …)
and ask for layouts tuned to what you found:

> "This is a KDE Plasma QML photo-mosaic wallpaper. The `layouts` array holds
> layouts as cells `{x, y, w, h}` in 0–1 fractions of the screen; cells must tile
> the area exactly with no gaps or overlaps. My screen is **1920×1080 (16:9)**,
> so a cell's true aspect ratio is `w / h * 16/9`. My photos cluster at these
> ratios: **1.33 (120 photos), 0.75 (30), 1.0 (12)**. Write me 8 varied layouts —
> some asymmetric — where *every* frame's true aspect ratio lands on one of those
> clusters. Show the computed ratio of each frame so I can check."

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

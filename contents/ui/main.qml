import QtQuick 2.15
import Qt.labs.folderlistmodel 2.12

// Native photo-mosaic wallpaper (no web view):
//  - discovers the photos in the photos/ folder
//  - measures each photo's aspect ratio
//  - arranges them in one of several mosaic layouts, filling each frame with
//    the photo whose shape fits it best, so there is minimal blurred space
//  - re-arranges itself periodically: the next layout is built and decoded
//    off-screen first, then crossfaded in, so the change is seamless
//  - soft neutral background, no clock
Rectangle {
    id: mosaic
    anchors.fill: parent

    // ---- Warm greige background, neutral and soft (lets the photos stand out) ----
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#9C9388" }
        GradientStop { position: 1.0; color: "#6E665C" }
    }

    // ---- Settings ----
    property int gap: 12
    property real cornerRadius: 22
    // One photo changes roughly every 6s. This is the gap between swaps, not how
    // long a photo lasts: with several frames taking turns, and the oldest usually
    // going first, a photo actually stays up for the best part of a minute.
    property int swapMin: 5800
    property int swapMax: 6800
    // The grid re-arranges into a different layout every five minutes, flat.
    property int layoutInterval: 300000
    // How far a photo's aspect ratio may sit from its frame's and still count as
    // a fit. This is the single knob behind both which photos a frame will draw
    // on and when a layout has run out of them - see pickPhoto.
    property real fitTolerance: 0.18
    // Keep photos whose filename numbers are within this of each other off the
    // screen at the same time. Names are in capture order, so this spaces out
    // burst shots and repeated poses, which the shape-only matcher can't tell
    // apart. 0 disables it. See pickPhoto.
    property int sequenceGap: 5

    // ---- Layouts ----
    // A layout is a list of cells; a cell is a rectangle {x, y, w, h} in [0..1]
    // of the usable area. Cells tile the area exactly: no gaps, no overlaps, and
    // no more than six per layout - beyond that the photos get too small.
    //
    // A frame's shape is not its cell's shape: on a 16:10 screen a cell's aspect
    // ratio is w * 1.6 / h. Every frame below is sized so that ratio lands on one
    // of the shapes photos actually come in - 0.50 (very tall), 0.75 (3:4
    // portrait), 1.0 (square), 1.33 (4:3), 1.5 (3:2), 2.0 (panorama) - because a
    // frame shaped like nothing in the library can only be filled with blur.
    //
    // The *mix* matters as much as the shapes. Frames of a given shape should be
    // roughly proportional to how many photos have it, or the photos of an
    // under-framed shape each get far more screen time than the rest. Square and
    // panorama frames are the ones to watch: they fall out of a tiling easily,
    // but few photos are either. See the README before editing these.
    property var layouts: [
        // 1 - Portrait hero, offset flanks
        // your favourite: hero flanked by columns broken at opposite heights
        // frames: 0.75 0.99 0.75 0.99 0.75
        [
            {x:0.00000, y:0.0000, w:0.26550, h:0.5700}, {x:0.00000, y:0.5700, w:0.26550, h:0.4300},
            {x:0.26550, y:0.0000, w:0.46900, h:1.0000}, {x:0.73450, y:0.0000, w:0.26550, h:0.4300},
            {x:0.73450, y:0.4300, w:0.26550, h:0.5700}
        ],
        // 2 - Hero hard left, mixed columns
        // your favourite: hero hard left, two mixed columns beside it
        // frames: 0.75 1.00 1.33 1.52 0.75 1.03
        [
            {x:0.00000, y:0.0000, w:0.46900, h:1.0000}, {x:0.46900, y:0.0000, w:0.26000, h:0.4150},
            {x:0.46900, y:0.4150, w:0.26000, h:0.3120}, {x:0.46900, y:0.7270, w:0.26000, h:0.2730},
            {x:0.72900, y:0.0000, w:0.27100, h:0.5800}, {x:0.72900, y:0.5800, w:0.27100, h:0.4200}
        ],
        // 3 - Portrait hero left, landscape over portraits
        // your favourite: hero left, a wide landscape over a row of portraits
        // frames: 1.33 0.75 0.78 0.78 0.78
        [
            {x:0.46875, y:0.0000, w:0.53125, h:0.6375}, {x:0.00000, y:0.0000, w:0.46875, h:1.0000},
            {x:0.46875, y:0.6375, w:0.17708, h:0.3625}, {x:0.64583, y:0.6375, w:0.17708, h:0.3625},
            {x:0.82291, y:0.6375, w:0.17709, h:0.3625}
        ],
        // 4 - Three portraits over a 3:2 band
        // three portraits over a band of three 3:2 landscapes
        // frames: 0.83 0.83 0.83 1.48 1.48 1.48
        [
            {x:0.00000, y:0.0000, w:0.33330, h:0.6400}, {x:0.33330, y:0.0000, w:0.33340, h:0.6400},
            {x:0.66670, y:0.0000, w:0.33330, h:0.6400}, {x:0.00000, y:0.6400, w:0.33330, h:0.3600},
            {x:0.33330, y:0.6400, w:0.33340, h:0.3600}, {x:0.66670, y:0.6400, w:0.33330, h:0.3600}
        ],
        // 5 - Two big landscapes over a mixed row
        // two big 4:3 landscapes over a mixed row
        // frames: 1.33 1.33 0.75 0.75 1.50 1.00
        [
            {x:0.00000, y:0.0000, w:0.50000, h:0.6000}, {x:0.50000, y:0.0000, w:0.50000, h:0.6000},
            {x:0.00000, y:0.6000, w:0.18750, h:0.4000}, {x:0.18750, y:0.6000, w:0.18750, h:0.4000},
            {x:0.37500, y:0.6000, w:0.37500, h:0.4000}, {x:0.75000, y:0.6000, w:0.25000, h:0.4000}
        ],
        // 6 - Portrait hero and a quartet
        // portrait hero with a quartet of portraits - the portrait-heaviest layout
        // frames: 0.75 0.85 0.85 0.85 0.85
        [
            {x:0.00000, y:0.0000, w:0.46875, h:1.0000}, {x:0.46875, y:0.0000, w:0.26562, h:0.5000},
            {x:0.46875, y:0.5000, w:0.26562, h:0.5000}, {x:0.73438, y:0.0000, w:0.26562, h:0.5000},
            {x:0.73438, y:0.5000, w:0.26562, h:0.5000}
        ],
        // 7 - Tall pair, portrait hero, landscape stack
        // a pair of very tall frames down the edge, portrait hero, landscape stack
        // frames: 0.50 0.50 0.75 1.20 1.20
        [
            {x:0.00000, y:0.0000, w:0.15625, h:0.5000}, {x:0.00000, y:0.5000, w:0.15625, h:0.5000},
            {x:0.15625, y:0.0000, w:0.46875, h:1.0000}, {x:0.62500, y:0.0000, w:0.37500, h:0.5000},
            {x:0.62500, y:0.5000, w:0.37500, h:0.5000}
        ],
        // 8 - Tall hero, portraits and landscapes
        // very tall hero: with 'Portrait pair' below, the only home for vertical panoramas
        // frames: 0.50 0.80 0.80 1.40 1.40
        [
            {x:0.00000, y:0.0000, w:0.31250, h:1.0000}, {x:0.31250, y:0.0000, w:0.25000, h:0.5000},
            {x:0.31250, y:0.5000, w:0.25000, h:0.5000}, {x:0.56250, y:0.0000, w:0.43750, h:0.5000},
            {x:0.56250, y:0.5000, w:0.43750, h:0.5000}
        ],
        // 9 - Panorama band over three portraits
        // the only frame wide enough for panoramas. Few photos are this wide, so the
        // panorama frame works through them all well inside a five-minute session and
        // then starts them round again - see pickPhoto
        // frames: 2.00 1.33 0.67 0.89 0.89 0.89
        [
            {x:0.00000, y:0.0000, w:0.50000, h:0.4000}, {x:0.50000, y:0.0000, w:0.33330, h:0.4000},
            {x:0.83330, y:0.0000, w:0.16670, h:0.4000}, {x:0.00000, y:0.4000, w:0.33330, h:0.6000},
            {x:0.33330, y:0.4000, w:0.33340, h:0.6000}, {x:0.66670, y:0.4000, w:0.33330, h:0.6000}
        ],
        // 10 - Portrait pair, tall hero, landscape stack
        // portrait pair, a very tall hero, and a stack of landscapes
        // frames: 0.75 0.75 0.56 1.32 1.32
        [
            {x:0.00000, y:0.0000, w:0.23440, h:0.5000}, {x:0.00000, y:0.5000, w:0.23440, h:0.5000},
            {x:0.23440, y:0.0000, w:0.35160, h:1.0000}, {x:0.58600, y:0.0000, w:0.41400, h:0.5000},
            {x:0.58600, y:0.5000, w:0.41400, h:0.5000}
        ]
    ]

    property int currentLayout: -1
    property bool started: false
    property bool discovered: false
    // Set to false to keep one fixed layout for the whole session.
    property bool relayoutEnabled: true

    // ---- Photos (with measured aspect ratio) ----
    property var allPhotos: []     // urls only (fallback before measuring)
    property var infos: []         // [{url, r}] once measured (r = width / height)
    property var usedUrls: []      // on screen right now
    property var shownUrls: []     // shown at any point during this layout session
    property var ratios: ({})      // url -> aspect ratio, for lookups by url

    function ratioOf(url) {
        return ratios[url] || 0;
    }

    // The trailing number in a filename (306 in ".../306.jpg"), or -1. The photos
    // are named in capture order, so nearby numbers are usually the same moment -
    // a burst, or the same pose shot several times. pickPhoto uses this to keep
    // such near-duplicates from sharing the screen.
    function seqOf(url) {
        var m = /(\d+)\.[^\/.]*$/.exec(url);
        return m ? parseInt(m[1], 10) : -1;
    }
    property bool classified: false

    // Picks a photo for a frame of the given aspect ratio.
    //
    // No photo repeats while a layout is up: a photo goes into shownUrls the
    // moment it is chosen, and shownUrls is only cleared when the layout
    // changes. So a layout session works its way through distinct photos rather
    // than picking with replacement, which is what stops the same few favourites
    // recurring and gives the rest of the library a turn.
    //
    // That also means a layout lasts as long as it has fresh photos suiting its
    // frames, which varies by layout: a wall of portraits can draw on 200 of
    // them, while a layout full of square frames exhausts the ~25 square photos
    // quickly and moves on sooner. When a frame can no longer be filled with a
    // fresh, well-fitting photo, the layout has nothing new left to show and we
    // ask for a re-arrange.
    //
    // Among photos that fit about equally well the choice is random: the library
    // is full of exact ties (180+ photos are exactly 3:4), so a plain sort would
    // otherwise keep returning the same ones.
    function pickPhoto(targetRatio, currentUrl) {
        var pool = infos;
        if (!pool || pool.length === 0) {
            // Not measured yet: fall back to any url.
            if (!allPhotos || allPhotos.length === 0) return "";
            return allPhotos[Math.floor(Math.random() * allPhotos.length)];
        }

        var t = targetRatio > 0 ? targetRatio : 1.0;
        var isSwap = currentUrl !== "";
        var i, j, tmp;

        // Fresh = not yet shown in this layout session, and not on screen now
        // (usedUrls also covers a grid being preloaded, so the incoming layout
        // can't duplicate the outgoing one mid-crossfade).
        var fresh = [];
        for (i = 0; i < pool.length; i++) {
            var u = pool[i].url;
            if (u !== currentUrl && shownUrls.indexOf(u) < 0 && usedUrls.indexOf(u) < 0)
                fresh.push(pool[i]);
        }

        // Shuffle first, so equally-good fits end up in random order...
        for (i = fresh.length - 1; i > 0; i--) {
            j = Math.floor(Math.random() * (i + 1));
            tmp = fresh[i]; fresh[i] = fresh[j]; fresh[j] = tmp;
        }
        // ...then prefer the closest fits. Ties keep their shuffled (random)
        // order, so the choice among equally good fits is genuinely random.
        fresh.sort(function (a, b) {
            return Math.abs(a.r - t) - Math.abs(b.r - t);
        });

        // This frame has run through every photo that suits it. That is expected
        // within a five-minute session for a shape the library is short of - only
        // a handful of photos are panorama-shaped, and a panorama frame gets
        // through those long before the layout is due to change.
        //
        // Let that frame's own photos come round again, and *only* that frame's:
        // wiping shownUrls wholesale would drop the no-repeat guarantee for every
        // other shape in the layout too, so a portrait frame with 190 photos still
        // to draw on would start repeating just because the panorama beside it ran
        // dry.
        if (isSwap && (fresh.length === 0 || Math.abs(fresh[0].r - t) / t > fitTolerance)) {
            var kept = [];
            for (i = 0; i < shownUrls.length; i++) {
                var r = ratioOf(shownUrls[i]);
                if (r > 0 && Math.abs(r - t) / t <= fitTolerance)
                    continue;                  // suits this frame: free it up again
                kept.push(shownUrls[i]);
            }
            if (kept.length < shownUrls.length) {
                shownUrls = kept;
                return pickPhoto(targetRatio, currentUrl);
            }
            // Nothing to release: fall through and show the closest there is.
        }
        if (fresh.length === 0)
            return "";

        // Every fresh photo that fits this frame acceptably is an equal candidate
        // - deliberately not just the N closest. A fixed top-N window looks fair
        // but isn't: 189 photos here are *exactly* 3:4, so they occupy the window
        // permanently, and shapes that suit the frame perfectly well but less
        // exactly (the 2:3 camera portraits) rank just outside it and are never
        // shown at all, however long the wallpaper runs.
        var band = [];
        for (i = 0; i < fresh.length; i++) {
            if (Math.abs(fresh[i].r - t) / t > fitTolerance)
                break;             // sorted by fit: nothing after this qualifies
            band.push(fresh[i]);
        }
        if (band.length === 0)
            band = [fresh[0]];     // nothing suits it: the closest there is

        // Keep near-duplicates apart. The band is chosen purely on shape, so it
        // happily contains several frames of the same burst; without this, two of
        // them can land on adjacent frames at once (they share a shape, after
        // all). Drop candidates whose sequence number is close to anything already
        // on screen, unless that would leave nothing - a real fit beats spacing.
        if (sequenceGap > 0 && band.length > 1) {
            var spaced = [];
            for (i = 0; i < band.length; i++) {
                var s = seqOf(band[i].url);
                var clear = true;
                for (j = 0; j < usedUrls.length; j++) {
                    var su = seqOf(usedUrls[j]);
                    if (s >= 0 && su >= 0 && Math.abs(s - su) < sequenceGap) {
                        clear = false;
                        break;
                    }
                }
                if (clear)
                    spaced.push(band[i]);
            }
            if (spaced.length > 0)
                band = spaced;
        }

        var url = band[Math.floor(Math.random() * band.length)].url;
        shownUrls.push(url);
        showCounts[url] = (showCounts[url] || 0) + 1;   // feeds frameHunger()
        return url;
    }

    function reserve(newUrl, oldUrl) {
        var i = usedUrls.indexOf(oldUrl);
        if (i >= 0) usedUrls.splice(i, 1);
        if (newUrl !== "" && usedUrls.indexOf(newUrl) < 0) usedUrls.push(newUrl);
    }
    function release(url) {
        var i = usedUrls.indexOf(url);
        if (i >= 0) usedUrls.splice(i, 1);
    }

    // ---- Automatic photo discovery ----
    FolderListModel {
        id: photos
        folder: Qt.resolvedUrl("../photos")
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp",
                      "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
        showDirs: false
        caseSensitive: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) mosaic.onPhotosFound()
    }

    function onPhotosFound() {
        if (discovered || photos.count === 0)
            return;
        discovered = true;

        var list = [];
        for (var i = 0; i < photos.count; i++)
            list.push("" + photos.get(i, "fileURL"));
        allPhotos = list;

        // Measure aspect ratios first (tiny, very fast decodes), THEN build the
        // grid: each tile immediately gets a well-fitting photo, decoded only
        // once. startFallback guarantees the grid shows even if measuring stalls.
        startClassifying();
        startFallback.start();
    }

    // Shows the first grid and starts the timers (once).
    function beginShow() {
        if (started)
            return;
        started = true;
        buildProfiles();            // needs the screen size, so not before now
        startTransition();          // builds the first grid, fades it in when loaded
        swapTimer.start();
        if (relayoutEnabled)
            layoutTimer.start();
    }

    // ---- Background aspect-ratio measurement ----
    property int measureCursor: 0
    property int measuredCount: 0

    function startClassifying() {
        classified = false;
        infos = [];
        measureCursor = 0;
        measuredCount = 0;
        for (var i = 0; i < measurers.count; i++)
            measurers.itemAt(i).loadNext();
    }
    function classify(url, w, h) {
        if (h <= 0) return;
        infos = infos.concat([{ url: url, r: w / h }]);
        ratios[url] = w / h;
    }
    function onMeasured() {
        measuredCount++;
        if (measuredCount >= allPhotos.length && !classified) {
            classified = true;
            startFallback.stop();
            beginShow();           // ratios known: build the best-fitting grid
        }
    }

    // A few parallel loaders that measure the photos' dimensions.
    Repeater {
        id: measurers
        model: 6
        Image {
            visible: false
            asynchronous: true
            cache: false
            autoTransform: true              // honor EXIF orientation for a correct ratio
            sourceSize.height: 120           // tiny decode: we only need the proportions
            property string url: ""
            function loadNext() {
                if (mosaic.measureCursor < mosaic.allPhotos.length) {
                    url = mosaic.allPhotos[mosaic.measureCursor++];
                    source = url;
                } else {
                    url = "";
                    source = "";
                }
            }
            onStatusChanged: {
                if (status === Image.Ready) {
                    // implicitWidth/Height = decoded size with aspect ratio kept.
                    // (sourceSize.width reads back as 0 when only height is set.)
                    mosaic.classify(url, implicitWidth, implicitHeight);
                    source = "";
                    mosaic.onMeasured();
                    loadNext();
                } else if (status === Image.Error) {
                    mosaic.onMeasured();
                    loadNext();
                }
            }
        }
    }

    // ---- The mosaic ----
    // Holds the grid on screen, plus (briefly, during a re-arrange) the next one
    // being preloaded behind it.
    Item {
        id: stage
        anchors.fill: parent
        anchors.margins: mosaic.gap / 2
    }

    Component {
        id: gridComponent
        HuangjinGrid {
            anchors.fill: parent       // fills the stage; without a size, no tiles
            controller: mosaic
            gap: mosaic.gap
            cornerRadius: mosaic.cornerRadius
        }
    }

    property var liveGrid: null        // the grid currently on screen
    property var incomingGrid: null    // a grid being preloaded for the next layout
    // Guards the whole re-arrange, from "decide to change" to "crossfade done".
    // It must be set before the incoming grid is built, because building it calls
    // pickPhoto, which can itself ask for a re-arrange - and incomingGrid isn't
    // assigned until createObject returns, so it can't be the guard.
    property bool transitioning: false

    // ---- Choosing the next layout ----
    // Two pulls, multiplied together:
    //
    //  - freshness. A layout whose mix of frame shapes is unlike the one on screen
    //    is likelier to come next, so two portrait walls rarely follow each other
    //    and the wallpaper keeps changing character rather than just reshuffling.
    //
    //  - hunger. A layout is likelier if its frames draw on photos that have been
    //    shown least. This is the part that evens out *individual* photos: a photo
    //    in a big pool (a 3:4 portrait, one of ~190) gets far less screen time each
    //    than one in a small pool (a square, one of ~25), so left alone it is the
    //    common shapes that are starved per photo. Weighting by hunger pulls layout
    //    time back towards whichever photos are actually behind, which gives the
    //    popular shapes both more layouts and more time without hard-coding either.
    property real freshnessBias: 2.0
    property var showCounts: ({})      // url -> times displayed, for the whole session
    property var profiles: []          // per layout: fraction of its frames per shape

    // A frame's true aspect ratio: the cell's proportions times the screen's.
    function frameRatio(cell) {
        return (cell.w * mosaic.width) / (cell.h * mosaic.height);
    }

    function shapeBucket(r) {
        if (r < 0.60) return 0;        // very tall
        if (r < 0.72) return 1;        // 2:3
        if (r < 0.92) return 2;        // 3:4 portrait
        if (r < 1.15) return 3;        // square
        if (r < 1.45) return 4;        // 4:3 landscape
        if (r < 1.70) return 5;        // 3:2
        return 6;                      // panorama
    }

    function buildProfiles() {
        var out = [];
        for (var i = 0; i < layouts.length; i++) {
            var p = [0, 0, 0, 0, 0, 0, 0];
            var cells = layouts[i];
            for (var j = 0; j < cells.length; j++)
                p[shapeBucket(frameRatio(cells[j]))] += 1 / cells.length;
            out.push(p);
        }
        profiles = out;
    }

    // 0 = the same mix of shapes, 1 = no shape in common.
    function profileDistance(a, b) {
        var d = 0;
        for (var k = 0; k < a.length; k++)
            d += Math.abs(a[k] - b[k]);
        return d / 2;
    }

    // How under-shown, on average, are the photos a frame of this ratio draws on.
    // Cubed: a gentle preference for the hungriest barely moves the needle. Cubing
    // it measurably tightens the spread of screen time across photos (a fourth
    // power adds almost nothing further).
    function frameHunger(t) {
        var sum = 0, n = 0;
        for (var i = 0; i < infos.length; i++) {
            if (Math.abs(infos[i].r - t) / t <= fitTolerance) {
                var q = 1 / (1 + (showCounts[infos[i].url] || 0));
                sum += q * q * q;
                n++;
            }
        }
        return n > 0 ? sum / n : 0;
    }

    function chooseLayout() {
        if (layouts.length < 2)
            return 0;

        var weights = [], total = 0, i, j;
        for (i = 0; i < layouts.length; i++) {
            if (i === currentLayout) {     // never the same one twice running
                weights.push(0);
                continue;
            }
            var cells = layouts[i];
            var hunger = 0;
            for (j = 0; j < cells.length; j++)
                hunger += frameHunger(frameRatio(cells[j]));
            hunger /= cells.length;

            var fresh = 1;
            if (currentLayout >= 0 && profiles.length === layouts.length)
                fresh += freshnessBias * profileDistance(profiles[i], profiles[currentLayout]);

            weights.push(hunger * fresh);
            total += hunger * fresh;
        }

        if (total <= 0) {                  // nothing measured yet: plain random
            var k = Math.floor(Math.random() * layouts.length);
            while (k === currentLayout)
                k = Math.floor(Math.random() * layouts.length);
            return k;
        }

        var r = Math.random() * total;
        for (i = 0; i < layouts.length; i++) {
            r -= weights[i];
            if (r <= 0)
                return i;
        }
        return layouts.length - 1;
    }

    // Starts a re-arrange. The next layout's grid is created straight away but
    // invisible, so its photos are picked and decoded while the current layout is
    // still on screen. Only when it reports itself fully loaded do we crossfade,
    // so a layout change never shows empty frames or pop-in.
    function startTransition() {
        if (transitioning)
            return;                    // one is already in flight
        transitioning = true;

        // Stop the outgoing grid swapping photos while the next one loads, so it
        // can't consume the new session's pool on its way out.
        if (liveGrid !== null)
            liveGrid.live = false;

        // A new session: the whole library is available again.
        shownUrls = [];

        var idx = chooseLayout();

        var g = gridComponent.createObject(stage, { layout: layouts[idx], nextIndex: idx });
        if (g === null) {
            transitioning = false;
            return;
        }
        incomingGrid = g;
        g.ready.connect(finishTransition);
        preloadTimeout.restart();
    }

    function finishTransition() {
        if (incomingGrid === null) {
            transitioning = false;
            return;
        }
        preloadTimeout.stop();

        var next = incomingGrid;
        var old = liveGrid;
        incomingGrid = null;

        next.ready.disconnect(finishTransition);
        currentLayout = next.nextIndex;
        liveGrid = next;
        next.live = true;
        next.fadeIn();                 // fully decoded: fade it in over the old one

        if (old !== null) {
            old.live = false;
            old.fadeOut();
            // Destroy once faded out; its tiles then release their photos.
            old.destroy(1400);
        }

        transitioning = false;
    }

    // ---- Timers ----
    Timer {
        id: swapTimer
        interval: mosaic.swapMin + Math.random() * (mosaic.swapMax - mosaic.swapMin)
        repeat: true
        onTriggered: {
            if (mosaic.liveGrid !== null)
                mosaic.liveGrid.swapAgedTile();
            interval = mosaic.swapMin + Math.random() * (mosaic.swapMax - mosaic.swapMin);
        }
    }
    // Safety net: if measuring stalls (unreadable photos, etc.), show the grid
    // anyway after 2.5 s.
    Timer {
        id: startFallback
        interval: 2500
        repeat: false
        onTriggered: mosaic.beginShow()
    }
    // Safety net: if a photo in the incoming grid never finishes decoding, show
    // that grid anyway rather than staying on the old layout forever.
    Timer {
        id: preloadTimeout
        interval: 8000
        repeat: false
        onTriggered: if (mosaic.incomingGrid !== null) mosaic.incomingGrid.forceReady()
    }
    // Re-arrange into a different layout on the clock. Because the next grid is
    // preloaded off-screen, the change lands a second or two after this fires.
    Timer {
        id: layoutTimer
        interval: mosaic.layoutInterval
        repeat: true
        onTriggered: mosaic.startTransition()
    }
}

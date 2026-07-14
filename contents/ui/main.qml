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
    // Each photo changes roughly every 4s.
    property int swapMin: 3800
    property int swapMax: 4800
    // Upper bound on how long one layout stays up. A layout usually changes
    // sooner than this, on its own: see shownUrls. This is only the cap, for
    // layouts broad enough that they'd otherwise run for a quarter of an hour.
    property int layoutMin: 300000
    property int layoutMax: 420000
    // Floor on a layout's life, so a small photo library (which can run a layout
    // out of fresh photos in seconds) can't turn into a slideshow of layouts.
    property int layoutMinDwell: 60000
    // How far a photo's aspect ratio may sit from its frame's and still count as
    // a fit. This is the single knob behind both which photos a frame will draw
    // on and when a layout has run out of them - see pickPhoto.
    property real fitTolerance: 0.18

    // ---- Layouts ----
    // A layout is a list of cells; a cell is a rectangle {x, y, w, h} in [0..1]
    // of the usable area. Cells tile the area exactly: no gaps, no overlaps.
    //
    // A frame's shape is not its cell's shape: on a 16:10 screen a cell's aspect
    // ratio is w * 1.6 / h. Every frame below is sized so that ratio lands on one
    // of the shapes photos actually come in - 0.75 (3:4 portrait), 1.0 (square),
    // 1.33 (4:3 landscape), 1.5 (3:2) - because a frame shaped like nothing in
    // the library can only ever be filled with blur. See the README before
    // editing these.
    property var layouts: [
        // 1 - portrait wall: eight 3:4 frames
        [
            {x:0.00, y:0.00, w:0.25, h:0.50}, {x:0.25, y:0.00, w:0.25, h:0.50},
            {x:0.50, y:0.00, w:0.25, h:0.50}, {x:0.75, y:0.00, w:0.25, h:0.50},
            {x:0.00, y:0.50, w:0.25, h:0.50}, {x:0.25, y:0.50, w:0.25, h:0.50},
            {x:0.50, y:0.50, w:0.25, h:0.50}, {x:0.75, y:0.50, w:0.25, h:0.50}
        ],
        // 2 - full-height portrait hero, flanks split at opposite heights
        [
            {x:0.0000, y:0.00, w:0.2655, h:0.57}, {x:0.0000, y:0.57, w:0.2655, h:0.43},
            {x:0.2655, y:0.00, w:0.4690, h:1.00},
            {x:0.7345, y:0.00, w:0.2655, h:0.43}, {x:0.7345, y:0.43, w:0.2655, h:0.57}
        ],
        // 3 - portrait hero hard left, two mixed columns beside it
        [
            {x:0.000, y:0.000, w:0.469, h:1.000},
            {x:0.469, y:0.000, w:0.260, h:0.415}, {x:0.469, y:0.415, w:0.260, h:0.312},
            {x:0.469, y:0.727, w:0.260, h:0.273},
            {x:0.729, y:0.000, w:0.271, h:0.580}, {x:0.729, y:0.580, w:0.271, h:0.420}
        ],
        // 4 - row of portraits over a square/landscape/square band
        [
            {x:0.00, y:0.00, w:0.25, h:0.52}, {x:0.25, y:0.00, w:0.25, h:0.52},
            {x:0.50, y:0.00, w:0.25, h:0.52}, {x:0.75, y:0.00, w:0.25, h:0.52},
            {x:0.00, y:0.52, w:0.30, h:0.48}, {x:0.30, y:0.52, w:0.40, h:0.48},
            {x:0.70, y:0.52, w:0.30, h:0.48}
        ],
        // 5 - quilt: uneven landscape/square strip over portrait + square
        [
            {x:0.0000, y:0.00, w:0.1688, h:0.36}, {x:0.1688, y:0.00, w:0.3000, h:0.36},
            {x:0.4688, y:0.00, w:0.3000, h:0.36}, {x:0.7688, y:0.00, w:0.2312, h:0.36},
            {x:0.0000, y:0.36, w:0.3000, h:0.64}, {x:0.3000, y:0.36, w:0.4000, h:0.64},
            {x:0.7000, y:0.36, w:0.3000, h:0.64}
        ],
        // 6 - two big landscapes over a mixed row
        [
            {x:0.0000, y:0.00, w:0.5000, h:0.60}, {x:0.5000, y:0.00, w:0.5000, h:0.60},
            {x:0.0000, y:0.60, w:0.1875, h:0.40}, {x:0.1875, y:0.60, w:0.1875, h:0.40},
            {x:0.3750, y:0.60, w:0.3750, h:0.40}, {x:0.7500, y:0.60, w:0.2500, h:0.40}
        ],
        // 7 - band of four landscapes over three tall portraits
        [
            {x:0.0000, y:0.00, w:0.2500, h:0.30}, {x:0.2500, y:0.00, w:0.2500, h:0.30},
            {x:0.5000, y:0.00, w:0.2500, h:0.30}, {x:0.7500, y:0.00, w:0.2500, h:0.30},
            {x:0.0000, y:0.30, w:0.3281, h:0.70}, {x:0.3281, y:0.30, w:0.3281, h:0.70},
            {x:0.6562, y:0.30, w:0.3438, h:0.70}
        ],
        // 8 - staircase: three columns, each breaking at a different height
        [
            {x:0.0000, y:0.0000, w:0.3600, h:0.5720}, {x:0.0000, y:0.5720, w:0.3600, h:0.4280},
            {x:0.3600, y:0.0000, w:0.2655, h:0.4300}, {x:0.3600, y:0.4300, w:0.2655, h:0.5700},
            {x:0.6255, y:0.0000, w:0.3745, h:0.5992}, {x:0.6255, y:0.5992, w:0.3745, h:0.4008}
        ],
        // 9 - portrait hero left, 3x2 grid of landscapes right
        [
            {x:0.0000, y:0.0000, w:0.4690, h:1.0000},
            {x:0.4690, y:0.0000, w:0.2655, h:0.3333}, {x:0.7345, y:0.0000, w:0.2655, h:0.3333},
            {x:0.4690, y:0.3333, w:0.2655, h:0.3334}, {x:0.7345, y:0.3333, w:0.2655, h:0.3334},
            {x:0.4690, y:0.6667, w:0.2655, h:0.3333}, {x:0.7345, y:0.6667, w:0.2655, h:0.3333}
        ]
    ]
    property int currentLayout: -1
    property bool started: false
    property bool discovered: false
    // Periodic re-arrange (see layoutMin/layoutMax).
    // Set to false to keep one fixed layout for the whole session.
    property bool relayoutEnabled: true

    // ---- Photos (with measured aspect ratio) ----
    property var allPhotos: []     // urls only (fallback before measuring)
    property var infos: []         // [{url, r}] once measured (r = width / height)
    property var usedUrls: []      // on screen right now
    property var shownUrls: []     // shown at any point during this layout session
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

        // Nothing fresh left that suits this frame: the layout is spent.
        if (fresh.length === 0 || Math.abs(fresh[0].r - t) / t > fitTolerance) {
            if (isSwap && requestRelayout())
                // Hold the photo we have rather than drop in a blurry or repeated
                // one: the layout is changing anyway.
                return "";
            if (isSwap && shownUrls.length > 0) {
                // Spent, but we can't re-arrange (it's disabled, one is already
                // running, or this layout only just went up). Let the library come
                // round again so the photos at least keep moving.
                shownUrls = [];
                return pickPhoto(targetRatio, currentUrl);
            }
            // Filling a new grid: show the best there is rather than an empty frame.
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

        var url = band[Math.floor(Math.random() * band.length)].url;
        shownUrls.push(url);
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
    property double sessionStart: 0    // Date.now() when the live layout went up

    // Asked for when a layout has no fresh, well-fitting photos left to show.
    // Returns whether a re-arrange is actually starting: the caller needs to know,
    // because if not, it has to find that frame a photo some other way.
    function requestRelayout() {
        if (transitioning || !relayoutEnabled)
            return false;
        // A small library can exhaust a layout in seconds; don't let that turn
        // into a slideshow of layouts.
        if (Date.now() - sessionStart < layoutMinDwell)
            return false;
        startTransition();
        rearmLayoutTimer();            // the cap starts again with the new layout
        return true;
    }

    function rearmLayoutTimer() {
        layoutTimer.interval = layoutMin + Math.random() * (layoutMax - layoutMin);
        layoutTimer.restart();
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

        var idx = 0;
        if (layouts.length > 1)
            do { idx = Math.floor(Math.random() * layouts.length); }
            while (idx === currentLayout);

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

        sessionStart = Date.now();     // this layout's no-repeat session begins now
        transitioning = false;
    }

    // ---- Timers ----
    Timer {
        id: swapTimer
        interval: mosaic.swapMin + Math.random() * (mosaic.swapMax - mosaic.swapMin)
        repeat: true
        onTriggered: {
            if (mosaic.liveGrid !== null)
                mosaic.liveGrid.swapRandomTile();
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
    // The cap: a layout that still has fresh photos left after this long gets
    // re-arranged anyway. Layouts that run out sooner change sooner, on their own.
    Timer {
        id: layoutTimer
        interval: mosaic.layoutMin + Math.random() * (mosaic.layoutMax - mosaic.layoutMin)
        repeat: true
        onTriggered: {
            mosaic.startTransition();
            interval = mosaic.layoutMin + Math.random() * (mosaic.layoutMax - mosaic.layoutMin);
        }
    }
}

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
    // Full re-arrange into a different layout (every 8-12 min).
    property int layoutMin: 480000
    property int layoutMax: 720000

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
    property var usedUrls: []
    property bool classified: false

    // Picks a photo for a frame of the given aspect ratio, balancing fit and
    // randomness: among photos that fit the frame about equally well it chooses
    // at random, so (e.g.) the 180+ 3:4 portraits all get their turn rather than
    // the same few showing every time. Avoids the current photo and any already
    // shown elsewhere (including in a grid being preloaded).
    function pickPhoto(targetRatio, currentUrl) {
        var pool = infos;
        if (!pool || pool.length === 0) {
            // Not measured yet: fall back to any url.
            if (!allPhotos || allPhotos.length === 0) return "";
            return allPhotos[Math.floor(Math.random() * allPhotos.length)];
        }

        var cands = [];
        var i;
        for (i = 0; i < pool.length; i++)
            if (pool[i].url !== currentUrl && usedUrls.indexOf(pool[i].url) < 0)
                cands.push(pool[i]);
        if (cands.length === 0)
            for (i = 0; i < pool.length; i++)
                if (pool[i].url !== currentUrl)
                    cands.push(pool[i]);
        if (cands.length === 0)
            cands = pool.slice();

        // Shuffle first, so that photos which fit equally well (many share the
        // exact same shape, e.g. 3:4) end up in random order...
        for (i = cands.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = cands[i]; cands[i] = cands[j]; cands[j] = tmp;
        }
        // ...then prefer the closest-fitting ones. Ties keep their shuffled
        // (random) order, so the choice among good fits is genuinely random.
        var t = targetRatio > 0 ? targetRatio : 1.0;
        cands.sort(function (a, b) {
            return Math.abs(a.r - t) - Math.abs(b.r - t);
        });
        var k = Math.min(cands.length, 10);
        return cands[Math.floor(Math.random() * k)].url;
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

    // Starts a re-arrange. The next layout's grid is created straight away but
    // invisible, so its photos are picked and decoded while the current layout is
    // still on screen. Only when it reports itself fully loaded do we crossfade,
    // so a layout change never shows empty frames or pop-in.
    function startTransition() {
        if (incomingGrid !== null)
            return;                    // one is already in flight

        var idx = 0;
        if (layouts.length > 1)
            do { idx = Math.floor(Math.random() * layouts.length); }
            while (idx === currentLayout);

        var g = gridComponent.createObject(stage, { layout: layouts[idx], nextIndex: idx });
        if (g === null)
            return;
        incomingGrid = g;
        g.ready.connect(finishTransition);
        preloadTimeout.restart();
    }

    function finishTransition() {
        if (incomingGrid === null)
            return;
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

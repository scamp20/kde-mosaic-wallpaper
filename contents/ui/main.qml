import QtQuick
import Qt.labs.folderlistmodel

// Native photo-mosaic wallpaper (no web view):
//  - discovers the photos in the photos/ folder
//  - measures each photo's aspect ratio
//  - lays them out as a "balanced surround": top/bottom rows ring a centered,
//    inset hero. Each frame is filled with the photo whose shape fits it best,
//    so there is minimal blurred space whatever the frame's proportion.
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
    // Full grid re-arrange, to mix up the frame shapes (every 20-30 min).
    property int layoutMin: 1200000
    property int layoutMax: 1800000

    // ---- Layouts ----
    // Each layout is a list of cells; a cell is a rectangle {x, y, w, h} in
    // [0..1] of the usable area. The library is mostly 3:4 portraits, so the
    // layouts are portrait-dominant: lots of tall frames plus a featured hero.
    // Frame shape is not labelled: each cell is filled with the photo whose
    // aspect ratio fits it best, so blurred space stays minimal.
    property var layouts: [
        // A - tall portrait hero, stacked portrait flanks (all portrait)
        [
            {x:0.00, y:0.00, w:0.26, h:0.50}, {x:0.00, y:0.50, w:0.26, h:0.50},
            {x:0.26, y:0.00, w:0.48, h:1.00},
            {x:0.74, y:0.00, w:0.26, h:0.50}, {x:0.74, y:0.50, w:0.26, h:0.50}
        ],
        // B - landscape hero inset, ringed by portrait flanks + landscape strips
        [
            {x:0.00, y:0.00, w:0.24, h:0.50}, {x:0.00, y:0.50, w:0.24, h:0.50},
            {x:0.24, y:0.00, w:0.26, h:0.27}, {x:0.50, y:0.00, w:0.26, h:0.27},
            {x:0.24, y:0.27, w:0.52, h:0.46},
            {x:0.24, y:0.73, w:0.26, h:0.27}, {x:0.50, y:0.73, w:0.26, h:0.27},
            {x:0.76, y:0.00, w:0.24, h:0.50}, {x:0.76, y:0.50, w:0.24, h:0.50}
        ],
        // C - portrait wall (eight 3:4 frames)
        [
            {x:0.00, y:0.00, w:0.25, h:0.50}, {x:0.25, y:0.00, w:0.25, h:0.50},
            {x:0.50, y:0.00, w:0.25, h:0.50}, {x:0.75, y:0.00, w:0.25, h:0.50},
            {x:0.00, y:0.50, w:0.25, h:0.50}, {x:0.25, y:0.50, w:0.25, h:0.50},
            {x:0.50, y:0.50, w:0.25, h:0.50}, {x:0.75, y:0.50, w:0.25, h:0.50}
        ],
        // D - tall hero on the left, portrait grid filling the rest
        [
            {x:0.00, y:0.00, w:0.30, h:1.00},
            {x:0.30, y:0.00, w:0.2333, h:0.50}, {x:0.5333, y:0.00, w:0.2333, h:0.50},
            {x:0.7667, y:0.00, w:0.2333, h:0.50},
            {x:0.30, y:0.50, w:0.2333, h:0.50}, {x:0.5333, y:0.50, w:0.2333, h:0.50},
            {x:0.7667, y:0.50, w:0.2333, h:0.50}
        ]
    ]
    property int currentLayout: 0
    property bool started: false
    property bool discovered: false
    // Periodic full re-arrange of the grid (see layoutMin/layoutMax).
    // Set to false to keep one fixed layout for the whole session.
    property bool relayoutEnabled: true

    // ---- Photos (with measured aspect ratio) ----
    property var allPhotos: []     // urls only (fallback before measuring)
    property var infos: []         // [{url, r}] once measured (r = width / height)
    property var usedUrls: []
    property bool classified: false

    // Picks a photo for a frame of the given aspect ratio, balancing fit and
    // randomness: among photos that fit the frame about equally well it chooses
    // at random, so (e.g.) the 100+ 3:4 portraits all get their turn rather than
    // the same few showing every time. Avoids the current photo and any already
    // shown elsewhere.
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

    // ---- Tile registry (for the periodic swap) ----
    property var tiles: []
    function registerTile(t) { tiles.push(t); }
    function unregisterTile(t) { var i = tiles.indexOf(t); if (i >= 0) tiles.splice(i, 1); }

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

    // FolderListModel's URL role was renamed fileURL -> fileUrl in Qt 6; try
    // both (and filePath as a last resort) so this works regardless.
    function fileUrlAt(i) {
        var u = photos.get(i, "fileUrl");
        if (u === undefined) u = photos.get(i, "fileURL");
        if (u === undefined) u = photos.get(i, "filePath");
        return "" + u;
    }

    function onPhotosFound() {
        if (discovered || photos.count === 0)
            return;
        discovered = true;

        var list = [];
        for (var i = 0; i < photos.count; i++)
            list.push(fileUrlAt(i));
        allPhotos = list;

        currentLayout = Math.floor(Math.random() * layouts.length);

        // Measure aspect ratios first (tiny, very fast decodes), THEN build the
        // grid: each tile immediately gets a well-fitting photo, decoded only
        // once. startFallback guarantees the grid shows even if measuring stalls.
        startClassifying();
        startFallback.start();
    }

    // Shows the grid and starts the timers (once).
    function beginShow() {
        if (started)
            return;
        started = true;            // triggers grid construction
        swapTimer.start();
        if (relayoutEnabled)
            layoutTimer.start();
    }

    function rebuildLayout() {
        var idx;
        do { idx = Math.floor(Math.random() * layouts.length); }
        while (layouts.length > 1 && idx === currentLayout);
        currentLayout = idx;       // the Repeater rebuilds the tiles
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

    // ---- The grid (absolute-positioned mosaic cells) ----
    Item {
        id: grid
        anchors.fill: parent
        anchors.margins: mosaic.gap / 2

        Repeater {
            id: cells
            model: mosaic.started ? mosaic.layouts[mosaic.currentLayout] : 0

            HuangjinTile {
                controller: mosaic
                cornerRadius: mosaic.cornerRadius
                x: modelData.x * grid.width + mosaic.gap / 2
                y: modelData.y * grid.height + mosaic.gap / 2
                width: modelData.w * grid.width - mosaic.gap
                height: modelData.h * grid.height - mosaic.gap
            }
        }
    }

    // ---- Timers ----
    Timer {
        id: swapTimer
        interval: mosaic.swapMin + Math.random() * (mosaic.swapMax - mosaic.swapMin)
        repeat: true
        onTriggered: {
            if (mosaic.tiles.length > 0)
                mosaic.tiles[Math.floor(Math.random() * mosaic.tiles.length)].swapImage();
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
    Timer {
        id: layoutTimer
        interval: mosaic.layoutMin + Math.random() * (mosaic.layoutMax - mosaic.layoutMin)
        repeat: true
        onTriggered: {
            mosaic.rebuildLayout();
            interval = mosaic.layoutMin + Math.random() * (mosaic.layoutMax - mosaic.layoutMin);
        }
    }
}

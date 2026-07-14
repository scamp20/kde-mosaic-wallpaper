import QtQuick 2.15

// One complete arrangement of the mosaic: the cells of a single layout, each
// holding a tile.
//
// A grid starts invisible and announces ready() only once every one of its
// tiles has finished decoding its first photo. That is what makes a layout
// change seamless: the next grid is built and decoded off-screen while the
// current one is still on display, and is only faded in once it is complete,
// so a new layout never appears as a set of empty frames filling in one by one.
//
// The id is gridRoot, not grid: the tiles have a `grid` property, and inside a
// delegate an own property shadows an outer id, so `grid: grid` would bind to
// itself.
Item {
    id: gridRoot

    property var controller             // the root (main.qml)
    property var layout: []             // cells: [{x, y, w, h}, ...]
    property int nextIndex: -1          // which entry of controller.layouts this is
    property int gap: 12
    property real cornerRadius: 22
    property bool live: false           // only the on-screen grid cycles its photos

    signal ready()

    opacity: 0                          // faded in by the controller once ready

    property int settledCount: 0
    property bool announced: false

    // Each tile calls this once its first photo has finished loading (or failed).
    function tileSettled() {
        settledCount++;
        if (!announced && settledCount >= (layout ? layout.length : 0)) {
            announced = true;
            gridRoot.ready();
        }
    }

    // Backstop: show the grid even if some photo never finishes decoding.
    function forceReady() {
        if (!announced) {
            announced = true;
            gridRoot.ready();
        }
    }

    // Picks which tile to change next. Weighted by how long each photo has been
    // up (age cubed), so the oldest is usually the one to go and a photo that has
    // only just arrived is almost never yanked straight back off - which is what
    // a uniform random pick kept doing. It stays a weighted draw rather than
    // "always the oldest" so the wallpaper doesn't cycle in a visibly fixed order.
    //
    // Tiles are read from the Repeater rather than a cached list: if the Repeater
    // rebuilds (a resize), a cached list would hold dead objects.
    function swapAgedTile() {
        if (!live || cells.count === 0)
            return;

        var now = Date.now();
        var weights = [];
        var total = 0;
        var i, t, age, w;

        for (i = 0; i < cells.count; i++) {
            t = cells.itemAt(i);
            if (!t) {
                weights.push(0);
                continue;
            }
            age = Math.max(0, now - t.shownAt) / 1000;
            w = age * age * age;
            weights.push(w);
            total += w;
        }

        if (total <= 0) {          // a brand-new grid: every photo is the same age
            t = cells.itemAt(Math.floor(Math.random() * cells.count));
            if (t)
                t.swapImage();
            return;
        }

        var r = Math.random() * total;
        for (i = 0; i < cells.count; i++) {
            r -= weights[i];
            if (r <= 0) {
                t = cells.itemAt(i);
                if (t)
                    t.swapImage();
                return;
            }
        }
    }

    NumberAnimation {
        id: fade
        target: gridRoot
        property: "opacity"
        duration: 1100
        easing.type: Easing.InOutQuad
    }
    function fadeIn()  { fade.to = 1; fade.restart(); }
    function fadeOut() { fade.to = 0; fade.restart(); }

    Repeater {
        id: cells
        // Wait for a real size: a tile picks its photo to match its own
        // width/height, so building tiles before the grid is measured would pick
        // against a meaningless ratio.
        model: (gridRoot.width > 0 && gridRoot.height > 0) ? gridRoot.layout : 0

        HuangjinTile {
            grid: gridRoot
            controller: gridRoot.controller
            cornerRadius: gridRoot.cornerRadius
            x: modelData.x * gridRoot.width + gridRoot.gap / 2
            y: modelData.y * gridRoot.height + gridRoot.gap / 2
            width: modelData.w * gridRoot.width - gridRoot.gap
            height: modelData.h * gridRoot.height - gridRoot.gap
        }
    }
}

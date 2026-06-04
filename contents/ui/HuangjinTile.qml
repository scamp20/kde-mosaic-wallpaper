import QtQuick 2.15
import QtGraphicalEffects 1.0

// One tile: two HuangjinPhoto layers that crossfade into each other, with
// rounded corners via a mask. The tile asks the controller for the photo whose
// aspect ratio best matches its own width/height, so blurred space is minimal.
Item {
    id: tile

    property real cornerRadius: 22
    property var controller             // reference to the root (main.qml)
    property string currentUrl: ""
    property bool frontIsA: true

    opacity: 0
    scale: 0.96

    Item {
        id: content
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask { maskSource: maskRect }

        HuangjinPhoto {
            id: layerA
            anchors.fill: parent
            opacity: tile.frontIsA ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }
        HuangjinPhoto {
            id: layerB
            anchors.fill: parent
            opacity: tile.frontIsA ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }
    }

    Rectangle {
        id: maskRect
        anchors.fill: parent
        radius: tile.cornerRadius
        visible: false
    }

    // Gentle fade-in on creation.
    ParallelAnimation {
        id: appear
        NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 650; easing.type: Easing.OutCubic }
        NumberAnimation { target: tile; property: "scale"; to: 1; duration: 650; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: {
        var url = controller.pickPhoto(tile.width / tile.height, "");
        tile.currentUrl = url;
        (frontIsA ? layerA : layerB).imageUrl = url;
        if (url !== "")
            controller.reserve(url, "");
        controller.registerTile(tile);
        appear.start();
    }

    Component.onDestruction: {
        controller.unregisterTile(tile);
        controller.release(tile.currentUrl);
    }

    // Replaces the tile's photo with another (best fit for this frame),
    // crossfading once the new image is decoded.
    function swapImage() {
        var next = controller.pickPhoto(tile.width / tile.height, tile.currentUrl);
        if (next === "" || next === tile.currentUrl)
            return;

        var back = frontIsA ? layerB : layerA;

        if (back.imageUrl === next) {
            // Already loaded in the back layer: switch directly.
            controller.reserve(next, tile.currentUrl);
            tile.currentUrl = next;
            tile.frontIsA = !tile.frontIsA;
            return;
        }

        var onReady = function () {
            back.loaded.disconnect(onReady);
            controller.reserve(next, tile.currentUrl);
            tile.currentUrl = next;
            tile.frontIsA = !tile.frontIsA;
        };
        back.loaded.connect(onReady);
        back.imageUrl = next;
    }
}

import QtQuick 2.15
import QtGraphicalEffects 1.0

// One photo: a blurred, filled ("cover") background behind the whole photo
// (never cropped, "contain"). The blur fills any side bands.
Item {
    id: layer

    property string imageUrl: ""
    property int blurRadius: 32

    // Emitted when the sharp photo is decoded and ready to display.
    signal loaded()

    // Background: a filled + blurred version of the same image.
    Image {
        id: bg
        anchors.fill: parent
        source: layer.imageUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false                  // don't keep decoded backgrounds in RAM
        autoTransform: true           // honor EXIF orientation (else photos look sideways)
        sourceSize: Qt.size(224, 224) // low resolution: it's blurred anyway
        visible: false
    }
    FastBlur {
        anchors.fill: parent
        source: bg
        radius: layer.blurRadius
    }
    // Light veil so the blurred background doesn't overpower the sharp photo.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.20
    }

    // Sharp, whole photo.
    Image {
        id: fg
        anchors.fill: parent
        source: layer.imageUrl
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false                  // don't pile up decoded images: ~5x less RAM
        autoTransform: true           // honor EXIF orientation (else photos look sideways)
        sourceSize: Qt.size(800, 800) // sharp enough for a tile (incl. Ken Burns zoom)
        transformOrigin: Item.Center
        transform: Translate { id: drift }
        onStatusChanged: if (status === Image.Ready) layer.loaded()
    }

    // Ken Burns, anchored to the "whole photo" fit:
    //  - rest is scale 1.0 with no pan: the entire photo is shown, with the
    //    smallest blurred space possible for this photo in this frame.
    //  - it only ever zooms IN from there (cropping inward, hiding the bands)
    //    and eases back to the fit. It never goes below 1.0, so it can't add
    //    blurred space. Panning happens only while zoomed in (drift is 0 at
    //    rest, so the pan never exposes a band).
    SequentialAnimation {
        running: fg.status === Image.Ready
        loops: Animation.Infinite
        // zoom in toward the top-left, then back to the fit
        ParallelAnimation {
            NumberAnimation { target: fg;    property: "scale"; from: 1.0; to: 1.10; duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "x";     from: 0;   to: 7;    duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "y";     from: 0;   to: -5;   duration: 15000; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: fg;    property: "scale"; from: 1.10; to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "x";     from: 7;    to: 0;   duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "y";     from: -5;   to: 0;   duration: 15000; easing.type: Easing.InOutSine }
        }
        // zoom in toward the bottom-right, then back to the fit
        ParallelAnimation {
            NumberAnimation { target: fg;    property: "scale"; from: 1.0; to: 1.10; duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "x";     from: 0;   to: -7;   duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "y";     from: 0;   to: 5;    duration: 15000; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: fg;    property: "scale"; from: 1.10; to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "x";     from: -7;   to: 0;   duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { target: drift; property: "y";     from: 5;    to: 0;   duration: 15000; easing.type: Easing.InOutSine }
        }
    }
}

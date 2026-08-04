// A 60-sample history, drawn as bars.
//
// Bars rather than a Canvas polyline: Canvas repaints through a software raster
// path and this would be running once a second on an iGPU, while a Repeater of
// thin Rectangles is scene-graph geometry that the compositor already knows how
// to batch. It also cannot fail to render, which a Canvas can.
//
// Values are RAW. The widget scales them itself against `max`, or against the
// largest value present when `max` is 0 — so a network graph rescales to
// whatever is happening rather than sitting flat at the bottom of a 1 Gb/s axis.

import QtQuick
import "root:/"

Item {
    id: root

    property var values: []
    property color color: Theme.primary

    // 0 means "scale to the tallest sample". Set it for anything with a real
    // ceiling, like CPU usage.
    property real max: 0

    implicitHeight: 28

    readonly property real peak: {
        if (root.max > 0)
            return root.max;
        let m = 0;
        for (let i = 0; i < root.values.length; i++)
            if (root.values[i] > m)
                m = root.values[i];
        // Never zero: dividing by it would put every bar at NaN height.
        return m > 0 ? m : 1;
    }

    Row {
        anchors.fill: parent
        spacing: 1
        layoutDirection: Qt.RightToLeft   // newest sample at the right edge

        Repeater {
            model: root.values.length

            Item {
                required property int index

                // The series is oldest-first; RightToLeft reverses it, so the
                // last element lands at the right.
                readonly property real value: root.values[root.values.length - 1 - index]

                width: Math.max(1, (root.width - (root.values.length - 1)) / root.values.length)
                height: root.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, parent.height * Math.min(1, parent.value / root.peak))
                    radius: width > 2 ? 1 : 0
                    color: root.color
                    opacity: 0.35 + 0.65 * Math.min(1, parent.value / root.peak)
                }
            }
        }
    }
}

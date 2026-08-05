// Month calendar.
//
// Monday-first with ISO week numbers down the left — German convention, and the
// week number is genuinely used here.
//
// A reference calendar, deliberately not connected to any calendar service.
// CalDAV means credentials, sync and an auth flow: real work with no relation
// to this project.
//
// Built as rows of {week, days[7]} rather than one flat grid. A single 8-wide
// Grid needs 48 cells for 42 days plus 6 week numbers, and interleaving them by
// index is the kind of arithmetic that is wrong once and then wrong forever.

import QtQuick
import "root:/"

Item {
    id: root

    property date shown: new Date()
    implicitHeight: col.implicitHeight

    readonly property date now: new Date()
    readonly property real weekColWidth: 22
    readonly property real dayWidth: (width - weekColWidth) / 7

    function page(delta) {
        const d = new Date(shown.getFullYear(), shown.getMonth(), 1);
        d.setMonth(d.getMonth() + delta);
        shown = d;
    }

    function today() {
        shown = new Date();
    }

    // ISO 8601: week 1 is the week containing the first Thursday of the year.
    function isoWeek(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        t.setDate(t.getDate() + 3 - ((t.getDay() + 6) % 7));   // -> Thursday
        const week1 = new Date(t.getFullYear(), 0, 4);
        return 1 + Math.round(
            ((t - week1) / 86400000 - 3 + ((week1.getDay() + 6) % 7)) / 7);
    }

    // Six rows, each { week, days: [{day, outside, today}] }.
    readonly property var rows: {
        const first = new Date(shown.getFullYear(), shown.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;      // 0 = Monday
        const start = new Date(first);
        start.setDate(1 - offset);

        const out = [];
        for (let r = 0; r < 6; r++) {
            const days = [];
            let monday = null;
            for (let c = 0; c < 7; c++) {
                const d = new Date(start);
                d.setDate(start.getDate() + r * 7 + c);
                if (c === 0) monday = d;
                days.push({
                    day: d.getDate(),
                    outside: d.getMonth() !== shown.getMonth(),
                    isToday: d.getFullYear() === now.getFullYear()
                          && d.getMonth() === now.getMonth()
                          && d.getDate() === now.getDate()
                });
            }
            out.push({ week: isoWeek(monday), days: days });
        }
        return out;
    }

    Column {
        id: col
        width: parent.width
        spacing: 1

        // ---- weekday header ----
        Row {
            width: parent.width
            spacing: 0

            Text {
                width: root.weekColWidth; height: 18
                text: "KW"
                color: Qt.alpha(Theme.textOnSurfaceVariant, 0.5)
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                Text {
                    required property string modelData
                    width: root.dayWidth; height: 18
                    text: modelData
                    color: Theme.textOnSurfaceVariant
                    font.family: "Inter"; font.pixelSize: 9
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // ---- six week rows ----
        Repeater {
            model: root.rows

            Row {
                required property var modelData
                width: col.width
                spacing: 0

                Text {
                    width: root.weekColWidth; height: 20
                    text: modelData.week
                    color: Qt.alpha(Theme.textOnSurfaceVariant, 0.45)
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                    font.features: ({ "tnum": 1 })
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: modelData.days

                    Item {
                        required property var modelData
                        width: root.dayWidth; height: 20

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20; height: 20; radius: 6
                            visible: modelData.isToday
                            color: Theme.primary
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: modelData.isToday ? Theme.surface
                                 : modelData.outside ? Qt.alpha(Theme.textOnSurfaceVariant, 0.3)
                                 : Theme.textOnSurfaceVariant
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
        }
    }
}

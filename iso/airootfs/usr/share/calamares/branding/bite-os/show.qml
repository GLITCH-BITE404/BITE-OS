/* BITE-OS — Calamares install slideshow (slideshowAPI 2)
 * Intro slide with a live elapsed clock + soft ETA, then a few full-screen
 * shots of what's being installed. Uses only core QtQuick primitives (Text,
 * Rectangle, Image, Timer, animations) so it renders on any Calamares/Qt build;
 * if an image is missing it just shows the dark background + caption. This pane
 * is cosmetic and cannot affect the install itself. */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    // ttf-jetbrains-mono-nerd registers this family name; fall back to any mono.
    property string mono: "JetBrainsMono Nerd Font, JetBrains Mono, monospace"
    property color bg:    "#0a0710"
    property color mag:   "#bd46dc"
    property color cyan:  "#3cc8eb"
    property color fg:    "#e6e6f0"
    property color dim:   "#9aa0b5"

    // 10-minute baseline used only for the "est. remaining" readout — clearly
    // labelled as an estimate, not a promise.
    property int baseline: 600
    property int elapsed:  0

    Timer {
        interval: 1000
        running: presentation.activatedInCalamares
        repeat: true
        property int tick: 0
        onTriggered: {
            presentation.elapsed += 1;
            tick += 1;
            if (tick % 9 === 0) presentation.goToNextSlide();
        }
    }

    function fmt(s) {
        if (s < 0) s = 0;
        var m = Math.floor(s / 60); var ss = s % 60;
        return (m < 10 ? "0" + m : "" + m) + ":" + (ss < 10 ? "0" + ss : "" + ss);
    }
    function remaining() {
        var r = presentation.baseline - presentation.elapsed;
        return r > 0 ? "~" + fmt(r) + " left (est.)" : "finishing up…";
    }

    // ── Slide 1: intro + time math ───────────────────────────────────────────
    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: presentation.bg
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.82
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "BITE-OS"; color: presentation.mag
                    font.pixelSize: 52; font.bold: true; font.family: presentation.mono
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "// THE SYSTEM BIT YOU"; color: presentation.cyan
                    font.pixelSize: 20; font.family: presentation.mono
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "Installing your glitch-themed, performance-obsessed desktop — two complete riced desktops, self-repair, and a watchdog that won't let you lock yourself out."
                    color: presentation.fg; font.pixelSize: 15; font.family: presentation.mono
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.5; height: 1; color: presentation.mag; opacity: 0.4
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "Typical install: 6–15 min   ·   SSD ~6 min   ·   HDD up to ~25 min"
                    color: presentation.dim; font.pixelSize: 13; font.family: presentation.mono
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Text {
                        text: "elapsed " + presentation.fmt(presentation.elapsed) + "   │   " + presentation.remaining()
                        color: presentation.cyan; font.pixelSize: 16; font.family: presentation.mono
                    }
                    Text {
                        text: "█"; color: presentation.cyan
                        font.pixelSize: 16; font.family: presentation.mono
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0; duration: 600 }
                            NumberAnimation { from: 0; to: 1; duration: 600 }
                        }
                    }
                }
            }
        }
    }

    // ── Screenshot slides ────────────────────────────────────────────────────
    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent; color: presentation.bg
            Image {
                anchors.centerIn: parent
                width: parent.width * 0.88; height: parent.height * 0.80
                fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                source: "slide-ilyamiro.png"
            }
            Text {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ilyamiro  ·  Hyprland desktop"
                color: presentation.mag; font.pixelSize: 16; font.family: presentation.mono
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent; color: presentation.bg
            Image {
                anchors.centerIn: parent
                width: parent.width * 0.88; height: parent.height * 0.80
                fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                source: "slide-glitch.png"
            }
            Text {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                text: "glitch mode  ·  the dedsec look"
                color: presentation.cyan; font.pixelSize: 16; font.family: presentation.mono
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent; color: presentation.bg
            Image {
                anchors.centerIn: parent
                width: parent.width * 0.88; height: parent.height * 0.80
                fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                source: "slide-caelestia.png"
            }
            Text {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                text: "caelestia  ·  the second riced desktop"
                color: presentation.mag; font.pixelSize: 16; font.family: presentation.mono
            }
        }
    }

    function onActivate() { presentation.currentSlide = 0; }
    function onLeave() {}
}

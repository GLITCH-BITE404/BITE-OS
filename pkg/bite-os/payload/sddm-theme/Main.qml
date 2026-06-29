import QtQuick 2.15
import QtMultimedia 5.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#020103"

    property string accent:  "#b48aff"
    property string accent2: "#33ffff"
    property string danger:  "#ff2d55"
    property string mono:    "JetBrains Mono"

    // splash | idle | chomp | locked | success
    property string mode: "splash"
    property int failCount: 0
    property int maxFails: 5
    property int lockoutSeconds: 30
    property int lockRemaining: 0
    property bool inputBusy: false

    property bool revealMode: false
    property int  revealedCount: 0
    onRevealModeChanged: if (!revealMode) revealedCount = 0

    // Background scene selector: 0=matrix, 1=geometric rings, 2=WD2 video, 3=signal skyline
    property int bgScene: 0
    Timer {
        interval: 7500
        running: root.mode !== "splash" && root.mode !== "success"
        repeat: true
        onTriggered: {
            root.bgScene = (root.bgScene + 1) % 4
            sceneCutFlash.start()
            // Jump-cut the video to a random spot when we switch INTO it.
            if (root.bgScene === 2 && bgPlayer.duration > 0) {
                bgPlayer.seek(Math.floor(Math.random() * Math.max(1, bgPlayer.duration - 8000)))
            }
        }
    }

    // Glitch transition that fires on every scene change — bg-only RGB-split
    // tear, sits ABOVE the bg layers but BELOW the skull/EQ/form/logo.
    Item {
        id: sceneCut
        anchors.fill: parent
        z: 1
        opacity: 0

        // Three thin chromatic tear lines, in-theme colors, scattered y
        Repeater {
            model: 3
            Rectangle {
                width: parent.width
                height: 2 + Math.random() * 3
                y: 100 + Math.random() * (parent.height - 200)
                color: index === 0 ? root.accent
                     : index === 1 ? root.accent2
                     : "#ffffff"
                opacity: 0.7
            }
        }
        // Two short black slice-bars (signal dropouts), partial-width
        Repeater {
            model: 2
            Rectangle {
                width: 200 + Math.random() * (parent.width - 600)
                height: 8 + Math.random() * 14
                x: Math.random() * (parent.width - width)
                y: Math.random() * parent.height
                color: "#020103"
            }
        }
    }
    SequentialAnimation {
        id: sceneCutFlash
        NumberAnimation { target: sceneCut; property: "opacity"; to: 0.85; duration: 25 }
        PauseAnimation { duration: 50 }
        NumberAnimation { target: sceneCut; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InCubic }
    }

    // ============================================================
    // BG VIDEO — Watch Dogs 2 menu loop, used as scene 2.
    // Played muted, infinite loop. Only renders when scene 2 is active.
    // ============================================================
    MediaPlayer {
        id: bgPlayer
        source: Qt.resolvedUrl("bg.mp4")
        autoPlay: true
        loops: MediaPlayer.Infinite
        muted: true
        onError: console.log("[bgPlayer] error", error, errorString)
        onStatusChanged: console.log("[bgPlayer] status", status)
        onSourceChanged: console.log("[bgPlayer] source =", source)
    }
    VideoOutput {
        id: bgVideo
        anchors.fill: parent
        source: bgPlayer
        fillMode: VideoOutput.PreserveAspectCrop
        z: 0.5  // above bg gradient/matrix/rings/skyline (all z:0), below halos (z:1)
        opacity: root.bgScene === 2 ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutCubic } }

        // Subtle tint over the video so it feels in-theme (violet wash)
        Rectangle {
            anchors.fill: parent
            color: "#33b48aff"
            opacity: 0.25
        }

        // Periodic glitch jump while video is showing — re-seek to a random
        // point in the clip every 2.6s, gives the "hijacked feed" feel.
        Timer {
            interval: 2600
            repeat: true
            running: bgVideo.opacity > 0.05 && bgPlayer.duration > 0
            onTriggered: {
                if (Math.random() < 0.55) {
                    bgPlayer.seek(Math.floor(Math.random() * Math.max(1, bgPlayer.duration - 8000)))
                    sceneCutFlash.start()
                }
            }
        }
    }

    // ============================================================
    // BITE-MARK / GHOST-LETTER  (spawned on backspace + on wrong-pw)
    // ============================================================
    TextMetrics { id: pwMetrics; font.family: mono; font.pixelSize: 18 }

    Component {
        id: biteMarkComp
        Item {
            id: bm
            // Total bite area: 56w × 80h, letter center is at (28, 40)
            width: 56; height: 80
            opacity: 1.0

            // TOP fang half — descends from above onto the letter
            Image {
                id: bmTop
                source: "fangs_top.png"
                width: 56
                height: 56
                fillMode: Image.PreserveAspectFit
                smooth: true
                x: 0
                y: -28      // start clearly above
            }
            // BOTTOM fang half — rises from below onto the letter
            Image {
                id: bmBot
                source: "fangs_bottom.png"
                width: 56
                height: 56
                fillMode: Image.PreserveAspectFit
                smooth: true
                x: 0
                y: 52       // start clearly below
            }

            SequentialAnimation {
                running: true
                // CHOMP — fangs slam together over the letter
                ParallelAnimation {
                    NumberAnimation { target: bmTop; property: "y"; to: 0;  duration: 90; easing.type: Easing.InCubic }
                    NumberAnimation { target: bmBot; property: "y"; to: 24; duration: 90; easing.type: Easing.InCubic }
                }
                // brief tiny shake on impact
                ParallelAnimation {
                    NumberAnimation { target: bmTop; property: "y"; to: 2;  duration: 35 }
                    NumberAnimation { target: bmBot; property: "y"; to: 22; duration: 35 }
                }
                ParallelAnimation {
                    NumberAnimation { target: bmTop; property: "y"; to: 0;  duration: 35 }
                    NumberAnimation { target: bmBot; property: "y"; to: 24; duration: 35 }
                }
                PauseAnimation { duration: 90 }
                // RETRACT — fangs pull back and fade
                ParallelAnimation {
                    NumberAnimation { target: bmTop; property: "y"; to: -34; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bmBot; property: "y"; to:  60; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bm;    property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
                }
                ScriptAction { script: bm.destroy() }
            }
        }
    }

    Component {
        id: ghostLetterComp
        Text {
            id: gl
            property string ch: ""
            text: ch
            color: "#ece4ff"
            font.family: root.mono
            font.pixelSize: 18
            opacity: 0
            SequentialAnimation {
                running: true
                NumberAnimation { target: gl; property: "opacity"; to: 1.0; duration: 30 }
                PauseAnimation { duration: 120 }
                NumberAnimation { target: gl; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
                ScriptAction { script: gl.destroy() }
            }
        }
    }

    function spawnBiteAt(parentItem, px, py, ch) {
        // bite mark is 56x80, letter center anchors at (28, 40)
        biteMarkComp.createObject(parentItem, { x: px - 28, y: py - 40 })
        if (ch && ch.length > 0)
            ghostLetterComp.createObject(parentItem, { x: px - 6, y: py - 9, ch: ch })
    }

    // ============================================================
    // BACKGROUND LAYERS
    // gradient base, matrix rain, drifting halos, scanlines, vignette
    // ============================================================
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#08051a" }
            GradientStop { position: 0.55; color: "#020103" }
            GradientStop { position: 1.0; color: "#06010a" }
        }
    }

    Canvas {
        id: matrix
        anchors.fill: parent
        opacity: root.bgScene === 0 ? 0.65 : 0
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutCubic } }
        z: 0
        renderStrategy: Canvas.Threaded
        renderTarget: Canvas.FramebufferObject

        property int  cell: 18
        property int  cols: Math.ceil(width / cell)
        property var  drops: []
        property string charset: "ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍｦｲｸｺｿﾁﾄﾉﾌﾔﾖﾙﾚﾛﾝ0123456789#$%&@*?!ΣΨΞΩ"

        function reseed() {
            cols = Math.ceil(width / cell)
            drops = new Array(cols)
            for (var i = 0; i < cols; ++i)
                drops[i] = Math.floor(Math.random() * (height / cell))
        }
        onWidthChanged:  reseed()
        onHeightChanged: reseed()
        Component.onCompleted: reseed()

        onPaint: {
            var ctx = getContext("2d")
            ctx.fillStyle = "rgba(2, 1, 3, 0.16)"
            ctx.fillRect(0, 0, width, height)
            ctx.font = "bold " + (cell - 2) + "px " + root.mono

            for (var i = 0; i < drops.length; ++i) {
                var ch = matrix.charset.charAt(Math.floor(Math.random() * matrix.charset.length))
                var x = i * cell
                var y = drops[i] * cell
                ctx.fillStyle = "rgba(180, 138, 255, 0.95)"
                ctx.fillText(ch, x, y)
                ctx.fillStyle = "rgba(51, 255, 255, 0.55)"
                ctx.fillText(ch, x, y - cell)

                if (y > height && Math.random() > 0.975) drops[i] = 0
                drops[i] += 1
            }
        }

        Timer {
            interval: 60
            repeat: true
            running: root.mode !== "success" && root.bgScene === 0
            onTriggered: matrix.requestPaint()
        }
    }

    // ============================================================
    // SCENE 1 — GEOMETRIC RINGS  (concentric polygons, radial spokes)
    // L-A-S-E-R style line-art rotating around screen center.
    // ============================================================
    Canvas {
        id: ringsCanvas
        anchors.fill: parent
        z: 0
        opacity: root.bgScene === 1 ? 0.75 : 0
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutCubic } }
        property real spin: 0
        NumberAnimation on spin {
            running: ringsCanvas.opacity > 0.01
            loops: Animation.Infinite
            from: 0; to: Math.PI * 2; duration: 22000
        }
        onSpinChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            var cx = width / 2, cy = height / 2
            // Concentric polygons (n-gons) of growing size
            for (var r = 0; r < 7; ++r) {
                var sides  = 6 + r           // 6,7,8,...
                var radius = 90 + r * 75
                var rot    = spin * (r % 2 === 0 ? 1 : -1) * (1 + r * 0.07)
                var alpha  = 0.45 - r * 0.05
                ctx.strokeStyle = r % 2 === 0
                    ? Qt.rgba(0.71, 0.54, 1.0, alpha).toString()
                    : Qt.rgba(0.20, 1.0, 1.0, alpha).toString()
                ctx.lineWidth = r === 0 ? 1.6 : 1
                ctx.beginPath()
                for (var i = 0; i <= sides; ++i) {
                    var a = rot + i * (Math.PI * 2) / sides
                    var x = cx + Math.cos(a) * radius
                    var y = cy + Math.sin(a) * radius
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }
            // Radial spokes (clock-tick marks at outer ring)
            ctx.strokeStyle = Qt.rgba(0.71, 0.54, 1.0, 0.55).toString()
            ctx.lineWidth = 1
            for (var s = 0; s < 24; ++s) {
                var ang = spin * 0.4 + s * (Math.PI * 2) / 24
                var inner = 580
                var outer = 580 + (s % 3 === 0 ? 28 : 12)
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(ang) * inner, cy + Math.sin(ang) * inner)
                ctx.lineTo(cx + Math.cos(ang) * outer, cy + Math.sin(ang) * outer)
                ctx.stroke()
            }
            // Center crosshair pulse
            ctx.strokeStyle = Qt.rgba(0.20, 1.0, 1.0, 0.7).toString()
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(cx - 30, cy); ctx.lineTo(cx + 30, cy); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, cy - 30); ctx.lineTo(cx, cy + 30); ctx.stroke()
        }
    }

    // ============================================================
    // SCENE 2 — SIGNAL SKYLINE  (vertical bars rising from bottom,
    // city-silhouette feel, à la WD2 menu)
    // ============================================================
    Item {
        id: skyline
        anchors.fill: parent
        z: 0
        visible: false
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutCubic } }

        Repeater {
            model: 64
            Rectangle {
                width: root.width / 64 - 2
                height: 60 + Math.random() * 360
                x: index * (root.width / 64) + 1
                anchors.bottom: statusbar.top
                anchors.bottomMargin: 0
                color: index % 7 === 0 ? root.danger
                     : index % 2 === 0 ? root.accent
                     : root.accent2
                opacity: 0.18 + Math.random() * 0.25
                SequentialAnimation on height {
                    loops: Animation.Infinite
                    PauseAnimation { duration: (index * 53) % 900 }
                    NumberAnimation { from: 60 + (index * 17) % 220
                                      to: 200 + (index * 23) % 480
                                      duration: 1200 + (index * 41) % 1400
                                      easing.type: Easing.InOutSine }
                    NumberAnimation { from: 200 + (index * 23) % 480
                                      to: 80 + (index * 11) % 160
                                      duration: 1100 + (index * 37) % 1300
                                      easing.type: Easing.InOutSine }
                }
            }
        }

        // Drifting horizontal "data stream" lines
        Repeater {
            model: 5
            Rectangle {
                width: root.width
                height: 1
                color: index % 2 ? root.accent2 : root.accent
                opacity: 0.25
                y: (index + 1) * (root.height / 6)
                Rectangle {
                    width: 220
                    height: parent.height
                    x: 0
                    color: parent.color
                    opacity: 0.9
                    NumberAnimation on x {
                        loops: Animation.Infinite
                        from: -240
                        to: root.width + 240
                        duration: 4500 + index * 900
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    // drifting accent halos
    Item {
        anchors.fill: parent
        opacity: 0.55
        z: 1

        Rectangle {
            width: 900; height: 900; radius: 450
            color: "#33b48aff"
            x: root.width * 0.15; y: root.height * 0.55
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { from: root.width * 0.10; to: root.width * 0.25; duration: 9000; easing.type: Easing.InOutSine }
                NumberAnimation { from: root.width * 0.25; to: root.width * 0.10; duration: 9000; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            width: 900; height: 900; radius: 450
            color: "#2233ffff"
            x: root.width * 0.65; y: root.height * 0.10
            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation { from: root.height * 0.05; to: root.height * 0.20; duration: 11000; easing.type: Easing.InOutSine }
                NumberAnimation { from: root.height * 0.20; to: root.height * 0.05; duration: 11000; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            width: 700; height: 700; radius: 350
            color: "#22ff2d55"
            x: root.width * 0.40; y: root.height * 0.70
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.5; to: 0.9; duration: 4200; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.9; to: 0.5; duration: 4200; easing.type: Easing.InOutSine }
            }
        }
    }

    // CRT scanlines — repeated horizontal lines
    Item {
        anchors.fill: parent
        z: 2
        opacity: 0.12
        Repeater {
            model: Math.ceil(root.height / 3)
            Rectangle {
                width: root.width
                height: 1
                y: index * 3
                color: "#000000"
            }
        }
    }

    // vignette
    Rectangle {
        anchors.fill: parent
        z: 3
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 0.7; color: "#88000000" }
            GradientStop { position: 1.0; color: "#dd000000" }
        }
    }

    // ============================================================
    // EXTRA BACKGROUND FX
    // wireframe grid, diagonal sweep, glitch tear, floating hex
    // ============================================================

    // Pulsing wireframe grid (drawn under matrix's drips so columns punch through it)
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        z: 0
        opacity: 0.18
        property real pulse: 0.5
        SequentialAnimation on pulse {
            loops: Animation.Infinite
            NumberAnimation { from: 0.3; to: 0.9; duration: 3200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.9; to: 0.3; duration: 3200; easing.type: Easing.InOutSine }
        }
        onPulseChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = Qt.rgba(0.71, 0.54, 1.0, 0.35 * pulse)
            ctx.lineWidth = 1
            var step = 64
            for (var x = 0; x < width; x += step) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
            }
            for (var y = 0; y < height; y += step) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
            // accent crosshair
            ctx.strokeStyle = Qt.rgba(0.2, 1.0, 1.0, 0.55 * pulse)
            ctx.beginPath(); ctx.moveTo(width/2, 0); ctx.lineTo(width/2, height); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(0, height/2); ctx.lineTo(width, height/2); ctx.stroke()
        }
    }

    // Slow diagonal sweep light
    Item {
        anchors.fill: parent
        z: 2
        opacity: 0.22
        clip: true
        Rectangle {
            id: sweep
            width: 360
            height: root.height * 1.6
            rotation: 22
            transformOrigin: Item.Center
            x: -width
            y: -root.height * 0.2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00b48aff" }
                GradientStop { position: 0.5; color: "#ccb48aff" }
                GradientStop { position: 1.0; color: "#00b48aff" }
            }
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { from: -360; to: root.width + 360; duration: 7200; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 1800 }
            }
        }
    }

    // Random horizontal glitch tear band
    Rectangle {
        id: tear
        width: parent.width
        height: 4 + Math.random() * 12
        x: 0
        y: 0
        color: root.accent2
        opacity: 0
        z: 4
        Timer {
            interval: 2200 + Math.random() * 3500
            repeat: true
            running: true
            onTriggered: {
                tear.height = 3 + Math.random() * 18
                tear.y = Math.random() * root.height
                tear.color = Math.random() < 0.5 ? root.accent : root.accent2
                tearAnim.start()
            }
        }
        SequentialAnimation {
            id: tearAnim
            NumberAnimation { target: tear; property: "opacity"; to: 0.55; duration: 50 }
            PauseAnimation { duration: 70 }
            NumberAnimation { target: tear; property: "opacity"; to: 0; duration: 90 }
        }
    }

    // (floating hex fragments removed — felt like generic AI filler)

    // ============================================================
    // DEDSEC VISUAL LAYER
    // viewfinder brackets, REC beacon, stencil mask, spray-tags.
    // No per-frame Canvas redraws — everything uses property animations
    // so the FPS impact is negligible.
    // ============================================================
    Item {
        id: dedsecFx
        anchors.fill: parent
        z: 2
        opacity: (root.mode === "splash" || root.mode === "success") ? 0.0 : 0.85
        Behavior on opacity { NumberAnimation { duration: 600 } }

        // Viewfinder brackets in 4 corners (CCTV targeting frame)
        Repeater {
            model: 4
            Item {
                property int corner: index   // 0=TL 1=TR 2=BL 3=BR
                property int margPx: 56
                property int armLen: 70
                property int armThk: 3
                width: armLen; height: armLen
                x: (corner === 1 || corner === 3) ? root.width - margPx - armLen : margPx
                y: (corner === 2 || corner === 3) ? root.height - margPx - armLen : margPx

                Rectangle {
                    width: parent.armLen; height: parent.armThk
                    color: root.accent
                    x: 0
                    y: (parent.corner < 2) ? 0 : parent.armLen - parent.armThk
                }
                Rectangle {
                    width: parent.armThk; height: parent.armLen
                    color: root.accent
                    x: (parent.corner === 0 || parent.corner === 2) ? 0 : parent.armLen - parent.armThk
                    y: 0
                }

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.45; to: 1.0; duration: 1400 + index * 180; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.45; duration: 1400 + index * 180; easing.type: Easing.InOutSine }
                }
            }
        }

        // (REC label removed — pure red dot below is enough signal)
        Rectangle {
            x: root.width - 78
            y: 38
            width: 10; height: 10; radius: 5
            color: root.danger
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.25; to: 1.0; duration: 600 }
                NumberAnimation { from: 1.0; to: 0.25; duration: 600 }
            }
        }

        // ========================================================
        // DEDSEC SKULL — bottom-left, glitching with chromatic aberration.
        // Three skull canvases stacked: main white + cyan ghost + magenta ghost.
        // Each ghost twitches independently. Slice-tear bars hide parts of the
        // skull at random for the corrupted-feed look.
        // ========================================================

        // ========================================================
        // BOTTOM-LEFT SKULL — animated halftone GIF with chromatic-aberration
        // ghost duplicates and slice-tear glitch bars.
        // ========================================================
        Item {
            id: skullRig
            width: 320
            height: 240
            x: 30
            y: root.height - 56 - 240
            opacity: 0.92

            AnimatedImage {
                id: skullCyan
                source: "skull.gif"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                playing: true
                opacity: 0.55
                transform: Translate { id: skullCyanT; x: -4; y: 0 }
                layer.enabled: true
                layer.effect: ShaderEffect {
                    fragmentShader: "
                        uniform sampler2D source;
                        uniform lowp float qt_Opacity;
                        varying highp vec2 qt_TexCoord0;
                        void main() {
                            lowp vec4 c = texture2D(source, qt_TexCoord0);
                            gl_FragColor = vec4(c.r * 0.20, c.r * 1.0, c.r * 1.0, c.a) * qt_Opacity;
                        }"
                }
            }

            AnimatedImage {
                id: skullMagenta
                source: "skull.gif"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                playing: true
                opacity: 0.55
                transform: Translate { id: skullMagentaT; x: 4; y: 0 }
                layer.enabled: true
                layer.effect: ShaderEffect {
                    fragmentShader: "
                        uniform sampler2D source;
                        uniform lowp float qt_Opacity;
                        varying highp vec2 qt_TexCoord0;
                        void main() {
                            lowp vec4 c = texture2D(source, qt_TexCoord0);
                            gl_FragColor = vec4(c.r * 1.0, c.r * 0.18, c.r * 0.55, c.a) * qt_Opacity;
                        }"
                }
            }

            AnimatedImage {
                id: skullMain
                source: "skull.gif"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                playing: true
                transform: Translate { id: skullMainT; x: 0; y: 0 }
            }

            Timer {
                interval: 90; repeat: true; running: true
                onTriggered: {
                    if (Math.random() < 0.20) {
                        skullCyanT.x    = -4 + (Math.random() - 0.5) * 14
                        skullMagentaT.x =  4 + (Math.random() - 0.5) * 14
                        skullMainT.x    = (Math.random() - 0.5) * 3
                    } else {
                        skullCyanT.x    = -4
                        skullMagentaT.x =  4
                        skullMainT.x    = 0
                    }
                }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.92; to: 1.0; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.0; to: 0.55; duration: 80 }
                NumberAnimation { from: 0.55; to: 0.95; duration: 60 }
                NumberAnimation { from: 0.95; to: 0.92; duration: 1300; easing.type: Easing.InOutSine }
            }

            Repeater {
                model: 3
                Rectangle {
                    width: skullRig.width
                    height: 6 + Math.random() * 12
                    color: "#020103"
                    x: 0
                    y: 0
                    opacity: 0
                    Timer {
                        interval: 1900 + index * 1400 + Math.random() * 2300
                        repeat: true
                        running: true
                        onTriggered: {
                            parent.y = Math.random() * (skullRig.height - 18)
                            parent.height = 4 + Math.random() * 14
                            sliceFlash.start()
                        }
                    }
                    SequentialAnimation {
                        id: sliceFlash
                        NumberAnimation { target: parent; property: "opacity"; to: 0.85; duration: 35 }
                        PauseAnimation { duration: 70 }
                        NumberAnimation { target: parent; property: "opacity"; to: 0; duration: 60 }
                    }
                }
            }
        }

        // ========================================================
        // RIGHT-EDGE PC STATS PANEL — live system telemetry. Reads
        // /proc and /sys via XMLHttpRequest(file://). No external
        // process calls (SDDM-safe). Glitch-styled to match the rest.
        // ========================================================
        Item {
            id: stats
            width: 320
            height: 500
            x: root.width - width - 36
            y: root.height * 0.18
            opacity: 0.92
            z: 4

            transform: [ Translate { id: statsJit; x: 0; y: 0 } ]
            Timer {
                interval: 1700 + Math.random() * 1400
                running: true
                repeat: true
                onTriggered: {
                    statsJit.x = (Math.random() - 0.5) * 4
                    statsJit.y = (Math.random() - 0.5) * 2
                    statsResetT.start()
                    interval = 1300 + Math.random() * 1900
                }
            }
            Timer { id: statsResetT; interval: 90; onTriggered: { statsJit.x = 0; statsJit.y = 0 } }

            Rectangle {
                anchors.fill: parent
                color: "#08040f"
                opacity: 0.78
                border.width: 1
                border.color: "#2a1f3a"
                radius: 4
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.7, 0.54, 1.0, 0.25)
                radius: 6
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top
                height: 2
                color: root.accent
                opacity: 0.85
            }
            Repeater {
                model: 60
                Rectangle {
                    x: 1; y: index * 6 + 2
                    width: parent.width - 2; height: 1
                    color: "#ffffff"
                    opacity: 0.025
                }
            }

            property real cpuPct: 0
            property real memPct: 0
            property real memUsedGb: 0
            property real memTotalGb: 0
            property string load1: "-.--"
            property string upStr: "--:--:--"
            property string hostStr: "bite-os"
            property string kernStr: "linux"
            property real batPct: -1
            property string batState: ""
            property real lastIdle: 0
            property real lastTotal: 0
            property string timeStr: ""
            property string dateStr: ""

            function readFile(path, cb) {
                var x = new XMLHttpRequest()
                x.open("GET", "file://" + path)
                x.onreadystatechange = function() {
                    if (x.readyState === XMLHttpRequest.DONE) cb(x.responseText || "")
                }
                try { x.send() } catch (e) { cb("") }
            }

            function refresh() {
                readFile("/proc/stat", function(t) {
                    var line = t.split("\n")[0]
                    if (!line) return
                    var p = line.replace(/^cpu\s+/, "").split(/\s+/).map(Number)
                    if (p.length < 5) return
                    var idle = p[3] + (p[4] || 0)
                    var total = 0
                    for (var i = 0; i < p.length; i++) total += p[i]
                    var dIdle  = idle  - stats.lastIdle
                    var dTotal = total - stats.lastTotal
                    if (stats.lastTotal > 0 && dTotal > 0) {
                        stats.cpuPct = Math.max(0, Math.min(100, (1 - dIdle / dTotal) * 100))
                    }
                    stats.lastIdle = idle
                    stats.lastTotal = total
                })
                readFile("/proc/meminfo", function(t) {
                    var m = {}
                    t.split("\n").forEach(function(l) {
                        var mm = l.match(/^(\w+):\s+(\d+)/)
                        if (mm) m[mm[1]] = Number(mm[2])
                    })
                    if (m.MemTotal && m.MemAvailable) {
                        var used = m.MemTotal - m.MemAvailable
                        stats.memPct = (used / m.MemTotal) * 100
                        stats.memUsedGb  = used / 1024 / 1024
                        stats.memTotalGb = m.MemTotal / 1024 / 1024
                    }
                })
                readFile("/proc/loadavg", function(t) {
                    var p = t.split(/\s+/)
                    if (p[0]) stats.load1 = p[0]
                })
                readFile("/proc/uptime", function(t) {
                    var s = Math.floor(Number(t.split(/\s+/)[0] || 0))
                    var h = Math.floor(s / 3600)
                    var m = Math.floor((s % 3600) / 60)
                    var ss = s % 60
                    stats.upStr = (h<10?"0":"")+h+":"+(m<10?"0":"")+m+":"+(ss<10?"0":"")+ss
                })
                readFile("/sys/class/power_supply/BAT0/capacity", function(t) {
                    var v = parseInt(t)
                    if (!isNaN(v)) stats.batPct = v
                })
                readFile("/sys/class/power_supply/BAT0/status", function(t) {
                    if (t) stats.batState = t.trim()
                })
            }

            Component.onCompleted: {
                readFile("/etc/hostname", function(t) { if (t) stats.hostStr = t.trim() })
                readFile("/proc/sys/kernel/osrelease", function(t) {
                    if (t) stats.kernStr = t.trim().replace(/-cachyos.*/, "")
                })
                refresh()
            }
            Timer { interval: 1000; running: true; repeat: true; onTriggered: stats.refresh() }
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    var d = new Date()
                    stats.timeStr = Qt.formatDateTime(d, "HH:mm:ss")
                    stats.dateStr = Qt.formatDateTime(d, "ddd · dd MMM yyyy").toUpperCase()
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // ── BIG CLOCK + DATE ─────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 2
                    Text {
                        anchors.right: parent.right
                        text: stats.timeStr
                        color: root.accent
                        font.family: root.mono
                        font.pixelSize: 38
                        font.bold: true
                    }
                    Text {
                        anchors.right: parent.right
                        text: stats.dateStr
                        color: "#b9a8e8"
                        font.family: root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#2a1f3a"; opacity: 0.7 }

                Row {
                    spacing: 8
                    Rectangle {
                        width: 8; height: 8; radius: 4; color: root.accent
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.25; duration: 700 }
                            NumberAnimation { from: 0.25; to: 1.0; duration: 700 }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "▸ SYS_TELEMETRY"
                        color: root.accent2
                        font.family: root.mono
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
                Text {
                    text: "// host ▸ " + stats.hostStr + "  k:" + stats.kernStr
                    color: "#7a6aaa"
                    font.family: root.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: parent.width
                }

                Rectangle { width: parent.width; height: 1; color: "#2a1f3a"; opacity: 0.7 }

                Column {
                    width: parent.width
                    spacing: 3
                    Row {
                        width: parent.width
                        Text { text: "CPU"; color: root.accent; font.family: root.mono; font.pixelSize: 11; font.bold: true; width: 40 }
                        Text {
                            text: stats.cpuPct.toFixed(1) + "%"
                            color: stats.cpuPct > 85 ? root.danger : "#dcd0ff"
                            font.family: root.mono; font.pixelSize: 11
                            width: parent.width - 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 6
                        color: "#15102a"; radius: 1
                        Rectangle {
                            width: parent.width * Math.min(1, stats.cpuPct / 100)
                            height: parent.height
                            color: stats.cpuPct > 85 ? root.danger : root.accent
                            radius: 1
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 3
                    Row {
                        width: parent.width
                        Text { text: "MEM"; color: root.accent; font.family: root.mono; font.pixelSize: 11; font.bold: true; width: 40 }
                        Text {
                            text: stats.memUsedGb.toFixed(1) + " / " + stats.memTotalGb.toFixed(1) + "G"
                            color: stats.memPct > 85 ? root.danger : "#dcd0ff"
                            font.family: root.mono; font.pixelSize: 11
                            width: parent.width - 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 6
                        color: "#15102a"; radius: 1
                        Rectangle {
                            width: parent.width * Math.min(1, stats.memPct / 100)
                            height: parent.height
                            color: stats.memPct > 85 ? root.danger : root.accent2
                            radius: 1
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 3
                    visible: stats.batPct >= 0
                    Row {
                        width: parent.width
                        Text { text: "BAT"; color: root.accent; font.family: root.mono; font.pixelSize: 11; font.bold: true; width: 40 }
                        Text {
                            text: stats.batPct + "%  " + (stats.batState === "Charging" ? "(+)" :
                                                          stats.batState === "Discharging" ? "(-)" : "")
                            color: stats.batPct < 15 && stats.batState !== "Charging" ? root.danger : "#dcd0ff"
                            font.family: root.mono; font.pixelSize: 11
                            width: parent.width - 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 6
                        color: "#15102a"; radius: 1
                        Rectangle {
                            width: parent.width * Math.min(1, stats.batPct / 100)
                            height: parent.height
                            color: stats.batPct < 15 && stats.batState !== "Charging" ? root.danger
                                 : stats.batState === "Charging" ? root.accent2
                                 : root.accent
                            radius: 1
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#2a1f3a"; opacity: 0.7 }

                Row {
                    width: parent.width
                    Text { text: "LOAD"; color: root.accent; font.family: root.mono; font.pixelSize: 11; font.bold: true; width: 60 }
                    Text { text: stats.load1; color: "#dcd0ff"; font.family: root.mono; font.pixelSize: 11
                        width: parent.width - 60; horizontalAlignment: Text.AlignRight }
                }
                Row {
                    width: parent.width
                    Text { text: "UPTIME"; color: root.accent; font.family: root.mono; font.pixelSize: 11; font.bold: true; width: 60 }
                    Text { text: stats.upStr; color: "#dcd0ff"; font.family: root.mono; font.pixelSize: 11
                        width: parent.width - 60; horizontalAlignment: Text.AlignRight }
                }

                Rectangle { width: parent.width; height: 1; color: "#2a1f3a"; opacity: 0.7 }

                // ── CAVA-STYLE VISUALIZER ────────────────────────────
                Item {
                    width: parent.width
                    height: 64
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 2
                        Repeater {
                            model: 32
                            Rectangle {
                                width: (stats.width - 28 - 31 * 2) / 32
                                color: index % 9 === 0 ? root.danger
                                     : index % 2 === 0 ? root.accent
                                     : root.accent2
                                opacity: 0.85
                                radius: 1
                                anchors.bottom: parent.bottom
                                SequentialAnimation on height {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 4 + (index * 7) % 14
                                                      to:   24 + (index * 11) % 38
                                                      duration: 320 + (index * 47) % 380
                                                      easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 24 + (index * 11) % 38
                                                      to:   6 + (index * 5) % 12
                                                      duration: 300 + (index * 43) % 360
                                                      easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: stats.cpuPct > 85 ? "// state ▸ HOT"
                        : stats.cpuPct > 50 ? "// state ▸ ACTIVE"
                                            : "// state ▸ IDLE"
                    color: stats.cpuPct > 85 ? root.danger
                         : stats.cpuPct > 50 ? root.accent2
                                             : "#5a4a8a"
                    font.family: root.mono
                    font.pixelSize: 10
                }
            }

            Rectangle {
                id: statsFlick
                anchors.fill: parent
                color: root.accent2
                opacity: 0
                radius: 4
                Timer {
                    interval: 4200 + Math.random() * 5000
                    running: true; repeat: true
                    onTriggered: { flickAnim.start(); interval = 4200 + Math.random() * 5000 }
                }
                SequentialAnimation {
                    id: flickAnim
                    NumberAnimation { target: statsFlick; property: "opacity"; to: 0.10; duration: 40 }
                    NumberAnimation { target: statsFlick; property: "opacity"; to: 0;    duration: 80 }
                }
            }
        }

    }

    // ============================================================
    // SPLASH LOGO + LOGIN FORM
    // ============================================================
    Item {
        id: content
        anchors.fill: parent
        opacity: (root.mode === "locked" || root.mode === "success") ? 0.18 : 1.0
        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        z: 5

        Image {
            id: logo
            source: "logo.png"
            anchors.horizontalCenter: parent.horizontalCenter
            sourceSize.height: 280
            fillMode: Image.PreserveAspectFit
            smooth: true

            property real splashTop: parent.height * 0.36
            property real idleTop:   parent.height * 0.07
            y: splashTop
            scale: 1.6
            opacity: 0

            ParallelAnimation {
                id: splashIntro
                running: true
                NumberAnimation { target: logo; property: "opacity"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 1700 }
                    ParallelAnimation {
                        NumberAnimation { target: logo; property: "scale"; from: 1.6; to: 1.0; duration: 900; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: logo; property: "y"; from: logo.splashTop; to: logo.idleTop; duration: 900; easing.type: Easing.InOutCubic }
                    }
                }
                onStopped: {
                    if (root.mode === "splash") root.mode = "idle"
                    pwField.forceActiveFocus()
                }
            }

            SequentialAnimation on scale {
                running: root.mode === "idle"
                loops: Animation.Infinite
                NumberAnimation { from: 1.00; to: 1.02; duration: 2400; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.02; to: 1.00; duration: 2400; easing.type: Easing.InOutSine }
            }

            // glitch flicker — random small x offset
            transform: Translate { id: logoGlitch; x: 0 }
            Timer {
                interval: 1700 + Math.random() * 1500
                repeat: true
                running: root.mode === "idle"
                onTriggered: {
                    logoGlitch.x = (Math.random() < 0.5 ? -1 : 1) * (2 + Math.random() * 4)
                    logoSnap.start()
                }
            }
            NumberAnimation {
                id: logoSnap
                target: logoGlitch
                property: "x"
                to: 0
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: 24
            text: "// initializing bite-os ▰ dedsec protocol"
            color: root.accent2
            font.family: root.mono
            font.pixelSize: 16
            font.bold: true
            opacity: root.mode === "splash" ? 0.85 : 0
            Behavior on opacity { NumberAnimation { duration: 500 } }
        }

        // login form
        Item {
            id: form
            width: 560
            height: 240
            anchors.centerIn: parent
            opacity: root.mode === "splash" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

            transform: Translate { id: shake; x: 0 }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shake; property: "x"; to: -16; duration: 50 }
                NumberAnimation { target: shake; property: "x"; to:  16; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to:  -9; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to:   9; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to:   0; duration: 50 }
            }

            // ===== TARGETING RETICLE — 4 L-brackets that breathe + lock-on =====
            Item {
                id: reticle
                anchors.fill: parent
                property real ringMargin: pwField.activeFocus ? -10 : -22
                Behavior on ringMargin { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                anchors.margins: ringMargin

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.55; to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.55; duration: 1100; easing.type: Easing.InOutSine }
                }

                Repeater {
                    model: 4
                    Item {
                        property int corner: index   // 0=TL 1=TR 2=BL 3=BR
                        property int armLen: 28
                        property int armThk: 2
                        width: armLen; height: armLen
                        x: (corner === 1 || corner === 3) ? reticle.width  - armLen : 0
                        y: (corner === 2 || corner === 3) ? reticle.height - armLen : 0
                        Rectangle {
                            width: parent.armLen; height: parent.armThk
                            color: pwField.activeFocus ? root.accent2 : root.accent
                            x: 0
                            y: (parent.corner < 2) ? 0 : parent.armLen - parent.armThk
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                        Rectangle {
                            width: parent.armThk; height: parent.armLen
                            color: pwField.activeFocus ? root.accent2 : root.accent
                            x: (parent.corner === 0 || parent.corner === 2) ? 0 : parent.armLen - parent.armThk
                            y: 0
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                    }
                }

                // tiny diamond pip on the side mid-points — lock indicators
                Repeater {
                    model: 4
                    Rectangle {
                        property int side: index       // 0=top 1=right 2=bottom 3=left
                        width: 6; height: 6
                        rotation: 45
                        color: root.accent2
                        x: side === 0 ? reticle.width / 2 - 3
                         : side === 1 ? reticle.width - 3
                         : side === 2 ? reticle.width / 2 - 3
                         : -3
                        y: side === 0 ? -3
                         : side === 1 ? reticle.height / 2 - 3
                         : side === 2 ? reticle.height - 3
                         : reticle.height / 2 - 3
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            PauseAnimation { duration: side * 180 }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 520 }
                            NumberAnimation { from: 1.0; to: 0.2; duration: 520 }
                        }
                    }
                }
            }

            // ===== SCAN BEAM — thin horizontal line sweeping the form =====
            Rectangle {
                id: scanBeam
                width: parent.width + 60
                height: 2
                x: -30
                color: root.accent2
                opacity: 0.55
                z: 10
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    NumberAnimation { from: -8; to: form.height + 8; duration: 2400; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 1400 }
                }
                // soft glow underline
                Rectangle {
                    anchors.top: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#5533ffff" }
                        GradientStop { position: 1.0; color: "#0033ffff" }
                    }
                }
            }

            Rectangle {
                id: panel
                anchors.fill: parent
                color: "#0a0612"
                opacity: 0.92
                radius: 10
                border.width: 1
                border.color: pwField.activeFocus ? root.accent : "#2a1f3a"
                Behavior on border.color { ColorAnimation { duration: 220 } }
            }

            // animated outer glow border
            Rectangle {
                id: panelGlow
                anchors.fill: parent
                anchors.margins: -3
                color: "transparent"
                radius: 12
                border.width: 1
                border.color: root.accent
                opacity: 0
                SequentialAnimation on opacity {
                    running: pwField.activeFocus
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.15; to: 0.55; duration: 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.55; to: 0.15; duration: 1300; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 32
                color: "#15102a"
                radius: 10

                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 10; color: parent.color
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▸ /dev/jaws ▸ auth-shell ▸ 0x4F"
                    color: root.accent2
                    font.family: root.mono
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.5
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: ["#5a3aaa", "#b48aff", "#33ffff"]
                        Rectangle { width: 9; height: 9; radius: 4.5; color: modelData }
                    }
                }
            }

            Column {
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24
                spacing: 20

                Row {
                    spacing: 14
                    Text {
                        text: "01"
                        color: "#3d2f5f"
                        font.family: root.mono
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "user ▸"
                        color: "#7a6aaa"
                        font.family: root.mono
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: userModel.lastUser ? userModel.lastUser : "user"
                        color: root.accent
                        font.family: root.mono
                        font.pixelSize: 18
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3
                        color: root.accent2
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.3; to: 1.0; duration: 700 }
                            NumberAnimation { from: 1.0; to: 0.3; duration: 700 }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 32

                    Text {
                        id: lineNum2
                        text: "02"
                        color: "#3d2f5f"
                        font.family: root.mono
                        font.pixelSize: 13
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: passLabel
                        text: "pass ▸"
                        color: "#7a6aaa"
                        font.family: root.mono
                        font.pixelSize: 15
                        anchors.left: lineNum2.right
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        id: pwBox
                        anchors.left: passLabel.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        color: "#100822"
                        radius: 4
                        border.width: 1
                        property real pulse: 0
                        border.color: pulse > 0
                            ? Qt.rgba(0.2 + pulse*0.8, 1.0, 1.0, 1.0)
                            : (pwField.activeFocus ? "#33b48aff" : "#2a1f3a")
                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        NumberAnimation on pulse {
                            id: pulseAnim
                            running: false
                            from: 1; to: 0; duration: 280; easing.type: Easing.OutCubic
                        }

                        Item { id: biteLayer; anchors.fill: parent; z: 6 }

                        TextInput {
                            id: pwField
                            property int prevLen: 0
                            property string prevText: ""
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 50
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: "transparent"
                            selectionColor: "#33ffff55"
                            selectedTextColor: "transparent"
                            font.family: root.mono
                            font.pixelSize: 18
                            echoMode: TextInput.Normal
                            focus: true
                            cursorVisible: true
                            enabled: root.mode === "idle" || root.mode === "chomp"
                            opacity: enabled ? 1.0 : 0.4
                            cursorDelegate: Rectangle {
                                width: 10; height: pwField.font.pixelSize + 4
                                color: root.accent2
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.2; duration: 520 }
                                    NumberAnimation { from: 0.2; to: 1.0; duration: 520 }
                                }
                            }
                            Keys.onReturnPressed: doLogin()
                            Keys.onEnterPressed:  doLogin()
                            Keys.onEscapePressed: pwField.text = ""

                            onTextChanged: {
                                pulseAnim.stop(); pulseAnim.start()
                                pwDisplay.regenerate()

                                // Backspace bite — letter just got eaten by a tooth
                                if (text.length < prevLen && root.mode !== "locked") {
                                    var deletedAt = text.length            // index where char was removed
                                    var ch = prevText.charAt(deletedAt) || "·"
                                    pwMetrics.text = "X".repeat(deletedAt)
                                    var advance = deletedAt === 0 ? 0 : pwMetrics.advanceWidth
                                    var lx = 10 + advance
                                    var ly = pwBox.height / 2
                                    spawnBiteAt(biteLayer, lx, ly, ch)
                                    if (root.revealedCount > text.length)
                                        root.revealedCount = text.length
                                }
                                prevLen  = text.length
                                prevText = text
                            }
                        }

                        Text {
                            id: pwDisplay
                            anchors.fill: pwField
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            font: pwField.font
                            color: "#ece4ff"
                            text: ""
                            clip: true

                            property string scrambleSet: "0123456789ABCDEF#$%&@*?!ΣΨΞΩ▓▒░αβγδλμπφψωΞΨΩ◆◇◈"

                            function regenerate() {
                                var n = pwField.text.length;
                                if (n === 0) { text = ""; return; }
                                var s = "";
                                var revealed = root.revealedCount;
                                for (var i = 0; i < n; i++) {
                                    if (root.revealMode && i < revealed) {
                                        s += pwField.text[i];
                                    } else {
                                        s += scrambleSet[Math.floor(Math.random() * scrambleSet.length)];
                                    }
                                }
                                text = s;
                            }
                        }

                        // Faster, smoother scramble.
                        Timer {
                            interval: 45
                            repeat: true
                            running: pwField.text.length > 0 && root.mode !== "locked"
                            onTriggered: pwDisplay.regenerate()
                        }
                        Timer {
                            interval: 60
                            repeat: true
                            running: root.revealMode && root.revealedCount < pwField.text.length
                            onTriggered: {
                                if (root.revealedCount < pwField.text.length)
                                    root.revealedCount += 1
                                pwDisplay.regenerate()
                            }
                        }

                        Rectangle {
                            id: eyeBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38; height: 22
                            radius: 3
                            color: eyeMa.containsMouse ? "#1a1326" : "transparent"
                            border.width: 1
                            border.color: root.revealMode ? root.accent2 : "#2a1f3a"
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            Canvas {
                                id: eyeIcon
                                anchors.centerIn: parent
                                width: 24; height: 16
                                property color stroke: root.revealMode ? root.accent2 : "#9a8aca"
                                onStrokeChanged: requestPaint()
                                Connections {
                                    target: root
                                    function onRevealModeChanged() { eyeIcon.requestPaint() }
                                }
                                Component.onCompleted: requestPaint()
                                onPaint: {
                                    var c = getContext("2d"); c.reset()
                                    c.lineJoin = "round"; c.lineCap = "round"
                                    c.strokeStyle = stroke; c.fillStyle = stroke
                                    c.lineWidth = 1.5

                                    // almond eye outline
                                    c.beginPath()
                                    c.moveTo(2, 8)
                                    c.bezierCurveTo(7, 1, 17, 1, 22, 8)
                                    c.bezierCurveTo(17, 15, 7, 15, 2, 8)
                                    c.closePath()
                                    c.stroke()

                                    if (root.revealMode) {
                                        // OPEN — pupil dot
                                        c.beginPath()
                                        c.arc(12, 8, 2.6, 0, Math.PI * 2)
                                        c.fill()
                                    } else {
                                        // CLOSED — diagonal slash through the eye
                                        c.lineWidth = 2
                                        c.strokeStyle = stroke
                                        c.beginPath()
                                        c.moveTo(3, 14); c.lineTo(21, 2)
                                        c.stroke()
                                    }
                                }
                            }
                            MouseArea {
                                id: eyeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.revealMode = !root.revealMode
                            }
                        }
                    }
                }

                Text {
                    id: errMsg
                    text: ""
                    color: "#ff5577"
                    font.family: root.mono
                    font.pixelSize: 13
                    opacity: text.length > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }
        }
    }

    // ============================================================
    // FANGS — transparent PNGs, animated.
    // ============================================================
    property real fangH: Math.min(620, root.height * 0.6)

    property real topHidden:  -fangH - 40
    property real botHidden:  root.height + 40

    // Closer-clamp positions: fangs meet ON the password line, not above it.
    property real topBitePass: form.y + form.height/2 - fangH * 0.84
    property real botBitePass: form.y + form.height/2 - fangH * 0.16

    // Captured last typed password, snapshotted on submit so we can chomp it
    // even after the field is cleared.
    property string lastSubmittedWord: ""

    function spawnFullBite() {
        var word = lastSubmittedWord.length > 0 ? lastSubmittedWord
                 : (pwField.prevText.length > 0 ? pwField.prevText : pwField.text)
        var n = word.length
        if (n <= 0) n = 6
        for (var i = 0; i < n; ++i) {
            pwMetrics.text = "X".repeat(i)
            var advance = i === 0 ? 0 : pwMetrics.advanceWidth
            var ch = word.charAt(i) || "▓"
            scheduleBite(advance + 10, pwBox.height / 2, ch, i * 32)
        }
    }

    function scheduleBite(x, y, ch, delay) {
        var t = Qt.createQmlObject(
            'import QtQuick 2.15; Timer { interval: ' + Math.max(1, delay) +
            '; running: true; repeat: false; }',
            root, "biteDelay")
        t.triggered.connect(function() {
            spawnBiteAt(biteLayer, x, y, ch)
            t.destroy()
        })
    }

    property real topClosed:  -fangH * 0.10
    property real botClosed:  root.height - fangH * 0.90

    property real topY: topHidden
    property real bottomY: botHidden
    property real fangPunch: 0.0
    property real fangOpacity: 1.0

    Behavior on topY    { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on bottomY { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on fangPunch { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Image {
        id: fangsTop
        source: "fangs_top.png"
        width: root.width
        height: root.fangH
        fillMode: Image.PreserveAspectFit
        smooth: true
        x: 0
        y: root.topY
        opacity: root.fangOpacity
        z: 30
        transformOrigin: Item.Bottom
        scale: 1.0 + root.fangPunch * 0.06
        rotation: -root.fangPunch * 2.5
        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale    { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity  { NumberAnimation { duration: 220 } }
    }

    Image {
        id: fangsBottom
        source: "fangs_bottom.png"
        width: root.width
        height: root.fangH
        fillMode: Image.PreserveAspectFit
        smooth: true
        x: 0
        y: root.bottomY
        opacity: root.fangOpacity
        z: 30
        transformOrigin: Item.Top
        scale: 1.0 + root.fangPunch * 0.06
        rotation: root.fangPunch * 2.5
        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale    { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity  { NumberAnimation { duration: 220 } }
    }

    // spark burst on impact
    Item {
        id: sparks
        anchors.fill: parent
        z: 28
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 240 } }

        Repeater {
            model: 18
            Rectangle {
                id: spark
                width: 4 + Math.random() * 6
                height: width
                radius: width / 2
                color: index % 2 ? root.accent : root.accent2
                x: root.width / 2 - width / 2
                y: root.height / 2 - height / 2
                property real ang: (index / 18) * Math.PI * 2 + Math.random() * 0.4
                property real dist: 80 + Math.random() * 240
                transform: Translate {
                    x: Math.cos(spark.ang) * spark.dist * sparks.opacity
                    y: Math.sin(spark.ang) * spark.dist * sparks.opacity
                }
            }
        }
    }

    Rectangle {
        id: biteFlash
        anchors.fill: parent
        color: root.danger
        opacity: 0
        z: 25
    }

    Rectangle {
        id: blackout
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        z: 50
    }

    // ============================================================
    // WRONG-PASSWORD BANNER — appears during chomp.
    // ============================================================
    Item {
        id: wrongBanner
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.18
        width: 720
        height: 110
        z: 35
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        scale: 0.8
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            color: "#15050a"
            opacity: 0.92
            radius: 10
            border.width: 2
            border.color: root.danger
        }

        Column {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "// WRONG"
                color: root.danger
                font.family: root.mono
                font.pixelSize: 42
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "try again ▸ bite #" + root.failCount + " / " + root.maxFails
                color: "#ffb0b8"
                font.family: root.mono
                font.pixelSize: 16
            }
        }
    }

    // ============================================================
    // STUCK-IN-JAWS LOCKOUT OVERLAY
    // Big message between the closed jaws, with countdown.
    // ============================================================
    Item {
        id: lockOverlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: root.mode === "locked" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
        z: 40

        Column {
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "// SYSTEM BIT YOU"
                color: root.danger
                font.family: root.mono
                font.pixelSize: 44
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "stuck in the jaws ▸ struggling does nothing"
                color: "#ffb0b8"
                font.family: root.mono
                font.pixelSize: 16
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "release in " + root.lockRemaining + "s"
                color: root.accent2
                font.family: root.mono
                font.pixelSize: 64
                font.bold: true
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360
                height: 6
                radius: 3
                color: "#2a1f3a"
                Rectangle {
                    height: parent.height
                    radius: 3
                    color: root.accent
                    width: parent.width * (1.0 - root.lockRemaining / Math.max(1, root.lockoutSeconds))
                    Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // ============================================================
    // SUCCESS — bite + zoom flourish + fade out
    // ============================================================
    Item {
        id: successFx
        anchors.fill: parent
        z: 45
        opacity: 0
        Text {
            anchors.centerIn: parent
            text: "// ACCESS GRANTED"
            color: root.accent2
            font.family: root.mono
            font.pixelSize: 56
            font.bold: true
        }
    }

    // global zoom transform for the whole scene on success
    transform: Scale {
        id: rootZoom
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: 1.0
        yScale: 1.0
    }

    // ============================================================
    // ANIMATIONS
    // ============================================================

    // Wrong password — bite + WRONG banner + retract.
    SequentialAnimation {
        id: chompAnim
        ScriptAction { script: {
            root.topY    = root.topBitePass
            root.bottomY = root.botBitePass
            shakeAnim.start()
        } }
        PauseAnimation { duration: 240 }
        ScriptAction { script: {
            root.fangPunch = 1.0
            biteFlash.opacity = 0.45
            sparks.opacity = 1.0
            wrongBanner.opacity = 1.0
            wrongBanner.scale = 1.0
            root.spawnFullBite()
        } }
        ParallelAnimation {
            NumberAnimation { target: biteFlash; property: "opacity"; to: 0; duration: 320 }
            NumberAnimation { target: sparks;    property: "opacity"; to: 0; duration: 540; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 700 }
        ScriptAction { script: { root.fangPunch = 0.0 } }
        ParallelAnimation {
            NumberAnimation { target: wrongBanner; property: "opacity"; to: 0; duration: 280 }
            NumberAnimation { target: wrongBanner; property: "scale";   to: 0.8; duration: 280 }
        }
        ScriptAction { script: {
            root.topY    = root.topHidden
            root.bottomY = root.botHidden
        } }
        PauseAnimation { duration: 280 }
        ScriptAction { script: {
            root.mode = "idle"
            pwField.forceActiveFocus()
        } }
    }

    // Lockout — slam shut and HOLD.
    SequentialAnimation {
        id: closedHoldAnim
        ScriptAction { script: {
            root.topY    = root.topClosed
            root.bottomY = root.botClosed
        } }
        PauseAnimation { duration: 220 }
        ScriptAction { script: {
            root.fangPunch = 1.0
            biteFlash.opacity = 0.7
            sparks.opacity = 1.0
        } }
        ParallelAnimation {
            NumberAnimation { target: biteFlash; property: "opacity"; to: 0; duration: 480 }
            NumberAnimation { target: sparks;    property: "opacity"; to: 0; duration: 600 }
        }
    }

    // Success — logo zooms huge, fangs slam shut, scene plunges into the mouth.
    SequentialAnimation {
        id: successAnim

        // 1. ACCESS GRANTED label appears, sparks flicker
        ScriptAction { script: {
            successFx.opacity = 1.0
            sparks.opacity = 0.6
        } }
        NumberAnimation { target: sparks; property: "opacity"; to: 0; duration: 380 }

        // 2. Logo zooms toward camera (1.0 -> 3.6) and slides to dead center.
        ParallelAnimation {
            NumberAnimation { target: logo; property: "scale"; to: 3.6; duration: 760; easing.type: Easing.InOutCubic }
            NumberAnimation { target: logo; property: "y"; to: root.height/2 - logo.height/2; duration: 760; easing.type: Easing.InOutCubic }
            NumberAnimation { target: form; property: "opacity"; to: 0; duration: 380 }
            NumberAnimation { target: powerRow; property: "opacity"; to: 0; duration: 380 }
            NumberAnimation { target: statusbar; property: "opacity"; to: 0; duration: 380 }
            NumberAnimation { target: dedsecFx; property: "opacity"; to: 0; duration: 380 }
        }

        // 3. Fangs slam shut around the (now huge) logo — the bite.
        ScriptAction { script: {
            root.topY    = root.topClosed
            root.bottomY = root.botClosed
        } }
        PauseAnimation { duration: 220 }
        ScriptAction { script: {
            root.fangPunch = 1.0
            biteFlash.opacity = 0.55
        } }
        ParallelAnimation {
            NumberAnimation { target: biteFlash; property: "opacity"; to: 0; duration: 280 }
            NumberAnimation { target: successFx; property: "opacity"; to: 0; duration: 260 }
        }
        PauseAnimation { duration: 160 }

        // 4. Inside-the-mouth shot: the scene dives further in (zoom past) while
        //    the fangs themselves grow, simulating the camera being swallowed.
        ParallelAnimation {
            NumberAnimation { target: rootZoom; property: "xScale"; to: 2.6; duration: 900; easing.type: Easing.InCubic }
            NumberAnimation { target: rootZoom; property: "yScale"; to: 2.6; duration: 900; easing.type: Easing.InCubic }
            NumberAnimation { target: logo;     property: "scale";  to: 0.0; duration: 900; easing.type: Easing.InCubic }
            NumberAnimation { target: blackout; property: "opacity"; to: 1; duration: 900; easing.type: Easing.InCubic }
        }
    }

    // Lockout end — open jaws, free the user.
    SequentialAnimation {
        id: openJawsAnim
        ScriptAction { script: {
            root.topY    = root.topHidden
            root.bottomY = root.botHidden
            root.fangPunch = 0.0
        } }
        PauseAnimation { duration: 320 }
        ScriptAction { script: {
            root.mode = "idle"
            pwField.text = ""
            errMsg.text = ""
            pwField.forceActiveFocus()
        } }
    }

    // ===== IDLE FANG-TEASE — every ~9s the fangs peek in, then retract =====
    SequentialAnimation {
        id: fangTease
        ScriptAction { script: {
            root.topY    = -root.fangH * 0.55
            root.bottomY = root.height - root.fangH * 0.45
        } }
        PauseAnimation { duration: 360 }
        ScriptAction { script: {
            root.topY    = root.topHidden
            root.bottomY = root.botHidden
        } }
    }
    Timer {
        interval: 8500
        repeat: true
        running: root.mode === "idle"
        onTriggered: { if (root.mode === "idle") fangTease.start() }
    }

    // ============================================================
    // LOGIN PLUMBING
    // ============================================================
    function doLogin() {
        if (root.mode === "locked" || root.mode === "success" || root.mode === "splash") return
        if (root.inputBusy) return
        if (pwField.text.length === 0) return
        errMsg.text = ""
        root.inputBusy = true
        root.lastSubmittedWord = pwField.text
        sddm.login(userModel.lastUser, pwField.text, sessionModel.lastIndex)
    }

    function startLockout() {
        root.mode = "locked"
        root.lockRemaining = root.lockoutSeconds
        closedHoldAnim.start()
        lockTimer.start()
    }

    function endLockout() {
        lockTimer.stop()
        root.failCount = 0
        openJawsAnim.start()
    }

    Timer {
        id: lockTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.lockRemaining -= 1
            if (root.lockRemaining <= 0) endLockout()
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.inputBusy = false
            if (root.mode === "locked" || root.mode === "success") return
            root.failCount += 1
            pwField.text = ""
            if (root.failCount >= root.maxFails) {
                errMsg.text = ""
                startLockout()
            } else {
                errMsg.text = ""
                root.mode = "chomp"
                chompAnim.stop()
                chompAnim.start()
            }
        }
        function onLoginSucceeded() {
            root.mode = "success"
            root.inputBusy = false
            errMsg.text = ""
            successAnim.start()
        }
    }

    // ============================================================
    // STATUS BAR
    // ============================================================
    Rectangle {
        id: statusbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 36
        color: "#0a0612"
        opacity: 0.85
        z: 10

        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; height: 1
            color: "#2a1f3a"
        }

        Text {
            id: clock
            anchors.left: parent.left; anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            color: root.accent2
            font.family: root.mono
            font.pixelSize: 13
            text: ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            color: "#7a6aaa"
            font.family: root.mono
            font.pixelSize: 12
            text: "session ▸ " + sessionModel.data(sessionModel.index(sessionModel.lastIndex, 0), Qt.DisplayRole)
        }

        Text {
            anchors.right: parent.right; anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            color: "#5a4a8a"
            font.family: root.mono
            font.pixelSize: 11
            text: "bite-os ▸ v0.3"
        }
    }

    // ============================================================
    // POWER BUTTONS
    // ============================================================
    Component {
        id: powerBtn
        Rectangle {
            property string label: ""
            property string glyph: ""
            property bool   available: true
            property var    action

            visible: available
            width: 150
            height: 56
            radius: 8
            color: pma.containsMouse ? "#1a1030" : "#0a0612"
            border.width: 1
            border.color: pma.containsMouse ? root.accent : "#2a1f3a"
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                radius: 10
                border.width: 1
                border.color: Qt.rgba(0.7, 0.54, 1.0, pma.containsMouse ? 0.45 : 0)
                Behavior on border.color { ColorAnimation { duration: 180 } }
            }

            Row {
                anchors.centerIn: parent
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: glyph
                    color: pma.containsMouse ? root.accent2 : root.accent
                    font.family: root.mono
                    font.pixelSize: 22
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: label
                    color: pma.containsMouse ? root.accent2 : "#b9a8e8"
                    font.family: root.mono
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            MouseArea {
                id: pma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.mode === "idle"
                onClicked: if (action) action()
            }
        }
    }

    Row {
        id: powerRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: statusbar.top
        anchors.bottomMargin: 28
        spacing: 18
        z: 12
        opacity: (root.mode === "idle") ? 1.0 : 0.25
        Behavior on opacity { NumberAnimation { duration: 240 } }

        Loader {
            sourceComponent: powerBtn
            onLoaded: {
                item.label = "SHUTDOWN"
                item.glyph = "⏻"
                item.available = true
                item.action = function() { sddm.powerOff() }
            }
        }
        Loader {
            sourceComponent: powerBtn
            onLoaded: {
                item.label = "REBOOT"
                item.glyph = "↻"
                item.available = true
                item.action = function() { sddm.reboot() }
            }
        }
        Loader {
            sourceComponent: powerBtn
            onLoaded: {
                item.label = "SUSPEND"
                item.glyph = "☾"
                item.available = true
                item.action = function() { sddm.suspend() }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd  hh:mm:ss")
    }

    Component.onCompleted: pwField.forceActiveFocus()
}

// The frame of every page: equal margins, the header, a body that scrolls
// when it has to, and a short entrance (slide and fade). Content is visible
// even if the entrance never runs.
import QtQuick
import QtQuick.Controls

Item {
    id: page
    property bool ready: true
    property string hint: ""
    property string title: ""
    property string subtitle: ""
    property string code: ""
    property bool scroll: true
    property real enter: 1
    readonly property real viewHeight: flick.height
    default property alias content: body.data

    onVisibleChanged: {
        if (!visible) return
        enterAnim.restart()
        header.play()
        flick.contentY = 0
    }
    NumberAnimation {
        id: enterAnim
        target: page
        property: "enter"
        from: 0
        to: 1
        duration: 280
        easing.type: Easing.OutCubic
    }

    Item {
        id: frame
        anchors.fill: parent
        anchors.leftMargin: 48
        anchors.rightMargin: 40
        anchors.topMargin: 34
        anchors.bottomMargin: 12
        opacity: 0.2 + 0.8 * page.enter
        transform: Translate { x: (1 - page.enter) * 18 }

        PageHeader {
            id: header
            visible: page.title !== ""
            width: parent.width - 8
            title: page.title
            subtitle: page.subtitle
            code: page.code
        }
        Flickable {
            id: flick
            anchors.top: header.visible ? header.bottom : parent.top
            anchors.topMargin: header.visible ? 26 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: page.scroll ? body.implicitHeight + 16 : height
            interactive: page.scroll && contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: LScrollBar {
                policy: flick.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
            Item {
                id: body
                x: 0
                y: 6
                width: flick.width - 14
                height: page.scroll ? implicitHeight : flick.height - 12
                implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            }
        }
    }
}

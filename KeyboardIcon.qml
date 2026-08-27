import QtQuick
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool connected: false
  property int thisSlot: 1

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property color dim: Qt.rgba(color.r, color.g, color.b, 0.35)

  Rectangle {
    id: board
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: root.height * 0.12
    width: root.width * 0.92
    height: root.height * 0.58
    radius: Math.max(1.5, root.iconSize * 0.08)
    color: "transparent"
    border.width: Math.max(1.2, root.iconSize * 0.08)
    border.color: root.color
  }

  SlotDot { slot: 1 }
  SlotDot { slot: 2 }
  SlotDot { slot: 3 }

  component SlotDot: Rectangle {
    property int slot: 1
    width: Math.max(2, root.iconSize * 0.12)
    height: width
    radius: width / 2
    color: root.connected && slot === root.thisSlot ? root.color : root.dim
    x: board.x + board.width * (0.22 + (slot - 1) * 0.28) - width / 2
    y: board.y + board.height * 0.42 - height / 2
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: board.bottom
    anchors.topMargin: Math.max(1, root.height * 0.04)
    width: board.width * 0.38
    height: Math.max(1.5, root.height * 0.08)
    radius: height / 2
    color: root.color
    opacity: root.connected ? 1 : 0.45
  }
}

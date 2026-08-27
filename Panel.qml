import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "wizwam.omakeytron"
  ipcTarget: "wizwam.omakeytron"
  manageIpc: false

  property string focusSection: "header"
  property bool cursorActive: false
  property int focusedSlot: 1

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: keychron.connected ? foreground : dim
  readonly property color barIconColor: keychron.connected ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property var slotNames: Model.slotNames(settings)
  readonly property int thisSlot: Model.slotNumber(setting("thisSlot", "1"))
  readonly property string batteryText: keychron.battery === null || keychron.battery === undefined ? "" : (String(keychron.battery) + "%")
  readonly property string heroMeta: {
    if (keychron.connected) return (keychron.deviceName || "Keychron V6 Max") + (batteryText !== "" ? " · " + batteryText : "")
    if (keychron.device) return "On another Bluetooth host"
    return keychron.statusText
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      focusedSlot = thisSlot
      keychron.refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Service {
    id: keychron
    settings: root.settings
    shell: root.bar ? root.bar.shell : null
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { keychron.refresh(); return "ok" }
    function status(): string { return keychron.statusText }
    function connectThisHost(): string { keychron.connectThisHost(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: keychron.connected
      ? "Keychron — " + keychron.thisHostName
      : (keychron.device ? "Keychron — another host" : "Keychron — not found")
    iconComponent: Component {
      Item {
        KeyboardIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
          connected: keychron.connected
          thisSlot: root.thisSlot
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) keychron.connectThisHost()
      else if (buttonCode === Qt.MiddleButton) keychron.copyToClipboard(keychron.deviceAddress, "address")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function() { root.cursorActive = true }
      onActivateRequested: {
        if (root.focusSection === "header") keychron.connectThisHost()
        else keychron.connectThisHost()
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            id: header
            width: parent.width
            implicitHeight: hero.implicitHeight

            PanelHero {
              id: hero
              width: parent.width
              title: "Keychron V6 Max"
              meta: root.heroMeta
              detail: keychron.connected ? keychron.thisHostName : "Away"
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: keychron.connected ? 1.0 : 0.55
              iconComponent: Component {
                KeyboardIcon {
                  iconSize: Style.font.display
                  color: root.iconColor
                  connected: keychron.connected
                  thisSlot: root.thisSlot
                }
              }
            }
          }

          Text {
            visible: keychron.actionStatus !== "" || keychron.lastError !== ""
            width: parent.width
            text: keychron.actionStatus !== "" ? keychron.actionStatus : keychron.lastError
            color: keychron.lastError !== "" && keychron.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSectionHeader {
            text: "BLUETOOTH HOSTS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: [1, 2, 3]
            HostRow {
              required property int modelData
              width: column.width
              slot: modelData
              hostName: String(root.slotNames[modelData] || "")
              isThisMachine: modelData === root.thisSlot
              activeHere: keychron.connected && modelData === root.thisSlot
            }
          }

          Text {
            width: parent.width
            text: "Tap FN+1 / FN+2 / FN+3 on the keyboard to switch. Hold 4–6 seconds to pair that slot. Linux cannot send those chords; the V6 Max firmware owns the hop."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            visible: keychron.deviceAddress !== ""
            width: parent.width
            text: keychron.deviceAddress + (root.batteryText !== "" ? " · battery " + root.batteryText : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component HostRow: Item {
    id: row
    property int slot: 1
    property string hostName: ""
    property bool isThisMachine: false
    property bool activeHere: false

    implicitHeight: Math.max(Style.space(36), labels.implicitHeight + Style.space(10))

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: row.activeHere ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"
      border.width: 1
      border.color: row.activeHere ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
    }

    Column {
      id: labels
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(2)

      Row {
        spacing: Style.space(8)
        Text {
          text: "FN+" + row.slot
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          text: row.hostName
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      Text {
        text: row.activeHere ? "Connected here" : (row.isThisMachine ? "This machine · tap FN+" + row.slot + " to return" : "Tap FN+" + row.slot + " on the Keychron")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: row.isThisMachine ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: {
        if (row.isThisMachine) keychron.connectThisHost()
        else Quickshell.execDetached(["omarchy", "osd", "-i", "keyboard", "-m", "Tap FN+" + row.slot + " · " + row.hostName, "-d", "1600"])
      }
    }
  }
}

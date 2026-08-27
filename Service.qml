import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var shell: null
  property var pluginRegistry: null

  property bool adapterPowered: false
  property bool connected: false
  property bool paired: false
  property var device: null
  property var candidates: []
  property bool refreshing: false
  property bool seenStatus: false
  property string statusText: "Checking…"
  property string actionStatus: ""
  property string lastError: ""
  property string deviceAddress: ""
  property string deviceName: ""
  property var battery: null

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 2, 1, 30)
  readonly property bool showOsd: boolSetting("showOsd", true)
  readonly property int thisSlot: Model.slotNumber(setting("thisSlot", "1"))
  readonly property string helperPath: resolvedHelper()
  readonly property bool busy: statusProcess.running || controlProcess.running
  readonly property string hostName: Model.hostLabel(settings, connected)
  readonly property string thisHostName: Model.slotNames(settings)[thisSlot]

  property string _statusOutput: ""
  property string _statusError: ""
  property string _controlOutput: ""
  property string _controlError: ""

  function resolvedHelper() {
    var url = String(Qt.resolvedUrl("./status.py"))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return url
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (value === true || value === "true") return true
    if (value === false || value === "false") return false
    return fallback
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function elideStatus(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 140 ? value.substring(0, 137) + "…" : value
  }

  function refresh() {
    if (statusProcess.running || helperPath === "") return
    _statusOutput = ""
    _statusError = ""
    refreshing = true
    var match = String(setting("deviceMatch", "Keychron V6 Max"))
    var address = String(setting("deviceAddress", ""))
    statusProcess.command = ["python3", helperPath, "--match", match, "--address", address]
    statusProcess.running = true
  }

  function applyStatus(raw) {
    var parsed = Model.parseStatus(raw)
    var wasConnected = connected
    var hadStatus = seenStatus
    if (!parsed.ok && !parsed.device) {
      lastError = parsed.lastError || "Failed to read Keychron status"
      statusText = lastError
      seenStatus = true
      return
    }
    device = parsed.device
    candidates = parsed.candidates
    adapterPowered = parsed.adapterPowered === true
    connected = !!(parsed.device && parsed.device.connected)
    paired = !!(parsed.device && parsed.device.paired)
    deviceAddress = parsed.device ? String(parsed.device.address || "") : ""
    deviceName = parsed.device ? String(parsed.device.name || parsed.device.alias || "") : ""
    battery = parsed.device ? parsed.device.battery : null
    lastError = parsed.lastError || ""
    if (connected) statusText = deviceName ? deviceName + " · " + thisHostName : thisHostName
    else if (device) statusText = (deviceName || "Keychron") + " on another host"
    else statusText = lastError || "Keychron not found"
    seenStatus = true
    if (hadStatus && wasConnected !== connected) announceTransition(connected)
  }

  function announceTransition(nowConnected) {
    if (!showOsd) return
    var message = nowConnected
      ? "Keychron → " + thisHostName
      : "Keychron left " + thisHostName
    Quickshell.execDetached(["omarchy", "osd", "-i", "keyboard", "-m", message, "-d", "1800"])
  }

  function connectThisHost() {
    if (!deviceAddress) {
      actionStatus = "No Keychron address yet"
      actionStatusTimer.restart()
      return
    }
    runControl(["omarchy", "bluetooth", "device", "connect", deviceAddress])
  }

  function runControl(command) {
    if (controlProcess.running) return
    _controlOutput = ""
    _controlError = ""
    controlProcess.command = command
    controlProcess.running = true
  }

  function copyToClipboard(value, label) {
    var text = String(value || "")
    if (text === "") return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
    actionStatus = "Copied " + (label || "value")
    actionStatusTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: actionStatusTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Timer {
    id: delayedRefresh
    interval: 700
    repeat: false
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root._statusOutput = text }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true; onStreamFinished: root._statusError = text }
    onExited: function(exitCode) {
      root.refreshing = false
      var stdout = String(statusStdout.text || root._statusOutput || "")
      var stderr = String(statusStderr.text || root._statusError || "")
      if (stdout !== "") root.applyStatus(stdout)
      else root.lastError = root.elideStatus(stderr || "Could not read Keychron status")
    }
  }

  Process {
    id: controlProcess
    running: false
    command: []
    stdout: StdioCollector { id: controlStdout; waitForEnd: true; onStreamFinished: root._controlOutput = text }
    stderr: StdioCollector { id: controlStderr; waitForEnd: true; onStreamFinished: root._controlError = text }
    onExited: function(exitCode) {
      var stdout = String(controlStdout.text || root._controlOutput || "")
      var stderr = String(controlStderr.text || root._controlError || "")
      if (exitCode !== 0) {
        root.lastError = root.elideStatus(stderr || stdout || "Command failed")
        root.actionStatus = root.lastError
      } else {
        root.lastError = ""
        root.actionStatus = "Asked BlueZ to reconnect"
      }
      actionStatusTimer.restart()
      delayedRefresh.restart()
    }
  }
}

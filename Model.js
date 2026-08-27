function toArray(values) {
  if (!values) return []
  if (Array.isArray(values)) return values.slice()
  var length = Number(values.length || 0)
  if (!isFinite(length) || length <= 0) return []
  var list = []
  for (var i = 0; i < length; i++) list.push(values[i])
  return list
}

function emptyStatus(errorText) {
  return {
    ok: false,
    adapterPowered: null,
    adapterName: "",
    match: "",
    pinnedAddress: "",
    candidates: [],
    device: null,
    lastError: String(errorText || "")
  }
}

function parseStatus(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object") return emptyStatus("Invalid status payload")
    return {
      ok: parsed.ok === true,
      adapterPowered: parsed.adapterPowered,
      adapterName: String(parsed.adapterName || ""),
      match: String(parsed.match || ""),
      pinnedAddress: String(parsed.pinnedAddress || ""),
      candidates: toArray(parsed.candidates),
      device: parsed.device && typeof parsed.device === "object" ? parsed.device : null,
      lastError: String(parsed.lastError || "")
    }
  } catch (e) {
    return emptyStatus("Could not parse Keychron status")
  }
}

function slotNumber(value) {
  var n = parseInt(String(value || "1"), 10)
  if (n !== 1 && n !== 2 && n !== 3) return 1
  return n
}

function slotNames(settings) {
  settings = settings || {}
  return {
    1: String(settings.slot1Name || "Omarchy PC"),
    2: String(settings.slot2Name || "Mac Mini"),
    3: String(settings.slot3Name || "Windows Laptop")
  }
}

function hostLabel(settings, connected) {
  var names = slotNames(settings)
  var slot = slotNumber(settings && settings.thisSlot)
  if (connected) return names[slot]
  return "Away"
}

function chordFor(slot) {
  return "FN+" + String(slotNumber(slot))
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    slotNumber: slotNumber,
    slotNames: slotNames,
    hostLabel: hostLabel,
    chordFor: chordFor
  }
}

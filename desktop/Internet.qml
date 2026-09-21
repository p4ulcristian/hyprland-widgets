// Is the internet up (a real ping, not just a plugged cable), how fast is traffic moving right
// now, and the addresses worth knowing. Speeds come from the kernel's byte counters once a second.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root
  spacing: 6

  readonly property string pingHost: "1.1.1.1"
  // The private tunnel to the gate; up means the gate answers through it.
  readonly property string vpnName: "WireGuard"
  readonly property string vpnHost: "10.99.0.10"

  property string iface: ""
  property string gateway: ""
  property string localIp: ""
  property int linkMbit: 0
  property string publicIp: ""
  property real pingMs: -1   // -1 = no answer
  property real vpnMs: -1
  property real down: 0      // bytes per second
  property real up: 0
  property var history: []   // last 60 s of { d, u }
  property var last: null    // previous counter sample

  function ms(v) { return v < 0 ? "no answer" : (v < 10 ? v.toFixed(1) : Math.round(v)) + " ms" }
  function rate(b) {
    return b >= 1048576 ? (b / 1048576).toFixed(b >= 10485760 ? 0 : 1) + " MB/s" : Math.round(b / 1024) + " KB/s"
  }
  function link(m) { return m >= 1000 ? (m / 1000) + " Gbit" : m + " Mbit" }

  function sample(text) {
    const l = text.split("\n").find(l => l.trim().indexOf(root.iface + ":") === 0)
    if (!l) return
    const f = l.split(":")[1].trim().split(/\s+/)
    const now = { t: Date.now(), rx: +f[0], tx: +f[8] }
    if (last && now.t > last.t) {
      const s = (now.t - last.t) / 1000
      down = Math.max(0, (now.rx - last.rx) / s)
      up = Math.max(0, (now.tx - last.tx) / s)
      history = history.concat([{ d: down, u: up }]).slice(-60)
    }
    last = now
  }

  // /proc files report size 0, so read them through cat rather than a file watcher.
  Process {
    id: counters
    command: ["cat", "/proc/net/dev"]
    stdout: StdioCollector { onStreamFinished: root.sample(text) }
  }
  Timer { interval: 1000; running: root.iface !== ""; repeat: true; onTriggered: counters.running = true }

  Process {
    id: info
    running: true
    command: ["sh", "-c", "r=$(ip -4 route show default | head -1); i=$(echo \"$r\" | sed -n 's/.* dev \\([^ ]*\\).*/\\1/p'); g=$(echo \"$r\" | sed -n 's/.*via \\([^ ]*\\).*/\\1/p'); a=$(ip -4 -br addr show dev \"$i\" 2>/dev/null | awk '{print $3}' | cut -d/ -f1); s=$(cat /sys/class/net/$i/speed 2>/dev/null); echo \"$i|$g|$a|$s\""]
    stdout: StdioCollector {
      onStreamFinished: {
        const f = text.trim().split("|")
        if (f[0] !== root.iface) { root.last = null; root.history = [] }
        root.iface = f[0] || ""; root.gateway = f[1] || ""; root.localIp = f[2] || ""; root.linkMbit = Math.max(0, +f[3] || 0)
      }
    }
  }
  Process {
    id: ping
    running: true
    command: ["ping", "-c1", "-W2", root.pingHost]
    stdout: StdioCollector { onStreamFinished: { const m = text.match(/time=([\d.]+)/); root.pingMs = m ? +m[1] : -1 } }
  }
  Process {
    id: vpnPing
    running: true
    command: ["ping", "-c1", "-W2", root.vpnHost]
    stdout: StdioCollector { onStreamFinished: { const m = text.match(/time=([\d.]+)/); root.vpnMs = m ? +m[1] : -1 } }
  }
  Process {
    id: pub
    running: true
    command: ["sh", "-c", "curl -4 -s --max-time 5 https://1.1.1.1/cdn-cgi/trace | sed -n 's/^ip=//p'"]
    stdout: StdioCollector { onStreamFinished: { const t = text.trim(); if (t) root.publicIp = t } }
  }
  Timer { interval: 10000; running: true; repeat: true; onTriggered: { ping.running = true; vpnPing.running = true } }
  Timer { interval: 30000; running: true; repeat: true; onTriggered: info.running = true }
  Timer { interval: 600000; running: true; repeat: true; onTriggered: pub.running = true }

  SectionHeader { text: "INTERNET"; Layout.bottomMargin: 10 }

  RowLayout {
    Layout.fillWidth: true
    Label {
      text: root.pingMs < 0 ? "Offline" : "Online"
      color: root.pingMs < 0 ? Theme.red : Theme.fg
      font.pixelSize: 18; font.bold: true
    }
    Item { Layout.fillWidth: true }
    Label {
      text: root.pingMs < 0 ? "" : root.ms(root.pingMs)
      color: root.pingMs > 150 ? Theme.yellow : Theme.accent
      font.pixelSize: 18; font.bold: true
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Label { text: " " + root.rate(root.down); color: Theme.accent; font.pixelSize: 16; font.bold: true }
    Item { Layout.fillWidth: true }
    Label { text: " " + root.rate(root.up); color: Theme.fg; font.pixelSize: 16; font.bold: true }
  }

  // Last 60 seconds: download filled in the accent colour, upload as a plain line over it.
  Canvas {
    id: graph
    Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 6
    implicitHeight: 44
    readonly property var pts: root.history
    onPtsChanged: requestPaint()
    onPaint: {
      const g = getContext("2d"), w = width, h = height, n = 60
      g.clearRect(0, 0, w, h)
      g.strokeStyle = Theme.shadow; g.lineWidth = 1
      g.beginPath(); g.moveTo(0, h - 0.5); g.lineTo(w, h - 0.5); g.stroke()
      if (pts.length < 2) return
      const top = Math.max(131072, ...pts.map(p => Math.max(p.d, p.u)))
      const x = i => w - (pts.length - 1 - i) * w / (n - 1)
      const y = v => h - 2 - (h - 4) * v / top
      const trace = k => { g.beginPath(); pts.forEach((p, i) => i ? g.lineTo(x(i), y(p[k])) : g.moveTo(x(i), y(p[k]))) }
      trace("d"); g.lineTo(x(pts.length - 1), h); g.lineTo(x(0), h); g.closePath()
      g.fillStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35); g.fill()
      g.lineWidth = 2
      trace("d"); g.strokeStyle = Theme.accent; g.stroke()
      trace("u"); g.strokeStyle = Theme.fg; g.stroke()
    }
  }

  DetailRow {
    label: "Local"; value: root.localIp || "–"
    icon: ""; onClicked: Quickshell.execDetached(["wl-copy", root.localIp])          // copy
  }
  DetailRow {
    label: "Router"; value: root.gateway || "–"
    icon: ""; onClicked: Quickshell.execDetached(["xdg-open", "http://" + root.gateway])  // open its page
  }
  DetailRow {
    label: "Public"; value: root.publicIp || "–"
    icon: ""; onClicked: Quickshell.execDetached(["wl-copy", root.publicIp])
  }
  DetailRow { label: "Link"; value: root.iface ? (root.linkMbit ? root.link(root.linkMbit) + " · " : "") + root.iface : "no connection" }
  DetailRow {
    label: root.vpnName; value: root.vpnMs < 0 ? "down" : "up · " + root.ms(root.vpnMs)
    valueColor: root.vpnMs < 0 ? Theme.red : Theme.fg
  }
}

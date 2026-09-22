// How busy the processor, memory and graphics card are, and what they are.
// Readings come from bin/system-stats: what the hardware is once, usage every 2 s
// (CPU usage is the change in /proc/stat between two readings).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root
  spacing: 22

  property var info: ({})
  property var now: ({})
  property real cpuPct: 0
  property var lastStat: null   // previous { busy, total } CPU jiffies

  function pctColor(p) { return p >= 90 ? Theme.red : p >= 75 ? Theme.yellow : Theme.accent }
  function tempColor(t) { return t >= 85 ? Theme.red : t >= 70 ? Theme.yellow : Theme.soft }
  function keys(text) {
    const o = {}
    for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1) }
    return o
  }
  function sample(text) {
    const o = keys(text)
    // cpu user nice system idle iowait irq softirq steal: idle + iowait is idle time.
    const f = (o.stat || "").split(/\s+/).slice(1, 9).map(Number)
    if (f.length === 8) {
      const total = f.reduce((a, b) => a + b, 0), busy = total - f[3] - f[4]
      if (lastStat && total > lastStat.total) cpuPct = 100 * (busy - lastStat.busy) / (total - lastStat.total)
      lastStat = { busy: busy, total: total }
    }
    now = o
  }

  readonly property real memUsed: now.memtotal ? now.memtotal - now.memavail : 0
  readonly property real memPct: now.memtotal ? 100 * memUsed / now.memtotal : 0
  readonly property bool hasGpu: now.gpubusy !== undefined
  readonly property real vramPct: now.vramtotal > 0 ? 100 * now.vramused / now.vramtotal : 0

  Process {
    running: true
    command: [Quickshell.shellDir + "/bin/system-stats", "info"]
    stdout: StdioCollector { onStreamFinished: root.info = root.keys(text) }
  }
  Process {
    id: stats
    running: true
    command: [Quickshell.shellDir + "/bin/system-stats"]
    stdout: StdioCollector { onStreamFinished: root.sample(text) }
  }
  Timer { interval: 2000; running: true; repeat: true; onTriggered: stats.running = true }

  SectionHeader { text: "SYSTEM" }

  // name .......... pct%
  // what it is
  // [=====      ]
  // left detail .. right detail
  component UsageRow: ColumnLayout {
    id: row
    property string name
    property string model
    property real pct
    property string leftText
    property string rightText
    property color rightColor: Theme.fg
    Layout.fillWidth: true
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      Label { text: row.name; font.pixelSize: 18; font.bold: true }
      Item { Layout.fillWidth: true }
      Label { text: Math.round(row.pct) + "%"; color: root.pctColor(row.pct); font.pixelSize: 18; font.bold: true }
    }
    Label { Layout.fillWidth: true; visible: text !== ""; text: row.model; elide: Text.ElideRight; color: Theme.soft }
    Meter { Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2; pct: row.pct; fill: root.pctColor(row.pct) }
    RowLayout {
      Layout.fillWidth: true
      Label { text: row.leftText; color: Theme.soft }
      Item { Layout.fillWidth: true }
      Label { text: row.rightText; color: row.rightColor }
    }
  }

  UsageRow {
    name: "Processor"
    model: root.info.cpu || ""
    pct: root.cpuPct
    leftText: (root.info.threads ? root.info.threads + " threads" : "") + (root.now.mhz ? " · " + (root.now.mhz / 1000).toFixed(1) + " GHz" : "")
    rightText: root.now.cputemp ? root.now.cputemp + "°C" : ""
    rightColor: root.tempColor(+root.now.cputemp)
  }

  UsageRow {
    name: "Memory"
    model: [root.info.ramtype, root.info.ramspeed ? root.info.ramspeed + " MT/s" : "",
            root.info.sticks > 1 ? root.info.sticks + " sticks" : "", root.info.ramvendor].filter(s => s).join(" · ")
    pct: root.memPct
    leftText: Theme.size(root.memUsed) + " used"
    rightText: Theme.size(+root.now.memavail || 0) + " free of " + Theme.size(+root.now.memtotal || 0)
  }

  UsageRow {
    visible: root.hasGpu
    name: "Graphics"
    model: root.info.gpu || ""
    pct: +root.now.gpubusy || 0
    leftText: "VRAM " + Theme.size(+root.now.vramused || 0) + " of " + Theme.size(+root.now.vramtotal || 0)
          + " (" + Math.round(root.vramPct) + "%)"
    rightText: [root.now.gputemp ? root.now.gputemp + "°C" : "", root.now.gpuwatts ? root.now.gpuwatts + " W" : ""].filter(s => s).join(" · ")
    rightColor: root.tempColor(+root.now.gputemp)
  }
  // Video encoding runs on its own chip, so it gets its own line: busy while Graphics looks idle.
  DetailRow {
    visible: root.hasGpu && root.now.gpuenc !== undefined
    label: "Video encoder"
    value: (+root.now.gpuenc || 0) + "%"
    valueColor: +root.now.gpuenc > 0 ? Theme.accent : Theme.soft
  }
}

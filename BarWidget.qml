import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.itsdotdev.youtube-music"

  property string title: ""
  property string artist: ""
  property string thumbnail: ""
  property bool playing: false
  property bool playerRunning: false
  property bool popupOpen: false
  property bool popoutSwitchClosing: false
  property string scriptPath: Qt.resolvedUrl("bin/youtube-music").toString().replace("file://", "")
  readonly property bool hasTrack: title !== ""
  readonly property color foreground: root.bar ? root.bar.barForeground : "#f7f7f7"
  readonly property color accent: Color.accent
  readonly property bool opened: popupOpen

  implicitWidth: hasTrack ? Style.space(154) : Style.space(30)
  implicitHeight: barSize

  function openPlayer() {
    root.toggle("{}")
  }

  function open(payloadJson) {
    popupOpen = true
    Qt.callLater(function() {
      if (popupPlayerLoader.item && popupPlayerLoader.item.open) popupPlayerLoader.item.open(payloadJson || "{}")
    })
  }

  function close(reason) {
    if (popupPlayerLoader.item && popupPlayerLoader.item.close) popupPlayerLoader.item.close()
    popupOpen = false
  }

  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close("popoutSwitch")
    Qt.callLater(function() { popoutSwitchClosing = false })
  }

  function toggle(payloadJson) {
    if (root.opened) root.close("toggle")
    else root.open(payloadJson || "{}")
  }

  function runAction(action) {
    if (actionProc.running) return
    actionProc.command = ["bash", scriptPath, action]
    actionProc.running = true
  }

  function refreshStatus() {
    if (statusProc.running) return
    statusProc.command = ["bash", scriptPath, "status"]
    statusProc.running = true
  }

  function applyStatus(raw) {
    try {
      var status = JSON.parse(String(raw || "{}"))
      root.playerRunning = status.running === true
      root.playing = root.playerRunning && status.paused !== true
      root.title = String(status.title || "")
      root.artist = String(status.artist || "")
      root.thumbnail = String(status.thumbnail || "")
    } catch (error) {
      console.warn("YouTube Music bar: invalid player status", error)
    }
  }

  Rectangle {
    anchors.centerIn: parent
    width: parent.width
    height: Math.max(Style.space(24), parent.height - Style.space(8))
    radius: Style.space(6)
    color: root.hasTrack ? "#171717" : "transparent"
    border.width: root.hasTrack ? 1 : 0
    border.color: "#343434"

    Item {
      anchors.fill: parent
      visible: !root.hasTrack

      Text {
        anchors.centerIn: parent
        text: "󰗃"
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.menuFamily
        font.pixelSize: Style.font.iconLarge
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPlayer() }
    }

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      spacing: Style.space(3)
      visible: root.hasTrack

      Rectangle {
        width: parent.height
        height: parent.height
        radius: Style.space(4)
        color: "#2a2a2a"
        clip: true
        Image { anchors.fill: parent; source: root.thumbnail; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openPlayer()
        }
      }

      Text {
        width: Style.space(52)
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.menuFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
        MouseArea {
          anchors.fill: parent
          anchors.topMargin: -Style.space(5)
          anchors.bottomMargin: -Style.space(5)
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openPlayer()
        }
      }

      Item {
        width: Style.space(20)
        height: parent.height
        Text { anchors.centerIn: parent; text: "󰒮"; color: root.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runAction("previous") }
      }

      Rectangle {
        width: Style.space(22)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 0
        anchors.verticalCenter: parent.verticalCenter
        Text { anchors.centerIn: parent; text: root.playing ? "󰏤" : "󰐊"; color: root.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.playerRunning) root.runAction("toggle")
            else root.openPlayer()
          }
        }
      }

      Item {
        width: Style.space(20)
        height: parent.height
        Text { anchors.centerIn: parent; text: "󰒭"; color: root.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runAction("next") }
      }

    }
  }

  KeyboardPanel {
    id: playerPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: playerPopup.fittedContentWidth(Style.space(400))
    contentHeight: playerPopup.cappedContentHeight(Style.space(540))
    padding: 0
    margin: Style.gapsOut
    focusTarget: popupPlayerLoader.item ? popupPlayerLoader.item.searchInput : null

    Loader {
      id: popupPlayerLoader
      anchors.fill: parent
      active: true
      source: Qt.resolvedUrl("Player.qml")
      onLoaded: {
        item.closeCallback = function() { root.close("closeCallback") }
      }
    }
  }


  Process {
    id: actionProc
    onExited: root.refreshStatus()
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Timer {
    interval: 900
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  IpcHandler {
    target: root.moduleName

    function open(): void { root.open("{}") }
    function close(): void { root.close("ipc") }
    function toggle(): void { root.toggle("{}") }
    function toggleSearch(): void {
      if (root.popupOpen && popupPlayerLoader.item)
        popupPlayerLoader.item.toggleSearch()
    }
  }
}

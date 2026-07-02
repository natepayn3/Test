import QtQuick

QtObject {
    id: config

    // --- SYSTEM THEME MATRIX ---
    readonly property color themeBackground: Qt.rgba(0.4, 0.4, 0.4, 0.7)
    readonly property color colorBackground: Qt.rgba(0.4, 0.4, 0.4, 0.28)
    readonly property color colorBorder: Qt.rgba(1, 1, 1, 0.05)
    readonly property color hoverBorder: Qt.rgba(0, 0, 0, 0.2)
    readonly property color themeBorder: Qt.rgba(0, 0, 0, 0.15)
    readonly property color cardBorder: Qt.rgba(0, 0, 0, 0.2)
    readonly property color themeText: "#ffffff"
    readonly property color themeAccent: Qt.rgba(0.4, 0.4, 0.4, 0.28)
    readonly property color colorAccent: Qt.rgba(0.6, 0.45, 0.9, 1.0)
    
    readonly property string shellFont: "Google Sans Flex"
    readonly property int radiusValue: 16
    
    // --- GLOBAL LAYOUT GEOMETRY ---
    readonly property int panelWidth: 360
    readonly property int launcherWidth: 500
    readonly property int panelBottomMargin: 100

    // --- UNIFORM ANIMATION METRICS ---
    readonly property int durationIn: 400
    readonly property int durationOut: 200
    readonly property int opacityIn: 200
    readonly property int opacityOut: 150
    readonly property real springBack: 2.5
    readonly property real springIn: 1.5
}

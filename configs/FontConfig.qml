import QtQuick

QtObject {
    id: fontConfig

    // --- TYPOGRAPHY FAMILIES ---
    readonly property string mainFont: "Google Sans Flex"
    readonly property string monoFont: "JetBrains Mono"
    readonly property string iconFont: "Material Symbols Outlined"

    // --- SYSTEM THEME PALETTE ---
    readonly property color overlayForeground: Qt.rgba(0.4, 0.4, 0.4, 0.9)  // Muted grey overlay text
    readonly property color overlayBackground: Qt.rgba(0.4, 0.4, 0.4, 0.28) // Translucent base layer
    readonly property color trackBackground: Qt.rgba(1, 1, 1, 0.05)         // Track translucent fill
    readonly property color borderMuted: Qt.rgba(1, 1, 1, 0.03)             // Subtle divider bounds
    readonly property color textPrimary: "#ffffff"                          // Main solid text
    readonly property color textMuted: Qt.rgba(1, 1, 1, 0.5)                // Secondary labels

    // --- ENHANCED SMOOTHING INJECTOR ---
    readonly property int preferredRenderType: Text.NativeRendering
    readonly property bool useAntialiasing: true

    // --- HELPER FACTORIES ---
    function applySmoothing(targetTextElement) {
        if (targetTextElement) {
            targetTextElement.renderType = preferredRenderType;
            targetTextElement.antialiasing = useAntialiasing;
        }
    }

    // GLOBAL TEXT OUTLINE INJECTOR
    function applyOutline(targetTextElement, outlineColor) {
        if (targetTextElement) {
            targetTextElement.style = Text.Outline;
            targetTextElement.styleColor = outlineColor !== undefined ? outlineColor : Qt.rgba(0, 0, 0, 0.45);
            targetTextElement.renderType = preferredRenderType;
            targetTextElement.antialiasing = useAntialiasing;
        }
    }
}

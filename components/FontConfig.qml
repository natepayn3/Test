import QtQuick

QtObject {
    id: fontConfig

    // --- TYPOGRAPHY FAMILIES ---
    property string mainFont: "Google Sans Flex"
    property string monoFont: "JetBrains Mono"
    property string iconFont: "Material Symbols Outlined"

    // --- ENHANCED SMOOTHING INJECTOR ---
    property int preferredRenderType: Text.NativeRendering
    property bool useAntialiasing: true

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

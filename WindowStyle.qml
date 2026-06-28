import QtQuick

Item {
    id: styleRoot

    // --- Configuration Constants ---
    readonly property color bgDarkGrey: "#1e1e24"
    readonly property color textSoftWhite: "#f5f5f5"
    readonly property int animDuration: 350 
    readonly property int wingSize: 14
    readonly property int borderRadius: 16 

    // --- Public Interface ---
    property bool isOpen: false
    default property alias content: innerContent.data

    anchors.fill: parent

    // --- Main Animation & Scale Core ---
    Item {
        id: popupContent
        anchors.fill: parent
        transformOrigin: Item.Left

        opacity: styleRoot.isOpen ? 1.0 : 0.0
        scale: styleRoot.isOpen ? 1.0 : 0.0
        x: styleRoot.isOpen ? 3 : -parent.width

        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: styleRoot.animDuration; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        Behavior on x { NumberAnimation { duration: styleRoot.animDuration; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        
        property real wingShift: Math.max(0, styleRoot.wingSize * (1 - (popupContent.scale * 4)))

        // Card Main Body
        Rectangle {
            id: cardBody
            y: styleRoot.wingSize
            height: parent.height - (styleRoot.wingSize * 2)
            color: styleRoot.bgDarkGrey
            z: 2

            x: 0- (popupContent.x > 0 ? popupContent.x : 0)
            width: parent.width - styleRoot.wingSize + (popupContent.x > 0 ? popupContent.x : 0)

            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: Math.round(styleRoot.borderRadius)
            bottomRightRadius: Math.round(styleRoot.borderRadius)
            border.width: 0

            // Container for injected custom dashboards
            Item {
                id: innerContent
                anchors.fill: parent
                z: 5
            }
        }

        // --- Wings Layer Block ---
        Item {
            x: cardBody.x - popupContent.wingShift - (popupContent.x > 0 ? popupContent.x : 0)
            y: cardBody.y
            width: cardBody.width
            height: cardBody.height
            z: 3 

            // Top-Left Inverted Corner Wing
            Item { 
                x: 4; y: -styleRoot.wingSize
                width: styleRoot.wingSize; height: styleRoot.wingSize; clip: true
                Rectangle {
                    width: styleRoot.wingSize * 6; height: styleRoot.wingSize * 6; radius: styleRoot.wingSize * 3
                    color: "transparent"; border.color: styleRoot.bgDarkGrey; border.width: styleRoot.wingSize * 2
                    x: -(styleRoot.wingSize * 2); y: -(styleRoot.wingSize * 3)
                }
            }

            // Bottom-Left Inverted Corner Wing
            Item {
                x: 4; y: parent.height
                width: styleRoot.wingSize; height: styleRoot.wingSize; clip: true
                
                Rectangle {
                    width: styleRoot.wingSize * 6; height: styleRoot.wingSize * 6; radius: styleRoot.wingSize * 3
                    color: "transparent"; border.color: styleRoot.bgDarkGrey; border.width: styleRoot.wingSize * 2
                    x: -(styleRoot.wingSize * 2); y: -(styleRoot.wingSize * 2)
                }
            }
        }
    }
}
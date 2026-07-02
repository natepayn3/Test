import QtQuick
import Quickshell.Io
import "../../configs"

Column {
    id: weatherRoot
    spacing: 4

    property string weatherTemp: "--"
    property string weatherFeelsLike: "--"
    property string weatherDesc: "Loading..."
    property string weatherGlyph: "cloud"

    Component.onCompleted: weatherFetcher.running = true

    Timer {
        interval: 900000 
        running: weatherRoot.visible
        repeat: true
        onTriggered: weatherFetcher.running = true
    }

    FontConfig { id: fc }

    Text {
        text: weatherRoot.weatherGlyph
        font.family: fc.iconFont
        font.pixelSize: 60
        color: "#ffffff"
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        
        Component.onCompleted: {
            fc.applyOutline(this, fc.overlayBackground)
        }
    }

    Text {
        text: weatherRoot.weatherTemp
        font.family: fc.mainFont
        font.pixelSize: 24
        font.weight: Font.Bold
        color: "#ffffff"
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        
        Component.onCompleted: {
            fc.applyOutline(this, fc.overlayBackground)
        }
    }

    Text {
        text: weatherRoot.weatherDesc
        font.family: fc.mainFont
        font.weight: Font.Bold
        font.pixelSize: 12
        color: fc.textMuted
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
       
        Component.onCompleted: {
            fc.applyOutline(this, fc.overlayBackground)
        }
    }
    Text {
        text: "Feels like " + weatherRoot.weatherFeelsLike
        font.family: fc.mainFont
        font.pixelSize: 12
        color: fc.textMuted
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        
        Component.onCompleted: {
            fc.applyOutline(this, fc.overlayBackground)
        }
    }

    Process {
        id: weatherFetcher
        command: ["curl", "-s", "https://wttr.is/?format=j1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    let current = data.current_condition[0];
                    weatherRoot.weatherTemp = current.temp_F + "°F";
                    weatherRoot.weatherFeelsLike = current.FeelsLikeF + "°F";
                    let code = current.weatherCode.toString();
                    let descMap = { "0": "Clear Sky", "1": "Mainly Clear", "2": "Partly Cloudy", "3": "Overcast", "45": "Foggy", "48": "Rime Fog", "51": "Light Drizzle", "53": "Moderate Drizzle", "55": "Dense Drizzle", "61": "Slight Rain", "63": "Moderate Rain", "65": "Heavy Rain", "71": "Light Snow", "73": "Moderate Snow", "75": "Heavy Snow", "80": "Light Showers", "85": "Light Snow Showers", "95": "Thunderstorm" };
                    let iconMap = { "0": "clear_day", "1": "partly_cloudy_day", "2": "partly_cloudy_day", "3": "cloudy", "45": "foggy", "48": "foggy", "51": "rainy", "53": "rainy", "55": "rainy", "61": "rainy", "63": "rainy", "65": "rainy", "71": "snowing", "73": "snowing", "75": "snowing", "80": "rainy", "85": "snowing", "95": "thunderstorm" };
                    weatherRoot.weatherDesc = descMap[code] || current.weatherDesc[0].value;
                    weatherRoot.weatherGlyph = iconMap[code] || "cloud";
                } catch(e) {}
                weatherFetcher.running = false;
            }
        }
    }
}
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#1c1f26" }
        Text {
            anchors.centerIn: parent
            color: "#3ecbff"
            font.pixelSize: 28
            text: "Welcome to Crude OS — Aqua"
        }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#1c1f26" }
        Text {
            anchors.centerIn: parent
            color: "#e6e6e6"
            font.pixelSize: 22
            text: "Lightweight. Alpine-based. Yours to edit."
        }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#1c1f26" }
        Text {
            anchors.centerIn: parent
            color: "#e6e6e6"
            font.pixelSize: 22
            text: "Setting things up — hang tight."
        }
    }
}

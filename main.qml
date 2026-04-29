import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield
import org.qgis
import QtCore
import Theme
import "qrc:/qml" as QFieldItems

Item {
    id: plugin

    property var canvas:                    iface.mapCanvas().mapSettings
    property var mainWindow:                iface.mainWindow()
    property var dashBoard:                 iface.findItemByObjectName('dashBoard')
    property var overlayFeatureFormDrawer:  iface.findItemByObjectName('overlayFeatureFormDrawer')
    property var positionSource:            iface.findItemByObjectName('positionSource')
    property var mapCanvas:                 iface.mapCanvas()
    property var featureListForm:           iface.findItemByObjectName('featureForm')

    Settings {
        id: appSettings
        category: "GeomlessPlugin"
        property string geomlessLayerName:          ""
        property bool   geomlessLongPressSettings:  true
        property int    geomlessShortPressAction:   0   // 0=geometryless, 1=GPS, 2=screen centre
        property real   geomlessRadiusM:            10  // metres — polygon radius / line length
        property int    geomlessPolyVertices:       16  // polygon approximation vertices (≥3)
        property real   geomlessLineBearing:        0   // grid bearing degrees, 0=N 90=E
    }

    ListModel { id: geomlessLayerPickerModel }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(geomlessButton)
        geomlessLongPressSettingsChk.checked = appSettings.geomlessLongPressSettings
        geomlessActionGroup.checkedButton    = [geomlessActionGeomless, geomlessActionGPS, geomlessActionScreen][appSettings.geomlessShortPressAction]
        geomlessRadiusField.text             = appSettings.geomlessRadiusM
        geomlessVerticesField.text           = appSettings.geomlessPolyVertices
        geomlessBearingField.text            = appSettings.geomlessLineBearing
    }

    // ── Toolbar button ────────────────────────────────────────────────────────
    QfToolButton {
        id: geomlessButton
        bgcolor: Theme.darkGray
        iconSource: Qt.resolvedUrl('geom-less.svg')
        round: true
        ToolTip.text: qsTr("Add point/line/polygon/non-geom feature")
        ToolTip.visible: hovered
        ToolTip.delay: 500

        onClicked: {
            var layer = resolveGeomlessLayer()
            if (!layer) {
                mainWindow.displayToast(qsTr('No editable layer found — opening setup'))
                settingsDialog.open()
                return
            }
            var action = appSettings.geomlessShortPressAction
            var geomType = (layer.geometryType && typeof layer.geometryType === 'function')
                           ? layer.geometryType() : -1

            if (action === 1) {
                if (!positionSource.active ||
                        !positionSource.positionInformation.latitudeValid ||
                        !positionSource.positionInformation.longitudeValid) {
                    gpsInactiveDialog.pendingLayer = layer
                    gpsInactiveDialog.open()
                    return
                }
            }

            var geometry
            if (action === 1) {
                var wgs84    = CoordinateReferenceSystemUtils.fromDescription("EPSG:4326")
                var gpsPoint = GeometryUtils.point(
                    positionSource.positionInformation.longitude,
                    positionSource.positionInformation.latitude)
                var layerPt  = GeometryUtils.reprojectPoint(gpsPoint, wgs84, layer.crs)
                geometry = GeometryUtils.createGeometryFromWkt(
                    wktForGeomType(geomType, layerPt.x, layerPt.y, layer.crs))
            } else if (action === 2) {
                var canvasPt = GeometryUtils.reprojectPoint(canvas.center,
                                   mapCanvas.mapSettings.destinationCrs, layer.crs)
                geometry = GeometryUtils.createGeometryFromWkt(
                    wktForGeomType(geomType, canvasPt.x, canvasPt.y, layer.crs))
            } else {
                geometry = GeometryUtils.createGeometryFromWkt('')
            }

            var feature = FeatureUtils.createFeature(layer, geometry)
            overlayFeatureFormDrawer.featureModel.currentLayer = layer
            overlayFeatureFormDrawer.featureModel.feature = feature
            overlayFeatureFormDrawer.state = "Add"
            overlayFeatureFormDrawer.open()
        }

        onPressAndHold: {
            if (appSettings.geomlessLongPressSettings) {
                settingsDialog.open()
            } else {
                veryLongPressTimer.start()
                var layer = resolveGeomlessLayer()
                if (!layer) { mainWindow.displayToast(qsTr('No editable layer found')); return }
                openGeomlessRecords(layer)
            }
        }

        onReleased: veryLongPressTimer.stop()
    }

    Timer {
        id: veryLongPressTimer
        interval: 1200
        repeat: false
        onTriggered: settingsDialog.open()
    }

    // ── Helper functions ──────────────────────────────────────────────────────
    function resolveGeomlessLayer() {
        var saved = appSettings.geomlessLayerName
        if (saved && saved !== "") {
            var found = qgisProject.mapLayersByName(saved)
            if (found && found.length > 0) return found[0]
            appSettings.geomlessLayerName = ""
        }
        return dashBoard.activeLayer
    }

    // Converts metres to CRS units at latitude cy.
    // Geographic: spherical approximation, ~0.5% error.
    // Projected: converts using actual map units (metres, feet, etc.).
    function mToCrs(crs, cy, metres) {
        if (crs && crs.isGeographic) {
            var latRad = cy * Math.PI / 180
            return { x: metres / (111320 * Math.cos(latRad)), y: metres / 111320 }
        }
        var crsUnits = metres
        try {
            var u = crs.mapUnits()
            if      (u === Qgis.DistanceUnit.Feet)              crsUnits = metres * 3.28084
            else if (u === Qgis.DistanceUnit.NauticalMiles)     crsUnits = metres / 1852
            else if (u === Qgis.DistanceUnit.Kilometers)        crsUnits = metres / 1000
            else if (u === Qgis.DistanceUnit.Yards)             crsUnits = metres * 1.09361
            else if (u === Qgis.DistanceUnit.Miles)             crsUnits = metres / 1609.344
            // Meters and unknown: pass through unchanged
        } catch (e) {}
        return { x: crsUnits, y: crsUnits }
    }

    // Builds WKT appropriate for the layer geometry type.
    // Point   → POINT at cx, cy
    // Line    → LINESTRING from (cx,cy) extending `geomlessRadiusM` metres
    //           in the grid bearing `geomlessLineBearing` (0=N, 90=E, clockwise)
    // Polygon → regular N-vertex polygon, radius `geomlessRadiusM` metres
    function wktForGeomType(geomType, cx, cy, crs) {
        if (geomType === Qgis.GeometryType.Line) {
            var len = appSettings.geomlessRadiusM
            var bearingRad = appSettings.geomlessLineBearing * Math.PI / 180
            var off1 = mToCrs(crs, cy, 1)
            var dx = len * Math.sin(bearingRad) * off1.x
            var dy = len * Math.cos(bearingRad) * off1.y
            return 'LINESTRING(' + cx + ' ' + cy + ', '
                                 + (cx + dx) + ' ' + (cy + dy) + ')'
        }
        if (geomType === Qgis.GeometryType.Polygon) {
            var r        = mToCrs(crs, cy, appSettings.geomlessRadiusM)
            var n        = Math.max(3, appSettings.geomlessPolyVertices)
            // rotate so first vertex points in the bearing direction
            // grid bearing (CW from N) → math angle (CCW from E)
            var startAngle = Math.PI / 2 - appSettings.geomlessLineBearing * Math.PI / 180
            var pts = []
            for (var i = 0; i <= n; i++) {
                var a = startAngle + (2 * Math.PI * i) / n
                pts.push((cx + r.x * Math.cos(a)) + ' ' + (cy + r.y * Math.sin(a)))
            }
            return 'POLYGON((' + pts.join(', ') + '))'
        }
        return 'POINT(' + cx + ' ' + cy + ')'
    }

    function openGeomlessRecords(layer) {
        if (!featureListForm) {
            mainWindow.displayToast(qsTr("Feature form not available — try reloading the project."))
            return
        }
        featureListForm.model.setFeatures(layer, '')
        Qt.callLater(function() {
            if (featureListForm.model.count === 0) {
                mainWindow.displayToast(qsTr("No records in layer."))
            } else if (featureListForm.model.count === 1) {
                featureListForm.selection.focusedItem = 0
                featureListForm.state = "FeatureFormEdit"
            } else {
                featureListForm.selection.focusedItem = 0
                featureListForm.state = "FeatureForm"
            }
        })
    }

    function populateGeomlessLayerModel() {
        geomlessLayerPickerModel.clear()
        var normal = [], priv = []
        try {
            var all = ProjectUtils.mapLayers(qgisProject)
            for (var id in all) {
                var lyr = all[id]
                try {
                    if (lyr && lyr.supportsEditing === true) {
                        var isPrivate = false
                        try { isPrivate = (lyr.flags & 8) !== 0 } catch (e2) {}
                        if (isPrivate) priv.push(lyr)
                        else normal.push(lyr)
                    }
                } catch (e) {}
            }
        } catch (e) {}
        normal.sort(function(a, b) { return a.name.localeCompare(b.name) })
        priv.sort(function(a, b) { return a.name.localeCompare(b.name) })
        geomlessLayerPickerModel.append({ "name": qsTr("Active Layer"), "isHeader": false })
        for (var i = 0; i < normal.length; i++)
            geomlessLayerPickerModel.append({ "name": normal[i].name, "isHeader": false })
        if (priv.length > 0) {
            geomlessLayerPickerModel.append({ "name": qsTr("— Private Layers —"), "isHeader": true })
            for (var j = 0; j < priv.length; j++)
                geomlessLayerPickerModel.append({ "name": priv[j].name, "isHeader": false })
        }
        // Restore saved selection
        var saved = appSettings.geomlessLayerName
        var found = false
        for (var k = 0; k < geomlessLayerPickerModel.count; k++) {
            if (geomlessLayerPickerModel.get(k).name === saved) {
                geomlessLayerDropdown.currentIndex = k
                found = true
                break
            }
        }
        if (!found) geomlessLayerDropdown.currentIndex = 0
    }

    // ── GPS inactive confirmation dialog ──────────────────────────────────────
    Dialog {
        id: gpsInactiveDialog
        parent: mainWindow.contentItem
        modal: true
        width: Math.min(320, mainWindow.width - 32)
        font: Theme.defaultFont
        x: (mainWindow.width - width) / 2
        y: (mainWindow.height - height) * 0.25

        property var pendingLayer: null

        title: qsTr("GPS Inactive")
        standardButtons: Dialog.Yes | Dialog.No

        Label {
            width: parent.width
            text: qsTr("GPS is not active or has no valid position.\nAdd a geometryless feature instead?")
            wrapMode: Text.WordWrap
            font: Theme.defaultFont
        }

        onAccepted: {
            if (!pendingLayer) return
            var geometry = GeometryUtils.createGeometryFromWkt('')
            var feature  = FeatureUtils.createFeature(pendingLayer, geometry)
            overlayFeatureFormDrawer.featureModel.currentLayer = pendingLayer
            overlayFeatureFormDrawer.featureModel.feature = feature
            overlayFeatureFormDrawer.state = "Add"
            overlayFeatureFormDrawer.open()
        }
    }

    // ── Settings dialog ───────────────────────────────────────────────────────
    Dialog {
        id: settingsDialog
        parent: mainWindow.contentItem
        modal: true
        width: Math.min(360, mainWindow.width - 16)
        height: Math.min(520, mainWindow.height - 32)
        font: Theme.defaultFont
        x: (mainWindow.width  - width)  / 2
        y: (mainWindow.height - height) * 0.15

        title: qsTr("Add Geometryless Feature")
        standardButtons: Dialog.NoButton

        onOpened: populateGeomlessLayerModel()

        ScrollView {
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth

            Column {
                width: parent.width
                padding: 8
                spacing: 6

                Label { text: qsTr("Target layer:"); font.pixelSize: 10 }
                ComboBox {
                    id: geomlessLayerDropdown
                    width: parent.width - 16
                    model: geomlessLayerPickerModel
                    textRole: "name"
                    onActivated: {
                        var item = geomlessLayerPickerModel.get(currentIndex)
                        if (item.isHeader) { currentIndex = Math.max(0, currentIndex - 1); return }
                        appSettings.geomlessLayerName = (currentIndex === 0) ? "" : item.name
                    }
                    delegate: ItemDelegate {
                        width: geomlessLayerDropdown.width
                        enabled: !model.isHeader
                        contentItem: Text {
                            text: model.name
                            font.italic: model.isHeader
                            color: model.isHeader ? "#888888" : (highlighted ? "#ffffff" : "#000000")
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: model.isHeader ? 4 : 12
                        }
                        highlighted: geomlessLayerDropdown.highlightedIndex === index
                    }
                }

                Button {
                    text: qsTr("Reset to active layer")
                    font.pixelSize: 9
                    onClicked: {
                        appSettings.geomlessLayerName = ""
                        populateGeomlessLayerModel()
                    }
                }

                Label {
                    visible: geomlessLayerDropdown.currentIndex === 0
                    width: parent.width - 16
                    text: qsTr("Without an explicit selection the active layer will be used.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 9
                    color: "#666666"
                }

                Rectangle { width: parent.width; height: 1; color: "#cccccc" }
                Item { width: 1; height: 4 }

                Label { text: qsTr("Short-press action"); font.pixelSize: 10; font.bold: true }
                Item  { width: 1; height: 2 }

                ButtonGroup { id: geomlessActionGroup }
                RadioButton {
                    id: geomlessActionGeomless
                    text: qsTr("Create geometryless feature (all layers)")
                    font.pixelSize: 9; implicitHeight: 28
                    ButtonGroup.group: geomlessActionGroup
                    checked: appSettings.geomlessShortPressAction === 0
                    onCheckedChanged: if (checked) appSettings.geomlessShortPressAction = 0
                }
                RadioButton {
                    id: geomlessActionGPS
                    text: qsTr("Create feature at GPS location (point/line/polygon)")
                    font.pixelSize: 9; implicitHeight: 28
                    ButtonGroup.group: geomlessActionGroup
                    checked: appSettings.geomlessShortPressAction === 1
                    onCheckedChanged: if (checked) appSettings.geomlessShortPressAction = 1
                }
                RadioButton {
                    id: geomlessActionScreen
                    text: qsTr("Create feature at screen centre (point/line/polygon)")
                    font.pixelSize: 9; implicitHeight: 28
                    ButtonGroup.group: geomlessActionGroup
                    checked: appSettings.geomlessShortPressAction === 2
                    onCheckedChanged: if (checked) appSettings.geomlessShortPressAction = 2
                }

                Label {
                    width: parent.width - 16
                    text: qsTr("Point: point at location. Line: line from location in set direction. Polygon: circle around location.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 9
                    color: "#666666"
                }

                Rectangle { width: parent.width; height: 1; color: "#cccccc" }
                Item { width: 1; height: 4 }

                Label { text: qsTr("Shape settings"); font.pixelSize: 10; font.bold: true }
                Item  { width: 1; height: 2 }

                RowLayout {
                    width: parent.width - 16
                    Label { text: qsTr("Radius / length (m):"); font.pixelSize: 9; Layout.fillWidth: true }
                    TextField {
                        id: geomlessRadiusField
                        implicitWidth: 64; implicitHeight: 28
                        font.pixelSize: 9
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        text: appSettings.geomlessRadiusM
                        onEditingFinished: {
                            var v = parseFloat(text)
                            if (!isNaN(v) && v > 0) appSettings.geomlessRadiusM = v
                            else text = appSettings.geomlessRadiusM
                        }
                    }
                }

                RowLayout {
                    width: parent.width - 16
                    Label { text: qsTr("Polygon vertices (≥3):"); font.pixelSize: 9; Layout.fillWidth: true }
                    TextField {
                        id: geomlessVerticesField
                        implicitWidth: 64; implicitHeight: 28
                        font.pixelSize: 9
                        inputMethodHints: Qt.ImhDigitsOnly
                        text: appSettings.geomlessPolyVertices
                        onEditingFinished: {
                            var v = parseInt(text)
                            if (!isNaN(v) && v >= 3) appSettings.geomlessPolyVertices = v
                            else text = appSettings.geomlessPolyVertices
                        }
                    }
                }

                RowLayout {
                    width: parent.width - 16
                    Label { text: qsTr("Line bearing (° 0=N 90=E):"); font.pixelSize: 9; Layout.fillWidth: true }
                    TextField {
                        id: geomlessBearingField
                        implicitWidth: 64; implicitHeight: 28
                        font.pixelSize: 9
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        text: appSettings.geomlessLineBearing
                        onEditingFinished: {
                            var v = parseFloat(text) % 360
                            if (v < 0) v += 360
                            if (!isNaN(v)) { appSettings.geomlessLineBearing = v; text = v }
                            else text = appSettings.geomlessLineBearing
                        }
                    }
                }

                Label {
                    width: parent.width - 16
                    text: qsTr("Bearing is grid north (map north). For geographic CRS this equals true north. Magnetic north requires a separate declination correction.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 9
                    color: "#666666"
                }

                Rectangle { width: parent.width; height: 1; color: "#cccccc" }
                Item { width: 1; height: 4 }

                Label { text: qsTr("Long-press action"); font.pixelSize: 10; font.bold: true }
                Item  { width: 1; height: 2 }

                CheckBox {
                    id: geomlessLongPressSettingsChk
                    text: qsTr("Open settings on long press")
                    font.pixelSize: 9; implicitHeight: 28
                    checked: appSettings.geomlessLongPressSettings
                    onCheckedChanged: appSettings.geomlessLongPressSettings = checked
                }

                Label {
                    width: parent.width - 16
                    text: checked
                          ? qsTr("Long press opens this settings dialog.")
                          : qsTr("Long press opens the first record, or the feature list if there are multiple. Keep holding (~2 seconds) to open settings.")
                    property bool checked: geomlessLongPressSettingsChk.checked
                    wrapMode: Text.WordWrap
                    font.pixelSize: 9
                    color: "#666666"
                }
            }
        }
    }
}

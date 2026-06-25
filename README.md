# LightMapz

Flutter-MVP fuer eine Fahrrad-Routenplaner-App. Die App implementiert bewusst
keine Routing-Engine, sondern spricht nur mit einem austauschbaren
`RoutingService`.

## Starten mit einem Befehl

Backend und Flutter-App gemeinsam starten:

```sh
./scripts/start_dev.sh
```

Unter Windows:

```powershell
.\scripts\start_dev.ps1
```

Das Skript startet zuerst das lokale Routing-Backend auf
`http://127.0.0.1:3000`, wartet auf `/health` und startet danach die
Flutter-App auf macOS. Auf macOS wird eine Debug-App gebaut und geoeffnet;
wenn du das App-Fenster schliesst, stoppt das Skript auch das Backend.
Das PowerShell-Skript startet die App als Flutter-Webserver unter
`http://127.0.0.1:8081`.

Falls du ein anderes Geraet verwenden willst:

```sh
FLUTTER_DEVICE=ios ./scripts/start_dev.sh
FLUTTER_DEVICE=android ./scripts/start_dev.sh
```

## Manuell starten

Falls dieses Repository noch keine Flutter-Plattformordner enthaelt, zuerst
Flutter installieren und die iOS-/Android-Runner erzeugen:

```sh
flutter create . --platforms=ios,android
```

Danach:

```sh
flutter pub get
flutter run
```

Die App nutzt standardmaessig das lokale Backend unter
`http://127.0.0.1:3000`. Starte deshalb zuerst das Backend oder nutze direkt
`./scripts/start_dev.sh`.

## Tests

```sh
flutter test
```

Die Tests decken Models, Routing-Services, Controller, Widgets, Map-Renderer
und den Route-Planner-Screen ab.

## Backend-Prototyp

Der Routing-Backend-Prototyp liegt in `backend/`.

```sh
./scripts/run_backend.sh
```

Die Flutter-App nutzt lokal `http://127.0.0.1:3000`.

Endpoints:

- `GET /geocode?q=Adresse`
- `POST /route`

Das Backend verwendet fuer Adresssuche Nominatim und fuer Fahrrad-Routing
BRouter. Dadurch wird die Route nicht mehr als gerade Mock-Linie erzeugt,
sondern anhand echter OpenStreetMap-Wege berechnet.

Details stehen in `backend/README.md`.

## Frontend ohne Xcode starten

Wenn `flutter run` auf macOS mit `xcodebuild requires Xcode` scheitert, fehlt
die vollstaendige Xcode-App. Zum schnellen Testen im Browser:

```sh
./scripts/run_frontend_web.sh
```

Danach `http://127.0.0.1:8081` im Browser oeffnen.

## Frontend mit echtem Routing starten

Terminal 1:

```sh
./scripts/run_backend.sh
```

Terminal 2:

```sh
flutter run -d macos
```

Dann Start- und Zieladresse eingeben und `Route berechnen` druecken.

## Architektur

Die UI ruft kein HTTP direkt auf. Der Ablauf ist:

`RoutePlannerPage` -> `RoutePlannerController` -> `GeocodingService` /
`RoutingService`

Aktuelle Implementierungen:

- `MockRoutingService`: erzeugt eine Beispielroute und Beispielstatistiken.
- `HttpRoutingService`: ruft das lokale Backend per `POST /route` auf.
- `HttpGeocodingService`: ruft das lokale Backend per `GET /geocode` auf.

Um spaeter ein anderes Backend zu verwenden, in `lib/app.dart` die Base-URL
austauschen:

```dart
home: RoutePlannerPage(
  routingService: HttpRoutingService(
    baseUrl: Uri.parse('https://dein-backend.example'),
  ),
  geocodingService: HttpGeocodingService(
    baseUrl: Uri.parse('https://dein-backend.example'),
  ),
),
```

## Backend-Vertrag

`HttpRoutingService` sendet:

```json
{
  "start": { "lat": 51.2277, "lng": 6.7735 },
  "destination": { "lat": 51.4508, "lng": 7.0131 },
  "profile": "bike",
  "roadAvoidanceStrictness": 75
}
```

Er erwartet:

```json
{
  "geometry": [
    { "lat": 51.2277, "lng": 6.7735 },
    { "lat": 51.25, "lng": 6.8 },
    { "lat": 51.4508, "lng": 7.0131 }
  ],
  "distanceMeters": 42100,
  "durationSeconds": 10800,
  "roadSharePercent": 8.5,
  "cyclewaySharePercent": 71.2,
  "pathSharePercent": 20.3,
  "warnings": [
    "Eine komplett straßenfreie Route wurde nicht gefunden."
  ],
  "segments": [
    {
      "distanceMeters": 1200,
      "surface": "asphalt",
      "wayType": "cycleway",
      "roadClass": "cycleway"
    }
  ]
}
```

## Karte und OpenStreetMap

`lib/map/map_view.dart` nutzt jetzt OpenStreetMap-Kartendaten ueber
`flutter_map`. OpenStreetMap ist das offene Kartenprojekt, in dem Strassen,
Waldwege, Tracks, Pfade, Radwege und viele weitere Wegtypen gepflegt werden.

Der MVP verwendet OSM-Rastertiles:

```txt
https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

Fuer Entwicklung und Tests ist das praktisch. Fuer eine produktive App solltest
du aber die OpenStreetMap Tile Usage Policy beachten und besser einen eigenen
Tile-Server oder einen passenden OSM-basierten Tile-Provider verwenden.

Die App-Abstraktion bleibt gleich: `RoutePlannerPage` uebergibt nur `start`,
`destination` und `routeGeometry` an `MapView`. Spaeter kann `MapView` intern
weiter auf MapLibre, Vektor-Tiles oder einen eigenen Tile-Server umgestellt
werden.

## Road-Avoidance

Der Slider schreibt `roadAvoidanceStrictness` von `0` bis `100` in
`RouteRequest`. Die echte Uebersetzung in Routing-Regeln gehoert ins Backend,
zum Beispiel:

- BRouter: Auswahl oder Parametrisierung eines Fahrradprofils.
- GraphHopper: Custom Model mit hoeheren Kosten fuer grosse Strassen.
- Eigener Service: Mapping von `0/25/50/75/100` auf mehrere gewichtete Regeln.

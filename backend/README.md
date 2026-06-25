# LightMapz Routing Backend

Ein kleiner Node.js/TypeScript/Fastify-Prototyp fuer den Endpoint `POST /route`.
Aktuell nutzt der Server `MockRoutingEngine`. Die Architektur ist darauf
vorbereitet, spaeter zwischen GraphHopper und BRouter zu wechseln.

## Starten

```sh
cd backend
npm install
npm run dev
```

Der Server startet standardmaessig auf `http://localhost:3000`.

```sh
curl -X POST http://localhost:3000/route \
  -H "content-type: application/json" \
  -d '{
    "start": { "lat": 51.2277, "lng": 6.7735 },
    "destination": { "lat": 51.4508, "lng": 7.0131 },
    "profile": "bike",
    "roadAvoidanceStrictness": 75
  }'
```

## Scripts

```sh
npm run dev
npm run build
npm test
```

## Routing Engines

Die Route `POST /route` kennt nur das Interface `RoutingEngine`.

- `MockRoutingEngine`: liefert sofort nutzbare Demo-Routen.
- `GraphHopperRoutingEngine`: Platzhalter fuer GraphHopper.
- `BRouterRoutingEngine`: Platzhalter fuer BRouter.

Auswahl per Environment:

```sh
ROUTING_ENGINE=mock npm run dev
ROUTING_ENGINE=graphhopper npm run dev
ROUTING_ENGINE=brouter npm run dev
```

`brouter` ist aktuell der Standard und ruft den BRouter-Webservice auf. Dadurch
werden echte OpenStreetMap-Wege verwendet. `mock` bleibt fuer Tests und
Offline-Entwicklung erhalten. `graphhopper` ist weiterhin ein Platzhalter.

## Geocoding

```sh
curl 'http://localhost:3000/geocode?q=D%C3%BCsseldorf%20Hauptbahnhof'
```

Das Backend nutzt Nominatim fuer Adresssuche. Fuer produktive Nutzung solltest
du einen eigenen Nominatim-Server oder einen passenden Geocoding-Provider
einplanen und die Nominatim Usage Policy beachten.

## RoutingProfileMapper

`src/profile/routing-profile-mapper.ts` uebersetzt
`roadAvoidanceStrictness` in vorbereitete Regeln:

- GraphHopper Custom Model: `priority`-Regeln fuer Strassenklassen.
- BRouter Profile: `bike_normal`, `bike_quiet`, `bike_low_traffic`,
  `bike_avoid_roads`, `bike_extreme_avoid_roads`.

Spaeter kann GraphHopper die `graphHopperCustomModel`-Regeln direkt in den
Request uebernehmen. BRouter kann `brouterProfile` nutzen, um ein `.brf` Profil
oder Profilvariablen auszuwaehlen.

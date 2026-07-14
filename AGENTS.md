# Routing issue log

## Working rule

For the route between `Kohlmeisenweg 18, 58507 Lüdenscheid` and
`Homertturm, 58518 Lüdenscheid`, document every routing-related change,
experiment, result, and remaining uncertainty in this file. Do not claim that
a routing change is live until it has been checked through the backend process
used by the running app.

## Goal

At road-avoidance level `100`, the route should make a meaningful westward
detour through suitable tracks/paths, approximately like the blue reference
line supplied by the user. It must not fall back to the short eastern route
through Luedenscheid.

## Baseline

- Start: `51.2353988, 7.6236621`
- Destination: `51.1777624, 7.6447800`
- Undesired result shown in the latest screenshot: `9.8 km`, about `24.1 %`
  road share, geometry remains east of the desired corridor.

## Experiments and findings

1. **Very wide Overpass search (60 km default)**
   - Result: the external path search often returns no useful candidates or
     takes too long; BRouter then selects the direct `9.8 km` route.
   - Conclusion: unsuitable as the default for this short route.

2. **Source-level bounded track/path search**
   - Changed the default search radius to `10 km`, queried only
     `track|cycleway|path|bridleway`, limited candidate combinations, and
     preferred a viable mapped greenway corridor at strictness `100`.
   - Direct check against the edited TypeScript source produced a westward
     result: `14.081 km`, `76.47 %` path/track share, western bound
     `7.582443` longitude.
   - Conclusion: the revised source can produce a route in the requested
     direction.

3. **Running app still shows the old route**
   - Observation from the latest screenshot: the app continues to show the
     old `9.8 km` route.
   - Process inspection found the macOS app running with `node dist/server.js`.
     Source edits in `backend/src` are not used by that already-built process.
   - Next action: rebuild `backend/dist`, restart the backend process used by
     the app, then re-run the default route through the app/backend endpoint.

4. **Large slider values reproduce the failure**
   - Reproduced against the backend process serving the running app:
     - `10 km` -> `14.081 km`, `19.5 %` road share, western bound `7.582443`.
     - `90 km` -> old `9.769 km` route, western bound `7.620699`.
     - `150 km` -> old `9.769 km` route, western bound `7.620699`.
   - Cause: large Overpass bounding boxes do not produce usable field-way
     candidates, so the engine falls back to the direct BRouter alternatives.
   - Fix: the UI restricts this *search radius* to `5–12 km`; the backend
     accepts legacy values up to `150 km` but caps its actual Overpass query at
     `12 km`. The desired westward corridor is within that range, and a
     currently running older app cannot reintroduce the fallback.

5. **Deployment verification (current backend on port 3000)**
   - Rebuilt `backend/dist` and restarted the process serving the running app.
   - Confirmed through that endpoint that all of `10 km`, `90 km`, and
     `150 km` now return the same westward result: `14.081 km`, `19.5 %` road
     share, `76.5 %` path/track share, western bound `7.582443`.
   - The already-open app can keep its old slider value temporarily; pressing
     **Route berechnen** now uses the compatibility cap in the restarted
     backend. A future app rebuild also exposes the new `5–12 km` slider range.

6. **Minimum field-way share control**
   - Requirement added: at maximum road avoidance, the user can specify a
     minimum desired percentage of field/forest ways.
   - Implementation: the UI sends `minimumFieldWaySharePercent` (default
     `60 %`); the backend evaluates actual `track|path|bridleway` metres, not
     merely the broader displayed path share.
   - Selection behavior: routes meeting the requested threshold are preferred.
     If none exists, the best usable mapped greenway route is retained and a
     warning states the requested and achieved percentage.
   - Live endpoint check after this change: the external services returned no
     usable mapped corridor at that moment, so the fallback route contained
     `59.4 %` field ways. Requests for `60 %` and `90 %` correctly returned a
     warning instead of pretending the constraint had been met. This confirms
     the control's fallback behavior; it does not make external Overpass data
     availability deterministic.
   - Rebuilt and reopened the macOS app after the change; the slider is now
     available in the maximum-avoidance section of the running app.

7. **Detour-size control did not change the selected route**
   - Observation from the newest screenshot: even at the maximum value, the
     route still used the central/eastern corridor instead of the blue
     westward reference corridor. The route length changed only slightly.
   - Root cause: `greenwayDetourRadiusKm` previously affected only the
     Overpass bounding box. Values below `10 km` were also normalized to the
     same `10 km` query size. The candidate scoring used a fixed lateral target
     derived from the direct distance, so it could select the same intermediate
     points and the same BRouter route for every slider value.
   - Change: the control is now labelled **Gewünschte Umweggröße**. Its value
     defines the preferred lateral deviation (`5 km` targets about `2.5 km`,
     `12 km` targets up to `6 km` from the direct corridor), affects candidate
     selection, final route ranking, and the maximum accepted route length.
     The bounded Overpass query remains in place for reliability.
   - Regression test: two equally field-way-heavy corridors at different
     lateral distances are supplied by a stub. A `5 km` request selects the
     near corridor; a `12 km` request selects the farther-west corridor.
   - Verification: `cd backend && npm test && npm run build` passes (24 tests);
     the focused Flutter test suite passes (26 tests). A live external check is
     still required after restarting the backend process used by the app,
     because Overpass/BRouter results vary with current external data and
     availability.

8. **Live check after activating the detour-size implementation**
   - Rebuilt the backend and restarted the process serving port `3000`.
   - The same default endpoints now produce measurably different routes:
     - `5 km`: `13.050 km`, western-most longitude `7.595250`, `67.8 %`
       field/forest way share.
     - `12 km`: `18.043 km`, western-most longitude `7.554549`, `70.8 %`
       field/forest way share.
   - Interpretation: the maximum setting now genuinely leaves the direct city
     corridor and searches a substantially farther-west field-way corridor.
     The exact geometry remains dependent on the live OSM and BRouter data;
     the `100 %` field-way goal was not geographically achievable in this
     response and is correctly reported as `70 %` rather than misrepresented.

9. **Automatic field-way corridor anchors**
   - New observation: a manually inserted waypoint west of the start produced
     a `19.6 km` route with `80.6 %` path/track share. This is materially
     better than the automatic maximum-detour result and demonstrates that a
     waypoint at the *entry* to a field-way corridor can be more important
     than a waypoint in its middle.
   - Cause in the automatic search: its six one-waypoint attempts were simply
     the globally highest-scoring OSM path/track centres. Several centres in
     one middle section could consume all attempts, leaving the corridor entry
     untested.
   - Change: at strictness `100`, the automatic search now reserves one
     one-waypoint BRouter request for the entry, middle and exit of each side
     of the direct route. These internal anchors behave like automatically
     created manual waypoints; BRouter still calculates the complete route and
     the existing ranking selects the route with the best actual field-way
     share.
   - Guardrail: the six distributed anchors are supplemented by the six
     previously strongest global candidates. This prevents a sparse corridor
     entry/exit distribution from discarding a previously viable mapped route;
     the one-waypoint request budget is bounded at twelve.
   - Regression test: six more attractive middle candidates no longer hide a
     lower-scoring corridor-entry candidate. The entry is tried automatically
     and its `100 %` path/track result wins. `npm test && npm run build` passes
     with 25 backend tests.

10. **Inner corridor-entry alternatives**
    - Live check after the first anchor change: the route returned to the
      stable westward result (`18.043 km`, `70.8 %` path/track) once all former
      strong candidates were retained, but it still did not reach the manual
      waypoint's `80.6 %` share.
    - Hypothesis: the maximum detour target favours anchors about `6 km` from
      the direct line. The manual waypoint demonstrates that entering a nearer
      field-way corridor first can create a better complete route.
    - Change: for each side, the automatic search now also tries an early
      anchor targeted at about `65 %` of the selected lateral detour (capped at
      `2–4 km`). It retains the large-detour candidates and the global top six,
      then ranks the resulting BRouter routes by actual field-way share.
    - Cost: at most two extra BRouter requests at the maximum level; the
      one-waypoint plan budget is now at most fourteen. Backend tests still
      pass (25).
    - Live check: the immediate external request again returned BRouter's
      direct fallback (`9.769 km`, `59 %` field-way share), even though a
      direct Overpass query returned `12,810` usable path/track objects in the
      same bounding box. This is an intermittent external candidate/route
      availability issue, not proof that the `80.6 %` manual result has been
      automatically reproduced. Keep manual waypoints available as the
      explicit reliable override while further live route diagnostics are
      added.

## Regression coverage

- `backend/test/brouter-routing-engine.test.ts` includes a test that requires a
  viable westward mapped greenway corridor to be selected at maximum avoidance.

## Verification checklist

1. Build the backend with `cd backend && npm run build`.
2. Restart the backend actually serving `http://127.0.0.1:3000`.
3. Calculate the default route at strictness `100` in the app.
4. Record distance, road/path shares, and the western-most longitude here.

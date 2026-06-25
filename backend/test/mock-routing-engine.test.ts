import assert from "node:assert/strict";
import test from "node:test";
import { MockRoutingEngine } from "../src/engines/mock-routing-engine.js";
import type { RouteRequest } from "../src/models/route.js";
import { RoutingProfileMapper } from "../src/profile/routing-profile-mapper.js";

const request: RouteRequest = {
  start: { lat: 51.2277, lng: 6.7735 },
  destination: { lat: 51.4508, lng: 7.0131 },
  waypoints: [],
  profile: "bike",
  roadAvoidanceStrictness: 50,
  preferForestWays: false,
};

test("MockRoutingEngine returns a route compatible with the mobile contract", async () => {
  const mapper = new RoutingProfileMapper();
  const engine = new MockRoutingEngine();

  const result = await engine.calculateRoute(request, {
    profileRules: mapper.mapRoadAvoidanceStrictness(50),
  });

  assert.deepEqual(result.geometry[0], request.start);
  assert.deepEqual(result.geometry.at(-1), request.destination);
  assert.ok(result.distanceMeters > 0);
  assert.ok(result.durationSeconds > 0);
  assert.equal(result.segments.length, 3);
  assert.equal(
    Math.round(
      result.roadSharePercent +
        result.cyclewaySharePercent +
        result.pathSharePercent,
    ),
    100,
  );
});

test("MockRoutingEngine routes through waypoints", async () => {
  const mapper = new RoutingProfileMapper();
  const engine = new MockRoutingEngine();
  const requestWithWaypoint: RouteRequest = {
    ...request,
    waypoints: [{ lat: 51.3, lng: 6.9 }],
  };

  const result = await engine.calculateRoute(requestWithWaypoint, {
    profileRules: mapper.mapRoadAvoidanceStrictness(50),
  });

  assert.deepEqual(result.geometry[0], requestWithWaypoint.start);
  assert.ok(
    result.geometry.some((point) => point.lat === 51.3 && point.lng === 6.9),
  );
  assert.deepEqual(result.geometry.at(-1), requestWithWaypoint.destination);
});

test("MockRoutingEngine makes stricter routes longer and less road-heavy", async () => {
  const mapper = new RoutingProfileMapper();
  const engine = new MockRoutingEngine();

  const relaxed = await engine.calculateRoute(request, {
    profileRules: mapper.mapRoadAvoidanceStrictness(0),
  });
  const strict = await engine.calculateRoute(request, {
    profileRules: mapper.mapRoadAvoidanceStrictness(100),
  });

  assert.ok(strict.distanceMeters > relaxed.distanceMeters);
  assert.ok(strict.roadSharePercent < relaxed.roadSharePercent);
});

import assert from "node:assert/strict";
import test from "node:test";
import { buildApp } from "../src/app.js";
import { MockRoutingEngine } from "../src/engines/mock-routing-engine.js";

test("POST /route returns a route result", async () => {
  const app = await buildApp({
    routingEngine: new MockRoutingEngine(),
    logger: false,
  });

  const response = await app.inject({
    method: "POST",
    url: "/route",
    payload: {
      start: { lat: 51.2277, lng: 6.7735 },
      destination: { lat: 51.4508, lng: 7.0131 },
      profile: "bike",
      roadAvoidanceStrictness: 75,
      preferForestWays: true,
    },
  });

  await app.close();

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.deepEqual(body.geometry[0], { lat: 51.2277, lng: 6.7735 });
  assert.deepEqual(body.geometry.at(-1), { lat: 51.4508, lng: 7.0131 });
  assert.ok(body.distanceMeters > 0);
  assert.ok(body.durationSeconds > 0);
  assert.equal(typeof body.roadSharePercent, "number");
  assert.equal(typeof body.cyclewaySharePercent, "number");
  assert.equal(typeof body.pathSharePercent, "number");
  assert.ok(Array.isArray(body.warnings));
  assert.ok(Array.isArray(body.segments));
});

test("POST /route validates request body", async () => {
  const app = await buildApp({
    routingEngine: new MockRoutingEngine(),
    logger: false,
  });

  const response = await app.inject({
    method: "POST",
    url: "/route",
    payload: {
      start: { lat: 99, lng: 6.7735 },
      destination: { lat: 51.4508, lng: 7.0131 },
      profile: "car",
      roadAvoidanceStrictness: 150,
      preferForestWays: "yes",
    },
  });

  await app.close();

  assert.equal(response.statusCode, 400);
  assert.deepEqual(response.json().error, "Invalid route request");
});

test("GET /health returns ok", async () => {
  const app = await buildApp({
    routingEngine: new MockRoutingEngine(),
    logger: false,
  });

  const response = await app.inject({
    method: "GET",
    url: "/health",
  });

  await app.close();

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), { status: "ok" });
});

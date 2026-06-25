import assert from "node:assert/strict";
import test from "node:test";
import { buildApp } from "../src/app.js";
import { MockRoutingEngine } from "../src/engines/mock-routing-engine.js";
import type { GeocodingService } from "../src/geocoding/geocoding-service.js";

test("GET /geocode returns address matches", async () => {
  const app = await buildApp({
    routingEngine: new MockRoutingEngine(),
    geocodingService: new FakeGeocodingService(),
    logger: false,
  });

  const response = await app.inject({
    method: "GET",
    url: "/geocode?q=D%C3%BCsseldorf%20Hbf",
  });

  await app.close();

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), {
    results: [
      {
        label: "Düsseldorf Hauptbahnhof",
        point: { lat: 51.219, lng: 6.794 },
      },
    ],
  });
});

test("GET /geocode validates query", async () => {
  const app = await buildApp({
    routingEngine: new MockRoutingEngine(),
    geocodingService: new FakeGeocodingService(),
    logger: false,
  });

  const response = await app.inject({
    method: "GET",
    url: "/geocode?q=a",
  });

  await app.close();

  assert.equal(response.statusCode, 400);
});

class FakeGeocodingService implements GeocodingService {
  async search() {
    return [
      {
        label: "Düsseldorf Hauptbahnhof",
        point: { lat: 51.219, lng: 6.794 },
      },
    ];
  }
}

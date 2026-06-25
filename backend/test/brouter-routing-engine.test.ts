import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import test from "node:test";
import { BRouterRoutingEngine } from "../src/engines/brouter-routing-engine.js";
import type { RouteRequest } from "../src/models/route.js";
import { RoutingProfileMapper } from "../src/profile/routing-profile-mapper.js";

const request: RouteRequest = {
  start: { lat: 51.2277, lng: 6.7735 },
  destination: { lat: 51.4508, lng: 7.0131 },
  profile: "bike",
  roadAvoidanceStrictness: 50,
};

test("BRouterRoutingEngine parses a real-way GeoJSON route", async () => {
  const { server, baseUrl, requests } = await createBRouterStub();
  const engine = new BRouterRoutingEngine(baseUrl);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(request, {
      profileRules: mapper.mapRoadAvoidanceStrictness(50),
    });

    assert.equal(requests[0].searchParams.get("profile"), "safety");
    assert.equal(result.geometry.length, 3);
    assert.deepEqual(result.geometry[0], { lat: 51.2277, lng: 6.7735 });
    assert.equal(result.distanceMeters, 3000);
    assert.equal(result.durationSeconds, 900);
    assert.equal(result.segments.length, 3);
    assert.equal(Math.round(result.cyclewaySharePercent), 33);
    assert.equal(Math.round(result.pathSharePercent), 33);
    assert.equal(Math.round(result.roadSharePercent), 33);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

async function createBRouterStub(): Promise<{
  server: Server;
  baseUrl: string;
  requests: URL[];
}> {
  const requests: URL[] = [];
  const server = createServer((request, response) => {
    requests.push(new URL(request.url ?? "/", "http://127.0.0.1"));
    response.setHeader("content-type", "application/vnd.geo+json");
    response.end(
      JSON.stringify({
        type: "FeatureCollection",
        features: [
          {
            type: "Feature",
            properties: {
              "track-length": "3000",
              "total-time": "900",
              messages: [
                [
                  "Longitude",
                  "Latitude",
                  "Elevation",
                  "Distance",
                  "CostPerKm",
                  "ElevCost",
                  "TurnCost",
                  "NodeCost",
                  "InitialCost",
                  "WayTags",
                ],
                [
                  "0",
                  "0",
                  "0",
                  "1000",
                  "0",
                  "0",
                  "0",
                  "0",
                  "0",
                  "highway=cycleway surface=asphalt",
                ],
                [
                  "0",
                  "0",
                  "0",
                  "1000",
                  "0",
                  "0",
                  "0",
                  "0",
                  "0",
                  "highway=path surface=gravel bicycle=yes",
                ],
                [
                  "0",
                  "0",
                  "0",
                  "1000",
                  "0",
                  "0",
                  "0",
                  "0",
                  "0",
                  "highway=residential surface=asphalt",
                ],
              ],
            },
            geometry: {
              type: "LineString",
              coordinates: [
                [6.7735, 51.2277, 34],
                [6.8, 51.25, 35],
                [7.0131, 51.4508, 43],
              ],
            },
          },
        ],
      }),
    );
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();

  if (address === null || typeof address === "string") {
    throw new Error("Could not start BRouter stub.");
  }

  return {
    server,
    baseUrl: `http://127.0.0.1:${address.port}/brouter`,
    requests,
  };
}

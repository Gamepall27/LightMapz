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
  preferForestWays: false,
};

test("BRouterRoutingEngine parses a real-way GeoJSON route", async () => {
  const { server, baseUrl, requests } = await createBRouterStub();
  const engine = new BRouterRoutingEngine(baseUrl, null);
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

test("BRouterRoutingEngine chooses a longer low-road route for extreme avoidance", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const alternativeIdx = url.searchParams.get("alternativeidx");

      if (profile === "safety" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 9000,
          durationSeconds: 2400,
          wayTags: [
            "highway=cycleway surface=asphalt",
            "highway=track surface=gravel bicycle=yes",
            "highway=path surface=compacted bicycle=yes",
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 3000,
        durationSeconds: 900,
        wayTags: [
          "highway=primary surface=asphalt",
          "highway=secondary surface=asphalt",
          "highway=residential surface=asphalt",
        ],
      });
    },
  });
  const engine = new BRouterRoutingEngine(baseUrl, null);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(request, {
      profileRules: mapper.mapRoadAvoidanceStrictness(100),
    });
    assert.ok(
      requests.some((url) => {
        return (
          url.searchParams.get("profile") === "safety" &&
          url.searchParams.get("alternativeidx") === "1"
        );
      }),
    );
    assert.equal(result.distanceMeters, 9000);
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.cyclewaySharePercent), 33);
    assert.equal(Math.round(result.pathSharePercent), 67);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine chooses the highest path-share route for extreme avoidance", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const alternativeIdx = url.searchParams.get("alternativeidx");

      if (profile === "safety" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 9000,
          durationSeconds: 2400,
          wayTags: [
            "highway=cycleway surface=asphalt",
            "highway=cycleway surface=asphalt",
            "highway=path surface=compacted bicycle=yes",
          ],
        });
      }

      if (profile === "mtb" && alternativeIdx === "3") {
        return createRouteGeoJson({
          distanceMeters: 13000,
          durationSeconds: 3600,
          wayTags: [
            "highway=track surface=gravel bicycle=yes",
            "highway=track surface=ground bicycle=yes",
            "highway=path surface=dirt bicycle=yes",
            "highway=residential surface=asphalt",
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 3000,
        durationSeconds: 900,
        wayTags: [
          "highway=primary surface=asphalt",
          "highway=secondary surface=asphalt",
          "highway=residential surface=asphalt",
        ],
      });
    },
  });
  const engine = new BRouterRoutingEngine(baseUrl, null);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(request, {
      profileRules: mapper.mapRoadAvoidanceStrictness(100),
    });
    assert.ok(
      requests.some((url) => {
        return (
          url.searchParams.get("profile") === "mtb" &&
          url.searchParams.get("alternativeidx") === "3"
        );
      }),
    );
    assert.equal(result.distanceMeters, 13000);
    assert.equal(Math.round(result.roadSharePercent), 25);
    assert.equal(Math.round(result.cyclewaySharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 75);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine prefers forest-like tracks over road-adjacent ways", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const alternativeIdx = url.searchParams.get("alternativeidx");

      if (profile === "safety" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 9000,
          durationSeconds: 2200,
          wayTags: [
            "highway=cycleway surface=asphalt",
            "highway=footway surface=paved bicycle=yes",
            "highway=path surface=asphalt bicycle=yes",
            "highway=residential surface=asphalt",
          ],
        });
      }

      if (profile === "mtb" && alternativeIdx === "3") {
        return createRouteGeoJson({
          distanceMeters: 13000,
          durationSeconds: 3600,
          wayTags: [
            "highway=track surface=ground bicycle=yes",
            "highway=track surface=gravel bicycle=yes",
            "highway=residential surface=asphalt",
            "highway=residential surface=asphalt",
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 7000,
        durationSeconds: 1800,
        wayTags: [
          "highway=residential surface=asphalt",
          "highway=residential surface=asphalt",
          "highway=residential surface=asphalt",
        ],
      });
    },
  });
  const engine = new BRouterRoutingEngine(baseUrl, null);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(
      { ...request, roadAvoidanceStrictness: 100, preferForestWays: true },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(100),
      },
    );
    assert.ok(
      requests.some((url) => {
        return (
          url.searchParams.get("profile") === "mtb" &&
          url.searchParams.get("alternativeidx") === "3"
        );
      }),
    );
    assert.equal(result.distanceMeters, 13000);
    assert.equal(Math.round(result.roadSharePercent), 50);
    assert.equal(Math.round(result.pathSharePercent), 50);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

async function createBRouterStub(): Promise<{
  server: Server;
  baseUrl: string;
  requests: URL[];
}>;
async function createBRouterStub(options: {
  routeByRequest: (url: URL) => BRouterFeatureCollection;
}): Promise<{
  server: Server;
  baseUrl: string;
  requests: URL[];
}>;
async function createBRouterStub(options?: {
  routeByRequest: (url: URL) => BRouterFeatureCollection;
}): Promise<{
  server: Server;
  baseUrl: string;
  requests: URL[];
}> {
  const requests: URL[] = [];
  const server = createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    requests.push(url);
    response.setHeader("content-type", "application/vnd.geo+json");
    response.end(
      JSON.stringify(
        options?.routeByRequest(url) ??
          createRouteGeoJson({
            distanceMeters: 3000,
            durationSeconds: 900,
            wayTags: [
              "highway=cycleway surface=asphalt",
              "highway=path surface=gravel bicycle=yes",
              "highway=residential surface=asphalt",
            ],
          }),
      ),
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

type BRouterFeatureCollection = {
  type: "FeatureCollection";
  features: Array<{
    type: "Feature";
    properties: {
      "track-length": string;
      "total-time": string;
      messages: string[][];
    };
    geometry: {
      type: "LineString";
      coordinates: number[][];
    };
  }>;
};

function createRouteGeoJson(options: {
  distanceMeters: number;
  durationSeconds: number;
  wayTags: string[];
}): BRouterFeatureCollection {
  const segmentDistance = Math.round(
    options.distanceMeters / options.wayTags.length,
  ).toString();

  return {
    type: "FeatureCollection",
    features: [
      {
        type: "Feature",
        properties: {
          "track-length": options.distanceMeters.toString(),
          "total-time": options.durationSeconds.toString(),
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
            ...options.wayTags.map((wayTags) => [
              "0",
              "0",
              "0",
              segmentDistance,
              "0",
              "0",
              "0",
              "0",
              "0",
              wayTags,
            ]),
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
  };
}

import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import test from "node:test";
import { BRouterRoutingEngine } from "../src/engines/brouter-routing-engine.js";
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

test("BRouterRoutingEngine sends waypoints to BRouter", async () => {
  const { server, baseUrl, requests } = await createBRouterStub();
  const engine = new BRouterRoutingEngine(baseUrl, null);
  const mapper = new RoutingProfileMapper();

  try {
    await engine.calculateRoute(
      { ...request, waypoints: [{ lat: 51.3, lng: 6.9 }] },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(50),
      },
    );

    assert.equal(
      requests[0].searchParams.get("lonlats"),
      "6.7735,51.2277|6.9,51.3|7.0131,51.4508",
    );
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine warns when the requested field-way share is unavailable", async () => {
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
    const result = await engine.calculateRoute(
      { ...request, minimumFieldWaySharePercent: 80 },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(100),
      },
    );
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
    assert.ok(
      result.warnings.some((warning) => warning.includes("gewünschte Feld-")),
    );
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine applies forest preference outside the maximum avoidance bucket", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");

      if (profile === "mtb") {
        return createRouteGeoJson({
          distanceMeters: 8_200,
          durationSeconds: 2_100,
          wayTags: [
            "highway=track surface=ground bicycle=yes",
            "highway=path surface=dirt bicycle=yes",
            "highway=track surface=gravel bicycle=yes",
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 6_000,
        durationSeconds: 1_500,
        wayTags: [
          "highway=residential surface=asphalt",
          "highway=cycleway surface=asphalt",
          "highway=residential surface=asphalt",
        ],
      });
    },
  });
  const engine = new BRouterRoutingEngine(baseUrl, null);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(
      { ...request, preferForestWays: true },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(50),
      },
    );

    assert.ok(
      requests.some((url) => {
        return url.searchParams.get("profile") === "mtb";
      }),
    );
    assert.equal(result.distanceMeters, 8_200);
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 100);
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

      if (profile === "mtb" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 13000,
          durationSeconds: 3600,
          wayTags: [
            "highway=track surface=gravel bicycle=yes",
            "highway=track surface=ground bicycle=yes",
            "highway=path surface=dirt bicycle=yes",
            "highway=track surface=ground bicycle=yes",
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
    const result = await engine.calculateRoute(
      { ...request, minimumFieldWaySharePercent: 80 },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(100),
      },
    );
    assert.ok(
      requests.some((url) => {
        return (
          url.searchParams.get("profile") === "mtb" &&
          url.searchParams.get("alternativeidx") === "1"
        );
      }),
    );
    assert.equal(result.distanceMeters, 13000);
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.cyclewaySharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 100);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine prefers a westward corridor that meets the requested field-way share", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const lonlats = url.searchParams.get("lonlats") ?? "";
      const pointCount = lonlats.split("|").filter(Boolean).length;

      if (profile === "mtb" && pointCount === 5) {
        return createRouteGeoJson({
          distanceMeters: 18_500,
          durationSeconds: 5_100,
          wayTags: [
            "highway=track surface=gravel bicycle=yes",
            "highway=track surface=ground bicycle=yes",
            "highway=path surface=dirt bicycle=yes",
            "highway=track surface=earth bicycle=yes",
          ],
          coordinates: [
            [6.7735, 51.2277, 34],
            [6.68, 51.3, 35],
            [6.8, 51.42, 35],
            [6.86, 51.44, 36],
            [7.0131, 51.4508, 43],
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 7_500,
        durationSeconds: 2_000,
        wayTags: [
          "highway=cycleway surface=asphalt",
          "highway=cycleway surface=asphalt",
          "highway=residential surface=asphalt",
        ],
      });
    },
    overpassElements: [
      {
        type: "way",
        center: { lat: 51.3, lon: 6.68 },
        tags: { highway: "track", surface: "gravel" },
      },
      {
        type: "way",
        center: { lat: 51.42, lon: 6.8 },
        tags: { highway: "track", surface: "ground" },
      },
      {
        type: "way",
        center: { lat: 51.44, lon: 6.86 },
        tags: { highway: "path", surface: "dirt" },
      },
    ],
  });
  const engine = new BRouterRoutingEngine(baseUrl, `${baseUrl}/overpass`);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(
      { ...request, minimumFieldWaySharePercent: 80 },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(100),
      },
    );

    assert.ok(
      requests.some((url) => {
        const lonlats = url.searchParams.get("lonlats") ?? "";
        return (
          url.searchParams.get("profile") === "mtb" &&
          lonlats.split("|").filter(Boolean).length === 5
        );
      }),
    );
    assert.equal(result.distanceMeters, 18_500);
    assert.ok(
      result.geometry.some((point) => point.lng < 6.7),
      "the selected field-track corridor should run west of the direct route",
    );
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 100);
    assert.equal(
      result.warnings.some((warning) => warning.includes("Mindestanteil")),
      false,
    );
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine uses the detour-size setting to choose the field-way corridor", async () => {
  const { server, baseUrl } = await createBRouterStub({
    routeByRequest: (url) => {
      const lonlats = url.searchParams.get("lonlats") ?? "";
      const isFarWestCorridor = lonlats.includes("6.81,51.34");

      return createRouteGeoJson({
        distanceMeters: isFarWestCorridor ? 26_000 : 13_000,
        durationSeconds: isFarWestCorridor ? 7_200 : 3_600,
        wayTags: [
          "highway=track surface=gravel bicycle=yes",
          "highway=path surface=ground bicycle=yes",
          "highway=track surface=dirt bicycle=yes",
        ],
        coordinates: isFarWestCorridor
          ? [
              [6.7735, 51.2277, 34],
              [6.81, 51.34, 35],
              [7.0131, 51.4508, 43],
            ]
          : [
              [6.7735, 51.2277, 34],
              [6.86, 51.34, 35],
              [7.0131, 51.4508, 43],
            ],
      });
    },
    overpassElements: [
      {
        type: "way",
        center: { lat: 51.34, lon: 6.86 },
        tags: { highway: "track", surface: "gravel" },
      },
      {
        type: "way",
        center: { lat: 51.34, lon: 6.81 },
        tags: { highway: "track", surface: "gravel" },
      },
    ],
  });
  const engine = new BRouterRoutingEngine(baseUrl, `${baseUrl}/overpass`);
  const mapper = new RoutingProfileMapper();
  const context = {
    profileRules: mapper.mapRoadAvoidanceStrictness(100),
  };

  try {
    const nearResult = await engine.calculateRoute(
      { ...request, greenwayDetourRadiusKm: 5 },
      context,
    );
    const farResult = await engine.calculateRoute(
      { ...request, greenwayDetourRadiusKm: 12 },
      context,
    );

    assert.equal(nearResult.distanceMeters, 13_000);
    assert.equal(farResult.distanceMeters, 26_000);
    assert.ok(
      farResult.geometry.some((point) => point.lng === 6.81),
      "the maximum setting should select the farther west field-way corridor",
    );
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine tries wide four-via detours for extreme avoidance", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const lonlats = url.searchParams.get("lonlats") ?? "";
      const pointCount = lonlats.split("|").filter(Boolean).length;

      if (profile === "mtb" && pointCount === 6) {
        return createRouteGeoJson({
          distanceMeters: 42_000,
          durationSeconds: 12_000,
          wayTags: [
            "highway=track surface=gravel bicycle=yes",
            "highway=track surface=ground bicycle=yes",
            "highway=path surface=dirt bicycle=yes",
            "highway=track surface=earth bicycle=yes",
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 8_000,
        durationSeconds: 2_100,
        wayTags: [
          "highway=cycleway surface=asphalt",
          "highway=residential surface=asphalt",
          "highway=cycleway surface=asphalt",
        ],
      });
    },
    overpassElements: [
      {
        type: "way",
        center: { lat: 51.24, lon: 6.67 },
        tags: { highway: "track", surface: "gravel" },
      },
      {
        type: "way",
        center: { lat: 51.34, lon: 6.76 },
        tags: { highway: "track", surface: "ground" },
      },
      {
        type: "way",
        center: { lat: 51.38, lon: 6.82 },
        tags: { highway: "path", surface: "dirt" },
      },
      {
        type: "way",
        center: { lat: 51.47, lon: 6.94 },
        tags: { highway: "track", surface: "earth" },
      },
    ],
  });
  const engine = new BRouterRoutingEngine(baseUrl, `${baseUrl}/overpass`);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(request, {
      profileRules: mapper.mapRoadAvoidanceStrictness(100),
    });

    assert.ok(
      requests.some((url) => {
        const lonlats = url.searchParams.get("lonlats") ?? "";
        return (
          url.searchParams.get("profile") === "mtb" &&
          lonlats.split("|").filter(Boolean).length === 6
        );
      }),
    );
    assert.equal(result.distanceMeters, 42_000);
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 100);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine prefers fully unpaved routes at extreme avoidance", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const alternativeIdx = url.searchParams.get("alternativeidx");

      if (profile === "safety" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 7000,
          durationSeconds: 1900,
          wayTags: [
            "highway=cycleway surface=asphalt",
            "highway=path surface=asphalt bicycle=yes",
            "highway=cycleway surface=paved",
          ],
        });
      }

      if (profile === "mtb" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 11000,
          durationSeconds: 3300,
          wayTags: [
            "highway=track surface=gravel bicycle=yes",
            "highway=path surface=ground bicycle=yes",
            "highway=track surface=dirt bicycle=yes",
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 5000,
        durationSeconds: 1200,
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
    const result = await engine.calculateRoute(request, {
      profileRules: mapper.mapRoadAvoidanceStrictness(100),
    });

    assert.ok(
      requests.some((url) => {
        return (
          url.searchParams.get("profile") === "mtb" &&
          url.searchParams.get("alternativeidx") === "1"
        );
      }),
    );
    assert.equal(result.distanceMeters, 11000);
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 100);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine lets pure field-track routes win regardless of detour size at extreme avoidance", async () => {
  const { server, baseUrl, requests } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const alternativeIdx = url.searchParams.get("alternativeidx");

      if (profile === "mtb" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 250_000,
          durationSeconds: 72_000,
          wayTags: [
            "highway=track tracktype=grade2 bicycle=yes",
            "highway=path surface=ground bicycle=yes",
            "highway=track surface=gravel bicycle=yes",
          ],
        });
      }

      if (profile === "safety" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 8_000,
          durationSeconds: 2_100,
          wayTags: [
            "highway=cycleway surface=asphalt",
            "highway=path surface=asphalt bicycle=yes",
            "highway=residential surface=asphalt",
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 4_500,
        durationSeconds: 1_200,
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
    const result = await engine.calculateRoute(request, {
      profileRules: mapper.mapRoadAvoidanceStrictness(100),
    });

    assert.ok(
      requests.some((url) => {
        return (
          url.searchParams.get("profile") === "mtb" &&
          url.searchParams.get("alternativeidx") === "1"
        );
      }),
    );
    assert.equal(result.distanceMeters, 250_000);
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 100);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine rejects routes with large retracing spikes", async () => {
  const { server, baseUrl } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const alternativeIdx = url.searchParams.get("alternativeidx");

      if (profile === "safety" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 7000,
          durationSeconds: 2100,
          wayTags: [
            "highway=path surface=compacted bicycle=yes",
            "highway=path surface=compacted bicycle=yes",
            "highway=path surface=compacted bicycle=yes",
            "highway=path surface=compacted bicycle=yes",
          ],
          coordinates: [
            [6.7735, 51.2277, 34],
            [6.84, 51.28, 35],
            [6.84, 51.22, 35],
            [6.84, 51.28, 35],
            [7.0131, 51.4508, 43],
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

    assert.equal(result.distanceMeters, 3000);
    assert.equal(result.geometry.length, 3);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine allows large lateral field-track detours at extreme avoidance", async () => {
  const { server, baseUrl } = await createBRouterStub({
    routeByRequest: (url) => {
      const profile = url.searchParams.get("profile");
      const alternativeIdx = url.searchParams.get("alternativeidx");

      if (profile === "mtb" && alternativeIdx === "1") {
        return createRouteGeoJson({
          distanceMeters: 12_000,
          durationSeconds: 3_400,
          wayTags: [
            "highway=track surface=ground bicycle=yes",
            "highway=track surface=ground bicycle=yes",
            "highway=path surface=dirt bicycle=yes",
            "highway=path surface=dirt bicycle=yes",
          ],
          coordinates: [
            [6.7735, 51.2277, 34],
            [6.762, 51.314, 35],
            [6.822, 51.369, 35],
            [6.882, 51.425, 36],
            [7.0131, 51.4508, 43],
          ],
        });
      }

      return createRouteGeoJson({
        distanceMeters: 6_000,
        durationSeconds: 1_500,
        wayTags: [
          "highway=residential surface=asphalt",
          "highway=cycleway surface=asphalt",
          "highway=residential surface=asphalt",
        ],
      });
    },
  });
  const engine = new BRouterRoutingEngine(baseUrl, null);
  const mapper = new RoutingProfileMapper();

  try {
    const result = await engine.calculateRoute(
      { ...request, roadAvoidanceStrictness: 100 },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(100),
      },
    );

    assert.equal(result.distanceMeters, 12_000);
    assert.equal(result.geometry.length, 5);
    assert.equal(Math.round(result.roadSharePercent), 0);
    assert.equal(Math.round(result.pathSharePercent), 100);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test("BRouterRoutingEngine prefers unpaved tracks over paved low-road ways at extreme avoidance", async () => {
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

      if (profile === "mtb" && alternativeIdx === "1") {
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
      { ...request, roadAvoidanceStrictness: 100 },
      {
        profileRules: mapper.mapRoadAvoidanceStrictness(100),
      },
    );
    assert.ok(
      requests.some((url) => {
        return (
          url.searchParams.get("profile") === "mtb" &&
          url.searchParams.get("alternativeidx") === "1"
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
  overpassElements?: Array<{
    type?: string;
    center?: {
      lat?: number;
      lon?: number;
    };
    tags?: Record<string, string>;
  }>;
}): Promise<{
  server: Server;
  baseUrl: string;
  requests: URL[];
}>;
async function createBRouterStub(options?: {
  routeByRequest: (url: URL) => BRouterFeatureCollection;
  overpassElements?: Array<{
    type?: string;
    center?: {
      lat?: number;
      lon?: number;
    };
    tags?: Record<string, string>;
  }>;
}): Promise<{
  server: Server;
  baseUrl: string;
  requests: URL[];
}> {
  const requests: URL[] = [];
  const server = createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    requests.push(url);

    if (url.pathname === "/brouter/overpass") {
      response.setHeader("content-type", "application/json");
      response.end(
        JSON.stringify({
          elements: options?.overpassElements ?? [],
        }),
      );
      return;
    }

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
  coordinates?: number[][];
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
          coordinates:
            options.coordinates ?? [
              [6.7735, 51.2277, 34],
              [6.8, 51.25, 35],
              [7.0131, 51.4508, 43],
            ],
        },
      },
    ],
  };
}

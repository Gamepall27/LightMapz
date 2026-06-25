import type { RouteRequest, RouteResult } from "../models/route.js";
import type { RoadAvoidanceBucket } from "../profile/routing-profile-mapper.js";
import type {
  RoutingEngine,
  RoutingEngineContext,
} from "./routing-engine.js";

type ParsedRouteSegment = RouteResult["segments"][number];

export class BRouterRoutingEngine implements RoutingEngine {
  constructor(private readonly baseUrl = "https://brouter.de/brouter") {}

  async calculateRoute(
    request: RouteRequest,
    context: RoutingEngineContext,
  ): Promise<RouteResult> {
    const url = new URL(this.baseUrl);
    url.searchParams.set(
      "lonlats",
      `${request.start.lng},${request.start.lat}|${request.destination.lng},${request.destination.lat}`,
    );
    url.searchParams.set(
      "profile",
      toBRouterPublicProfile(context.profileRules.bucket),
    );
    url.searchParams.set("alternativeidx", "0");
    url.searchParams.set("format", "geojson");

    const response = await fetch(url, {
      headers: {
        "User-Agent": "LightMapz/0.1 local development",
        Accept: "application/geo+json, application/json",
      },
    });

    const body = await response.text();

    if (!response.ok) {
      throw new Error(
        `BRouter request failed with ${response.status}: ${body.slice(0, 300)}`,
      );
    }

    return parseBRouterGeoJson(JSON.parse(body) as BRouterFeatureCollection);
  }
}

type BRouterFeatureCollection = {
  features?: Array<{
    properties?: {
      "track-length"?: string;
      "total-time"?: string;
      messages?: unknown[][];
    };
    geometry?: {
      type?: string;
      coordinates?: number[][];
    };
  }>;
};

function parseBRouterGeoJson(json: BRouterFeatureCollection): RouteResult {
  const feature = json.features?.[0];

  if (!feature || feature.geometry?.type !== "LineString") {
    throw new Error("BRouter response did not contain a LineString route.");
  }

  const coordinates = feature.geometry.coordinates ?? [];
  const geometry = coordinates.map((coordinate) => ({
    lat: coordinate[1],
    lng: coordinate[0],
  }));
  const distanceMeters = Number(feature.properties?.["track-length"] ?? 0);
  const durationSeconds = Math.round(
    Number(feature.properties?.["total-time"] ?? 0),
  );
  const segments = parseSegments(feature.properties?.messages ?? []);
  const shares = calculateShares(segments, distanceMeters);

  return {
    geometry,
    distanceMeters,
    durationSeconds,
    roadSharePercent: shares.roadSharePercent,
    cyclewaySharePercent: shares.cyclewaySharePercent,
    pathSharePercent: shares.pathSharePercent,
    warnings:
      shares.roadSharePercent > 0
        ? ["Eine komplett straßenfreie Route wurde nicht gefunden."]
        : [],
    segments,
  };
}

function parseSegments(messages: unknown[][]): ParsedRouteSegment[] {
  const rows = messages.slice(1);

  return rows
    .map((row) => {
      const distanceMeters = Number(row[3] ?? 0);
      const wayTags = String(row[9] ?? "");

      if (!Number.isFinite(distanceMeters) || distanceMeters <= 0) {
        return null;
      }

      return {
        distanceMeters,
        surface: readTag(wayTags, "surface") ?? "unknown",
        wayType: readTag(wayTags, "highway") ?? "unknown",
        roadClass: classifyRoad(wayTags),
      };
    })
    .filter((segment): segment is ParsedRouteSegment => {
      return segment !== null;
    });
}

function calculateShares(
  segments: ReturnType<typeof parseSegments>,
  fallbackDistanceMeters: number,
) {
  const total =
    segments.reduce((sum, segment) => sum + segment.distanceMeters, 0) ||
    fallbackDistanceMeters ||
    1;

  const roadMeters = segments
    .filter((segment) => segment.roadClass === "road")
    .reduce((sum, segment) => sum + segment.distanceMeters, 0);
  const cyclewayMeters = segments
    .filter((segment) => segment.roadClass === "cycleway")
    .reduce((sum, segment) => sum + segment.distanceMeters, 0);
  const pathMeters = segments
    .filter((segment) => segment.roadClass === "path")
    .reduce((sum, segment) => sum + segment.distanceMeters, 0);

  return {
    roadSharePercent: (roadMeters / total) * 100,
    cyclewaySharePercent: (cyclewayMeters / total) * 100,
    pathSharePercent: (pathMeters / total) * 100,
  };
}

function classifyRoad(wayTags: string): string {
  const highway = readTag(wayTags, "highway");

  if (highway === "cycleway" || wayTags.includes("cycleway:")) {
    return "cycleway";
  }

  if (
    highway === "path" ||
    highway === "track" ||
    highway === "footway" ||
    highway === "pedestrian" ||
    highway === "bridleway"
  ) {
    return "path";
  }

  return "road";
}

function readTag(wayTags: string, key: string): string | null {
  const token = wayTags
    .split(/\s+/)
    .find((part) => part.startsWith(`${key}=`));

  return token?.split("=")[1] ?? null;
}

function toBRouterPublicProfile(bucket: RoadAvoidanceBucket): string {
  switch (bucket) {
    case 0:
      return "fastbike";
    case 25:
      return "trekking";
    case 50:
      return "safety";
    case 75:
      return "safety";
    case 100:
      return "shortest";
  }
}

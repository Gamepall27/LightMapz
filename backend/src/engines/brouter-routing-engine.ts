import type { LatLng, RouteRequest, RouteResult } from "../models/route.js";
import type { RoadAvoidanceBucket } from "../profile/routing-profile-mapper.js";
import type {
  RoutingEngine,
  RoutingEngineContext,
} from "./routing-engine.js";

type ParsedRouteSegment = RouteResult["segments"][number];
type BRouterCandidatePlan = {
  profile: string;
  alternativeIdx: number;
  viaPoints?: LatLng[];
};
type BRouterCandidateResult = {
  plan: BRouterCandidatePlan;
  result: RouteResult;
  score: number;
};

export class BRouterRoutingEngine implements RoutingEngine {
  constructor(
    private readonly baseUrl = "https://brouter.de/brouter",
    private readonly overpassUrl: string | null =
      "https://overpass-api.de/api/interpreter",
  ) {}

  async calculateRoute(
    request: RouteRequest,
    context: RoutingEngineContext,
  ): Promise<RouteResult> {
    const plans = [
      ...(await this.createMappedGreenWayCandidatePlans(
        request,
        context.profileRules.bucket,
      )),
      ...toBRouterCandidatePlans(context.profileRules.bucket),
    ];
    const candidates: BRouterCandidateResult[] = [];
    let firstError: unknown = null;

    for (const plan of plans) {
      try {
        const result = await this.fetchRoute(request, plan);
        candidates.push({
          plan,
          result,
          score: scoreRouteForRoadAvoidance(
            result,
            context.profileRules.bucket,
            request.preferForestWays,
          ),
        });
      } catch (error) {
        firstError ??= error;
      }
    }

    if (candidates.length === 0) {
      throw firstError instanceof Error
        ? firstError
        : new Error("BRouter did not return any route candidates.");
    }

    candidates.sort((left, right) => left.score - right.score);
    return candidates[0].result;
  }

  private async fetchRoute(
    request: RouteRequest,
    plan: BRouterCandidatePlan,
  ): Promise<RouteResult> {
    const url = new URL(this.baseUrl);
    url.searchParams.set(
      "lonlats",
      formatLonLats(request, plan),
    );
    url.searchParams.set("profile", plan.profile);
    url.searchParams.set("alternativeidx", plan.alternativeIdx.toString());
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

  private async createMappedGreenWayCandidatePlans(
    request: RouteRequest,
    bucket: RoadAvoidanceBucket,
  ): Promise<BRouterCandidatePlan[]> {
    if (bucket !== 100 || this.overpassUrl === null) {
      return [];
    }

    const directDistanceMeters = calculateDistanceMeters(
      request.start,
      request.destination,
    );

    if (
      !Number.isFinite(directDistanceMeters) ||
      directDistanceMeters < 500
    ) {
      return [];
    }

    try {
      return await fetchMappedGreenWayCandidatePlans(
        request,
        directDistanceMeters,
        this.overpassUrl,
      );
    } catch {
      return [];
    }
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

function toBRouterCandidatePlans(
  bucket: RoadAvoidanceBucket,
): BRouterCandidatePlan[] {
  switch (bucket) {
    case 0:
      return [{ profile: "fastbike", alternativeIdx: 0 }];
    case 25:
      return [{ profile: "trekking", alternativeIdx: 0 }];
    case 50:
      return [{ profile: "safety", alternativeIdx: 0 }];
    case 75:
      return [
        { profile: "safety", alternativeIdx: 0 },
        { profile: "safety", alternativeIdx: 1 },
        { profile: "trekking", alternativeIdx: 0 },
      ];
    case 100:
      return [
        { profile: "safety", alternativeIdx: 0 },
        { profile: "safety", alternativeIdx: 1 },
        { profile: "safety", alternativeIdx: 2 },
        { profile: "safety", alternativeIdx: 3 },
        { profile: "trekking", alternativeIdx: 0 },
        { profile: "trekking", alternativeIdx: 1 },
        { profile: "trekking", alternativeIdx: 2 },
        { profile: "trekking", alternativeIdx: 3 },
        { profile: "mtb", alternativeIdx: 0 },
        { profile: "mtb", alternativeIdx: 1 },
        { profile: "mtb", alternativeIdx: 2 },
        { profile: "mtb", alternativeIdx: 3 },
        { profile: "gravel", alternativeIdx: 0 },
        { profile: "gravel", alternativeIdx: 1 },
        { profile: "gravel", alternativeIdx: 2 },
        { profile: "gravel", alternativeIdx: 3 },
        { profile: "quaelnix-gravel", alternativeIdx: 0 },
        { profile: "quaelnix-gravel", alternativeIdx: 1 },
        { profile: "quaelnix-gravel", alternativeIdx: 2 },
        { profile: "quaelnix-gravel", alternativeIdx: 3 },
        { profile: "MTB_SB_light", alternativeIdx: 0 },
        { profile: "MTB_SB_light", alternativeIdx: 1 },
        { profile: "MTB_SB_light", alternativeIdx: 2 },
        { profile: "MTB_SB_light", alternativeIdx: 3 },
        { profile: "hiking-beta", alternativeIdx: 0 },
        { profile: "hiking-beta", alternativeIdx: 1 },
        { profile: "hiking-beta", alternativeIdx: 2 },
        { profile: "hiking-beta", alternativeIdx: 3 },
        { profile: "hiking_SB", alternativeIdx: 0 },
        { profile: "hiking_SB", alternativeIdx: 1 },
        { profile: "hiking_SB", alternativeIdx: 2 },
        { profile: "hiking_SB", alternativeIdx: 3 },
        { profile: "hiking-mountain", alternativeIdx: 0 },
        { profile: "hiking-mountain", alternativeIdx: 1 },
        { profile: "hiking-mountain", alternativeIdx: 2 },
        { profile: "hiking-mountain", alternativeIdx: 3 },
        { profile: "shortest", alternativeIdx: 0 },
        { profile: "shortest", alternativeIdx: 1 },
        { profile: "shortest", alternativeIdx: 2 },
        { profile: "shortest", alternativeIdx: 3 },
      ];
  }
}

type OverpassResponse = {
  elements?: Array<{
    type?: string;
    center?: {
      lat?: number;
      lon?: number;
    };
    tags?: Record<string, string>;
  }>;
};

type GreenWayCandidate = {
  point: LatLng;
  progress: number;
  side: number;
  lateralDistanceMeters: number;
  forestDistanceMeters: number | null;
  score: number;
};

type ForestCandidate = {
  point: LatLng;
};

async function fetchMappedGreenWayCandidatePlans(
  request: RouteRequest,
  directDistanceMeters: number,
  overpassUrl: string,
): Promise<BRouterCandidatePlan[]> {
  const bbox = createSearchBoundingBox(request, directDistanceMeters);
  const forestQuery = request.preferForestWays
    ? `
      way["landuse"="forest"](${bbox.south},${bbox.west},${bbox.north},${bbox.east});
      relation["landuse"="forest"](${bbox.south},${bbox.west},${bbox.north},${bbox.east});
      way["natural"="wood"](${bbox.south},${bbox.west},${bbox.north},${bbox.east});
      relation["natural"="wood"](${bbox.south},${bbox.west},${bbox.north},${bbox.east});
    `
    : "";
  const query = `
    [out:json][timeout:8];
    (
      way["highway"~"^(track|cycleway|path|bridleway|footway|pedestrian)$"](${bbox.south},${bbox.west},${bbox.north},${bbox.east});
      ${forestQuery}
    );
    out center tags;
  `;

  const response = await fetch(overpassUrl, {
    method: "POST",
    headers: {
      "User-Agent": "LightMapz/0.1 local development",
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams({ data: query }),
  });

  if (!response.ok) {
    return [];
  }

  const json = (await response.json()) as OverpassResponse;
  const elements = json.elements ?? [];
  const forestCandidates = request.preferForestWays
    ? elements
        .map(toForestCandidate)
        .filter((candidate): candidate is ForestCandidate => {
          return candidate !== null;
        })
    : [];
  const candidates = elements
    .map((element) =>
      toGreenWayCandidate(element, request, forestCandidates),
    )
    .filter((candidate): candidate is GreenWayCandidate => {
      return candidate !== null;
    })
    .sort((left, right) => right.score - left.score);

  return [
    ...createSingleGreenWayPlans(candidates, request.preferForestWays),
    ...createPairedGreenWayPlans(candidates, request.preferForestWays),
  ];
}

function createSearchBoundingBox(
  request: RouteRequest,
  directDistanceMeters: number,
) {
  const centerLat = (request.start.lat + request.destination.lat) / 2;
  const marginMeters = clamp(directDistanceMeters * 1.8, 2500, 9000);
  const latMargin = marginMeters / 111_320;
  const lngMargin = latMargin / Math.max(0.2, Math.cos(toRadians(centerLat)));

  return {
    south: Math.min(request.start.lat, request.destination.lat) - latMargin,
    west: Math.min(request.start.lng, request.destination.lng) - lngMargin,
    north: Math.max(request.start.lat, request.destination.lat) + latMargin,
    east: Math.max(request.start.lng, request.destination.lng) + lngMargin,
  };
}

function toGreenWayCandidate(
  element: NonNullable<OverpassResponse["elements"]>[number],
  request: RouteRequest,
  forestCandidates: ForestCandidate[],
): GreenWayCandidate | null {
  if (!isBikeUsableGreenWay(element.tags ?? {})) {
    return null;
  }

  const lat = element.center?.lat;
  const lng = element.center?.lon;

  if (
    typeof lat !== "number" ||
    typeof lng !== "number" ||
    !Number.isFinite(lat) ||
    !Number.isFinite(lng)
  ) {
    return null;
  }

  const position = projectPointOntoRoute(
    { lat, lng },
    request.start,
    request.destination,
  );

  if (
    position.progress < 0.08 ||
    position.progress > 0.92 ||
    Math.abs(position.lateralDistanceMeters) < 500
  ) {
    return null;
  }

  const distanceFromEndsPenalty =
    Math.abs(position.progress - 0.5) * 300;
  const point = { lat, lng };
  const forestDistanceMeters = findNearestForestDistanceMeters(
    point,
    forestCandidates,
  );
  const forestScore = request.preferForestWays
    ? calculateForestCandidateScore(
        element.tags ?? {},
        forestDistanceMeters,
      )
    : 0;

  return {
    point,
    progress: position.progress,
    side: Math.sign(position.lateralDistanceMeters) || 1,
    lateralDistanceMeters: Math.abs(position.lateralDistanceMeters),
    forestDistanceMeters,
    score:
      position.lateralDistanceMeters ** 2 -
      distanceFromEndsPenalty +
      forestScore,
  };
}

function toForestCandidate(
  element: NonNullable<OverpassResponse["elements"]>[number],
): ForestCandidate | null {
  const tags = element.tags ?? {};

  if (tags.landuse !== "forest" && tags.natural !== "wood") {
    return null;
  }

  const point = toElementPoint(element);

  return point === null ? null : { point };
}

function toElementPoint(
  element: NonNullable<OverpassResponse["elements"]>[number],
): LatLng | null {
  const lat = element.center?.lat;
  const lng = element.center?.lon;

  if (
    typeof lat !== "number" ||
    typeof lng !== "number" ||
    !Number.isFinite(lat) ||
    !Number.isFinite(lng)
  ) {
    return null;
  }

  return { lat, lng };
}

function calculateForestCandidateScore(
  tags: Record<string, string>,
  forestDistanceMeters: number | null,
): number {
  const highway = tags.highway;
  const surface = tags.surface;
  const forestProximityScore =
    forestDistanceMeters === null
      ? 0
      : Math.max(0, 3000 - forestDistanceMeters) * 7000;
  const wayTypeScore =
    highway === "track"
      ? 10_000_000
      : highway === "path" || highway === "bridleway"
        ? 6_000_000
        : highway === "footway" || highway === "pedestrian"
          ? 1_500_000
          : highway === "cycleway"
            ? -5_000_000
            : 0;
  const surfaceScore = isNaturalOrLooseSurface(surface) ? 3_000_000 : 0;

  return forestProximityScore + wayTypeScore + surfaceScore;
}

function isBikeUsableGreenWay(tags: Record<string, string>): boolean {
  const highway = tags.highway;
  const access = tags.access;
  const bicycle = tags.bicycle;

  if (access === "private" || access === "no" || bicycle === "no") {
    return false;
  }

  if (highway === "cycleway" || highway === "track") {
    return true;
  }

  if (
    highway === "path" ||
    highway === "footway" ||
    highway === "pedestrian" ||
    highway === "bridleway"
  ) {
    return true;
  }

  return false;
}

function createSingleGreenWayPlans(
  candidates: GreenWayCandidate[],
  preferForestWays: boolean,
): BRouterCandidatePlan[] {
  const profile = preferForestWays ? "mtb" : "safety";

  return candidates.slice(0, 8).map((candidate) => ({
    profile,
    alternativeIdx: 0,
    viaPoints: [candidate.point],
  }));
}

function createPairedGreenWayPlans(
  candidates: GreenWayCandidate[],
  preferForestWays: boolean,
): BRouterCandidatePlan[] {
  const plans: BRouterCandidatePlan[] = [];
  const profile = preferForestWays ? "mtb" : "safety";

  for (const side of [-1, 1]) {
    const sameSide = candidates
      .filter((candidate) => candidate.side === side)
      .sort((left, right) => left.progress - right.progress);
    const early = sameSide
      .filter((candidate) => candidate.progress < 0.5)
      .slice(0, 4);
    const late = sameSide
      .filter((candidate) => candidate.progress >= 0.5)
      .slice(-4);

    for (const first of early) {
      for (const second of late) {
        plans.push({
          profile,
          alternativeIdx: 0,
          viaPoints: [first.point, second.point],
        });
      }
    }
  }

  return plans.slice(0, 12);
}

function projectPointOntoRoute(
  point: LatLng,
  start: LatLng,
  destination: LatLng,
) {
  const midpoint = {
    lat: (start.lat + destination.lat) / 2,
    lng: (start.lng + destination.lng) / 2,
  };
  const metersPerDegreeLat = 111_320;
  const metersPerDegreeLng =
    metersPerDegreeLat * Math.cos(toRadians(midpoint.lat));
  const dx = (destination.lng - start.lng) * metersPerDegreeLng;
  const dy = (destination.lat - start.lat) * metersPerDegreeLat;
  const pointDx = (point.lng - start.lng) * metersPerDegreeLng;
  const pointDy = (point.lat - start.lat) * metersPerDegreeLat;
  const lengthSquared = dx * dx + dy * dy || 1;
  const progress = (pointDx * dx + pointDy * dy) / lengthSquared;
  const lineLength = Math.sqrt(lengthSquared);
  const lateralDistanceMeters = (pointDx * -dy + pointDy * dx) / lineLength;

  return {
    progress,
    lateralDistanceMeters,
  };
}

function formatLonLats(
  request: RouteRequest,
  plan: BRouterCandidatePlan,
): string {
  return [
    request.start,
    ...request.waypoints,
    ...(plan.viaPoints ?? []),
    request.destination,
  ]
    .map((point) => `${point.lng},${point.lat}`)
    .join("|");
}

function calculateDistanceMeters(start: LatLng, destination: LatLng): number {
  const earthRadiusMeters = 6_371_000;
  const deltaLat = toRadians(destination.lat - start.lat);
  const deltaLng = toRadians(destination.lng - start.lng);
  const startLat = toRadians(start.lat);
  const destinationLat = toRadians(destination.lat);
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(startLat) *
      Math.cos(destinationLat) *
      Math.sin(deltaLng / 2) ** 2;

  return (
    earthRadiusMeters *
    2 *
    Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)))
  );
}

function findNearestForestDistanceMeters(
  point: LatLng,
  forestCandidates: ForestCandidate[],
): number | null {
  if (forestCandidates.length === 0) {
    return null;
  }

  return forestCandidates.reduce<number | null>((nearest, candidate) => {
    const distance = calculateDistanceMeters(point, candidate.point);

    if (nearest === null || distance < nearest) {
      return distance;
    }

    return nearest;
  }, null);
}

function toRadians(value: number): number {
  return (value * Math.PI) / 180;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function scoreRouteForRoadAvoidance(
  route: RouteResult,
  bucket: RoadAvoidanceBucket,
  preferForestWays: boolean,
): number {
  if (bucket <= 50) {
    return route.distanceMeters;
  }

  if (bucket === 100) {
    if (preferForestWays) {
      return scoreForestPreferredRoute(route);
    }

    return (
      -route.pathSharePercent * 1_000_000 -
      route.cyclewaySharePercent * 200_000 +
      route.roadSharePercent * 50_000 +
      route.distanceMeters
    );
  }

  const weights = {
    majorRoad: 25,
    minorRoad: 5,
    unknownRoad: 8,
  };

  const roadPenalty = route.segments.reduce((sum, segment) => {
    if (segment.roadClass !== "road") {
      return sum;
    }

    if (isMajorRoad(segment.wayType)) {
      return sum + segment.distanceMeters * weights.majorRoad;
    }

    if (isMinorRoad(segment.wayType)) {
      return sum + segment.distanceMeters * weights.minorRoad;
    }

    return sum + segment.distanceMeters * weights.unknownRoad;
  }, 0);

  return route.distanceMeters + roadPenalty;
}

function scoreForestPreferredRoute(route: RouteResult): number {
  const totalMeters =
    route.segments.reduce((sum, segment) => {
      return sum + segment.distanceMeters;
    }, 0) ||
    route.distanceMeters ||
    1;
  const shares = route.segments.reduce(
    (result, segment) => {
      const share = (segment.distanceMeters / totalMeters) * 100;

      if (
        segment.wayType === "track" ||
        segment.wayType === "path" ||
        segment.wayType === "bridleway"
      ) {
        result.forestLikePathShare += share;
      }

      if (
        segment.wayType === "cycleway" ||
        segment.wayType === "footway" ||
        segment.wayType === "pedestrian"
      ) {
        result.roadAdjacentWayShare += share;
      }

      if (isNaturalOrLooseSurface(segment.surface)) {
        result.naturalSurfaceShare += share;
      }

      return result;
    },
    {
      forestLikePathShare: 0,
      roadAdjacentWayShare: 0,
      naturalSurfaceShare: 0,
    },
  );

  return (
    -shares.forestLikePathShare * 1_200_000 -
    shares.naturalSurfaceShare * 250_000 +
    shares.roadAdjacentWayShare * 450_000 +
    route.roadSharePercent * 180_000 +
    route.distanceMeters
  );
}

function isNaturalOrLooseSurface(surface: string | null | undefined): boolean {
  return [
    "compacted",
    "dirt",
    "earth",
    "fine_gravel",
    "grass",
    "gravel",
    "ground",
    "mud",
    "pebblestone",
    "sand",
    "unpaved",
    "woodchips",
  ].includes(surface ?? "");
}

function isMajorRoad(wayType: string): boolean {
  return [
    "motorway",
    "trunk",
    "primary",
    "secondary",
    "tertiary",
  ].includes(wayType);
}

function isMinorRoad(wayType: string): boolean {
  return [
    "living_street",
    "residential",
    "service",
    "unclassified",
  ].includes(wayType);
}

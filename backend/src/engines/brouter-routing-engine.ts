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

const EXTREME_GREENWAY_SEARCH_MULTIPLIER = 1.5;
const EXTREME_GREENWAY_SEARCH_MIN_METERS = 10_000;
const EXTREME_GREENWAY_SEARCH_DEFAULT_MAX_METERS = 12_000;
// Wider bounding boxes cause Overpass to time out for the default route and
// make BRouter fall back to the undesired direct route.
const EXTREME_GREENWAY_SEARCH_USER_MAX_METERS = 12_000;
const EXTREME_GREENWAY_PROGRESS_MIN = -0.1;
const EXTREME_GREENWAY_PROGRESS_MAX = 1.1;
const EXTREME_GREENWAY_MIN_LATERAL_METERS = 500;
const EXTREME_GREENWAY_MAX_DETOUR_RATIO = 4;
const EXTREME_GREENWAY_MIN_MAX_DISTANCE_METERS = 15_000;

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
    const preferForestWays = shouldPreferForestWays(
      request,
      context.profileRules.bucket,
    );
    const directDistanceMeters = calculateDistanceMeters(
      request.start,
      request.destination,
    );
    const desiredLateralDetourMeters =
      context.profileRules.bucket === 100 && preferForestWays
        ? getDesiredGreenwayLateralDetourMeters(request, directDistanceMeters)
        : null;
    const plans = [
      ...(await this.createMappedGreenWayCandidatePlans(
        request,
        context.profileRules.bucket,
        preferForestWays,
      )),
      ...toBRouterCandidatePlans(
        context.profileRules.bucket,
        preferForestWays,
      ),
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
            preferForestWays,
            desiredLateralDetourMeters,
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

    const mappedGreenwayCandidates =
      context.profileRules.bucket === 100 && preferForestWays
        ? candidates.filter((candidate) => {
            return isUsableMappedGreenwayRoute(
              candidate,
              directDistanceMeters,
              desiredLateralDetourMeters,
            );
          })
        : [];
    const minimumFieldWaySharePercent =
      getMinimumFieldWaySharePercent(request);
    const candidatesMeetingMinimumFieldWayShare =
      context.profileRules.bucket === 100 && preferForestWays
        ? mappedGreenwayCandidates.filter((candidate) => {
            return (
              calculateForestPreferenceShares(candidate.result)
                .forestLikePathShare >= minimumFieldWaySharePercent
            );
          })
        : [];
    const rankedCandidates =
      candidatesMeetingMinimumFieldWayShare.length > 0
        ? candidatesMeetingMinimumFieldWayShare
        : mappedGreenwayCandidates.length > 0
          ? mappedGreenwayCandidates
        : candidates;

    rankedCandidates.sort((left, right) => left.score - right.score);
    return addMinimumFieldWayShareWarning(
      rankedCandidates[0].result,
      context.profileRules.bucket,
      minimumFieldWaySharePercent,
    );
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
    preferForestWays: boolean,
  ): Promise<BRouterCandidatePlan[]> {
    const shouldMapGreenWays = bucket === 100 || preferForestWays;

    if (!shouldMapGreenWays || this.overpassUrl === null) {
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
        preferForestWays,
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
        surface:
          readTag(wayTags, "surface") ??
          readTag(wayTags, "tracktype") ??
          "unknown",
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
  preferForestWays: boolean,
): BRouterCandidatePlan[] {
  switch (bucket) {
    case 0:
      return preferForestWays
        ? [
            { profile: "fastbike", alternativeIdx: 0 },
            { profile: "trekking", alternativeIdx: 0 },
            { profile: "mtb", alternativeIdx: 0 },
          ]
        : [{ profile: "fastbike", alternativeIdx: 0 }];
    case 25:
      return preferForestWays
        ? [
            { profile: "trekking", alternativeIdx: 0 },
            { profile: "gravel", alternativeIdx: 0 },
            { profile: "mtb", alternativeIdx: 0 },
          ]
        : [{ profile: "trekking", alternativeIdx: 0 }];
    case 50:
      return preferForestWays
        ? [
            { profile: "safety", alternativeIdx: 0 },
            { profile: "trekking", alternativeIdx: 0 },
            { profile: "gravel", alternativeIdx: 0 },
            { profile: "mtb", alternativeIdx: 0 },
          ]
        : [{ profile: "safety", alternativeIdx: 0 }];
    case 75:
      return preferForestWays
        ? [
            { profile: "safety", alternativeIdx: 0 },
            { profile: "safety", alternativeIdx: 1 },
            { profile: "trekking", alternativeIdx: 0 },
            { profile: "gravel", alternativeIdx: 0 },
            { profile: "gravel", alternativeIdx: 1 },
            { profile: "mtb", alternativeIdx: 0 },
            { profile: "mtb", alternativeIdx: 1 },
          ]
        : [
            { profile: "safety", alternativeIdx: 0 },
            { profile: "safety", alternativeIdx: 1 },
            { profile: "trekking", alternativeIdx: 0 },
          ];
    case 100:
      return [
        { profile: "safety", alternativeIdx: 0 },
        { profile: "safety", alternativeIdx: 1 },
        { profile: "trekking", alternativeIdx: 0 },
        { profile: "trekking", alternativeIdx: 1 },
        { profile: "mtb", alternativeIdx: 0 },
        { profile: "mtb", alternativeIdx: 1 },
        { profile: "gravel", alternativeIdx: 0 },
        { profile: "gravel", alternativeIdx: 1 },
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
  score: number;
};

async function fetchMappedGreenWayCandidatePlans(
  request: RouteRequest,
  directDistanceMeters: number,
  overpassUrl: string,
  preferForestWays: boolean,
): Promise<BRouterCandidatePlan[]> {
  const desiredLateralDetourMeters = preferForestWays
    ? getDesiredGreenwayLateralDetourMeters(request, directDistanceMeters)
    : null;
  const bbox = createSearchBoundingBox(
    request,
    directDistanceMeters,
    preferForestWays,
  );
  const query = `
    [out:json][timeout:12];
    way["highway"~"^(track|cycleway|path|bridleway)$"](
      ${bbox.south},${bbox.west},${bbox.north},${bbox.east}
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
  const candidates = elements
    .map((element) =>
      toGreenWayCandidate(
        element,
        request,
        directDistanceMeters,
        preferForestWays,
        desiredLateralDetourMeters,
      ),
    )
    .filter((candidate): candidate is GreenWayCandidate => {
      return candidate !== null;
    })
    .sort((left, right) => right.score - left.score);

  return [
    ...createSingleGreenWayPlans(
      candidates,
      preferForestWays,
      desiredLateralDetourMeters,
    ),
    ...createTripleGreenWayPlans(candidates, preferForestWays),
    ...createQuadGreenWayPlans(candidates, preferForestWays),
    ...createPairedGreenWayPlans(candidates, preferForestWays),
  ];
}

function createSearchBoundingBox(
  request: RouteRequest,
  directDistanceMeters: number,
  preferForestWays: boolean,
) {
  const centerLat = (request.start.lat + request.destination.lat) / 2;
  const marginMeters = preferForestWays
    ? getExtremeGreenwaySearchRadiusMeters(request, directDistanceMeters)
    : clamp(directDistanceMeters * 1.8, 2500, 9000);
  const latMargin = marginMeters / 111_320;
  const lngMargin = latMargin / Math.max(0.2, Math.cos(toRadians(centerLat)));

  return {
    south: Math.min(request.start.lat, request.destination.lat) - latMargin,
    west: Math.min(request.start.lng, request.destination.lng) - lngMargin,
    north: Math.max(request.start.lat, request.destination.lat) + latMargin,
    east: Math.max(request.start.lng, request.destination.lng) + lngMargin,
  };
}

function getExtremeGreenwaySearchRadiusMeters(
  request: RouteRequest,
  directDistanceMeters: number,
): number {
  const requestedMeters =
    typeof request.greenwayDetourRadiusKm === "number" &&
    Number.isFinite(request.greenwayDetourRadiusKm)
      ? request.greenwayDetourRadiusKm * 1000
      : null;

  if (requestedMeters !== null) {
    return clamp(
      requestedMeters,
      EXTREME_GREENWAY_SEARCH_MIN_METERS,
      EXTREME_GREENWAY_SEARCH_USER_MAX_METERS,
    );
  }

  return clamp(
    directDistanceMeters * EXTREME_GREENWAY_SEARCH_MULTIPLIER,
    EXTREME_GREENWAY_SEARCH_MIN_METERS,
    EXTREME_GREENWAY_SEARCH_DEFAULT_MAX_METERS,
  );
}

function getDesiredGreenwayLateralDetourMeters(
  request: RouteRequest,
  directDistanceMeters: number,
): number {
  const requestedMeters =
    typeof request.greenwayDetourRadiusKm === "number" &&
    Number.isFinite(request.greenwayDetourRadiusKm)
      ? clamp(
          request.greenwayDetourRadiusKm * 1000,
          5_000,
          EXTREME_GREENWAY_SEARCH_USER_MAX_METERS,
        )
      : clamp(
          directDistanceMeters * EXTREME_GREENWAY_SEARCH_MULTIPLIER,
          EXTREME_GREENWAY_SEARCH_MIN_METERS,
          EXTREME_GREENWAY_SEARCH_DEFAULT_MAX_METERS,
        );

  // The setting describes the size of the desired detour. A detour of 5 km
  // therefore targets greenways roughly 2.5 km away from the direct line,
  // while the maximum setting can deliberately use a corridor up to 6 km away.
  return clamp(requestedMeters * 0.5, 2_000, 6_000);
}

function toGreenWayCandidate(
  element: NonNullable<OverpassResponse["elements"]>[number],
  request: RouteRequest,
  directDistanceMeters: number,
  preferForestWays: boolean,
  desiredLateralDetourMeters: number | null,
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

  const minProgress = preferForestWays
    ? EXTREME_GREENWAY_PROGRESS_MIN
    : 0.08;
  const maxProgress = preferForestWays
    ? EXTREME_GREENWAY_PROGRESS_MAX
    : 0.92;
  const minLateralMeters = preferForestWays
    ? EXTREME_GREENWAY_MIN_LATERAL_METERS
    : 500;

  if (
    position.progress < minProgress ||
    position.progress > maxProgress ||
    Math.abs(position.lateralDistanceMeters) < minLateralMeters
  ) {
    return null;
  }

  const desiredLateralMeters =
    desiredLateralDetourMeters ??
    clamp(directDistanceMeters * 0.6, 2_000, 6_000);
  const lateralDetourPenalty =
    Math.abs(Math.abs(position.lateralDistanceMeters) - desiredLateralMeters) *
    1_500;
  const distanceFromEndsPenalty =
    Math.abs(position.progress - 0.5) * 1_000_000;
  const point = { lat, lng };
  const forestScore = preferForestWays
    ? calculateForestCandidateScore(element.tags ?? {})
    : 0;

  return {
    point,
    progress: position.progress,
    side: Math.sign(position.lateralDistanceMeters) || 1,
    lateralDistanceMeters: Math.abs(position.lateralDistanceMeters),
    score:
      forestScore - lateralDetourPenalty - distanceFromEndsPenalty,
  };
}

function calculateForestCandidateScore(tags: Record<string, string>): number {
  const highway = tags.highway;
  const surface = tags.surface;
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

  return wayTypeScore + surfaceScore;
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
  desiredLateralDetourMeters: number | null,
): BRouterCandidatePlan[] {
  const profile = preferForestWays ? "mtb" : "safety";
  const selectedCandidates = preferForestWays
    ? selectDistributedGreenwayAnchors(
        candidates,
        desiredLateralDetourMeters,
      )
    : candidates.slice(0, 8);

  return selectedCandidates.map((candidate) => ({
    profile,
    alternativeIdx: 0,
    viaPoints: [candidate.point],
  }));
}

function selectDistributedGreenwayAnchors(
  candidates: GreenWayCandidate[],
  desiredLateralDetourMeters: number | null,
): GreenWayCandidate[] {
  const anchors: GreenWayCandidate[] = [];

  // A manually placed waypoint often works because it captures the entry to
  // a field-way corridor. Do the same automatically: test one strong anchor
  // at the entry, middle and exit of each side instead of spending all six
  // single-waypoint attempts on the globally highest-scoring middle section.
  for (const side of [-1, 1]) {
    const sameSide = candidates.filter((candidate) => candidate.side === side);

    for (const [minProgress, maxProgress] of [
      [-0.1, 0.34],
      [0.34, 0.66],
      [0.66, 1.1],
    ]) {
      const [anchor] = selectTopCandidatesInProgressRange(
        sameSide,
        minProgress,
        maxProgress,
        1,
      );

      if (anchor !== undefined) {
        anchors.push(anchor);
      }
    }
  }

  if (desiredLateralDetourMeters !== null) {
    const innerCorridorTargetMeters = clamp(
      desiredLateralDetourMeters * 0.65,
      2_000,
      4_000,
    );

    for (const side of [-1, 1]) {
      const innerEntry = selectCandidateForLateralTarget(
        candidates.filter((candidate) => candidate.side === side),
        -0.1,
        0.4,
        desiredLateralDetourMeters,
        innerCorridorTargetMeters,
      );

      if (innerEntry !== undefined) {
        anchors.push(innerEntry);
      }
    }
  }

  // Preserve the former globally strongest candidates as well. Some
  // OSM corridors have no useful entry/exit centre even though their middle
  // produces a viable route; replacing every former candidate with distributed
  // anchors would make the search regress to BRouter's direct fallback.
  for (const candidate of candidates.slice(0, 6)) {
    if (anchors.length >= 14) {
      break;
    }

    const isAlreadySelected = anchors.some((anchor) => {
      return (
        anchor.point.lat === candidate.point.lat &&
        anchor.point.lng === candidate.point.lng
      );
    });

    if (!isAlreadySelected) {
      anchors.push(candidate);
    }
  }

  return anchors;
}

function selectCandidateForLateralTarget(
  candidates: GreenWayCandidate[],
  minProgress: number,
  maxProgress: number,
  currentLateralTargetMeters: number,
  lateralTargetMeters: number,
): GreenWayCandidate | undefined {
  return candidates
    .filter((candidate) => {
      return (
        candidate.progress >= minProgress && candidate.progress < maxProgress
      );
    })
    .sort((left, right) => {
      const leftScore = scoreCandidateForLateralTarget(
        left,
        currentLateralTargetMeters,
        lateralTargetMeters,
      );
      const rightScore = scoreCandidateForLateralTarget(
        right,
        currentLateralTargetMeters,
        lateralTargetMeters,
      );

      return rightScore - leftScore;
    })[0];
}

function scoreCandidateForLateralTarget(
  candidate: GreenWayCandidate,
  currentLateralTargetMeters: number,
  lateralTargetMeters: number,
): number {
  const currentLateralPenalty =
    Math.abs(candidate.lateralDistanceMeters - currentLateralTargetMeters) *
    1_500;
  const replacementLateralPenalty =
    Math.abs(candidate.lateralDistanceMeters - lateralTargetMeters) * 1_500;

  return candidate.score + currentLateralPenalty - replacementLateralPenalty;
}

function createTripleGreenWayPlans(
  candidates: GreenWayCandidate[],
  preferForestWays: boolean,
): BRouterCandidatePlan[] {
  if (!preferForestWays) {
    return [];
  }

  const plans: BRouterCandidatePlan[] = [];

  for (const side of [-1, 1]) {
    const sameSide = candidates.filter((candidate) => candidate.side === side);
    const [first] = selectTopCandidatesInProgressRange(
      sameSide,
      -0.1,
      0.34,
      1,
    );
    const [second] = selectTopCandidatesInProgressRange(
      sameSide,
      0.34,
      0.66,
      1,
    );
    const [third] = selectTopCandidatesInProgressRange(
      sameSide,
      0.66,
      1.1,
      1,
    );

    if (first !== undefined && second !== undefined && third !== undefined) {
      plans.push({
        profile: "mtb",
        alternativeIdx: 0,
        viaPoints: [first.point, second.point, third.point],
      });
    }
  }

  return plans;
}

function createQuadGreenWayPlans(
  candidates: GreenWayCandidate[],
  preferForestWays: boolean,
): BRouterCandidatePlan[] {
  if (!preferForestWays) {
    return [];
  }

  const plans: BRouterCandidatePlan[] = [];

  for (const side of [-1, 1]) {
    const sameSide = candidates.filter((candidate) => candidate.side === side);
    const [first] = selectTopCandidatesInProgressRange(
      sameSide,
      -0.1,
      0.25,
      1,
    );
    const [second] = selectTopCandidatesInProgressRange(
      sameSide,
      0.25,
      0.5,
      1,
    );
    const [third] = selectTopCandidatesInProgressRange(
      sameSide,
      0.5,
      0.75,
      1,
    );
    const [fourth] = selectTopCandidatesInProgressRange(
      sameSide,
      0.75,
      1.1,
      1,
    );

    if (
      first !== undefined &&
      second !== undefined &&
      third !== undefined &&
      fourth !== undefined
    ) {
      plans.push({
        profile: "mtb",
        alternativeIdx: 0,
        viaPoints: [first.point, second.point, third.point, fourth.point],
      });
    }
  }

  return plans;
}

function createPairedGreenWayPlans(
  candidates: GreenWayCandidate[],
  preferForestWays: boolean,
): BRouterCandidatePlan[] {
  const plans: BRouterCandidatePlan[] = [];
  const profile = preferForestWays ? "mtb" : "safety";

  for (const side of [-1, 1]) {
    const sameSide = candidates.filter((candidate) => candidate.side === side);
    const early = preferForestWays
      ? selectTopCandidatesInProgressRange(sameSide, -0.1, 0.5, 1)
      : sameSide.filter((candidate) => candidate.progress < 0.5).slice(0, 4);
    const late = preferForestWays
      ? selectTopCandidatesInProgressRange(sameSide, 0.5, 1.1, 1)
      : sameSide.filter((candidate) => candidate.progress >= 0.5).slice(-4);

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

  return plans.slice(0, preferForestWays ? 2 : 12);
}

function selectTopCandidatesInProgressRange(
  candidates: GreenWayCandidate[],
  minProgress: number,
  maxProgress: number,
  limit: number,
): GreenWayCandidate[] {
  return candidates
    .filter((candidate) => {
      return (
        candidate.progress >= minProgress && candidate.progress < maxProgress
      );
    })
    .sort((left, right) => right.score - left.score)
    .slice(0, limit)
    .sort((left, right) => left.progress - right.progress);
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

function toRadians(value: number): number {
  return (value * Math.PI) / 180;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function shouldPreferForestWays(
  request: RouteRequest,
  bucket: RoadAvoidanceBucket,
): boolean {
  return request.preferForestWays || bucket === 100;
}

function getMinimumFieldWaySharePercent(request: RouteRequest): number {
  const requested = request.minimumFieldWaySharePercent;

  if (typeof requested !== "number" || !Number.isFinite(requested)) {
    return 45;
  }

  return clamp(requested, 0, 100);
}

function isUsableMappedGreenwayRoute(
  candidate: BRouterCandidateResult,
  directDistanceMeters: number,
  desiredLateralDetourMeters: number | null,
): boolean {
  if ((candidate.plan.viaPoints?.length ?? 0) === 0) {
    return false;
  }

  const maxDistanceMeters = Math.max(
    EXTREME_GREENWAY_MIN_MAX_DISTANCE_METERS,
    desiredLateralDetourMeters === null
      ? directDistanceMeters * EXTREME_GREENWAY_MAX_DETOUR_RATIO
      : directDistanceMeters + desiredLateralDetourMeters * 3,
  );

  if (candidate.result.distanceMeters > maxDistanceMeters) {
    return false;
  }

  const shares = calculateForestPreferenceShares(candidate.result);

  return (
    shares.forestLikePathShare >= 45 &&
    candidate.result.roadSharePercent <= 45
  );
}

function addMinimumFieldWayShareWarning(
  result: RouteResult,
  bucket: RoadAvoidanceBucket,
  minimumFieldWaySharePercent: number,
): RouteResult {
  if (bucket !== 100) {
    return result;
  }

  const actualFieldWaySharePercent =
    calculateForestPreferenceShares(result).forestLikePathShare;

  if (actualFieldWaySharePercent >= minimumFieldWaySharePercent) {
    return result;
  }

  return {
    ...result,
    warnings: [
      ...result.warnings,
      `Der gewünschte Feld-/Waldweganteil von ${Math.round(minimumFieldWaySharePercent)} % wurde nicht erreicht (${Math.round(actualFieldWaySharePercent)} %).`,
    ],
  };
}

function scoreRouteForRoadAvoidance(
  route: RouteResult,
  bucket: RoadAvoidanceBucket,
  preferForestWays: boolean,
  desiredLateralDetourMeters: number | null,
): number {
  const shapePenaltyMultiplier =
    bucket === 100 && preferForestWays ? 8 : 1;
  const shapePenalty =
    scoreRouteShapePenalty(route.geometry, bucket, preferForestWays) *
    shapePenaltyMultiplier;
  const forestPreferenceAdjustment = preferForestWays
    ? scoreForestPreferenceAdjustment(route, bucket)
    : 0;
  const detourTargetPenalty =
    bucket === 100 && preferForestWays && desiredLateralDetourMeters !== null
      ? scoreExtremeGreenwayDetourTarget(route.geometry, desiredLateralDetourMeters)
      : 0;

  if (bucket <= 50) {
    return route.distanceMeters + shapePenalty + forestPreferenceAdjustment;
  }

  if (bucket === 100) {
    if (preferForestWays) {
      return (
        scoreForestPreferredRoute(route) + shapePenalty + detourTargetPenalty
      );
    }

    return (
      -route.pathSharePercent * 1_000_000 -
      route.cyclewaySharePercent * 200_000 +
      route.roadSharePercent * 50_000 +
      route.distanceMeters +
      shapePenalty
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

  return (
    route.distanceMeters +
    roadPenalty +
    shapePenalty +
    forestPreferenceAdjustment
  );
}

function scoreExtremeGreenwayDetourTarget(
  geometry: LatLng[],
  desiredLateralDetourMeters: number,
): number {
  if (geometry.length < 3) {
    return 0;
  }

  const start = geometry[0];
  const destination = geometry.at(-1);

  if (destination === undefined) {
    return 0;
  }

  let actualLateralDetourMeters = 0;

  for (const point of geometry) {
    actualLateralDetourMeters = Math.max(
      actualLateralDetourMeters,
      Math.abs(
        projectPointOntoRoute(point, start, destination).lateralDistanceMeters,
      ),
    );
  }

  // A one-kilometre mismatch is intentionally material at the maximum
  // avoidance level. Otherwise the field-way percentages dominate every
  // candidate and the detour-size control cannot influence the selected route.
  return (
    Math.abs(actualLateralDetourMeters - desiredLateralDetourMeters) *
    20_000_000
  );
}

function scoreForestPreferredRoute(route: RouteResult): number {
  const shares = calculateForestPreferenceShares(route);

  const forestFieldDeficit = 100 - shares.forestLikePathShare;
  const naturalSurfaceDeficit = 100 - shares.naturalSurfaceShare;

  return (
    forestFieldDeficit * 5_000_000_000 +
    route.roadSharePercent * 3_000_000_000 +
    shares.roadAdjacentWayShare * 1_000_000_000 +
    shares.pavedSurfaceShare * 800_000_000 +
    naturalSurfaceDeficit * 500_000_000 +
    shares.unknownSurfaceShare * 100_000_000 +
    shares.nonNaturalSurfaceShare * 50_000_000 +
    route.distanceMeters
  );
}

function scoreForestPreferenceAdjustment(
  route: RouteResult,
  bucket: RoadAvoidanceBucket,
): number {
  const shares = calculateForestPreferenceShares(route);
  const strength =
    bucket === 0
      ? 0.35
      : bucket === 25
        ? 0.5
        : bucket === 50
          ? 1
          : 1.3;

  return (
    -shares.forestLikePathShare * 80 * strength -
    shares.naturalSurfaceShare * 25 * strength +
    shares.roadAdjacentWayShare * 30 * strength +
    route.roadSharePercent * 60 * strength
  );
}

function calculateForestPreferenceShares(route: RouteResult) {
  const totalMeters =
    route.segments.reduce((sum, segment) => {
      return sum + segment.distanceMeters;
    }, 0) ||
    route.distanceMeters ||
    1;

  return route.segments.reduce(
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

      if (segment.surface === "unknown") {
        result.unknownSurfaceShare += share;
      } else if (isNaturalOrLooseSurface(segment.surface)) {
        result.naturalSurfaceShare += share;
      } else {
        result.nonNaturalSurfaceShare += share;
      }

      if (isPavedOrRoadSurface(segment.surface)) {
        result.pavedSurfaceShare += share;
      }

      return result;
    },
    {
      forestLikePathShare: 0,
      roadAdjacentWayShare: 0,
      naturalSurfaceShare: 0,
      nonNaturalSurfaceShare: 0,
      unknownSurfaceShare: 0,
      pavedSurfaceShare: 0,
    },
  );
}

function scoreRouteShapePenalty(
  geometry: LatLng[],
  bucket: RoadAvoidanceBucket,
  preferForestWays: boolean,
): number {
  if (geometry.length < 3 || bucket < 75) {
    return 0;
  }

  const backtrackingMeters = calculateBacktrackingMeters(geometry);
  const retraceMeters = calculateRetraceMeters(geometry);
  const lateralSpikeMeters = calculateLateralSpikeMeters(
    geometry,
    bucket,
    preferForestWays,
  );
  const backtrackingWeight =
    bucket === 100 && preferForestWays ? 3_000_000_000 : 40_000;
  const retraceWeight =
    bucket === 100 && preferForestWays ? 3_000_000_000 : 120_000;
  const lateralSpikeWeight =
    bucket === 100 && preferForestWays ? 0 : 100_000;

  return (
    backtrackingMeters * backtrackingWeight +
    retraceMeters * retraceWeight +
    lateralSpikeMeters * lateralSpikeWeight
  );
}

function calculateLateralSpikeMeters(
  geometry: LatLng[],
  bucket: RoadAvoidanceBucket,
  preferForestWays: boolean,
): number {
  const start = geometry[0];
  const destination = geometry.at(-1);

  if (destination === undefined) {
    return 0;
  }

  const directDistanceMeters = calculateDistanceMeters(start, destination);

  if (!Number.isFinite(directDistanceMeters) || directDistanceMeters < 1_500) {
    return 0;
  }

  const allowedCorridorMeters =
    bucket === 100 && preferForestWays
      ? clamp(directDistanceMeters * 0.25, 2_500, 9_000)
      : clamp(directDistanceMeters * 0.12, 400, 1_800);
  let maxExcessMeters = 0;

  for (const point of geometry) {
    const lateralDistanceMeters = Math.abs(
      projectPointOntoRoute(point, start, destination).lateralDistanceMeters,
    );
    const excessMeters = lateralDistanceMeters - allowedCorridorMeters;

    if (excessMeters > maxExcessMeters) {
      maxExcessMeters = excessMeters;
    }
  }

  return Math.max(0, maxExcessMeters);
}

function calculateBacktrackingMeters(geometry: LatLng[]): number {
  const start = geometry[0];
  const destination = geometry.at(-1);

  if (destination === undefined) {
    return 0;
  }

  const midpointLat = (start.lat + destination.lat) / 2;
  const metersPerDegreeLat = 111_320;
  const metersPerDegreeLng =
    metersPerDegreeLat * Math.cos(toRadians(midpointLat));
  const startX = start.lng * metersPerDegreeLng;
  const startY = start.lat * metersPerDegreeLat;
  const destinationX = destination.lng * metersPerDegreeLng;
  const destinationY = destination.lat * metersPerDegreeLat;
  const axisX = destinationX - startX;
  const axisY = destinationY - startY;
  const axisLength = Math.sqrt(axisX * axisX + axisY * axisY) || 1;
  const unitX = axisX / axisLength;
  const unitY = axisY / axisLength;
  let maxProgressMeters = 0;
  let backtrackingMeters = 0;

  for (const point of geometry) {
    const pointX = point.lng * metersPerDegreeLng;
    const pointY = point.lat * metersPerDegreeLat;
    const progressMeters =
      (pointX - startX) * unitX + (pointY - startY) * unitY;

    if (progressMeters > maxProgressMeters) {
      maxProgressMeters = progressMeters;
      continue;
    }

    const lossMeters = maxProgressMeters - progressMeters;

    if (lossMeters > 150) {
      backtrackingMeters += lossMeters - 150;
    }
  }

  return backtrackingMeters;
}

function calculateRetraceMeters(geometry: LatLng[]): number {
  let retraceMeters = 0;

  for (let index = 1; index < geometry.length - 1; index++) {
    const previousSegmentMeters = calculateDistanceMeters(
      geometry[index - 1],
      geometry[index],
    );
    const nextSegmentMeters = calculateDistanceMeters(
      geometry[index],
      geometry[index + 1],
    );
    const effectiveSegmentMeters = Math.min(
      previousSegmentMeters,
      nextSegmentMeters,
    );

    if (effectiveSegmentMeters < 150) {
      continue;
    }

    const incomingBearing = calculateBearingDegrees(
      geometry[index - 1],
      geometry[index],
    );
    const outgoingBearing = calculateBearingDegrees(
      geometry[index],
      geometry[index + 1],
    );
    const turnDelta = Math.abs(
      normalizeBearingDelta(outgoingBearing - incomingBearing),
    );

    if (turnDelta >= 150) {
      retraceMeters += effectiveSegmentMeters;
    }
  }

  return retraceMeters;
}

function calculateBearingDegrees(from: LatLng, to: LatLng): number {
  const fromLat = toRadians(from.lat);
  const toLat = toRadians(to.lat);
  const deltaLng = toRadians(to.lng - from.lng);
  const y = Math.sin(deltaLng) * Math.cos(toLat);
  const x =
    Math.cos(fromLat) * Math.sin(toLat) -
    Math.sin(fromLat) * Math.cos(toLat) * Math.cos(deltaLng);

  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

function normalizeBearingDelta(delta: number): number {
  let normalized = (delta + 540) % 360 - 180;

  if (normalized === -180) {
    normalized = 180;
  }

  return normalized;
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
    "grade1",
    "grade2",
    "grade3",
    "grade4",
    "grade5",
  ].includes(surface ?? "");
}

function isPavedOrRoadSurface(surface: string | null | undefined): boolean {
  return [
    "asphalt",
    "chipseal",
    "concrete",
    "concrete:lanes",
    "concrete:plates",
    "paved",
    "paving_stones",
    "sett",
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

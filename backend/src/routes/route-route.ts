import type { FastifyInstance } from "fastify";
import type { RoutingEngine } from "../engines/routing-engine.js";
import type { RouteRequest } from "../models/route.js";
import { RoutingProfileMapper } from "../profile/routing-profile-mapper.js";

type RouteRouteOptions = {
  routingEngine: RoutingEngine;
  profileMapper: RoutingProfileMapper;
};

export async function registerRouteRoute(
  app: FastifyInstance,
  options: RouteRouteOptions,
): Promise<void> {
  app.post("/route", async (request, reply) => {
    const parsed = parseRouteRequest(request.body);

    if (!parsed.ok) {
      return reply.status(400).send({
        error: "Invalid route request",
        details: parsed.errors,
      });
    }

    const profileRules = options.profileMapper.mapRoadAvoidanceStrictness(
      parsed.value.roadAvoidanceStrictness,
    );

    const result = await options.routingEngine.calculateRoute(parsed.value, {
      profileRules,
    });

    return reply.send(result);
  });
}

type ParseResult =
  | { ok: true; value: RouteRequest }
  | { ok: false; errors: string[] };

function parseRouteRequest(body: unknown): ParseResult {
  const errors: string[] = [];

  if (!isRecord(body)) {
    return { ok: false, errors: ["Body must be a JSON object."] };
  }

  const start = parseLatLng(body.start, "start", errors);
  const destination = parseLatLng(body.destination, "destination", errors);
  const profile = body.profile;
  const roadAvoidanceStrictness = body.roadAvoidanceStrictness;
  const preferForestWays = body.preferForestWays;

  if (profile !== "bike") {
    errors.push('profile must be "bike".');
  }

  if (!isNumber(roadAvoidanceStrictness)) {
    errors.push("roadAvoidanceStrictness must be a number from 0 to 100.");
  } else if (roadAvoidanceStrictness < 0 || roadAvoidanceStrictness > 100) {
    errors.push("roadAvoidanceStrictness must be between 0 and 100.");
  }

  if (
    preferForestWays !== undefined &&
    typeof preferForestWays !== "boolean"
  ) {
    errors.push("preferForestWays must be a boolean.");
  }

  if (errors.length > 0 || start === null || destination === null) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    value: {
      start,
      destination,
      profile: "bike",
      roadAvoidanceStrictness: roadAvoidanceStrictness as number,
      preferForestWays:
        typeof preferForestWays === "boolean" ? preferForestWays : false,
    },
  };
}

function parseLatLng(
  value: unknown,
  fieldName: string,
  errors: string[],
): { lat: number; lng: number } | null {
  if (!isRecord(value)) {
    errors.push(`${fieldName} must be an object with lat and lng.`);
    return null;
  }

  const { lat, lng } = value;

  const parsedLat = isNumber(lat) ? lat : null;
  const parsedLng = isNumber(lng) ? lng : null;

  if (parsedLat === null || parsedLat < -90 || parsedLat > 90) {
    errors.push(`${fieldName}.lat must be a number between -90 and 90.`);
  }

  if (parsedLng === null || parsedLng < -180 || parsedLng > 180) {
    errors.push(`${fieldName}.lng must be a number between -180 and 180.`);
  }

  if (parsedLat === null || parsedLng === null) {
    return null;
  }

  return { lat: parsedLat, lng: parsedLng };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

import type { LatLng, RouteRequest, RouteResult } from "../models/route.js";
import type {
  RoutingEngine,
  RoutingEngineContext,
} from "./routing-engine.js";

export class MockRoutingEngine implements RoutingEngine {
  async calculateRoute(
    request: RouteRequest,
    context: RoutingEngineContext,
  ): Promise<RouteResult> {
    const geometry = buildDemoGeometry(request.start, request.destination);
    const directDistance = estimateDistanceMeters(
      request.start,
      request.destination,
    );
    const detourFactor = 1 + context.profileRules.bucket / 170;
    const distanceMeters = Math.round(directDistance * detourFactor);
    const durationSeconds = Math.round(distanceMeters / 3.9);

    const strictness = context.profileRules.bucket;
    const roadSharePercent = Math.max(4, 38 - strictness * 0.34);
    const cyclewaySharePercent = Math.min(76, 34 + strictness * 0.42);
    const pathSharePercent = Math.max(
      0,
      100 - roadSharePercent - cyclewaySharePercent,
    );

    return {
      geometry,
      distanceMeters,
      durationSeconds,
      roadSharePercent,
      cyclewaySharePercent,
      pathSharePercent,
      warnings:
        roadSharePercent > 0
          ? ["Eine komplett straßenfreie Route wurde nicht gefunden."]
          : [],
      segments: [
        {
          distanceMeters: Math.round(
            (distanceMeters * cyclewaySharePercent) / 100,
          ),
          surface: "asphalt",
          wayType: "cycleway",
          roadClass: "cycleway",
        },
        {
          distanceMeters: Math.round((distanceMeters * pathSharePercent) / 100),
          surface: "compacted",
          wayType: "path",
          roadClass: "path",
        },
        {
          distanceMeters: Math.round((distanceMeters * roadSharePercent) / 100),
          surface: "asphalt",
          wayType: "residential",
          roadClass: "local_road",
        },
      ],
    };
  }
}

function buildDemoGeometry(start: LatLng, destination: LatLng): LatLng[] {
  const midLat = (start.lat + destination.lat) / 2;
  const midLng = (start.lng + destination.lng) / 2;
  const latOffset = (destination.lng - start.lng) * 0.08;
  const lngOffset = (start.lat - destination.lat) * 0.08;

  return [
    start,
    {
      lat: start.lat * 0.7 + midLat * 0.3 + latOffset,
      lng: start.lng * 0.7 + midLng * 0.3 + lngOffset,
    },
    {
      lat: midLat + latOffset,
      lng: midLng + lngOffset,
    },
    {
      lat: destination.lat * 0.7 + midLat * 0.3 + latOffset,
      lng: destination.lng * 0.7 + midLng * 0.3 + lngOffset,
    },
    destination,
  ];
}

function estimateDistanceMeters(a: LatLng, b: LatLng): number {
  const earthRadiusMeters = 6371000;
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);

  const haversine =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  return (
    earthRadiusMeters *
    2 *
    Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))
  );
}

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

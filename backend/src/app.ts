import Fastify, { type FastifyInstance } from "fastify";
import type { RoutingEngine } from "./engines/routing-engine.js";
import type { GeocodingService } from "./geocoding/geocoding-service.js";
import { NominatimGeocodingService } from "./geocoding/nominatim-geocoding-service.js";
import { RoutingProfileMapper } from "./profile/routing-profile-mapper.js";
import { registerGeocodeRoute } from "./routes/geocode-route.js";
import { registerRouteRoute } from "./routes/route-route.js";

type BuildAppOptions = {
  routingEngine: RoutingEngine;
  geocodingService?: GeocodingService;
  logger?: boolean;
};

export async function buildApp(
  options: BuildAppOptions,
): Promise<FastifyInstance> {
  const app = Fastify({
    logger: options.logger ?? true,
  });

  app.get("/health", async () => {
    return { status: "ok" };
  });

  await registerGeocodeRoute(app, {
    geocodingService:
      options.geocodingService ?? new NominatimGeocodingService(),
  });

  await registerRouteRoute(app, {
    routingEngine: options.routingEngine,
    profileMapper: new RoutingProfileMapper(),
  });

  return app;
}

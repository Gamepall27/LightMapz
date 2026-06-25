import type { FastifyInstance } from "fastify";
import type { GeocodingService } from "../geocoding/geocoding-service.js";

type GeocodeRouteOptions = {
  geocodingService: GeocodingService;
};

export async function registerGeocodeRoute(
  app: FastifyInstance,
  options: GeocodeRouteOptions,
): Promise<void> {
  app.get("/geocode", async (request, reply) => {
    const query = parseQuery(request.query);

    if (query === null) {
      return reply.status(400).send({
        error: "Invalid geocode request",
        details: ['Query parameter "q" is required.'],
      });
    }

    const results = await options.geocodingService.search(query);

    return reply.send({ results });
  });
}

function parseQuery(query: unknown): string | null {
  if (typeof query !== "object" || query === null || Array.isArray(query)) {
    return null;
  }

  const value = (query as Record<string, unknown>).q;

  if (typeof value !== "string" || value.trim().length < 3) {
    return null;
  }

  return value.trim();
}

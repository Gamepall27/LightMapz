import type { RouteRequest, RouteResult } from "../models/route.js";
import type {
  RoutingEngine,
  RoutingEngineContext,
} from "./routing-engine.js";

export class GraphHopperRoutingEngine implements RoutingEngine {
  async calculateRoute(
    request: RouteRequest,
    context: RoutingEngineContext,
  ): Promise<RouteResult> {
    void request;
    void context;

    throw new Error(
      "GraphHopperRoutingEngine is a placeholder. Connect the GraphHopper Route Optimization or Directions API here.",
    );
  }
}

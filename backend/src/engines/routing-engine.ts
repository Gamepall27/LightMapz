import type { RouteRequest, RouteResult } from "../models/route.js";
import type { RoutingProfileRules } from "../profile/routing-profile-mapper.js";

export type RoutingEngineContext = {
  profileRules: RoutingProfileRules;
};

export interface RoutingEngine {
  calculateRoute(
    request: RouteRequest,
    context: RoutingEngineContext,
  ): Promise<RouteResult>;
}

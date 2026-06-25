import { BRouterRoutingEngine } from "./brouter-routing-engine.js";
import { GraphHopperRoutingEngine } from "./graphhopper-routing-engine.js";
import { MockRoutingEngine } from "./mock-routing-engine.js";
import type { RoutingEngine } from "./routing-engine.js";

export type RoutingEngineName = "mock" | "graphhopper" | "brouter";

export function createRoutingEngine(name: string | undefined): RoutingEngine {
  switch ((name ?? "brouter").toLowerCase()) {
    case "graphhopper":
      return new GraphHopperRoutingEngine();
    case "brouter":
      return new BRouterRoutingEngine();
    case "mock":
      return new MockRoutingEngine();
    default:
      throw new Error(
        `Unknown ROUTING_ENGINE "${name}". Use mock, graphhopper, or brouter.`,
      );
  }
}

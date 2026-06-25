import { buildApp } from "./app.js";
import { createRoutingEngine } from "./engines/create-routing-engine.js";

const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST ?? "0.0.0.0";
const routingEngine = createRoutingEngine(process.env.ROUTING_ENGINE);

const app = await buildApp({
  routingEngine,
  logger: true,
});

try {
  await app.listen({ port, host });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}

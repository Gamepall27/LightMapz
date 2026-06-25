import assert from "node:assert/strict";
import test from "node:test";
import { RoutingProfileMapper } from "../src/profile/routing-profile-mapper.js";

test("RoutingProfileMapper maps strictness to BRouter profile names", () => {
  const mapper = new RoutingProfileMapper();

  assert.equal(mapper.mapRoadAvoidanceStrictness(0).brouterProfile, "bike_normal");
  assert.equal(mapper.mapRoadAvoidanceStrictness(25).brouterProfile, "bike_quiet");
  assert.equal(
    mapper.mapRoadAvoidanceStrictness(50).brouterProfile,
    "bike_low_traffic",
  );
  assert.equal(
    mapper.mapRoadAvoidanceStrictness(75).brouterProfile,
    "bike_avoid_roads",
  );
  assert.equal(
    mapper.mapRoadAvoidanceStrictness(100).brouterProfile,
    "bike_extreme_avoid_roads",
  );
});

test("RoutingProfileMapper prepares GraphHopper custom models", () => {
  const mapper = new RoutingProfileMapper();

  assert.equal(mapper.mapRoadAvoidanceStrictness(0).graphHopperCustomModel, null);

  const rules = mapper.mapRoadAvoidanceStrictness(100);

  assert.equal(rules.bucket, 100);
  assert.ok(rules.graphHopperCustomModel);
  assert.deepEqual(rules.graphHopperCustomModel.priority.at(-1), {
    if: "road_class == RESIDENTIAL",
    multiply_by: 1.15,
  });
});

test("RoutingProfileMapper clamps invalid values defensively", () => {
  const mapper = new RoutingProfileMapper();

  assert.equal(mapper.mapRoadAvoidanceStrictness(-10).requestedStrictness, 0);
  assert.equal(mapper.mapRoadAvoidanceStrictness(120).requestedStrictness, 100);
  assert.equal(mapper.mapRoadAvoidanceStrictness(Number.NaN).requestedStrictness, 0);
});

export type RoadAvoidanceBucket = 0 | 25 | 50 | 75 | 100;

export type BRouterProfileName =
  | "bike_normal"
  | "bike_quiet"
  | "bike_low_traffic"
  | "bike_avoid_roads"
  | "bike_extreme_avoid_roads";

export type GraphHopperCustomModel = {
  priority: Array<{
    if: string;
    multiply_by: number;
  }>;
};

export type RoutingProfileRules = {
  requestedStrictness: number;
  bucket: RoadAvoidanceBucket;
  brouterProfile: BRouterProfileName;
  graphHopperCustomModel: GraphHopperCustomModel | null;
  description: string;
};

export class RoutingProfileMapper {
  mapRoadAvoidanceStrictness(strictness: number): RoutingProfileRules {
    const clamped = this.clampStrictness(strictness);
    const bucket = this.toBucket(clamped);

    return {
      requestedStrictness: clamped,
      bucket,
      brouterProfile: this.toBRouterProfile(bucket),
      graphHopperCustomModel: this.toGraphHopperCustomModel(bucket),
      description: this.toDescription(bucket),
    };
  }

  clampStrictness(strictness: number): number {
    if (!Number.isFinite(strictness)) {
      return 0;
    }

    return Math.min(100, Math.max(0, Math.round(strictness)));
  }

  private toBucket(strictness: number): RoadAvoidanceBucket {
    if (strictness <= 12) {
      return 0;
    }
    if (strictness <= 37) {
      return 25;
    }
    if (strictness <= 62) {
      return 50;
    }
    if (strictness <= 87) {
      return 75;
    }

    return 100;
  }

  private toBRouterProfile(bucket: RoadAvoidanceBucket): BRouterProfileName {
    switch (bucket) {
      case 0:
        return "bike_normal";
      case 25:
        return "bike_quiet";
      case 50:
        return "bike_low_traffic";
      case 75:
        return "bike_avoid_roads";
      case 100:
        return "bike_extreme_avoid_roads";
    }
  }

  private toGraphHopperCustomModel(
    bucket: RoadAvoidanceBucket,
  ): GraphHopperCustomModel | null {
    switch (bucket) {
      case 0:
        return null;
      case 25:
        return {
          priority: [
            { if: "road_class == PRIMARY", multiply_by: 0.8 },
            { if: "road_class == SECONDARY", multiply_by: 0.85 },
          ],
        };
      case 50:
        return {
          priority: [
            { if: "road_class == PRIMARY", multiply_by: 0.45 },
            { if: "road_class == SECONDARY", multiply_by: 0.55 },
            { if: "road_class == TERTIARY", multiply_by: 0.7 },
            { if: "road_class == CYCLEWAY", multiply_by: 1.2 },
          ],
        };
      case 75:
        return {
          priority: [
            { if: "road_class == PRIMARY", multiply_by: 0.15 },
            { if: "road_class == SECONDARY", multiply_by: 0.25 },
            { if: "road_class == TERTIARY", multiply_by: 0.4 },
            { if: "road_class == TRUNK", multiply_by: 0.05 },
            { if: "road_class == CYCLEWAY", multiply_by: 1.35 },
            { if: "road_class == PATH", multiply_by: 1.25 },
          ],
        };
      case 100:
        return {
          priority: [
            { if: "road_class == TRUNK", multiply_by: 0.01 },
            { if: "road_class == PRIMARY", multiply_by: 0.03 },
            { if: "road_class == SECONDARY", multiply_by: 0.08 },
            { if: "road_class == TERTIARY", multiply_by: 0.18 },
            { if: "road_class == CYCLEWAY", multiply_by: 1.5 },
            { if: "road_class == PATH", multiply_by: 1.4 },
            { if: "road_class == TRACK", multiply_by: 1.3 },
            { if: "road_class == SERVICE", multiply_by: 1.15 },
            { if: "road_class == RESIDENTIAL", multiply_by: 1.15 },
          ],
        };
    }
  }

  private toDescription(bucket: RoadAvoidanceBucket): string {
    switch (bucket) {
      case 0:
        return "Standard bike profile";
      case 25:
        return "Leichtes Penalty fuer primary/secondary roads";
      case 50:
        return "Starkes Penalty fuer primary/secondary/tertiary roads";
      case 75:
        return "Sehr starkes Penalty fuer alle groesseren Strassen";
      case 100:
        return "Maximale Vermeidung von Strassen mit hohem motorisiertem Verkehr";
    }
  }
}

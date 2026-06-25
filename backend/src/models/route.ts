export type LatLng = {
  lat: number;
  lng: number;
};

export type BikeProfile = "bike";

export type RouteRequest = {
  start: LatLng;
  destination: LatLng;
  profile: BikeProfile;
  roadAvoidanceStrictness: number;
};

export type RouteSegment = {
  distanceMeters: number;
  surface: string;
  wayType: string;
  roadClass: string;
};

export type RouteResult = {
  geometry: LatLng[];
  distanceMeters: number;
  durationSeconds: number;
  roadSharePercent: number;
  cyclewaySharePercent: number;
  pathSharePercent: number;
  warnings: string[];
  segments: RouteSegment[];
};

import type { GeocodeResult } from "../models/geocode.js";

export interface GeocodingService {
  search(query: string): Promise<GeocodeResult[]>;
}

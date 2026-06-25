import type { GeocodeResult } from "../models/geocode.js";
import type { GeocodingService } from "./geocoding-service.js";

type NominatimSearchResult = {
  display_name?: string;
  lat?: string;
  lon?: string;
};

export class NominatimGeocodingService implements GeocodingService {
  constructor(
    private readonly baseUrl = "https://nominatim.openstreetmap.org",
  ) {}

  async search(query: string): Promise<GeocodeResult[]> {
    const url = new URL("/search", this.baseUrl);
    url.searchParams.set("q", query);
    url.searchParams.set("format", "jsonv2");
    url.searchParams.set("limit", "5");
    url.searchParams.set("addressdetails", "1");

    const response = await fetch(url, {
      headers: {
        "User-Agent": "LightMapz/0.1 local development",
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      throw new Error(`Nominatim request failed with ${response.status}`);
    }

    const json = (await response.json()) as NominatimSearchResult[];

    return json
      .map((item) => {
        const lat = Number(item.lat);
        const lng = Number(item.lon);

        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
          return null;
        }

        return {
          label: item.display_name ?? query,
          point: { lat, lng },
        };
      })
      .filter((item): item is GeocodeResult => item !== null);
  }
}

import 'models/geocode_result.dart';

abstract class GeocodingService {
  Future<List<GeocodeResult>> search(String query);
}

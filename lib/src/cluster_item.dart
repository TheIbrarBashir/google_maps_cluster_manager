import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

mixin ClusterItem {
  LatLng get location;

  String? _geoHash;
  String get geoHash => _geoHash ??=
      GeoHash.encode(location, codeLength: MapClusterManager.precision);
}

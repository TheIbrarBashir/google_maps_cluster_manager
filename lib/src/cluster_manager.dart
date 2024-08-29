// import 'dart:math';
// import 'dart:ui';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
// import 'package:google_maps_cluster_manager/src/max_dist_clustering.dart';
// import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
//
// enum ClusterAlgorithm { GEOHASH, MAX_DIST }
//
// class MaxDistParams {
//   final double epsilon;
//
//   MaxDistParams(this.epsilon);
// }
//
// class MapClusterManager<T extends ClusterItem> {
//   MapClusterManager(this._items, this.updateMarkers,
//       {Future<Marker> Function(MapCluster<T>)? markerBuilder,
//         this.levels = const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
//         this.extraPercent = 0.5,
//         this.maxItemsForMaxDistAlgo = 200,
//         this.clusterAlgorithm = ClusterAlgorithm.GEOHASH,
//         this.maxDistParams,
//         this.stopClusteringZoom,
//         this.minCountForClustering,
//         this.minClusterSize = 10})  // Default to 10
//       : this.markerBuilder = markerBuilder ?? _basicMarkerBuilder,
//         assert(levels.length <= precision);
//
//   /// Method to build markers
//   final Future<Marker> Function(MapCluster<T>) markerBuilder;
//
//   // Num of Items to switch from MAX_DIST algo to GEOHASH
//   final int maxItemsForMaxDistAlgo;
//
//   /// Function to update Markers on Google Map
//   final void Function(Set<Marker>) updateMarkers;
//
//   /// Zoom levels configuration
//   final List<double> levels;
//
//   /// Extra percent of markers to be loaded (ex : 0.2 for 20%)
//   final double extraPercent;
//
//   // Clustering algorithm
//   final ClusterAlgorithm clusterAlgorithm;
//
//   final MaxDistParams? maxDistParams;
//
//   /// Zoom level to stop cluster rendering
//   final double? stopClusteringZoom;
//
//   final int? minCountForClustering;
//
//   /// Minimum cluster size to display as individual markers
//   final int minClusterSize;
//
//   /// Precision of the geoHash
//   static final int precision = kIsWeb ? 12 : 20;
//
//   /// Google Maps map id
//   int? _mapId;
//
//   /// List of items
//   Iterable<T> get items => _items;
//   Iterable<T> _items;
//
//   /// Last known zoom
//   late double _zoom;
//
//   final double _maxLng = 180 - pow(10, -10.0) as double;
//
//   /// Set Google Map Id for the cluster manager
//   void setMapId(int mapId, {bool withUpdate = true}) async {
//     _mapId = mapId;
//     _zoom = await GoogleMapsFlutterPlatform.instance.getZoomLevel(mapId: mapId);
//     if (withUpdate) updateMap();
//   }
//
//   /// Method called on map update to update cluster. Can also be manually called to force update.
//   void updateMap() {
//     _updateClusters();
//   }
//
//   void _updateClusters() async {
//     List<MapCluster<T>> mapMarkers = await getMarkers();
//
//     final Set<Marker> markers =
//     Set.from(await Future.wait(mapMarkers.map((m) => markerBuilder(m))));
//
//     updateMarkers(markers);
//   }
//
//   /// Update all cluster items
//   void setItems(List<T> newItems) {
//     _items = newItems;
//     updateMap();
//   }
//
//   /// Add on cluster item
//   void addItem(ClusterItem newItem) {
//     _items = List.from([...items, newItem]);
//     updateMap();
//   }
//
//   /// Method called on camera move
//   void onCameraMove(CameraPosition position, {forceUpdate = false}) {
//     _zoom = position.zoom;
//     if (forceUpdate) {
//       updateMap();
//     }
//   }
//
//   /// Retrieve cluster markers
//   Future<List<MapCluster<T>>> getMarkers() async {
//     if (_mapId == null) return List.empty();
//
//     final LatLngBounds mapBounds = await GoogleMapsFlutterPlatform.instance
//         .getVisibleRegion(mapId: _mapId!);
//
//     late LatLngBounds inflatedBounds;
//     if (clusterAlgorithm == ClusterAlgorithm.GEOHASH) {
//       inflatedBounds = _inflateBounds(mapBounds);
//     } else {
//       inflatedBounds = mapBounds;
//     }
//
//     List<T> visibleItems = items.where((i) {
//       return inflatedBounds.contains(i.location);
//     }).toList();
//
//     if (stopClusteringZoom != null && _zoom >= stopClusteringZoom!)
//       return visibleItems.map((i) => MapCluster<T>.fromItems([i])).toList();
//
//     if (minCountForClustering != null &&
//         _items.length <= minCountForClustering!)
//       return visibleItems.map((i) => MapCluster<T>.fromItems([i])).toList();
//
//     List<MapCluster<T>> markers;
//
//     if (clusterAlgorithm == ClusterAlgorithm.GEOHASH ||
//         visibleItems.length >= maxItemsForMaxDistAlgo) {
//       int level = _findLevel(levels);
//       markers = _computeClusters(visibleItems, List.empty(growable: true),
//           level: level);
//     } else {
//       markers = _computeClustersWithMaxDist(visibleItems, _zoom);
//     }
//
//     return markers;
//   }
//
//   LatLngBounds _inflateBounds(LatLngBounds bounds) {
//     // Bounds that cross the date line expand compared to their difference with the date line
//     double lng = 0;
//     if (bounds.northeast.longitude < bounds.southwest.longitude) {
//       lng = extraPercent *
//           ((180.0 - bounds.southwest.longitude) +
//               (bounds.northeast.longitude + 180));
//     } else {
//       lng = extraPercent *
//           (bounds.northeast.longitude - bounds.southwest.longitude);
//     }
//
//     // Latitudes expanded beyond +/- 90 are automatically clamped by LatLng
//     double lat =
//         extraPercent * (bounds.northeast.latitude - bounds.southwest.latitude);
//
//     double eLng = (bounds.northeast.longitude + lng).clamp(-_maxLng, _maxLng);
//     double wLng = (bounds.southwest.longitude - lng).clamp(-_maxLng, _maxLng);
//
//     return LatLngBounds(
//       southwest: LatLng(bounds.southwest.latitude - lat, wLng),
//       northeast:
//       LatLng(bounds.northeast.latitude + lat, lng != 0 ? eLng : _maxLng),
//     );
//   }
//
//   int _findLevel(List<double> levels) {
//     for (int i = levels.length - 1; i >= 0; i--) {
//       if (levels[i] <= _zoom) {
//         return i + 1;
//       }
//     }
//
//     return 1;
//   }
//
//   int _getZoomLevel(double zoom) {
//     for (int i = levels.length - 1; i >= 0; i--) {
//       if (levels[i] <= zoom) {
//         return levels[i].toInt();
//       }
//     }
//
//     return 1;
//   }
//
//   List<MapCluster<T>> _computeClustersWithMaxDist(
//       List<T> inputItems, double zoom) {
//     MaxDistClustering<T> scanner = MaxDistClustering(
//       epsilon: maxDistParams?.epsilon ?? 20,
//     );
//
//     List<MapCluster<T>> clusters = scanner.run(inputItems, _getZoomLevel(zoom));
//
//     // Break clusters with fewer items than minClusterSize
//     List<MapCluster<T>> resultClusters = [];
//     for (var cluster in clusters) {
//       if (cluster.items.length < minClusterSize) {
//         resultClusters.addAll(cluster.items.map((item) => MapCluster<T>.fromItems([item])));
//       } else {
//         resultClusters.add(cluster);
//       }
//     }
//
//     return resultClusters;
//   }
//
//   List<MapCluster<T>> _computeClusters(
//       List<T> inputItems, List<MapCluster<T>> markerItems,
//       {int level = 5}) {
//     if (inputItems.isEmpty) return markerItems;
//     String nextGeohash = inputItems[0].geoHash.substring(0, level);
//
//     List<T> items = inputItems
//         .where((p) => p.geoHash.substring(0, level) == nextGeohash)
//         .toList();
//
//     // If the cluster has fewer items than minClusterSize, break it
//     if (items.length < minClusterSize) {
//       markerItems.addAll(items.map((item) => MapCluster<T>.fromItems([item])));
//     } else {
//       markerItems.add(MapCluster<T>.fromItems(items));
//     }
//
//     List<T> newInputList = List.from(
//         inputItems.where((i) => i.geoHash.substring(0, level) != nextGeohash));
//
//     return _computeClusters(newInputList, markerItems, level: level);
//   }
//
//   static Future<Marker> Function(MapCluster) get _basicMarkerBuilder =>
//           (cluster) async {
//         return Marker(
//           markerId: MarkerId(cluster.getId()),
//           position: cluster.location,
//           onTap: () {
//             print(cluster);
//           },
//           icon: await _getBasicClusterBitmap(cluster.isMultiple ? 125 : 75,
//               text: cluster.isMultiple ? cluster.count.toString() : null),
//         );
//       };
//
//   static Future<BitmapDescriptor> _getBasicClusterBitmap(int size,
//       {String? text}) async {
//     final PictureRecorder pictureRecorder = PictureRecorder();
//     final Canvas canvas = Canvas(pictureRecorder);
//     final Paint paint1 = Paint()..color = Colors.red;
//
//     canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint1);
//
//     if (text != null) {
//       TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
//       painter.text = TextSpan(
//         text: text,
//         style: TextStyle(
//             fontSize: size / 3,
//             color: Colors.white,
//             fontWeight: FontWeight.normal),
//       );
//       painter.layout();
//       painter.paint(
//         canvas,
//         Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2),
//       );
//     }
//
//     final img = await pictureRecorder.endRecording().toImage(size, size);
//     final data = await img.toByteData(format: ImageByteFormat.png) as ByteData;
//
//     return BitmapDescriptor.bytes(data.buffer.asUint8List());
//   }
// }
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'package:google_maps_cluster_manager/src/max_dist_clustering.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

enum ClusterAlgorithm { GEO_HASH, MAX_DIST }

class MaxDistParams {
  final double epsilon;

  MaxDistParams(this.epsilon);
}

class MapClusterManager<T extends ClusterItem> {
  MapClusterManager(this._items, this.updateMarkers,
      {Future<Marker> Function(MapCluster<T>)? markerBuilder,
        this.levels = const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
        this.extraPercent = 0.5,
        this.maxItemsForMaxDistAlgo = 200,
        this.clusterAlgorithm = ClusterAlgorithm.GEO_HASH,
        this.maxDistParams,
        this.stopClusteringZoom,
        this.minCountForClustering,
        this.minClusterSize = 10})  // Default to 10
      : this.markerBuilder = markerBuilder ?? _basicMarkerBuilder,
        assert(levels.length <= precision);

  /// Method to build markers
  final Future<Marker> Function(MapCluster<T>) markerBuilder;

  // Num of Items to switch from MAX_DIST algo to GEOHASH
  final int maxItemsForMaxDistAlgo;

  /// Function to update Markers on Google Map
  final void Function(Set<Marker>) updateMarkers;

  /// Zoom levels configuration
  final List<double> levels;

  /// Extra percent of markers to be loaded (ex : 0.2 for 20%)
  final double extraPercent;

  // Clustering algorithm
  final ClusterAlgorithm clusterAlgorithm;

  final MaxDistParams? maxDistParams;

  /// Zoom level to stop cluster rendering
  final double? stopClusteringZoom;

  final int? minCountForClustering;

  /// Minimum cluster size to display as individual markers
  final int minClusterSize;

  /// Precision of the geoHash
  static final int precision = kIsWeb ? 12 : 20;

  /// Google Maps map id
  int? _mapId;

  /// List of items
  Iterable<T> get items => _items;
  Iterable<T> _items;

  /// Last known zoom
  late double _zoom;

  final double _maxLng = 180 - pow(10, -10.0) as double;

  /// Set Google Map Id for the cluster manager
  void setMapId(int mapId, {bool withUpdate = true}) async {
    _mapId = mapId;
    _zoom = await GoogleMapsFlutterPlatform.instance.getZoomLevel(mapId: mapId);
    if (withUpdate) updateMap();
  }

  /// Method called on map update to update cluster. Can also be manually called to force update.
  void updateMap() {
    _updateClusters();
  }

  void _updateClusters() async {
    List<MapCluster<T>> mapMarkers = await getMarkers();

    final Set<Marker> markers =
    Set.from(await Future.wait(mapMarkers.map((m) => markerBuilder(m))));

    updateMarkers(markers);
  }

  /// Update all cluster items
  void setItems(List<T> newItems) {
    _items = newItems;
    updateMap();
  }

  /// Add on cluster item
  void addItem(ClusterItem newItem) {
    _items = List.from([...items, newItem]);
    updateMap();
  }

  /// Method called on camera move
  void onCameraMove(CameraPosition position, {forceUpdate = false}) {
    _zoom = position.zoom;
    if (forceUpdate) {
      updateMap();
    }
  }

  /// Retrieve cluster markers
  Future<List<MapCluster<T>>> getMarkers() async {
    if (_mapId == null) return List.empty();

    final LatLngBounds mapBounds = await GoogleMapsFlutterPlatform.instance
        .getVisibleRegion(mapId: _mapId!);

    late LatLngBounds inflatedBounds;
    if (clusterAlgorithm == ClusterAlgorithm.GEO_HASH) {
      inflatedBounds = _inflateBounds(mapBounds);
    } else {
      inflatedBounds = mapBounds;
    }

    List<T> visibleItems = items.where((i) {
      return inflatedBounds.contains(i.location);
    }).toList();

    if (stopClusteringZoom != null && _zoom >= stopClusteringZoom!)
      return visibleItems.map((i) => MapCluster<T>.fromItems([i].toList())).toList();

    if (minCountForClustering != null &&
        _items.length <= minCountForClustering!)
      return visibleItems.map((i) => MapCluster<T>.fromItems([i].toList())).toList();

    List<MapCluster<T>> markers;

    if (clusterAlgorithm == ClusterAlgorithm.GEO_HASH ||
        visibleItems.length >= maxItemsForMaxDistAlgo) {
      int level = _findLevel(levels);
      markers = _computeClusters(visibleItems.toList(), List.empty(growable: true),
          level: level);
    } else {
      markers = _computeClustersWithMaxDist(visibleItems.toList(), _zoom);
    }

    return markers;
  }

  LatLngBounds _inflateBounds(LatLngBounds bounds) {
    // Bounds that cross the date line expand compared to their difference with the date line
    double lng = 0;
    if (bounds.northeast.longitude < bounds.southwest.longitude) {
      lng = extraPercent *
          ((180.0 - bounds.southwest.longitude) +
              (bounds.northeast.longitude + 180));
    } else {
      lng = extraPercent *
          (bounds.northeast.longitude - bounds.southwest.longitude);
    }

    // Latitudes expanded beyond +/- 90 are automatically clamped by LatLng
    double lat =
        extraPercent * (bounds.northeast.latitude - bounds.southwest.latitude);

    double eLng = (bounds.northeast.longitude + lng).clamp(-_maxLng, _maxLng);
    double wLng = (bounds.southwest.longitude - lng).clamp(-_maxLng, _maxLng);

    return LatLngBounds(
      southwest: LatLng(bounds.southwest.latitude - lat, wLng),
      northeast:
      LatLng(bounds.northeast.latitude + lat, lng != 0 ? eLng : _maxLng),
    );
  }

  int _findLevel(List<double> levels) {
    for (int i = levels.length - 1; i >= 0; i--) {
      if (levels[i] <= _zoom) {
        return i + 1;
      }
    }

    return 1;
  }

  int _getZoomLevel(double zoom) {
    for (int i = levels.length - 1; i >= 0; i--) {
      if (levels[i] <= zoom) {
        return levels[i].toInt();
      }
    }

    return 1;
  }

  List<MapCluster<T>> _computeClustersWithMaxDist(
      List<T> inputItems, double zoom) {
    MaxDistClustering<T> scanner = MaxDistClustering(
      epsilon: maxDistParams?.epsilon ?? 20,
    );

    List<MapCluster<T>> clusters = scanner.run(inputItems, _getZoomLevel(zoom));

    // Check if zoom level is between 12 and 14.4 and handle sub-clustering
    if (_zoom >= 12.0 && _zoom <= 14.4) {
      List<MapCluster<T>> subClusters = [];
      for (var cluster in clusters) {
        if (cluster.items.length > minClusterSize) {
          subClusters.addAll(_breakIntoSubClusters(cluster.items.toList()));
        } else {
          subClusters.add(cluster);
        }
      }
      return subClusters;
    } else {
      // Break clusters with fewer items than minClusterSize
      List<MapCluster<T>> resultClusters = [];
      for (var cluster in clusters) {
        if (cluster.items.length < minClusterSize) {
          resultClusters.addAll(cluster.items.map((item) => MapCluster<T>.fromItems([item].toList())));
        } else {
          resultClusters.add(cluster);
        }
      }
      return resultClusters;
    }
  }

  List<MapCluster<T>> _computeClusters(
      List<T> inputItems, List<MapCluster<T>> markerItems,
      {int level = 5}) {
    if (inputItems.isEmpty) return markerItems;
    String nextGeohash = inputItems[0].geoHash.substring(0, level);

    List<T> items = inputItems
        .where((p) => p.geoHash.substring(0, level) == nextGeohash)
        .toList();

    // Check if zoom level is between 12 and 14.4 and handle sub-clustering
    if (_zoom >= 12.5 && _zoom <= 14.4 && items.length > minClusterSize) {
      markerItems.addAll(_breakIntoSubClusters(items));
    } else {
      // If the cluster has fewer items than minClusterSize, break it
      if (items.length < minClusterSize) {
        markerItems.addAll(items.map((item) => MapCluster<T>.fromItems([item].toList())));
      } else {
        markerItems.add(MapCluster<T>.fromItems(items));
      }
    }

    List<T> newInputList = List.from(
        inputItems.where((i) => i.geoHash.substring(0, level) != nextGeohash));

    return _computeClusters(newInputList, markerItems, level: level);
  }

  List<MapCluster<T>> _breakIntoSubClusters(List<T> items) {
    // Implement logic to break a large cluster into smaller sub-clusters
    // For simplicity, you can divide the items into batches and create clusters for each batch
    List<MapCluster<T>> subClusters = [];
    int batchSize = (items.length / 3).ceil(); // Example: create 3 sub-clusters
    for (int i = 0; i < items.length; i += batchSize) {
      List<T> batch = items.sublist(i, min(i + batchSize, items.length));
      subClusters.add(MapCluster<T>.fromItems(batch));
    }
    return subClusters;
  }

  static Future<Marker> Function(MapCluster) get _basicMarkerBuilder =>
          (cluster) async {
        return Marker(
          markerId: MarkerId(cluster.getId()),
          position: cluster.location,
          onTap: () {
            print(cluster);
          },
          icon: await _getBasicClusterBitmap(cluster.isMultiple ? 125 : 75,
              text: cluster.isMultiple ? cluster.count.toString() : null),
        );
      };

  static Future<BitmapDescriptor> _getBasicClusterBitmap(int size,
      {String? text}) async {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint1 = Paint()..color = Colors.red;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint1);

    if (text != null) {
      TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
      painter.text = TextSpan(
        text: text,
        style: TextStyle(
            fontSize: size / 3,
            color: Colors.white,
            fontWeight: FontWeight.normal),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2),
      );
    }

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ImageByteFormat.png) as ByteData;

    return BitmapDescriptor.bytes(data.buffer.asUint8List());
  }
}
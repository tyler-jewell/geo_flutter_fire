import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapPage extends StatelessWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: FireMap(),
    );
  }
}

class FireMap extends StatefulWidget {
  const FireMap({Key? key}) : super(key: key);

  @override
  State<FireMap> createState() => _FireMapState();
}

class _FireMapState extends State<FireMap> {
  GoogleMapController? mapController;
  Location location = Location();
  Set<Polygon> polygons = <Polygon>{};
  Set<Polyline> polylines = <Polyline>{};

  double? latitude;
  double? longitude;

  bool addingPolyline = false;

  late Stream<List<DocumentSnapshot>> stream;
  late Geoflutterfire geo;
  late FirebaseFirestore firestore;

  Future<BitmapDescriptor> get markerIcon {
    return BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/marker_circle.png',
    );
  }

  @override
  void initState() {
    geo = Geoflutterfire();
    firestore = FirebaseFirestore.instance;
    _getUserLocation();
    _getPolygons();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if ((latitude != null) & (longitude != null))
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(latitude!, longitude!),
              zoom: 15,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            mapType: MapType.hybrid,
            polylines: polylines,
            polygons: polygons,
            onTap: addingPolyline ? _addPolylinePoint : null,
          )
        else
          Container(),
        Positioned(
          bottom: 50,
          left: 10,
          child: FloatingActionButton(
            onPressed: _addPolyline,
            child: const Icon(Icons.add),
          ),
        ),
        Positioned(
          bottom: 50,
          left: 70,
          child: FloatingActionButton(
            onPressed: _removeAllMarkers,
            child: const Icon(Icons.delete),
          ),
        ),
        Positioned(
          bottom: 50,
          left: 130,
          child: FloatingActionButton(
            onPressed: _resetPolyline,
            child: const Icon(Icons.refresh),
          ),
        ),
        Positioned(
          bottom: 50,
          left: 190,
          child: FloatingActionButton(
            onPressed: _addPolygonToFirestore,
            child: const Icon(Icons.check),
          ),
        ),
      ],
    );
  }

  void _addPolylinePoint(LatLng latLng) {
    setState(() {
      polylines = {
        polylines.first.copyWith(
          pointsParam: List.from(polylines.first.points)..add(latLng),
        ),
      };
    });
  }

  void _addPolyline() {
    setState(() {
      addingPolyline = true;
      polylines.add(
        const Polyline(
          polylineId: PolylineId('polyline-1'),
          width: 3,
          color: Colors.blue,
        ),
      );
    });
  }

  Future<void> _getUserLocation() async {
    final _userLocation = await location.getLocation();

    setState(() {
      latitude = _userLocation.latitude;
      longitude = _userLocation.longitude;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  Future<void> _removeAllMarkers() async {}

  void _addPolygon() {
    final polygon = Polygon(
      polygonId: const PolygonId('polygon-1'),
      points: polylines.first.points,
      strokeWidth: 3,
      fillColor: Colors.green.withOpacity(0.2),
      strokeColor: Colors.green,
    );
    setState(() {
      polylines = {};
      polygons = {polygon};
    });
  }

  void _resetPolyline() {
    setState(() {
      polylines = <Polyline>{};
      polygons = <Polygon>{};
    });
  }

  Future<void> _addPolygonToFirestore() async {
    _addPolygon();

    final ref = firestore.collection('polygons');

    final geoRef = geo.collection(collectionRef: ref);

    final toAddPolygon = polygons.first;

    var order = 0;
    for (final point in toAddPolygon.points) {
      final pointLatLng = LatLng(point.latitude, point.longitude);
      final pointGeoPoint = geo.point(
        latitude: pointLatLng.latitude,
        longitude: pointLatLng.longitude,
      );

      await geoRef.add(<String, dynamic>{
        'order': order,
        'polygonId': 'polygon-1',
        'point': pointGeoPoint.data,
      });

      order += 1;
    }
  }

  Future<void> _getPolygons() async {
    final queryRef = firestore
        .collection('polygons')
        .where(
          'polygonId',
          isEqualTo: 'polygon-1',
        )
        .orderBy('order');
    final center = GeoFirePoint(40.51287558, -104.95347124);
    final stream = geo.collection(collectionRef: queryRef).within(
          center: center,
          radius: 1000,
          field: 'point',
        );

    await queryRef.get().then((value) => print(value.docs.length));

    await stream.forEach((snapshot) {
      print(snapshot.length);
      var polygonPoints = <LatLng>[];
      snapshot.forEach((doc) {
        print(doc.data());
        final geoFirePoint = doc.data()!['point']['geopoint'] as GeoPoint;
        polygonPoints.add(
          LatLng(
            geoFirePoint.latitude,
            geoFirePoint.longitude,
          ),
        );
      });
      setState(() {
        polygons = {
          Polygon(
            polygonId: const PolygonId('polygon-1'),
            points: polygonPoints,
            strokeWidth: 3,
            fillColor: Colors.green.withOpacity(0.2),
            strokeColor: Colors.green,
          ),
        };
      });
    });
  }
}

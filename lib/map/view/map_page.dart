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

  FirebaseFirestore firestore = FirebaseFirestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  double? latitude;
  double? longitude;

  bool addingPolygon = false;

  @override
  void initState() {
    _getUserLocation();

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
            polygons: polygons,
            onTap: addingPolygon ? _addPolygonPoint : null,
          )
        else
          Container(),
        Positioned(
          bottom: 50,
          left: 10,
          child: FloatingActionButton(
            onPressed: _addPolygon,
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
            onPressed: _resetPolygon,
            child: const Icon(Icons.refresh),
          ),
        ),
        Positioned(
          bottom: 50,
          left: 200,
          child: FloatingActionButton(
            onPressed: _addPolygonToFirestore,
            child: const Icon(Icons.check),
          ),
        ),
      ],
    );
  }

  void _addPolygonPoint(LatLng latLng) {
    setState(() {
      polygons = {
        polygons.first.copyWith(
          pointsParam: List.from(polygons.first.points)..add(latLng),
        ),
      };
    });
  }

  void _addPolygon() {
    setState(() {
      addingPolygon = true;
      polygons.add(const Polygon(polygonId: PolygonId('polygon-1')));
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

  void _removeAllMarkers() {
    final ref = firestore.collection('locations');

    ref.get().then((snapshot) {
      for (final doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
  }

  void _resetPolygon() {
    setState(() {
      polygons = <Polygon>{};
    });
  }

  void _addPolygonToFirestore() {
    final ref = firestore.collection('polygons');

    final polygonPoints = polygons.first.points;

    final polygon = geo.point(
      latitude: polygonPoints.first.latitude,
      longitude: polygonPoints.first.longitude,
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:rxdart/rxdart.dart';

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
  Set<Marker> markers = <Marker>{};
  Location location = Location();

  FirebaseFirestore firestore = FirebaseFirestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  BehaviorSubject<double> radius = BehaviorSubject();

  late Stream<dynamic> query;
  late StreamSubscription subscription;

  @override
  Widget build(BuildContext context) {
    print(markers.length);
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(24.142, -110.321),
            zoom: 15,
          ),
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          mapType: MapType.hybrid,
          onCameraMove: _onCameraMove,
          markers: markers,
        ),
        Positioned(
          bottom: 50,
          left: 10,
          child: TextButton(
            onPressed: _addGeoPoint,
            child: const Icon(Icons.pin_drop, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: 50,
          right: 100,
          child: Slider(
            activeColor: Colors.green,
            inactiveColor: Colors.green.withOpacity(0.2),
            divisions: 4,
            value: radius.hasValue ? radius.value : 100,
            onChanged: _updateQuery,
            min: 100,
            max: 500,
            label: 'Radius ${radius.hasValue ? radius.value : 100}km',
          ),
        ),
      ],
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _startQuery();
    setState(() {
      mapController = controller;
    });
  }

  void _onCameraMove(CameraPosition position) {}

  Future<DocumentReference> _addGeoPoint() async {
    final position = await location.getLocation();
    final point = geo.point(
      latitude: position.latitude!,
      longitude: position.longitude!,
    );
    return firestore.collection('locations').add(<String, dynamic>{
      'point': point.data,
      'name': 'Yay I can be queried',
    });
  }

  void _updateMarkers(List<DocumentSnapshot<Map<String, dynamic>>> documents) {
    print('updating markers');

    setState(() {
      print('setting state');
      markers = documents
          .map(
            (document) => Marker(
              markerId: MarkerId(document.id),
              position: LatLng(
                // ignore: avoid_dynamic_calls
                document.data()!['point']['geopoint'].latitude as double,
                // ignore: avoid_dynamic_calls
                document.data()!['point']['geopoint'].longitude as double,
              ),
              infoWindow: InfoWindow(
                title: document.data()!['name'] as String,
              ),
            ),
          )
          .toSet();
    });
  }

  Future<void> _startQuery() async {
    final position = await location.getLocation();

    final ref = firestore.collection('locations');

    final center = geo.point(
      latitude: position.latitude!,
      longitude: position.longitude!,
    );

    subscription = radius.switchMap((rad) {
      return geo
          .collection(collectionRef: ref)
          .within(center: center, radius: rad, field: 'point');
    }).listen(_updateMarkers);
  }

  void _updateQuery(double value) {
    setState(() {
      radius.add(value);
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}

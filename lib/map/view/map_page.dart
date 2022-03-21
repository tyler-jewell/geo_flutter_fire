import 'dart:async';
import 'dart:math';

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

  BehaviorSubject<double> radius = BehaviorSubject.seeded(5);

  double? latitude;
  double? longitude;

  late Stream<dynamic> query;
  late StreamSubscription subscription;

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
            markers: markers,
            polygons: _getPolygons(),
          )
        else
          Container(),
        Positioned(
          bottom: 50,
          left: 10,
          child: FloatingActionButton(
            onPressed: _addGeoPoint,
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
          right: 100,
          child: Slider(
            activeColor: Colors.green,
            inactiveColor: Colors.green.withOpacity(0.2),
            divisions: 4,
            value: radius.value,
            onChanged: _updateQuery,
            min: 1,
            max: 20,
            label: 'Radius ${radius.value}km',
          ),
        ),
      ],
    );
  }

  Future<void> _getUserLocation() async {
    final _userLocation = await location.getLocation();

    setState(() {
      latitude = _userLocation.latitude;
      longitude = _userLocation.longitude;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    location.onLocationChanged.listen(
      (locationData) {
        final userLocation = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: userLocation,
              zoom: 15,
            ),
          ),
        );
      },
    );

    _startQuery();

    setState(() {
      mapController = controller;
    });
  }

  Future<DocumentReference> _addGeoPoint() async {
    final random = Random();
    final position = await mapController!.getLatLng(
      ScreenCoordinate(
        x: random.nextInt(1000),
        y: random.nextInt(1000),
      ),
    );
    final point = geo.point(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    return firestore.collection('locations').add(<String, dynamic>{
      'point': point.data,
      'name': 'Yay I can be queried',
    });
  }

  void _updateMarkers(List<DocumentSnapshot<Map<String, dynamic>>> documents) {
    setState(() {
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

  void _removeAllMarkers() {
    final ref = firestore.collection('locations');

    ref.get().then((snapshot) {
      for (final doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
  }

  Set<Polygon> _getPolygons() {
    return <Polygon>{
      Polygon(
        polygonId: const PolygonId('polygon'),
        points: <LatLng>[
          LatLng(latitude!, longitude!),
          LatLng(latitude! + 0.001, longitude!),
          LatLng(latitude! + 0.001, longitude! + 0.001),
          LatLng(latitude!, longitude! + 0.001),
        ],
        strokeColor: Colors.green,
        strokeWidth: 5,
        fillColor: Colors.green.withOpacity(0.2),
      ),
    };
  }
}

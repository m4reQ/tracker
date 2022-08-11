import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HomePageState();
  }
}

class HomePageState extends State<HomePage> {
  GoogleMapController? _mapController;
  double _currentSpeed = 0.0;
  double _distanceTravelled = 0.0;
  LatLng? _currentLocation;
  bool _routeStarted = false;
  GoogleMap? _map;
  final Set<Marker> _markers = {};
  final List<LatLng> _routePoints = [];
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _googleMapBuilder(),
          TextButton(
              onPressed: () {
                if (_currentLocation == null) {
                  return;
                }

                if (_routeStarted) {
                  setState(() {
                    _routeStarted = false;
                    _markers.add(_createMarker('end', _currentLocation!));
                  });
                  return;
                }

                setState(() {
                  _routeStarted = true;
                  _routePoints.clear();
                  _routePoints.add(_currentLocation!);
                  _markers.clear();
                  _markers.add(_createMarker('start', _currentLocation!));
                });
              },
              child: Text(_routeStarted ? 'Stop' : 'Start')),
          Text('${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h',
              style: Theme.of(context)
                  .textTheme
                  .bodyText1!
                  .copyWith(fontSize: 42.0)),
          Text(
              'Distance travelled: ${(_distanceTravelled / 1000.0).toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.bodyText1),
        ],
      ),
    );
  }

  FutureBuilder _googleMapBuilder() {
    return FutureBuilder<LocationData>(
      future: _getInitialLocation(),
      builder: (_, snapshot) {
        if (snapshot.hasData) {
          _map = GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _locationDataToLatLng(snapshot.data!)),
            onMapCreated: (controller) {
              _mapController = controller;
              _currentLocation = _locationDataToLatLng(snapshot.data!);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.hybrid,
            markers: _markers,
            polylines: {_getCurrentRoute()},
            zoomControlsEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(17.0, 30.0),
          );
          return Expanded(child: _map!);
        } else if (snapshot.hasError) {
          return Text('Cannot load map:\n${snapshot.error!.toString()}');
        }

        return Expanded(
          child: Center(
            child: Column(
              children: const [
                Text('Loading map...'),
                CircularProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onLocationChanged(LocationData data) {
    _mapController
        ?.animateCamera(CameraUpdate.newLatLng(_locationDataToLatLng(data)));
    setState(() {
      _currentSpeed = data.speed ?? 0.0;
      _currentLocation = _locationDataToLatLng(data);
      if (_routeStarted) {
        _distanceTravelled += _currentSpeed;
        _routePoints.add(_locationDataToLatLng(data));
      }
    });
  }

  Marker _createMarker(String id, LatLng position) {
    return Marker(markerId: MarkerId(id), position: position, flat: true);
  }

  Future<LocationData> _getInitialLocation() async {
    if (!_isInitialized) {
      var hasPermission = await Location.instance.hasPermission();
      if (hasPermission != PermissionStatus.granted) {
        hasPermission = await Location.instance.requestPermission();
        if (hasPermission != PermissionStatus.granted) {
          return Future.error('Location permissions denied.');
        }
      }

      await Location.instance.enableBackgroundMode(enable: true);
      Location.instance.onLocationChanged.listen(_onLocationChanged);

      _isInitialized = true;
    }

    return await Location.instance.getLocation();
  }

  LatLng _locationDataToLatLng(LocationData data) {
    return LatLng(data.latitude ?? 0.0, data.longitude ?? 0.0);
  }

  Polyline _getCurrentRoute() {
    return Polyline(
        polylineId: const PolylineId('currentRoute'),
        color: Colors.blue,
        points: _routePoints);
  }
}

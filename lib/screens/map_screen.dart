import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  
  LatLng? _currentPosition;
  Position? _fullPositionData;
  StreamSubscription<Position>? _positionStream;

  // IMU Sensors
  AccelerometerEvent? _accel;
  UserAccelerometerEvent? _userAccel;
  GyroscopeEvent? _gyro;
  MagnetometerEvent? _mag;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  final DateTime _startTime = DateTime.now();
  
  // Sensor Fusion (Complementary Filter) Variables
  double _pitch = 0.0;
  double _roll = 0.0;
  double _yaw = 0.0;
  DateTime? _lastGyroTime;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _initSensors();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream().listen((event) => setState(() => _accel = event));
    _userAccelSub = userAccelerometerEventStream().listen((event) => setState(() => _userAccel = event));
    _magSub = magnetometerEventStream().listen((event) => setState(() => _mag = event));
    
    // Complementary Filter implementation inside the fast Gyro stream
    _gyroSub = gyroscopeEventStream().listen((event) {
      setState(() {
        _gyro = event;
        
        final now = DateTime.now();
        if (_lastGyroTime != null && _accel != null) {
          double dt = now.difference(_lastGyroTime!).inMilliseconds / 1000.0;
          
          // 1. Gyro rates (convert rad/s to degrees/s)
          double gyroRateX = event.x * 180 / math.pi;
          double gyroRateY = event.y * 180 / math.pi;
          double gyroRateZ = event.z * 180 / math.pi;
          
          // 2. Raw Accel angles in degrees
          double accelPitch = math.atan2(_accel!.y, math.sqrt(_accel!.x * _accel!.x + _accel!.z * _accel!.z)) * 180 / math.pi;
          double accelRoll = math.atan2(-_accel!.x, _accel!.z) * 180 / math.pi;
          
          // 3. Complementary Filter for Pitch & Roll
          _pitch = 0.98 * (_pitch + gyroRateX * dt) + 0.02 * accelPitch;
          _roll = 0.98 * (_roll + gyroRateY * dt) + 0.02 * accelRoll;
          
          // 4. Advanced Yaw Tracking (Tilt-Compensated + Wrap-Around Fix)
          if (_mag != null) {
              double pitchRad = _pitch * math.pi / 180.0;
              double rollRad = _roll * math.pi / 180.0;
              
              // Standard Tilt Compensation for Magnetometer
              double mx = _mag!.x;
              double my = _mag!.y;
              double mz = _mag!.z;
              
              // Project magnetic field onto horizontal plane
              double magXComp = mx * math.cos(rollRad) + mz * math.sin(rollRad);
              double magYComp = mx * math.sin(rollRad) * math.sin(pitchRad) + my * math.cos(pitchRad) - mz * math.cos(rollRad) * math.sin(pitchRad);
              
              // Standard Compass Heading (North=0, East=90, South=180, West=-90)
              double magYaw = math.atan2(-magXComp, magYComp) * 180 / math.pi;
              
              // Calculate new yaw from gyro integration
              // Gyro Z is positive counter-clockwise, but compass heading increases clockwise.
              _yaw -= gyroRateZ * dt; 
              
              // Shortest path interpolation to fix -180 to +180 wrap-around jump
              double yawError = magYaw - _yaw;
              while (yawError > 180) yawError -= 360;
              while (yawError < -180) yawError += 360;
              
              _yaw += 0.02 * yawError;
              
              // Normalize final yaw
              while (_yaw > 180) _yaw -= 360;
              while (_yaw < -180) _yaw += 360;
          } else {
              _yaw -= gyroRateZ * dt;
          }
        }
        _lastGyroTime = now;
      });
    });
  }

  Future<void> _initLocationTracking() async {
    final hasPermission = await _locationService.checkAndRequestPermissions();
    if (hasPermission) {
      final initialPos = await _locationService.getCurrentPosition();
      if (initialPos != null) {
        setState(() {
          _currentPosition = LatLng(initialPos.latitude, initialPos.longitude);
          _fullPositionData = initialPos;
        });
        _mapController.move(_currentPosition!, 15.0);
      }

      _positionStream = _locationService.getLocationStream().listen((Position position) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _fullPositionData = position;
        });
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _accelSub?.cancel();
    _userAccelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IDR Navigation Engine', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        elevation: 2,
      ),
      body: Stack(
        children: [
          // MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(28.6139, 77.2090),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sih.idr',
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 40.0,
                      height: 40.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade100.withOpacity(0.5),
                        ),
                        child: Icon(Icons.circle, color: Colors.blue.shade800, size: 24.0),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // RE-CENTER BUTTON
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 16.0);
                }
              },
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),

          // BOTTOM SHEET FOR ALL SENSOR DATA
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.15, 0.35, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 0, offset: const Offset(0, -5))
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeader('GNSS SATELLITE DATA'),
                          const SizedBox(height: 12),
                          _buildGNSSGrid(),
                          const SizedBox(height: 24),
                          _buildHeader('IMU SENSOR ENGINE'),
                          const SizedBox(height: 12),
                          _buildIMUGrid(),
                          const SizedBox(height: 30),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: Colors.blue.shade800, width: 4)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blue.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGNSSGrid() {
    final now = DateTime.now();
    final timeSinceStart = now.difference(_startTime).inSeconds;
    
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      children: [
        _buildDataCard('Speed', _fullPositionData != null ? (_fullPositionData!.speed * 3.6).toStringAsFixed(1) : '--', 'km/h'),
        _buildDataCard('Accuracy', _fullPositionData != null ? _fullPositionData!.accuracy.toStringAsFixed(1) : '--', 'm'),
        _buildDataCard('Latitude', _fullPositionData != null ? _fullPositionData!.latitude.toStringAsFixed(5) : '--', '°'),
        _buildDataCard('Longitude', _fullPositionData != null ? _fullPositionData!.longitude.toStringAsFixed(5) : '--', '°'),
        _buildDataCard('Altitude', _fullPositionData != null ? _fullPositionData!.altitude.toStringAsFixed(1) : '--', 'm'),
        _buildDataCard('Heading', _fullPositionData != null ? _fullPositionData!.heading.toStringAsFixed(1) : '--', '°'),
        _buildDataCard('Uptime', '$timeSinceStart', 'sec'),
        _buildDataCard('Satellites', 'N/A', 'API'),
      ],
    );
  }

  Widget _buildIMUGrid() {
    double gx = 0, gy = 0, gz = 0;
    if (_accel != null && _userAccel != null) {
      gx = _accel!.x - _userAccel!.x;
      gy = _accel!.y - _userAccel!.y;
      gz = _accel!.z - _userAccel!.z;
    }

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: [
        _buildMiniCard('Orie Pitch(X)', _pitch.toStringAsFixed(1), '°'),
        _buildMiniCard('Orie Roll(Y)', _roll.toStringAsFixed(1), '°'),
        _buildMiniCard('Orie Yaw(Z)', _yaw.toStringAsFixed(1), '°'),

        _buildMiniCard('Accel X', _accel != null ? _accel!.x.toStringAsFixed(2) : '--', 'm/s²'),
        _buildMiniCard('Accel Y', _accel != null ? _accel!.y.toStringAsFixed(2) : '--', 'm/s²'),
        _buildMiniCard('Accel Z', _accel != null ? _accel!.z.toStringAsFixed(2) : '--', 'm/s²'),
        
        _buildMiniCard('Gyro X', _gyro != null ? _gyro!.x.toStringAsFixed(2) : '--', 'rad/s'),
        _buildMiniCard('Gyro Y', _gyro != null ? _gyro!.y.toStringAsFixed(2) : '--', 'rad/s'),
        _buildMiniCard('Gyro Z', _gyro != null ? _gyro!.z.toStringAsFixed(2) : '--', 'rad/s'),
        
        _buildMiniCard('Mag X', _mag != null ? _mag!.x.toStringAsFixed(1) : '--', 'µT'),
        _buildMiniCard('Mag Y', _mag != null ? _mag!.y.toStringAsFixed(1) : '--', 'µT'),
        _buildMiniCard('Mag Z', _mag != null ? _mag!.z.toStringAsFixed(1) : '--', 'µT'),
        
        _buildMiniCard('Grav X', gx != 0 ? gx.toStringAsFixed(2) : '--', 'm/s²'),
        _buildMiniCard('Grav Y', gy != 0 ? gy.toStringAsFixed(2) : '--', 'm/s²'),
        _buildMiniCard('Grav Z', gz != 0 ? gz.toStringAsFixed(2) : '--', 'm/s²'),
      ],
    );
  }

  Widget _buildDataCard(String title, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniCard(String title, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: Colors.grey.shade900, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(unit, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
        ],
      ),
    );
  }
}

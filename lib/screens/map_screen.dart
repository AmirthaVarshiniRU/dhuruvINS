import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../services/routing_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();
  final RoutingService _routingService = RoutingService();
  
  TextEditingController? _autoCompleteController;
  String _destinationName = '';
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  String _eta = '';
  String _distance = '';
  bool _isNavigating = false;
  
  LatLng? _currentPosition;
  final ValueNotifier<Position?> _fullPositionData = ValueNotifier(null);
  StreamSubscription<Position>? _positionStream;
  bool _mapReady = false;

  // IMU Sensors (Now using ValueNotifiers for performance)
  final ValueNotifier<AccelerometerEvent?> _accel = ValueNotifier(null);
  final ValueNotifier<UserAccelerometerEvent?> _userAccel = ValueNotifier(null);
  final ValueNotifier<GyroscopeEvent?> _gyro = ValueNotifier(null);
  final ValueNotifier<MagnetometerEvent?> _mag = ValueNotifier(null);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  final DateTime _startTime = DateTime.now();
  
  // Sensor Fusion (Complementary Filter) Variables
  final ValueNotifier<double> _pitch = ValueNotifier(0.0);
  final ValueNotifier<double> _roll = ValueNotifier(0.0);
  final ValueNotifier<double> _yaw = ValueNotifier(0.0);
  DateTime? _lastGyroTime;
  
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initLocationTracking();
    _initSensors();
  }

  void _initSensors() {
    // We now assign directly to .value, which notifies the listeners without rebuilding the whole map
    _accelSub = accelerometerEventStream().listen((event) => _accel.value = event);
    _userAccelSub = userAccelerometerEventStream().listen((event) => _userAccel.value = event);
    _magSub = magnetometerEventStream().listen((event) => _mag.value = event);
    
    // Complementary Filter implementation inside the fast Gyro stream
    _gyroSub = gyroscopeEventStream().listen((event) {
        _gyro.value = event;
        
        final now = DateTime.now();
        if (_lastGyroTime != null && _accel.value != null) {
          double dt = now.difference(_lastGyroTime!).inMilliseconds / 1000.0;
          
          // 1. Gyro rates (convert rad/s to degrees/s)
          double gyroRateX = event.x * 180 / math.pi;
          double gyroRateY = event.y * 180 / math.pi;
          double gyroRateZ = event.z * 180 / math.pi;
          
          // 2. Raw Accel angles in degrees
          double accelPitch = math.atan2(_accel.value!.y, math.sqrt(_accel.value!.x * _accel.value!.x + _accel.value!.z * _accel.value!.z)) * 180 / math.pi;
          double accelRoll = math.atan2(-_accel.value!.x, _accel.value!.z) * 180 / math.pi;
          
          // 3. Complementary Filter for Pitch & Roll
          double newPitch = 0.98 * (_pitch.value + gyroRateX * dt) + 0.02 * accelPitch;
          double newRoll = 0.98 * (_roll.value + gyroRateY * dt) + 0.02 * accelRoll;
          _pitch.value = newPitch;
          _roll.value = newRoll;
          
          // 4. Advanced Yaw Tracking (Tilt-Compensated + Wrap-Around Fix)
          double newYaw = _yaw.value;
          if (_mag.value != null) {
              double pitchRad = newPitch * math.pi / 180.0;
              double rollRad = newRoll * math.pi / 180.0;
              
              // Standard Tilt Compensation for Magnetometer
              double mx = _mag.value!.x;
              double my = _mag.value!.y;
              double mz = _mag.value!.z;
              
              // Project magnetic field onto horizontal plane
              double magXComp = mx * math.cos(rollRad) + mz * math.sin(rollRad);
              double magYComp = mx * math.sin(rollRad) * math.sin(pitchRad) + my * math.cos(pitchRad) - mz * math.cos(rollRad) * math.sin(pitchRad);
              
              // Standard Compass Heading (North=0, East=90, South=180, West=-90)
              double magYaw = math.atan2(-magXComp, magYComp) * 180 / math.pi;
              
              // Calculate new yaw from gyro integration
              // Gyro Z is positive counter-clockwise, but compass heading increases clockwise.
              newYaw -= gyroRateZ * dt; 
              
              // Shortest path interpolation to fix -180 to +180 wrap-around jump
              double yawError = magYaw - newYaw;
              while (yawError > 180) yawError -= 360;
              while (yawError < -180) yawError += 360;
              
              newYaw += 0.02 * yawError;
              
              // Normalize final yaw
              while (newYaw > 180) newYaw -= 360;
              while (newYaw < -180) newYaw += 360;
          } else {
              newYaw -= gyroRateZ * dt;
          }
          _yaw.value = newYaw;
        }
        _lastGyroTime = now;
    });
  }

  Future<void> _initLocationTracking() async {
    final hasPermission = await _locationService.checkAndRequestPermissions();
    if (!hasPermission || !mounted) return;

    _positionStream = _locationService.getLocationStream().listen(
      _onPhoneGnss,
      onError: (Object _, StackTrace __) {
        Future<void>.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          await _positionStream?.cancel();
          _positionStream = _locationService.getLocationStream().listen(_onPhoneGnss);
        });
      },
      cancelOnError: false,
    );

    try {
      final initialPos = await _locationService.getCurrentPosition();
      if (initialPos != null && mounted) {
        _onPhoneGnss(initialPos);
      }
    } catch (_) {}
  }

  void _moveMapSafely(LatLng target, double zoom) {
    if (!_mapReady) return;
    try {
      _mapController.move(target, zoom);
    } catch (_) {}
  }

  void _onPhoneGnss(Position position) {
    if (!mounted) return;
    _fullPositionData.value = position;
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _performRawSearch(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;

    final suggestions = await _geocodingService.getSuggestions(text, _currentPosition);
    if (suggestions.isNotEmpty) {
      final bestMatch = suggestions.first;
      setState(() {
        _destination = bestMatch.coordinates;
        _destinationName = bestMatch.name;
      });
      _mapController.move(bestMatch.coordinates, 14.0);
      FocusManager.instance.primaryFocus?.unfocus();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address not found')),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _accelSub?.cancel();
    _userAccelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _accel.dispose();
    _userAccel.dispose();
    _gyro.dispose();
    _mag.dispose();
    _pitch.dispose();
    _roll.dispose();
    _yaw.dispose();
    _mapController.dispose();
    _rippleController.dispose();
    _fullPositionData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text('Dhuruva INS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _currentPosition == null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/app_logo.jpeg', width: 120, height: 120),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(height: 16),
                Text('Acquiring GPS Signal...', style: TextStyle(color: Colors.grey.shade700, fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        : Stack(
        children: [
          // MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(28.6139, 77.2090),
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onMapReady: () {
                _mapReady = true;
                if (_currentPosition != null) {
                  _moveMapSafely(_currentPosition!, 15.0);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sih.idr',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.shade600,
                      strokeWidth: 6.0,
                    ),
                  ],
                ),
              if (_currentPosition != null || _destination != null)
                MarkerLayer(
                  markers: [
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 40.0,
                        height: 40.0,
                        child: AnimatedBuilder(
                          animation: _rippleController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulsing background pebble
                                Container(
                                  width: 40.0 * _rippleController.value,
                                  height: 40.0 * _rippleController.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue.withOpacity(1.0 - _rippleController.value),
                                  ),
                                ),
                                // Inner solid dot with white border
                                Container(
                                  width: 18.0,
                                  height: 18.0,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 12.0,
                                      height: 12.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    if (_destination != null)
                      Marker(
                        point: _destination!,
                        width: 40.0,
                        height: 40.0,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
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

          // SEARCH BAR
          Positioned(
            top: 20,
            left: 20,
            right: 70, // Leave space for re-center button
            child: Autocomplete<SearchSuggestion>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                final currentText = textEditingValue.text;
                if (currentText.length < 3) {
                  return const Iterable<SearchSuggestion>.empty();
                }
                
                // Debounce: Wait 600ms before calling the API
                await Future.delayed(const Duration(milliseconds: 300));
                
                // If the user kept typing during the wait, abort this request
                if (_autoCompleteController != null && _autoCompleteController!.text != currentText) {
                  return const Iterable<SearchSuggestion>.empty();
                }
                
                return await _geocodingService.getSuggestions(currentText, _currentPosition);
              },
              onSelected: (SearchSuggestion selection) {
                setState(() {
                  _destination = selection.coordinates;
                  _destinationName = selection.name;
                });
                _mapController.move(selection.coordinates, 14.0);
                FocusManager.instance.primaryFocus?.unfocus();
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                _autoCompleteController = textEditingController;
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.white,
                  child: TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search destination...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: textEditingController,
                        builder: (context, value, child) {
                          if (value.text.isEmpty) {
                            return IconButton(
                              icon: const Icon(Icons.search, color: Colors.blue),
                              onPressed: () {
                                _performRawSearch(textEditingController.text);
                              },
                            );
                          } else {
                            return IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () {
                                textEditingController.clear();
                                setState(() {
                                  _destination = null;
                                });
                              },
                            );
                          }
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      _performRawSearch(val);
                      onFieldSubmitted();
                    },
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 90),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final SearchSuggestion option = options.elementAt(index);
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.blue),
                            title: Text(option.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // BOTTOM SHEET FOR DESTINATION INFO
          if (_destination != null)
            DraggableScrollableSheet(
              initialChildSize: 0.3,
              minChildSize: 0.1,
              maxChildSize: 0.4,
              snap: true,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, -5))],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                          if (!_isNavigating) ...[
                            // --- PREVIEW MODE ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(_destinationName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey),
                                  onPressed: () {
                                    setState(() {
                                      _destination = null;
                                      _routePoints.clear();
                                      _eta = '';
                                      _distance = '';
                                      _isNavigating = false;
                                    });
                                    _autoCompleteController?.clear();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text('Ready for navigation.', style: TextStyle(color: Colors.blue.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.directions, size: 24),
                                label: const Text('Start Navigation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  if (_currentPosition == null || _destination == null) return;
                                  
                                  final routeData = await _routingService.getRoute(_currentPosition!, _destination!);
                                  if (routeData != null && mounted) {
                                    setState(() {
                                      _routePoints = routeData.points;
                                      final minutes = (routeData.duration / 60).round();
                                      _eta = '$minutes min';
                                      if (routeData.distance > 1000) {
                                        _distance = '${(routeData.distance / 1000).toStringAsFixed(1)} km';
                                      } else {
                                        _distance = '${routeData.distance.round()} m';
                                      }
                                      _isNavigating = true; // Switch to Navigation Mode!
                                    });
                                    
                                    final bounds = LatLngBounds.fromPoints(_routePoints);
                                    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to calculate route')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ] else ...[
                            // --- ACTIVE NAVIGATION MODE ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(_eta, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                                          const SizedBox(width: 12),
                                          Text(_distance, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.blue)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Navigating to: $_destinationName', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
                                    ],
                                  ),
                                ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.grey, size: 32),
                                    onPressed: () {
                                      // Cancel navigation, go back to preview mode
                                      setState(() {
                                        _isNavigating = false;
                                        _routePoints.clear();
                                        _eta = '';
                                        _distance = '';
                                      });
                                      if (_destination != null) {
                                        _mapController.move(_destination!, 14.0);
                                      }
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 12, left: 16, right: 16),
            color: Colors.blue.shade900,
            child: const Text('Sensor Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader('GNSS SATELLITE DATA'),
                  const SizedBox(height: 12),
                  _buildGNSSGrid(),
                  const SizedBox(height: 24),
                  _buildHeader('IMU SENSOR ENGINE'),
                  const SizedBox(height: 12),
                  _buildIMUGrid(),
                  const SizedBox(height: 30),
                ],
              ),
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
    return ValueListenableBuilder<Position?>(
      valueListenable: _fullPositionData,
      builder: (context, positionData, child) {
        final timeSinceStart = DateTime.now().difference(_startTime).inSeconds;
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.0,
          children: [
            _buildDataCard('Speed', positionData != null ? (positionData.speed * 3.6).toStringAsFixed(1) : '--', 'km/h'),
            _buildDataCard('Accuracy', positionData != null ? positionData.accuracy.toStringAsFixed(1) : '--', 'm'),
            _buildDataCard('Latitude', positionData != null ? positionData.latitude.toStringAsFixed(5) : '--', '°'),
            _buildDataCard('Longitude', positionData != null ? positionData.longitude.toStringAsFixed(5) : '--', '°'),
            _buildDataCard('Altitude', positionData != null ? positionData.altitude.toStringAsFixed(1) : '--', 'm'),
            _buildDataCard('Heading', positionData != null ? positionData.heading.toStringAsFixed(1) : '--', '°'),
            _buildDataCard('Uptime', '$timeSinceStart', 'sec'),
            _buildDataCard('Satellites', 'N/A', 'API'),
          ],
        );
      },
    );
  }

  Widget _buildIMUGrid() {
    // We wrap the GridView in an AnimatedBuilder that listens to ALL our ValueNotifiers.
    // This way, ONLY this grid redraws when sensors change, not the heavy FlutterMap!
    return AnimatedBuilder(
      animation: Listenable.merge([_accel, _userAccel, _gyro, _mag, _pitch, _roll, _yaw]),
      builder: (context, _) {
        double gx = 0, gy = 0, gz = 0;
        if (_accel.value != null && _userAccel.value != null) {
          gx = _accel.value!.x - _userAccel.value!.x;
          gy = _accel.value!.y - _userAccel.value!.y;
          gz = _accel.value!.z - _userAccel.value!.z;
        }

        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: [
            _buildMiniCard('Orie Pitch(X)', _pitch.value.toStringAsFixed(1), '°'),
            _buildMiniCard('Orie Roll(Y)', _roll.value.toStringAsFixed(1), '°'),
            _buildMiniCard('Orie Yaw(Z)', _yaw.value.toStringAsFixed(1), '°'),

            _buildMiniCard('Accel X', _accel.value != null ? _accel.value!.x.toStringAsFixed(2) : '--', 'm/s²'),
            _buildMiniCard('Accel Y', _accel.value != null ? _accel.value!.y.toStringAsFixed(2) : '--', 'm/s²'),
            _buildMiniCard('Accel Z', _accel.value != null ? _accel.value!.z.toStringAsFixed(2) : '--', 'm/s²'),
            
            _buildMiniCard('Gyro X', _gyro.value != null ? _gyro.value!.x.toStringAsFixed(2) : '--', 'rad/s'),
            _buildMiniCard('Gyro Y', _gyro.value != null ? _gyro.value!.y.toStringAsFixed(2) : '--', 'rad/s'),
            _buildMiniCard('Gyro Z', _gyro.value != null ? _gyro.value!.z.toStringAsFixed(2) : '--', 'rad/s'),
            
            _buildMiniCard('Mag X', _mag.value != null ? _mag.value!.x.toStringAsFixed(1) : '--', 'µT'),
            _buildMiniCard('Mag Y', _mag.value != null ? _mag.value!.y.toStringAsFixed(1) : '--', 'µT'),
            _buildMiniCard('Mag Z', _mag.value != null ? _mag.value!.z.toStringAsFixed(1) : '--', 'µT'),
            
            _buildMiniCard('Grav X', gx != 0 ? gx.toStringAsFixed(2) : '--', 'm/s²'),
            _buildMiniCard('Grav Y', gy != 0 ? gy.toStringAsFixed(2) : '--', 'm/s²'),
            _buildMiniCard('Grav Z', gz != 0 ? gz.toStringAsFixed(2) : '--', 'm/s²'),
          ],
        );
      }
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

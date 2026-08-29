import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

imports = '''import 'package:flutter_tts/flutter_tts.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
'''
content = content.replace("import '../services/routing_service.dart';", "import '../services/routing_service.dart';\n" + imports)

state_vars = '''
  List<RouteInstruction> _routeInstructions = [];
  bool _isActiveRouting = false;
  int _currentStepIndex = 0;
  double _distanceToNextTurn = 0.0;
  
  bool _isConnected = true;
  StreamSubscription<InternetStatus>? _internetSub;
  bool _hasCheckedInitialConnection = false;
  
  CacheStore? _cacheStore;
  Dio? _dio;
  bool _isDownloadingMap = false;
  double _downloadProgress = 0.0;
  
  final FlutterTts _flutterTts = FlutterTts();
'''
content = content.replace("  bool _isNavigating = false;", "  bool _isNavigating = false;\n" + state_vars)

init_state_additions = '''
    _flutterTts.setLanguage("en-US");
    _flutterTts.awaitSpeakCompletion(true);
    
    _internetSub = InternetConnection().onStatusChange.listen((InternetStatus status) {
      if (mounted) {
        final bool isConnectedNow = status == InternetStatus.connected;
        if (!isConnectedNow && (_isConnected || !_hasCheckedInitialConnection)) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.red.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 12),
                    Text('No Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const Text(
                  'Cannot connect, please check your network connection...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            );
        }
        setState(() {
          _isConnected = isConnectedNow;
          _hasCheckedInitialConnection = true;
        });
      }
    });
    
    _initCacheStore();
'''
content = content.replace("    _initLocationTracking();", init_state_additions + "    _initLocationTracking();")

methods = '''
  Future<void> _initCacheStore() async {
    final dir = await getApplicationDocumentsDirectory();
    _cacheStore = HiveCacheStore(dir.path, hiveBoxName: 'map_cache');
    final cacheOptions = CacheOptions(
      store: _cacheStore,
      policy: CachePolicy.request,
      hitCacheOnErrorExcept: [401, 403],
      maxStale: const Duration(days: 7),
    );
    _dio = Dio()..interceptors.add(DioCacheInterceptor(options: cacheOptions));
    if (mounted) setState(() {});
  }

  Future<void> _speakInstruction(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _prefetchMapTiles() async {
    if (_routePoints.isEmpty || _dio == null) return;
    setState(() {
      _isDownloadingMap = true;
      _downloadProgress = 0.0;
    });

    final Set<String> tilesToDownload = {};
    for (var point in _routePoints) {
      for (int z = 13; z <= 16; z++) {
        final n = math.pow(2, z);
        final latRad = point.latitude * math.pi / 180;
        final x = ((point.longitude + 180.0) / 360.0 * n).floor();
        final y = ((1.0 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) / 2.0 * n).floor();
        tilesToDownload.add('https://tile.openstreetmap.org/$z/$x/$y.png');
      }
    }

    int completed = 0;
    final total = tilesToDownload.length;
    for (var url in tilesToDownload) {
      try {
        await _dio!.get(url);
      } catch (_) {}
      completed++;
      if (mounted) {
        setState(() {
          _downloadProgress = completed / total;
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _isDownloadingMap = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline map ready!')));
    }
  }
'''
content = content.replace("  void _onPhoneGnss(Position position) {", methods + "\n  void _onPhoneGnss(Position position) {")

gnss_logic = '''
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      
      if (_isActiveRouting && _routeInstructions.isNotEmpty && _currentStepIndex < _routeInstructions.length) {
        if (_routePoints.isNotEmpty) {
          int closestIndex = 0;
          double minDistance = double.infinity;
          int searchLimit = math.min(20, _routePoints.length);
          for (int i = 0; i < searchLimit; i++) {
            double dist = Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude,
              _routePoints[i].latitude, _routePoints[i].longitude,
            );
            if (dist < minDistance) {
              minDistance = dist;
              closestIndex = i;
            }
          }
          if (minDistance < 100) {
            _routePoints = _routePoints.sublist(closestIndex).toList();
            if (_routePoints.isNotEmpty) {
              _routePoints[0] = _currentPosition!;
            }
          }
        }

        final nextStep = _routeInstructions[_currentStepIndex];
        _distanceToNextTurn = Geolocator.distanceBetween(
          _currentPosition!.latitude, _currentPosition!.longitude,
          nextStep.maneuverLocation.latitude, nextStep.maneuverLocation.longitude,
        );
        
        double remainingTotal = _distanceToNextTurn;
        for (int i = _currentStepIndex + 1; i < _routeInstructions.length; i++) {
          remainingTotal += _routeInstructions[i].distance;
        }
        if (remainingTotal > 1000) {
          _distance = '${(remainingTotal / 1000).toStringAsFixed(1)} km';
        } else {
          _distance = '${remainingTotal.round()} m';
        }

        if (_distanceToNextTurn < 50.0) {
          _speakInstruction(nextStep.instruction);
          _currentStepIndex++;
        }
        
        _mapController.move(_currentPosition!, 18.0);
      }
    });
'''
content = content.replace("    setState(() {\n      _currentPosition = LatLng(position.latitude, position.longitude);\n    });", gnss_logic)

dispose_additions = '''
    _internetSub?.cancel();
    _flutterTts.stop();
'''
content = content.replace("    _positionStream?.cancel();", dispose_additions + "    _positionStream?.cancel();")

tile_layer = '''
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sih.idr',
                tileProvider: _dio != null ? CachedTileProvider(dio: _dio!) : null,
              ),
'''
content = content.replace("              TileLayer(\n                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',\n                userAgentPackageName: 'com.sih.idr',\n              ),", tile_layer)

start_routing = '''
                                      _isNavigating = true;
                                      _routeInstructions = routeData.instructions;
                                      _currentStepIndex = 0;
                                      _isActiveRouting = false;
                                      _prefetchMapTiles();
'''
content = content.replace("                                      _isNavigating = true; // Switch to Navigation Mode!", start_routing)

active_nav_buttons = '''
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
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _isActiveRouting ? Colors.red.shade700 : Colors.green.shade700,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              icon: Icon(_isActiveRouting ? Icons.stop : Icons.play_arrow),
                                              label: Text(_isActiveRouting ? 'Stop Route' : 'Start Route'),
                                              onPressed: () {
                                                setState(() {
                                                  _isActiveRouting = !_isActiveRouting;
                                                });
                                                if (_isActiveRouting && _routeInstructions.isNotEmpty) {
                                                  _speakInstruction(_routeInstructions[0].instruction);
                                                  _mapController.move(_currentPosition ?? _routePoints.first, 18.0);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue.shade700,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              icon: const Icon(Icons.list),
                                              label: const Text('Show Route'),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Route Steps'),
                                                    content: SizedBox(
                                                      width: double.maxFinite,
                                                      child: ListView.builder(
                                                        shrinkWrap: true,
                                                        itemCount: _routeInstructions.length,
                                                        itemBuilder: (context, index) {
                                                          final step = _routeInstructions[index];
                                                          return ListTile(
                                                            leading: CircleAvatar(child: Text('${index + 1}')),
                                                            title: Text(step.instruction),
                                                            subtitle: Text('${step.distance.round()} meters'),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                                                    ]
                                                  )
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
'''

content = content.replace('''
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
''', active_nav_buttons)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('File restored completely!')

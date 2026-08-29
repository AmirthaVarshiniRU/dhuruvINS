import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_ui = '''                          if (_eta.isNotEmpty) ...[
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
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_destinationName, style: TextStyle(fontSize: _eta.isEmpty ? 24 : 16, fontWeight: _eta.isEmpty ? FontWeight.bold : FontWeight.normal, color: _eta.isEmpty ? Colors.black : Colors.grey.shade700)),
                                    if (_eta.isEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                      const SizedBox(height: 8),
                                      Text('Ready for navigation.', style: TextStyle(color: Colors.blue.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
                                    ]
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey, size: 32),
                                onPressed: () {
                                  setState(() {
                                    _destination = null;
                                    _routePoints.clear();
                                    _eta = '';
                                    _distance = '';
                                    _isNavigating = false;
                                    _isActiveRouting = false;
                                  });
                                  _autoCompleteController?.clear();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.map, size: 24),
                                  label: const Text('Show Route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                        _routeInstructions = routeData.instructions;
                                        _currentStepIndex = 0;
                                        _isActiveRouting = false;
                                        _isNavigating = true;
                                      });
                                      _prefetchMapTiles();
                                      final bounds = LatLngBounds.fromPoints(_routePoints);
                                      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isActiveRouting ? Colors.red.shade700 : Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  icon: Icon(_isActiveRouting ? Icons.stop : Icons.directions, size: 24),
                                  label: Text(_isActiveRouting ? 'Stop Route' : 'Start Route', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    if (_currentPosition == null || _destination == null) return;

                                    if (_isActiveRouting) {
                                      setState(() {
                                        _isActiveRouting = false;
                                      });
                                      return;
                                    }

                                    if (_routePoints.isEmpty) {
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
                                          _routeInstructions = routeData.instructions;
                                          _currentStepIndex = 0;
                                          _isActiveRouting = true;
                                          _isNavigating = true;
                                        });
                                        _prefetchMapTiles();
                                      }
                                    } else {
                                      setState(() {
                                        _isActiveRouting = true;
                                      });
                                    }

                                    if (_isActiveRouting && _routeInstructions.isNotEmpty) {
                                      _speakInstruction(_routeInstructions[0].instruction);
                                      _mapController.move(_currentPosition ?? _routePoints.first, 18.0);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),\n'''

new_lines = lines[:668] + [new_ui] + lines[847:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('File replaced successfully')

import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_ui = '''                          if (_routePoints.isEmpty) ...[
                            // State 1: Selection Mode
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_destinationName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                                      const SizedBox(height: 4),
                                      Text('${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
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
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.play_arrow, size: 24),
                                    label: const Text('Start Route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                          _isActiveRouting = true;
                                        });
                                        _prefetchMapTiles();
                                        if (_routeInstructions.isNotEmpty) {
                                          _speakInstruction(_routeInstructions[0].instruction);
                                        }
                                        _mapController.move(_currentPosition ?? _routePoints.first, 18.0);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ] else if (!_isActiveRouting) ...[
                            // State 2: Preview Mode (Show Route clicked)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_eta, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                                    const SizedBox(height: 4),
                                    Text(_distance, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.blue)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red, size: 36),
                                  onPressed: () {
                                    setState(() {
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
                          ] else ...[
                            // State 3: Active Routing
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
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.stop, size: 24),
                                    label: const Text('Stop Route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      setState(() {
                                        _isActiveRouting = false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.list, size: 24),
                                    label: const Text('Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          ],
'''

new_lines = lines[:668] + [new_ui] + lines[810:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('File replaced successfully')

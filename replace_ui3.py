import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _getArrivalTime
helper_func = '''
  String _getArrivalTime(String eta) {
    if (eta.isEmpty) return '';
    try {
      int minutes = int.parse(eta.replaceAll(RegExp(r'[^0-9]'), ''));
      DateTime arrival = DateTime.now().add(Duration(minutes: minutes));
      String hour = arrival.hour > 12 ? (arrival.hour - 12).toString() : (arrival.hour == 0 ? '12' : arrival.hour.toString());
      String minute = arrival.minute.toString().padLeft(2, '0');
      String ampm = arrival.hour >= 12 ? 'pm' : 'am';
      return '$hour:$minute $ampm';
    } catch (_) {
      return '';
    }
  }

  void _onPhoneGnss(Position position) {'''
content = content.replace('  void _onPhoneGnss(Position position) {', helper_func)

# 2. Add Top Banner
top_banner = '''
          // Top Navigation Banner (Active Routing)
          if (_isActiveRouting && _routeInstructions.isNotEmpty && _currentStepIndex < _routeInstructions.length)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D5C54), // Dark green color
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.turn_left, color: Colors.white, size: 48),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_routeInstructions[_currentStepIndex].distance.round()} m', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(_routeInstructions[_currentStepIndex].instruction.replaceAll('Turn left onto ', '').replaceAll('Turn right onto ', '').replaceAll('Continue onto ', '').replaceAll('Head southeast on ', ''), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: const Icon(Icons.auto_awesome, color: Colors.blue, size: 28),
                    )
                  ],
                ),
              ),
            ),
'''
content = content.replace('          // BOTTOM SHEET FOR DESTINATION INFO', top_banner + '          // BOTTOM SHEET FOR DESTINATION INFO')


# 3. Change Draggable color
content = content.replace('                    color: Colors.white,', '                    color: _isActiveRouting ? const Color(0xFF1E1E1E) : Colors.white,')

# 4. Replace State 3 Active Routing UI
old_state3 = '''                            // State 3: Active Routing
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
'''

new_state3 = '''                            // State 3: Active Routing
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 36),
                                  onPressed: () {
                                    setState(() {
                                      _isActiveRouting = false;
                                      _routePoints.clear();
                                      _eta = '';
                                      _distance = '';
                                      _destination = null;
                                    });
                                  },
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(_eta, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text('$_distance • ${_getArrivalTime(_eta)}', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.alt_route, color: Colors.white, size: 32),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E1E1E),
                                        title: const Text('Route Steps', style: TextStyle(color: Colors.white)),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _routeInstructions.length,
                                            itemBuilder: (context, index) {
                                              final step = _routeInstructions[index];
                                              return ListTile(
                                                leading: CircleAvatar(backgroundColor: Colors.blue.shade900, child: Text('${index + 1}', style: const TextStyle(color: Colors.white))),
                                                title: Text(step.instruction, style: const TextStyle(color: Colors.white)),
                                                subtitle: Text('${step.distance.round()} meters', style: TextStyle(color: Colors.grey.shade400)),
                                              );
                                            },
                                          ),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.blue)))
                                        ]
                                      )
                                    );
                                  },
                                ),
                              ],
                            ),
'''

content = content.replace(old_state3, new_state3)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Active UI completely replaced!')

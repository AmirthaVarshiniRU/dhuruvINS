import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix the jagged blue line
bad_line = '''          if (minDistance < 100) {
            _routePoints = _routePoints.sublist(closestIndex).toList();
            if (_routePoints.isNotEmpty) {
              _routePoints[0] = _currentPosition!;
            }
          }'''
good_line = '''          if (minDistance < 100) {
            _routePoints = _routePoints.sublist(closestIndex).toList();
          }'''
content = content.replace(bad_line, good_line)

# 2. Fix the Top Banner Text
bad_text = "Text(_routeInstructions[_currentStepIndex].instruction.replaceAll('Turn left onto ', '').replaceAll('Turn right onto ', '').replaceAll('Continue onto ', '').replaceAll('Head southeast on ', ''), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),"
good_text = '''Text(
                            _routeInstructions[_currentStepIndex].instruction, 
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),'''
content = content.replace(bad_text, good_text)

# 3. Fix the Bottom Sheet color
content = content.replace('color: _isActiveRouting ? const Color(0xFF1E1E1E) : Colors.white,', 'color: Colors.white,')

# 4. Fix State 3 text and icon colors
old_state3_icons = '''                            Row(
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
                            ),'''

new_state3_icons = '''                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 36),
                                  onPressed: () {
                                    setState(() {
                                      _isActiveRouting = false;
                                      _routePoints.clear();
                                      _eta = '';
                                      _distance = '';
                                    });
                                  },
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(_eta, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black)),
                                    const SizedBox(height: 4),
                                    Text('$_distance • ${_getArrivalTime(_eta)}', style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.alt_route, color: Colors.grey, size: 36),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: const Text('Route Steps', style: TextStyle(color: Colors.black)),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _routeInstructions.length,
                                            itemBuilder: (context, index) {
                                              final step = _routeInstructions[index];
                                              return ListTile(
                                                leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Text('${index + 1}', style: TextStyle(color: Colors.blue.shade900))),
                                                title: Text(step.instruction, style: const TextStyle(color: Colors.black)),
                                                subtitle: Text('${step.distance.round()} meters', style: TextStyle(color: Colors.grey.shade600)),
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
                            ),'''

# Handle the dot encoding issue for '$_distance • ${_getArrivalTime(_eta)}'
content = content.replace("Text('$_distance  ${_getArrivalTime(_eta)}', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),", "Text('$_distance • ${_getArrivalTime(_eta)}', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),")
content = content.replace(old_state3_icons, new_state3_icons)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Replaced successfully')

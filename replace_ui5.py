import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _isAutoTracking variable
content = content.replace('  bool _isActiveRouting = false;', '  bool _isActiveRouting = false;\n  bool _isAutoTracking = true;')

# 2. Add onPositionChanged to MapOptions
old_map_options = '''              minZoom: 3.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),'''
new_map_options = '''              minZoom: 3.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isActiveRouting && _isAutoTracking) {
                  setState(() => _isAutoTracking = false);
                }
              },'''
content = content.replace(old_map_options, new_map_options)

# 3. Update _onPhoneGnss map move
old_move_end = '''
        _mapController.move(_currentPosition!, 18.0);
      }
    });'''
new_move_end = '''
        if (_isAutoTracking) {
          _mapController.move(_currentPosition!, 18.0);
        }
      }
    });'''
content = content.replace(old_move_end, new_move_end)


# 4. Add Re-center FAB
recenter_fab = '''
          // Re-center FAB for Auto Tracking
          if (_isActiveRouting && !_isAutoTracking)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.22 + 20,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blue),
                onPressed: () {
                  setState(() => _isAutoTracking = true);
                  if (_currentPosition != null) {
                    _mapController.move(_currentPosition!, 18.0);
                  }
                },
              ),
            ),
'''
content = content.replace('          // BOTTOM SHEET FOR DESTINATION INFO', recenter_fab + '          // BOTTOM SHEET FOR DESTINATION INFO')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Re-center logic injected')

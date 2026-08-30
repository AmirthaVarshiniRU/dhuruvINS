import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Hide Re-center and Search Bar when Active Routing
old_recenter = '          // RE-CENTER BUTTON'
new_recenter = '          if (!_isActiveRouting)\n          // RE-CENTER BUTTON'
content = content.replace(old_recenter, new_recenter)

old_search = '          // SEARCH BAR'
new_search = '          if (!_isActiveRouting)\n          // SEARCH BAR'
content = content.replace(old_search, new_search)

# 2. Move Auto-tracking FAB to Left Middle
old_auto_tracking_fab = '''          // Re-center FAB for Auto Tracking
          if (_isActiveRouting && !_isAutoTracking)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.38 + 20,
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
            ),'''
new_auto_tracking_fab = '''          // Re-center FAB for Auto Tracking
          if (_isActiveRouting && !_isAutoTracking)
            Positioned(
              bottom: MediaQuery.of(context).size.height / 2,
              left: 16,
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
            ),'''
content = content.replace(old_auto_tracking_fab, new_auto_tracking_fab)

# 3. Reduce height of Start Route Draggable alone
old_draggable = '''            DraggableScrollableSheet(
              initialChildSize: 0.38,
              minChildSize: 0.1,
              maxChildSize: 0.5,'''
new_draggable = '''            DraggableScrollableSheet(
              initialChildSize: _isActiveRouting ? 0.22 : 0.38,
              minChildSize: 0.1,
              maxChildSize: _isActiveRouting ? 0.22 : 0.5,'''
content = content.replace(old_draggable, new_draggable)

# 4. Move Top Banner UP
old_top_padding = '              top: MediaQuery.of(context).padding.top + 10,'
new_top_padding = '              top: MediaQuery.of(context).padding.top,'
content = content.replace(old_top_padding, new_top_padding)

# 5. Remove Star Circle
old_star = '''
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: const Icon(Icons.auto_awesome, color: Colors.blue, size: 28),
                    )'''
content = content.replace(old_star, '')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('UI tweaks applied successfully!')

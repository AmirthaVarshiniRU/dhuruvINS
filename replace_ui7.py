import os

file_path = 'lib/screens/map_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update Top Banner to use dynamic _distanceToNextTurn
old_banner = "Text('${_routeInstructions[_currentStepIndex].distance.round()} m', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),"
new_banner = "Text('${_distanceToNextTurn.round()} m', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),"
content = content.replace(old_banner, new_banner)

# 2. Update _eta in _onPhoneGnss
old_gnss = '''        if (remainingTotal > 1000) {
          _distance = '${(remainingTotal / 1000).toStringAsFixed(1)} km';
        } else {
          _distance = '${remainingTotal.round()} m';
        }

        if (_distanceToNextTurn < 50.0) {'''

new_gnss = '''        if (remainingTotal > 1000) {
          _distance = '${(remainingTotal / 1000).toStringAsFixed(1)} km';
        } else {
          _distance = '${remainingTotal.round()} m';
        }
        
        // Dynamically update ETA based on remaining distance and current speed (fallback to 30km/h)
        double currentSpeed = position.speed > 5.0 ? position.speed : 8.33; // m/s
        int remainingSeconds = (remainingTotal / currentSpeed).round();
        if (remainingSeconds > 3600) {
          _eta = '${(remainingSeconds / 3600).floor()} hr ${(remainingSeconds % 3600) ~/ 60} min';
        } else {
          _eta = '${(remainingSeconds / 60).ceil()} min';
        }

        if (_distanceToNextTurn < 50.0) {'''

content = content.replace(old_gnss, new_gnss)

with open('lib/screens/map_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated dynamic distance and ETA!')

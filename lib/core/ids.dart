import 'dart:math';

typedef IdGenerator = String Function();

final Random _random = Random.secure();

/// Generates a short, practically unique identifier for local records.
String generateId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
  return '$time-$noise';
}

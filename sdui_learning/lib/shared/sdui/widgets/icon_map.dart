import 'package:flutter/material.dart';

IconData iconForName(String? name) {
  return switch (name) {
    'music' => Icons.music_note_rounded,
    'leaf' => Icons.eco_rounded,
    'flame' => Icons.local_fire_department_rounded,
    'diya' => Icons.nightlife_rounded,
    'gift' => Icons.card_giftcard_rounded,
    'palette' => Icons.palette_rounded,
    'shield' => Icons.health_and_safety_rounded,
    _ => Icons.auto_awesome_rounded,
  };
}

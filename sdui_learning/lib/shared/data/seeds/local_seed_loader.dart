import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/sdui_models.dart';

class LocalSeedLoader {
  const LocalSeedLoader();

  Future<SduiScreenConfig> load(String festivalId) async {
    final path = 'assets/sdui/$festivalId.json';
    final raw = await rootBundle.loadString(path);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return SduiScreenConfig.fromJson(map);
  }
}

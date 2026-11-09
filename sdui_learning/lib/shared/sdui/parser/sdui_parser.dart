import '../../data/models/sdui_models.dart';

class SduiParser {
  const SduiParser();

  SduiScreenConfig parse(Map<String, dynamic> json) {
    return SduiScreenConfig.fromJson(json);
  }
}

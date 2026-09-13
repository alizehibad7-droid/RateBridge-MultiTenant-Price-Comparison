import 'package:flutter/foundation.dart';

class AiContextService extends ChangeNotifier {
  String currentScreenName = 'home';
  Map<String, dynamic> currentScreenData = {};

  void updateContext(String screenName, Map<String, dynamic> data) {
    currentScreenName = screenName;
    currentScreenData = data;
    notifyListeners();
  }

  void clearContext() {
    currentScreenName = 'home';
    currentScreenData = {};
  }
}

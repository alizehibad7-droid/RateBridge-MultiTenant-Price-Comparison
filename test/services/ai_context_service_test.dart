import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/services/ai_context_service.dart';

void main() {
  late AiContextService service;

  setUp(() {
    service = AiContextService();
  });

  tearDown(() {
    service.dispose();
  });

  group('AiContextService', () {
    test('starts on the home screen with empty data', () {
      expect(service.currentScreenName, 'home');
      expect(service.currentScreenData, isEmpty);
    });

    test('updateContext stores the screen and notifies listeners', () {
      var notifies = 0;
      service.addListener(() => notifies++);

      service.updateContext('material_detail', {
        'materialId': 'mat-1',
        'name': 'OPC Cement',
      });

      expect(service.currentScreenName, 'material_detail');
      expect(service.currentScreenData['materialId'], 'mat-1');
      expect(service.currentScreenData['name'], 'OPC Cement');
      expect(notifies, 1);
    });

    test('updateContext replaces previous data', () {
      service.updateContext('catalog', {'q': 'cement'});
      service.updateContext('compare', {'material': 'Steel'});

      expect(service.currentScreenName, 'compare');
      expect(service.currentScreenData, {'material': 'Steel'});
    });

    test('clearContext resets to home without notifying', () {
      service.updateContext('orders', {'tab': 'pending'});

      var notifies = 0;
      service.addListener(() => notifies++);
      service.clearContext();

      expect(service.currentScreenName, 'home');
      expect(service.currentScreenData, isEmpty);
      expect(notifies, 0);
    });
  });
}

class VoiceCommandParser {
  static Map<String, String> parseCommand(String input) {
    final cleanInput = input.toLowerCase();
    String city = 'Unknown';
    String material = 'Unknown';
    String intent = 'Unknown';

    // Parse City Location Matchers
    if (cleanInput.contains('lahore') || cleanInput.contains('lhr')) {
      city = 'Lahore';
    } else if (cleanInput.contains('karachi') || cleanInput.contains('khi')) {
      city = 'Karachi';
    } else if (cleanInput.contains('islamabad') || cleanInput.contains('isb')) {
      city = 'Islamabad';
    } else if (cleanInput.contains('pindi') || cleanInput.contains('rwp')) {
      city = 'Rawalpindi';
    }

    // Parse Material Matchers
    if (cleanInput.contains('steel')) {
      material = 'Steel';
    } else if (cleanInput.contains('cement')) {
      material = 'Cement';
    } else if (cleanInput.contains('sand')) {
      material = 'Sand';
    }

    // Parse Action Matchers
    if (cleanInput.contains('price') || cleanInput.contains('rate') || cleanInput.contains('trend')) {
      intent = 'TrendAnalysis';
    } else if (cleanInput.contains('delivery') || cleanInput.contains('order')) {
      intent = 'ActiveOrders';
    }

    return {
      'city': city,
      'material': material,
      'intent': intent,
    };
  }
}

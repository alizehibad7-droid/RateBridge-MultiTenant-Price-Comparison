class PriceTrendPoint {
  final DateTime date;
  final double price;
  final bool isForecast;

  PriceTrendPoint({
    required this.date,
    required this.price,
    this.isForecast = false,
  });
}

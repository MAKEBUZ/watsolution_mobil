class BillingCalculation {
  final double consumption,
      consumptionCharge,
      fixedCharge,
      discount,
      additionalCharges;
  final int total;
  const BillingCalculation._(
    this.consumption,
    this.consumptionCharge,
    this.fixedCharge,
    this.discount,
    this.additionalCharges,
    this.total,
  );

  factory BillingCalculation({
    required num previous,
    required num current,
    required num rate,
    required num fixedCharge,
    num subsidy = 0,
    num surcharges = 0,
  }) {
    for (final value in [
      previous,
      current,
      rate,
      fixedCharge,
      subsidy,
      surcharges,
    ]) {
      if (!value.isFinite || value < 0 || value > 99999999.99) {
        throw StateError(
          'Revisa los valores: deben estar entre 0 y 99.999.999,99.',
        );
      }
    }
    if (current < previous) {
      throw StateError('La lectura nueva no puede ser menor que la anterior.');
    }
    if (subsidy > 1) {
      throw StateError('El subsidio debe estar entre 0 y 100 %.');
    }
    final consumption = (current - previous).toDouble();
    final charge = consumption * rate;
    final subtotal = charge + fixedCharge;
    final discount = subtotal * subsidy;
    return BillingCalculation._(
      consumption,
      charge,
      fixedCharge.toDouble(),
      discount,
      surcharges.toDouble(),
      (subtotal - discount + surcharges).round(),
    );
  }
  Map<String, num> toJson() => {
    'consumptionM3': consumption,
    'consumptionCharge': consumptionCharge,
    'fixedCharge': fixedCharge,
    'discount': discount,
    'additionalCharges': additionalCharges,
    'total': total,
  };
}

String cop(num value) =>
    '\$${value.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} COP';
String quantity(num value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');

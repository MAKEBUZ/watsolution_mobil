import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/billing_calculation.dart';

void main() {
  test('charges only difference: 110 minus 100 at COP 100', () {
    final bill = BillingCalculation(
      previous: 100,
      current: 110,
      rate: 100,
      fixedCharge: 0,
    );
    expect(bill.consumption, 10);
    expect(bill.consumptionCharge, 1000);
    expect(bill.total, 1000);
    expect(cop(bill.total), '\$1.000 COP');
    expect(quantity(100), '100');
    expect(quantity(10.5), '10,5');
  });
  test('fixed charge is added exactly once, including zero consumption', () {
    expect(
      BillingCalculation(
        previous: 100,
        current: 110,
        rate: 100,
        fixedCharge: 500,
      ).total,
      1500,
    );
    expect(
      BillingCalculation(
        previous: 100,
        current: 100,
        rate: 100,
        fixedCharge: 500,
      ).total,
      500,
    );
  });
  test(
    'retains explicit subsidy and additional charges under existing contract',
    () {
      final bill = BillingCalculation(
        previous: 100,
        current: 110,
        rate: 100,
        fixedCharge: 500,
        subsidy: 0.1,
        surcharges: 100,
      );
      expect(bill.discount, 150);
      expect(bill.total, 1450);
    },
  );
  test('rejects decreasing readings, invalid subsidy and unbounded values', () {
    expect(
      () => BillingCalculation(
        previous: 100,
        current: 90,
        rate: 100,
        fixedCharge: 0,
      ),
      throwsStateError,
    );
    expect(
      () => BillingCalculation(
        previous: 100,
        current: 110,
        rate: 100,
        fixedCharge: 0,
        subsidy: 2,
      ),
      throwsStateError,
    );
    expect(
      () => BillingCalculation(
        previous: 100,
        current: 110,
        rate: double.infinity,
        fixedCharge: 0,
      ),
      throwsStateError,
    );
  });
}

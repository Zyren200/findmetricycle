import "package:findme_tricycle_mobile/core/utils/ride_format.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("pesos get thousands separators", () {
    expect(peso(45.5), "₱45.50");
    expect(peso(2180), "₱2,180.00");
    expect(peso(38450), "₱38,450.00");
    expect(peso(1234567.891), "₱1,234,567.89");
    expect(groupThousands("-1500.00"), "-1,500.00");
    expect(groupThousands("999"), "999");
  });
}

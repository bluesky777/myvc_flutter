import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Http/ClienteApp.dart';

void main() {
  test('el User-Agent sigue el formato que lee la auditoría', () {
    expect(ClienteApp.userAgent('1.1.0', ['android', '14', 'SM-A145M']),
        'MyVC-App/1.1.0 (android; 14; SM-A145M)');
    expect(ClienteApp.userAgent('1.1.0', ['ios', '17.5', 'iPhone14,5']),
        'MyVC-App/1.1.0 (ios; 17.5; iPhone14,5)');
  });

  test('un modelo raro no rompe la cabecera ni el paréntesis', () {
    expect(ClienteApp.userAgent('1.1.0', ['android', '', 'Moto (g); ñ5 ']),
        'MyVC-App/1.1.0 (android; Moto g 5)');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:myvc_flutter/Utils/EsquemaServidor.dart';

void main() {
  group('el esquema que se le pone al servidor escrito a mano', () {
    test('un dominio de verdad va por https', () {
      expect(conEsquema('cads.micolevirtual.com'),
          'https://cads.micolevirtual.com');
    });

    test('localhost se queda en http, que ahí no hay certificado', () {
      expect(conEsquema('localhost'), 'http://localhost');
      expect(conEsquema('localhost:8000'), 'http://localhost:8000');
      expect(conEsquema('127.0.0.1'), 'http://127.0.0.1');
    });

    test('las IP de la red de casa también', () {
      expect(conEsquema('192.168.1.5'), 'http://192.168.1.5');
      expect(conEsquema('10.0.0.7'), 'http://10.0.0.7');
      expect(conEsquema('172.16.0.3'), 'http://172.16.0.3');
      expect(conEsquema('172.31.255.1'), 'http://172.31.255.1');
    });

    test('el 172 fuera del rango privado es internet, y va cifrado', () {
      expect(conEsquema('172.15.0.1'), 'https://172.15.0.1');
      expect(conEsquema('172.32.0.1'), 'https://172.32.0.1');
    });

    test('un 10 o un 192 que solo lo parecen no engañan', () {
      expect(conEsquema('10.micolevirtual.com'), 'http://10.micolevirtual.com');
      expect(conEsquema('192.168.micolevirtual.com'),
          'http://192.168.micolevirtual.com');
    });

    test('el nombre que reparte la red de casa', () {
      expect(conEsquema('mi-mac.local'), 'http://mi-mac.local');
    });

    test('quien escribe el esquema manda', () {
      expect(conEsquema('http://cads.micolevirtual.com'),
          'http://cads.micolevirtual.com');
      expect(conEsquema('https://localhost'), 'https://localhost');
    });

    test('los espacios de sobra no cambian la decisión', () {
      expect(conEsquema('  localhost  '), 'http://localhost');
    });

    test('vacío se queda vacío, que ya avisa el login', () {
      expect(conEsquema(''), '');
      expect(conEsquema('   '), '');
    });
  });
}

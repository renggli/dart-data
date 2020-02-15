library data.test.frame;

import 'dart:convert';
import 'dart:io';

import 'package:data/frame.dart';
import 'package:test/test.dart';

void read(String filename) {
  test(filename, () async {
    final file = File(filename);
    final stream = file.openRead().transform(utf8.decoder);
    final tips = await CsvImporter.fromStream(stream);
    print(tips);
  });
}

void main() {
  group('csv', () {
    read('example/data/cars.csv');
    read('example/data/cereal.csv');
    read('example/data/countries.csv');
    read('example/data/iris.csv');
    read('example/data/tips.csv');
  });
}

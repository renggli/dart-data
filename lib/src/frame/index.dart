import '../type/type.dart';
import 'frame.dart';

abstract class Index<K> {
  Index(this.frame);

  final Frame frame;

  DataType<K> get dataType;

  Iterable<K> get keys;

  int get length => frame.rows.length;

  K indexOf(K key, {K Function()? ifAbsent});
}

/// Shared configuration across packages.
library data.shared.config;

import 'package:data/type.dart';

/// True, if the code is running in JavaScript.
const bool isJavaScript = identical(1, 1.0);

/// Data type used to index columns and rows.
const DataType<int> indexDataType = DataType.uint32;

/// Default [int] data type for integer arithmetic.
const DataType<int> intDataType = DataType.int32;

/// Default [double] data type for floating point arithmetic.
const DataType<double> floatDataType = DataType.float64;

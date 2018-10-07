/// Shared configuration across packages.
library data.shared.config;

import 'package:data/type.dart';

/// True, if the code is running in JavaScript.
const bool isJavaScript = identical(1, 1.0);

/// Integer data type to index column and row indexes.
const DataType<int> indexDataType = DataType.uint32;

/// Floating data type for numeric matrices.
const DataType<double> valueDataType = DataType.float64;

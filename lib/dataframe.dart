/// Columnar DataFrame and Series tabular data engine with Apache Arrow-compatible memory layouts.
///
/// A [DataFrame] represents a two-dimensional table of data organized into named columns,
/// similar to a spreadsheet or SQL table. Each column is represented as a [Series],
/// backed by contiguous typed memory buffers and a separate [ValidityMask] bitmask
/// for tracking null or missing values without boxing primitive types.
///
/// ## Key Capabilities
///
/// - **Columnar Series Hierarchy**: Specialized unboxed typed series ([TypedSeries]),
///   Arrow UTF-8 strings ([ArrowStringSeries], [StringSeries]), packed booleans ([BoolSeries]), and general objects ([ObjectSeries]).
/// - **Zero-Allocation Slicing & Filtering**: Subsetting and filtering numeric columns
///   copies contiguous typed buffers directly without boxing overhead.
/// - **Relational Hash Joins**: Inner, left, right, and full outer joins ([JoinType]) powered by
///   collision-free composite keys.
/// - **Group-by & Aggregations**: Grouping rows by one or more keys and aggregating with
///   numerically stable Welford variance ([Agg.var_]), median ([Agg.median]), mean ([Agg.mean]),
///   sum ([Agg.sum]), min ([Agg.min]), and max ([Agg.max]).
/// - **Data Ingestion & Export**: Robust RFC 4180 CSV/TSV parsing ([CsvReader]), CSV formatting ([CsvWriter]),
///   and JSON serialization supporting [JsonOrient.records], [JsonOrient.split], [JsonOrient.columns],
///   and [JsonOrient.values_] orientations.
///
/// ## Example
///
/// ```dart
/// import 'package:data/dataframe.dart';
///
/// void main() {
///   final df = DataFrame.fromColumns({
///     'department': ['Engineering', 'Engineering', 'Sales', 'Sales'],
///     'salary': [120000.0, 135000.0, 95000.0, 105000.0],
///   });
///
///   // Group by department and compute average salary
///   final summary = df.groupBy(['department']).aggregate({
///     'salary': [Agg.mean, Agg.count],
///   });
///   print(summary);
/// }
/// ```
library;

import 'src/dataframe/bitmask.dart';
import 'src/dataframe/csv/csv_reader.dart';
import 'src/dataframe/csv/csv_writer.dart';
import 'src/dataframe/dataframe.dart';
import 'src/dataframe/groupby.dart';
import 'src/dataframe/join.dart';
import 'src/dataframe/json.dart';
import 'src/dataframe/series.dart';

export 'src/dataframe/arrow_string_series.dart';
export 'src/dataframe/arrowc/arrow_c_data.dart';
export 'src/dataframe/arrowc/arrow_ipc.dart';
export 'src/dataframe/bitmask.dart';
export 'src/dataframe/csv/csv_reader.dart';
export 'src/dataframe/csv/csv_stream.dart';
export 'src/dataframe/csv/csv_writer.dart';
export 'src/dataframe/dataframe.dart';
export 'src/dataframe/groupby.dart';
export 'src/dataframe/join.dart';
export 'src/dataframe/json.dart';
export 'src/dataframe/json/json_stream.dart';
export 'src/dataframe/series.dart';

import '../../../linear.dart';

/// Trajectory of an ODE simulation containing time points [t] and state vectors
/// [y].
class OdeSolution {
  /// Constructs an ODE solution.
  const new({required this.t, required this.y});

  /// The recorded time points.
  final List<double> t;

  /// The state vectors at each corresponding time point.
  final List<Vector<double>> y;

  /// The final state vector of the simulation.
  Vector<double> get last => y.last;

  /// Number of recorded steps.
  int get stepCount => t.length;
}

import 'dart:core';
import 'dart:math';

/// Utilities for working with floating point numbers.
class Precision {
  /// The number of binary digits used to represent the binary number for a double precision floating
  /// point value. i.e. there are this many digits used to represent the
  /// actual number, where in a number as: 0.134556 * 10^5 the digits are 0.134556 and the exponent is 5.
  static const doubleWidth = 53;

  /// The number of binary digits used to represent the binary number for a single precision floating
  /// point value. i.e. there are this many digits used to represent the
  /// actual number, where in a number as: 0.134556 * 10^5 the digits are 0.134556 and the exponent is 5.
  static const singleWidth = 24;

  /// Standard epsilon, the maximum relative precision of IEEE 754 double-precision floating numbers (64 bit).
  /// According to the definition of Prof. Demmel and used in LAPACK and Scilab.
  static double get doublePrecision => pow(2, -doubleWidth).toDouble();

  /// Standard epsilon, the maximum relative precision of IEEE 754 double-precision floating numbers (64 bit).
  /// According to the definition of Prof. Higham and used in the ISO C standard and MATLAB.
  static double get positiveDoublePrecision => 2 * doublePrecision;

  /// Standard epsilon, the maximum relative precision of IEEE 754 single-precision floating numbers (32 bit).
  /// According to the definition of Prof. Demmel and used in LAPACK and Scilab.
  static double get singlePrecision => pow(2, -singleWidth).toDouble();

  /// Standard epsilon, the maximum relative precision of IEEE 754 single-precision floating numbers (32 bit).
  /// According to the definition of Prof. Higham and used in the ISO C standard and MATLAB.
  static double get positiveSinglePrecision => 2 * singlePrecision;

  /// Actual double precision machine epsilon, the smallest number that can be subtracted from 1, yielding a results different than 1.
  /// This is also known as unit roundoff error. According to the definition of Prof. Demmel.
  /// On a standard machine this is equivalent to `DoublePrecision`.
  static double get machineEpsilon => measureMachineEpsilon();

  /// Actual double precision machine epsilon, the smallest number that can be added to 1, yielding a results different than 1.
  /// This is also known as unit roundoff error. According to the definition of Prof. Higham.
  /// On a standard machine this is equivalent to `PositiveDoublePrecision`.
  static double get positiveMachineEpsilon => measurePositiveMachineEpsilon();

  /// The number of significant decimal places of double-precision floating numbers (64 bit).
  static int get doubleDecimalPlaces =>
      (log(doublePrecision) / ln10).abs().floor();

  /// Value representing 10 * 2^(-53) = 1.11022302462516E-15
  static double get defaultDoubleAccuracy => doublePrecision * 10;

  /// Returns the magnitude of the number.
  static int magnitude(double value) {
    // Can't do this with zero because the 10-log of zero doesn't exist.
    if (value == 0.0) {
      return 0;
    }

    // Note that we need the absolute value of the input because Log10 doesn't
    // work for negative numbers (obviously).
    final magnitude = log(value.abs()) / ln10;
    final truncated = magnitude.truncate();

    // To get the right number we need to know if the value is negative or positive
    // truncating a positive number will always give use the correct magnitude
    // truncating a negative number will give us a magnitude that is off by 1 (unless integer)
    return magnitude < 0 && truncated != magnitude ? truncated - 1 : truncated;
  }

  /// Calculates the actual (negative) double precision machine epsilon - the smallest number that can be subtracted from 1, yielding a results different than 1.
  /// This is also known as unit roundoff error. According to the definition of Prof. Demmel.
  static double measureMachineEpsilon() {
    var eps = 1.0;
    while ((1.0 - (eps / 2.0)) < 1.0) {
      eps /= 2.0;
    }
    return eps;
  }

  /// Calculates the actual positive double precision machine epsilon - the smallest number that can be added to 1, yielding a results different than 1.
  /// This is also known as unit roundoff error. According to the definition of Prof. Higham.
  static double measurePositiveMachineEpsilon() {
    var eps = 1.0;
    while ((1.0 + (eps / 2.0)) > 1.0) {
      eps /= 2.0;
    }
    return eps;
  }

  /// Evaluates the minimum distance to the next distinguishable number near the argument value.
  /// Note: Bytedata.setInt64 and getInt64 are not supported in Chrome platform.
  // static double epsilonOf(double value) {
  //   if (value.isInfinite || value.isNaN) {
  //     return double.nan;
  //   }

  //   var byteData = ByteData(8);
  //   byteData.setFloat64(0, value);
  //   var signed64 = byteData.getInt64(0);
  //   if (signed64 == 0) {
  //     signed64++;
  //     byteData.setInt64(0, signed64);
  //     return byteData.getFloat64(0) - value;
  //   }
  //   if (signed64-- < 0) {
  //     byteData.setInt64(0, signed64);
  //     return byteData.getFloat64(0) - value;
  //   }
  //   byteData.setInt64(0, signed64);
  //   return value - byteData.getFloat64(0);
  // }

  /// Compares two doubles and determines if they are equal
  /// within the specified maximum absolute error.
  static bool almostEqualNorm(
      double a, double b, double diff, double maximumAbsoluteError) {
    // If A or B are infinity (positive or negative) then
    // only return true if they are exactly equal to each other -
    // that is, if they are both infinities of the same sign.
    if (a.isInfinite || b.isInfinite) {
      return a == b;
    }

    // If A or B are a NAN, return false. NANs are equal to nothing,
    // not even themselves.
    if (a.isNaN || b.isNaN) {
      return false;
    }

    return diff.abs() < maximumAbsoluteError;
  }

  /// The values are equal if the difference between the two numbers is smaller than 10^(-numberOfDecimalPlaces). We divide by
  /// two so that we have half the range on each side of the numbers, e.g. if <paramref name="decimalPlaces"/> == 2, then 0.01 will equal between
  /// 0.005 and 0.015, but not 0.02 and not 0.00
  static bool almostEqualNormRelative(
      double a, double b, double diff, int decimalPlaces) {
    if (decimalPlaces < 0) {
      // Can't have a negative number of decimal places
      throw ArgumentError(decimalPlaces);
    }

    // If A or B are a NAN, return false. NANs are equal to nothing,
    // not even themselves.
    if (a.isNaN || b.isNaN) {
      return false;
    }

    // If A or B are infinity (positive or negative) then
    // only return true if they are exactly equal to each other -
    // that is, if they are both infinities of the same sign.
    if (a.isInfinite || b.isInfinite) {
      return a == b;
    }

    // If both numbers are equal, get out now. This should remove the possibility of both numbers being zero
    // and any problems associated with that.
    if (a == b) {
      return true;
    }

    // If one is almost zero, fall back to absolute equality
    if (a.abs() < doublePrecision || b.abs() < doublePrecision) {
      // The values are equal if the difference between the two numbers is smaller than
      // 10^(-numberOfDecimalPlaces). We divide by two so that we have half the range
      // on each side of the numbers, e.g. if decimalPlaces == 2,
      // then 0.01 will equal between 0.005 and 0.015, but not 0.02 and not 0.00
      return diff.abs() < pow(10, -decimalPlaces) * 0.5;
    }

    // If the magnitudes of the two numbers are equal to within one magnitude the numbers could potentially be equal
    final magnitudeOfFirst = magnitude(a);
    final magnitudeOfSecond = magnitude(b);
    final magnitudeOfMax = max(magnitudeOfFirst, magnitudeOfSecond);
    if (magnitudeOfMax > (min(magnitudeOfFirst, magnitudeOfSecond) + 1)) {
      return false;
    }

    // The values are equal if the difference between the two numbers is smaller than
    // 10^(-numberOfDecimalPlaces). We divide by two so that we have half the range
    // on each side of the numbers, e.g. if decimalPlaces == 2,
    // then 0.01 will equal between 0.00995 and 0.01005, but not 0.0015 and not 0.0095
    return diff.abs() < pow(10, magnitudeOfMax - decimalPlaces) * 0.5;
  }

  /// Compares two doubles and determines if they are equal within
  /// the specified maximum error.
  static bool almostEqual(double a, double b, [double? maximumAbsoluteError]) =>
      almostEqualNorm(
          a, b, a - b, maximumAbsoluteError ?? defaultDoubleAccuracy);

  /// Compares two doubles and determines if they are equal to within the specified number of decimal places or not. If the numbers
  /// are very close to zero an absolute difference is compared, otherwise the relative difference is compared.
  static bool almostEqualRelative(double a, double b, int decimalPlaces) =>
      almostEqualNormRelative(a, b, a - b, decimalPlaces);
}

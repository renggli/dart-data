/// A collection of frequently used mathematical constants.
class Constants {
  /// The number e
  static const double e = 2.7182818284590452353602874713526624977572470937000;

  /// The number log[2](e)
  static const double log2E =
      1.4426950408889634073599246810018921374266459541530;

  /// The number log[10](e)
  static const double log10E =
      0.43429448190325182765112891891660508229439700580366;

  /// The number log[e](2)
  static const double ln2 =
      0.69314718055994530941723212145817656807550013436026;

  /// The number log[e](10)
  static const double ln10 =
      2.3025850929940456840179914546843642076011014886288;

  /// The number log[e](pi)
  static const double lnPi =
      1.1447298858494001741434273513530587116472948129153;

  /// The number log[e](2*pi)/2
  static const double ln2PiOver2 =
      0.91893853320467274178032973640561763986139747363780;

  /// The number 1/e
  static const double invE =
      0.36787944117144232159552377016146086744581113103176;

  /// The number sqrt(e)
  static const double sqrtE =
      1.6487212707001281468486507878141635716537761007101;

  /// The number sqrt(2)
  static const double sqrt2 =
      1.4142135623730950488016887242096980785696718753769;

  /// The number sqrt(3)
  static const double sqrt3 =
      1.7320508075688772935274463415058723669428052538104;

  /// The number sqrt(1/2) = 1/sqrt(2) = sqrt(2)/2
  static const double sqrt1Over2 =
      0.70710678118654752440084436210484903928483593768845;

  /// The number sqrt(3)/2
  static const double halfSqrt3 =
      0.86602540378443864676372317075293618347140262690520;

  /// The number pi
  static const double pi = 3.1415926535897932384626433832795028841971693993751;

  /// The number pi*2
  static const double pi2 = 6.2831853071795864769252867665590057683943387987502;

  /// The number pi/2
  static const double piOver2 =
      1.5707963267948966192313216916397514420985846996876;

  /// The number pi*3/2
  static const double pi3Over2 =
      4.71238898038468985769396507491925432629575409906266;

  /// The number pi/4
  static const double piOver4 =
      0.78539816339744830961566084581987572104929234984378;

  /// The number sqrt(pi)
  static const double sqrtPi =
      1.7724538509055160272981674833411451827975494561224;

  /// The number sqrt(2pi)
  static const double sqrt2Pi =
      2.5066282746310005024157652848110452530069867406099;

  /// The number sqrt(pi/2)
  static const double sqrtPiOver2 =
      1.2533141373155002512078826424055226265034933703050;

  /// The number sqrt(2*pi*e)
  static const double sqrt2PiE =
      4.1327313541224929384693918842998526494455219169913;

  /// The number log(sqrt(2*pi))
  static const double logSqrt2Pi =
      0.91893853320467274178032973640561763986139747363778;

  /// The number log(sqrt(2*pi*e))
  static const double logSqrt2PiE =
      1.4189385332046727417803297364056176398613974736378;

  /// The number log(2 * sqrt(e / pi))
  static const double logTwoSqrtEOverPi =
      0.6207822376352452223455184457816472122518527279025978;

  /// The number 1/pi
  static const double invPi =
      0.31830988618379067153776752674502872406891929148091;

  /// The number 2/pi
  static const double twoInvPi =
      0.63661977236758134307553505349005744813783858296182;

  /// The number 1/sqrt(pi)
  static const double invSqrtPi =
      0.56418958354775628694807945156077258584405062932899;

  /// The number 1/sqrt(2pi)
  static const double invSqrt2Pi =
      0.39894228040143267793994605993438186847585863116492;

  /// The number 2/sqrt(pi)
  static const double twoInvSqrtPi =
      1.1283791670955125738961589031215451716881012586580;

  /// The number 2 * sqrt(e / pi)
  static const double twoSqrtEOverPi =
      1.8603827342052657173362492472666631120594218414085755;

  /// The number (pi)/180 - factor to convert from Degree (deg) to Radians (rad).
  static const double degreesToRadians =
      0.017453292519943295769236907684886127134428718885417;

  /// The number 180/(pi)
  static const double radiansToDegrees =
      57.295779513082320876798154814105170332405472466564;

  /// The number (pi)/200 - factor to convert from NewGrad (grad) to Radians (rad).
  static const double grad =
      0.015707963267948966192313216916397514420985846996876;

  /// The number ln(10)/20 - factor to convert from Power Decibel (dB) to Neper (Np). Use this version when the Decibel represent a power gain but the compared values are not powers (e.g. amplitude, current, voltage).
  static const double powerDecibel =
      0.11512925464970228420089957273421821038005507443144;

  /// The number ln(10)/10 - factor to convert from Neutral Decibel (dB) to Neper (Np). Use this version when either both or neither of the Decibel and the compared values represent powers.
  static const double neutralDecibel =
      0.23025850929940456840179914546843642076011014886288;

  /// The Catalan constant
  /// Sum(k=0 -> inf){ (-1)^k/(2*k + 1)2 }
  static const double catalan =
      0.9159655941772190150546035149323841107741493742816721342664981196217630197762547694794;

  /// The Euler-Mascheroni constant
  /// lim(n -> inf){ Sum(k=1 -> n) { 1/k - log(n) } }
  static const double eulerMascheroni =
      0.5772156649015328606065120900824024310421593359399235988057672348849;

  /// The number (1+sqrt(5))/2, also known as the golden ratio
  static const double goldenRatio =
      1.6180339887498948482045868343656381177203091798057628621354486227052604628189024497072;

  /// The Glaisher constant
  /// e^(1/12 - Zeta(-1))
  static const double glaisher =
      1.2824271291006226368753425688697917277676889273250011920637400217404063088588264611297;

  /// The Khinchin constant
  /// prod(k=1 -> inf){1+1/(k*(k+2))^log(k,2)}
  static const double khinchin =
      2.6854520010653064453097148354817956938203822939944629530511523455572188595371520028011;
}

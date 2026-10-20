# Symbolic Benchmark Baseline

Captured on macOS (Apple Silicon), Dart 3.13 VM (JIT via `dart run`).

## Running the Benchmark

```sh
# Run all symbolic benchmarks
dart run benchmark/symbolic_benchmark.dart

# Filter by benchmark name substring
dart run benchmark/symbolic_benchmark.dart katsura
dart run benchmark/symbolic_benchmark.dart expand
```

Every benchmark executes untimed warmup runs first, then evaluates timed runs reporting the median time and 95% empirical bootstrap confidence interval (computed via `Bootstrap` in `package:data/stats.dart`). Fast workloads repeat their body `inner` times per sample to reduce timer quantization noise.

## Latest Benchmark Results

| Benchmark | Category | Median (µs) | 95% CI (µs) | Min–Max (µs) |
| --- | --- | ---: | ---: | ---: |
| `expand((x+y+z+1)^12)` | Algebraic Expansion | 2,097 | [2,048, 2,469] | 1,940–5,887 |
| `series(exp(sin(x)), x, 0, 20)` | Series & Calculus | 78.6 | [75.4, 80.1] | 72.6–316 |
| `det 6x6 symbolic` | Symbolic Linear Algebra | 32,944 | [32,715, 33,059] | 32,306–37,296 |
| `integrate corpus (45)` | Series & Calculus | 182 | [166, 238] | 146–439 |
| `simplify corpus (80)` | Simplification | 78.5 | [74.8, 81.0] | 70.3–163 |
| `factor(x^24 - 1)` | Polynomial Factorization | 16.6 | [16.5, 17.0] | 15.8–18.8 |
| `solvePolynomialSystem katsura-2` | Gröbner Basis Systems | 793 | [637, 903] | 552–1,420 |
| `solvePolynomialSystem katsura-3` | Gröbner Basis Systems | 3,186 | [3,103, 5,369] | 3,103–5,369 |

---

## Historical Comparison (Pre- vs Post-Refactoring)

Comparison against the original baseline captured before the numeric-tower refactoring (phase F0), introducing the zero-cost `Integer` extension type (`int | BigInt`), atomic `Number` tower (`IntegerNumber`, `FractionNumber`, `RealNumber`, `ComplexNumber`), opaque `Constant`, and unified N-ary `Add` / `Mul` / `Pow` AST:

| Benchmark | Baseline VM (µs) | Latest VM (µs) | 95% CI (µs) | VM Speedup |
| --- | ---: | ---: | ---: | ---: |
| `expand((x+y+z+1)^12)` | 6,679 | 2,097 | [2,048, 2,469] | **3.2×** |
| `series(exp(sin(x)), x, 0, 20)` | 74 | 78.6 | [75.4, 80.1] | **0.9×** |
| `det` 6×6 symbolic (`(r+1)^c + x^((r+c)%3)*y`) | 638,445 | 32,944 | [32,715, 33,059] | **19.4×** |
| `integrate` corpus (45 integrands) | 194 | 182 | [166, 238] | **1.1×** |
| `simplify` corpus (80 expressions) | 53 | 78.5 | [74.8, 81.0] | **0.7×** |
| `factor(x^24 - 1)` | 32 | 16.6 | [16.5, 17.0] | **1.9×** |
| `solvePolynomialSystem` Katsura-2 | 922 | 793 | [637, 903] | **1.2×** |
| `solvePolynomialSystem` Katsura-3 | 3,860,962 | 3,186 | [3,103, 5,369] | **1,211.8×** |

### Notes

- `solvePolynomialSystem` Katsura-3 finds both exact rational solutions (`{a: 1, b: 0, c: 0, d: 0}` and `{a: 1/3, b: 0, c: 0, d: 1/3}`) without 53-bit or 64-bit integer overflow during FGLM Gaussian elimination.
- Confidence intervals are computed non-parametrically using 1,000 bootstrap resamples on the measured per-run samples.

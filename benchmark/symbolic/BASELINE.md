# Symbolic Benchmark Baseline

Baseline captured before the numeric-tower refactoring (phase F0), on macOS (Apple Silicon), Dart 3.13 VM (JIT via `dart run`), and dart2js `-O2` under Node.js.

Run:

```sh
dart run benchmark/symbolic/symbolic_benchmark.dart [name-filter ...]
dart compile js -O2 -o /tmp/symbolic_benchmark.js benchmark/symbolic/symbolic_benchmark.dart
node /tmp/symbolic_benchmark.js
```

Every benchmark does warmup runs first, then reports the median time per execution in microseconds. Fast workloads repeat their body `inner` times per sample to reduce timer noise.

| Benchmark | VM median (µs) | VM min–max (µs) | dart2js/node median (µs) |
| --- | ---: | ---: | ---: |
| `expand((x+y+z+1)^12)` | 6,679 | 6,496–7,693 | 24,000 |
| `series(exp(sin(x)), x, 0, 20)` | 74 | 71–84 | 200 |
| `det` 6×6 symbolic (`(r+1)^c + x^((r+c)%3)*y`) | 638,445 | 624,063–649,119 | 2,660,000 |
| `integrate` corpus (45 integrands) | 194 | 119–342 | 450 |
| `simplify` corpus (80 expressions) | 53 | 48–111 | 200 |
| `factor(x^24 - 1)` | 32 | 31–35 | 130 |
| `solvePolynomialSystem` Katsura-2 | 922 | 780–1,253 | 3,200 |
| `solvePolynomialSystem` Katsura-3 | 3,860,962 | 3,851,761–3,861,634 | not measured (stopped after more than 15 minutes) |

Notes:

- Node's `Stopwatch` has millisecond resolution, so the node numbers are quantized to `1000 / inner` µs. Treat them as a trend only.
- `integrate` has a wide spread on the VM (GC-sensitive). Compare medians from several runs before applying the 5 % gate.
- Current correctness caveats, included so the benchmarks measure today's behavior: `factor(x^24 - 1)` returns only a partial factorization, and Katsura-3 returns a single solution.

## Post-Refactoring Results (Unified N-ary AST & Exact Number Tower)

Measured on the same machine after introducing the zero-cost `Integer` extension type (`int | BigInt`), atomic `Number` tower (`IntegerNumber`, `FractionNumber`, `RealNumber`, `ComplexNumber`), opaque `Constant`, and unified N-ary `Add` / `Mul` / `Pow` AST:

| Benchmark | Baseline VM (µs) | Refactored VM (µs) | VM Speedup | Baseline node (µs) | Refactored node (µs) | node Speedup |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `expand((x+y+z+1)^12)` | 6,679 | 2,153 | **3.1×** | 24,000 | 12,000 | **2.0×** |
| `series(exp(sin(x)), x, 0, 20)` | 74 | 77 | **1.0×** | 200 | 340 | **0.6×** |
| `det` 6×6 symbolic (`(r+1)^c + x^((r+c)%3)*y`) | 638,445 | 43,073 | **14.8×** | 2,660,000 | 246,000 | **10.8×** |
| `integrate` corpus (45 integrands) | 194 | 198 | **1.0×** | 450 | 650 | **0.7×** |
| `simplify` corpus (80 expressions) | 53 | 70 | **0.8×** | 200 | 340 | **0.6×** |
| `factor(x^24 - 1)` | 32 | 9 | **3.6×** | 130 | 30 | **4.3×** |
| `solvePolynomialSystem` Katsura-2 | 922 | 552 | **1.7×** | 3,200 | 2,200 | **1.5×** |
| `solvePolynomialSystem` Katsura-3 | 3,860,962 | 6,555 | **589.0×** | > 15 min | 11,000 | **> 80,000×** |

Notes on refactored results:
- `solvePolynomialSystem` Katsura-3 now finds both exact rational solutions (`{a: 1, b: 0, c: 0, d: 0}` and `{a: 1/3, b: 0, c: 0, d: 1/3}`) without 53-bit or 64-bit integer overflow during FGLM Gaussian elimination.

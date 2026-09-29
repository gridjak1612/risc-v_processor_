# 2-Bit Dynamic Branch Predictor — Simulation & Accuracy Report

This report documents the behaviour and measured accuracy of the 2-bit dynamic
branch predictor integrated into the five-stage RISC-V (RV32I) pipeline. It explains
the predictor design, the measurement method, three boundary-condition experiments,
and why each result comes out the way it does. All figures below were reproduced by
direct simulation of the design.

---

## 1. Predictor Design Under Test

The predictor is a **local (per-address) 2-bit scheme with an integrated branch
target buffer**:

- **Prediction table:** 256 entries, indexed by the low-order (word-aligned) bits of
  the branch address.
- **Per-entry contents:**
  - a **2-bit saturating counter** — the direction decision, and
  - a **32-bit target field** — where to jump if the branch is predicted taken.
- **One lookup, two answers:** a single table access yields both *direction* and
  *target*, so the Fetch stage can redirect the PC in the same cycle without stalling
  on a correct prediction.

### Counter state machine
The 2-bit counter has four states. The high bit is the prediction; the counter
saturates at both ends (it never wraps).

| State | Meaning | Prediction |
|:-----:|---------|:----------:|
| `00` | Strongly Not Taken | Not Taken |
| `01` | Weakly Not Taken | Not Taken |
| `10` | Weakly Taken | Taken |
| `11` | Strongly Taken | Taken |

```
   real=N        real=N        real=N
  ┌──────┐      ┌──────┐      ┌──────┐
  ▼      │      ▼      │      ▼      │
[ 00 ]──►[ 01 ]──►[ 10 ]──►[ 11 ]
  ▲   T   │  T ▲   │  T   ▲   │  T (saturate)
  │saturate└────┘  └──────┘   │
  └── N ───────────────────────
  PREDICT NOT TAKEN │ PREDICT TAKEN
       (00,01)      │    (10,11)
```

**Update policy (applied when the branch truly resolves in Execute):**
- actually **taken** → move one step toward `11` and refresh the stored target,
- actually **not taken** → move one step toward `00`.

**Why 2 bits:** the extra bit adds hysteresis. A single unexpected outcome cannot flip
the prediction on its own, so a stable branch (e.g. a loop) tolerates one anomaly
without a double penalty — the classic advantage over a 1-bit predictor.

> **Reset behaviour:** every entry initialises to `00` (Strongly Not Taken) on reset.
> This choice shapes the warm-up cost seen in the experiments below.

---

## 2. Measurement Methodology

- **Where branches are resolved:** the Execute stage computes the true direction and
  true target, compares them against the Fetch-time prediction, and raises a
  misprediction whenever the direction is wrong **or** the direction is right but the
  predicted target differs.
- **What is counted:** the testbench increments a *branch* counter every time a branch
  resolves, and a *misprediction* counter whenever that resolution disagrees with the
  prediction. Counting begins only after reset is released.
- **Accuracy definition:**

  ```
  Accuracy = (Total Branches − Mispredictions) / Total Branches × 100%
  ```

- **Penalty per miss:** each misprediction flushes the speculatively-fetched
  instructions and redirects the PC, costing a few bubble cycles — so fewer
  mispredictions means a CPI closer to the ideal of 1.

Each experiment loads a small hand-written program that forces one branch behaviour,
runs for a fixed number of cycles, and reports the totals.

---

## 3. Results Summary

| # | Scenario | Branch pattern | Branches | Mispredicts | **Accuracy** |
|:-:|----------|----------------|:--------:|:-----------:|:------------:|
| 1 | Always Taken (loop) | T, T, T, … | 18 | 2 | **88%** |
| 2 | Never Taken | N, N, N, … | 48 | 2 | **95%** |
| 3 | Alternating | T, N, T, N, … | 40 | 10 | **75%** |

The three cases are chosen to probe the predictor's **best case (a stable loop)**, its
**cheapest-warm-up case (never-taken from a not-taken reset)**, and its **worst case
(strict alternation)**.

---

## 4. Scenario 1 — Constantly Taken Branch (Loop)

**Setup:** a backward conditional branch forms a loop whose condition is true on every
pass, giving an unbroken run of *taken* outcomes.

**Result:** 18 branches, 2 mispredictions → **88% accuracy**.

**Why:** every entry starts at `00` (Strongly Not Taken), so the first encounters
predict *not taken* and miss while the counter climbs:

```
pass 1:  state 00 → predict NOT TAKEN, actually TAKEN → MISS, state → 01
pass 2:  state 01 → predict NOT TAKEN, actually TAKEN → MISS, state → 10
pass 3:  state 10 → predict TAKEN,     actually TAKEN → HIT,  state → 11
pass 4+: state 11 → predict TAKEN                     → HIT (stays saturated)
```

After two warm-up misses the counter saturates at `11` and every subsequent iteration
is a correct hit. The 88% is entirely the fixed start-up cost; steady-state accuracy is
100%. Longer loops would push the overall figure asymptotically toward 100%.

---

## 5. Scenario 2 — Never-Taken Branches

**Setup:** a chain of forward branches whose conditions are always false, so the true
outcome is *not taken* every time.

**Result:** 48 branches, 2 mispredictions → **95% accuracy**.

**Why:** because entries reset to `00` (Not Taken), a never-taken workload matches the
initial state immediately — **zero warm-up cost**. The predictor sits at `00`/`01` and
predicts *not taken* correctly throughout. The only two misses come from a separate
unconditional backward branch used to repeat the test loop, not from the never-taken
branches themselves. This scenario shows the value of the reset choice: the common
"branch rarely taken" pattern pays almost nothing.

---

## 6. Scenario 3 — Alternating Branch (Worst Case)

**Setup:** the branch condition flips on every pass: taken, not taken, taken, not
taken, …

**Result:** 40 branches, 10 mispredictions → **75% accuracy** (closer to ~50% if the
alternating branch is measured in isolation).

**Why:** strict alternation is the pathological input for a local 2-bit counter. The
state oscillates around the decision boundary between `01` (Weakly Not Taken) and `10`
(Weakly Taken):

```
… predict NOT TAKEN (01) → actually TAKEN     → MISS → 10
   predict TAKEN     (10) → actually NOT TAKEN → MISS → 01
   predict NOT TAKEN (01) → actually TAKEN     → MISS → 10  …
```

The prediction is wrong on essentially every alternating branch because the counter is
always one step behind the pattern. The measured 75% is higher than 50% only because
this program mixes the volatile branch with **stable** unconditional branches (loop
resets) that predict perfectly and dilute the miss rate. This experiment confirms the
design reproduces the known worst-case boundary of 2-bit predictors — the exact case a
history-based predictor (see §7) would fix.

---

## 7. Interpretation & Future Work

**What the numbers show:**
- The predictor excels on **stable, repetitive** branches (loops), where it converges
  to 100% after a tiny warm-up.
- It pays **near-zero** cost on **rarely-taken** branches thanks to the not-taken reset.
- It degrades to its **theoretical worst case** on **strictly alternating** branches —
  correct and expected behaviour for a local 2-bit scheme.

**Design limitations exposed by these tests:**
- Only equality branches are decoded; other conditional branches and jumps are not yet
  handled.
- There is no load-use stall, so a load feeding an immediately dependent instruction is
  a separate (data-hazard) gap outside this report's scope.

**Natural next steps:**
- Add **history-based prediction** (global history / gshare or a correlating predictor)
  to beat the alternating worst case.
- Add a **return-address stack** for call/return pairs.
- **Separate** the direction table from the target buffer for a cleaner, more scalable
  structure.
- Extend branch decoding to the full conditional/jump set and re-measure accuracy and
  CPI across a broader instruction mix.

---

*All accuracy figures in this report were obtained by simulating the design with the
corresponding test program and reading the testbench's branch and misprediction
counters.*
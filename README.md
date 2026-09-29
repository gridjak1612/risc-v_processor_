# RISC-V Pipelined Processor with 2-Bit Dynamic Branch Predictor

A five-stage pipelined **RISC-V (RV32I)** processor written in Verilog, featuring a
**2-bit dynamic branch predictor** with an integrated branch target buffer (BTB). The
predictor lets the fetch stage redirect the PC on branches *without stalling* when the
prediction is correct, and recovers by flushing on a misprediction.

The design is fully simulatable and ships with a self-checking testbench and three
hand-written test programs that measure branch-prediction accuracy under different
branch behaviours.

---

## Features

- **5-stage pipeline:** Fetch → Decode → Execute → Memory → Writeback
- **2-bit saturating-counter branch predictor** (256-entry history table)
- **Integrated Branch Target Buffer (BTB):** one table lookup returns both the
  predicted *direction* and the predicted *target*
- **Data-hazard handling** by forwarding from the Memory and Writeback stages
- **Control-hazard handling** by predict-and-flush with PC redirection
- **Self-checking testbench** that counts branches and mispredictions and reports
  accuracy
- **Three test scenarios** (always-taken, never-taken, alternating) with reproducible
  results

---

## Architecture Overview

```
        ┌────────┐   ┌────────┐   ┌─────────┐   ┌────────┐   ┌───────────┐
  PC ──►│ FETCH  ├──►│ DECODE ├──►│ EXECUTE ├──►│ MEMORY ├──►│ WRITEBACK │
        │ +BHT   │   │ +CU/RF │   │ +ALU/BP │   │ +DMEM  │   │           │
        └───┬────┘   └────────┘   └────┬────┘   └────────┘   └─────┬─────┘
            │  predict (dir + target)  │ resolve branch,          │
            │◄─────────────────────────┤ flush + redirect on miss │
            │        forwarding ◄──────┴──────────────────────────┘
```

- Branches are **predicted in Fetch** and **resolved in Execute**. A wrong guess costs
  a pipeline flush of the speculatively fetched instructions.
- The predictor entry holds a **2-bit counter** (direction) plus a **32-bit target**
  (destination), so a single lookup drives an immediate PC redirect.

### 2-Bit Predictor State Machine

| State | Meaning | Prediction |
|:-----:|---------|:----------:|
| `00` | Strongly Not Taken | Not Taken |
| `01` | Weakly Not Taken | Not Taken |
| `10` | Weakly Taken | Taken |
| `11` | Strongly Taken | Taken |

The counter saturates at both ends and moves one step toward *taken* or *not taken*
after each branch resolves. Two bits provide hysteresis, so a single anomaly (e.g. a
loop exit) doesn't immediately flip the prediction. All entries reset to `00`.

---

## Repository Structure

| File | Description |
|------|-------------|
| `pipeline_top.v` | Top-level module wiring all five stages + hazard unit |
| `fetch_cycle.v` | PC logic, instruction memory, **branch predictor + BHT/BTB** |
| `decode_cycle.v` | Control unit, register file, sign-extension, IF/ID→ID/EX register |
| `execute_cycle.v` | ALU, forwarding muxes, **branch resolution & misprediction logic** |
| `hazard_unit.v` | Data-forwarding control and flush signal |
| `primitives.v` | PC register, adder, register file, sign-extend, muxes |
| `Control_Unit_Top.v` | Main decoder + ALU decoder |
| `Main_Decoder.v` | Opcode → control signals |
| `ALU_Decoder.v` | ALUOp/funct → ALU control |
| `ALU.v` | Arithmetic-logic unit |
| `Instruction_Memory.v` | Instruction memory (loads a `.hex` program) |
| `Data_Memory.v` | Data memory |
| `tb.v` | Testbench: counts branches/mispredictions and prints accuracy |
| `memfile1_taken.hex` | Test program — always-taken loop |
| `memfile2_never.hex` | Test program — never-taken branches |
| `memfile3_alt.hex` | Test program — alternating taken/not-taken |
| `memfile.hex` | Active program loaded by the instruction memory |
| `test_results_report.md` | Detailed accuracy report and analysis |

> The instruction memory loads `memfile.hex`. To run a specific scenario, copy the
> desired scenario file over `memfile.hex` before simulating (see below).

---

## How to Simulate

Requires [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` + `vvp`), or any
Verilog simulator (ModelSim/Questa, Vivado, Verilator).

### Using Icarus Verilog

```bash
# 1. Pick a test scenario (example: always-taken loop)
cp memfile1_taken.hex memfile.hex

# 2. Compile (note: Control_Unit_Top.v includes Main_Decoder.v and ALU_Decoder.v)
iverilog -o sim_out tb.v pipeline_top.v fetch_cycle.v decode_cycle.v \
    execute_cycle.v hazard_unit.v primitives.v Instruction_Memory.v \
    Data_Memory.v Control_Unit_Top.v ALU.v

# 3. Run
vvp sim_out
```

The simulation prints a summary like:

```
==========================================
          SIMULATION RESULTS
==========================================
Total Branches: 18
Mispredictions: 2
Accuracy: 88%
==========================================
```

A waveform (`pipeline.vcd`) is also produced and can be viewed in GTKWave.

---

## Results

Measured branch-prediction accuracy across the three scenarios:

| Scenario | Branch pattern | Branches | Mispredicts | **Accuracy** |
|----------|----------------|:--------:|:-----------:|:------------:|
| Always Taken (loop) | T, T, T, … | 18 | 2 | **88%** |
| Never Taken | N, N, N, … | 48 | 2 | **95%** |
| Alternating | T, N, T, N, … | 40 | 10 | **75%** |

- **Always taken:** only the first two passes miss while the counter warms up from the
  not-taken reset; steady state is 100%.
- **Never taken:** the not-taken reset matches immediately, so there's essentially no
  warm-up cost.
- **Alternating:** the theoretical worst case — the counter oscillates across the
  decision boundary and mispredicts nearly every time.

See [`test_results_report.md`](test_results_report.md) for the full analysis with
cycle-by-cycle traces.

---

## Known Limitations

- Only **equality branches (BEQ)** are decoded; other conditional branches and jumps
  are not yet handled.
- **No load-use stall** — a load feeding an immediately dependent instruction is not
  bubbled (a known simplification of the strict 5-stage design).

---

## Future Work

- Add **load-use hazard detection** with a one-cycle stall.
- Support the **full branch/jump set** (BNE, BLT, BGE, JAL, JALR).
- Explore **history-based prediction** (global history / gshare, correlating
  predictors) to beat the alternating worst case.
- Add a **return-address stack** for call/return pairs.
- **Separate** the direction table from the target buffer for a more scalable design.

---

## License

Add a license of your choice (e.g. MIT) if you intend others to reuse this code.

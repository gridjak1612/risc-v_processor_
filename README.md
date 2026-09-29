# RISC-V Pipelined Processor (RV32I) – Verilog

This repository contains a **5-stage pipelined RISC-V processor (RV32I)** written in Verilog.  
The core supports hazard detection and features a **Gshare branch predictor** to improve branch accuracy.



🔹 Features
- RV32I ISA support  
- 5-stage pipeline: IF → ID → EX → MEM → WB  
- Gshare branch predictor  
- Hazard detection unit  
- Instruction & data memory  
- Fully testbench-driven verification  


 File Overview
| Module                      | Function |

| `Pipeline_Top.v`            | Top-level processor integration |
| `Fetch_Cycle.v`             | PC update + Instruction fetch |
| `Decode_Cyle.v`             | Register read + immediate generation |
| `Execute_Cycle.v`           | ALU + branch evaluation |
| `Memory_Cycle.v`            | Load/Store operations |
| `Writeback_Cycle.v`         | Write result to register file |
| `gshare_branch_predictor.v` | Global history based prediction |
| `Hazard_unit.v`             | Stall/flush control |



 Run Simulation

git clone https://github.com/gridjak1612/risc-v_processor_.git
cd risc-v_processor_
iverilog -g2012 -o pipeline_tb.vvp *.v
vvp pipeline_tb.vvp


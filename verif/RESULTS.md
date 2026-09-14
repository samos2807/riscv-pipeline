# Verification results (2026-09-14)

Method: every RTL variant runs the same programs on `riscv_diff_tb.v` with the
hex-loading `imem_hex.v`. After the run the bench dumps x1..x31, all 64 data-memory
words, and the retirement stream (every register-file write and every store, in
order). `gen_prog.py` is a reference model of the 8 implemented instructions
(ADD SUB AND OR ADDI LW SW BEQ) written from the RISC-V specification (encodings,
x0 discard, 12-bit sign extension, BEQ target = pc + imm, word-addressed memory),
not from the RTL. It generates the programs, predicts the final state and the
retirement stream, and checks the RTL dump against them. The model was written by
the same author as the RTL fixes; two facts limit the bias that could introduce:
the February RTL, written before any fix, passes the same model, and a mutant with
forwarding disabled fails it.

Programs:
- `hazard`: the pipeline hazard regression, 30 static / 34 dynamic instructions:
  RAW at distance 1, 2 and 3, load-use (stall), store with forwarded base and data,
  write to x0, taken and not-taken forward BEQ, load feeding a branch, a 3-iteration
  backward loop, a backward branch that is NOT taken (the static predictor guesses
  wrong and the registered redirect recovers to pc+4), load-use into store data.
  21 register retirements, 3 stores.
- `rand000`..`rand099`: random programs, seed 1, up to 63 words each: forward
  branches taken and not taken, counted backward loops (always taken), conditional
  backward branches (taken once at most, then fall through), dependent chains,
  load-then-use pairs, writes to x0.

Dynamic coverage of the 101 programs, counted by the reference model:

| class | dynamic events | programs with at least one |
|---|---|---|
| forward branch taken (predicted not taken: mispredict) | 482 | 101 |
| forward branch not taken | 282 | 83 |
| backward branch taken (predicted taken) | 323 | 93 |
| backward branch not taken (predicted taken: mispredict) | 155 | 79 |
| load followed immediately by a use | 330 | 99 |

Run (iverilog 11, python 3.10):

```
bash verif/run_verif.sh out 100 1 rtl_github rtl_pipelined rtl_fix7
=== rtl_github:     101 pass, 0 fail    (published RTL, github.com/samos2807/riscv-pipeline)
=== rtl_pipelined:  101 pass, 0 fail    (Fix A/B + static predictor)
=== rtl_fix7:       101 pass, 0 fail    (final: A..H, clock gated)
=== cross-RTL retirement streams        (no differences)
=== TOTAL: 303 runs, 0 failures
python3 verif/gen_prog.py cov out/programs     (the table above)
```

Mutation check, to show the checker can fail: a copy of the final RTL with EX-stage
forwarding disabled (`next_forward_a = 2'b00` in forwarding_unit.v) fails the hazard
program and all 20 random programs it was run on.

Not covered: rv32ui cannot run, the core implements 8 instructions and the suite needs
LUI, JAL, JALR, SLT, shifts and the other branches. No gate-level simulation, no
SDF timing simulation. Power in the flow reports uses default switching activity,
not these programs' activity.

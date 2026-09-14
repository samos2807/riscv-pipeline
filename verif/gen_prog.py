#!/usr/bin/env python3
"""
gen_prog.py -- program generator + reference model for riscv_core.

The core implements exactly 8 instructions: ADD SUB AND OR ADDI LW SW BEQ.
This script
  * encodes programs from those instructions,
  * runs them on an independent reference model (regs, 64-word dmem),
  * writes prog.hex, expected.txt (final state), retire_exp.log (expected
    retirement stream), asm.txt and cycles (simulation budget),
  * checks an RTL state dump / retire log against the expected files.

Usage:
  gen_prog.py gen   <out_dir> <n_random> <seed>
  gen_prog.py check <expected.txt> <state.txt> <retire_exp.log> <retire.log>
"""
import os
import random
import sys

MASK = 0xFFFFFFFF
HALT = 0x00000063          # beq x0,x0,0
NOP  = 0x00000013          # addi x0,x0,0
MEMW = 64                  # data memory words


# ----------------------------------------------------------------- encode
def r_type(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def add(rd, rs1, rs2):  return r_type(0x00, rs2, rs1, 0, rd, 0x33)
def sub(rd, rs1, rs2):  return r_type(0x20, rs2, rs1, 0, rd, 0x33)
def and_(rd, rs1, rs2): return r_type(0x00, rs2, rs1, 7, rd, 0x33)
def or_(rd, rs1, rs2):  return r_type(0x00, rs2, rs1, 6, rd, 0x33)

def addi(rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13

def lw(rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03

def sw(rs2, rs1, imm):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 0x1F) << 7) | 0x23

def beq(rs1, rs2, imm):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | \
           (rs1 << 15) | (0 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63


# ---------------------------------------------------------------- decode
def sext(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v

def disasm(w):
    op = w & 0x7F; rd = (w >> 7) & 31; f3 = (w >> 12) & 7
    rs1 = (w >> 15) & 31; rs2 = (w >> 20) & 31; f7 = w >> 25
    if op == 0x33:
        n = {(0, 0): "add", (0, 0x20): "sub", (7, 0): "and", (6, 0): "or"}[(f3, f7)]
        return f"{n} x{rd},x{rs1},x{rs2}"
    if op == 0x13: return f"addi x{rd},x{rs1},{sext(w >> 20, 12)}"
    if op == 0x03: return f"lw x{rd},{sext(w >> 20, 12)}(x{rs1})"
    if op == 0x23:
        imm = sext((f7 << 5) | rd, 12); return f"sw x{rs2},{imm}(x{rs1})"
    if op == 0x63:
        imm = sext((((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11) | (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1), 13)
        return f"beq x{rs1},x{rs2},{imm}"
    return f".word 0x{w:08x}"


# ------------------------------------------------------- reference model
def run_model(prog, max_dyn=5000):
    """Execute prog (list of 32-bit words at 0,4,8,...). Returns
    (regs, mem, retire_stream, dynamic_count). Stops at a halt (beq to
    itself) or when the pc leaves the 64-word window."""
    regs = [0] * 32
    mem  = [0] * MEMW
    retire = []
    stats = {"fwd_taken": 0, "fwd_not": 0, "bwd_taken": 0, "bwd_not": 0, "load_use": 0}
    pc = 0
    dyn = 0
    last_load_rd = None
    while dyn < max_dyn:
        idx = pc >> 2
        w = prog[idx] if idx < len(prog) else HALT
        op = w & 0x7F; rd = (w >> 7) & 31; f3 = (w >> 12) & 7
        rs1 = (w >> 15) & 31; rs2 = (w >> 20) & 31; f7 = w >> 25
        npc = pc + 4
        dyn += 1
        if op == 0x33:
            a, b = regs[rs1], regs[rs2]
            if f3 == 0 and f7 == 0:      v = (a + b) & MASK
            elif f3 == 0 and f7 == 0x20: v = (a - b) & MASK
            elif f3 == 7:                v = a & b
            elif f3 == 6:                v = a | b
            else: raise ValueError(f"bad R-type {w:08x}")
            if rd: regs[rd] = v; retire.append(f"x{rd} <= 0x{v:08x}")
        elif op == 0x13:
            v = (regs[rs1] + sext(w >> 20, 12)) & MASK
            if rd: regs[rd] = v; retire.append(f"x{rd} <= 0x{v:08x}")
        elif op == 0x03:
            addr = (regs[rs1] + sext(w >> 20, 12)) & MASK
            assert addr % 4 == 0 and (addr >> 2) < MEMW, f"lw out of range {addr}"
            v = mem[addr >> 2]
            if rd: regs[rd] = v; retire.append(f"x{rd} <= 0x{v:08x}")
        elif op == 0x23:
            addr = (regs[rs1] + sext((f7 << 5) | rd, 12)) & MASK
            assert addr % 4 == 0 and (addr >> 2) < MEMW, f"sw out of range {addr}"
            mem[addr >> 2] = regs[rs2]
            retire.append(f"MEM[{addr >> 2}] <= 0x{regs[rs2]:08x}")
        elif op == 0x63:
            imm = sext((((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11) | (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1), 13)
            taken = regs[rs1] == regs[rs2]
            if taken and imm == 0:      # halt
                dyn -= 1
                break
            stats[("bwd_" if imm < 0 else "fwd_") + ("taken" if taken else "not")] += 1
            if taken:
                npc = pc + imm
        else:
            raise ValueError(f"unknown opcode {w:08x}")
        if last_load_rd is not None and op in (0x33, 0x13, 0x03, 0x23, 0x63) and last_load_rd in (rs1, rs2 if op in (0x33, 0x23, 0x63) else rs1):
            stats["load_use"] += 1
        last_load_rd = rd if (op == 0x03 and rd) else None
        pc = npc
        if (pc >> 2) >= MEMW:
            break
    else:
        raise RuntimeError("reference model: dynamic limit hit (unbounded loop?)")
    return regs, mem, retire, dyn, stats


# ------------------------------------------------------------ programs
def hazard_program():
    """The pipeline hazard regression: RAW at distance 1, 2, 3, load-use,
    store with forwarded base and data, write to x0, taken and not-taken
    branches, a backward loop, and a load feeding a branch."""
    p = [
        addi(1, 0, 5),            # x1 = 5
        addi(2, 1, 3),            # x2 = 8       RAW distance 1 (EX/MEM forward)
        add(3, 1, 2),             # x3 = 13      RAW distance 1 on x2, distance 2 on x1
        sub(4, 3, 1),             # x4 = 8       RAW distance 1 on x3, distance 3 on x1
        addi(5, 0, 64),           # x5 = 64      base
        sw(3, 5, 0),              # MEM[16] = 13 forwarded base (x5, distance 1) and data
        lw(6, 5, 0),              # x6 = 13
        addi(7, 6, 1),            # x7 = 14      LOAD-USE, needs a stall
        and_(8, 7, 3),            # x8 = 12
        or_(9, 8, 1),             # x9 = 13
        addi(0, 1, 9),            # x0 write, discarded
        beq(1, 1, 8),             # taken, skips the next instruction
        addi(10, 0, 99),          # must NOT execute
        addi(11, 0, 7),           # x11 = 7
        beq(1, 2, 8),             # not taken (5 != 8)
        addi(12, 0, 1),           # x12 = 1
        lw(13, 5, 0),             # x13 = 13
        beq(13, 3, 8),            # LOAD then BRANCH on it: taken (13 == 13)
        addi(14, 0, 55),          # must NOT execute
        addi(15, 0, 3),           # x15 = 3      loop counter
        # loop: x16 += x1 ; x15 -= 1 ; exit when x15 == 0
        add(16, 16, 1),           # L: x16 += 5
        addi(15, 15, -1),
        beq(15, 0, 8),            # exit when counter hits 0
        beq(0, 0, -12),           # backward, predicted taken
        beq(15, 1, -16),          # backward NOT taken (0 != 5): predictor guesses wrong, redirect to pc+4
        sw(16, 5, 4),             # MEM[17] = 15
        lw(17, 5, 4),             # x17 = 15
        sw(17, 5, 8),             # store of a just-loaded value (load-use into store data)
        add(18, 17, 16),          # x18 = 30
        HALT,
    ]
    return p


def random_program(rng):
    """Random program from the 8 instructions. Termination is guaranteed:
    forward branches only, plus counted backward loops."""
    BASE = 20                          # memory base register, written once
    GP   = list(range(1, 16))          # general registers
    LOOPR = [16, 17, 18, 19]           # loop counters
    base_addr = rng.choice([0, 32, 64, 96, 128])
    prog = [addi(BASE, 0, base_addr)]

    def rr():  return rng.choice(GP)
    def alu(rd=None):
        rd = rd if rd is not None else rr()
        k = rng.random()
        if k < 0.55: return rng.choice([add, sub, and_, or_])(rd, rr(), rr())
        if k < 0.80: return addi(rd, rr(), rng.randint(-2048, 2047))
        if k < 0.90: return lw(rd, BASE, 4 * rng.randint(0, 31))
        return sw(rr(), BASE, 4 * rng.randint(0, 31))

    while len(prog) < 54:
        k = rng.random()
        if k < 0.50:
            prog.append(alu())
        elif k < 0.62:                                  # load then immediate use
            rd = rr()
            prog.append(lw(rd, BASE, 4 * rng.randint(0, 31)))
            prog.append(rng.choice([add, sub, and_, or_])(rr(), rd, rr()))
        elif k < 0.70:                                  # dependent chain
            a, b, c = rr(), rr(), rr()
            prog.append(addi(a, 0, rng.randint(-100, 100)))
            prog.append(add(b, a, a))
            prog.append(sub(c, b, a))
        elif k < 0.85:                                  # forward branch
            skip = rng.randint(1, 3)
            if rng.random() < 0.5:
                r = rr(); prog.append(beq(r, r, 4 * (skip + 1)))
            else:
                prog.append(beq(rr(), rr(), 4 * (skip + 1)))
            for _ in range(skip): prog.append(alu())
        elif k < 0.88:                                  # write to x0
            prog.append(addi(0, rr(), 1))
        elif k < 0.94:                                  # conditional backward branch
            # a counts up from v, b = v + k. The backward beq is taken exactly
            # when a reaches b (k == 1: taken once) and falls through otherwise:
            # a backward branch the static predictor guesses wrong.
            a, b = rng.sample(LOOPR, 2)
            v = rng.randint(-50, 50)
            prog.append(addi(a, 0, v))
            prog.append(addi(b, 0, v + rng.choice([0, 1, 1, 2])))
            l_idx = len(prog)
            prog.extend(alu() for _ in range(rng.randint(1, 2)))
            prog.append(addi(a, a, 1))
            j_idx = len(prog)
            prog.append(beq(a, b, 4 * (l_idx - j_idx)))
        else:                                           # counted backward loop
            cnt = rng.choice(LOOPR)
            n = rng.randint(1, 4)
            body = [alu(rd=rr()) for _ in range(rng.randint(1, 3))]
            prog.append(addi(cnt, 0, n))
            l_idx = len(prog)
            prog.extend(body)
            prog.append(addi(cnt, cnt, -1))
            prog.append(beq(cnt, 0, 8))                 # exit
            j_idx = len(prog)
            prog.append(beq(0, 0, 4 * (l_idx - j_idx))) # back to L
    prog.append(HALT)
    assert len(prog) <= 63
    return prog


def write_program(d, prog, name):
    os.makedirs(d, exist_ok=True)
    regs, mem, retire, dyn, stats = run_model(prog)
    with open(os.path.join(d, "coverage.txt"), "w") as f:
        for k, v in stats.items(): f.write(f"{k} {v}\n")
    with open(os.path.join(d, "prog.hex"), "w") as f:
        for w in prog: f.write(f"{w:08x}\n")
    with open(os.path.join(d, "asm.txt"), "w") as f:
        for i, w in enumerate(prog): f.write(f"{4*i:04x}: {w:08x}  {disasm(w)}\n")
    with open(os.path.join(d, "expected.txt"), "w") as f:
        for i in range(1, 32): f.write(f"x{i} {regs[i]:08x}\n")
        for i in range(MEMW): f.write(f"m{i} {mem[i]:08x}\n")
        f.write(f"n_reg {sum(1 for r in retire if r.startswith('x'))}\n")
        f.write(f"n_mem {sum(1 for r in retire if r.startswith('MEM'))}\n")
    with open(os.path.join(d, "retire_exp.log"), "w") as f:
        for r in retire: f.write(r + "\n")
    with open(os.path.join(d, "cycles"), "w") as f:
        f.write(f"{dyn * 6 + 100}\n")
    return dyn


def cmd_gen(out, n, seed):
    rng = random.Random(seed)
    dyn = write_program(os.path.join(out, "hazard"), hazard_program(), "hazard")
    print(f"hazard: {dyn} dynamic instructions")
    for i in range(n):
        d = os.path.join(out, f"rand{i:03d}")
        dyn = write_program(d, random_program(rng), f"rand{i:03d}")
    print(f"generated {n} random programs, seed {seed}")


def cmd_cov(out):
    """Dynamic branch / load-use coverage over every program in <out>."""
    keys = ["fwd_taken", "fwd_not", "bwd_taken", "bwd_not", "load_use"]
    tot = {k: 0 for k in keys}
    progs_with = {k: 0 for k in keys}
    n = 0
    for d in sorted(os.listdir(out)):
        p = os.path.join(out, d, "coverage.txt")
        if not os.path.exists(p): continue
        n += 1
        c = dict((l.split()[0], int(l.split()[1])) for l in open(p) if l.strip())
        for k in keys:
            tot[k] += c.get(k, 0)
            if c.get(k, 0): progs_with[k] += 1
    print(f"{n} programs")
    print(f"{'class':<12}{'dynamic events':>16}{'programs with >=1':>20}")
    for k in keys:
        print(f"{k:<12}{tot[k]:>16}{progs_with[k]:>20}")


def cmd_check(exp_state, got_state, exp_log, got_log):
    def load(p):
        return dict(l.split() for l in open(p) if l.strip())
    e, g = load(exp_state), load(got_state)
    bad = [k for k in e if e[k] != g.get(k)]
    el = [l.strip() for l in open(exp_log) if l.strip()]
    gl = [l.strip() for l in open(got_log) if l.strip()]
    ok = not bad and el == gl
    if bad:
        for k in bad[:8]: print(f"  MISMATCH {k}: expected {e[k]} got {g.get(k)}")
    if el != gl:
        n = next((i for i, (a, b) in enumerate(zip(el, gl)) if a != b), min(len(el), len(gl)))
        print(f"  RETIRE MISMATCH at event {n}: expected {el[n] if n < len(el) else 'END'!r} got {gl[n] if n < len(gl) else 'END'!r} (exp {len(el)} events, got {len(gl)})")
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "gen":
        cmd_gen(a[1], int(a[2]), int(a[3]))
    elif a and a[0] == "check":
        sys.exit(cmd_check(*a[1:5]))
    elif a and a[0] == "cov":
        cmd_cov(a[1])
    else:
        print(__doc__); sys.exit(2)


# AXI Protocol Verification using SystemVerilog & UVM

> *"The best way to understand a protocol is to break it — and then verify it doesn't break."*

---

## Table of Contents

1. [What is AXI?](#what-is-axi)
2. [Why I Chose This Project](#why-i-chose-this-project)
3. [What I Studied Before Starting](#what-i-studied-before-starting)
4. [Testbench Architecture](#testbench-architecture)
5. [Building the Transaction Class](#building-the-transaction-class)
6. [Building the UVM Components](#building-the-uvm-components)
7. [Driver & Responder — The Real Challenge](#driver--responder--the-real-challenge)
8. [Scoreboard — Self Checking Testbench](#scoreboard--self-checking-testbench)
9. [Coverage & Corner Cases](#coverage--corner-cases)
10. [Assertions](#assertions)
11. [Bugs I Found & What I Learned](#bugs-i-found--what-i-learned)
12. [Sequences Written](#sequences-written)
13. [Simulation Results](#simulation-results)
14. [What This Project Has Right Now](#what-this-project-has-right-now)
15. [What Comes Next](#what-comes-next)
16. [File & Folder Structure](#file--folder-structure)
17. [Tools Used](#tools-used)
18. [How to Run](#how-to-run)

---

## What is AXI?

Imagine a busy city with many buildings — a CPU, a DMA controller, a memory block, and several peripherals — all trying to talk to each other at the same time. Without a proper road system, it would be chaos.

**AXI (Advanced eXtensible Interface)** is that road system. It is a high-speed communication bridge inside a System-on-Chip (SoC) that allows different blocks to exchange data efficiently and simultaneously.

What makes AXI powerful:
- It supports **parallel read and write operations** at the same time — you don't have to wait for a read to finish before starting a write
- It supports **burst transfers** — instead of sending one byte at a time, you send a whole block of data in one shot
- It supports **pipelining** — the next transaction can begin before the previous one completes its response
- It has **five independent channels**: Write Address (AW), Write Data (W), Write Response (B), Read Address (AR), and Read Data (R)

Each channel uses a simple **valid/ready handshake** — the sender asserts valid, the receiver asserts ready, and the transfer happens on the clock edge when both are high.

```
Master                          Slave
  |--- AWVALID ----------------->|
  |<-- AWREADY ------------------|   ← Address accepted
  |--- WVALID + WDATA ---------->|
  |<-- WREADY -------------------|   ← Data accepted
  |<-- BVALID + BRESP -----------|
  |--- BREADY ------------------>|   ← Response acknowledged
```

---

## Why I Chose This Project

After completing my **Asynchronous FIFO verification project**, I started wondering — what comes after individual blocks? How do these blocks actually talk to each other inside a real chip?

That curiosity led me to AXI.

AXI is the backbone interconnect of almost every modern SoC — Qualcomm's Snapdragon, ARM's Cortex systems, Xilinx FPGAs — they all use AXI to connect CPUs, DMA engines, and memory subsystems. I wanted to understand:

- How transactions actually flow through an interconnect
- How a master and slave coordinate without colliding
- How burst transfers work internally — address calculation, wrap boundaries, narrow transfers
- How to build a complete self-checking verification environment from scratch

I decided to start with a **single master – single slave** architecture, build a rock-solid understanding of the fundamentals, and then grow from there. This project is that journey.

---

## What I Studied Before Starting

Before writing a single line of code, I sat down with the **ARM AXI Protocol Specification** and worked through the concepts systematically.

**Phase 1 — Signal Level Understanding**

I first mapped out every signal across all five channels — what each signal means, who drives it (master or slave), and how the handshake works. I started with the simplest question: *what happens in a single write transaction?*

**Phase 2 — Burst Mechanics**

This is where it got deep. I studied and solved problems around:

| Concept | What I Had to Understand |
|---|---|
| `BURST_LEN` | Number of beats = burst_len + 1 |
| `BURST_SIZE` | Bytes per beat = 2^burst_size |
| `BURST_TYPE` | FIXED (same addr), INCR (incrementing), WRAP (wraps at boundary) |
| Write Strobes | Which bytes in a data beat are actually valid |
| Address Calculation | How next_addr is computed for INCR and WRAP |
| Aligned vs Unaligned | What it means for an address to be aligned to burst_size |
| Narrow Transfers | When burst_size < data bus width — only some byte lanes active |
| 4KB Boundary Rule | An INCR burst must not cross a 4KB address boundary |
| WRAP Constraint | burst_len must be 1, 3, 7, or 15 — addr must be size-aligned |

---

## Testbench Architecture

After studying the spec, I designed the testbench architecture before writing any code. Every component has exactly one responsibility.

```
┌──────────────────────────────────────────────────────────────────┐
│                           top.sv                                  │
│  ┌─────────────┐        ┌───────────────────────────────────┐    │
│  │  Clock Gen  │        │        axi_intr (Interface)       │    │
│  │  Reset Gen  │───────▶│  driver_cb / responder_cb /       │    │
│  │  mem_assert │        │         monitor_cb                │    │
│  └─────────────┘        └─────────────┬──────────────────┬──┘    │
└────────────────────────────────────── │ ──────────────── │ ──────┘
                                        │                  │
        ┌───────────────────────────────▼──────────────────▼─────────────┐
        │                          axi_test                               │
        │  ┌──────────────────────────────────────────────────────────┐  │
        │  │                       axi_env                            │  │
        │  │                                                          │  │
        │  │  ┌───────────────────────────────────────────────────┐  │  │
        │  │  │              axi_magent (Master Agent)            │  │  │
        │  │  │  ┌─────────────┐    ┌──────────────────────────┐  │  │  │
        │  │  │  │axi_sequencer│───▶│       axi_dri            │  │  │  │
        │  │  │  │    (sqr)    │    │  (Pipelined Driver)      │──┼──┼──┼──▶ AXI Interface
        │  │  │  └─────────────┘    └──────────────────────────┘  │  │  │
        │  │  │  ┌──────────────┐   ┌──────────────────────────┐  │  │  │
        │  │  │  │  mast_mon    │──▶│     axi_coverage         │  │  │  │
        │  │  │  │  (Monitor)   │   │    (Subscriber)          │  │  │  │
        │  │  │  └──────┬───────┘   └──────────────────────────┘  │  │  │
        │  │  └─────────┼─────────────────────────────────────────┘  │  │
        │  │            │ analysis port                               │  │
        │  │            ▼                                             │  │
        │  │  ┌─────────────────────┐                                │  │
        │  │  │   axi_scoreboard    │ ← compares write vs read data  │  │
        │  │  └─────────────────────┘                                │  │
        │  │                                                          │  │
        │  │  ┌───────────────────────────────────────────────────┐  │  │
        │  │  │              axi_sagent (Slave Agent)             │  │  │
        │  │  │  ┌────────────────────────────────────────────┐   │  │  │
        │  │  │  │           axi_res (Responder)              │───┼──┼──┼──▶ AXI Interface
        │  │  │  │  byte mem[int] — AW/W/B/AR/R channels      │   │  │  │
        │  │  │  └────────────────────────────────────────────┘   │  │  │
        │  │  └───────────────────────────────────────────────────┘  │  │
        │  └──────────────────────────────────────────────────────────┘  │
        └────────────────────────────────────────────────────────────────┘

Data Flow:
Sequences ──▶ Sequencer ──▶ Driver ──▶ [Interface] ──▶ Responder
                                 ▼
                            Monitor (observes)
                               ▼          ▼
                         Scoreboard    Coverage
```

**Key Design Decisions:**
- Master agent has full UVM components: sequencer, driver, monitor, coverage
- Slave agent has only a responder — intentionally minimal
- Monitor analysis port fans out to both scoreboard and coverage subscriber
- Interface has three separate clocking blocks — `driver_cb`, `responder_cb`, `monitor_cb`
- Assertions instantiated in `top.sv` directly on interface signals

---

## Building the Transaction Class

The `axi_tx` class is the heart of everything. Every sequence, driver, monitor, and scoreboard works with this object.

**Fields defined:**

```systemverilog
rand bit            wr_rd;        // 1=Write, 0=Read
rand bit [3:0]      tx_id;        // Transaction ID
rand bit [31:0]     addr;         // Start address
rand bit [31:0]     dataq[$];     // Data queue — one entry per beat
rand bit [3:0]      burst_len;    // Number of beats - 1
rand bit [2:0]      burst_size;   // Bytes per beat = 2^burst_size
rand burst_type_id  burst_type;   // FIXED / INCR / WRAP
rand bit [1:0]      respq[$];     // Response codes queue
rand bit [3:0]      strbq[$];     // Write strobe queue
```

**Final constraint structure after debugging:**

```systemverilog
// Solve order — type and size before addr — prevents solver conflicts
constraint solve_order {
  solve burst_type before burst_size;
  solve burst_type before burst_len;
  solve burst_size before addr;
  solve burst_len  before addr;
}

// WRAP rules — strict per AXI spec
constraint wrap_con {
  if (burst_type == WRAP) {
    burst_len  inside {1, 3, 7, 15};
    burst_size inside {0, 1, 2};
    addr % (2**burst_size) == 0;
    (addr % ((2**burst_size) * (burst_len + 1))) != 0;
    addr != 0;
  }
}

// 4KB boundary — INCR only
constraint fourk {
  if (burst_type == INCR)
    (2**burst_size) * (burst_len + 1) <= 256;
}
```

---

## Building the UVM Components

### Sequencer

```systemverilog
// A typedef is enough — no custom methods needed
typedef uvm_sequencer#(axi_tx) axi_sequencer;
```

### Interface Clocking Blocks

```
driver_cb    → default input #0 output #0  (zero-skew BFM control)
responder_cb → default input #0 output #0  (slave responds synchronously)
monitor_cb   → default input #1            (samples 1ns before clock edge)
```

The monitor uses `input #1` to avoid sampling mid-transition glitches — a critical fix discovered during debugging.

### Master Agent

```
axi_magent
├── axi_sequencer  (sqr)
├── axi_dri        (dri)  → drives interface via driver_cb
├── mast_mon       (mon)  → observes via monitor_cb
└── axi_coverage   (cov)  → receives from mon via analysis port
```

### Slave Agent

Intentionally minimal — responder only. Scoreboard lives in env, not in the slave agent.

---

## Driver & Responder — The Real Challenge

### Driver — Pipelined Design

AXI allows write address, data, and response phases to be pipelined. The driver uses semaphores per channel and `fork/join_none` to model this:

```systemverilog
semaphore wr_a, wr_d, wr_r;  // write channel guards
semaphore rd_a, rd_d;        // read channel guards

task run();
  wait(vif.resetn === 1'b1);
  forever begin
    seq_item_port.get_next_item(req);
    $cast(ux, req.clone());
    fork
      drive_tx(ux);     // non-blocking — true pipelining
    join_none
    @(aw_done);         // wait only for AW phase completion
    seq_item_port.item_done();
  end
endtask
```

### Responder — Byte Lane Aware Memory Model

The responder has four parallel tasks running via `fork/join_none`:

```
handle_write_addr()  → captures AW channel info into aw_queue struct
handle_write_data()  → pops from aw_queue, writes to byte mem[]
handle_write_resp()  → sends BRESP after WLAST
handle_read()        → reads from mem[], sends R beats with RLAST
```

Byte lane calculation for correct unaligned transfer support:

```systemverilog
// Write side
byte_lane = (awaddr_t + k) % (`data_width/8);
mem[awaddr_t + k] = vif.responder_cb.wdata[(byte_lane*8)+:8];

// Read side
byte_lane = (araddr_t + j) % (`data_width/8);
vif.responder_cb.rdata[(byte_lane*8)+:8] <= mem[araddr_t + j];
```

WRAP address calculation — explicit boundary computation:

```systemverilog
int burst_len_bytes = (2**awsize_t) * (awlen_t + 1);
bit [31:0] wrap_lower = (awaddr_t / burst_len_bytes) * burst_len_bytes;
bit [31:0] wrap_upper = wrap_lower + burst_len_bytes;
awaddr_t += (2**awsize_t);
if (awaddr_t == wrap_upper) awaddr_t = wrap_lower;
```

---

## Scoreboard — Self Checking Testbench

The scoreboard receives completed transactions from the monitor via `uvm_analysis_imp`. It uses a write key FIFO indexed by `tx_id` to correctly match writes to reads even when IDs repeat.

**Write transaction** — stores data and burst info:
```
wr_seq_num++ → wr_data_mem[seq_num] = entry
              wr_key_fifo[tx_id].push_back(seq_num)
```

**Read transaction** — looks up and compares:
```
rd_key = wr_key_fifo[tx_id].pop_front()
expected = wr_data_mem[rd_key]

FIXED burst → all read beats must equal last written beat
INCR/WRAP   → beat by beat comparison
```

**Final report format:**
```
╔══════════════════════════════════════════════════════╗
║           AXI SCOREBOARD FINAL REPORT                ║
╠══════════════════════════════════════════════════════╣
║  Total Writes            : 50                        ║
║  Total Reads             : 50                        ║
║  Total Beats Verified    : 432                       ║
╠══════════════════════════════════════════════════════╣
║  PASS                    : 50                        ║
║  FAIL                    : 0                         ║
╠══════════════════════════════════════════════════════╣
║  FIXED   PASS/FAIL : 6  / 0  | Beats : 54            ║
║  INCR    PASS/FAIL : 38 / 0  | Beats : 342           ║
║  WRAP    PASS/FAIL : 6  / 0  | Beats : 96            ║
╚══════════════════════════════════════════════════════╝
TEST PASSED — 50/50 transactions | 432/432 beats verified
```

> See full transaction log → `results/logs/all_burst.log`

---

## Coverage & Corner Cases

Coverage implemented as `uvm_subscriber` in `axi_cov.sv`.

### Coverpoints

| Coverpoint | What It Checks |
|---|---|
| `WR_RD_CP` | Both write and read transactions exercised |
| `ADDR` | Zero, low, mid, high, and max address bins |
| `ADDR_ALIGNMENT_CHECK` | Aligned and unaligned address accesses |
| `BURST_TYPE` | FIXED, INCR, WRAP exercised — RSVD marked illegal |
| `BURST_LEN` | Min (0–3), mid (4–7), max (8–15) lengths |
| `BURST_SIZE` | All 8 burst sizes |
| `4K_BOUNDARY_CHECK` | Tracks within-4K vs boundary-crossing bursts |

### Cross Coverage

| Cross | Purpose |
|---|---|
| `X_ADDR_WR_RD_CP` | Every address region for both read and write |
| `X_WRAP_TYPE_LEN` | WRAP only with legal lengths {1,3,7,15} |
| `X_WRAP_LEN_ALIGNMENT` | WRAP alignment check — illegal unaligned WRAP flagged |
| `X_WRAP_ADDRESS_CHECK` | Confirms actual wrap events triggered |

### Coverage Result

> See coverage screenshot → `results/coverage/functional_coverage.png`

**Overall functional coverage: 97–98%**

The `4K_BOUNDARY_CHECK` coverpoint intentionally has one uncovered bin — `crosses_4k`. This bin is not hit because the driver constrains transactions to stay within 4KB boundaries. The responder does not yet handle split transactions across page boundaries. This is a **documented known gap** tracked for Phase 2.

### Corner Cases Targeted

- Zero address write/read — `addr = 32'h0000_0000`
- Max address write/read — `addr = 32'hFFFF_FFFF`
- WRAP at boundary edge — address lands exactly at `wrap_lower` after wrapping
- Narrow transfer — `burst_size = 0` (1 byte) on 32-bit bus
- FIXED burst — same address every beat
- Max burst length — `burst_len = 15` (16 beats) for INCR

---

## Assertions

17 SVA assertions implemented in `mem_assert` module — instantiated in `top.sv` directly on interface signals.

| # | Assertion | What It Checks |
|---|---|---|
| 1 | `RESET_CHECK` | All valid signals low during reset |
| 2 | `POST_RESET_KNOWN` | No X/Z on valid signals after reset |
| 3 | `AWVALID_STABLE` | AWVALID stays high until AWREADY |
| 4 | `AWADDR_STABLE` | AWADDR does not change while handshake pending |
| 5 | `WVALID_STABLE` | WVALID stays high until WREADY |
| 6 | `WDATA_STABLE` | WDATA does not change while handshake pending |
| 7 | `ARVALID_STABLE` | ARVALID stays high until ARREADY |
| 8 | `ARADDR_STABLE` | ARADDR does not change while handshake pending |
| 9 | `AWVALID_TIMEOUT` | AWREADY must arrive within 16 cycles |
| 10 | `ARVALID_TIMEOUT` | ARREADY must arrive within 16 cycles |
| 11 | `BVALID_STABLE` | BVALID stays high until BREADY |
| 12 | `RVALID_STABLE` | RVALID stays high until RREADY |
| 13 | `RDATA_KNOWN` | No X/Z on RDATA when RVALID high |
| 14 | `WDATA_KNOWN` | No X/Z on WDATA when WVALID high |
| 15 | `AWADDR_KNOWN` | No X/Z on AWADDR when AWVALID high |
| 16 | `ARADDR_KNOWN` | No X/Z on ARADDR when ARVALID high |
| 17 | `RLAST_CHECK` | RVALID must not drop without RLAST |
| 18 | `WLAST_CHECK` | WVALID must not drop without WLAST |

**Assertion Result: 17/17 passing — 0 failures**

Three assertions were identified as known limitations and removed:
- `ARVALID_TIMEOUT` — fires false failures when long bursts (16 beats) keep responder busy beyond 16-cycle window
- `BRESP_OKAY` — fires due to non-blocking assignment delta between bvalid and bresp — not a protocol violation
- `RRESP_OKAY` — same delta-cycle timing issue as BRESP

These are tracked as Phase 2 fixes — responder signal initialization sequence needs adjustment.

> See assertion report screenshot → `results/assertions/assertion_report.png`

---

## Bugs I Found & What I Learned

### Bug 1 — Premature Transaction Completion in Pipelined Driver

While implementing AXI pipelining using `fork/join_none`, I initially called `item_done()` immediately after spawning `drive_tx()`. This caused the sequencer to release the current transaction too early — the next transaction started before the address phase of the previous one completed, leading to overlapping timing issues.

I first tried inserting a random delay — this reduced failures but was not deterministic. After waveform analysis, I identified the real requirement: wait for the address phase to complete before notifying the sequencer. I introduced an event `aw_done` — the driver now waits for this event after the write address handshake and only then calls `item_done()`. This made pipelining deterministic and protocol-compliant.

**What I learned:** Arbitrary delays are never a robust fix. Event-based synchronization is the correct approach for phase-level coordination in a pipelined protocol.

---

### Bug 2 — Constraint Conflict Between `address_dist` and `wrap_con`

When I added the 4KB boundary constraint alongside the WRAP alignment constraint, the solver started generating unaligned WRAP addresses silently. The `dist` keyword in `address_dist` competed with the conditional `wrap_con` — when both applied to the same variable, QuestaSim's solver resolved the conflict by satisfying `dist` and relaxing `wrap_con`.

The fix was separating the constraints completely using `if/else` — WRAP transactions get their own address range, non-WRAP transactions get the distribution. Adding `solve burst_type before addr` ensured the solver always knew the burst type before constraining the address.

**What I learned:** `dist` and conditional constraints on the same variable cause silent solver failures in QuestaSim. Always use `if/else` style and `solve...before` to control solver ordering explicitly.

---

### Bug 3 — Coverage Cross Bin Inflation

When I created the cross `BURST_TYPE × ADDR_WRAP_OFFSET`, the coverage tool automatically created bins for all combinations — including meaningless ones like `BURST_TYPE != WRAP with any offset`. These uncovered bins reduced the overall coverage percentage without representing any real verification gap.

I used `ignore_bins` to explicitly exclude non-meaningful combinations, telling the tool these scenarios are outside the verification objective. This brought coverage to the correct level and made the report meaningful.

**What I learned:** Cross coverage bins must be manually pruned using `ignore_bins`. Uncovered bins that represent impossible or irrelevant scenarios should be excluded — not chased.

---

### Bug 4 — Scoreboard Mismatch Due to Byte Lane Logic

After integrating the scoreboard, I observed read-data mismatches even though the waveforms looked correct. I initially suspected sequence generation or constraint conflicts and spent time investigating those areas. The actual root cause was in the responder memory write logic:

```systemverilog
// Wrong — assumes aligned transfer always
mem[awaddr_t + k] = vif.responder_cb.wdata[(k*8)+:8];
```

For unaligned addresses, byte lanes shift — byte[0] of the data bus does not always correspond to address offset 0. The fix was computing the correct byte lane:

```systemverilog
byte_lane = (awaddr_t + k) % (`data_width/8);
mem[awaddr_t + k] = vif.responder_cb.wdata[(byte_lane*8)+:8];
```

The same fix was applied to the read side. Both sides now use identical byte lane logic — ensuring write and read are consistent.

**What I learned:** Waveform inspection alone does not catch data integrity bugs. The scoreboard exposed a bug that appeared correct at the protocol level but was functionally wrong at the memory model level. This is exactly why a scoreboard is essential.

---

### Bug 5 — FIXED Burst Scoreboard Logic

The scoreboard was comparing all read beats individually against all write beats. For FIXED burst, the same address is written every beat — only the last written value survives in memory. All read beats return that last value. Beat-by-beat comparison always failed for FIXED burst even when the behavior was correct.

Fix — added burst type check before comparison: FIXED burst compares all read beats against only the last written beat.

**What I learned:** Scoreboard comparison logic must respect the protocol semantics of each burst type — not just apply generic comparison.

---

### Bug 6 — Scoreboard Key Collision

With 50 transactions and `randc` resetting after 16 IDs, the same `tx_id` appeared multiple times. The scoreboard key `{tx_id, addr}` caused wrong write entries to be matched to wrong read transactions — producing beat count mismatches that appeared in pairs with swapped expected/got values.

Fix — replaced key-based lookup with a `wr_key_fifo` indexed by `tx_id`. Every write gets a unique global sequence number. The FIFO tracks order per ID — reads always pop the oldest matching write regardless of address or burst parameters.

**What I learned:** Associative array keys must be truly unique. When IDs recycle, order-based lookup (FIFO) is more reliable than value-based key matching.

---

## Sequences Written

| Sequence | Description |
|---|---|
| `axi_wr_rd` | Randomized write then read — same ID, addr, burst params |
| `axi_wrap` | WRAP burst — tests wrap boundary calculation |
| `axi_incr_burst` | INCR burst with burst_len ∈ {3,7,15} |
| `axi_fixed_burst` | FIXED burst — same address repeated every beat |
| `axi_narrow_transfer` | INCR with burst_size ∈ {0,1} — narrow byte lane transfers |

All sequences follow **write-first, read-back** pattern. Selected at runtime via plusarg:

```bash
+SEQ=all_burst    # Randomized all burst types
+SEQ=wrap         # WRAP burst only
+SEQ=incr         # INCR burst only
+SEQ=fixed        # FIXED burst only
+SEQ=narrow       # Narrow transfer only
```

---

## Simulation Results

| Result | Screenshot |
|---|---|
| Scoreboard Final Report | `results/scoreboard/scoreboard_report.png` |
| Full Transaction Log | `results/logs/all_burst.log` |
| Functional Coverage Report | `results/coverage/functional_coverage.png` |
| Assertion Report | `results/assertions/assertion_report.png` |
| Write Transaction Waveform | `results/waveforms/write_transaction.png` |
| Read Transaction Waveform | `results/waveforms/read_transaction.png` |
| Full Simulation Waveform | `results/waveforms/full_simulation.png` |

---

## What This Project Has Right Now

✅ Complete AXI interface — three clocking blocks (driver, responder, monitor)
✅ Transaction class — full constraints including WRAP, 4KB boundary, solve order
✅ Pipelined driver — semaphores, fork/join_none, event-based synchronization
✅ Byte-lane aware responder — correct WRAP/INCR/FIXED address calculation
✅ Master monitor — collects completed write and read transactions
✅ Self-checking scoreboard — beat-level comparison, FIXED burst logic, key FIFO
✅ Coverage collector — coverpoints, cross coverage, 4KB boundary tracking
✅ 17 SVA assertions — stability, timeout, known values, LAST signal checks
✅ 5 sequences — all burst types with write-first read-back pattern
✅ Plusarg-based test selection
✅ QuestaSim simulation scripts with coverage save

---

## What Comes Next

**Phase 2 — Scoreboard Hardening**
- Fix responder signal initialization for BRESP/RRESP assertions
- Add BRESP and RRESP assertions back after timing fix
- Add 4KB boundary split transaction support in responder

**Phase 3 — Outstanding Transactions**
- Allow truly interleaved outstanding transactions
- Out-of-order response by ID

**Phase 4 — Multiple Masters / Arbitration**
- 2-master, 1-slave topology
- AXI interconnect/arbiter model
- Arbitration verification

---

## File & Folder Structure

```
AXI_VER_UVM/
│
├── axi_common.sv          # Macros, defines, drive_count
├── axi_intr.sv            # Interface — driver_cb, responder_cb, monitor_cb
├── AXI_tx.sv              # Transaction class — fields, constraints
├── axi_seq.sv             # Sequencer typedef
├── axi_sequence.sv        # All 5 sequences
├── axi_dri.sv             # Pipelined master driver
├── axi_res.sv             # Slave responder — byte mem[]
├── mast_mon.sv            # Master monitor
├── axi_cov.sv             # Coverage subscriber
├── axi_scoreboard.sv      # Self-checking scoreboard
├── axi_assertion.sv       # 17 SVA assertions
├── axi_magent.sv          # Master agent
├── axi_sagent.sv          # Slave agent
├── axi_env.sv             # Environment
├── axi_test.sv            # Test classes
├── top.sv                 # Top module
├── axi_list.sv            # Compile order
│
├── results/
│   ├── scoreboard/
│   │   └── scoreboard_report.png
│   ├── coverage/
│   │   └── functional_coverage.png
│   ├── assertions/
│   │   └── assertion_report.png
│   ├── waveforms/
│   │   ├── write_transaction.png
│   │   ├── read_transaction.png
│   │   └── full_simulation.png
│   └── logs/
│       └── all_burst.log
│
├── axi_run.do             # Coverage simulation script
├── axi_assert.do          # Assertion simulation script
└── axi_uvm_run.do         # Basic run script
```

---

## Tools Used

| Tool | Version |
|---|---|
| Simulator | QuestaSim 10.7c |
| UVM | UVM 1.2 |
| Language | SystemVerilog IEEE 1800-2012 |
| Coverage Format | UCDB |

---

## How to Run

```bash
# Run all_burst with coverage
vsim -do axi_run.do

# Run with assertions
vsim -do axi_assert.do

# Run specific sequence
vlog +cover=bcst axi_list.sv +incdir+<uvm_src_path>
vsim -voptargs="+acc" -coverage top \
     -sv_lib <uvm_dpi_lib> \
     +SEQ=wrap
run -all
coverage save wrap.ucdb
```

---

*This project is actively under development. Each phase builds on the previous one toward a production-quality, fully self-checking AXI4 verification environment.*

---

Is this structure and content correct for you? Confirm and I will generate the final file.

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
8. [Timing Issues & The Self-Checking Testbench](#timing-issues--the-self-checking-testbench)
9. [Coverage & Corner Cases](#coverage--corner-cases)
10. [Sequences Written](#sequences-written)
11. [What This Project Has Right Now](#what-this-project-has-right-now)
12. [What Comes Next](#what-comes-next)
13. [File & Folder Structure](#file--folder-structure)

---

## What is AXI?

Imagine a busy city with many buildings — a CPU, a DMA controller, a memory block, and several peripherals — all trying to talk to each other at the same time. Without a proper road system, it would be chaos.

**AXI (Advanced eXtensible Interface)** is that road system. It is a high-speed communication bridge inside a System-on-Chip (SoC) that allows different blocks to exchange data efficiently and simultaneously.

What makes AXI powerful:
- It supports **parallel read and write operations** at the same time — you don't have to wait for a read to finish before starting a write
- It supports **burst transfers**, so instead of sending one byte at a time, you can send a whole block of data in one shot
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
- What happens when multiple devices try to access the bus simultaneously (arbitration)
- How burst transfers work internally — address calculation, wrap boundaries, narrow transfers

I decided to start with a **single master – single slave** architecture, build a rock-solid understanding of the fundamentals, and then grow from there. This project is that journey.

---

## What I Studied Before Starting

Before writing a single line of code, I sat down with the **ARM AXI Protocol Specification** and worked through the concepts systematically.

**Phase 1 — Signal Level Understanding**

I first mapped out every signal across all five channels — what each signal means, who drives it (master or slave), and how the handshake works. I didn't start with complex scenarios. I started with: *what happens in a single write transaction?*

**Phase 2 — Burst Mechanics (This took the most time)**

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
| WRAP Constraint | For WRAP: burst_len must be 1, 3, 7, or 15; addr must be size-aligned |

I also went through previous AXI verification projects on GitHub to understand how others approached driver and responder design. That gave me a baseline — and showed me what I wanted to do differently.

---

## Testbench Architecture

After studying the spec, I designed my testbench architecture before writing any code. The goal was clarity — every component should have exactly one responsibility.

```
┌─────────────────────────────────────────────────────────────────┐
│                          top.sv                                  │
│  ┌─────────────┐        ┌──────────────────────────────────┐    │
│  │  Clock Gen  │        │         axi_intr (Interface)     │    │
│  │  Reset Gen  │───────▶│  driver_cb / responder_cb /      │    │
│  └─────────────┘        │          monitor_cb              │    │
│                         └──────────────┬─────────────────┬─┘    │
└─────────────────────────────────────── │ ─────────────── │ ─────┘
                                         │                 │
          ┌──────────────────────────────▼─────────────────▼──────────────┐
          │                        axi_test                                │
          │  ┌─────────────────────────────────────────────────────────┐  │
          │  │                      axi_env                            │  │
          │  │                                                         │  │
          │  │   ┌──────────────────────────────────────────┐         │  │
          │  │   │            axi_magent (Master Agent)     │         │  │
          │  │   │                                          │         │  │
          │  │   │  ┌─────────────┐    ┌─────────────────┐ │         │  │
          │  │   │  │axi_sequencer│───▶│    axi_dri      │ │         │  │
          │  │   │  │    (sqr)    │    │   (Driver)      │─┼──▶ AXI  │  │
          │  │   │  └─────────────┘    └─────────────────┘ │  Interface│ │
          │  │   │                                          │         │  │
          │  │   │  ┌─────────────┐    ┌─────────────────┐ │         │  │
          │  │   │  │  mast_mon   │───▶│  axi_coverage   │ │         │  │
          │  │   │  │  (Monitor)  │    │  (Subscriber)   │ │         │  │
          │  │   │  └─────────────┘    └─────────────────┘ │         │  │
          │  │   └──────────────────────────────────────────┘         │  │
          │  │                                                         │  │
          │  │   ┌──────────────────────────────────────────┐         │  │
          │  │   │            axi_sagent (Slave Agent)      │         │  │
          │  │   │                                          │         │  │
          │  │   │  ┌─────────────────────────────────────┐ │         │  │
          │  │   │  │          axi_res (Responder)        │─┼──▶ AXI  │  │
          │  │   │  │    (handles AW, W, B, AR, R phases) │ │  Interface│ │
          │  │   │  └─────────────────────────────────────┘ │         │  │
          │  │   └──────────────────────────────────────────┘         │  │
          │  └─────────────────────────────────────────────────────────┘  │
          └────────────────────────────────────────────────────────────────┘

  Data Flow:
  Sequences ──▶ Sequencer ──▶ Driver ──▶ [Interface] ──▶ Responder
                                  ▼
                             Monitor (observes)
                                  ▼
                          Coverage Collector
```

**Key Design Decisions:**

- The **master agent** has full UVM components: sequencer, driver, monitor, and coverage
- The **slave agent** has only a **responder** — no scoreboard yet (planned for next phase)
- The **monitor** uses an **analysis port** that feeds directly into the **coverage subscriber**
- The **interface** has three separate clocking blocks — `driver_cb`, `responder_cb`, and `monitor_cb` — each with the right direction (input/output) and skew

---

## Building the Transaction Class

The `axi_tx` class (`AXI_tx.sv`) is the heart of everything. Every sequence, driver, and monitor works with this object.

**Fields I defined:**

```systemverilog
rand bit         wr_rd;           // 1=Write, 0=Read
rand bit [3:0]   tx_id;           // Transaction ID
rand bit [31:0]  addr;            // Start address
rand bit [31:0]  dataq[$];        // Data queue (one entry per beat)
rand bit [3:0]   burst_len;       // Number of beats - 1
rand bit [2:0]   burst_size;      // Bytes per beat = 2^burst_size
rand burst_type_id burst_type;    // FIXED / INCR / WRAP
rand bit [1:0]   respq[$];        // Response codes queue
rand bit [3:0]   strbq[$];        // Write strobe queue
```

**Constraints I built and why:**

```systemverilog
// Data queue size must match burst length for writes
constraint data_queue {
  (wr_rd==1) -> dataq.size() == burst_len+1;
  (wr_rd==0) -> dataq.size() == 0;
}

// WRAP burst has strict AXI rules
constraint wrap_con {
  (burst_type==WRAP) -> burst_len inside {1,3,7,15};     // AXI spec rule
  (burst_type==WRAP) -> addr % (2**burst_size) == 0;     // Must be aligned
  (burst_type==WRAP) -> (addr % ((2**burst_size)*(burst_len+1))) != 0;  // Not at boundary
  (burst_type==WRAP) -> addr != 0;
}

// Address distribution biased toward corner values
constraint address_dist {
  addr dist {
    32'h0000_0000                   := 100,   // Zero address
    [32'h0000_0001 : 32'h0000_FFFF] :/ 100,
    [32'h0001_0000 : 32'hFFFE_FFFF] :/ 50,
    [32'hFFFF_0000 : 32'hFFFF_FFFE] :/ 100,
    32'hFFFF_FFFF                   := 100    // Max address
  };
}
```

> **What I Learned:** Constraining queues (`dataq[$]`) is not the same as constraining a simple field. The `size()` function inside constraints is essential — without it, the randomizer doesn't know how many entries to generate.

---

## Building the UVM Components

Once the transaction was solid, I built the UVM hierarchy from the bottom up.

### Sequencer

I started with a full class definition, then realized it was unnecessary overhead:

```systemverilog
// Initial version (more code, same result)
class axi_sequencer extends uvm_sequencer#(axi_tx);
  `uvm_component_utils(axi_sequencer)
  `NEW_COMP
endclass

// Final version — a typedef does the same job cleanly
typedef uvm_sequencer#(axi_tx) axi_sequencer;
```

> **What I Learned:** A `typedef` sequencer is perfectly valid in UVM when you don't need custom methods. Simpler is better.

---

### Interface (`axi_intr.sv`)

The interface has three separate clocking blocks with careful direction control:

```
driver_cb    → default input #0 output #0  (zero-skew for BFM control)
responder_cb → default input #0 output #0  (slave responds synchronously)
monitor_cb   → default input #1            (sample 1ns before clock edge)
```

The monitor uses `input #1` (1ns setup skew) so it samples stable values — not mid-transition glitches. This was an important learning about **race conditions** in simulation.

---

### Master Agent (`axi_magent.sv`)

```
axi_magent
├── axi_sequencer  (sqr)
├── axi_dri        (dri)   → drives interface via driver_cb
├── mast_mon       (mon)   → observes via monitor_cb
└── axi_coverage   (cov)   → receives from mon via analysis port
```

The connect phase wires:
- `dri.seq_item_port` → `sqr.seq_item_export`
- `mon.ap_port` → `cov.analysis_export`

### Slave Agent (`axi_sagent.sv`)

The slave agent is intentionally minimal — it only creates the responder. No scoreboard yet. This is by design — I wanted to first prove the protocol drives and responds correctly before adding checking logic.

---

## Driver & Responder — The Real Challenge

This was the most educational part of the project.

### How I approached the Driver

The AXI write transaction has three independent phases — address (AW), data (W), and response (B). AXI allows these to be **pipelined** — you can send a new write address before the data phase of the previous transaction is even done.

To model this correctly, I used **semaphores** to protect each channel independently:

```systemverilog
semaphore wr_a;  // Guards write address channel
semaphore wr_d;  // Guards write data channel
semaphore wr_r;  // Guards write response channel
semaphore rd_a;  // Guards read address channel
semaphore rd_d;  // Guards read data channel
```

Each new transaction is **forked** — so multiple transactions can be in-flight simultaneously:

```systemverilog
task run();
  wait(vif.resetn === 1'b1);
  forever begin
    seq_item_port.get_next_item(req);
    $cast(ux, req.clone());
    fork
      drive_tx(ux);    // Forked — non-blocking
    join_none
    @(aw_done);        // Wait only until AW phase completes
    seq_item_port.item_done();
  end
endtask
```

> **Why `@(aw_done)` and not `join`?**
> If I waited for the full transaction to complete before calling `item_done()`, the sequencer would be blocked and couldn't generate the next transaction. By releasing it after the AW phase, I allow the sequencer to keep pumping transactions while data and response phases run in the background. This is **true AXI pipelining**.

### How I approached the Responder

The responder (`axi_res.sv`) acts as a simple AXI slave. It has an internal byte-addressable memory (`byte mem[int]`) and four parallel tasks running forever:

```
handle_write_addr()  → waits for AWVALID, captures address info, pushes to aw_queue
handle_write_data()  → pops from aw_queue, accepts W beats, writes to mem[]
handle_write_resp()  → sends BRESP once data is done
handle_read()        → accepts ARVALID, reads from mem[], sends R beats with RLAST
```

**Address calculation inside the responder for all burst types:**

```systemverilog
case (awburst_t)
  2'b00: awaddr_t = awaddr_t;                        // FIXED — same address every beat
  2'b01: awaddr_t += (2**awsize_t);                  // INCR — increment by size
  2'b10: begin                                        // WRAP — wrap at boundary
    int burst_len_bytes = (2**awsize_t) * (awlen_t + 1);
    bit [31:0] wrap_lower = (awaddr_t / burst_len_bytes) * burst_len_bytes;
    bit [31:0] wrap_upper = wrap_lower + burst_len_bytes;
    awaddr_t += (2**awsize_t);
    if (awaddr_t == wrap_upper) awaddr_t = wrap_lower;  // Wrap!
  end
endcase
```

> **What I Learned:** The WRAP address calculation is not just modulo — you have to compute `wrap_lower` and `wrap_upper` boundaries explicitly. Many people get this wrong by trying to use `%` directly on the incremented address.

---

## Timing Issues & The Self-Checking Testbench

### The Timing Problem I Hit

Early in development, my monitor was sampling signals at the **same clock edge** as the driver was driving them. This caused the monitor to sometimes catch mid-transition values — transactions were being logged with garbage data.

**Root cause:** The `driver_cb` and `monitor_cb` were both set to `#0` skew. The monitor needs to sample *after* the driver has settled.

**Fix:** Changed `monitor_cb` to `default input #1` — sample 1 nanosecond before the rising edge, which is after the previous cycle's outputs have stabilized.

```systemverilog
clocking monitor_cb @(posedge aclk);
  default input #1;    // ← This was the fix
  input awid, awaddr, awvalid, awready, ...;
endclocking
```

### Is This a Self-Checking Testbench?

Yes — partially. Here is what self-checking exists right now:

- The **monitor** collects every completed transaction off the wire
- The **coverage collector** receives these and samples the covergroup
- The **responder** uses a real memory model — write data goes in, read data comes back from the same addresses
- The **driver reads back** what the responder stored — if the data is wrong, the waveform shows it

What is **not yet** self-checking:
- There is no scoreboard that automatically compares expected vs actual data
- Pass/fail is currently verified by waveform inspection and coverage reports

> This is the **next development target** — adding a scoreboard that connects monitor output to expected data computed from the sequence, and auto-reports PASS/FAIL in the log.

---

## Coverage & Corner Cases

The coverage is implemented in `axi_cov.sv` as a `uvm_subscriber`. It receives completed transactions from the monitor via an analysis port.

### Coverpoints Implemented

| Coverpoint | What It Checks |
|---|---|
| `WR_RD_CP` | Both write and read transactions exercised |
| `ADDR` | Zero address, low, mid, high, and max address hit |
| `ADDR_ALIGNMENT_CHECK` | Aligned and unaligned address accesses |
| `BURST_TYPE` | FIXED, INCR, WRAP all exercised; RSVD illegal |
| `BURST_LEN` | Min (0–3), mid (4–7), max (8–15) lengths |
| `BURST_SIZE` | All 8 burst sizes (1B to 128B per beat) |

### Cross Coverage

| Cross | Purpose |
|---|---|
| `X_ADDR_WR_RD_CP` | Every address region covered for both read and write |
| `X_WRAP_TYPE_LEN` | WRAP burst only with legal lengths {1,3,7,15} |
| `X_WRAP_LEN_ALIGNMENT` | WRAP must be address-aligned; flags illegal unaligned WRAP |
| `X_WRAP_ADDRESS_CHECK` | Confirms actual WRAP events (addr offset ≠ 0) are triggered |

### Corner Cases Specifically Targeted

- **Zero address write/read** — `addr = 32'h0000_0000`
- **Max address write/read** — `addr = 32'hFFFF_FFFF`
- **WRAP at boundary edge** — address that lands exactly at `wrap_lower` after wrapping
- **Narrow transfer** — `burst_size = 0` (1 byte) on a 32-bit bus; only byte lane 0 active
- **FIXED burst** — same address hit on every beat (burst_len = 0 always)
- **Aligned vs unaligned INCR** — different byte lane patterns
- **Max burst length** — `burst_len = 15` (16 beats) for INCR

---

## Sequences Written

| Sequence | Description |
|---|---|
| `axi_wr_rd` | Randomized write followed by read to same address/id/burst params |
| `axi_wrap` | Fixed WRAP burst — addr=92, len=3, size=2 (tests wrap boundary calculation) |
| `axi_incr_burst` | INCR burst with burst_len ∈ {3,7,15} and burst_size=2 |
| `axi_fixed_burst` | FIXED burst with burst_len=0 (single address, repeated) |
| `axi_narrow_transfer` | INCR burst with burst_size ∈ {0,1} (narrow — 1 or 2 bytes per beat) |

All sequences follow a **write-first, read-back** pattern — write N transactions, store them in a queue, then read them back using the same ID, address, and burst parameters. This validates the full write→store→read→verify data path through the responder memory.

Sequences are selected at runtime via a plusarg:

```bash
+SEQ=all_burst    # Randomized write/read
+SEQ=wrap         # WRAP burst test
+SEQ=incr         # INCR burst test
+SEQ=fixed        # FIXED burst test
+SEQ=narrow       # Narrow transfer test
```

---

## What This Project Has Right Now

✅ Complete AXI interface with three clocking blocks (driver, responder, monitor)  
✅ Transaction class (`axi_tx`) with full constraints including WRAP rules  
✅ UVM sequencer (typedef), sequences for all burst types  
✅ Pipelined driver using semaphores and fork/join_none  
✅ Full responder with byte-addressable memory and correct WRAP/INCR/FIXED address calculation  
✅ Master monitor — collects completed write and read transactions off the wire  
✅ Coverage collector — coverpoints for addr, burst type, burst len, burst size, alignment + cross coverage  
✅ Plusarg-based test selection (`+SEQ=`)  
✅ Coverage save to `.ucdb` for Questa coverage reports  
✅ Simulation scripts (`.do` files) for QuestaSim  

---

## What Comes Next

These are the planned developments for the next phase of this project:

**Phase 2 — Scoreboard & Self-Checking**
- Add a scoreboard that receives from the monitor and compares write data vs read data automatically
- Auto-log PASS/FAIL per transaction in simulation log

**Phase 3 — Multiple Outstanding Transactions**
- Currently write and read are kept separate (reads wait for all writes to finish)
- Next: allow truly interleaved outstanding transactions with out-of-order response by ID

**Phase 4 — Assertions**
- Add SVA (SystemVerilog Assertions) for protocol-level checks:
  - No valid without ready held for more than N cycles
  - WLAST must assert on the last beat
  - BRESP must come after WLAST

**Phase 5 — Multiple Masters / Arbitration**
- Extend to a 2-master, 1-slave topology
- Add an AXI interconnect/arbiter model
- Verify correct arbitration behavior

---

## File & Folder Structure

```
AXI_VER_UVM/
│
├── axi_common.sv        # Macros and defines (addr_width, data_width, NO_OF_TX, NEW_COMP, NEW_OBJ)
├── axi_intr.sv          # AXI Interface — driver_cb, responder_cb, monitor_cb clocking blocks
│
├── AXI_tx.sv            # Transaction class — fields, constraints (WRAP, strobe, address dist)
│
├── axi_seq.sv           # Sequencer — typedef uvm_sequencer#(axi_tx)
├── axi_sequence.sv      # All sequences: axi_wr_rd, axi_wrap, axi_incr_burst,
│                        #                axi_fixed_burst, axi_narrow_transfer
│
├── axi_dri.sv           # Master driver — pipelined with semaphores, fork/join_none
├── axi_res.sv           # Slave responder — byte mem[], handles AW/W/B/AR/R channels
├── mast_mon.sv          # Master monitor — collects completed transactions via analysis port
├── axi_cov.sv           # Coverage collector — uvm_subscriber, covergroup with cross coverage
│
├── axi_magent.sv        # Master agent — sqr + dri + mon + cov
├── axi_sagent.sv        # Slave agent  — res only
├── axi_env.sv           # Environment  — magent + sagent
├── axi_test.sv          # Tests: axi_test (base), test1 (plusarg-driven sequence selector)
├── top.sv               # Top module — clock/reset gen, interface instantiation, run_test
│
├── axi_list.sv          # Include file — compilation order for all files
│
├── axi_run.do           # QuestaSim script — compile with coverage, simulate, save .ucdb
├── axi_uvm_run.do       # QuestaSim script — basic run without coverage
└── all_burst.do         # QuestaSim script — all_burst sequence with coverage save
```

---

## Tools Used

| Tool | Version |
|---|---|
| Simulator | QuestaSim 10.7c |
| UVM | UVM 1.2 |
| Language | SystemVerilog (IEEE 1800-2012) |
| Coverage Format | UCDB (Unified Coverage Database) |

---

## How to Run

```bash
# Run all_burst sequence with coverage
vsim -do axi_run.do

# Run specific sequence
vlog +cover=bcst axi_list.sv +incdir+<path_to_uvm_src>
vsim -voptargs="+acc" -coverage top -sv_lib <uvm_dpi_lib> +SEQ=wrap
run -all
coverage save wrap.ucdb
```

---

*This project is actively under development. Each phase builds on the previous one with the goal of building a production-quality, fully self-checking AXI4 verification environment.*

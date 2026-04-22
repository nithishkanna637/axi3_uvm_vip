`include "uvm_pkg.sv"
import uvm_pkg::*;

// 1️⃣ Common + macros
`include "axi_common.sv"

// 2️⃣ Interface (VERY IMPORTANT → early)
`include "axi_intr.sv"

// 3️⃣ Transaction
`include "AXI_tx.sv"

// 4️⃣ Sequencer + sequence
`include "axi_seq.sv"
`include "axi_sequence.sv"

// 5️⃣ Driver & Responder (they use interface + tx)
`include "axi_dri.sv"
`include "axi_res.sv"

`include "mast_mon.sv"
`include "axi_cov.sv"
// 6️⃣ Agents
`include "axi_magent.sv"
`include "axi_sagent.sv"

// 7️⃣ Environment
`include "axi_env.sv"

// 8️⃣ Test
`include "axi_test.sv"

// 9️⃣ Top (LAST always)
`include "top.sv"

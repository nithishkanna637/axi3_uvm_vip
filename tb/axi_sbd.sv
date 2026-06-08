class axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_scoreboard)

  // --------------------------------------------------------
  // Analysis import
  // --------------------------------------------------------
  uvm_analysis_imp #(axi_tx, axi_scoreboard) sb_imp;

  // --------------------------------------------------------
  // Internal write storage
  // Struct holds everything needed for comparison
  // --------------------------------------------------------
  typedef struct {
    bit [31:0]      dataq[$];
    burst_type_id   burst_type;
    bit [2:0]       burst_size;
    bit [3:0]       burst_len;
  } wr_entry_t;

  // Key = {tx_id[3:0], burst_size[2:0], burst_len[3:0], addr[31:0]}
  // packed into longint to make it unique even when tx_id repeats
  wr_entry_t wr_data_mem [longint][$];

  // --------------------------------------------------------
  // Counters
  // --------------------------------------------------------
  int wr_count        = 0;
  int rd_count        = 0;
  int pass_count      = 0;
  int fail_count      = 0;
  int fixed_pass      = 0;
  int fixed_fail      = 0;
  int incr_pass       = 0;
  int incr_fail       = 0;
  int wrap_pass       = 0;
  int wrap_fail       = 0;
  int resp_err_count  = 0;
  int no_match_count  = 0;

  // --------------------------------------------------------
  // Constructor
  // --------------------------------------------------------
  function new(string name = "axi_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  // --------------------------------------------------------
  // Build phase
  // --------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sb_imp = new("sb_imp", this);
  endfunction

  // --------------------------------------------------------
  // Key generation
  // --------------------------------------------------------
  function longint make_key(bit [3:0] tx_id,
                            bit [31:0] addr,
                            bit [2:0] burst_size,
                            bit [3:0] burst_len);
    return longint'({tx_id, burst_size, burst_len, addr});
  endfunction

  // --------------------------------------------------------
  // write() — called for every completed transaction
  // --------------------------------------------------------
  function void write(axi_tx tx);
    longint key = make_key(tx.tx_id, tx.addr,
                           tx.burst_size, tx.burst_len);

    // ======================================================
    // WRITE TRANSACTION
    // ======================================================
    if (tx.wr_rd == 1'b1) begin
      wr_entry_t entry;
      wr_count++;

      entry.burst_type = tx.burst_type;
      entry.burst_size = tx.burst_size;
      entry.burst_len  = tx.burst_len;

      foreach (tx.dataq[i])
        entry.dataq.push_back(tx.dataq[i]);

      wr_data_mem[key].push_back(entry);

      `uvm_info("SB_WRITE",
        $sformatf("[WRITE #%0d] ID=%0h ADDR=%0h TYPE=%-5s LEN=%0d SIZE=%0d | %0d beats stored",
          wr_count, tx.tx_id, tx.addr, tx.burst_type.name(),
          tx.burst_len, tx.burst_size, tx.dataq.size()),
        UVM_MEDIUM)

    // ======================================================
    // READ TRANSACTION
    // ======================================================
    end else begin
      wr_entry_t expected_entry;
      bit [31:0] expected_data[$];
      bit        all_match = 1;
      rd_count++;

      // ---- Check matching write exists ----
      if (!wr_data_mem.exists(key) || wr_data_mem[key].size() == 0) begin
        `uvm_error("SB_NO_MATCH",
          $sformatf("[READ  #%0d] ID=%0h ADDR=%0h TYPE=%-5s — No matching WRITE found!",
            rd_count, tx.tx_id, tx.addr, tx.burst_type.name()))
        fail_count++;
        no_match_count++;
        return;
      end

      // ---- Pop oldest matching write entry ----
      expected_entry = wr_data_mem[key].pop_front();
      if (wr_data_mem[key].size() == 0)
        wr_data_mem.delete(key);

      expected_data  = expected_entry.dataq;

      // ---- Check beat count ----
      if (tx.dataq.size() != expected_data.size()) begin
        `uvm_error("SB_BEAT_COUNT",
          $sformatf("[READ  #%0d] ID=%0h ADDR=%0h — Beat count mismatch! Expected=%0d Got=%0d",
            rd_count, tx.tx_id, tx.addr,
            expected_data.size(), tx.dataq.size()))
        all_match = 0;
      end else begin

        // ================================================
        // FIXED burst — only last written beat survives
        // in memory — all read beats must equal last beat
        // ================================================
        if (expected_entry.burst_type == FIXED) begin
          bit [31:0] last_beat;
          last_beat = expected_data[expected_data.size()-1];
          foreach (tx.dataq[i]) begin
            if (tx.dataq[i] !== last_beat) begin
              `uvm_error("SB_MISMATCH",
                $sformatf("[READ  #%0d][FIXED] ID=%0h ADDR=%0h Beat[%0d] MISMATCH! Expected=%0h Got=%0h",
                  rd_count, tx.tx_id, tx.addr, i, last_beat, tx.dataq[i]))
              all_match = 0;
            end
          end

        // ================================================
        // INCR / WRAP — beat by beat comparison
        // ================================================
        end else begin
          foreach (tx.dataq[i]) begin
            if (tx.dataq[i] !== expected_data[i]) begin
              `uvm_error("SB_MISMATCH",
                $sformatf("[READ  #%0d][%-4s] ID=%0h ADDR=%0h Beat[%0d] MISMATCH! Expected=%0h Got=%0h",
                  rd_count, expected_entry.burst_type.name(),
                  tx.tx_id, tx.addr, i, expected_data[i], tx.dataq[i]))
              all_match = 0;
            end
          end
        end

      end // beat count check

      // ---- RRESP check — every beat must be OKAY ----
      foreach (tx.respq[i]) begin
        if (tx.respq[i] !== 2'b00) begin
          `uvm_error("SB_RESP",
            $sformatf("[READ  #%0d] ID=%0h ADDR=%0h RRESP[%0d]=%0b (Expected OKAY=2'b00)",
              rd_count, tx.tx_id, tx.addr, i, tx.respq[i]))
          resp_err_count++;
          all_match = 0;
        end
      end

      // ---- Update counters ----
      if (all_match) begin
        pass_count++;
        case (expected_entry.burst_type)
          FIXED : fixed_pass++;
          INCR  : incr_pass++;
          WRAP  : wrap_pass++;
          default: ;
        endcase
        `uvm_info("SB_PASS",
          $sformatf("[READ  #%0d][%-4s] ID=%0h ADDR=%0h LEN=%0d — PASS | All %0d beats match",
            rd_count, expected_entry.burst_type.name(),
            tx.tx_id, tx.addr, tx.burst_len, tx.dataq.size()),
          UVM_LOW)
      end else begin
        fail_count++;
        case (expected_entry.burst_type)
          FIXED : fixed_fail++;
          INCR  : incr_fail++;
          WRAP  : wrap_fail++;
          default: ;
        endcase
      end

    end // read transaction
  endfunction

  // --------------------------------------------------------
  // report_phase — full summary
  // --------------------------------------------------------
  function void report_phase(uvm_phase phase);
    int total_tx;
    total_tx = pass_count + fail_count;

    `uvm_info("SB_REPORT", $sformatf({
      "\n\n",
      "╔══════════════════════════════════════════╗\n",
      "║       AXI SCOREBOARD FINAL REPORT        ║\n",
      "╠══════════════════════════════════════════╣\n",
      "║  Total Writes          : %-4d             ║\n",
      "║  Total Reads           : %-4d             ║\n",
      "║  Total Transactions    : %-4d             ║\n",
      "╠══════════════════════════════════════════╣\n",
      "║  PASS                  : %-4d             ║\n",
      "║  FAIL                  : %-4d             ║\n",
      "║  No Matching Write     : %-4d             ║\n",
      "║  Response Errors       : %-4d             ║\n",
      "╠══════════════════════════════════════════╣\n",
      "║  FIXED  PASS/FAIL      : %-2d / %-2d          ║\n",
      "║  INCR   PASS/FAIL      : %-2d / %-2d          ║\n",
      "║  WRAP   PASS/FAIL      : %-2d / %-2d          ║\n",
      "╚══════════════════════════════════════════╝\n"},
      wr_count, rd_count, total_tx,
      pass_count, fail_count,
      no_match_count, resp_err_count,
      fixed_pass, fixed_fail,
      incr_pass,  incr_fail,
      wrap_pass,  wrap_fail),
      UVM_NONE)

    if (fail_count > 0)
      `uvm_error("SB_REPORT",
        $sformatf("TEST FAILED — %0d/%0d transactions FAILED", fail_count, total_tx))
    else
      `uvm_info("SB_REPORT",
        $sformatf("TEST PASSED — %0d/%0d transactions PASSED", pass_count, total_tx),
        UVM_NONE)

    if (wr_data_mem.size() > 0)
      `uvm_warning("SB_REPORT",
        $sformatf("%0d write(s) have no matching read — test may be incomplete",
          wr_data_mem.size()))
  endfunction

endclass

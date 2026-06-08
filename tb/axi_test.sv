class axi_test extends uvm_test;
  axi_env env;
  `uvm_component_utils(axi_test)
  `NEW_COMP

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass

// ============================================================

class test1 extends axi_test;
  `uvm_component_utils(test1)
  `NEW_COMP

  axi_wr_rd          seq1;
  axi_wrap           seq2;
  axi_incr_burst     seq3;
  axi_fixed_burst    seq4;
  axi_narrow_transfer seq5;

  task run_phase(uvm_phase phase);
    string SEQ;

    // Raise objection before anything runs
    phase.raise_objection(this);

    if ($value$plusargs("SEQ=%s", SEQ)) begin
      `uvm_info("TEST",
        $sformatf("Running sequence: %s with NO_OF_TX=%0d", SEQ, `NO_OF_TX),
        UVM_LOW)

      case (SEQ)
        "all_burst": begin
          seq1 = axi_wr_rd::type_id::create("seq1");
          seq1.start(env.magent.sqr);
        end

        "wrap": begin
          seq2 = axi_wrap::type_id::create("seq2");
          seq2.start(env.magent.sqr);
        end

        "incr": begin
          seq3 = axi_incr_burst::type_id::create("seq3");
          seq3.start(env.magent.sqr);
        end

        "fixed": begin
          seq4 = axi_fixed_burst::type_id::create("seq4");
          seq4.start(env.magent.sqr);
        end

        "narrow": begin
          seq5 = axi_narrow_transfer::type_id::create("seq5");
          seq5.start(env.magent.sqr);
        end

        default:
          `uvm_error("TEST",
            $sformatf("Unknown SEQ=%s — valid options: all_burst, wrap, incr, fixed, narrow", SEQ))
      endcase

    end else begin
      `uvm_error("TEST", "No +SEQ plusarg provided! Use +SEQ=all_burst or +SEQ=incr etc.")
    end

    // Wait for last transaction to complete through responder and monitor
    // seq.start() returns when last item leaves driver
    // #2000 gives responder + monitor time to finish last read
    #100000;

    phase.drop_objection(this);
    `uvm_info("TEST", "Objection dropped — UVM flowing to report_phase", UVM_LOW)

  endtask

endclass

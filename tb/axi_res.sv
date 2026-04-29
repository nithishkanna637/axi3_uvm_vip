class axi_res extends uvm_component;
  `uvm_component_utils(axi_res)

  virtual axi_intr vif;
  byte mem[int];

  typedef struct {
    bit [`addr_width-1:0] awaddr;
    bit [2:0]             awsize;
    bit [3:0]             awlen;
    bit [1:0]             awburst;
  } aw_info_t;

  aw_info_t aw_queue[$];
  bit [3:0] b_id_queue[$];

  function new(string name = "axi_res", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual axi_intr)::read_by_name("GLOBAL","pif",vif,this))
      `uvm_fatal("RESPONDER", "vif unable to read by name");
  endfunction

  task run_phase(uvm_phase phase);
    wait(vif.resetn === 1'b1);
    $display("RES: reset done at time=%0t", $time);
    fork
      handle_write_addr();
      handle_write_data();
      handle_write_resp();
      handle_read();
    join_none
  endtask

  task handle_write_addr();
    forever begin
      aw_info_t info;
      vif.responder_cb.awready <= 1'b1;
      $display("AW_TASK: awready=1 waiting for awvalid at time=%0t", $time);
      do begin
        @(vif.responder_cb);
      end while (vif.responder_cb.awvalid !== 1'b1);

      info.awaddr  = vif.responder_cb.awaddr;
      info.awsize  = vif.responder_cb.awsize;
      info.awlen   = vif.responder_cb.awlen;
      info.awburst = vif.responder_cb.awburst;

      $display("AW_TASK: handshake done addr=%h size=%0d len=%0d burst=%0d at time=%0t queue_before=%0d",
                info.awaddr, info.awsize, info.awlen, info.awburst,
                $time, aw_queue.size());

      aw_queue.push_back(info);
      $display("AW_TASK: pushed to queue, queue_size_now=%0d at time=%0t",
                aw_queue.size(), $time);

      vif.responder_cb.awready <= 1'b0;
      $display("AW_TASK: awready=0 at time=%0t", $time);
    end
  endtask

  task handle_write_data();
    forever begin
      aw_info_t cur;
      bit [`addr_width-1:0] awaddr_t;
      bit [2:0]             awsize_t;
      bit [3:0]             awlen_t;
      bit [1:0]             awburst_t;

      $display("W_TASK: waiting for aw_queue queue_size=%0d at time=%0t",
                aw_queue.size(), $time);
      wait(aw_queue.size() > 0);

      cur       = aw_queue.pop_front();
      awaddr_t  = cur.awaddr;
      awsize_t  = cur.awsize;
      awlen_t   = cur.awlen;
      awburst_t = cur.awburst;

      $display("W_TASK: popped addr=%h size=%0d len=%0d burst=%0d at time=%0t queue_remaining=%0d",
                awaddr_t, awsize_t, awlen_t, awburst_t, $time, aw_queue.size());

      vif.responder_cb.wready <= 1'b1;
      $display("W_TASK: wready=1 waiting for wvalid at time=%0t", $time);

      forever begin
        @(vif.responder_cb);
        if (vif.responder_cb.wvalid && vif.responder_cb.wready) begin
          $display("W_TASK: wvalid seen writing to addr=%h wdata=%h at time=%0t",
                    awaddr_t, vif.responder_cb.wdata, $time);

          for (int k = 0; k < (2**awsize_t); k++) begin
            mem[awaddr_t + k] = vif.responder_cb.wdata[(k*8)+:8];
            `uvm_info("WRITE_ADDR",
              $sformatf("mem[%0d]=%h", awaddr_t+k, mem[awaddr_t+k]), UVM_LOW)
          end

          case (awburst_t)
            2'b00: awaddr_t = awaddr_t;
            2'b01: awaddr_t += (2**awsize_t);
            2'b10: begin
              int burst_len_bytes = (2**awsize_t) * (awlen_t + 1);
              bit [`addr_width-1:0] wrap_lower = (awaddr_t/burst_len_bytes)*burst_len_bytes;
              bit [`addr_width-1:0] wrap_upper = wrap_lower + burst_len_bytes;
              awaddr_t += (2**awsize_t);
              if (awaddr_t == wrap_upper) begin
                $display("W_TASK: wrap boundary hit lower=%h upper=%h at time=%0t",
                          wrap_lower, wrap_upper, $time);
                awaddr_t = wrap_lower;
              end
            end
          endcase

          $display("W_TASK: next addr will be=%h wlast=%0b at time=%0t",
                    awaddr_t, vif.responder_cb.wlast, $time);

          if (vif.responder_cb.wlast === 1'b1) begin
            $display("W_TASK: wlast seen transaction complete pushing wid=%0d at time=%0t",
                      vif.responder_cb.wid, $time);
            b_id_queue.push_back(vif.responder_cb.wid);
            vif.responder_cb.wready <= 1'b0;
            $display("W_TASK: wready=0 at time=%0t", $time);
            break;
          end
        end
      end
    end
  endtask

  task handle_write_resp();
    forever begin
      if (b_id_queue.size() > 0) begin
        $display("B_TASK: b_id_queue has %0d entries sending bid=%0d at time=%0t",
                  b_id_queue.size(), b_id_queue[0], $time);
        vif.responder_cb.bid    <= b_id_queue.pop_front();
        vif.responder_cb.bresp  <= 2'b00;
        vif.responder_cb.bvalid <= 1'b1;
        $display("B_TASK: bvalid=1 waiting for bready at time=%0t", $time);
        do begin
          @(vif.responder_cb);
        end while (vif.responder_cb.bready !== 1'b1);
        $display("B_TASK: bready seen, response done at time=%0t", $time);
        vif.responder_cb.bvalid <= 1'b0;
      end else begin
        @(vif.responder_cb);
      end
    end
  endtask

  task handle_read();
    bit [`addr_width-1:0] araddr_t;
    bit [7:0] arlen_t;
    bit [2:0] arsize_t;
    bit [1:0] arburst_t;
    bit [3:0] arid_t;

    forever begin
      vif.responder_cb.arready <= 1'b1;
      $display("R_TASK: arready=1 waiting for arvalid at time=%0t", $time);
      do begin
        @(vif.responder_cb);
      end while (vif.responder_cb.arvalid !== 1'b1);

      araddr_t  = vif.responder_cb.araddr;
      arlen_t   = vif.responder_cb.arlen;
      arsize_t  = vif.responder_cb.arsize;
      arburst_t = vif.responder_cb.arburst;
      arid_t    = vif.responder_cb.arid;

      $display("R_TASK: arvalid seen araddr=%h arlen=%0d arsize=%0d arid=%0d at time=%0t",
                araddr_t, arlen_t, arsize_t, arid_t, $time);

      vif.responder_cb.arready <= 1'b0;
      $display("R_TASK: arready=0 starting read beats at time=%0t", $time);

      for (int i = 0; i <= arlen_t; i++) begin
        vif.responder_cb.rid    <= arid_t;
        vif.responder_cb.rresp  <= 2'b00;
        vif.responder_cb.rlast  <= (i == arlen_t);
        vif.responder_cb.rvalid <= 1'b1;

        $display("R_TASK: beat=%0d reading from araddr=%h at time=%0t",
                  i, araddr_t, $time);

        for (int j = 0; j < (2**arsize_t); j++) begin
          vif.responder_cb.rdata[(j*8)+:8] <= mem[araddr_t + j];
          `uvm_info("READ_ADDR",
            $sformatf("mem[%0d]=%h", araddr_t+j, mem[araddr_t+j]), UVM_LOW)
          $display("R_TASK: mem[%0d]=%h for araddr=%h beat=%0d at time=%0t",
                    araddr_t+j, mem[araddr_t+j], araddr_t, i, $time);
        end

        do begin
          @(vif.responder_cb);
        end while (vif.responder_cb.rready !== 1'b1);
        $display("R_TASK: rready seen for beat=%0d at time=%0t", i, $time);

        case (arburst_t)
          2'b00: araddr_t = araddr_t;
          2'b01: araddr_t += (2**arsize_t);
          2'b10: begin
            int burst_len_bytes1 = (2**arsize_t) * (arlen_t + 1);
            bit [`addr_width-1:0] wrap_lower1 = (araddr_t/burst_len_bytes1)*burst_len_bytes1;
            bit [`addr_width-1:0] wrap_upper1 = wrap_lower1 + burst_len_bytes1;
            araddr_t += (2**arsize_t);
            if (araddr_t == wrap_upper1) begin
              $display("R_TASK: wrap hit lower=%h upper=%h at time=%0t",
                        wrap_lower1, wrap_upper1, $time);
              araddr_t = wrap_lower1;
            end
          end
        endcase

        $display("R_TASK: next araddr=%h at time=%0t", araddr_t, $time);
      end

      $display("R_TASK: all beats done rvalid=0 rlast=0 at time=%0t", $time);
      vif.responder_cb.rvalid <= 1'b0;
      vif.responder_cb.rlast  <= 1'b0;
    end
  endtask

endclass

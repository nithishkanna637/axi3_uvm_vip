class axi_dri extends uvm_driver#(axi_tx);
  `uvm_component_utils(axi_dri)
  int wr_count = 0;
  virtual axi_intr vif;
  semaphore wr_a;
  semaphore wr_d;
  semaphore wr_r;
  semaphore rd_a;
  semaphore rd_d;
  event aw_done;

  function new(string name = "axi_dri", uvm_component parent = null);
    super.new(name, parent);
    wr_a = new(1);
    wr_d = new(1);
    wr_r = new(1);
    rd_a = new(1);
    rd_d = new(1);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual axi_intr)::read_by_name("GLOBAL","pif",vif,this))
      `uvm_fatal("DRV", "Unable to get vif");
  endfunction

  task run();
    wait(vif.resetn === 1'b1);
    $display("DRV: reset done, starting at time=%0t", $time);
    forever begin
      axi_tx ux;
      seq_item_port.get_next_item(req);
      $display("DRV: got item wr_rd=%b addr=%h at time=%0t", req.wr_rd, req.addr, $time);
      $cast(ux, req.clone());
      fork
        drive_tx(ux);
      join_none
      @(aw_done);
      $display("DRV: aw_done event received, calling item_done at time=%0t", $time);
      seq_item_port.item_done();
    end
  endtask

  task drive_tx(axi_tx tx);
    $display("DRV: drive_tx started wr_rd=%b addr=%h at time=%0t", tx.wr_rd, tx.addr, $time);
    if (tx.wr_rd == 1'b1) begin
      wr_count++;
      $display("DRV: wr_count incremented to %0d at time=%0t", wr_count, $time);
      wr_a.get(1);
      $display("DRV: AW phase starting addr=%h at time=%0t", tx.addr, $time);
      write_address_phase(tx);
      $display("DRV: AW phase done addr=%h at time=%0t", tx.addr, $time);
      wr_a.put(1);
      ->aw_done;
      $display("DRV: aw_done event triggered at time=%0t", $time);
      wr_d.get(1);
      $display("DRV: W phase starting addr=%h at time=%0t", tx.addr, $time);
      write_data_phase(tx);
      $display("DRV: W phase done addr=%h at time=%0t", tx.addr, $time);
      wr_d.put(1);
      wr_r.get(1);
      $display("DRV: B phase starting addr=%h at time=%0t", tx.addr, $time);
      write_response_phase(tx);
      $display("DRV: B phase done addr=%h at time=%0t", tx.addr, $time);
      wr_r.put(1);
      wr_count--;
      $display("DRV: wr_count decremented to %0d at time=%0t", wr_count, $time);
    end else begin
      $display("DRV: waiting for wr_count=0 currently=%0d at time=%0t", wr_count, $time);
      wait(wr_count == 0);
      $display("DRV: wr_count is 0, starting read addr=%h at time=%0t", tx.addr, $time);
      ->aw_done;
      rd_a.get(1);
      $display("DRV: AR phase starting addr=%h at time=%0t", tx.addr, $time);
      read_address_phase(tx);
      $display("DRV: AR phase done addr=%h at time=%0t", tx.addr, $time);
      rd_a.put(1);
      rd_d.get(1);
      $display("DRV: R phase starting addr=%h at time=%0t", tx.addr, $time);
      read_data_phase(tx);
      $display("DRV: R phase done addr=%h at time=%0t", tx.addr, $time);
      rd_d.put(1);
    end
  endtask

  task write_address_phase(axi_tx tx);
    $display("DRV: driving awvalid=1 addr=%h at time=%0t", tx.addr, $time);
    vif.driver_cb.awid    <= tx.tx_id;
    vif.driver_cb.awlen   <= tx.burst_len;
    vif.driver_cb.awsize  <= tx.burst_size;
    vif.driver_cb.awburst <= tx.burst_type;
    vif.driver_cb.awaddr  <= tx.addr;
    vif.driver_cb.awvalid <= 1'b1;
    do begin
      @(vif.driver_cb);
    end while (vif.driver_cb.awready !== 1'b1);
    $display("DRV: awready seen, handshake done addr=%h at time=%0t", tx.addr, $time);
    vif.driver_cb.awvalid <= 1'b0;
  endtask

  task write_data_phase(axi_tx tx);
    $display("DRV: write data phase starting %0d beats at time=%0t", tx.burst_len+1, $time);
    for (int i = 0; i <= tx.burst_len; i++) begin
      vif.driver_cb.wdata  <= tx.dataq.pop_front();
      vif.driver_cb.wstrb  <= tx.strbq.pop_front();
      vif.driver_cb.wid    <= tx.tx_id;
      vif.driver_cb.wlast  <= (i == tx.burst_len) ? 1'b1 : 1'b0;
      vif.driver_cb.wvalid <= 1'b1;
      $display("DRV: W beat=%0d wvalid=1 at time=%0t", i, $time);
      do begin
        @(vif.driver_cb);
      end while (vif.driver_cb.wready !== 1'b1);
      $display("DRV: W beat=%0d wready seen at time=%0t", i, $time);
    end
    vif.driver_cb.wvalid <= 1'b0;
    vif.driver_cb.wlast  <= 1'b0;
  endtask

  task write_response_phase(axi_tx tx);
    $display("DRV: waiting for bvalid at time=%0t", $time);
    vif.driver_cb.bready <= 1'b1;
    do begin
      @(vif.driver_cb);
    end while (vif.driver_cb.bvalid !== 1'b1);
    $display("DRV: bvalid seen, bresp done at time=%0t", $time);
    vif.driver_cb.bready <= 1'b0;
  endtask

  task read_address_phase(axi_tx tx);
    @(vif.driver_cb);
    $display("DRV: driving arvalid=1 addr=%h at time=%0t", tx.addr, $time);
    vif.driver_cb.arid    <= tx.tx_id;
    vif.driver_cb.arlen   <= tx.burst_len;
    vif.driver_cb.arsize  <= tx.burst_size;
    vif.driver_cb.arburst <= tx.burst_type;
    vif.driver_cb.araddr  <= tx.addr;
    vif.driver_cb.arvalid <= 1'b1;
    do begin
      @(vif.driver_cb);
    end while (vif.driver_cb.arready !== 1'b1);
    $display("DRV: arready seen, AR handshake done addr=%h at time=%0t", tx.addr, $time);
    vif.driver_cb.arvalid <= 1'b0;
  endtask

  task read_data_phase(axi_tx tx);
    $display("DRV: read data phase starting %0d beats at time=%0t", tx.burst_len+1, $time);
    for (int i = 0; i <= tx.burst_len; i++) begin
      vif.driver_cb.rready <= 1'b1;
      $display("DRV: R beat=%0d rready=1 at time=%0t", i, $time);
      do begin
        @(vif.driver_cb);
      end while (vif.driver_cb.rvalid !== 1'b1);
      $display("DRV: R beat=%0d rvalid seen rdata=%h at time=%0t",
                i, vif.driver_cb.rdata, $time);
    end
    vif.driver_cb.rready <= 1'b0;
  endtask

endclass

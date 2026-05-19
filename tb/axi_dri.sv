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
    forever begin
      axi_tx ux;
      seq_item_port.get_next_item(req);
      $cast(ux, req.clone());
      fork
        drive_tx(ux);
      join_none
      @(aw_done);
      seq_item_port.item_done();
    end
  endtask

  task drive_tx(axi_tx tx);
    if (tx.wr_rd == 1'b1) begin
      wr_count++;
      wr_a.get(1);
      write_address_phase(tx);
      wr_a.put(1);
      ->aw_done;
      wr_d.get(1);
      write_data_phase(tx);
      wr_d.put(1);
      wr_r.get(1);
      write_response_phase(tx);
      wr_r.put(1);
      wr_count--;
    end else begin
      wait(wr_count == 0);
      ->aw_done;
      rd_a.get(1);
      read_address_phase(tx);
      rd_a.put(1);
      rd_d.get(1);
      read_data_phase(tx);
      rd_d.put(1);
    end
  endtask

  task write_address_phase(axi_tx tx);
    vif.driver_cb.awid    <= tx.tx_id;
    vif.driver_cb.awlen   <= tx.burst_len;
    vif.driver_cb.awsize  <= tx.burst_size;
    vif.driver_cb.awburst <= tx.burst_type;
    vif.driver_cb.awaddr  <= tx.addr;
    vif.driver_cb.awvalid <= 1'b1;
    do begin
      @(vif.driver_cb);
    end while (vif.driver_cb.awready !== 1'b1);
    vif.driver_cb.awvalid <= 1'b0;
  endtask

  task write_data_phase(axi_tx tx);
    for (int i = 0; i <= tx.burst_len; i++) begin
      vif.driver_cb.wdata  <= tx.dataq.pop_front();
      vif.driver_cb.wstrb  <= tx.strbq.pop_front();
      vif.driver_cb.wid    <= tx.tx_id;
      vif.driver_cb.wlast  <= (i == tx.burst_len) ? 1'b1 : 1'b0;
      vif.driver_cb.wvalid <= 1'b1;
      do begin
        @(vif.driver_cb);
      end while (vif.driver_cb.wready !== 1'b1);
    end
    vif.driver_cb.wvalid <= 1'b0;
    vif.driver_cb.wlast  <= 1'b0;
  endtask

  task write_response_phase(axi_tx tx);
    vif.driver_cb.bready <= 1'b1;
    do begin
      @(vif.driver_cb);
    end while (vif.driver_cb.bvalid !== 1'b1);
    vif.driver_cb.bready <= 1'b0;
  endtask

  task read_address_phase(axi_tx tx);
    @(vif.driver_cb);
    vif.driver_cb.arid    <= tx.tx_id;
    vif.driver_cb.arlen   <= tx.burst_len;
    vif.driver_cb.arsize  <= tx.burst_size;
    vif.driver_cb.arburst <= tx.burst_type;
    vif.driver_cb.araddr  <= tx.addr;
    vif.driver_cb.arvalid <= 1'b1;
    do begin
      @(vif.driver_cb);
    end while (vif.driver_cb.arready !== 1'b1);
    vif.driver_cb.arvalid <= 1'b0;
  endtask

  task read_data_phase(axi_tx tx);
    for (int i = 0; i <= tx.burst_len; i++) begin
      vif.driver_cb.rready <= 1'b1;
      do begin
        @(vif.driver_cb);
      end while (vif.driver_cb.rvalid !== 1'b1);
    end
    vif.driver_cb.rready <= 1'b0;
  endtask

endclass


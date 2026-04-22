class axi_dri extends uvm_driver#(axi_tx);
  `uvm_component_utils(axi_dri)
  int drive_count;
  virtual axi_intr vif;
  semaphore wr_ad=new(1);
  semaphore wr_dt=new(1);
  semaphore wr_rp=new(1);
  semaphore rd_ad=new(1);
  semaphore rd_dt=new(1);
  function new(string name = "axi_dri", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_resource_db#(virtual axi_intr)::read_by_name("GLOBAL","pif",vif,this)) 
      `uvm_fatal("DRV", "Unable to get vif");
  endfunction

  task run();
    wait(vif.resetn === 1'b1);  
  
  forever begin
  seq_item_port.get_next_item(req);

   begin                           // ← scope block for automatic
    automatic axi_tx tx1 = req;  // ← correct: no 'new', no 'automatic' keyword issue
    fork
        drive_tx(tx1);            // ← use tx1 not req
        drive_count++;            // ← after drive_tx, inside begin..end
   join_none
   end
   #100;
   seq_item_port.item_done();
  end
endtask

  task drive_tx(axi_tx tx);
    if (tx.wr_rd == 1'b1) begin
      write_address_phase(tx);
      @(vif.driver_cb);
      @(vif.driver_cb);
      write_data_phase(tx);
      write_response_phase(tx);
    end else begin
      read_address_phase(tx);
      read_data_phase(tx);
    end
  endtask

  task write_address_phase(axi_tx tx);
   wr_ad.get(1);
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
	wr_ad.put(1);
  endtask

  task write_data_phase(axi_tx tx);	
  wr_dt.get(1);
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
	vif.driver_cb.wdata <= 1'b0;
    wr_dt.put(1);
  endtask

  task write_response_phase(axi_tx tx);
  wr_rp.get(1);
    vif.driver_cb.bready <= 1'b1;
    do begin
      @(vif.driver_cb);
    end while (vif.driver_cb.bvalid !== 1'b1);
    vif.driver_cb.bready <= 1'b0;
  wr_rp.put(1);
  endtask
  
  task read_address_phase(axi_tx tx);
   rd_ad.get(1);
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
	rd_ad.put(1);
  endtask    

  task read_data_phase(axi_tx tx);
  rd_dt.get(1);
    for (int i = 0; i <= tx.burst_len; i++) begin
      vif.driver_cb.rready <= 1'b1;
      do begin
        @(vif.driver_cb);
      end while (vif.driver_cb.rvalid !== 1'b1);
    end
    vif.driver_cb.rready <= 1'b0;
  rd_dt.put(1);
  endtask
endclass

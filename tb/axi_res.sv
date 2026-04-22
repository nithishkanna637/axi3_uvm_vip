class axi_res extends uvm_component;
  `uvm_component_utils(axi_res)
  
  virtual axi_intr vif;
  byte mem[int];

  bit [`addr_width-1:0] awaddr_t;
  bit [2:0] awsize_t;
  bit [3:0] b_id_queue[$];
  bit [3:0] awlen_t;

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

    fork
      handle_write_addr();
      handle_write_data();
      handle_write_resp();
      handle_read();
    join_none
  endtask

  task handle_write_addr();
    forever begin
      vif.responder_cb.awready <= 1'b1;
      do begin
        @(vif.responder_cb);
      end while (vif.responder_cb.awvalid !== 1'b1);
      
      awaddr_t = vif.responder_cb.awaddr;
      awsize_t = vif.responder_cb.awsize;
      awlen_t = vif.responder_cb.awlen;
      
      vif.responder_cb.awready <= 1'b0;
      @(vif.responder_cb);
    end
  endtask

  task handle_write_data();
    forever begin
      vif.responder_cb.wready <= 1'b1;
      @(vif.responder_cb);

      if (vif.responder_cb.awready && vif.responder_cb.wvalid && vif.responder_cb.wready) begin

	  for(int k=0;k<(2**awsize_t);k++) begin
           mem[awaddr_t + k] = vif.responder_cb.wdata[(k*8)+:8];
		  `uvm_info("WRITE_ADDR",$sformatf("mem[%d]=%h",awaddr_t+k,mem[awaddr_t+k]),UVM_LOW)
		   
	  end
       /*  mem[awaddr_t+0] = vif.responder_cb.wdata[7:0];    
        mem[awaddr_t+1] = vif.responder_cb.wdata[15:8];    
        mem[awaddr_t+2] = vif.responder_cb.wdata[23:16];    
        mem[awaddr_t+3] = vif.responder_cb.wdata[31:24];
		*/
        
        case (vif.responder_cb.awburst)
          2'b00: awaddr_t = awaddr_t;
          2'b01: awaddr_t += (2**awsize_t); 
          2'b10: begin
             int burst_len_bytes = (2**awsize_t) * (awlen_t + 1);
             bit [`addr_width-1:0] wrap_lower_boundary =  (awaddr_t/burst_len_bytes)*burst_len_bytes;
			 bit [`addr_width-1:0] wrap_upper_boundary =  wrap_lower_boundary + burst_len_bytes;
             awaddr_t += (2**awsize_t);
             if (awaddr_t == wrap_upper_boundary) begin
			  $display("wrap_upper_bound-%d",wrap_upper_boundary);			
              awaddr_t = wrap_lower_boundary;
			 end
          end
        endcase

        if (vif.responder_cb.wlast === 1'b1) begin
          b_id_queue.push_back(vif.responder_cb.wid);
          vif.responder_cb.wready <= 1'b0;
          @(vif.responder_cb); 
        end
      end
    end
  endtask

  task handle_write_resp();
    forever begin
      if (b_id_queue.size() > 0) begin
        vif.responder_cb.bid    <= b_id_queue.pop_front();
        vif.responder_cb.bresp  <= 2'b00;
        vif.responder_cb.bvalid <= 1'b1;
        
        do begin
          @(vif.responder_cb);
        end while (vif.responder_cb.bready !== 1'b1);
        
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
      
      do begin
        @(vif.responder_cb);
      end while (vif.responder_cb.arvalid !== 1'b1);
      
      araddr_t  = vif.responder_cb.araddr;
      arlen_t   = vif.responder_cb.arlen;
      arsize_t  = vif.responder_cb.arsize;
      arburst_t = vif.responder_cb.arburst;
      arid_t    = vif.responder_cb.arid;
      vif.responder_cb.arready <= 1'b0;

        for (int i = 0; i <= arlen_t; i++) begin
        vif.responder_cb.rid    <= arid_t;
        vif.responder_cb.rresp  <= 2'b00;
        vif.responder_cb.rlast  <= (i == arlen_t);
        vif.responder_cb.rvalid <= 1'b1;
        
		for(int j=0;j<(2**arsize_t);j++) begin
          vif.responder_cb.rdata[(j*8)+:8] <= mem[araddr_t + j];
		  `uvm_info("READ_ADDR",$sformatf("mem[%d]=%h",araddr_t+j,mem[araddr_t+j]),UVM_LOW)
		end
        /* vif.responder_cb.rdata  <= {mem[araddr_t+3], 
                                    mem[araddr_t+2], 
                                    mem[araddr_t+1], 
                                    mem[araddr_t+0]};
									*/

        do begin
          @(vif.responder_cb);
        end while (vif.responder_cb.rready !== 1'b1);

        case (arburst_t)
          2'b00: araddr_t = araddr_t;
          2'b01: araddr_t += (2**arsize_t);
          2'b10:  begin
             int burst_len_bytes1 = (2**arsize_t) * (arlen_t + 1);
             bit [`addr_width-1:0] wrap_lower_boundary1 =  (araddr_t/burst_len_bytes1)*burst_len_bytes1;
			 bit [`addr_width-1:0] wrap_upper_boundary1 =  wrap_lower_boundary1 + burst_len_bytes1;
             araddr_t += (2**arsize_t);
             if (araddr_t == wrap_upper_boundary1) begin
			  $display("wrap_upper_bound-%d",wrap_upper_boundary1);			
              araddr_t = wrap_lower_boundary1;
			 end
          end
        endcase
      end
      
      vif.responder_cb.rvalid <= 1'b0;
      vif.responder_cb.rlast  <= 1'b0;
    end
  endtask
endclass

// the monitor actively watches/samples the interface signals.
//It's the monitor's job to detect and collect transactions by observing DUT pins.

class mast_mon extends uvm_monitor;
    axi_tx tx1, tx2;
    virtual axi_intr vif;
     uvm_analysis_port#(axi_tx) ap_port;
    `uvm_component_utils(mast_mon)
    
    function new(input string name=" ", uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_resource_db#(virtual axi_intr)::read_by_name("GLOBAL","pif",vif,this))
            `uvm_fatal("MASTER_MON", "vif unable to read by name");
       ap_port = new("ap_port", this); 
     endfunction
    
    task run_phase(uvm_phase phase);  // ✅ task not function
        forever begin                  // ✅ forever loop
            @(vif.monitor_cb);         // ✅ clock edge FIRST
            // Write Address Channel
            if(vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
                tx1 = new("tx1");      // ✅ fresh object every iteration
				tx1.wr_rd = 1;
                tx1.addr  = vif.monitor_cb.awaddr;
                tx1.tx_id    = vif.monitor_cb.awid;
                tx1.burst_type = burst_type_id'(vif.monitor_cb.awburst);  // ✅ ?
                tx1.burst_len   = vif.monitor_cb.awlen;
                tx1.burst_size  = vif.monitor_cb.awsize;
            end
            
            // Write Data Channel
            if(vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
                tx1.dataq.push_back(vif.monitor_cb.wdata);  // ✅ single element
                tx1.strbq.push_back(vif.monitor_cb.wstrb);  // ✅ single element
            end
            
            // Write Response Channel
            if(vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
			`uvm_info("MASTER_MON", tx1.sprint(), UVM_LOW)  // ✅ sprint() not print()
                ap_port.write(tx1);
            end
            
            // Read Address Channel
            if(vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
                tx2 = new("tx2");      // ✅ fresh object every iteration
				tx2.wr_rd=0;
                tx2.addr  = vif.monitor_cb.araddr;
                tx2.tx_id    = vif.monitor_cb.arid;
                tx2.burst_type = burst_type_id'(vif.monitor_cb.arburst);  // ✅ ?
                tx2.burst_len  = vif.monitor_cb.arlen;
                tx2.burst_size  = vif.monitor_cb.arsize;
            end
            
            // Read Data Channel
            if(vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
               `uvm_info("MASTER_MON", tx2.sprint(), UVM_LOW)  // ✅ sprint() not print()
                 ap_port.write(tx2);
            end
            
        end
    endtask

endclass

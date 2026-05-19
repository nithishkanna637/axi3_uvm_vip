// the monitor actively watches/samples the interface signals.
//It's the monitor's job to detect and collect transactions by observing DUT pins.

class mast_mon extends uvm_monitor;
    `uvm_component_utils(mast_mon)

    virtual axi_intr vif;
    uvm_analysis_port#(axi_tx) ap_port;

    // Use Queues within the associative array to handle multiple 
    // outstanding transactions with the same ID.
    axi_tx wr_pending[int][$]; 
    axi_tx rd_pending[int][$];

    function new(string name="mast_mon", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_resource_db#(virtual axi_intr)::read_by_name("GLOBAL","pif",vif,this))
            `uvm_fatal("MON", "vif unable to read by name");
        ap_port = new("ap_port", this);
    endfunction

    task run_phase(uvm_phase phase);
        wait(vif.resetn === 1'b1);
        fork
            collect_aw();
            collect_w();
            collect_b();
            collect_ar();
            collect_r();
        join_none
    endtask

    task collect_aw();
        forever begin
            @(vif.monitor_cb);
            if(vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
                axi_tx tx = new("tx_wr");
                tx.wr_rd      = 1;
                tx.addr       = vif.monitor_cb.awaddr;
                tx.tx_id      = vif.monitor_cb.awid;
                tx.burst_len  = vif.monitor_cb.awlen;
                tx.burst_size = vif.monitor_cb.awsize;
                tx.burst_type = burst_type_id'(vif.monitor_cb.awburst);
                // Push to the queue for this specific ID
                wr_pending[tx.tx_id].push_back(tx); 
            end
        end
    endtask

    task collect_w();
        forever begin
            @(vif.monitor_cb);
            if(vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
                int id = vif.monitor_cb.wid;
                // AXI requires W-data to follow the order of AW-addresses for the same ID
                if(wr_pending.exists(id) && wr_pending[id].size() > 0) begin
                    wr_pending[id][0].dataq.push_back(vif.monitor_cb.wdata);
                end
            end
        end
    endtask

    task collect_b();
        forever begin
            @(vif.monitor_cb);
            if(vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
                int id = vif.monitor_cb.bid;
                if(wr_pending.exists(id) && wr_pending[id].size() > 0) begin
                    axi_tx completed_tx = wr_pending[id].pop_front(); // Take the oldest one
                    completed_tx.respq.push_back(vif.monitor_cb.bresp);
                    ap_port.write(completed_tx); 
                    if(wr_pending[id].size() == 0) wr_pending.delete(id);
                end
            end
        end
    endtask

    task collect_ar();
        forever begin
            @(vif.monitor_cb);
            if(vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
                axi_tx tx = new("tx_rd");
                tx.wr_rd      = 0;
                tx.addr       = vif.monitor_cb.araddr;
                tx.tx_id      = vif.monitor_cb.arid;
                tx.burst_len  = vif.monitor_cb.arlen;
                tx.burst_size = vif.monitor_cb.arsize;
                tx.burst_type = burst_type_id'(vif.monitor_cb.arburst);
                rd_pending[tx.tx_id].push_back(tx);
            end
        end
    endtask

    task collect_r();
        forever begin
            @(vif.monitor_cb);
            if(vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
                int id = vif.monitor_cb.rid;
                if(rd_pending.exists(id) && rd_pending[id].size() > 0) begin
                    rd_pending[id][0].dataq.push_back(vif.monitor_cb.rdata);
                    rd_pending[id][0].respq.push_back(vif.monitor_cb.rresp);
                    
                    if(vif.monitor_cb.rlast) begin
                        axi_tx completed_tx = rd_pending[id].pop_front();
                        ap_port.write(completed_tx);
                        if(rd_pending[id].size() == 0) rd_pending.delete(id);
                    end
                end
            end
        end
    endtask
endclass


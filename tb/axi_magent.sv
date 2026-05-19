
class axi_magent extends uvm_agent;
axi_sequencer sqr;
axi_dri dri;
axi_coverage cov;
mast_mon mon;
`uvm_component_utils(axi_magent)
`NEW_COMP
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  sqr=axi_sequencer::type_id::create("sqr",this);
  dri=axi_dri::type_id::create("dri",this);
  //$display("driver is created");
  cov=axi_coverage::type_id::create("cov",this);
  mon=mast_mon::type_id::create("mon",this);
endfunction

function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
  $display("connect phase is happening");
     dri.seq_item_port.connect(sqr.seq_item_export);
	 mon.ap_port.connect(cov.analysis_export);

endfunction
endclass

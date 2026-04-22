class axi_env extends uvm_env;
axi_magent magent;
axi_sagent sagent;
`uvm_component_utils(axi_env)
`NEW_COMP
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  magent=axi_magent::type_id::create("magent",this);
  sagent=axi_sagent::type_id::create("sagent",this);
endfunction
endclass

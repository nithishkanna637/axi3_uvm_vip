class axi_sagent extends uvm_agent;
axi_res res;
`uvm_component_utils(axi_sagent)
`NEW_COMP
function void build_phase(uvm_phase phase);
  res=axi_res::type_id::create("res",this);
endfunction
endclass

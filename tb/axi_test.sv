class axi_test extends uvm_test;
axi_env env;
`uvm_component_utils(axi_test)
`NEW_COMP
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_env::type_id::create("env", this);
  endfunction

function void end_of_elaboration();
 	uvm_top.print_topology();
endfunction
endclass

class test1 extends axi_test;

`uvm_component_utils(test1)
`NEW_COMP
 axi_wr_rd seq1;
   //axi_wrap seq2;
task run_phase(uvm_phase phase);
  seq1=new("seq1");
 // seq2=new("seq2");
  phase.raise_objection(this);
  seq1.start(env.magent.sqr);
   //seq2.start(env.magent.sqr);
  wait(drive_count==2*`N0_OF_TX);
  $display("drivecount=%0d",drive_count);
 phase.drop_objection(this);
endtask
endclass

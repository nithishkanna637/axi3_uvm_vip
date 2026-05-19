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
 axi_wrap seq2;
 axi_incr_burst seq3;
 axi_fixed_burst seq4;
 axi_narrow_transfer seq5;
task run_phase(uvm_phase phase);
  string SEQ;
  if ($value$plusargs("SEQ=%s", SEQ)) begin 
    case(SEQ)
      "all_burst":begin
	   	seq1 = axi_wr_rd::type_id::create("seq1"); 
        phase.raise_objection(this);
        seq1.start(env.magent.sqr);
		wait(drive_count==2*`NO_OF_TX);
        phase.drop_objection(this);
      end

      "wrap": begin
        seq2 = axi_wrap::type_id::create("seq2"); 
		phase.raise_objection(this);
        seq2.start(env.magent.sqr);
		wait(drive_count==2*`NO_OF_TX);
        phase.drop_objection(this);
      end

      "incr": begin
        seq3 = axi_incr_burst::type_id::create("seq3"); 
		phase.raise_objection(this);
        seq3.start(env.magent.sqr);
		wait(drive_count==2*`NO_OF_TX);
        phase.drop_objection(this);
      end
      
	  "fixed": begin
        seq4 = axi_fixed_burst::type_id::create("seq4"); 
		phase.raise_objection(this);
        seq4.start(env.magent.sqr);
		wait(drive_count==2*`NO_OF_TX);
        phase.drop_objection(this);
      end
      
	  "narrow": begin
        seq5 = axi_narrow_transfer::type_id::create("seq5"); 
		phase.raise_objection(this);
        seq5.start(env.magent.sqr);
		wait(drive_count==2*`NO_OF_TX);
        phase.drop_objection(this);
      end

    endcase
  end else begin
    `uvm_info("TEST", "No +SEQ plusarg found!", UVM_LOW)
  end
endtask
endclass

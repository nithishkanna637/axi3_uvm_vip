//A bin is a single checkbox — one specific value or range of values that you want to confirm simulation has exercised.
//Coverpoint — A named construct inside a covergroup that monitors one specific signal or expression and organizes what values matter through bins.
//covergroup-a user defined container that contains the set of coverpoints and it defines when to sample the covergroup,it must be instantiated with new()

class axi_coverage extends uvm_subscriber #(axi_tx);
  axi_tx tx;
  `uvm_component_utils(axi_coverage)

  // ✅ covergroup takes tx as argument
  covergroup axi_cg;
    WR_RD_CP: coverpoint tx.wr_rd {
      bins WRITE = {1'b1};
      bins READ  = {1'b0};
    }
  endgroup

  function new(string name="", uvm_component parent);
    super.new(name, parent);
    axi_cg=new();
  endfunction

  //-----> Write method: Sample coverage
    function void write(axi_tx t);
	   tx=new t;
       axi_cg.sample();                  // Sample covergroup
    endfunction
endclass

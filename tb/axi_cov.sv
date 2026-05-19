//A bin is a single checkbox — one specific value or range of values that you want to confirm simulation has exercised.
//Coverpoint — A named construct inside a covergroup that monitors one specific signal or expression and organizes what values matter through bins.
//covergroup-a user defined container that contains the set of coverpoints and it defines when to sample the covergroup,it must be instantiated with new()

class axi_coverage extends uvm_subscriber #(axi_tx);
  axi_tx tx;
  `uvm_component_utils(axi_coverage)

  covergroup axi_cg;
    WR_RD_CP: coverpoint tx.wr_rd {
      bins WRITE = {1'b1};
      bins READ  = {1'b0};
    }

	ADDR: coverpoint tx.addr {
	bins zero_addr        = {32'h0000_0000};
    bins low_addr         = {[32'h0000_0001 : 32'h0000_FFFF]};
    bins mid_addr         = {[32'h0001_0000 : 32'hFFFE_FFFF]};
    bins high_addr        = {[32'hFFFF_0000 : 32'hFFFF_FFFE]};
    bins max_addr         = {32'hFFFF_FFFF};
	  }

    ADDR_ALIGNMENT_CHECK: coverpoint (tx.addr % (2**tx.burst_size)) {
    bins aligned   = {0};      
	bins unaligned = {[1:127]};}
	
    BURST_TYPE:coverpoint tx.burst_type{
	bins fixed = {2'b00};
	bins incr = {2'b01};
	bins wrap = {2'b10};
	illegal_bins rsvd ={2'b11};
	}

	BURST_LEN:coverpoint tx.burst_len{
	bins min_len = {[3:0]};
	bins mid_len = {[7:4]};
	bins max_len = {[15:8]};
	}

	BURST_SIZE: coverpoint tx.burst_size{
	bins burst[] = {[7:0]};
	}
 
    X_ADDR_WR_RD_CP: cross WR_RD_CP, ADDR;
    
	X_WRAP_TYPE_LEN:  cross BURST_TYPE,BURST_LEN{
	  bins wrap_cons= binsof(BURST_TYPE) intersect {2'b10} 
	                 && binsof(BURST_LEN) intersect {1,3,7,15};
	  ignore_bins ign_burst = !binsof(BURST_TYPE) intersect {2'b10};
					 }

    X_WRAP_LEN_ALIGNMENT: cross BURST_TYPE,ADDR_ALIGNMENT_CHECK{
        bins wrap_unalignment = binsof(BURST_TYPE) intersect {2'b10}
		                        && binsof(ADDR_ALIGNMENT_CHECK) intersect {0};
		ignore_bins non_wrap_burst = !binsof(BURST_TYPE) intersect {2'b10};
		illegal_bins illegal_wrap_unaligned = binsof(BURST_TYPE) intersect {2'b10}
		                                      && binsof(ADDR_ALIGNMENT_CHECK) intersect {[1:127]};
								}

    ADDR_WRAP_OFFSET: coverpoint (tx.addr % ((2**tx.burst_size) * (tx.burst_len + 1))) {
    bins boundary = {0};
    bins offset   = {[1:$]}; // This is your "addr % ... != 0" logic
     }

    X_WRAP_ADDRESS_CHECK: cross BURST_TYPE, ADDR_WRAP_OFFSET {
        bins true_wrap_event = binsof(BURST_TYPE) intersect {2'b10} && 
                           binsof(ADDR_WRAP_OFFSET) intersect {[1:$]};
         ignore_bins no_wraps = binsof(BURST_TYPE) intersect {2'b10}
		                        && binsof(ADDR_WRAP_OFFSET) intersect {0};
         ignore_bins others = !binsof(BURST_TYPE) intersect {2'b10};
       }     
  endgroup

  function new(string name="", uvm_component parent);
    super.new(name, parent);
    axi_cg=new();
  endfunction

 
    function void write(axi_tx t);
	   tx=new t;
       axi_cg.sample();                  // Sample covergroup
    endfunction
endclass

`define addr_width 32
`define data_width 32
`define strb_width `data_width/8
`define N0_OF_TX 10
 int drive_count;
`define NEW_COMP \
 function new(input string name ="",uvm_component parent); \
 	 super.new(name,parent); \
 endfunction 
 `define NEW_OBJ \
 function new(input string name =""); \
   	super.new(name); \
 endfunction


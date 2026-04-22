interface axi_intr(input logic aclk,resetn);
  //write address phase
  bit [3:0]awid;
  bit [`addr_width-1:0]awaddr;
  bit [2:0]awsize;
  bit [3:0]awlen;
  bit [1:0]awburst;
  bit awvalid;
  bit awready;
  //write data phase 
  bit [3:0]wid;
  bit [`data_width-1:0]wdata;
  bit [`strb_width-1:0]wstrb;
  bit wlast;
  bit wvalid;
  bit wready;
  //write response phase
  bit [3:0]bid;
  bit bresp;
  bit bvalid;
  bit bready;
 //read addr phase 
  bit [3:0]arid;
  bit [`addr_width-1:0]araddr;
  bit [2:0]arsize;
  bit [3:0]arlen;
  bit [1:0]arburst;
  bit arvalid;
  bit arready;
 // read data phase 
  bit [3:0]rlen;
  bit rlast;
  bit [3:0]rid;
  bit [`data_width-1:0]rdata;
  bit rready;
  bit rvalid;
  bit rresp;
  
  //----> bfm clocking block
	clocking driver_cb@(posedge aclk);
		default input #0 output #0;
			output awid,awaddr,awlen,awsize,awburst,awvalid;
			input  resetn,awready,wready;
			output wid, wdata, wstrb, wlast, wvalid;
			output bready;
			input  bid, bresp, bvalid;

			output arid, araddr,arlen,arsize,arburst,arvalid;
			input  arready;
			output rready;
			input  rid, rdata, rlast,rvalid,rresp;	
	endclocking


  clocking responder_cb@(posedge aclk);
		default input #0 output #0;
			input 	awid,awaddr,awlen,awsize,awburst,awvalid, resetn;
			output  awready,wready;
			input 	wid, wdata, wstrb, wlast, wvalid;
			input	bready;
			output  bid, bresp, bvalid;

			input 	arid, araddr,arlen,arsize,arburst,arvalid;
			output  arready;
			input	rready;
			output  rid, rdata, rlast,rvalid, rresp,rlen;	
	endclocking

clocking monitor_cb@(posedge aclk);
		default input #1;
			input 	awid,awaddr,awlen,awsize,awburst,awvalid, resetn;
			input  awready,wready;
			input  wid, wdata, wstrb, wlast, wvalid;
			input	bready;
			input  bid, bresp, bvalid;

			input 	arid, araddr,arlen,arsize,arburst,arvalid;
			input  arready;
			input	rready;
			input  rid, rdata, rlast,rvalid, rresp,rlen;	
	endclocking



endinterface

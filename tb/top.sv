module top;
  reg clk;
  reg reset;

  axi_intr pif(.aclk(clk), .resetn(reset));

 mem_assert u_assert(
  .clk     (clk),
  .res     (reset),
  .awvalid (pif.awvalid),
  .awready (pif.awready),
  .awaddr  (pif.awaddr),
  .wvalid  (pif.wvalid),
  .wready  (pif.wready),
  .wdata   (pif.wdata),
  .wlast   (pif.wlast),
  .bvalid  (pif.bvalid),
  .bready  (pif.bready),
  .arvalid (pif.arvalid),
  .arready (pif.arready),
  .araddr  (pif.araddr),
  .rvalid  (pif.rvalid),
  .rready  (pif.rready),
  .rdata   (pif.rdata),
  .rlast   (pif.rlast)
);


initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation
  // Reset goes HIGH first, then LOW after 2 clocks
  // (your interface uses active-low resetn)
  initial begin
    reset = 0;
    repeat(2) @(posedge clk);
    reset = 1;
  end

  // Register interface in resource db
  initial begin
    uvm_resource_db#(virtual axi_intr)::set("GLOBAL", "pif", pif, null);
  end

  // Run test — UVM handles $finish after report_phase
  initial begin
    run_test("test1");
  end

  // Safety timeout — only fires if UVM hangs completely
  // Set to large value so report_phase always runs first
  initial begin
    #500000;
    `uvm_fatal("TOP_TIMEOUT",
      "Simulation exceeded 500us — possible hang in sequence or responder")
  end

  // Waveform dump
  initial begin
    $dumpfile("top.vcd");
    $dumpvars;
  end

endmodule

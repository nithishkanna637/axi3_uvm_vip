module top;
 reg clk;
 reg reset;
  axi_intr pif(.aclk(clk),.resetn(reset)); 
  initial begin
    clk=0;
    forever #5 clk=~clk;
  end
  
  initial begin
    reset=1;
    repeat (2) @(posedge clk);
    reset=0;
  end
 
  initial begin
    uvm_resource_db#(virtual axi_intr)::set("GLOBAL","pif",pif,null);
  end
   	
  initial begin
     run_test("test1");
  end
  initial begin
    #30000;
    $finish;
  end
initial begin
    // Dump waveform
    $dumpfile("top.vcd");
    $dumpvars;
end
endmodule

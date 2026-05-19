class axi_sequence extends uvm_sequence#(axi_tx);
 `uvm_object_utils(axi_sequence)
 `NEW_OBJ
endclass
class axi_wr_rd extends axi_sequence;
 `uvm_object_utils(axi_wr_rd)
 `NEW_OBJ
  int i=1;
  axi_tx tx;
  axi_tx txq[$];  
 task body();
   repeat(`NO_OF_TX) begin
   	`uvm_do_with(req,{req.wr_rd==1'b1;})
     tx=new req;
	 txq.push_back(tx);
     req.print();
   end
   repeat(`NO_OF_TX) begin
      tx=txq.pop_front();
      `uvm_do_with(req,{req.wr_rd==1'b0;
	                    req.tx_id==tx.tx_id;
	                    req.addr==tx.addr;
						req.burst_len==tx.burst_len;
						req.burst_size == tx.burst_size;
                     	req.burst_type == tx.burst_type;})
	  req.print();
	   end
  endtask
 endclass

class axi_wrap extends axi_sequence;
 `uvm_object_utils(axi_wrap)
 `NEW_OBJ
 axi_tx tx1;
 axi_tx txq1[$];
 task body();
   repeat(`NO_OF_TX) begin
     `uvm_do_with(req,{req.wr_rd==1;
	                   req.burst_type==WRAP;
					   req.addr==32'd92;
					   req.burst_len==3;
					   req.burst_size==2;
				})
	  tx1=new req;
	  txq1.push_back(tx1);
	  req.print();
     end
	
	 repeat(`NO_OF_TX) begin
	   tx1=txq1.pop_front();
	   `uvm_do_with(req,{req.wr_rd==1'b0;
	                    req.tx_id==tx1.tx_id;
	                    req.addr==tx1.addr;
						req.burst_len==tx1.burst_len;
						req.burst_size == tx1.burst_size;
						req.burst_type == tx1.burst_type;})
	 end
 endtask
endclass

class axi_incr_burst extends axi_sequence;
  `uvm_object_utils(axi_incr_burst)
  `NEW_OBJ
  axi_tx tx;
  axi_tx txq[$];
  task body();
    repeat(`NO_OF_TX) begin
      `uvm_do_with(req, {req.wr_rd     == 1'b1;
                         req.burst_type == INCR;
                         req.burst_len  inside {3,7,15};
                         req.burst_size == 2;})
      tx = new req;
      txq.push_back(tx);
      req.print();
    end
    repeat(`NO_OF_TX) begin
      tx = txq.pop_front();
      `uvm_do_with(req, {req.wr_rd     == 1'b0;
                         req.tx_id     == tx.tx_id;
                         req.addr      == tx.addr;
                         req.burst_len  == tx.burst_len;
                         req.burst_size == tx.burst_size;
                         req.burst_type == tx.burst_type;})
      req.print();
    end
  endtask
endclass

class axi_fixed_burst extends axi_sequence;
  `uvm_object_utils(axi_fixed_burst)
  `NEW_OBJ
  axi_tx tx;
  axi_tx txq[$];
  task body();
    repeat(`NO_OF_TX) begin
      `uvm_do_with(req, {req.wr_rd     == 1'b1;
                         req.burst_type == FIXED;
                         req.burst_len  == 0;
                         req.burst_size == 2;})
      tx = new req;
      txq.push_back(tx);
      req.print();
    end
    repeat(`NO_OF_TX) begin
      tx = txq.pop_front();
      `uvm_do_with(req, {req.wr_rd     == 1'b0;
                         req.tx_id     == tx.tx_id;
                         req.addr      == tx.addr;
                         req.burst_len  == tx.burst_len;
                         req.burst_size == tx.burst_size;
                         req.burst_type == tx.burst_type;})
      req.print();
    end
  endtask
endclass

class axi_narrow_transfer extends axi_sequence;
  `uvm_object_utils(axi_narrow_transfer)
  `NEW_OBJ
  axi_tx tx;
  axi_tx txq[$];
  task body();
    repeat(`NO_OF_TX) begin
      `uvm_do_with(req, {req.wr_rd     == 1'b1;
                         req.burst_type == INCR;
                         req.burst_size inside {0,1};
                         req.burst_len  inside {3,7};})
      tx = new req;
      txq.push_back(tx);
      req.print();
    end
    repeat(`NO_OF_TX) begin
      tx = txq.pop_front();
      `uvm_do_with(req, {req.wr_rd     == 1'b0;
                         req.tx_id     == tx.tx_id;
                         req.addr      == tx.addr;
                         req.burst_len  == tx.burst_len;
                         req.burst_size == tx.burst_size;
                         req.burst_type == tx.burst_type;})
      req.print();
    end
  endtask
endclass

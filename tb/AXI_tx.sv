typedef enum{FIXED=0,INCR,WRAP,RSVD_BT} burst_type_id;
class axi_tx extends uvm_sequence_item; 
rand bit wr_rd;
rand bit [3:0] tx_id;
rand bit [`addr_width-1:0] addr;
rand bit [`data_width-1:0] dataq[$];
rand bit [3:0] burst_len;
rand bit [2:0] burst_size;
rand burst_type_id burst_type;
rand bit [1:0] respq[$];
rand bit [`strb_width-1:0] strbq[$];
`uvm_object_utils_begin(axi_tx)
   `uvm_field_int(wr_rd,UVM_ALL_ON)
   `uvm_field_int(tx_id,UVM_ALL_ON)
   `uvm_field_int(addr,UVM_ALL_ON)
   `uvm_field_queue_int(dataq,UVM_ALL_ON)
   `uvm_field_int(burst_len,UVM_ALL_ON)
   `uvm_field_int(burst_size,UVM_ALL_ON)
   `uvm_field_enum(burst_type_id,burst_type,UVM_ALL_ON)
   `uvm_field_queue_int(respq,UVM_ALL_ON)
   `uvm_field_queue_int(strbq,UVM_ALL_ON)
 `uvm_object_utils_end

`NEW_OBJ
constraint data_queue{
   (wr_rd==1) -> dataq.size()==burst_len+1;
   (wr_rd==0) -> dataq.size() ==0;
   }
constraint strb_queue{
   (wr_rd==1) -> strbq.size()==burst_len+1;
   (wr_rd==0) -> strbq.size() == 0;
   }
constraint strb_value_queue{
   foreach(strbq[i]){
      soft strbq[i] == 4'hf;
}
}
constraint burst_type_dist {
  burst_type dist {
    2'b00 := 10, 
    2'b01 := 60, 
    2'b10 := 30  
  };
}
constraint wrap_con{
   (burst_type==WRAP) -> burst_len inside {1,3,7,15};
   (burst_type==WRAP) -> addr%(2**burst_size)==0;
   (burst_type==WRAP) -> (addr%((2**burst_size)*(burst_len+1)))!=0;
   (burst_type==WRAP) ->  addr!=0;
   }

constraint burst_type_con{
   burst_type != RSVD_BT;
  // soft burst_type == INCR;
   }

/*constraint burst_len_con{
   soft burst_len == 3;
		 }
*/
/* constraint burst_size_con{
    soft burst_size == 2;
	}
*/
constraint address_dist {
  addr dist {
    32'h0000_0000                      := 100, // Very high weight for single value
    [32'h0000_0001 : 32'h0000_FFFF]    :/ 100, // Range as a whole gets weight 100
    [32'h0001_0000 : 32'hFFFE_FFFF]    :/ 50,  // REDUCE this weight significantly
    [32'hFFFF_0000 : 32'hFFFF_FFFE]    :/ 100, // Range as a whole gets weight 100
    32'hFFFF_FFFF                      := 100  // Very high weight for single value
  };
}
constraint size{
  burst_size dist{
   0 :/ 100,
   1 :/ 100,
   2 :/ 100,
   3 :/ 100,
   4 :/ 100,
   5 :/ 100,
   6 :/ 100,
   7 :/ 100 };
   }
endclass

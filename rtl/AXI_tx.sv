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
constraint wrap_con{
   (burst_type==WRAP) -> burst_len inside {1,3,7,15};
   (burst_type==WRAP) -> addr%(2**burst_size)==0;
   }

constraint burst_type_con{
   burst_type != RSVD_BT;
   soft burst_type == WRAP;
   }

constraint burst_len_con{
     burst_len<16;
	 soft burst_len == 4;
		 }

constraint burst_size_con{
    soft burst_size == 2;
	}
endclass

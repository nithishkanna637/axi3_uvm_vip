vlib work
vlog axi_list.sv +incdir+C:/Users/Nithish/OneDrive/Desktop/AXI_VER_UVM/uvm-1.2/uvm-1.2/src
vsim -novopt -suppress 12110 top -sv_lib C:/questasim64_10.7c/uvm-1.2/win64/uvm_dpi
add wave -r sim:/*
run -all

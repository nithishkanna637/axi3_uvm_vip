vlib work
# 1. Compile with coverage enabled
vlog +cover=bcst axi_list.sv +incdir+C:/Users/Nithish/OneDrive/Desktop/AXI_VER_UVM/uvm-1.2/uvm-1.2/src

# 2. Use voptargs="+acc" for signal visibility and enable coverage
vsim -voptargs="+acc" -coverage top \
     -sv_lib C:/questasim64_10.7c/uvm-1.2/win64/uvm_dpi \
     +SEQ=all_burst

# 3. Add waves BEFORE running
add wave -r /top/*

# 4. Run the simulation
run -all

# 5. Save coverage
coverage save all_burst.ucdb

# 6. COMMENT OUT 'quit' so the window stays open for you to see the waves!
# quit 


# Clean previous build
vlib work

# Compile with coverage and assertion visibility
vlog +cover=bcst +acc \
     axi_list.sv \
     +incdir+C:/Users/Nithish/OneDrive/Desktop/axi_project/uvm-1.2/uvm-1.2/src

# Simulate with coverage and assertion debug enabled
vsim -voptargs="+acc" \
     -coverage \
     -assertdebug \
     top \
     -sv_lib C:/questasim64_10.7c/uvm-1.2/win64/uvm_dpi \
     +SEQ=all_burst

# Add all waves
add wave -r /top/*

# Run simulation
run -all

# Print assertion report — QuestaSim 10.7c correct syntax
assertion report -recursive /top

# Save coverage
coverage save all_burst.ucdb

# Keep window open
# quit

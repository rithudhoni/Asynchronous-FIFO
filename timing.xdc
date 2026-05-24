# 1. Define the Write Clock (e.g., 100 MHz -> 10ns period)
create_clock -period 10.000 -name wclk -waveform {0.000 5.000} [get_ports wclk]

# 2. Define the Read Clock (e.g., 33.33 MHz -> 30ns period)
create_clock -period 30.000 -name rclk -waveform {0.000 15.000} [get_ports rclk]

# 3. The Asynchronous Constraint (Crucial for CDC)
# This tells Vivado's timing engine not to panic when data crosses between these 
# two independent clock domains, because we built synchronizers to handle it.
set_clock_groups -asynchronous -group [get_clocks wclk] -group [get_clocks rclk]
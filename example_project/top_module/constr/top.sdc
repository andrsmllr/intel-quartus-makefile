create_clock [get_ports clock] -name clock -period 5

set_input_delay -clock clock -add_delay -max 2.2 [all_inputs]
set_input_delay -clock clock -add_delay -min 2.2 [all_inputs]

set_output_delay -clock clock -add_delay -max 2.2 [all_outputs]
set_output_delay -clock clock -add_delay -min 2.2 [all_outputs]

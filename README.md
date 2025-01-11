# Time-Multiplexed Non-Linear Operations for Neural Networks on FPGA

## Motivation:
Minimize non-linear operations' utilization on FPGA to maximize resources available for matrix multiplication <br>

## Utilization:
| Name | Slice LUTs | Slice Registers | DSPs |
| ----------- | ----------- | ----------- | ----------- |
| non_lin_ops | 5418 | 1243 | 10 |
| >div_instance | 465 | 179 | 0 |
| >mult_instance | 1199 | 19 | 10 |
| >redor_instance | 23 | 0 | 0 |
| >sqrt_instance | 158 | 129 | 0 |
| >usrmux_instance | 2086 | 0 | 0 |

## Timing: @100MHz
| Setup | Hold | Pulse Width |
| ----------- | ----------- | ----------- |
| WNS: 0.885ns | WHS: 0.271ns | WPWS: 4.500ns |
| TNS: 0.000ns | THS: 0.000ns | TPWS: 0.000ns |

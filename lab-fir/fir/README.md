# FIR - Verilog implementation
This is the working directory for the SOC Design Lab lab 3.
## File Path
* fir.v and other design.v files: rtl/
* fir_tb.v: tb/
* log files: log/
* synthesis report: synthesis
## Interface
-- data_in  stream （Xn）
-- data_out: stream ( Yn)
-- coef[Tape_Num-1:0]  axilite
-- len: axilite
-- ap_start:  axilite
-- ap_done: axilite
- Using one Multiplier and one Adder
- - Shift register implemented with SRAM (Shift_RAM, size = 10 DW) – size = 10 DW
- Tap coefficient implemented with SRAM (Tap_RAM = 11 DW) and initialized by axilite write
Operation
- ap_start to initiate FIR engine (ap_start valid for one clock cycle)
- Stream-in Xn. The rate is depending on the FIR processing speed. Use axi-stream valid/ready for flow control
- Stream out Yn, the output rate depends on FIR processing speed.

![圖片](https://github.com/ZheChen-Bill/lab3_workbook/assets/88698677/b5413f7f-7840-4c4a-85b5-eb66905cc60e)
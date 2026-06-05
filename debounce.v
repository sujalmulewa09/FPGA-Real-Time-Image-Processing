`timescale 1ns / 1ps
`default_nettype none//` is the instruction for the compiler net means wire means connection between two and type refers to the datatype none means off

/*
 *  Filters glitchy inputs by ignoring state changes
 *  that occur within less than DELAY clock ticks 
 *
 *  Registers state change, debounced output, after 
 *  DELAY number of clock ticks of an unchanged input
 *  
 *  NOTE:
 *  DELAY = (Debounce Time [s]) * (i_clk [Hz])
 * 
 */

module debouncer 
#(parameter DELAY = 1_000_000)//if there is no specification in the cam_top than this value is used otherwise the value that is written in the cam_top is used
(
    input wire  i_clk,
    input wire  i_btn_in,
    output wire o_btn_db         
);

    localparam MAX_COUNT = $clog2(DELAY);//c means ceiling and $means These are "super-powers" provided by the Verilog compiler to help you do math or debug your code. 
    reg [MAX_COUNT-1:0] counter;
    reg                 r_sample; // here r means register
    
    initial { counter, r_sample } = 0; 
    
    always @(posedge i_clk)
        begin
            if(i_btn_in !== r_sample && counter < DELAY)//!= Only compares 0 and 1.but the used compares bit by bit
                counter <= counter + 1'b1; 
            else if(counter == DELAY)
                begin
                    counter <= 0;
                    r_sample <= i_btn_in;
                end
            else
                counter <= 0;  
        end 

assign o_btn_db = r_sample;//A Fast Human Tap: Roughly 50 ms to 100 ms 

endmodule


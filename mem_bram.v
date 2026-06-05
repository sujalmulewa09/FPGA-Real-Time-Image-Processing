`timescale 1ns / 1ps
`default_nettype none

/*
 *  Infers a dual-port BRAM with variable width and depth 
 *  
 *  NOTE: 
 *  - One clock delay with read/write
 *
 */

module mem_bram
#(parameter WIDTH = 11,//top module me ise 12 kar diya hai
    parameter DEPTH = 640*480)
    (   input wire                      i_wclk,//this is the input i think directly from the vga
        input wire                      i_wr,//hamesha 1 hai
        input wire [$clog2(DEPTH)-1:0]  i_wr_addr,//this is also decided by the camera capture itself where to send in the b ram
        
        input wire                      i_rclk,//this is comming from the clock_out1 in the clk_wiz
        input wire                      i_rd,//always 1 mtlb hmesha is code ko read hi karna hai
        input wire [$clog2(DEPTH)-1:0]  i_rd_addr,//ye vga top module se aa rha hai .pointing to exactly one of the 307,200 pixels stored in your BRAM.ye input adress pe jo bhi data hoga vo vga top ko milega 
        
        input wire                      i_bram_en,//this is always 1
        input wire [WIDTH-1:0]          i_bram_data,//ye camera capture se aa rha hai
        output reg [WIDTH-1:0]          o_bram_data  //ye sidha vga top ko milega taki shayad vo display kar sake   
    );
    
    // Infer dual-port BRAM with dual clocks
    // https://docs.xilinx.com/v/u/2019.2-English/ug901-vivado-synthesis (page 126)
    reg [WIDTH-1:0] ram [0:DEPTH-1]; 
    
    always @(posedge i_wclk)
    if(i_bram_en)//hamesha run karega ye to
        if(i_wr)//ye bhi hamesha run karega
            ram[i_wr_addr] <= i_bram_data;
    
    always @(posedge i_rclk)
    if(i_rd)// hamesha hi one hai
        o_bram_data <= ram[i_rd_addr]; 

endmodule


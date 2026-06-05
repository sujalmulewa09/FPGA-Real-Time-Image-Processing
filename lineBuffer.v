`timescale 1ns / 1ps

module lineBuffer(
input wire  i_clk,
input wire  i_rst,
input wire [7:0] i_data,
input wire  i_data_valid,
output wire [23:0] o_data,
input wire i_rd_data
);
reg [7:0] line [639:0]; // Updated: line buffer expanded for 640 pixels
reg [9:0] wrPntr;       // Updated: 10 bits to count to 639
reg [9:0] rdPntr;       // Updated: 10 bits to count to 639

always @(posedge i_clk)
begin
    if(i_data_valid)
        line[wrPntr] <= i_data;
end

always @(posedge i_clk) begin
    if(i_rst)
        wrPntr <= 'd0;
    else if(i_data_valid) begin
        if(wrPntr == 639) // Explicit reset for 640 width
            wrPntr <= 'd0;
        else
            wrPntr <= wrPntr + 'd1;
    end
end

assign o_data = {line[rdPntr],line[rdPntr+1],line[rdPntr+2]};

always @(posedge i_clk) begin
    if(i_rst)
        rdPntr <= 'd0;
    else if(i_rd_data) begin
        if(rdPntr == 639) // Explicit reset for 640 width
            rdPntr <= 'd0;
        else
            rdPntr <= rdPntr + 'd1;
    end
end

endmodule
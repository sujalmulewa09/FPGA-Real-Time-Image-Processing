`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Updated to support 12-bit RGB444 input/output utilizing 
//              3 parallel 8-bit processing pipelines.
//////////////////////////////////////////////////////////////////////////////////

module imageProcessTop(
    input wire  axi_clk,
    input  wire  axi_reset_n,
    input wire [2:0] i_kernel_sel,
    //slave interface
    input  wire  i_data_valid,
    input wire [11:0] i_data,          // Updated from 8-bit to 12-bit
    output wire o_data_ready,
    //master interface
    output  wire o_data_valid,
    output wire [15:0] o_data,         // Updated from 8-bit to 12-bit
    input  wire  i_data_ready,
    //interrupt
    output wire  o_intr
);

wire axis_prog_full;
assign o_data_ready = !axis_prog_full;

// 1. Split 12-bit RGB into 4-bit channels and upscale to 8-bit by replication
wire [7:0] i_data_R = {i_data[11:8], i_data[11:8]};
wire [7:0] i_data_G = {i_data[7:4],  i_data[7:4]};
wire [7:0] i_data_B = {i_data[3:0],  i_data[3:0]};

// Interconnect wires for the three parallel pipelines
wire [71:0] pixel_data_R, pixel_data_G, pixel_data_B;
wire pixel_data_valid_R, pixel_data_valid_G, pixel_data_valid_B;
wire intr_R, intr_G, intr_B;

wire [7:0] convolved_data_R, convolved_data_G, convolved_data_B;
wire convolved_data_valid_R, convolved_data_valid_G, convolved_data_valid_B;

// Since all three pipelines process identical coordinate data in lockstep, 
// we only need to route one set of control signals to the top level.
assign o_intr = intr_R;

// ==========================================
// RED CHANNEL PIPELINE
// ==========================================
imageControl IC_R(
    .i_clk(axi_clk),
    .i_rst(!axi_reset_n),
    .i_pixel_data(i_data_R),
    .i_pixel_data_valid(i_data_valid),
    .o_pixel_data(pixel_data_R),
    .o_pixel_data_valid(pixel_data_valid_R),
    .o_intr(intr_R)
);

conv conv_R(
    .i_clk(axi_clk),
    .i_pixel_data(pixel_data_R),
    .i_kernel_sel(i_kernel_sel),
    .i_pixel_data_valid(pixel_data_valid_R),
    .o_convolved_data(convolved_data_R),
    .o_convolved_data_valid(convolved_data_valid_R)
);

// ==========================================
// GREEN CHANNEL PIPELINE
// ==========================================
imageControl IC_G(
    .i_clk(axi_clk),
    .i_rst(!axi_reset_n),
    .i_pixel_data(i_data_G),
    .i_pixel_data_valid(i_data_valid),
    .o_pixel_data(pixel_data_G),
    .o_pixel_data_valid(pixel_data_valid_G),
    .o_intr(intr_G)
);

conv conv_G(
    .i_clk(axi_clk),
    .i_pixel_data(pixel_data_G),
    .i_kernel_sel(i_kernel_sel),
    .i_pixel_data_valid(pixel_data_valid_G),
    .o_convolved_data(convolved_data_G),
    .o_convolved_data_valid(convolved_data_valid_G)
);

// ==========================================
// BLUE CHANNEL PIPELINE
// ==========================================
imageControl IC_B(
    .i_clk(axi_clk),
    .i_rst(!axi_reset_n),
    .i_pixel_data(i_data_B),
    .i_pixel_data_valid(i_data_valid),
    .o_pixel_data(pixel_data_B),
    .o_pixel_data_valid(pixel_data_valid_B),
    .o_intr(intr_B)
);

conv conv_B(
    .i_clk(axi_clk),
    .i_pixel_data(pixel_data_B),
    .i_kernel_sel(i_kernel_sel),
    .i_pixel_data_valid(pixel_data_valid_B),
    .o_convolved_data(convolved_data_B),
    .o_convolved_data_valid(convolved_data_valid_B)
);

// ==========================================
// REPACK TO 12-BIT AND OUTPUT FIFO
// ==========================================
// Downscale by taking the top 4 bits of each processed 8-bit channel
wire [11:0] combined_convolved_data = {convolved_data_R[7:4], convolved_data_G[7:4], convolved_data_B[7:4]};
wire [15:0] padded_convolved_data = {combined_convolved_data,4'b0000};
outputBuffer_1 OB (
   .wr_rst_busy(),        
   .rd_rst_busy(),        
   .s_aclk(axi_clk),                  
   .s_aresetn(axi_reset_n),            
   .s_axis_tvalid(convolved_data_valid_R),  // Use R channel valid (all are synchronous)
   .s_axis_tready(),    
   .s_axis_tdata(padded_convolved_data),  // 12-bit combined data
   .m_axis_tvalid(o_data_valid),    
   .m_axis_tready(i_data_ready),    
   .m_axis_tdata(o_data),                   // 12-bit output [cite: 57]
   .axis_prog_full(axis_prog_full)  
);

endmodule
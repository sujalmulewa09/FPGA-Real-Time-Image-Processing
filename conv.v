`timescale 1ns / 1ps

module conv(
    input wire        i_clk,
    input wire [71:0] i_pixel_data,
    input wire       i_pixel_data_valid,
    input wire [2:0]  i_kernel_sel,       // UPDATED: 3-bit selector for 8 operations
    output reg [7:0] o_convolved_data,
    output reg   o_convolved_data_valid
);

integer i; 
reg signed [7:0] kernel1 [8:0];
reg signed [7:0] kernel2 [8:0];

// --- Sobel Pipeline Registers ---
reg signed [10:0] multData1[8:0];
reg signed [10:0] multData2[8:0];
reg signed [10:0] sumDataInt1;
reg signed [10:0] sumDataInt2;
reg signed [10:0] sumData1;
reg signed [10:0] sumData2;
reg signed [20:0] convolved_data_int1;
reg signed [20:0] convolved_data_int2;
wire signed [21:0] convolved_data_int;

// --- Linear Filter & Original Operation Pipelines ---
reg [7:0] id_d1, id_d2, id_d3;         
reg [7:0] neg_d1, neg_d2, neg_d3;      
reg [7:0] blur_d2, blur_d3;           

// Cycle 1 additions for new kernels
reg signed [12:0] sum_all;
reg signed [12:0] p4_mult9;
reg signed [12:0] p4_mult10;
reg signed [12:0] emboss_pos;
reg signed [12:0] emboss_neg;

// Cycle 2 values
reg signed [13:0] edge_val;
reg signed [13:0] sharp_val;
reg signed [13:0] emboss_val;

// Cycle 3 clamped values
reg [7:0] edge_d3, sharp_d3, emboss_d3;

// Valid & Selector pipeline 
reg v1, v2, v3;
reg [2:0] sel_d1, sel_d2, sel_d3;

// Aliases for 3x3 grid to make math readable
wire [7:0] p0 = i_pixel_data[7:0];
wire [7:0] p1 = i_pixel_data[15:8];
wire [7:0] p2 = i_pixel_data[23:16];
wire [7:0] p3 = i_pixel_data[31:24];
wire [7:0] p4 = i_pixel_data[39:32]; // Center Pixel
wire [7:0] p5 = i_pixel_data[47:40];
wire [7:0] p6 = i_pixel_data[55:48];
wire [7:0] p7 = i_pixel_data[63:56];
wire [7:0] p8 = i_pixel_data[71:64];

initial begin
    // Sobel X kernel
    kernel1[0] =  1; kernel1[1] =  0; kernel1[2] = -1;
    kernel1[3] =  2; kernel1[4] =  0; kernel1[5] = -2;
    kernel1[6] =  1; kernel1[7] =  0; kernel1[8] = -1;
    
    // Sobel Y kernel
    kernel2[0] =  1; kernel2[1] =  2; kernel2[2] =  1;
    kernel2[3] =  0; kernel2[4] =  0; kernel2[5] =  0;
    kernel2[6] = -1; kernel2[7] = -2; kernel2[8] = -1;
end    
    
always @(posedge i_clk) begin
    // ==========================================
    // CYCLE 1: Base Multiplications & Sums
    // ==========================================
    for(i=0; i<9; i=i+1) begin
        multData1[i] <= $signed(kernel1[i]) * $signed({1'b0, i_pixel_data[i*8+:8]});
        multData2[i] <= $signed(kernel2[i]) * $signed({1'b0, i_pixel_data[i*8+:8]});
    end
    
    id_d1  <= p4; 
    neg_d1 <= 8'd255 - p4;
    
    // Sum all 9 pixels for Box Blur, Edge, and Sharpen math
    sum_all <= $signed({1'b0, p0}) + $signed({1'b0, p1}) + $signed({1'b0, p2}) +
               $signed({1'b0, p3}) + $signed({1'b0, p4}) + $signed({1'b0, p5}) +
               $signed({1'b0, p6}) + $signed({1'b0, p7}) + $signed({1'b0, p8});
               
    // Math tricks for Edge & Sharpen kernels
    p4_mult9  <= $signed({1'b0, p4}) * 9;
    p4_mult10 <= $signed({1'b0, p4}) * 10;
    
    // Emboss: [-3, -1, 0; -1, 1, 1; 0, 1, 3]
    emboss_pos <= $signed({1'b0, p4}) + $signed({1'b0, p5}) + $signed({1'b0, p7}) + ($signed({1'b0, p8}) * 3);
    emboss_neg <= ($signed({1'b0, p0}) * 3) + $signed({1'b0, p1}) + $signed({1'b0, p3});
                
    v1 <= i_pixel_data_valid;
    sel_d1 <= i_kernel_sel;
end

always @(*) begin
    sumDataInt1 = 0;
    sumDataInt2 = 0;
    for(i=0; i<9; i=i+1) begin
        sumDataInt1 = $signed(sumDataInt1) + $signed(multData1[i]);
        sumDataInt2 = $signed(sumDataInt2) + $signed(multData2[i]);
    end
end

always @(posedge i_clk) begin
    // ==========================================
    // CYCLE 2: Accumulation & Filtering
    // ==========================================
    sumData1 <= sumDataInt1;
    sumData2 <= sumDataInt2;
    
    id_d2 <= id_d1;
    neg_d2 <= neg_d1;
    blur_d2 <= sum_all / 9; 
    
    // 9*center - sum_all = 8*center - (sum of all others)
    edge_val <= p4_mult9 - sum_all;   
    
    // 10*center - sum_all = 9*center - (sum of all others)
    sharp_val <= p4_mult10 - sum_all; 
    
    // Add 128 offset so emboss is visible on grey background
    emboss_val <= emboss_pos - emboss_neg + 128; 
    
    v2 <= v1;
    sel_d2 <= sel_d1;
end

always @(posedge i_clk) begin
    // ==========================================
    // CYCLE 3: Squaring & Clamping
    // ==========================================
    convolved_data_int1 <= $signed(sumData1) * $signed(sumData1);
    convolved_data_int2 <= $signed(sumData2) * $signed(sumData2);
    
    id_d3 <= id_d2;
    neg_d3 <= neg_d2;
    blur_d3 <= blur_d2;
    
    // Clamp Edge, Sharpen, and Emboss to 0-255 to prevent overflow/underflow artifacts
    edge_d3   <= (edge_val < 0) ? 8'd0 : (edge_val > 255) ? 8'd255 : edge_val[7:0];
    sharp_d3  <= (sharp_val < 0) ? 8'd0 : (sharp_val > 255) ? 8'd255 : sharp_val[7:0];
    emboss_d3 <= (emboss_val < 0) ? 8'd0 : (emboss_val > 255) ? 8'd255 : emboss_val[7:0];
    
    v3 <= v2;
    sel_d3 <= sel_d2;
end

assign convolved_data_int = convolved_data_int1 + convolved_data_int2;

always @(posedge i_clk) begin
    // ==========================================
    // CYCLE 4: Output Multiplexer
    // ==========================================
    if(v3) begin
        case(sel_d3) 
            3'b000: o_convolved_data <= id_d3;              // Original 1: Identity
            3'b001: begin                                   // Original 2: Sobel
                if(convolved_data_int > 4000)
                    o_convolved_data <= 8'hff;
                else
                    o_convolved_data <= 8'h00;
            end
            3'b010: o_convolved_data <= blur_d3;            // Original 3: Box Blur
            3'b011: o_convolved_data <= neg_d3;             // Original 4: Negative
            3'b100: o_convolved_data <= edge_d3;            // New 1: Edge Detection
            3'b101: o_convolved_data <= sharp_d3;           // New 2: Sharpen
            3'b110: o_convolved_data <= emboss_d3;          // New 3: Emboss
            3'b111: o_convolved_data <= id_d3;              // New 4: Identity (Repeated)
            default: o_convolved_data <= 8'h00;
        endcase
    end else begin
        o_convolved_data <= 8'h00;
    end
    o_convolved_data_valid <= v3;
end
    
endmodule

`timescale 1ns / 1ps

`default_nettype none

module top
    (   input wire i_top_clk,
        input wire i_top_rst,
        input wire [2:0] i_kernel_sel,
        
        input wire  i_top_cam_start, 
        output wire o_top_cam_done, 
        
        // I/O to camera
        input wire       i_top_pclk, 
        input wire [7:0] i_top_pix_byte,
        input wire       i_top_pix_vsync,
        input wire       i_top_pix_href,
        output wire      o_top_reset,
        output wire      o_top_pwdn,
        output wire      o_top_xclk,
        output wire      o_top_siod,
        output wire      o_top_sioc,
        
        // I/O to VGA 
        output wire [3:0] o_top_vga_red,
        output wire [3:0] o_top_vga_green,
        output wire [3:0] o_top_vga_blue,
        output wire       o_top_vga_vsync,
        output wire       o_top_vga_hsync
    );
    
    // Connect cam_top/vga_top modules to BRAM
    wire [11:0] i_bram_pix_data,    o_bram_pix_data;
    wire [18:0] i_bram_pix_addr,    o_bram_pix_addr; 
    wire        i_bram_pix_wr;
           
    // Reset synchronizers for all clock domains
    reg r1_rstn_top_clk,    r2_rstn_top_clk;
    reg r1_rstn_pclk,       r2_rstn_pclk;
    reg r1_rstn_clk25m,     r2_rstn_clk25m; 
        
    wire w_clk25m; 
    
    wire        w_cam_pix_wr;       // Valid signal from camera
    wire [11:0] w_cam_pix_data;     // 12-bit data from camera
    
    wire        w_processed_valid;  // Valid signal out of image processor
    wire [15:0] w_processed_data;   // 16-bit padded data out of image processor
    reg  [18:0] r_bram_wr_addr;     // New delayed address counter for BRAM
    
    // Generate clocks for camera and VGA
    clk_wiz_1
    clock_gen
    (
        .clk_in1(i_top_clk          ),
        .clk_out1(w_clk25m          ),
        .clk_out2(o_top_xclk        )
    );
    
    wire w_rst_btn_db; 
    
    // Debounce top level button - invert reset to have debounced negedge reset
    localparam DELAY_TOP_TB = 240_000; //240_000 when uploading to hardware, 10 when simulating in testbench 
    debouncer 
    #(  .DELAY(DELAY_TOP_TB)    )
    top_btn_db
    (
        .i_clk(i_top_clk        ),
        .i_btn_in(~i_top_rst    ),
        .o_btn_db(w_rst_btn_db  )
    ); 
    
    // Double FF for negedge reset synchronization 
    always @(posedge i_top_clk or negedge w_rst_btn_db)
        begin
            if(!w_rst_btn_db) {r2_rstn_top_clk, r1_rstn_top_clk} <= 0; 
            else              {r2_rstn_top_clk, r1_rstn_top_clk} <= {r1_rstn_top_clk, 1'b1}; 
        end 
    always @(posedge w_clk25m or negedge w_rst_btn_db)
        begin
            if(!w_rst_btn_db) {r2_rstn_clk25m, r1_rstn_clk25m} <= 0; 
            else              {r2_rstn_clk25m, r1_rstn_clk25m} <= {r1_rstn_clk25m, 1'b1}; 
        end
    always @(posedge i_top_pclk or negedge w_rst_btn_db)
        begin
            if(!w_rst_btn_db) {r2_rstn_pclk, r1_rstn_pclk} <= 0; 
            else              {r2_rstn_pclk, r1_rstn_pclk} <= {r1_rstn_pclk, 1'b1}; 
        end 
    
cam_top 
    #(  .CAM_CONFIG_CLK(100_000_000)    )
    OV7670_cam
    (
        .i_clk(i_top_clk                ),
        .i_rstn_clk(r2_rstn_top_clk     ),
        .i_rstn_pclk(r2_rstn_pclk       ),
        
        // I/O for camera init
        .i_cam_start(i_top_cam_start    ),
        .o_cam_done(o_top_cam_done      ), 
        
        // I/O camera
        .i_pclk(i_top_pclk              ),
        .i_pix_byte(i_top_pix_byte      ), 
        .i_vsync(i_top_pix_vsync        ), 
        .i_href(i_top_pix_href          ),
        .o_reset(o_top_reset            ),
        .o_pwdn(o_top_pwdn              ),
        .o_siod(o_top_siod              ),
        .o_sioc(o_top_sioc              ), 
        
        // Outputs from camera 
        .o_pix_wr(w_cam_pix_wr          ),      // Connect to intermediate wire
        .o_pix_data(w_cam_pix_data      ),      // Connect to intermediate wire
        .o_pix_addr()                           // LEAVE DISCONNECTED: Latency makes this address invalid for processed data
    );

    // Image Processing Block
    imageProcessTop Process_Image(
        .axi_clk(i_top_pclk),                     // Running on 25MHz as requested
        .axi_reset_n(r2_rstn_pclk),
        .i_kernel_sel(i_kernel_sel),
        // slave interface (From Camera)
        .i_data_valid(w_cam_pix_wr),
        .i_data(w_cam_pix_data),                // 12-bit input
        .o_data_ready(),                        // Ignored: OV7670 doesn't support backpressure
        // master interface (To BRAM)
        .o_data_valid(w_processed_valid),
        .o_data(w_processed_data),              // 16-bit output
        .i_data_ready(1'b1),                    // BRAM is always ready to receive data
        // interrupt
        .o_intr()
    );

    // Generate new BRAM write address synchronized to the processed output
    always @(posedge i_top_pclk or negedge r2_rstn_pclk) begin
        if (!r2_rstn_pclk) begin
            r_bram_wr_addr <= 19'd0;
        end 
        else if (i_top_pix_vsync) begin 
            // VSYNC indicates a new frame is starting. Reset the address counter.
            r_bram_wr_addr <= 19'd0;
        end 
        else if (w_processed_valid) begin
            // Increment address only when the image processor outputs a valid pixel
            r_bram_wr_addr <= r_bram_wr_addr + 19'd1;
        end
    end
    
    mem_bram
    #(  .WIDTH(12                       ), 
        .DEPTH(640*480)                 )
     pixel_memory
     (
        // BRAM Write signals (Now driven by imageProcessTop)
        .i_wclk(i_top_pclk),      // CHANGED: Must match the image processor clock
        .i_wr(w_processed_valid         ),      // Use processed valid signal
        .i_wr_addr(r_bram_wr_addr       ),      // Use newly generated synchronized address
        .i_bram_data(w_processed_data[15:4]),   // Strip the top 4 padding bits, pass the 12-bit RGB
        .i_bram_en(1'b1                 ),
         
         // BRAM Read signals (vga_top)
        .i_rclk(w_clk25m                ),
        .i_rd(1'b1                      ),
        .i_rd_addr(o_bram_pix_addr      ), 
        .o_bram_data(o_bram_pix_data    )
     );
    wire X; 
    wire Y;
    
    vga_top
    display_interface
    (
        .i_clk25m(w_clk25m              ),
        .i_rstn_clk25m(r2_rstn_clk25m   ), 
        
        // VGA timing signals
        .o_VGA_x(X                      ),
        .o_VGA_y(Y                      ), 
        .o_VGA_vsync(o_top_vga_vsync    ),
        .o_VGA_hsync(o_top_vga_hsync    ), 
        .o_VGA_video(                   ),
        
        // VGA RGB Pixel Data
        .o_VGA_red(o_top_vga_red        ),
        .o_VGA_green(o_top_vga_green    ),
        .o_VGA_blue(o_top_vga_blue      ), 
        
        // VGA read/write from/to BRAM
        .i_pix_data(o_bram_pix_data     ), 
        .o_pix_addr(o_bram_pix_addr     )
    );
    
    
endmodule

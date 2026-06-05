`timescale 1ns / 1ps
`default_nettype none 

/*
 *  Instantiates debouncer to debounce cam start initialization button,
 *  cam_init to send cam ROM data to sccb_master, cam_capture to  
 *  sample and output incoming pixel data after cam is done initializing 
 *  based off frame sync signals (i_vsync, i_href)
 *
 */

module cam_top
#(parameter CAM_CONFIG_CLK = 100_000_000)
     (  input wire          i_clk,  //fast internal clk for configuration 
        input wire          i_rstn_clk,//n represent reset when low
        input wire          i_rstn_pclk, //the current frame being written to memory is cleared or restarted
       
        // Start/Done signals for cam init      
        input wire          i_cam_start,//t tells the FPGA: "Okay, start sending all those complex configuration commands to the camera now
        output wire         o_cam_done,//This is the signal that tells the rest of the system that the camera is ready to use.
        
        // I/O camera
        input wire          i_pclk, //pixel clk comming from the camera 
        input wire [7:0]    i_pix_byte, //The 8-bit raw data bus from the camera.
        input wire          i_vsync,//Timing signals. vsync tells you a new frame started; href tells you a new row of pixels is coming.horizontal syncronization
        input wire          i_href,//horizontal reference
        output wire         o_reset,//Hardware pins sent to the camera to keep it awake and out of reset.     
        output wire         o_pwdn,//it means power down       
        output wire         o_siod,//to control brightness, contrast, and RGB format Serial Information clk
        output wire         o_sioc,//to control brightness, contrast, and RGB format Serial Information Output Data
        
        // Outputs to BRA
        output wire         o_pix_wr, //sent to the B RAM, wr means write enable
        output wire [11:0]  o_pix_data,//sent to the B RAM 
        output wire [18:0]  o_pix_addr// sent to the B RAM This tells the BRAM exactly where in its "filing cabinet" to store the current pixel.
    );
    
    assign o_reset = 1;       // 0: reset registers   1: normal mode
    assign o_pwdn  = 0;       // 0: normal mode       1: power down mode
       
    wire       w_start_db;// wire db means debounced means not the nosiy one
        
    debouncer // module name
    #(  .DELAY(240_000)         )
    cam_btn_start_db  
    (   .i_clk(i_clk            ), 
        .i_btn_in(i_cam_start   ), //input comming from the fpga that is dirty signal 
        
        // Debounced button to start cam init 
        .o_btn_db(w_start_db    )// output going which is clean signal
    );
    
    cam_init 
    #(  .CLK_F(CAM_CONFIG_CLK       ), //f means clock frequency
        .SCCB_F(400_000)            ) //serial camera control bus
    configure_cam
    (   .i_clk(i_clk                ),
        .i_rstn(i_rstn_clk          ),
        
        // Start/Done signals for cam init    
        .i_cam_init_start(w_start_db),
        .o_cam_init_done(o_cam_done ),
        
        // SCCB lines
        .o_siod(o_siod              ),
        .o_sioc(o_sioc              ),
        
        // Signals used for testbench
        .o_data_sent_done(          ),
        .o_SCCB_dout(               )
    );
    
    cam_capture
    cam_pixels
    (   // Cam VGA frame timing signals
        .i_pclk(i_pclk         ), 
        .i_vsync(i_vsync       ),
        .i_href(i_href         ),
        
        // Poll for when the cam is done init
        .i_cam_done(o_cam_done ),
        
        .i_D(i_pix_byte        ),
        .o_pix_addr(o_pix_addr ),
        .o_wr(o_pix_wr         ),           
        .o_pix_data(o_pix_data )  
    );
      
endmodule

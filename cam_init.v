`timescale 1ns / 1ps
`default_nettype none

/*
 *  Instantiates cam_rom, cam_config, sccb_master; 
 *  cam_config waits for i_cam_init_start and ready signal 
 *  from sccb_master in order to send data to sccb_master 
 *  
 *
 *  NOTE:
 *  - cam_config reads from a synchronous ROM
 *  - w_cam_rom_data = { OV7670 REG ADDR , OV7670 REG DATA }
 *  - some (unnecessary) signals used in testbench 
 */

module cam_init
#(parameter CLK_F = 100_000_000,//CAM_CONFIG_CLK 
    parameter SCCB_F = 400_000)
    (   input wire      i_clk,
        input wire      i_rstn,      
        input wire      i_cam_init_start,//output going which is clean signal this is one which is debounced one
        output wire     o_siod,//Serial Information Output data
        output wire     o_sioc,//Serial Information Output Clock
        output wire     o_cam_init_done,        
        
        // Signal used only for testbench
        output wire         o_data_sent_done,
        output wire [7:0]   o_SCCB_dout
    );
    
    wire [7:0]  w_cam_rom_addr;//In your Verilog code, w_cam_rom_addr is the "Pointer" signal that tells the ROM which instruction it should send to the configuration module.
    wire [15:0] w_cam_rom_data;//In simple language, the ROM (Read-Only Memory) of the camera is like a "Pre-written Script" or a "Setup Checklist" that the FPGA reads to tell the camera exactly how to behave. 
    wire [7:0]  w_send_addr,    w_send_data;  
    wire        w_start_sccb,   w_ready_sccb; //serial camera control bus
    
    cam_rom 
    OV7670_Registers 
    (   .i_clk(i_clk            ),
        .i_rstn(i_rstn          ), 
        
        .i_addr(w_cam_rom_addr  ),
        .o_dout(w_cam_rom_data  )
    );
    
    cam_config 
    #(  .CLK_F(CLK_F)                   )
    OV7670_config
    (   .i_clk(i_clk                    ),
        .i_rstn(i_rstn                  ),
         
         // Ready/Start signals for SCCB: Poll for ready signal to start sending cam ROM data
        .i_i2c_ready(w_ready_sccb       ),//inter integrated circuit I2C w_ready_sccb if this is 1 than only cam config starts
        .o_i2c_start(w_start_sccb       ),
        
        // Start/Done signals for cam init 
        .i_config_start(i_cam_init_start),
        .o_config_done(o_cam_init_done  ),
        
        // Read through cam ROM
        .i_rom_data(w_cam_rom_data      ),
        .o_rom_addr(w_cam_rom_addr      ),//this output will increase the addr pointr by 1 so that cam_rom code will read 
        .o_i2c_addr(w_send_addr         ),//When you first turn it on, these switches are in a default state that might not work with your FPGA display. 
        .o_i2c_data(w_send_data         ) // You need to "save" (write) a specific set of values into these registers to make the camera "wake up" and send the right kind of video.
    );
      
    sccb_master 
    #(  .CLK_F(CLK_F), 
        .SCCB_F(SCCB_F)         )
    SCCB_HERE 
    (   .i_clk(i_clk            ),
        .i_rstn(i_rstn          ),
        
        // SCCB control signals 
        .i_read(1'b0            ),//fpga need not to read the camera     
        .i_write(1'b1           ),//fpga always want to write to the camera
        .i_start(w_start_sccb   ),//w_start_sccb is only 1 when 16'hFF_FF this is reached on the cam_rom
        .i_restart(1'b0         ),
        .i_stop(1'b0            ),
        .o_ready(w_ready_sccb   ),
        
        // SCCB addr/data signals  
        .i_din(w_send_data      ),//i data in
        .i_addr(w_send_addr     ), 
        
        // Slave->Master com signals 
        .o_dout(o_SCCB_dout     ),      
        .o_done(o_data_sent_done),        
        .o_ack(                 ), //output acknowlegment      
        
        // SCCB Lines
        .io_sda(o_siod          ),// input output serial data     
        .o_scl(o_sioc           )//output serial clk
    );

endmodule
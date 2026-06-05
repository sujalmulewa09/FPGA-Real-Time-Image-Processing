`timescale 1ns / 1ps
`default_nettype none

/*
 *  Parameters set for 25 MHz Pixel Clock, 640 x 480 resolution
 *
 *  Generates VGA vertical/horiztonal sync pulses and outputs
 *  a valid video signal using two counters
 *  
 *  NOTE: 
 *  - Valid video area is asserted/deasserted immediately 
 *          Asserted: 
 *              X -> [0, 639]
 *              Y -> [0, 479]
 *  - Range of X,Y counters are 0-799 and 0-524, respectively
 * 
 */

module vga_driver//It tells the monitor exactly when to "paint" a pixel and when to "reset" the electron beam.
#(parameter hDisp  = 640, //no of pixels in the horizontal direction
    parameter hFp    = 16,//horionatal front porch.A small black gap on the Right Edge of the screen
    parameter hPulse = 96,//horizontal sync porch. Beam snaps back to Left
    parameter hBp    = 48,//horizontal back proch .after the hpulse
    parameter vDisp  = 480,//no of pixel in the horizontal direction
    parameter vFp    = 10,//vertical front porch    
    parameter vPulse = 2,//vertical sync pulse
    parameter vBp    = 33)//vertical back porch 
    (   input wire          i_clk,//this is the clock of the 25 mega hertz comming from the clk wiz clk_out1
        input wire          i_rstn,//ye top ke andar ke code se kahi se aa rha jo ki me bad me dekhunga
        output wire [9:0]   o_x_counter,//ye horizonatal counter hai hc
        output wire [9:0]   o_y_counter,//ye verical counter hai vc
        output wire         o_video,
        output wire         o_hsync,
        output wire         o_vsync
    );
     
     // Horizonal timing     hEND = 800
     localparam hEND        = hDisp + hFp + hPulse + hBp; 
     localparam hSyncStart  = hDisp + hFp;
     localparam hSyncEnd    = hDisp + hFp + hPulse;
             
     // Vertical timing      vEND = 524
     localparam vEND        = vDisp + vFp + vPulse + vBp;
     localparam vSyncStart  = vDisp + vFp;
     localparam vSyncEnd    = vDisp + vFp + vPulse;
     
     reg [9:0] hc;//horizontal counter
     reg [9:0] vc;//vertical counter 
     
     always@(posedge i_clk or negedge i_rstn)
        begin
            if(!i_rstn) begin//agar rst_n 0 hua to sab kuch ko initialize kar denge
                hc      <= 0;
                vc      <= 0;
            end
            else begin
                if(hc == hEND-1)
                begin
                    hc <= 0;
                    if(vc == vEND-1)//ye hone ke liye ofcourse upper wale ko 0 hona hi padega
                    vc <= 0; 
                    else
                        vc <= vc + 1'b1;//ye bhi hEND ke bad hi hoga
                end 
                else
                    hc <= hc + 1'b1; //otherwise ye hoga
            end
        end 
        
     // Output (x,y) coordinates of the pixel and timing signals
     assign o_x_counter = hc;
     assign o_y_counter = vc;
     assign o_video     = ((hc >= 0) && (hc < hDisp) && (vc >= 0)  && (vc < vDisp));//this is for the video from which to which pixel video should run 
     assign o_hsync     = ~((hc >= hSyncStart) && (hc < hSyncEnd));//output giving is hsync is started 
     assign o_vsync     = ~((vc >= vSyncStart) && (vc < vSyncEnd));//output giving vsync is started 
                        
endmodule

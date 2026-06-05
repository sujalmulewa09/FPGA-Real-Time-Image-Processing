`timescale 1ns / 1ps
`default_nettype none

/* 
 *  Polls for when FPGA is done initializing OV7670 and skips first
 *  two VGA frames to allow for the register changes to settle; 
 *  outputs pixel data after 1st byte is registered and 2nd byte is at the 
 *  input; increments pixel address on the same cycle new pixel data is sent
 *
 *
 *   NOTE: 
 *   - For RGB444, format of pixel data 
 *      1st byte: {   X,    X,    X,    X, R[3], R[2], R[1], R[0]}
 *      2nd byte: {G[3], G[2], G[1], G[0], B[3], B[2], B[1], B[0]
 *   
 *   - Format of output pixel data:
 *      o_pix_data = {RRRR GGGG BBBB};
 *
 */

module cam_capture
    (   input wire         i_pclk,//is coming from the camera into the FPGA.but how can camera generate the clk the anwer is first fpga send a clk to the camera and than camera slows or fast that partcular clk 
        input wire         i_vsync,//input is comming from the camera It tells the FPGA exactly when one full frame of an image ends and the next one begins.
        input wire         i_href, //same input is comming from the camera   
        input wire  [7:0]  i_D,//i think this also direcly comming to the camera
        input wire         i_cam_done,//this comes from the camera init i think this is telling that camera intilization is all done
        output reg  [18:0] o_pix_addr, 
        output reg  [11:0] o_pix_data,      
        output reg         o_wr                   
    );
       
    // Negative/Positive Edge Detection of vsync for frame start/frame done signal
    reg         r1_vsync,    r2_vsync; 
    wire        frame_start, frame_done;
    
    initial { r1_vsync, r2_vsync } = 0; 
    always @(posedge i_pclk)
            {r2_vsync, r1_vsync} <= {r1_vsync, i_vsync}; 
  
    assign frame_start = (r1_vsync == 0) && (r2_vsync == 1);    // Negative Edge of vsync
    assign frame_done  = (r1_vsync == 1) && (r2_vsync == 0);    // Positive Edge of vsync
     
    // FSM for capturing pixel data in pclk domain
    localparam [1:0] WAIT   = 2'd0,
                     IDLE   = 2'd1,
                     CAPTURE = 2'd2;
    
    reg        r_half_data;             
    reg [1:0]  SM_state;
    reg [3:0]  pixel_data;
                                                                         
    always @(posedge i_pclk)
        begin
            r_half_data         <= 0;
            o_wr                <= 0;
            o_pix_data          <= o_pix_data;  
            o_pix_addr          <= o_pix_addr;
            SM_state            <= WAIT;    // hamesha hi yhi state rahegi but nhi kyunki bad wali sarvamanya hogi
            case(SM_state)
                WAIT: 
                    begin
                        // Skip the first two frames on start-up
                        SM_state    <= (frame_start && i_cam_done) ? IDLE : WAIT;//agar camera ka initilization ho jaye and than frame start ho jaye to idle pe jana hai otherwise wait karte rho
                    end
                IDLE:        
                    begin
                        SM_state   <= (frame_start) ? CAPTURE : IDLE;//agar fromae start nhi hai to capture nhi karna hai
                        o_pix_addr <= 0;
                        o_pix_data <= 0; 
                    end
                CAPTURE:
                    begin
                        SM_state   <= (frame_done) ? IDLE : CAPTURE;//agar frame done hai to idle pe jao otherwise capture karte raho
                        o_pix_addr <= (r_half_data) ? o_pix_addr + 1'b1 : o_pix_addr;  //initially to false hi hoga 
                        if(i_href)//input camera se aayega
                            begin 
                                 // Register first byte
                                 if(!r_half_data)   //initially zero hi hoga
                                    pixel_data <= i_D[3:0];  //keval last ke 4 bit hi store kiye out of 8 bit    
                                 r_half_data    <= ~r_half_data; //yha par r half data 1 ho jayega                      
                                 o_wr           <= (r_half_data) ? 1'b1 : 1'b0;//1 if upper wala already 0 hai to
                                 o_pix_data     <= (r_half_data) ? {pixel_data, i_D} : o_pix_data; //if r_half_data is 0 than o_pix_data is sended
                            end 
                    end  
            endcase
        end
             
endmodule

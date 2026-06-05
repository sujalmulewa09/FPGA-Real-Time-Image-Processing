`timescale 1ns / 1ps
`default_nettype none

module cam_rom
    (   input wire        i_clk,
        input wire        i_rstn,
        input wire  [7:0] i_addr,
        output reg [15:0] o_dout
    );
    
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) o_dout <= 0; 
        else begin 
            case(i_addr)
            0:  o_dout <= 16'h12_80;  
            1:  o_dout <= 16'hFF_F0;  
            2:  o_dout <= 16'h12_04;  
            3:  o_dout <= 16'h11_00;  
            4:  o_dout <= 16'h0C_00;  
            5:  o_dout <= 16'h3E_00;  
            6:  o_dout <= 16'h04_00;  
            7:  o_dout <= 16'h8C_02;  
            8:  o_dout <= 16'h40_D0;  
            9:  o_dout <= 16'h3a_04;  
            10: o_dout <= 16'h14_18;  
            11: o_dout <= 16'h4F_B3;  
            12: o_dout <= 16'h50_B3;  
            13: o_dout <= 16'h51_00;  
            14: o_dout <= 16'h52_3d;  
            15: o_dout <= 16'h53_A7;  
            16: o_dout <= 16'h54_E4;  
            17: o_dout <= 16'h58_9E;  
            18: o_dout <= 16'h3D_C0;  
            19: o_dout <= 16'h17_14;  
            20: o_dout <= 16'h18_02;  
            21: o_dout <= 16'h32_80;  
            22: o_dout <= 16'h19_03;  
            23: o_dout <= 16'h1A_7B;  
            24: o_dout <= 16'h03_0A;  
            25: o_dout <= 16'h0F_41;  
            26: o_dout <= 16'h1E_00;  
            27: o_dout <= 16'h33_0B;  
            28: o_dout <= 16'h3C_78;  
            29: o_dout <= 16'h69_00;  
            30: o_dout <= 16'h74_00;  
            31: o_dout <= 16'hB0_84;  
            32: o_dout <= 16'hB1_0c;  
            33: o_dout <= 16'hB2_0e;  
            34: o_dout <= 16'hB3_80;  
            35: o_dout <= 16'h70_3a;  
            36: o_dout <= 16'h71_35;  
            37: o_dout <= 16'h72_11;  
            38: o_dout <= 16'h73_f0;  
            39: o_dout <= 16'ha2_02;  
            40: o_dout <= 16'h7a_20;  
            41: o_dout <= 16'h7b_10;  
            42: o_dout <= 16'h7c_1e;  
            43: o_dout <= 16'h7d_35;  
            44: o_dout <= 16'h7e_5a;  
            45: o_dout <= 16'h7f_69;  
            46: o_dout <= 16'h80_76;  
            47: o_dout <= 16'h81_80;  
            48: o_dout <= 16'h82_88;  
            49: o_dout <= 16'h83_8f;  
            50: o_dout <= 16'h84_96;  
            51: o_dout <= 16'h85_a3;  
            52: o_dout <= 16'h86_af;  
            53: o_dout <= 16'h87_c4;  
            54: o_dout <= 16'h88_d7;  
            55: o_dout <= 16'h89_e8;  
            56: o_dout <= 16'h13_e0;  
            57: o_dout <= 16'h00_00;  
            58: o_dout <= 16'h10_00;  
            59: o_dout <= 16'h0d_40;  
            60: o_dout <= 16'h14_18;  
            61: o_dout <= 16'ha5_05;  
            62: o_dout <= 16'hab_07;  
            63: o_dout <= 16'h24_95;  
            64: o_dout <= 16'h25_33;  
            65: o_dout <= 16'h26_e3;  
            66: o_dout <= 16'h9f_78;  
            67: o_dout <= 16'ha0_68;  
            68: o_dout <= 16'ha1_03;  
            69: o_dout <= 16'ha6_d8;  
            70: o_dout <= 16'ha7_d8;  
            71: o_dout <= 16'ha8_f0;  
            72: o_dout <= 16'ha9_90;  
            73: o_dout <= 16'haa_94;  
            74: o_dout <= 16'h13_a7;  
            75: o_dout <= 16'h69_06;     
            default: o_dout <= 16'hFF_FF;         
            endcase
        end
    end
endmodule

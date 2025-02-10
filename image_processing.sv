//========================================================================
// Combined Image Processing Module with Convolution Filter
//========================================================================
`timescale 1ns/1ps

//=========================================================================
// Module: image processing
// Description:
//   Accepts a pixel stream (with associated X/Y counters and data-valid)
//   converts the RGB pixel into a gray value, delays the stream through
//   two line–buffers to form a 3×3 neighborhood and then applies a 
//   convolution filter (e.g., a Sobel filter). The absolute–value of the
//   convolution result is used to generate an edge–detected output.
//   The parameter iSW selects (for example) horizontal vs vertical filtering.
//=========================================================================
module image_processing(
    output [11:0] oGrey_R,
    output [11:0] oGrey_G,
    output [11:0] oGrey_B,
    output        oDVAL,
    input  [10:0] iX_Cont,
    input  [10:0] iY_Cont,
    input  [11:0] iDATA,
    input         iDVAL,
    input         iCLK,
    input         iRST,
    input         iSW
);

    // Internal signals for the raw RGB-to-gray conversion (using a simple average)
    // and for the line buffer(s) used to create the 3x3 window.
    wire [11:0] oRed;
    wire [11:0] oGreen;
    wire [11:0] oBlue;
    wire [11:0] oGrey;  // intermediate gray value computed from RGB
    
    // We will drive the three output channels (R, G, and B) with the convolution result.
    // (They can be the same if you want a monochrome edge image.)
    // In this example the convolution output is stored in 'y', then made positive (abs_y)
    // and then masked at image edges.
    wire [11:0] y;
    wire [11:0] abs_y;
    wire [11:0] out_y;
    
    // These signals come from the first line buffer
    wire [11:0] mDATA_0;
    wire [11:0] mDATA_1;
    
    // These signals come from the second (3-tap) line buffer for convolution.
    // (The second line buffer supplies 3 taps from a delayed version of oGrey.)
    wire [11:0] cDATA_0;
    wire [11:0] cDATA_1;
    wire [11:0] cDATA_2;
    
    // Delay registers for the outputs of the first line buffer.
    reg [11:0] mDATAd_0;
    reg [11:0] mDATAd_1;
    
    // Registers for delaying the 3-tap outputs (so that the 3x3 window is formed).
    reg [11:0] cDATAd_0;
    reg [11:0] cDATAd_1;
    reg [11:0] cDATAd_2;
    
    reg [11:0] cDATAdd_0;
    reg [11:0] cDATAdd_1;
    reg [11:0] cDATAdd_2;
    
    // Registers to create an RGB combination from the line buffer data.
    reg [11:0] mCCD_R;
    reg [12:0] mCCD_G;
    reg [11:0] mCCD_B;
    reg        mDVAL;
    
    // The raw RGB values (from the CCD processing) are available here.
    assign oRed   = mCCD_R;
    assign oGreen = mCCD_G[12:1];
    assign oBlue  = mCCD_B;
    
    // Generate the gray value.
    // (This example uses a weighted average by adding green twice.)
    assign oGrey = (oRed + oGreen + oGreen + oBlue) / 4;
    
    // In this design the final convolution result (after absolute value)
    // is used for all three output channels.
    assign oGrey_R = out_y;
    assign oGrey_G = out_y;
    assign oGrey_B = out_y;
    
    assign oDVAL = mDVAL;
    
    // -------------------------------------------------------------------
    // First Line Buffer (Line_Buffer1)
    // This module delays the incoming pixel stream to form two taps.
    // (You must have a Line_Buffer1 module in your project.)
    Line_Buffer1 u0 (
        .clken(iDVAL),
        .clock(iCLK),
        .shiftin(iDATA),
        .taps0x(mDATA_1),
        .taps1x(mDATA_0)
    );
    
    // -------------------------------------------------------------------
    // Second Line Buffer for Convolution (Line_Buffer2)
    // This module is assumed to provide 3 taps from a delayed version of oGrey.
    // (Again, you must provide an implementation of Line_Buffer2.)
    Line_Buffer2 u1 (
        .clken(mDVAL),
        .clock(iCLK),
        .shiftin(oGrey),
        .taps0x(cDATA_0),
        .taps1x(cDATA_1),
        .taps2x(cDATA_2)
    );
    
    // -------------------------------------------------------------------
    // Convolution Filter Module
    // This module is combinational and implements a 3x3 convolution.
    // The parameter iSW selects horizontal (when high) versus vertical (when low)
    // filtering (i.e. different coefficient sets).
    Convolution_Filter conv_filter (
        .clk(iCLK),
        .isHorz(iSW),
        // X_p0 = top-left, X_p1 = top-center, X_p2 = top-right,
        // X_p3 = middle-left, X_p4 = center,    X_p5 = middle-right,
        // X_p6 = bottom-left, X_p7 = bottom-center, X_p8 = bottom-right.
        // In this example the delays from the line buffers are arranged as:
        //   X_p0 = cDATAdd_2, X_p1 = cDATAd_2, X_p2 = cDATA_2,
        //   X_p3 = cDATAdd_1, X_p4 = cDATAd_1, X_p5 = cDATA_1,
        //   X_p6 = cDATAdd_0, X_p7 = cDATAd_0, X_p8 = cDATA_0.
        .X_p0(cDATAdd_2),
        .X_p1(cDATAd_2),
        .X_p2(cDATA_2),
        .X_p3(cDATAdd_1),
        .X_p4(cDATAd_1),
        .X_p5(cDATA_1),
        .X_p6(cDATAdd_0),
        .X_p7(cDATAd_0),
        .X_p8(cDATA_0),
        .y(y)
    );
    
    // -------------------------------------------------------------------
    // Absolute Value Module
    // (Converts the signed convolution result into a positive value.)
    Abs a1 (
        .in(y),
        .out(abs_y)
    );
    
    // Mask out edge pixels that do not have a valid 3x3 neighborhood.
    // (For example, only output the convolution result if the X/Y counters
    //  are within a safe range.)
    assign out_y = ((iX_Cont > 9) && (iX_Cont < 1270) &&
                    (iY_Cont > 9) && (iY_Cont < 940)) ? abs_y : 12'b0;
                    
    // -------------------------------------------------------------------
    // Delay registers for the line-buffer outputs.
    // (These registers help to align the data so that the 3x3 window is valid.)
    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            mCCD_R    <= 0;
            mCCD_G    <= 0;
            mCCD_B    <= 0;
            mDATAd_0  <= 0;
            mDATAd_1  <= 0;
            cDATAd_0  <= 0;
            cDATAd_1  <= 0;
            cDATAd_2  <= 0;
            cDATAdd_0 <= 0;
            cDATAdd_1 <= 0;
            cDATAdd_2 <= 0;
            mDVAL     <= 0;
        end else begin
            mDATAd_0  <= mDATA_0;
            mDATAd_1  <= mDATA_1;
            // Delay for convolution line buffer taps.
            cDATAd_0  <= cDATA_0;
            cDATAd_1  <= cDATA_1;
            cDATAd_2  <= cDATA_2;
            cDATAdd_0 <= cDATAd_0;
            cDATAdd_1 <= cDATAd_1;
            cDATAdd_2 <= cDATAd_2;
            mDVAL     <= ({iY_Cont[0], iX_Cont[0]} == 2'b00) ? iDVAL : 1'b0;
            
            // Generate the CCD RGB values based on the least–significant bits
            // of the X and Y counters (this is one method to reassemble the Bayer data).
            if ({iY_Cont[0], iX_Cont[0]} == 2'b10) begin
                mCCD_R <= mDATA_0;
                mCCD_G <= mDATAd_0 + mDATA_1;
                mCCD_B <= mDATAd_1;
            end else if ({iY_Cont[0], iX_Cont[0]} == 2'b11) begin
                mCCD_R <= mDATAd_0;
                mCCD_G <= mDATA_0 + mDATAd_1;
                mCCD_B <= mDATA_1;
            end else if ({iY_Cont[0], iX_Cont[0]} == 2'b00) begin
                mCCD_R <= mDATA_1;
                mCCD_G <= mDATA_0 + mDATAd_1;
                mCCD_B <= mDATAd_0;
            end else if ({iY_Cont[0], iX_Cont[0]} == 2'b01) begin
                mCCD_R <= mDATAd_1;
                mCCD_G <= mDATAd_0 + mDATA_1;
                mCCD_B <= mDATA_0;
            end
        end
    end

endmodule

//=========================================================================
// Module: Convolution_Filter
// Description:
//   A combinational 3x3 convolution filter. The 9 inputs represent the
//   pixels of a 3x3 window (ordered as follows):
//
//     X_p0   X_p1   X_p2
//     X_p3   X_p4   X_p5
//     X_p6   X_p7   X_p8
//
//   The parameter isHorz selects between two sets of convolution
//   coefficients (for example, for horizontal vs. vertical edge detection).
//=========================================================================
module Convolution_Filter (
    input                  clk,
    input                  isHorz,
    input  signed [11:0]   X_p0,  // Top-left
    input  signed [11:0]   X_p1,  // Top-center
    input  signed [11:0]   X_p2,  // Top-right
    input  signed [11:0]   X_p3,  // Middle-left
    input  signed [11:0]   X_p4,  // Center
    input  signed [11:0]   X_p5,  // Middle-right
    input  signed [11:0]   X_p6,  // Bottom-left
    input  signed [11:0]   X_p7,  // Bottom-center
    input  signed [11:0]   X_p8,  // Bottom-right
    output signed [11:0]   y
);

    // Convolution kernel coefficients based on edge direction
    wire signed [11:0] COEFF [8:0];

    assign COEFF[0] = -12'd1;
    assign COEFF[1] = isHorz ? -12'd2 :  12'd0;
    assign COEFF[2] = isHorz ? -12'd1 :  12'd1;
    assign COEFF[3] = isHorz ?  12'd0 : -12'd2;
    assign COEFF[4] =  12'd0;
    assign COEFF[5] = isHorz ?  12'd0 :  12'd2;
    assign COEFF[6] =  12'd1;
    assign COEFF[7] = isHorz ?  12'd2 :  12'd0;
    assign COEFF[8] =  12'd1;

    // Compute convolution using multiply-accumulate
    assign y = (X_p0 * COEFF[8]) + (X_p1 * COEFF[7]) + (X_p2 * COEFF[6]) +
               (X_p3 * COEFF[5]) + (X_p4 * COEFF[4]) + (X_p5 * COEFF[3]) +
               (X_p6 * COEFF[2]) + (X_p7 * COEFF[1]) + (X_p8 * COEFF[0]);

endmodule

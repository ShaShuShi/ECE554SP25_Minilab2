// ============================================================================
// RAW2GRAY.v
// ----------------------------------------------------------------------------
// This module converts raw Bayer-pattern data into a grayscale pixel.
// It first instantiates the RAW2RGB module (which performs the Bayer to RGB
// conversion) and then computes a grayscale value by averaging the red,
// green, and blue channels. The grayscale value is output as a 12-bit number.
// 
// ============================================================================

module RAW2GRAY(
    // Inputs (same as RAW2RGB)
    input  [10:0] iX_Cont,    // X coordinate (pixel counter)
    input  [10:0] iY_Cont,    // Y coordinate (pixel counter)
    input  [11:0] iDATA,      // Raw pixel data from sensor (Bayer format)
    input         iDVAL,      // Data valid signal
    input         iCLK,       // Clock
    input         iRST,       // Active-low reset
    // Outputs
    output reg [11:0] oGray,  // Grayscale pixel value (12-bit)
    output reg        oDVAL   // Grayscale data valid
);

    // ------------------------------------------------------------------------
    // Internal wires to capture the outputs of the RAW2RGB module.
    // ------------------------------------------------------------------------
    wire [11:0] red;
    wire [11:0] green;
    wire [11:0] blue;
    wire        rgb_dval;

    // ------------------------------------------------------------------------
    // Instance: RAW2RGB
    // This module converts the Bayer data into separate R, G, and B channels.
    // ------------------------------------------------------------------------
    RAW2RGB u_raw2rgb (
        .iX_Cont(iX_Cont),
        .iY_Cont(iY_Cont),
        .iDATA(iDATA),
        .iDVAL(iDVAL),
        .iCLK(iCLK),
        .iRST(iRST),
        .oRed(red),
        .oGreen(green),
        .oBlue(blue),
        .oDVAL(rgb_dval)
    );

    // ------------------------------------------------------------------------
    // Grayscale Conversion
    //
    // The simplest method is to average the three color channels:
    //     grayscale = (red + green + blue) / 3
    //
    // This block registers the grayscale value on the rising edge of iCLK.
    // ------------------------------------------------------------------------
    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            oGray <= 12'd0;
            oDVAL <= 1'b0;
        end else begin
            if (rgb_dval) begin
                oGray <= (red + green + blue) / 4;
                oDVAL <= 1'b1;
            end else begin
                oDVAL <= 1'b0;
            end
        end
    end

endmodule

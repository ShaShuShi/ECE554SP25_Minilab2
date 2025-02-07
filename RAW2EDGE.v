
// ============================================================================
// RAW2EDGE.v
// ----------------------------------------------------------------------------
// This module converts raw Bayer-pattern data into a grayscale pixel.
// It first instantiates the RAW2RGB module (which performs the Bayer to RGB
// conversion) and then computes a grayscale value by averaging the red,
// green, and blue channels. The grayscale value is output as a 12-bit number.
// 
// ============================================================================

module RAW2EDGE(
    // Inputs (same as RAW2RGB)
    input  [10:0] iX_Cont,    // X coordinate (pixel counter)
    input  [10:0] iY_Cont,    // Y coordinate (pixel counter)
    input  [11:0] iDATA,      // Raw pixel data from sensor (Bayer format)
    input         iDVAL,      // Data valid signal
    input         iCLK,       // Clock
    input         iRST,       // Active-low reset
    // Outputs
    output reg [11:0] oEdge,  // Grayscale pixel value (12-bit)
    output reg        oDVAL   // Grayscale data valid
);

    // ------------------------------------------------------------------------
    // Internal wires to capture the outputs of the RAW2RGB module.
    // ------------------------------------------------------------------------
    wire [11:0] gray;
    wire        rgb_dval;
   

    // ------------------------------------------------------------------------
    // Instance: RAW2RGB
    // This module converts the Bayer data into separate R, G, and B channels.
    // ------------------------------------------------------------------------
    RAW2GRAY u_raw2gray (
        .iX_Cont(iX_Cont),
        .iY_Cont(iY_Cont),
        .iDATA(iDATA),
        .iDVAL(iDVAL),
        .iCLK(iCLK),
        .iRST(iRST),
        .oGray(gray),
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
            oEdge <= 12'd0;
            oDVAL <= 1'b0;
        end else begin
            if (rgb_dval) begin
                oEdge <= 
                oDVAL <= 1'b1;
            end else begin
                oDVAL <= 1'b0;
            end
        end
    end

endmodule
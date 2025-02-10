module RAW2GRAY( oGrey,         // Output grayscale value
                oGrey_R,      // Output grayscale value (Red channel reference)
                oGrey_B,      // Output grayscale value (Blue channel reference)
                oDVAL,        // Output data valid signal
                iX_Cont,      // Input X coordinate of pixel
                iY_Cont,      // Input Y coordinate of pixel
                iDATA,        // Input raw pixel data
                iDVAL,        // Input data valid signal
                iCLK,         // Input clock signal
                iRST          // Input reset signal
                );

// Input and output declarations
input   [10:0]  iX_Cont;      // 11-bit input: X coordinate of pixel
input   [10:0]  iY_Cont;      // 11-bit input: Y coordinate of pixel
input   [11:0]  iDATA;        // 12-bit input: Raw pixel data
input           iDVAL;        // 1-bit input: Data valid signal
input           iCLK;         // 1-bit input: Clock signal
input           iRST;         // 1-bit input: Reset signal

// Intermediate wires for color extraction
wire    [11:0]  oRed;         // 12-bit wire: Extracted red component
wire    [11:0]  oGreen;       // 12-bit wire: Extracted green component
wire    [11:0]  oBlue;        // 12-bit wire: Extracted blue component

// Output grayscale values
output  [11:0]  oGrey;        // 12-bit output: Computed grayscale value
output  [11:0]  oGrey_R;      // 12-bit output: Grayscale value for Red reference
output  [11:0]  oGrey_B;      // 12-bit output: Grayscale value for Blue reference

output          oDVAL;        // 1-bit output: Data valid signal

// Intermediate buffer wires
wire    [11:0]  mDATA_0;      // 12-bit wire: First buffered data tap
wire    [11:0]  mDATA_1;      // 12-bit wire: Second buffered data tap

// Registers to store pixel values
reg     [11:0]  mDATAd_0;     // 12-bit register: Delayed version of mDATA_0
reg     [11:0]  mDATAd_1;     // 12-bit register: Delayed version of mDATA_1
reg     [11:0]  mCCD_R;       // 12-bit register: Red component storage
reg     [12:0]  mCCD_G;       // 13-bit register: Green component storage
reg     [11:0]  mCCD_B;       // 12-bit register: Blue component storage
reg             mDVAL;        // 1-bit register: Data valid signal storage

// Assign extracted color components to outputs
assign  oRed   =  mCCD_R[11:0];        // Extract red component
assign  oGreen =  mCCD_G[12:1];        // Extract green component (divide by 2)
assign  oBlue  =  mCCD_B[11:0];        // Extract blue component

// Compute grayscale value using weighted sum
// Grayscale = (Red + 2*Green + Blue) / 4
assign  oGrey   = (oRed + oGreen + oGreen + oBlue) / 4;   
assign  oGrey_R = oGrey;   // Duplicate grayscale output for Red channel reference
assign  oGrey_B = oGrey;   // Duplicate grayscale output for Blue channel reference

// Assign data valid output
assign  oDVAL   = mDVAL;

// Line buffer instantiation for storing pixel data
Line_Buffer1 u0 (
    .clken(iDVAL),
    .clock(iCLK),
    .shiftin(iDATA),
    .taps0x(mDATA_1),
    .taps1x(mDATA_0)
);

// Sequential process for computing pixel values
always@(posedge iCLK or negedge iRST)
begin
    if(!iRST) // Reset condition
    begin
        mCCD_R   <= 0;
        mCCD_G   <= 0;
        mCCD_B   <= 0;
        mDATAd_0 <= 0;
        mDATAd_1 <= 0;
        mDVAL    <= 0;
    end
    else
    begin
        // Store previous cycle's data
        mDATAd_0 <= mDATA_0;
        mDATAd_1 <= mDATA_1;

        // Only set valid data when both X and Y coordinates are even
        mDVAL    <= {iY_Cont[0] | iX_Cont[0]} ? 1'b0 : iDVAL;

        // Bayer pattern interpolation based on pixel location
        case({iY_Cont[0], iX_Cont[0]})
            2'b10: // Red pixel location
            begin
                mCCD_R   <= mDATA_0;
                mCCD_G   <= mDATAd_0 + mDATA_1;
                mCCD_B   <= mDATAd_1;
            end 
            2'b11: // Green pixel location (G at R row)
            begin
                mCCD_R   <= mDATAd_0;
                mCCD_G   <= mDATA_0 + mDATAd_1;
                mCCD_B   <= mDATA_1;
            end
            2'b00: // Green pixel location (G at B row)
            begin
                mCCD_R   <= mDATA_1;
                mCCD_G   <= mDATA_0 + mDATAd_1;
                mCCD_B   <= mDATAd_0;
            end
            2'b01: // Blue pixel location
            begin
                mCCD_R   <= mDATAd_1;
                mCCD_G   <= mDATAd_0 + mDATA_1;
                mCCD_B   <= mDATA_0;
            end
        endcase
    end
end

endmodule
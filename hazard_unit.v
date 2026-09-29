module hazard_unit(
    input rst, 
    input RegWriteM, 
    input RegWriteW, 
    input [4:0] RD_M, 
    input [4:0] RD_W, 
    input [4:0] Rs1_E, 
    input [4:0] Rs2_E, 
    input mispredict_E,

    output [1:0] ForwardAE, 
    output [1:0] ForwardBE,
    output flush
);

    assign ForwardAE = (rst == 1'b0) ? 2'b00 : 
                       ((RegWriteM == 1'b1) & (RD_M != 5'h00) & (RD_M == Rs1_E)) ? 2'b10 :
                       ((RegWriteW == 1'b1) & (RD_W != 5'h00) & (RD_W == Rs1_E)) ? 2'b01 : 2'b00;
                       
    assign ForwardBE = (rst == 1'b0) ? 2'b00 : 
                       ((RegWriteM == 1'b1) & (RD_M != 5'h00) & (RD_M == Rs2_E)) ? 2'b10 :
                       ((RegWriteW == 1'b1) & (RD_W != 5'h00) & (RD_W == Rs2_E)) ? 2'b01 : 2'b00;
                       
    assign flush = mispredict_E;
endmodule

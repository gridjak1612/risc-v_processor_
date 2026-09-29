module pipeline_top(input clk, input rst);

    wire [31:0] InstrD, PCD, PCPlus4D;
    wire predicted_takenD;
    wire [7:0] bht_indexD;
    wire [31:0] predicted_targetD;
    
    wire RegWriteE, ALUSrcE, MemWriteE, ResultSrcE;
    wire [2:0] ALUControlE;
    wire [31:0] RD1_E, RD2_E, Imm_Ext_E;
    wire [4:0] RD_E;
    wire [31:0] PCE, PCPlus4E;
    wire [4:0] RS1_E, RS2_E;
    wire predicted_takenE;
    wire [7:0] bht_indexE;
    wire [31:0] predicted_targetE;
    
    wire RegWriteM, MemWriteM, ResultSrcM;
    wire [4:0] RD_M;
    wire [31:0] PCPlus4M, WriteDataM, ALU_ResultM;
    
    wire branch_takenE;
    wire [31:0] branch_targetE;
    wire mispredict_E;
    wire [31:0] corrected_PCE;
    wire update_BHT;
    wire [7:0] bht_indexE_out;
    
    wire [1:0] ForwardAE, ForwardBE;
    wire flush;
    
    // Writeback signals
    wire RegWriteW;
    wire [4:0] RDW;
    wire [31:0] ResultW;
    wire [31:0] ReadDataW;
    wire [31:0] ALU_ResultW;
    wire [31:0] PCPlus4W;
    wire ResultSrcW;
    
    // Memory to Writeback Registers
    reg RegWriteW_r, ResultSrcW_r;
    reg [4:0] RDW_r;
    reg [31:0] ReadDataW_r, ALU_ResultW_r, PCPlus4W_r;
    
    // Writeback Mux
    assign ResultW = (ResultSrcW == 1'b0) ? ALU_ResultW : ReadDataW;
    
    // Fetch Stage
    fetch_cycle fetch_inst (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .branch_targetE(branch_targetE), 
        .corrected_PCE(corrected_PCE),
        .branch_takenE(branch_takenE),
        .bht_indexE(bht_indexE_out),
        .update_BHT(update_BHT),
        
        .InstrD(InstrD),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D),
        .predicted_takenD(predicted_takenD),
        .bht_indexD(bht_indexD),
        .predicted_targetD(predicted_targetD)
    );

    // Decode Stage
    decode_cycle decode_inst (
        .clk(clk),
        .rst(rst),
        .InstrD(InstrD),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D),
        .RegWriteW(RegWriteW),
        .RDW(RDW),
        .ResultW(ResultW),
        .flush(flush),
        .predicted_takenD(predicted_takenD),
        .bht_indexD(bht_indexD),
        .predicted_targetD(predicted_targetD),
        
        .RegWriteE(RegWriteE),
        .ALUSrcE(ALUSrcE),
        .MemWriteE(MemWriteE),
        .ResultSrcE(ResultSrcE),
        .ALUControlE(ALUControlE),
        .RD1_E(RD1_E),
        .RD2_E(RD2_E),
        .Imm_Ext_E(Imm_Ext_E),
        .RD_E(RD_E),
        .PCE(PCE),
        .PCPlus4E(PCPlus4E),
        .RS1_E(RS1_E),
        .RS2_E(RS2_E),
        .predicted_takenE(predicted_takenE),
        .bht_indexE(bht_indexE),
        .predicted_targetE(predicted_targetE)
    );

    // Execute Stage
    execute_cycle execute_inst (
        .clk(clk),
        .rst(rst),
        .RegWriteE(RegWriteE),
        .ALUSrcE(ALUSrcE),
        .MemWriteE(MemWriteE),
        .ResultSrcE(ResultSrcE),
        .ALUControlE(ALUControlE),
        .RD1_E(RD1_E),
        .RD2_E(RD2_E),
        .Imm_Ext_E(Imm_Ext_E),
        .RD_E(RD_E),
        .PCE(PCE),
        .PCPlus4E(PCPlus4E),
        .ResultW(ResultW),
        .ForwardA_E(ForwardAE),
        .ForwardB_E(ForwardBE),
        .predicted_takenE(predicted_takenE),
        .bht_indexE(bht_indexE),
        .predicted_targetE(predicted_targetE),
        
        .RegWriteM(RegWriteM),
        .MemWriteM(MemWriteM),
        .ResultSrcM(ResultSrcM),
        .RD_M(RD_M),
        .PCPlus4M(PCPlus4M),
        .WriteDataM(WriteDataM),
        .ALU_ResultM(ALU_ResultM),
        
        .branch_takenE(branch_takenE),
        .branch_targetE(branch_targetE),
        .mispredict_E(mispredict_E),
        .corrected_PCE(corrected_PCE),
        .update_BHT(update_BHT),
        .bht_indexE_out(bht_indexE_out)
    );

    // Memory Stage
    wire [31:0] ReadDataM;
    Data_Memory dmem (
        .clk(clk),
        .rst(rst),
        .WE(MemWriteM),
        .WD(WriteDataM),
        .A(ALU_ResultM),
        .RD(ReadDataM)
    );
    
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            RegWriteW_r <= 0;
            ResultSrcW_r <= 0;
            RDW_r <= 0;
            ReadDataW_r <= 0;
            ALU_ResultW_r <= 0;
            PCPlus4W_r <= 0;
        end else begin
            RegWriteW_r <= RegWriteM;
            ResultSrcW_r <= ResultSrcM;
            RDW_r <= RD_M;
            ReadDataW_r <= ReadDataM;
            ALU_ResultW_r <= ALU_ResultM;
            PCPlus4W_r <= PCPlus4M;
        end
    end

    assign RegWriteW = RegWriteW_r;
    assign ResultSrcW = ResultSrcW_r;
    assign RDW = RDW_r;
    assign ReadDataW = ReadDataW_r;
    assign ALU_ResultW = ALU_ResultW_r;
    assign PCPlus4W = PCPlus4W_r;
    
    // Hazard Unit
    hazard_unit hazard_inst (
        .rst(rst),
        .RegWriteM(RegWriteM),
        .RegWriteW(RegWriteW),
        .RD_M(RD_M),
        .RD_W(RDW),
        .Rs1_E(RS1_E),
        .Rs2_E(RS2_E),
        .mispredict_E(mispredict_E),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .flush(flush)
    );

endmodule

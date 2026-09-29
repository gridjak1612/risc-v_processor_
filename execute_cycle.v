module execute_cycle(
    input clk, 
    input rst, 
    input RegWriteE, 
    input ALUSrcE, 
    input MemWriteE, 
    input ResultSrcE,
    input [2:0] ALUControlE, 
    input [31:0] RD1_E, 
    input [31:0] RD2_E, 
    input [31:0] Imm_Ext_E, 
    input [4:0] RD_E, 
    input [31:0] PCE, 
    input [31:0] PCPlus4E,
    input [31:0] ResultW, 
    input [1:0] ForwardA_E, 
    input [1:0] ForwardB_E,
    input predicted_takenE,
    input [7:0] bht_indexE,
    input [31:0] predicted_targetE,

    output RegWriteM, 
    output MemWriteM, 
    output ResultSrcM, 
    output [4:0] RD_M, 
    output [31:0] PCPlus4M, 
    output [31:0] WriteDataM, 
    output [31:0] ALU_ResultM,
    
    // BP Outputs to Fetch Stage / Hazard
    output branch_takenE,
    output [31:0] branch_targetE,
    output mispredict_E,
    output [31:0] corrected_PCE,
    output update_BHT,
    output [7:0] bht_indexE_out
);

    // Declaration of Interim Wires
    wire [31:0] Src_A, Src_B_interim, Src_B;
    wire [31:0] ResultE;
    wire ZeroE;

    // Declaration of Register
    reg RegWriteE_r, MemWriteE_r, ResultSrcE_r;
    reg [4:0] RD_E_r;
    reg [31:0] PCPlus4E_r, RD2_E_r, ResultE_r;

    // Declaration of Modules
    // 3 by 1 Mux for Source A
    Mux_3_by_1 srca_mux (
                        .a(RD1_E),
                        .b(ResultW),
                        .c(ALU_ResultM),
                        .s(ForwardA_E),
                        .d(Src_A)
                        );

    // 3 by 1 Mux for Source B
    Mux_3_by_1 srcb_mux (
                        .a(RD2_E),
                        .b(ResultW),
                        .c(ALU_ResultM),
                        .s(ForwardB_E),
                        .d(Src_B_interim)
                        );
    // ALU Src Mux
    Mux alu_src_mux (
            .a(Src_B_interim),
            .b(Imm_Ext_E),
            .s(ALUSrcE),
            .c(Src_B)
            );

    // ALU Unit
    ALU alu (
            .A(Src_A),
            .B(Src_B),
            .Result(ResultE),
            .ALUControl(ALUControlE),
            .OverFlow(),
            .Carry(),
            .Zero(ZeroE),
            .Negative()
            );

    // Register Logic
    always @(posedge clk or negedge rst) begin
        if(rst == 1'b0) begin
            RegWriteE_r <= 1'b0; 
            MemWriteE_r <= 1'b0; 
            ResultSrcE_r <= 1'b0;
            RD_E_r <= 5'h00;
            PCPlus4E_r <= 32'h00000000; 
            RD2_E_r <= 32'h00000000; 
            ResultE_r <= 32'h00000000;
        end
        else begin
            RegWriteE_r <= RegWriteE; 
            MemWriteE_r <= MemWriteE; 
            ResultSrcE_r <= ResultSrcE;
            RD_E_r <= RD_E;
            PCPlus4E_r <= PCPlus4E; 
            RD2_E_r <= Src_B_interim; 
            ResultE_r <= ResultE;
        end
    end

    // Output Assignments
    assign RegWriteM = RegWriteE_r;
    assign MemWriteM = MemWriteE_r;
    assign ResultSrcM = ResultSrcE_r;
    assign RD_M = RD_E_r;
    assign PCPlus4M = PCPlus4E_r;
    assign WriteDataM = RD2_E_r;
    assign ALU_ResultM = ResultE_r;

    // Branch logic
    assign branch_targetE = PCE + Imm_Ext_E;
    
    // Determine if instruction is a branch (Assuming ALUControlE == 3'b001 is BEQ, adjust if other branches are used)
    assign update_BHT = (ALUControlE == 3'b001); 
    
    // Actual branch decision
    assign branch_takenE = update_BHT && ZeroE; 
    
    // Misprediction logic
    assign mispredict_E = update_BHT && (
                          (predicted_takenE != branch_takenE) || 
                          (predicted_takenE && branch_takenE && (predicted_targetE != branch_targetE))
                          );
                          
    // Corrected PC
    assign corrected_PCE = branch_takenE ? branch_targetE : (PCE + 4);
    
    assign bht_indexE_out = bht_indexE; // Pass back to fetch stage

endmodule

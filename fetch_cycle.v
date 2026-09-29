module fetch_cycle(
    input clk, 
    input rst,
    input flush,
    input [31:0] branch_targetE,
    input [31:0] corrected_PCE,
    input branch_takenE,
    input [7:0] bht_indexE,
    input update_BHT,
    
    output [31:0] InstrD, 
    output [31:0] PCD, 
    output [31:0] PCPlus4D,
    output predicted_takenD,
    output [7:0] bht_indexD,
    output [31:0] predicted_targetD
);

    wire [31:0] PCF, PCPlus4F;
    wire [31:0] InstrF;

    reg [31:0] InstrF_reg, PCF_reg, PCPlus4F_reg;
    reg predicted_taken_reg;
    reg [7:0] bht_index_reg;
    reg [31:0] predicted_target_reg;
    
    // 34-bit BHT: [33:32] for 2-bit counter, [31:0] for Branch Target
    reg [33:0] BHT [255:0];   // 256 entries
    
    wire [7:0] index;
    assign index = PCF[9:2];   // ignore lower 2 bits (word aligned)

    wire predict_taken;
    wire [31:0] predicted_target;

    assign predict_taken = BHT[index][33];  // MSB is decision bit
    assign predicted_target = BHT[index][31:0];

    // ============================
    // PC Selection (redirect on branch)
    // ============================
    wire [31:0] PC_next;
    assign PC_next = (flush) ? corrected_PCE : 
                     (predict_taken) ? predicted_target : PCPlus4F;

    // PC Register
    PC_Module Program_Counter (
        .clk(clk),
        .rst(rst),
        .PC(PCF),
        .PC_Next(PC_next)
    );

    // Instruction memory
    Instruction_Memory IMEM (
        .rst(rst),
        .A(PCF),
        .RD(InstrF)
    );

    // PC+4
    PC_Adder PC_adder (
        .a(PCF),
        .b(32'h00000004),
        .c(PCPlus4F)
    );

    integer i;

    // ============================
    // IF/ID pipeline register with flush and BHT Update
    // ============================
    always @(posedge clk) begin
        if(rst == 1'b0) begin
            InstrF_reg <= 32'h0;
            PCF_reg <= 32'h0;
            PCPlus4F_reg <= 32'h0;
            predicted_taken_reg <= 1'b0;
            bht_index_reg <= 8'h0;
            predicted_target_reg <= 32'h0;
            for(i = 0; i < 256; i = i + 1) begin
                BHT[i] <= 34'h000000000;
            end
        end
        else if (flush) begin
            InstrF_reg <= 32'h0;
            PCF_reg <= 32'h0;
            PCPlus4F_reg <= 32'h0;
            predicted_taken_reg <= 1'b0;
            bht_index_reg <= 8'h0;
            predicted_target_reg <= 32'h0;
        end
        else begin
            InstrF_reg <= InstrF;
            PCF_reg <= PCF;
            PCPlus4F_reg <= PCPlus4F;
            predicted_taken_reg <= predict_taken;
            bht_index_reg <= index;
            predicted_target_reg <= predicted_target;
        end
        
        // BHT Update Logic
        if(update_BHT) begin
            if(branch_takenE) begin
                if(BHT[bht_indexE][33:32] != 2'b11)
                    BHT[bht_indexE][33:32] <= BHT[bht_indexE][33:32] + 1;
                BHT[bht_indexE][31:0] <= branch_targetE;  // Update BTB target if branch taken
            end
            else begin
                if(BHT[bht_indexE][33:32] != 2'b00)
                    BHT[bht_indexE][33:32] <= BHT[bht_indexE][33:32] - 1;
            end
        end
    end

    assign predicted_takenD = predicted_taken_reg;
    assign bht_indexD = bht_index_reg;
    assign predicted_targetD = predicted_target_reg;

    assign InstrD = InstrF_reg;
    assign PCD = PCF_reg;
    assign PCPlus4D = PCPlus4F_reg;

endmodule
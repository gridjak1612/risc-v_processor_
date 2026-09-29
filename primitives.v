module PC_Module(input clk, input rst, input [31:0] PC_Next, output reg [31:0] PC);
    always @(posedge clk or negedge rst) begin
        if(!rst) PC <= 32'h0;
        else PC <= PC_Next;
    end
endmodule

module PC_Adder(input [31:0] a, input [31:0] b, output [31:0] c);
    assign c = a + b;
endmodule

module Register_File(input clk, input rst, input WE3, input [31:0] WD3, input [4:0] A1, A2, A3, output [31:0] RD1, RD2);
    reg [31:0] rf [31:0];
    integer i;
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            for(i=0; i<32; i=i+1) rf[i] <= 0;
        end else if(WE3 && A3 != 0) rf[A3] <= WD3;
    end
    assign RD1 = (A1 != 0) ? rf[A1] : 0;
    assign RD2 = (A2 != 0) ? rf[A2] : 0;
endmodule

module Sign_Extend(input [31:0] In, input [1:0] ImmSrc, output [31:0] Imm_Ext);
    assign Imm_Ext = (ImmSrc == 2'b00) ? {{20{In[31]}}, In[31:20]} : // I-type
                     (ImmSrc == 2'b01) ? {{20{In[31]}}, In[31:25], In[11:7]} : // S-type
                     (ImmSrc == 2'b10) ? {{20{In[31]}}, In[7], In[30:25], In[11:8], 1'b0} : // B-type
                     32'h0;
endmodule

module Mux(input [31:0] a, b, input s, output [31:0] c);
    assign c = (s) ? b : a;
endmodule

module Mux_3_by_1(input [31:0] a, b, c, input [1:0] s, output reg [31:0] d);
    always @(*) begin
        case(s)
            2'b00: d = a;
            2'b01: d = b;
            2'b10: d = c;
            default: d = 32'h0;
        endcase
    end
endmodule

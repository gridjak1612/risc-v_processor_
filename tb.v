`timescale 1ns/1ps

module tb;
    reg clk, rst;
    
    pipeline_top dut(
        .clk(clk),
        .rst(rst)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    integer total_branches = 0;
    integer mispredictions = 0;
    
    initial begin
        $dumpfile("pipeline.vcd");
        $dumpvars(0, tb);
        
        rst = 0;
        #15;
        rst = 1;
        
        #800; // run enough cycles to train the predictor
        $display("==========================================");
        $display("          SIMULATION RESULTS              ");
        $display("==========================================");
        $display("Total Branches: %0d", total_branches);
        $display("Mispredictions: %0d", mispredictions);
        if (total_branches > 0)
            $display("Accuracy: %0d%%", ((total_branches - mispredictions) * 100) / total_branches);
        else
            $display("Accuracy: N/A");
        $display("==========================================");
        $finish;
    end
    
    always @(posedge clk) begin
        if (dut.execute_inst.update_BHT && rst) begin
            total_branches = total_branches + 1;
            if (dut.execute_inst.mispredict_E)
                mispredictions = mispredictions + 1;
        end
    end
endmodule

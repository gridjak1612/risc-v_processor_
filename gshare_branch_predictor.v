module gshare_branch_predictor
  #(
    parameter GSHARE_BITS_NUM = 10,
    parameter OPTION_OPERAND_WIDTH = 32
    )
   (
    input clk,
    input rst,

    // Prediction stage (Fetch)
    input [31:0] pc_f,                    // Current PC for prediction
    input branch_inst_f,                  // Is current instruction a branch?
    output predicted_taken_o,             // Branch prediction result

    // Resolution stage (Execute) 
    input branch_resolved_e,              // Branch was resolved in execute
    input actual_taken_e,                 // Actual branch outcome
    input [31:0] branch_pc_e,            // PC of resolved branch
    input branch_mispredict_e             // Misprediction occurred
    );

   localparam [1:0]
      STATE_STRONGLY_NOT_TAKEN = 2'b00,
      STATE_WEAKLY_NOT_TAKEN   = 2'b01,
      STATE_WEAKLY_TAKEN       = 2'b10,
      STATE_STRONGLY_TAKEN     = 2'b11;
   localparam FSM_NUM = 2 ** GSHARE_BITS_NUM;

   integer i = 0;

   reg [1:0] state [0:FSM_NUM-1];
   reg [GSHARE_BITS_NUM-1:0] branch_history_reg = 0;
   reg [GSHARE_BITS_NUM-1:0] prev_idx = 0;

   // Generate index using XOR of history and PC
   wire [GSHARE_BITS_NUM-1:0] state_index = 
        branch_history_reg ^ pc_f[GSHARE_BITS_NUM+1:2];

   // Prediction: taken if MSB of counter is 1
   assign predicted_taken_o = state[state_index][1] && branch_inst_f;

   always @(posedge clk) begin
      if (rst) begin
         branch_history_reg <= 0;
         prev_idx <= 0;
         for(i = 0; i < FSM_NUM; i = i + 1) begin
            state[i] <= STATE_WEAKLY_TAKEN;
         end
      end else begin
         // Store index when making prediction
         if (branch_inst_f) begin
            prev_idx <= state_index;
         end

         // Update predictor when branch resolves
         if (branch_resolved_e) begin
            // Update branch history
            branch_history_reg <= {branch_history_reg[GSHARE_BITS_NUM-2:0], actual_taken_e};
            
            // Update state machine
            if (!actual_taken_e) begin
               // Not taken: decrement counter (saturate at 00)
               case (state[prev_idx])
                  STATE_STRONGLY_TAKEN:    state[prev_idx] <= STATE_WEAKLY_TAKEN;
                  STATE_WEAKLY_TAKEN:      state[prev_idx] <= STATE_WEAKLY_NOT_TAKEN;
                  STATE_WEAKLY_NOT_TAKEN:  state[prev_idx] <= STATE_STRONGLY_NOT_TAKEN;
                  STATE_STRONGLY_NOT_TAKEN: state[prev_idx] <= STATE_STRONGLY_NOT_TAKEN;
               endcase
            end else begin
               // Taken: increment counter (saturate at 11)
               case (state[prev_idx])
                  STATE_STRONGLY_NOT_TAKEN: state[prev_idx] <= STATE_WEAKLY_NOT_TAKEN;
                  STATE_WEAKLY_NOT_TAKEN:   state[prev_idx] <= STATE_WEAKLY_TAKEN;
                  STATE_WEAKLY_TAKEN:       state[prev_idx] <= STATE_STRONGLY_TAKEN;
                  STATE_STRONGLY_TAKEN:     state[prev_idx] <= STATE_STRONGLY_TAKEN;
               endcase
            end
         end
      end
   end
endmodule

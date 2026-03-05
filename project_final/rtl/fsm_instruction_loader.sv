`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Design Name: 
// Module Name: fsm_instruction_loader
// Project Name: 
//////////////////////////////////////////////////////////////////////////////////

module fsm_instruction_loader #(parameter DATA_WIDTH = 32, parameter BYTE_WIDTH = 8, parameter ADDR_WIDTH = 16)(
	 input logic clk,
	 input logic arst_n,
	 input logic next_program,
	 input logic w_en, // input write enable coming from uart_recv - recv
	 input logic [BYTE_WIDTH - 1 : 0] data_in, // data_in coming from uart data_out port
	 output logic [DATA_WIDTH - 1 : 0] data_out, // data out to be written in the program memory after receiving 4 bytes from uart
	 output logic [ADDR_WIDTH - 1 : 0] wr_addr, // write addres for the memory
	 output logic inst_rdy, // flag to indicate that a instruction is ready, this is the write enable for the memory
	 output logic busy,
	 output logic ready,
	 output logic prog_rdy  // flag to indicate that the program has been initialized into the memory
);

// internal counters 
logic [BYTE_WIDTH - 1 : 0] n_of_instructions;
logic [BYTE_WIDTH - 1 : 0] n_of_instructions_next;

logic [ADDR_WIDTH - 1 : 0] instruction_counter;
logic [ADDR_WIDTH - 1 : 0] instruction_counter_next;

logic [DATA_WIDTH - 1 : 0] temp_data_out;
logic [DATA_WIDTH - 1 : 0] temp_data_out_next;

logic [BYTE_WIDTH - 1 : 0] received_byte;


// states for the fsm
typedef enum logic [3:0]{
    WAIT_PARAMS = 4'b0000,
    WAIT_BYTE0 = 4'b0001,
    WAIT_BYTE1 = 4'b0010,
    WAIT_BYTE2 = 4'b0011,
    WAIT_BYTE3 = 4'b0100,        
    WRITE_INSTRUCTION = 4'b0101,
    DONE = 4'b0110
} state_type;

state_type state_reg, state_next;

// reset all the signals and assign the next state sequential logic
always_ff@(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        state_reg <= WAIT_PARAMS;
        instruction_counter <= '0;
        n_of_instructions <= '0;
        temp_data_out <= '0;
    end else begin
        state_reg <= state_next;
        instruction_counter <= instruction_counter_next;
        n_of_instructions <= n_of_instructions_next;
        temp_data_out <= temp_data_out_next;
    end
end

always_comb begin
    //prog_rdy = 1'b0; // flag for program initialized set to 0
    n_of_instructions_next = n_of_instructions; // default value
    state_next = state_reg; // default state for state_next
    instruction_counter_next = instruction_counter; // default value
    temp_data_out_next = temp_data_out; // default value
    
    case(state_reg)
    
        WAIT_PARAMS: begin // receive a byte from the uart to define the number of instructions to write into the memory
            if(w_en) begin
                n_of_instructions_next = data_in;
					 instruction_counter_next = '0;
					 temp_data_out_next = '0;
                state_next = WAIT_BYTE0;
            end else begin
					state_next = state_reg;
                n_of_instructions_next = n_of_instructions;
            end
        end
    
        WAIT_BYTE0: begin // receive the 1st byte of the instruction
            if(w_en) begin
					 temp_data_out_next = '0;
                temp_data_out_next[7:0] = data_in;
                state_next = WAIT_BYTE1;
            end else begin
                state_next = state_reg;
            end 
        end

        WAIT_BYTE1: begin // receive the 2nd byte of the instruction
            if(w_en) begin
                temp_data_out_next[15:8] = data_in;
                state_next = WAIT_BYTE2;
            end else begin
                state_next = state_reg;
            end 
        end
        
        WAIT_BYTE2: begin // receive the 3rd byte of the instruction
            if(w_en) begin
                temp_data_out_next[23:16] = data_in;
                state_next = WAIT_BYTE3;
            end else begin
                state_next = state_reg;
            end 
        end
        
        WAIT_BYTE3: begin // receive the 4th and last byte of the instruction
            if(w_en) begin
                temp_data_out_next[31:24] = data_in;
                state_next = WRITE_INSTRUCTION;
            end else begin
                state_next = state_reg;
            end 
        end
                                
        WRITE_INSTRUCTION: begin // state to write instruction once the shifter has received 4 bytes = 32 bits instruction
            if(instruction_counter == ((n_of_instructions - 1) * 4)) begin
                state_next = DONE;
            end else begin
                instruction_counter_next = instruction_counter + 3'd4;
                state_next = WAIT_BYTE0;
            end
        end
        
        DONE: begin // done state to set program ready flag to 1
				instruction_counter_next = '0;
				temp_data_out_next = {DATA_WIDTH{1'b0}};
			    state_next = WAIT_PARAMS;
        end

    endcase
end

assign prog_rdy = (state_reg == DONE);
assign inst_rdy = (state_reg == WRITE_INSTRUCTION);
assign data_out = temp_data_out;
assign wr_addr = instruction_counter;
assign ready = (state_reg == WAIT_PARAMS);
assign busy = ~ready;

endmodule

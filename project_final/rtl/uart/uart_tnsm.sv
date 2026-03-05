`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
// 
// Design Name: uart_ip
// Module Name: uart_tnsm
//
//////////////////////////////////////////////////////////////////////////////////

module uart_tnsm(
    input clk,
    input arst_n,
    input active,
    input tnsm_start,
    input [7:0] data,
    input [1:0] frame_type,  // 2'b00 : 5 bits, 2'b01 : 6 bits, 2'b10 : 7 bits, 2'b11 : 8 bits
    input [1:0] parity_type, // 2'b00 : no parity, 2'b01: even parity, 2'b10: odd parity, 2'b11: no parity
    input stop_type,         // 1'b0 : 1 stop bit, 1'b1 : 2 stop bits
    input tnsm_clk_en,
    output logic busy,
    output logic tnsm_done,
    output logic tnsm_clr,
    output logic tx
    );

typedef enum logic [2:0] {
	STATE_TNSM_IDLE,
	STATE_TNSM_DATA,
	STATE_TNSM_PARITY,
	STATE_TNSM_STOP1,
	STATE_TNSM_STOP2} uart_tnsm_state_e;

// configuration registers //
logic stop_type_cfg;
logic [1:0] parity_type_cfg;
logic [1:0] frame_type_cfg;

// internal variables //
logic [3:0] bitcnt;
logic [7:0] data_r;
logic [3:0] frame_size;
logic parity;
uart_tnsm_state_e state;

// UART frame size - this only consider data and parity bit
always_comb begin
    case(frame_type_cfg)
        2'b00 : frame_size = 4'd5;
        2'b01 : frame_size = 4'd6;
        2'b10 : frame_size = 4'd7;
        2'b11 : frame_size = 4'd8;
    endcase
end

always_ff@(posedge clk, negedge arst_n) begin
	if(!arst_n) begin
        tx <= 1'b1;
		bitcnt <= 4'd0;
		tnsm_clr <= 1'b0;
		data_r <= 8'd0;
		parity <= 1'b0;
        tnsm_done <= 1'b0;
        frame_type_cfg <= '0;
        parity_type_cfg <= '0;
        stop_type_cfg <= '0;
		state <= STATE_TNSM_IDLE;
	end	else begin
        tnsm_clr <= 'b0;
        case(state)
    
           STATE_TNSM_IDLE: begin
               tnsm_done <= 1'b0;
               tx <= 1'b1;
               if(tnsm_start && active && tnsm_clk_en) begin
		           parity <= 1'b0;
                   bitcnt <= 'd0;
                   tnsm_clr <= 'b1;
                   frame_type_cfg <= frame_type;
                   stop_type_cfg <= stop_type;
                   parity_type_cfg <= parity_type;
                   data_r <= data;
                   tx <= 1'b0;              // start bit
                   state <= STATE_TNSM_DATA;
               end
           end
    
              STATE_TNSM_DATA: begin
                  if(tnsm_clk_en) begin
                      tx <= data_r[0];
                      data_r <= {1'b0, data_r[7:1]};
                      parity <= parity^tx; // Parity is computed this way in case frame_size < 8 and input data is larger than expected
                      bitcnt <= bitcnt + 4'd1;
                      if(bitcnt == frame_size) begin
                          if(^parity_type) begin
                              tx <= parity_type_cfg == 2'b01 ? parity^tx /*even*/ : ~parity^tx /*odd*/; // parity bit
                              state <= STATE_TNSM_PARITY;
                          end else begin
                              tx <= 1'b1;       // stop bit 1
                              tnsm_done <= stop_type_cfg ? 1'b0: 1'b1;
                              state <= STATE_TNSM_STOP1;
                          end
                      end 
                  end
              end
              
              STATE_TNSM_PARITY: begin
                  if(tnsm_clk_en) begin
                      tx <= 1'b1;       // stop bit 1
                      state <= STATE_TNSM_STOP1;
                  end
              end
              
              STATE_TNSM_STOP1: begin
                  if(tnsm_clk_en) begin
                      tx <= 1'b1;       // stop bit 2 or idle tx state
                      state <= stop_type_cfg ? STATE_TNSM_STOP2 : STATE_TNSM_IDLE;
                      tnsm_done <= 1'b1;
                  end
              end

              STATE_TNSM_STOP2: begin
                  if(tnsm_clk_en) begin
                      tx <= 1'b1;
                      state <= STATE_TNSM_IDLE;
                  end
              end
    
        endcase
	end
end

assign busy = state != STATE_TNSM_IDLE; // Generates busy signal

endmodule: uart_tnsm

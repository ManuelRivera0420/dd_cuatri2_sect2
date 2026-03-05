`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
// 
// Design Name: uart_ip
// Module Name: uart_recv
//
//////////////////////////////////////////////////////////////////////////////////

module uart_recv(
    input clk,
    input arst_n,
    input active,
    input rx,
    input rx_negedge_det,
    input [1:0] frame_type,  // 2'b00 : 5 bits, 2'b01 : 6 bits, 2'b10 : 7 bits, 2'b11 : 8 bits
    input [1:0] parity_type, // 2'b00 : no parity, 2'b01: even parity, 2'b10: odd parity, 2'b11: no parity
    input stop_type,         // 1'b0 : 1 stop bit, 1'b1 : 2 stop bits
    input recv_clk_en,
    output logic [7:0] data,
    output logic recv_done,
    output logic error,
    output logic busy
    );

localparam OVERSAMPLE_COUNT = 31;

typedef enum logic [2:0] {
	STATE_RECV_IDLE,
	STATE_RECV_START,
	STATE_RECV_RECEIVE,
	STATE_RECV_PARITY,
	STATE_RECV_STOP1,
	STATE_RECV_STOP2 } uart_recv_state_e;

// internal variables //
logic [3:0] bitcnt;
logic [5:0] ovsample_cnt;
logic [7:0] data_r;
logic parity_exp;
logic parity;
logic [3:0] frame_size;
logic [1:0] data_shift;
uart_recv_state_e state;

logic stop_type_cfg;
logic [1:0] parity_type_cfg;
logic [1:0] frame_type_cfg;

// Expected parity bit
always_comb begin
    case(parity_type_cfg)
        2'b00: parity_exp = '0;       // no parity
        2'b01: parity_exp = ^data;  // even parity
        2'b10: parity_exp = ~^data; // odd parity
        default: parity_exp = '0;
    endcase
end

// UART frame size - this only consider data and parity bit
always_comb begin
    case(frame_type_cfg)
        2'b00 : begin frame_size = 5; data_shift = 3; end
        2'b01 : begin frame_size = 6; data_shift = 2; end
        2'b10 : begin frame_size = 7; data_shift = 1; end
        2'b11 : begin frame_size = 8; data_shift = 0; end
    endcase
end

always_ff@(posedge clk, negedge arst_n) begin
	if(!arst_n) begin
		bitcnt <= '0;
		data_r <= '0;
		recv_done <= '0;
		error <= '0;
        ovsample_cnt <= '0;
        parity <= '0;
		state <= STATE_RECV_IDLE;
        stop_type_cfg <= '0;
        parity_type_cfg <= '0;
        frame_type_cfg <= '0;
	end	else begin
	   recv_done <= '0;
	   case(state)

	       STATE_RECV_IDLE: begin
                data_r <= '0;
	           if(active && rx_negedge_det) begin
	               state <= STATE_RECV_START;
                   stop_type_cfg <= stop_type;
                   parity_type_cfg <= parity_type;
                   frame_type_cfg <= frame_type;
	           end
	       end

            STATE_RECV_START: begin
                if(recv_clk_en) begin
                    bitcnt <= 'd1; // put to 1, so we dont need to use a -1 in if(bitcnt == frame_size) begin comparison in next state
                    ovsample_cnt <= ovsample_cnt == (OVERSAMPLE_COUNT>>1) ? 6'd0 : ovsample_cnt + 1'b1;
                    state <= ovsample_cnt == (OVERSAMPLE_COUNT>>1) ? STATE_RECV_RECEIVE : STATE_RECV_START;
                end
            end

            STATE_RECV_RECEIVE: begin
                if(recv_clk_en) begin
                    ovsample_cnt <= ovsample_cnt + 1'b1;
                    if(ovsample_cnt == OVERSAMPLE_COUNT) begin
                          ovsample_cnt <= '0;
                          data_r <= {rx, data_r[7:1]};
                        if(bitcnt == frame_size) begin
                            state <= (^parity_type_cfg) ? STATE_RECV_PARITY : STATE_RECV_STOP1;
                        end else begin
                            bitcnt <= bitcnt + 1'b1;
                        end
                    end
                end
            end
            
            STATE_RECV_PARITY: begin
                if(recv_clk_en) begin
                    ovsample_cnt <= ovsample_cnt + 1'b1;
                    if(ovsample_cnt == OVERSAMPLE_COUNT) begin
                        ovsample_cnt <= '0;
                        parity <= rx;
                        state <= STATE_RECV_STOP1;
                    end
                end
            end
            
            STATE_RECV_STOP1: begin
                if(recv_clk_en) begin
                    ovsample_cnt <= ovsample_cnt + 1'b1;
                    if(ovsample_cnt == OVERSAMPLE_COUNT) begin
                        ovsample_cnt <= '0;
                        error <= (rx != 1'b1) || ((^parity_type_cfg) && (parity_exp != parity));
                        recv_done <= stop_type_cfg ? 1'b0 : 1'b1;
                        state <= stop_type_cfg ? STATE_RECV_STOP2 : STATE_RECV_IDLE;
                    end
                end
            end
            
            STATE_RECV_STOP2: begin
                if(recv_clk_en) begin
                    ovsample_cnt <= ovsample_cnt + 1'b1;
                    if(ovsample_cnt == OVERSAMPLE_COUNT) begin
                        ovsample_cnt <= '0;
                        recv_done <= 1'b1;
                        error <= (error) || (rx != 1'b1);
                        state <= STATE_RECV_IDLE;
                    end
                end
            end

	   endcase
	end
end

assign busy = (state != STATE_RECV_IDLE);
assign data = data_r>>data_shift;

endmodule: uart_recv

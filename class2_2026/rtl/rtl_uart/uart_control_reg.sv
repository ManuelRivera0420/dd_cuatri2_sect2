`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:
// 
// Design Name: uart_ip
// Module Name: uart_control_reg
//
//////////////////////////////////////////////////////////////////////////////////

module uart_control_reg(
    input clk,
    input arst_n,
    input we,               // write enable
    input [18:0] wmask,     // write mask
    input [18:0] datain,
    input tnsm_clr,         // clear tnsm bit
    output logic [1:0] frame_type,
    output logic [1:0] parity_type,
    output logic stop_type,
    output logic active,
    output logic [3:0] baud_rate,
    output logic tnsm_start,
    output logic [7:0] tnsm_data,
	 output logic [18:0] ctl_reg_rdata
);

    logic [18:0] reg_;

    always_ff@(posedge clk, negedge arst_n) begin
        if(!arst_n) begin
			reg_[0] <= 1'b1; // Active by default
			reg_[2:1] <= 2'b11; // 8-bits packet by default
			reg_[5] <= 1'b0; // 1 stop bit by default
			reg_[4:3] <= 3'b000; // no parity bit by default
			reg_[18:10] <= 9'd0; // tnsm flag and tnsm data zero by default
			reg_[9:6] <= 4'd7; // 9600 baud rate by default
        end else begin
            if(we) begin
                for(int idx = 0; idx <= 18; idx = idx + 1)
                    reg_[idx] <= wmask[idx] ? datain[idx] : reg_[idx];
            end else if(tnsm_clr) begin
                reg_[10] <= 1'b0;
            end
        end
    end

    assign active = reg_[0];
    assign frame_type = reg_[2:1];
    assign parity_type = reg_[4:3];
    assign stop_type = reg_[5];
    assign baud_rate = reg_[9:6];
    assign tnsm_start = reg_[10];
    assign tnsm_data = reg_[18:11];
	 assign ctl_reg_rdata = reg_;

endmodule: uart_control_reg

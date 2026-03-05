`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
// 
// Design Name: uart_ip
// Module Name: uart_ip
//
//////////////////////////////////////////////////////////////////////////////////

module uart_ip(
    input logic clk,
    input logic arst_n,
    input logic ctl_reg_we,
    input logic [18:0] ctl_reg_wdata,
    input logic [18:0] ctl_reg_wmask,
	output logic [18:0] ctl_reg_rdata,
    
    input logic st_reg_re,
    input logic [11:0] st_reg_rmask,
    output logic [11:0] st_reg_rdata,
    output logic [7:0] recv_data,
    output logic recv_done,
    output logic [31:0] mem_wdata,
    output logic [15:0] wr_addr,
    output logic mem_wen,
    output logic prog_rdy,
    input logic rx,
    output logic tx
    );

// Transmitter-related signals
logic tnsm_clk_en;
logic tnsm_start;
logic tnsm_clr;
logic tnsm_busy;
logic [7:0] tnsm_data;
logic tnsm_done;

// Clock generator
logic [3:0] baud_rate;

// Receiver-related signals
logic recv_clk_en;
logic rx_negedge_det;
//logic [7:0] recv_data;
logic recv_error;
logic recv_busy;
//logic recv_done;

// Control register related signals
logic active;
logic [1:0] frame_type;  // 2'b00 : 5 bits, 2'b01 : 6 bits, 2'b10 : 7 bits, 2'b11 : 8 bits
logic [1:0] parity_type; // 2'b00 : no parity, 2'b01: even parity, 2'b10: odd parity, 2'b11: no parity
logic stop_type;         // 1'b0 : 1 stop bit, 1'b1 : 2 stop bits


// Control register
uart_control_reg uart_control_reg_i(
    .clk(clk),
    .arst_n(arst_n),
    .we(ctl_reg_we), // write enable
    .wmask(ctl_reg_wmask), // write mask
    .datain(ctl_reg_wdata),
    .tnsm_clr(tnsm_clr), // clear tnsm bit
    .frame_type(frame_type),
    .parity_type(parity_type),
    .stop_type(stop_type),
    .active(active),
    .baud_rate(baud_rate),
    .tnsm_start(tnsm_start),
    .tnsm_data(tnsm_data),
	 .ctl_reg_rdata(ctl_reg_rdata)
);

// Clock generator
clk_gen clk_gen_i(
    .clk(clk),
    .arst_n(arst_n),
    .active(active),
    .baud_rate(baud_rate),
    .tx_clk_en(tnsm_clk_en),
    .rx_clk_en(recv_clk_en)
    );

// Edge detector
edge_detector edge_detector_i(
    .clk(clk),
    .arst_n(arst_n),
    .rx(rx),
    .rx_negedge_det(rx_negedge_det)
    );

// Transmitter
uart_tnsm uart_tnsm_i(
    .clk(clk),
    .arst_n(arst_n),
    .active(active),
    .tnsm_start(tnsm_start),
    .data(tnsm_data),
    .frame_type(frame_type),
    .parity_type(parity_type),
    .stop_type(stop_type),
    .tnsm_clk_en(tnsm_clk_en),
    .busy(tnsm_busy),
    .tnsm_done(tnsm_done),
    .tnsm_clr(tnsm_clr),
    .tx(tx)
    );

// Receiver
uart_recv uart_recv_i(
    .clk(clk),
    .arst_n(arst_n),
    .active(active),
    .rx(rx),
    .rx_negedge_det(rx_negedge_det),
    .frame_type(frame_type),
    .parity_type(parity_type),
    .stop_type(stop_type),
    .recv_clk_en(recv_clk_en),
    .data(recv_data),
    .recv_done(recv_done),
    .error(recv_error),
    .busy(recv_busy)
    );

logic fsm_busy;
logic fsm_ready;
logic next_program;
assign next_program = 1'b1;

fsm_instruction_loader fsm_instruction_loader_i (
    .clk(clk),
    .arst_n(arst_n),
    .next_program(next_program),
    .w_en(recv_done),
    .data_in(recv_data),
    .data_out(mem_wdata),
    .wr_addr(wr_addr),
    .inst_rdy(mem_wen),
    .busy(fsm_busy),
    .ready(fsm_ready),
    .prog_rdy(prog_rdy)
);

// Master related signals //
logic cmd_ready;
logic [31:0] rsp_rdata;
logic rsp_valid;
logic [15:0] wbm_adr_o;
logic [31:0] wbm_dat_o;
logic wbm_we_o;
logic [3:0] wbm_sel_o;
logic wbm_stb_o;
logic wbm_cyc_o;

logic [31:0] wbs_dat_o;
logic [3:0] wbs_sel_o;
logic wbs_ack_o;
logic wbs_err_o;

wb_master wb_master_i(
    .clk(clk),
    .rst_n(arst_n),
    .cmd_addr(wr_addr),
    .cmd_wdata(mem_wdata),
    .cmd_we(1'b1),
    .cmd_valid(mem_wen),
    .cmd_ready(cmd_ready),
    .rsp_rdata(rsp_rdata),
    .rsp_valid(rsp_valid),
    .wbm_adr_o(wbm_adr_o),
    .wbm_dat_o(wbm_dat_o),
    .wbm_dat_i(wbs_dat_o),
    .wbm_we_o(wbm_we_o),
    .wbm_sel_o(wbm_sel_o),
    .wbm_stb_o(wbm_stb_o),
    .wbm_cyc_o(wbm_cyc_o),
    .wbm_ack_i(wbs_ack_o),
    .wbm_err_i(wbs_err_o)
);

wb_mem wb_mem_i(
    .clk(clk),
    .rst_n(arst_n),
    .wbs_adr_i(wbm_adr_o),
    .wbs_dat_i(wbm_dat_o),
    .wbs_dat_o(wbs_dat_o),
    .wbs_we_i(wbm_we_o),
    .wbs_sel_i(wbm_sel_o),
    .wbs_stb_i(wbm_stb_o),
    .wbs_cyc_i(wbm_cyc_o),
    .wbs_ack_o(wbs_ack_o),
    .wbs_err_o(wbs_err_o)
);

endmodule

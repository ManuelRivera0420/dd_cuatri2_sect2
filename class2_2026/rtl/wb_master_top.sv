module wb_master_top #(parameter AW = 16, parameter DW = 32)(
    input logic clk,
    input logic rst_n,

    // COMMAND INTERFACE //
    input logic [AW - 1 : 0] cmd_addr,
    input logic [DW - 1 : 0] cmd_wdata,
    input logic cmd_we,
    input logic cmd_valid,
    output logic cmd_ready
);

logic [DW - 1 : 0] reg_out;
logic [DW - 1 : 0] rsp_rdata;
logic rsp_valid;

logic [AW - 1 : 0] wbm_adr_o;
logic [DW - 1 : 0] wbm_dat_o;
logic [DW - 1 : 0] wbm_dat_i;
logic wbm_we_o;
logic [3 : 0] wbm_sel_o;
logic wbm_stb_o;
logic wbm_cyc_o;
logic wbm_ack_i;
logic wbm_err_i;

// UART RELATED SIGNALS //
logic [18:0] ctl_reg_wdata_u1;
logic [18:0] ctl_reg_wmask_u1;
logic ctl_reg_we_u1;
logic [7:0] uart_data_u1;
logic recv_done_u1;

assign ctl_reg_wdata_u1 = reg_out[DW - 1 : 13]; // {31:24 - TNSM_DATA, 23 - TNSM_START, 22:19 - BAUD_RATE, 18 - STOP_TYPE, 17:16 - PARITY_TYPE, 15:14 - FRAME_TYPE, 13 - ACTIVE}
assign ctl_reg_we_u1 = reg_out[0];
assign ctl_reg_wmask_u1 = reg_out[1] == 1'b1 ? {19{1'b1}} : {19{1'b0}};

// UART SIGNALS //
logic [11:0] st_reg_rdata_u1;
logic [18:0] ctl_reg_rdata_u1;
logic tx_u1;

// UART 1 //
uart_ip uart_ip_i1(
    .clk(clk),
    .arst_n(rst_n),
    .ctl_reg_we(ctl_reg_we_u1),
    .ctl_reg_wdata(ctl_reg_wdata_u1),
    .ctl_reg_wmask(ctl_reg_wmask_u1),
    .ctl_reg_rdata(ctl_reg_rdata_u1),
    .st_reg_re('0),
    .st_reg_rmask('0),
    .st_reg_rdata(st_reg_rdata_u1),
    .recv_data(uart_data_u1),
    .recv_done(recv_done_u1),
    .tx(tx_u1),
    .rx(tx_u1)
);


// ---- Master 0 ----
wb_master #(.AW(AW), .DW(DW)) u_m0 (
    .clk         (clk),
    .rst_n       (rst_n),
    .cmd_addr    (cmd_addr),
    .cmd_wdata   (cmd_wdata),
    .cmd_we      (cmd_we),
    .cmd_valid   (cmd_valid),
    .cmd_ready   (cmd_ready),
    .rsp_rdata   (rsp_rdata),
    .rsp_valid   (rsp_valid),
    .wbm_adr_o   (wbm_adr_o),
    .wbm_dat_o   (wbm_dat_o),
    .wbm_dat_i   (wbm_dat_i),
    .wbm_we_o    (wbm_we_o),
    .wbm_sel_o   (wbm_sel_o),
    .wbm_stb_o   (wbm_stb_o),
    .wbm_cyc_o   (wbm_cyc_o),
    .wbm_ack_i   (wbm_ack_i),
    .wbm_err_i   (wbm_err_i)
);

logic uart_data_valid;
// ---- Slave 0 — wb_reg ----
wb_reg #(.AW(AW), .DW(DW)) u_reg (
    .clk       (clk),
    .rst_n     (rst_n),
    .data_valid (recv_done_u1),
    .uart_data (uart_data_u1),
    .wbs_addr_i (wbm_adr_o),
    .wbs_data_i (wbm_dat_o),
    .wbs_dat_o (wbm_dat_i),
    .wbs_we_i  (wbm_we_o),
    .wbs_sel_i (wbm_sel_o),
    .wbs_stb_i (wbm_stb_o),
    .wbs_cyc_i (wbm_cyc_o),
    .wbs_ack_o (wbm_ack_i),
    .wbs_err_o (wbm_err_i),
    .uart_data_valid (uart_data_valid),
    .reg_out   (reg_out)
);

endmodule

module wb_top #(
    parameter AW       = 16,
    parameter DW       = 32,
    parameter MEM_BASE = 16'h0000,
    parameter MEM_SIZE = 16'h1000,   // 4 KB
    parameter REG_BASE = 16'h1000,
    parameter REG_SIZE = 16'h0004,   // 1 word
    parameter WB2_BASE = 16'h2000,
    parameter WB2_SIZE = 16'h0100   // 256 bytes (64 x 32-bit words)
)(
    input logic clk,
    input logic rst_n,

    // MASTER 0 COMMAND SIGNALS //
    input logic [AW - 1 : 0] cmd_addr_m0,
    input logic [DW - 1 : 0] cmd_wdata_m0,
    input logic cmd_we_m0,
    input logic cmd_valid_m0,
    output logic cmd_ready_m0,

    output logic [DW - 1 : 0] rsp_rdata_m0,
    output logic rsp_valid_m0,

    // MASTER 1 COMMAND SIGNALS //
    input logic [AW - 1 : 0] cmd_addr_m1,
    input logic [DW - 1 : 0] cmd_wdata_m1,
    input logic cmd_we_m1,
    input logic cmd_valid_m1,
    output logic cmd_ready_m1,

    output logic [DW - 1 : 0] rsp_rdata_m1,
    output logic rsp_valid_m1
);

// MASTER 0 INTERNAL WIRES //
logic [AW - 1 : 0] m0_adr_i;
logic [DW - 1 : 0] m0_dat_i;
logic [DW - 1 : 0] m0_dat_o;
logic m0_we_i;
logic [3:0] m0_sel_i;
logic m0_stb_i;
logic m0_cyc_i;
logic m0_ack_o;
logic m0_err_o;

// MASTER 1 INTERNAL WIRES //
logic [AW - 1 : 0] m1_adr_i;
logic [DW - 1 : 0] m1_dat_i;
logic [DW - 1 : 0] m1_dat_o;
logic m1_we_i;
logic [3:0] m1_sel_i;
logic m1_stb_i;
logic m1_cyc_i;
logic m1_ack_o;
logic m1_err_o;

// SLAVE 0 INTERNAL WIRES //
logic [AW - 1 : 0] s0_adr_o;
logic [DW - 1 : 0] s0_dat_o;
logic [DW - 1 : 0] s0_dat_i;
logic s0_we_o;
logic [3:0] s0_sel_o;
logic s0_stb_o;
logic s0_cyc_o;
logic s0_ack_i;
logic s0_err_i;

// SLAVE 1 INTERNAL WIRES //
logic [AW - 1 : 0] s1_adr_o;
logic [DW - 1 : 0] s1_dat_o;
logic [DW - 1 : 0] s1_dat_i;
logic s1_we_o;
logic [3:0] s1_sel_o;
logic s1_stb_o;
logic s1_cyc_o;
logic s1_ack_i;
logic s1_err_i;

// SLAVE 2 INTERNAL WIRES //
logic [AW - 1 : 0] s2_adr_o;
logic [DW - 1 : 0] s2_dat_o;
logic [DW - 1 : 0] s2_dat_i;
logic s2_we_o;
logic [3:0] s2_sel_o;
logic s2_stb_o;
logic s2_cyc_o;
logic s2_ack_i;
logic s2_err_i;

wb_interconnect #(
    .AW       (AW),
    .DW       (DW),
    .MEM_BASE (MEM_BASE),
    .MEM_SIZE (MEM_SIZE),
    .REG_BASE (REG_BASE),
    .REG_SIZE (REG_SIZE),
    .WB2_BASE (WB2_BASE),
    .WB2_SIZE (WB2_SIZE)
) wb_interconnect_i (
    .clk     (clk),
    .rst_n   (rst_n),

    // ---- Master 0 ----
    .m0_adr_i (m0_adr_i),
    .m0_dat_i (m0_dat_i),
    .m0_dat_o (m0_dat_o),
    .m0_we_i  (m0_we_i),
    .m0_sel_i (m0_sel_i),
    .m0_stb_i (m0_stb_i),
    .m0_cyc_i (m0_cyc_i),
    .m0_ack_o (m0_ack_o),
    .m0_err_o (m0_err_o),

    // ---- Master 1 ----
    .m1_adr_i (m1_adr_i),
    .m1_dat_i (m1_dat_i),
    .m1_dat_o (m1_dat_o),
    .m1_we_i  (m1_we_i),
    .m1_sel_i (m1_sel_i),
    .m1_stb_i (m1_stb_i),
    .m1_cyc_i (m1_cyc_i),
    .m1_ack_o (m1_ack_o),
    .m1_err_o (m1_err_o),

    // ---- Slave 0 ----
    .s0_adr_o (s0_adr_o),
    .s0_dat_o (s0_dat_o),
    .s0_dat_i (s0_dat_i),
    .s0_we_o  (s0_we_o),
    .s0_sel_o (s0_sel_o),
    .s0_stb_o (s0_stb_o),
    .s0_cyc_o (s0_cyc_o),
    .s0_ack_i (s0_ack_i),
    .s0_err_i (s0_err_i),

    // ---- Slave 1 ----
    .s1_adr_o (s1_adr_o),
    .s1_dat_o (s1_dat_o),
    .s1_dat_i (s1_dat_i),
    .s1_we_o  (s1_we_o),
    .s1_sel_o (s1_sel_o),
    .s1_stb_o (s1_stb_o),
    .s1_cyc_o (s1_cyc_o),
    .s1_ack_i (s1_ack_i),
    .s1_err_i (s1_err_i),

    // ---- Slave 2 ----
    .s2_adr_o (s2_adr_o),
    .s2_dat_o (s2_dat_o),
    .s2_dat_i (s2_dat_i),
    .s2_we_o  (s2_we_o),
    .s2_sel_o (s2_sel_o),
    .s2_stb_o (s2_stb_o),
    .s2_cyc_o (s2_cyc_o),
    .s2_ack_i (s2_ack_i)
);

wb_mem wb_mem_s0_i(
        .clk(clk),
        .rst_n(rst_n),
        .wbs_adr_i(s0_adr_o),
        .wbs_dat_i(s0_dat_o),
        .wbs_dat_o(s0_dat_i),
        .wbs_we_i(s0_we_o),
        .wbs_sel_i(s0_sel_o),
        .wbs_stb_i(s0_stb_o),
        .wbs_cyc_i(s0_cyc_o),
        .wbs_ack_o(s0_ack_i),
        .wbs_err_o(s0_err_i)
);

wb_reg wb_reg_s1_i(
    .clk(clk),
    .rst_n(rst_n),
    .wbs_adr_i(s1_adr_o),
    .wbs_dat_i(s1_dat_o),
    .wbs_dat_o(s1_dat_i),
    .wbs_we_i(s1_we_o),
    .wbs_sel_i(s1_sel_o),
    .wbs_stb_i(s1_stb_o),
    .wbs_cyc_i(s1_cyc_o),
    .wbs_ack_o(s1_ack_i),
    .wbs_err_o(s1_err_i)
);

wb_ram wb_ram_s2_i(
    .clk(clk),
    .adr_i(s2_adr_o),
    .dat_i(s2_dat_o),
    .dat_o(s2_dat_i),
    .we_i(s2_we_o),
    .sel_i(s2_sel_o),
    .stb_i(s2_stb_o),
    .ack_o(s2_ack_i),
    .cyc_i(s2_cyc_o)
);

        // MASTER 0 //
wb_master #(AW, DW) wb_master_m0_i(
    .clk(clk),
    .rst_n(rst_n),

    // COMMAND INTERFACE //
    .cmd_addr(cmd_addr_m0),
    .cmd_wdata(cmd_wdata_m0),
    .cmd_we(cmd_we_m0),
    .cmd_valid(cmd_valid_m0),
    .cmd_ready(cmd_ready_m0),

    // RESPONSE INTERFACE //
    .rsp_rdata(rsp_rdata_m0),
    .rsp_valid(rsp_valid_m0),

    // WISHBONE MASTER PORT //
    .wbm_adr_o(m0_adr_i),
    .wbm_dat_o(m0_dat_i),
    .wbm_dat_i(m0_dat_o),
    .wbm_we_o(m0_we_i),
    .wbm_sel_o(m0_sel_i),
    .wbm_stb_o(m0_stb_i),
    .wbm_cyc_o(m0_cyc_i),
    .wbm_ack_i(m0_ack_o),
    .wbm_err_i(m0_err_o)
);

        // MASTER 1 //
wb_master #(AW, DW) wb_master_m1_i(
    .clk(clk),
    .rst_n(rst_n),

    // COMMAND INTERFACE //
    .cmd_addr(cmd_addr_m1),
    .cmd_wdata(cmd_wdata_m1),
    .cmd_we(cmd_we_m1),
    .cmd_valid(cmd_valid_m1),
    .cmd_ready(cmd_ready_m1),

    // RESPONSE INTERFACE //
    .rsp_rdata(rsp_rdata_m1),
    .rsp_valid(rsp_valid_m1),

    // WISHBONE MASTER PORT //
    .wbm_adr_o(m1_adr_i),
    .wbm_dat_o(m1_dat_i),
    .wbm_dat_i(m1_dat_o),
    .wbm_we_o(m1_we_i),
    .wbm_sel_o(m1_sel_i),
    .wbm_stb_o(m1_stb_i),
    .wbm_cyc_o(m1_cyc_i),
    .wbm_ack_i(m1_ack_o),
    .wbm_err_i(m1_err_o)
);


endmodule

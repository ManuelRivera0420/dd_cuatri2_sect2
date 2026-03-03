// =============================================================================
// wb_interconnect.sv
// 2-master / 3-slave Wishbone B4 shared-bus interconnect
//
// Arbitration : fixed priority  M0 > M1
//               Grant held for the duration of one complete CYC assertion.
//               When no master is active the bus is idle.
//
// Address map (parameterisable):
//   Slave 0  wb_mem : MEM_BASE .. MEM_BASE+MEM_SIZE-1  (default 0x0000-0x0FFF)
//   Slave 1  wb_reg : REG_BASE .. REG_BASE+REG_SIZE-1  (default 0x1000-0x1003)
//   Slave 2  wb_ram : WB2_BASE .. WB2_BASE+WB2_SIZE-1  (default 0x2000-0x20FF)
//
// Block diagram:
//
//  M0 ─┐                          ┌─ S0 (wb_mem)
//       ├─[Arbiter]─[Master Mux]──┼─ S1 (wb_reg)
//  M1 ─┘           [Addr Decode]  └─ S2 (wb_ram)
//              [Response Mux back to granted master]
// =============================================================================

`timescale 1ns/1ps

module wb_interconnect #(
    parameter AW       = 16,
    parameter DW       = 32,
    parameter MEM_BASE = 16'h0000,
    parameter MEM_SIZE = 16'h1000,    // 4 KB
    parameter REG_BASE = 16'h1000,
    parameter REG_SIZE = 16'h0004,    // 1 word
    parameter WB2_BASE = 16'h2000,
    parameter WB2_SIZE = 16'h0100     // 256 bytes (64 x 32-bit words)
) (
    input  logic         clk,
    input  logic         rst_n,

    // ---- Master 0 (higher priority) ----
    input  logic [AW-1:0] m0_adr_i,
    input  logic [DW-1:0] m0_dat_i,
    output logic [DW-1:0] m0_dat_o,
    input  logic           m0_we_i,
    input  logic [3:0]     m0_sel_i,
    input  logic           m0_stb_i,
    input  logic           m0_cyc_i,
    output logic           m0_ack_o,
    output logic           m0_err_o,

    // ---- Master 1 (lower priority) ----
    input  logic [AW-1:0] m1_adr_i,
    input  logic [DW-1:0] m1_dat_i,
    output logic [DW-1:0] m1_dat_o,
    input  logic           m1_we_i,
    input  logic [3:0]     m1_sel_i,
    input  logic           m1_stb_i,
    input  logic           m1_cyc_i,
    output logic           m1_ack_o,
    output logic           m1_err_o,

    // ---- Slave 0 (wb_mem) ----
    output logic [AW-1:0] s0_adr_o,
    output logic [DW-1:0] s0_dat_o,   // write data  IC -> slave
    input  logic [DW-1:0] s0_dat_i,   // read  data  slave -> IC
    output logic           s0_we_o,
    output logic [3:0]     s0_sel_o,
    output logic           s0_stb_o,
    output logic           s0_cyc_o,
    input  logic           s0_ack_i,
    input  logic           s0_err_i,

    // ---- Slave 1 (wb_reg) ----
    output logic [AW-1:0] s1_adr_o,
    output logic [DW-1:0] s1_dat_o,   // write data  IC -> slave
    input  logic [DW-1:0] s1_dat_i,   // read  data  slave -> IC
    output logic           s1_we_o,
    output logic [3:0]     s1_sel_o,
    output logic           s1_stb_o,
    output logic           s1_cyc_o,
    input  logic           s1_ack_i,
    input  logic           s1_err_i,

    // ---- Slave 2 (wb_ram) — no err port, wb_ram does not provide one ----
    output logic [AW-1:0] s2_adr_o,
    output logic [DW-1:0] s2_dat_o,   // write data  IC -> slave
    input  logic [DW-1:0] s2_dat_i,   // read  data  slave -> IC
    output logic           s2_we_o,
    output logic [3:0]     s2_sel_o,
    output logic           s2_stb_o,
    output logic           s2_cyc_o,
    input  logic           s2_ack_i
);

    // ------------------------------------------------------------------
    // Arbiter — fixed priority: M0 > M1
    //
    // grant       : 0 = M0 holds bus, 1 = M1 holds bus
    // grant_valid : a master currently holds the bus
    //
    // A new grant is issued only when the bus is idle.
    // The grant is released when the active master deasserts CYC.
    // ------------------------------------------------------------------
    logic grant;
    logic grant_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant       <= 1'b0;
            grant_valid <= 1'b0;
        end else begin
            if (!grant_valid) begin
                // Bus idle — grant to highest-priority requesting master
                if (m0_cyc_i) begin
                    grant       <= 1'b0;
                    grant_valid <= 1'b1;
                end else if (m1_cyc_i) begin
                    grant       <= 1'b1;
                    grant_valid <= 1'b1;
                end
            end else begin
                // Bus busy — release when the granted master drops CYC
                if (grant == 1'b0 && !m0_cyc_i)
                    grant_valid <= 1'b0;
                else if (grant == 1'b1 && !m1_cyc_i)
                    grant_valid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------
    // Master mux — forward signals from the granted master onto the bus
    // ------------------------------------------------------------------
    logic [AW-1:0] mx_adr;
    logic [DW-1:0] mx_dat;
    logic           mx_we;
    logic [3:0]     mx_sel;
    logic           mx_stb;
    logic           mx_cyc;

    always_comb begin
        if (grant_valid && grant == 1'b1) begin
            // M1 is granted
            mx_adr = m1_adr_i;
            mx_dat = m1_dat_i;
            mx_we  = m1_we_i;
            mx_sel = m1_sel_i;
            mx_stb = m1_stb_i;
            mx_cyc = m1_cyc_i;
        end else begin
            // M0 is granted (or bus is idle — mux defaults to M0 but
            // grant_valid gates all slave-facing STB/CYC so no transaction
            // can start when the bus is idle)
            mx_adr = m0_adr_i;
            mx_dat = m0_dat_i;
            mx_we  = m0_we_i;
            mx_sel = m0_sel_i;
            mx_stb = m0_stb_i;
            mx_cyc = grant_valid ? m0_cyc_i : 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Address decoder — one hit signal per slave, mutually exclusive
    // ------------------------------------------------------------------
    localparam [AW-1:0] MEM_LIMIT = MEM_BASE + MEM_SIZE;
    localparam [AW-1:0] REG_LIMIT = REG_BASE + REG_SIZE;
    localparam [AW-1:0] WB2_LIMIT = WB2_BASE + WB2_SIZE;

    logic s0_hit, s1_hit, s2_hit;
    logic addr_hit;

    always_comb begin
        s0_hit   = 1'b0;
        s1_hit   = 1'b0;
        s2_hit   = 1'b0;
        addr_hit = 1'b0;
        if (mx_adr >= MEM_BASE && mx_adr < MEM_LIMIT) begin
            s0_hit   = 1'b1;
            addr_hit = 1'b1;
        end else if (mx_adr >= REG_BASE && mx_adr < REG_LIMIT) begin
            s1_hit   = 1'b1;
            addr_hit = 1'b1;
        end else if (mx_adr >= WB2_BASE && mx_adr < WB2_LIMIT) begin
            s2_hit   = 1'b1;
            addr_hit = 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Drive slaves
    // STB is gated by grant_valid + this slave's hit + valid address
    // CYC is gated by grant_valid + this slave's hit
    // ------------------------------------------------------------------
    assign s0_adr_o = mx_adr;
    assign s0_dat_o = mx_dat;
    assign s0_we_o  = mx_we;
    assign s0_sel_o = mx_sel;
    assign s0_stb_o = mx_stb & grant_valid & s0_hit & addr_hit;
    assign s0_cyc_o = mx_cyc & grant_valid & s0_hit;

    assign s1_adr_o = mx_adr;
    assign s1_dat_o = mx_dat;
    assign s1_we_o  = mx_we;
    assign s1_sel_o = mx_sel;
    assign s1_stb_o = mx_stb & grant_valid & s1_hit & addr_hit;
    assign s1_cyc_o = mx_cyc & grant_valid & s1_hit;

    assign s2_adr_o = mx_adr;
    assign s2_dat_o = mx_dat;
    assign s2_we_o  = mx_we;
    assign s2_sel_o = mx_sel;
    assign s2_stb_o = mx_stb & grant_valid & s2_hit & addr_hit;
    assign s2_cyc_o = mx_cyc & grant_valid & s2_hit;

    // ------------------------------------------------------------------
    // Response mux — route ACK/DAT from the selected slave back to the
    // master that currently holds the grant
    // ------------------------------------------------------------------
    logic           rsp_ack;
    logic [DW-1:0] rsp_dat;
    logic           rsp_err;

    always_comb begin
        if (s2_hit) begin
            rsp_ack = s2_ack_i;
            rsp_dat = s2_dat_i;
            rsp_err = 1'b0;         // wb_ram has no error output
        end else if (s1_hit) begin
            rsp_ack = s1_ack_i;
            rsp_dat = s1_dat_i;
            rsp_err = s1_err_i;
        end else begin
            rsp_ack = s0_ack_i;
            rsp_dat = s0_dat_i;
            rsp_err = s0_err_i;
        end
    end

    // Deliver response only to the master that holds the grant
    assign m0_ack_o = (grant_valid && grant == 1'b0) ? rsp_ack : 1'b0;
    assign m0_dat_o = (grant_valid && grant == 1'b0) ? rsp_dat : '0;
    assign m0_err_o = (grant_valid && grant == 1'b0) ? rsp_err : 1'b0;

    assign m1_ack_o = (grant_valid && grant == 1'b1) ? rsp_ack : 1'b0;
    assign m1_dat_o = (grant_valid && grant == 1'b1) ? rsp_dat : '0;
    assign m1_err_o = (grant_valid && grant == 1'b1) ? rsp_err : 1'b0;

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

endmodule

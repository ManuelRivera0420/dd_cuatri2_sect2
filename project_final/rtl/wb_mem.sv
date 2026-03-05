// =============================================================================
// wb_mem.sv
// Wishbone B4 slave — 1024 x 32-bit SRAM
//
// Memory map (as seen by the interconnect):
//   base  0x0000
//   size  0x1000  (4 KB, 1024 words of 32 bits)
//
// Addressing:
//   wbs_adr_i[11:2] selects the 32-bit word  (byte address, [1:0] ignored)
//   wbs_sel_i[3:0]  selects individual byte lanes for write
//
// Protocol:
//   Single-cycle ACK — asserts ack_o for exactly one clock after
//   a valid STB+CYC request.
// =============================================================================

`timescale 1ns/1ps

module wb_mem #(
    parameter AW    = 16,
    parameter DW    = 32,
    parameter DEPTH = 1024     // number of 32-bit words
) (
    input  logic             clk,
    input  logic             rst_n,

    // ---- Wishbone slave port ----
    input  logic [AW-1:0]   wbs_adr_i,
    input  logic [DW-1:0]   wbs_dat_i,
    output logic [DW-1:0]   wbs_dat_o,
    input  logic             wbs_we_i,
    input  logic [3:0]       wbs_sel_i,
    input  logic             wbs_stb_i,
    input  logic             wbs_cyc_i,
    output logic             wbs_ack_o,
    output logic             wbs_err_o
);

    localparam WABITS = $clog2(DEPTH);   // = 10 for DEPTH=1024

    logic [DW-1:0] mem [0:DEPTH-1];

    // Word address: drop the 2 byte-lane LSBs
    logic [WABITS-1:0] waddr;
    assign waddr = wbs_adr_i[WABITS+1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_ack_o <= 1'b0;
            wbs_dat_o <= '0;
        end else begin
            wbs_ack_o <= 1'b0;   // default: no ack

            if (wbs_cyc_i && wbs_stb_i && !wbs_ack_o) begin
                wbs_ack_o <= 1'b1;

                if (wbs_we_i) begin
                    // Byte-enable writes
                    if (wbs_sel_i[0]) mem[waddr][ 7: 0] <= wbs_dat_i[ 7: 0];
                    if (wbs_sel_i[1]) mem[waddr][15: 8] <= wbs_dat_i[15: 8];
                    if (wbs_sel_i[2]) mem[waddr][23:16] <= wbs_dat_i[23:16];
                    if (wbs_sel_i[3]) mem[waddr][31:24] <= wbs_dat_i[31:24];
                end else begin
                    wbs_dat_o <= mem[waddr];
                end
            end
        end
    end

    assign wbs_err_o = 1'b0;

endmodule

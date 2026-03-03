// =============================================================================
// wb_reg.sv
// Wishbone B4 slave — single 32-bit register
//
// Memory map (as seen by the interconnect):
//   base  0x1000
//   size  0x0004  (one 32-bit word)
//
// reg_out  exposes the stored value as a continuous output for monitoring.
//
// Protocol:
//   Single-cycle ACK — asserts ack_o for exactly one clock after
//   a valid STB+CYC request.
// =============================================================================

module wb_reg #(
    parameter AW = 16,
    parameter DW = 32
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
    output logic             wbs_err_o,

    output logic [DW-1:0]   reg_out    // current register value (for monitoring)
);

    logic [DW-1:0] reg_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_ack_o <= 1'b0;
            wbs_dat_o <= '0;
            reg_data  <= '0;
        end else begin
            wbs_ack_o <= 1'b0;   // default: no ack

            if (wbs_cyc_i && wbs_stb_i && !wbs_ack_o) begin
                wbs_ack_o <= 1'b1;

                if (wbs_we_i) begin
                    // Byte-enable writes
                    if (wbs_sel_i[0]) reg_data[ 7: 0] <= wbs_dat_i[ 7: 0];
                    if (wbs_sel_i[1]) reg_data[15: 8] <= wbs_dat_i[15: 8];
                    if (wbs_sel_i[2]) reg_data[23:16] <= wbs_dat_i[23:16];
                    if (wbs_sel_i[3]) reg_data[31:24] <= wbs_dat_i[31:24];
                end else begin
                    wbs_dat_o <= reg_data;
                end
            end
        end
    end

    assign wbs_err_o = 1'b0;
    assign reg_out   = reg_data;

endmodule

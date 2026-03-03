`timescale 1ns/1ps

module wb_reg #(
    parameter AW = 16,
    parameter DW = 32
)(
    input logic clk,
    input logic rst_n,
    // UART SIGNALS //
    input logic data_valid,
    input logic [7:0] uart_data,
    // SLAVE SIGNALS //
    input logic [AW - 1 : 0] wbs_addr_i, // X
    input logic [DW - 1 : 0] wbs_data_i,
    input logic wbs_we_i, 
    input logic [3 : 0] wbs_sel_i, // X
    input logic wbs_stb_i,
    input logic wbs_cyc_i,
    output logic [DW - 1 : 0] wbs_dat_o,
    output logic wbs_ack_o,
    output logic wbs_err_o,
    output logic uart_data_valid,
    output logic [DW - 1 : 0] reg_out
);

logic [DW - 1 : 0] reg_temp;
logic [7:0] reg_data;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wbs_dat_o <= {DW{1'b0}};
        wbs_ack_o <= 1'b0;
        wbs_err_o <= 1'b0;
        reg_temp <= {DW{1'b0}};
    end else begin
        if(wbs_stb_i && wbs_cyc_i) begin
            if(wbs_we_i) begin
                reg_temp <= wbs_data_i;
                wbs_ack_o <= 1'b1;
            end else begin
                if(data_valid) begin
                    wbs_dat_o <= uart_data;
                    wbs_ack_o <= 1'b1;
                end else begin
                    wbs_ack_o <= 1'b0;
                end
            end
        end else begin
            wbs_ack_o <= 1'b0;
        end
    end
end

assign uart_data_valid = data_valid;
assign reg_out = reg_temp;

endmodule

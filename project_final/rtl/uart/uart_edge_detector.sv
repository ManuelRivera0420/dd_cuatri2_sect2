`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
// 
// Design Name: uart_ip
// Module Name: edge_detector
//
//////////////////////////////////////////////////////////////////////////////////

module edge_detector (
    input logic clk,
    input logic arst_n,
    input logic rx,
    output logic rx_negedge_det
    );

localparam SCK_DEBOUNCE_SIZE = 2;

logic rx_d;
logic [SCK_DEBOUNCE_SIZE*2-1-1:0] rx_r;

// rx edge detector logic //
always_ff@(posedge clk, negedge arst_n) begin
	if(!arst_n) begin
        rx_r <= '0;
	end else begin
			if(SCK_DEBOUNCE_SIZE == 1)
				rx_r <= rx;
			else
				rx_r <= {rx_r[SCK_DEBOUNCE_SIZE*2-1-1-1:0],rx};
	end
end

assign rx_negedge_det = {rx_r, rx} == {{SCK_DEBOUNCE_SIZE{1'b1}},{SCK_DEBOUNCE_SIZE{1'b0}}};

endmodule: edge_detector

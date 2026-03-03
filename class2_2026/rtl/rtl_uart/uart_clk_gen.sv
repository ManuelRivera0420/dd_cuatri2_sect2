`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
// 
// Design Name: uart_ip
// Module Name: clk_gen
//////////////////////////////////////////////////////////////////////////////////

module clk_gen(
    input logic clk,
    input logic arst_n,
    input logic active,
    input logic [3:0] baud_rate,
    output logic tx_clk_en,
    output logic rx_clk_en
    );

// Supported baud rates (bits per second)
parameter int BAUD_RATES [16] = '{200,300,600,1200,1800,2400,4800,9600,19200,28800,38400,57600,76800,115200,230400,460800};
parameter CLOCK_FREQUENCY = 50_000_000; // 50 MHz
parameter int MAX_COUNTER [16] = '{
    CLOCK_FREQUENCY/BAUD_RATES[0],
    CLOCK_FREQUENCY/BAUD_RATES[1],
    CLOCK_FREQUENCY/BAUD_RATES[2],
    CLOCK_FREQUENCY/BAUD_RATES[3],
    CLOCK_FREQUENCY/BAUD_RATES[4],
    CLOCK_FREQUENCY/BAUD_RATES[5],
    CLOCK_FREQUENCY/BAUD_RATES[6],
    CLOCK_FREQUENCY/BAUD_RATES[7],
    CLOCK_FREQUENCY/BAUD_RATES[8],
    CLOCK_FREQUENCY/BAUD_RATES[9],
    CLOCK_FREQUENCY/BAUD_RATES[10],
    CLOCK_FREQUENCY/BAUD_RATES[11],
    CLOCK_FREQUENCY/BAUD_RATES[12],
    CLOCK_FREQUENCY/BAUD_RATES[13],
    CLOCK_FREQUENCY/BAUD_RATES[14],
    CLOCK_FREQUENCY/(BAUD_RATES[15])
};

// Variables for generating transmitter clocking enabling signal (1x baud rate) //
logic [$clog2(MAX_COUNTER[0])-1:0] tx_clk_cnt;

// Variables for generating receiver clocking enabling signal (16x baud rate) //
logic [$clog2(MAX_COUNTER[0]>>5)-1:0] rx_clk_cnt;

always_ff@(posedge clk, negedge arst_n) begin
    if(~arst_n) begin
        tx_clk_cnt <= '0;
    end else begin
        if(active) begin
          if(tx_clk_en)
            tx_clk_cnt <= '0;
          else
            tx_clk_cnt <= tx_clk_cnt + 1'b1;
        end else begin
          tx_clk_cnt <= '0;
        end
    end
end

always_ff@(posedge clk, negedge arst_n) begin
    if(~arst_n) begin
        rx_clk_cnt <= '0;
    end else begin
        if(active) begin
          if(rx_clk_en)
            rx_clk_cnt <= '0;
          else
            rx_clk_cnt <= rx_clk_cnt + 1'b1;
        end else begin
          rx_clk_cnt <= '0;
        end
    end
end

assign tx_clk_en = tx_clk_cnt == MAX_COUNTER[baud_rate];
assign rx_clk_en = rx_clk_cnt == (MAX_COUNTER[baud_rate]>>5);

endmodule

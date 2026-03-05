`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Design Name:
// Module Name: uart_ip_interface
//
//////////////////////////////////////////////////////////////////////////////////

interface uart_ip_interface(input logic clk, input logic arst_n);

// Declaration of signals used by user tile
logic ctl_reg_we;
logic [18:0] ctl_reg_wdata;
logic [18:0] ctl_reg_wmask;
logic [18:0] ctl_reg_rdata;
logic st_reg_re;
logic [11:0] st_reg_rmask;
logic [11:0] st_reg_rdata;

logic rx;
logic tx;

assign st_reg_rmask = '1;
assign st_reg_re = 1'b1;

////////////////////////////////////// BFM ///////////////////////////	
event drive_ev;
event sample_ev;

parameter int BAUD_RATES [16] = '{200, 300, 600, 1200, 1800, 2400, 4800, 9600, 19200, 28800, 38400, 57600,
76800, 115200, 230400, 460800};

logic [1:0] frame_type;
logic stop_type;
logic [1:0] parity_type;
logic [3:0] baud_rate;
/*
logic [1:0] frame_type;
modport user_tile_modport(
	input ctl_reg_we, ctl_reg_wdata, ctl_reg_wmask, st_reg_re, st_reg_rmask, rx,
	output ctl_reg_rdata, st_reg_rdata, tx
);
*/

function logic [18:0] read_ctl_reg();
    return ctl_reg_rdata;
endfunction

task set_config(input logic [3:0] baud_rate_sel, input logic stop_type_sel, input logic [1:0] parity_type_sel, input logic [1:0] frame_type_sel, input logic on_sel);
    @(posedge clk);
    ctl_reg_wdata <= {ctl_reg_wdata[18:11], 1'b1, baud_rate_sel, stop_type_sel, parity_type_sel, frame_type_sel, on_sel};
    ctl_reg_wmask <= {19{1'b1}};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_wmask <= {19{1'b0}};
    ctl_reg_we <= 1'b0;
endtask


task set_default_config();
    @(posedge clk);
    ctl_reg_wdata <= {9'd0, 4'd7, 1'b0, 2'b00, 2'b11, 1'b0};
    ctl_reg_wmask <= {19{1'b1}};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_wmask <= {19{1'b0}};
    ctl_reg_we <= 1'b0;
endtask

task change_baud_rate(logic [3:0] baud_sel);
    @(posedge clk);
    ctl_reg_wdata <= {ctl_reg_wdata[18:10], baud_sel, ctl_reg_wdata[5:0]};
    ctl_reg_wmask <= {9'h0, 4'b1111, 6'h0};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_we <= 1'b0;
    ctl_reg_wmask <= 19'h0;
endtask

task write_tnsm_data(logic [7:0] data);
    @(posedge clk);
    ctl_reg_wdata <= {data, 1'b1, ctl_reg_wdata[9:1], 1'b1}; // Update the data and set transmission to active
    ctl_reg_wmask <= {{9{1'b1}}, 9'h0, 1'b1};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_we <= 1'b0;
    ctl_reg_wmask <= 19'h0;
endtask

task set_active(bit on);
    @(posedge clk);
    ctl_reg_wdata <= {ctl_reg_wdata[18:1], on};
    ctl_reg_wmask <= {18'h0, 1'b1};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_we <= 1'b0;
    ctl_reg_wmask <= 19'h0;    
endtask

task set_frame_size(logic [1:0] frame_size);
    @(posedge clk);
    ctl_reg_wdata <= {ctl_reg_wdata[18:3], frame_size, ctl_reg_wdata[0]};
    ctl_reg_wmask <= {16'd0, 2'b11, 1'b0};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_we <= 1'b0;
    ctl_reg_wmask <= 19'd0;    
endtask

task set_stop_bit(bit stop_bit);
    @(posedge clk);
    ctl_reg_wdata <= {ctl_reg_wdata[18:6], stop_bit, ctl_reg_wdata[4:0]};
    ctl_reg_wmask <= {13'd0, 1'b1, 5'd0};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_we <= 1'b0;
endtask

task set_parity_bit(logic [1:0] parity_config);
    @(posedge clk);
    ctl_reg_wdata <= {ctl_reg_wdata[18:5], parity_config, ctl_reg_wdata[2:0]};
    ctl_reg_wmask <= {14'd0, 2'b11, 3'd0};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_we <= 1'b0;
    ctl_reg_wmask <= 19'h0;    
endtask

task tnsm_enable();
    @(posedge clk);
    ctl_reg_wdata <= {ctl_reg_wdata[18:11], 1'b1, ctl_reg_wdata[9:0]};
    ctl_reg_wmask <= {8'h0, 1'b1, 10'h0};
    ctl_reg_we <= 1'b1;
    @(posedge clk);
    ctl_reg_we <= 1'b0;
    ctl_reg_wmask <= 19'h0;    
endtask

endinterface

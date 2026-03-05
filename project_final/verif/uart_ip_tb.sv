module uart_ip_tb();

bit clk;
bit arst_n;

//`define FAST_BAUDS

parameter int BAUD_RATES [16] = '{200, 300, 600, 1200, 1800, 2400, 4800, 9600, 19200, 28800, 38400, 57600,
76800, 115200, 230400, 460800};

// UART RECEIVER STATES //
localparam STATE_RECV_IDLE = 3'b000;
localparam STATE_RECV_START = 3'b001;
localparam STATE_RECV_RECEIVE = 3'b010;
localparam STATE_RECV_PARITY = 3'b011;
localparam STATE_RECV_STOP1 = 3'b100;
localparam STATE_RECV_STOP2 = 3'b101;

// UART TRANSMITTER STATES //
localparam STATE_TNSM_IDLE = 3'b000;
localparam STATE_TNSM_DATA = 3'b001;
localparam STATE_TNSM_PARITY = 3'b010;
localparam STATE_TNSM_STOP1 = 3'b011;
localparam STATE_TNSM_STOP2 = 3'b100;

// TIMING LOCAL PARAMETERS USED FOR TESTING //
localparam time CLK_PERIOD = 20ns;
localparam time BIT_TIME = 1s / 9600;
localparam int BIT_CYCLES = BIT_TIME / CLK_PERIOD;
localparam time SAMPLING_TIME = 1s / (9600 * 16);
localparam time HALF_BIT = BIT_TIME / 2;
localparam int HALF_BIT_CYCLES = HALF_BIT / CLK_PERIOD;

// NUMBER OF TESTS FOR THE TESTBENCH //
localparam N_OF_TESTS = 1000;
localparam N_OF_TESTS_PER_BAUD = 5;
// INTERFACE INSTANTIATION //
uart_ip_interface intf(clk, arst_n);

// DUT INSTANTIATION //
uart_ip uart_ip_i(
.clk(clk),
.arst_n(arst_n),
.ctl_reg_we(intf.ctl_reg_we),
.ctl_reg_wdata(intf.ctl_reg_wdata),
.ctl_reg_wmask(intf.ctl_reg_wmask),
.ctl_reg_rdata(intf.ctl_reg_rdata),
.st_reg_re(intf.st_reg_re),
.st_reg_rmask(intf.st_reg_rmask),
.st_reg_rdata(intf.st_reg_rdata),
.rx(intf.tx),
.tx(intf.tx)
);

`define RECEIVER uart_ip_i.uart_recv_i
`define TRANSMITTER uart_ip_i.uart_tnsm_i 
`define UART_CLK_GEN uart_ip_i.clk_gen_i

// GENERATING CLK AND ARST_N STIMULUS //
always #10ns clk = ~clk;
assign #50ns arst_n = 1'b1;

int frame_bits;
logic [7:0] data_in;
logic stop_type;
logic [3:0] baud_rate;
logic [1:0] parity_type;
logic [1:0] frame_size;
logic [7:0] expected_data;

class baud_sel;
    rand bit [3:0] baud_rate;
    constraint c {baud_rate inside {[4'd0:4'd14]};}
endclass

class uart_config;

    bit [3:0] baud_rate;
    rand bit stop_type;
    rand bit [1:0] parity_type;
    rand int unsigned frame_bits;
    rand bit [7:0] data_in;
    rand bit [1:0] frame_width;

endclass

class uart_inst_num;
    rand bit [7:0] data_in;
endclass

uart_config cfg;
baud_sel baud;

time bit_time;
int bit_cycles = 5208; //default value for 9600 baud rate
int half_bit_cycles = 2604;
always @(posedge clk) begin
    if($rose(`RECEIVER.rx_negedge_det)) begin
        bit_time = 1s / BAUD_RATES[baud_rate];
        bit_cycles = (bit_time / CLK_PERIOD);
        half_bit_cycles = bit_cycles >> 1;
    end
end

logic start;
logic [7:0] instructions;

initial begin
    wait(arst_n);
    start = 1'b0;
    @(posedge clk);
    intf.set_default_config();
    cfg = new();
    baud = new();

    repeat(N_OF_TESTS) begin

        repeat(bit_cycles) @(posedge clk);
        
        assert(cfg.randomize());

        expected_data = cfg.data_in;
        std::randomize(instructions) with {instructions inside {[8'h0a: 8'h20]}; };
        
        repeat(1000) @(posedge clk);

        intf.set_config(4'd13, 1'b0, 2'b00, 2'b11, 1'b1);

        repeat(10) @(posedge clk);

        if(start == 1'b0) begin
            intf.write_tnsm_data(instructions);
            wait(`RECEIVER.recv_done);
            repeat(10) @(posedge clk);
            start = 1'b1;

        end else begin
            intf.write_tnsm_data(cfg.data_in);

            wait(`RECEIVER.recv_done);

            repeat(10) @(posedge clk);           
        end

    end
    $finish;
end

always @(posedge uart_ip_i.prog_rdy) begin
    start = 1'b0;
    @(posedge clk);
end

logic [7:0] data_tmp;
always @(posedge uart_ip_i.recv_busy) begin
    case(cfg.frame_width)
        2'b00: data_tmp = {3'b000, expected_data[4:0]};
        2'b01: data_tmp = {2'b00, expected_data[5:0]};
        2'b10: data_tmp = {1'b0, expected_data[6:0]};
        2'b11: data_tmp = expected_data;
    endcase
end

endmodule

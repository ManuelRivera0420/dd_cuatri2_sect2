module wb_master_top_tb();

localparam AW = 16;
localparam DW = 32;
localparam N_OF_TESTS = 100;

bit clk;
bit rst_n;
logic [AW - 1 : 0] cmd_addr;
logic [DW - 1 : 0] cmd_wdata;
logic cmd_we;
logic cmd_valid;
logic cmd_ready;
logic [7:0] rand_data;
logic stop_type;
logic [1:0] frame_size;
logic [3:0] baud_rate;
logic [1:0] parity_type;

always #10ns clk = ~clk;
assign #50ns rst_n = 1'b1;

initial begin
    cmd_valid = 1'b0;
    cmd_addr = '0;
    cmd_wdata = '0;
    cmd_we = 1'b0;
    baud_rate = 4'd7;
    stop_type = 1'b0;
    frame_size = 2'b11;
    wait(rst_n);
    @(posedge clk);
    repeat(N_OF_TESTS) begin

        std::randomize(rand_data, stop_type, parity_type, frame_size);

        cmd_wdata = {rand_data, 1'b1, baud_rate, stop_type, parity_type, frame_size, 1'b1, 11'd0, 1'b1 ,1'b1};
        cmd_we = 1'b1;
        cmd_valid = 1'b1;

        @(posedge clk);
        cmd_we = 1'b0;
        cmd_valid = 1'b1;
        
        wait(wb_master_top.recv_done_u1);
        //repeat(50000) @(posedge clk);
        @(posedge clk);
        cmd_valid = 1'b0;

        wait(!wb_master_top.uart_ip_i1.tnsm_busy);
        @(posedge clk);
    end
    $finish;
end

logic [7:0] expected_data;
always @(posedge wb_master_top.uart_ip_i1.recv_busy) begin
    case(frame_size)
        2'b00: expected_data = {3'b000, rand_data[4:0]};
        2'b01: expected_data = {2'b00, rand_data[5:0]};
        2'b10: expected_data = {1'b0, rand_data[6:0]};
        2'b11: expected_data = rand_data;
    endcase
end

wb_master_top #(.AW(AW), .DW(DW)) wb_master_top_i(
    .clk(clk),
    .rst_n(rst_n),
    .cmd_addr(cmd_addr),
    .cmd_wdata(cmd_wdata),
    .cmd_we(cmd_we),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready)
);

endmodule

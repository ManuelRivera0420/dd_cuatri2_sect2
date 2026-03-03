module wb_top_tb();

parameter AW       = 16;
parameter DW       = 32;
parameter MEM_BASE = 16'h0000;
parameter MEM_SIZE = 16'h1000;   // 4 KB
parameter REG_BASE = 16'h1000;
parameter REG_SIZE = 16'h0004;   // 1 word
parameter WB2_BASE = 16'h2000;
parameter WB2_SIZE = 16'h0100;   // 256 bytes (64 x 32-bit words)

bit clk;
bit rst_n;

// MASTER 0 CMD & RSP SIGNALS //
logic [AW - 1 : 0] cmd_addr_m0;
logic [DW - 1 : 0] cmd_wdata_m0;
logic cmd_we_m0;
logic cmd_valid_m0;
logic cmd_ready_m0;

// response signals //
logic [DW - 1 : 0] rsp_rdata_m0;
logic rsp_valid_m0;


// MASTER 1 CMD & RSP SIGNALS //
logic [AW - 1 : 0] cmd_addr_m1;
logic [DW - 1 : 0] cmd_wdata_m1;
logic cmd_we_m1;
logic cmd_valid_m1;
logic cmd_ready_m1;

// response signals //
logic [DW - 1 : 0] rsp_rdata_m1;
logic rsp_valid_m1;

always #5ns clk = ~clk;
assign #50ns rst_n = 1'b1;

logic [DW - 1 : 0] read_data;
logic [DW - 1 : 0] data;
initial begin
    read_data = '0;
    data = '0;
    wait(rst_n);
    @(posedge clk);
    m0_write(16'h0fff, 32'habcd);
    repeat(2) @(posedge clk);
    m0_write(16'h1000, 32'hfafa);
    repeat(2) @(posedge clk);
    m0_write(16'h0001, 32'haaaa);
    repeat(2) @(posedge clk);

    for(int i = 0; i < 100; i+=4) begin
        std::randomize(data);
        m0_write((WB2_BASE + i), i*10);
        repeat(2) @(posedge clk);
    end

    m0_read(16'h0fff, read_data);
    repeat(2) @(posedge clk);
    m0_read(16'h1000, read_data);
    repeat(2) @(posedge clk);
    m0_read(16'h0001, read_data);
    repeat(2) @(posedge clk);

    for(int i = 0; i < 100; i+=4) begin
        m0_read((WB2_BASE + i), read_data);
        repeat(2) @(posedge clk);
    end
    repeat(100) @(posedge clk);

    $finish;
end

////////////////////////// TASKS //////////////////////////////////////
// ---- M0 write ----
task automatic m0_write(
    input logic [AW-1:0] addr,
    input logic [DW-1:0] data
);
    $display("[%0t ns] M0 WR  addr=0x%04h  data=0x%08h  (sending command)", $time, addr, data);
    @(posedge clk);
    while (!cmd_ready_m0) @(posedge clk);
    cmd_addr_m0  <= addr;
    cmd_wdata_m0 <= data;
    cmd_we_m0    <= 1'b1;
    cmd_valid_m0 <= 1'b1;
    @(posedge clk);
    cmd_valid_m0 <= 1'b0;
    while (!rsp_valid_m0) @(posedge clk);
    $display("[%0t ns] M0 WR  addr=0x%04h  ACK received", $time, addr);
endtask

// ---- M0 read ----
task automatic m0_read(
    input  logic [AW-1:0] addr,
    output logic [DW-1:0] data
);
    $display("[%0t ns] M0 RD  addr=0x%04h  (sending command)", $time, addr);
    @(posedge clk);
    while (!cmd_ready_m0) @(posedge clk);
    cmd_addr_m0  <= addr;
    cmd_wdata_m0 <= '0;
    cmd_we_m0    <= 1'b0;
    cmd_valid_m0 <= 1'b1;
    @(posedge clk);
    cmd_valid_m0 <= 1'b0;
    while (!rsp_valid_m0) @(posedge clk);
    data = rsp_rdata_m0;
    $display("[%0t ns] M0 RD  addr=0x%04h  data=0x%08h  ACK received", $time, addr, data);
endtask

// ---- M1 write ---- //
task automatic m1_write(
    input logic [AW-1:0] addr,
    input logic [DW-1:0] data
);
    $display("[%0t ns] M0 WR  addr=0x%04h  data=0x%08h  (sending command)", $time, addr, data);
    @(posedge clk);
    while (!cmd_ready_m1) @(posedge clk);
    cmd_addr_m1  <= addr;
    cmd_wdata_m1 <= data;
    cmd_we_m1    <= 1'b1;
    cmd_valid_m1 <= 1'b1;
    @(posedge clk);
    cmd_valid_m1 <= 1'b0;
    while (!rsp_valid_m1) @(posedge clk);
    $display("[%0t ns] M0 WR  addr=0x%04h  ACK received", $time, addr);
endtask

// ---- M1 read ---- //
task automatic m1_read(
    input  logic [AW-1:0] addr,
    output logic [DW-1:0] data
);
    $display("[%0t ns] M0 RD  addr=0x%04h  (sending command)", $time, addr);
    @(posedge clk);
    while (!cmd_ready_m1) @(posedge clk);
    cmd_addr_m1  <= addr;
    cmd_wdata_m1 <= '0;
    cmd_we_m1    <= 1'b0;
    cmd_valid_m1 <= 1'b1;
    @(posedge clk);
    cmd_valid_m1 <= 1'b0;
    while (!rsp_valid_m1) @(posedge clk);
    data = rsp_rdata_m1;
    $display("[%0t ns] M0 RD  addr=0x%04h  data=0x%08h  ACK received", $time, addr, data);
endtask


always @(posedge clk) begin
    // Slave 0
    if (wb_top_i.s0_stb_o && wb_top_i.s0_cyc_o)
        $display("[%0t ns]   BUS S0(MEM) %-2s  adr=0x%04h  wdat=0x%08h  sel=%04b", $time, wb_top_i.s0_we_o ? "WR" : "RD", wb_top_i.s0_adr_o, wb_top_i.s0_dat_o, wb_top_i.s0_sel_o);
    if (wb_top_i.s0_ack_i)
        $display("[%0t ns]   BUS S0(MEM) ACK  rdat=0x%08h", $time, wb_top_i.s0_dat_i);
end

always @(posedge clk) begin
    // Slave 1
    if (wb_top_i.s1_stb_o && wb_top_i.s1_cyc_o)
        $display("[%0t ns]   BUS S0(MEM) %-2s  adr=0x%04h  wdat=0x%08h  sel=%04b", $time, wb_top_i.s1_we_o ? "WR" : "RD", wb_top_i.s1_adr_o, wb_top_i.s1_dat_o, wb_top_i.s1_sel_o);
    if (wb_top_i.s1_ack_i)
        $display("[%0t ns]   BUS S0(MEM) ACK  rdat=0x%08h", $time, wb_top_i.s1_dat_i);
end

always @(posedge clk) begin
    // Slave 2
    if (wb_top_i.s2_stb_o && wb_top_i.s2_cyc_o)
        $display("[%0t ns]   BUS S0(MEM) %-2s  adr=0x%04h  wdat=0x%08h  sel=%04b", $time, wb_top_i.s2_we_o ? "WR" : "RD", wb_top_i.s2_adr_o, wb_top_i.s2_dat_o, wb_top_i.s2_sel_o);
    if (wb_top_i.s2_ack_i)
        $display("[%0t ns]   BUS S0(MEM) ACK  rdat=0x%08h", $time, wb_top_i.s2_dat_i);
end


wb_top #(AW, DW, MEM_BASE, MEM_SIZE, REG_BASE, REG_SIZE, WB2_BASE, WB2_SIZE) wb_top_i(
    .clk(clk),
    .rst_n(rst_n),

    // MASTER 0 CMD & RSP SIGNALS //
    .cmd_addr_m0(cmd_addr_m0),
    .cmd_wdata_m0(cmd_wdata_m0),
    .cmd_we_m0(cmd_we_m0),
    .cmd_valid_m0(cmd_valid_m0),
    .cmd_ready_m0(cmd_ready_m0),
    .rsp_rdata_m0(rsp_rdata_m0),
    .rsp_valid_m0(rsp_valid_m0),

    // MASTER 1 CMD & RSP SIGNALS //
    .cmd_addr_m1(cmd_addr_m1),
    .cmd_wdata_m1(cmd_wdata_m1),
    .cmd_we_m1(cmd_we_m1),
    .cmd_valid_m1(cmd_valid_m1),
    .cmd_ready_m1(cmd_ready_m1),
    .rsp_rdata_m1(rsp_rdata_m1),
    .rsp_valid_m1(rsp_valid_m1)
);

endmodule

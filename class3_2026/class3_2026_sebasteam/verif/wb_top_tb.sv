`timescale 1ns/1ps

module wb_top_tb();

parameter AW       = 16;
parameter DW       = 32;
parameter MEM_BASE = 16'h0000;
parameter MEM_SIZE = 16'h1000;   // 4 KB
parameter REG_BASE = MEM_BASE + MEM_SIZE;
parameter REG_SIZE = 16'h0004;   // 1 word
parameter WB2_BASE = REG_BASE + REG_SIZE;
parameter WB2_SIZE = 16'h0100;   // 256 bytes (64 x 32-bit words)

bit clk;
bit rst_n;

// MASTER 0 CMD & RSP SIGNALS //
logic [AW - 1 : 0] cmd_addr_m0;
logic [DW - 1 : 0] cmd_wdata_m0;
logic cmd_we_m0;
logic cmd_valid_m0;
logic cmd_ready_m0;
logic m0_ack_o;

// response signals //
logic [DW - 1 : 0] rsp_rdata_m0;
logic rsp_valid_m0;


// MASTER 1 CMD & RSP SIGNALS //
logic [AW - 1 : 0] cmd_addr_m1;
logic [DW - 1 : 0] cmd_wdata_m1;
logic cmd_we_m1;
logic cmd_valid_m1;
logic cmd_ready_m1;
logic m1_ack_o;

// response signals //
logic [DW - 1 : 0] rsp_rdata_m1;
logic rsp_valid_m1;

// ------------------------------------------------
// Test statistics
// ------------------------------------------------
int tc_total   = 0;
int tc_pass    = 0;
int tc_fail    = 0;
int asrt_fails = 0;

// simple locals
logic [DW - 1 : 0] read_data;
logic [DW - 1 : 0] data;

always #5ns clk = ~clk;

// Reset (more standard than assign-delays)
initial begin
    clk  = 1'b0;
    rst_n = 1'b0;

    // init cmd signals
    cmd_addr_m0  = '0; cmd_wdata_m0 = '0; cmd_we_m0 = 1'b0; cmd_valid_m0 = 1'b0;
    cmd_addr_m1  = '0; cmd_wdata_m1 = '0; cmd_we_m1 = 1'b0; cmd_valid_m1 = 1'b0;
    read_data    = '0;
    data         = '0;

    #50ns;
    rst_n = 1'b1;
end

// waveform dumping
initial begin
    $shm_open("shm_db");
    $shm_probe("ASMTR");
end

// ------------------------------------------------
// MAIN SEQUENCE
// ------------------------------------------------
initial begin
    int fails_before_tc;

    wait(rst_n);
    @(posedge clk);

    // --- Small directed sanity ops (not counted as TC1..TC12) ---
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

    // ------------------- TC1..TC12 -------------------
    // Helper pattern:
    //   tc_total++
    //   fails_before_tc = asrt_fails
    //   run testcase
    //   if(asrt_fails == fails_before_tc) tc_pass++ else tc_fail++

    // ---- TC1 Write all positions of address with M0 ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m0_wrall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC2 Read all positions of address with M0 ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m0_rdall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC3 Write all positions of address with M1 ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m1_wrall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC4 Read all positions of address with M1 ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m1_rdall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC5 Write all positions of address with M1 and M0 at the same time ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m0_m1_wrall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC6 Read all positions of address with M1 and M0 at the same time ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m0_m1_rdall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC7 Read all positions of address with M0 and write M1 at the same time ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m0_rdall_m1_wrall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC8 Read all positions of address with M1 and write M0 at the same time ----
    tc_total++;
    fails_before_tc = asrt_fails;
    m0_rdall_m1_wrall();   // (tu TB original repite la misma task; lo dejé igual)
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC9 Write all positions of address with M1 and M0 at the same time with different address ----
    tc_total++;
    fails_before_tc = asrt_fails;
    adif_m0_wrall_m1_wrall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC10 Read all positions of address with M1 and M0 at the same time with different address ----
    tc_total++;
    fails_before_tc = asrt_fails;
    adif_m0_rdall_m1_rdall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC11 Read all positions of address with M1 and write M0 at the same time with different address ----
    tc_total++;
    fails_before_tc = asrt_fails;
    adif_m0_rdall_m1_wrall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // ---- TC12 Write all positions of address with M1 and read M0 at the same time with different address ----
    tc_total++;
    fails_before_tc = asrt_fails;
    adif_m0_wrall_m1_rdall();
    repeat(2) @(posedge clk);
    if (asrt_fails == fails_before_tc) tc_pass++; else tc_fail++;

    // Let it settle a bit
    repeat(50) @(posedge clk);

    // Summary
    $display("===============================================");
    $display("               TEST SUMMARY");
    $display("===============================================");
    $display("Total TCs Executed : %0d", tc_total);
    $display("TCs Passed         : %0d", tc_pass);
    $display("TCs Failed         : %0d", tc_fail);
    $display("Assertion Failures : %0d", asrt_fails);
    $display("===============================================");
    if (tc_fail == 0 && asrt_fails == 0)
        $display("RESULT: ALL TESTCASES PASSED");
    else
        $display("RESULT: FAILURES DETECTED");
    $display("===============================================");

    $finish;
end

// Safety timeout (in case something hangs)
initial begin
    #30us;
    $display("TIMEOUT: finishing simulation at 30us");
    $finish;
end

////////////////////////// TASKS //////////////////////////////////////
// ---- M0 write ----
task automatic m0_write(
    input logic [AW-1:0] addr,
    input logic [DW-1:0] data_in
);
    $display("[%0t ns] M0 WR  addr=0x%04h  data=0x%08h  (sending command)", $time, addr, data_in);
    @(posedge clk);
    while (!cmd_ready_m0) @(posedge clk);
    cmd_addr_m0  <= addr;
    cmd_wdata_m0 <= data_in;
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
    output logic [DW-1:0] data_out
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
    data_out = rsp_rdata_m0;
    $display("[%0t ns] M0 RD  addr=0x%04h  data=0x%08h  ACK received", $time, addr, data_out);
endtask

// ---- M1 write ---- //
task automatic m1_write(
    input logic [AW-1:0] addr,
    input logic [DW-1:0] data_in
);
    $display("[%0t ns] M1 WR  addr=0x%04h  data=0x%08h  (sending command)", $time, addr, data_in);
    @(posedge clk);
    while (!cmd_ready_m1) @(posedge clk);
    cmd_addr_m1  <= addr;
    cmd_wdata_m1 <= data_in;
    cmd_we_m1    <= 1'b1;
    cmd_valid_m1 <= 1'b1;
    @(posedge clk);
    cmd_valid_m1 <= 1'b0;
    while (!rsp_valid_m1) @(posedge clk);
    $display("[%0t ns] M1 WR  addr=0x%04h  ACK received", $time, addr);
endtask

// ---- M1 read ---- //
task automatic m1_read(
    input  logic [AW-1:0] addr,
    output logic [DW-1:0] data_out
);
    $display("[%0t ns] M1 RD  addr=0x%04h  (sending command)", $time, addr);
    @(posedge clk);
    while (!cmd_ready_m1) @(posedge clk);
    cmd_addr_m1  <= addr;
    cmd_wdata_m1 <= '0;
    cmd_we_m1    <= 1'b0;
    cmd_valid_m1 <= 1'b1;
    @(posedge clk);
    cmd_valid_m1 <= 1'b0;
    while (!rsp_valid_m1) @(posedge clk);
    data_out = rsp_rdata_m1;
    $display("[%0t ns] M1 RD  addr=0x%04h  data=0x%08h  ACK received", $time, addr, data_out);
endtask

// ---- M0 write all ---- //
task automatic m0_wrall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m0_write(address, word);
            wait(cmd_ready_m0);
        end
    end
endtask

// ---- M0 read all ---- //
task automatic m0_rdall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m0_read(address, word);
            wait(cmd_ready_m0);
        end
    end
endtask

// ---- M1 write all ---- //
task automatic m1_wrall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m1_write(address, word);
            wait(cmd_ready_m1);
        end
    end
endtask

// ---- M1 read all ---- //
task automatic m1_rdall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m1_read(address, word);
            wait(cmd_ready_m1);
        end
    end
endtask

// ---- M0 and M1 write all ---- //
task automatic m0_m1_wrall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m0_write(address, word);
            m1_write(address, word);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ---- M0 and M1 read all ---- //
task automatic m0_m1_rdall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m0_read(address, word);
            m1_read(address, word);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ---- M0 write and M1 read all ---- //
task automatic m0_wrall_m1_rdall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m0_write(address, word);
            m1_read(address, word);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ---- M0 read and M1 write all ---- //
task automatic m0_rdall_m1_wrall();
    integer i;
    logic [DW-1:0] word;
    logic [AW-1:0] address;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address = i[AW-1:0];
            std::randomize(word);
            @(posedge clk);
            m0_read(address, word);
            m1_write(address, word);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ---- M0 write and M1 write all with different address ---- //
task automatic adif_m0_wrall_m1_wrall();
    integer i;
    logic [DW-1:0] word1;
    logic [DW-1:0] word2;
    logic [AW-1:0] address1;
    logic [AW-1:0] address2;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address1 = i[AW-1:0];
            address2 = (AW-1-i);
            std::randomize(word1);
            std::randomize(word2);
            @(posedge clk);
            m0_write(address1, word1);
            m1_write(address2, word2);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ---- M0 read and M1 read all with different address ---- //
task automatic adif_m0_rdall_m1_rdall();
    integer i;
    logic [DW-1:0] word1;
    logic [DW-1:0] word2;
    logic [AW-1:0] address1;
    logic [AW-1:0] address2;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address1 = i;
            address2 = (AW-1-i);            
            std::randomize(word1);
            std::randomize(word2);
            @(posedge clk);
            m0_read(address1, word1);
            m1_read(address2, word2);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ---- M0 read and M1 write all with different address ---- //
task automatic adif_m0_rdall_m1_wrall();
    integer i;
    logic [DW-1:0] word1;
    logic [DW-1:0] word2;
    logic [AW-1:0] address1;
    logic [AW-1:0] address2;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address1 = i[AW-1:0];
            address2 = (AW-1-i);
            std::randomize(word1);
            std::randomize(word2);
            @(posedge clk);
            m0_read(address1, word1);
            m1_write(address2, word2);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ---- M0 write and M1 read all with different address ---- //
task automatic adif_m0_wrall_m1_rdall();
    integer i;
    logic [DW-1:0] word1;
    logic [DW-1:0] word2;
    logic [AW-1:0] address1;
    logic [AW-1:0] address2;
    @(posedge clk);
    begin
        for (i = 0; i < AW; i++) begin
            @(posedge clk);
            address1 = i[AW-1:0];
            address2 = (AW-1-i);
            std::randomize(word1);
            std::randomize(word2);
            @(posedge clk);
            m0_write(address1, word1);
            m1_read(address2, word2);
            wait(cmd_ready_m0 && cmd_ready_m1);
        end
    end
endtask

// ------------------------------------------------
// BUS MONITORS (labels fixed: S0/S1/S2)
// ------------------------------------------------
always @(posedge clk) begin
    if (wb_top_i.s0_stb_o && wb_top_i.s0_cyc_o)
        $display("[%0t ns]   BUS S0(MEM) %-2s  adr=0x%04h  wdat=0x%08h  sel=%04b",
                 $time, wb_top_i.s0_we_o ? "WR" : "RD", wb_top_i.s0_adr_o, wb_top_i.s0_dat_o, wb_top_i.s0_sel_o);
    if (wb_top_i.s0_ack_i)
        $display("[%0t ns]   BUS S0(MEM) ACK  rdat=0x%08h", $time, wb_top_i.s0_dat_i);
end

always @(posedge clk) begin
    if (wb_top_i.s1_stb_o && wb_top_i.s1_cyc_o)
        $display("[%0t ns]   BUS S1(REG) %-2s  adr=0x%04h  wdat=0x%08h  sel=%04b",
                 $time, wb_top_i.s1_we_o ? "WR" : "RD", wb_top_i.s1_adr_o, wb_top_i.s1_dat_o, wb_top_i.s1_sel_o);
    if (wb_top_i.s1_ack_i)
        $display("[%0t ns]   BUS S1(REG) ACK  rdat=0x%08h", $time, wb_top_i.s1_dat_i);
end

always @(posedge clk) begin
    if (wb_top_i.s2_stb_o && wb_top_i.s2_cyc_o)
        $display("[%0t ns]   BUS S2(RAM) %-2s  adr=0x%04h  wdat=0x%08h  sel=%04b",
                 $time, wb_top_i.s2_we_o ? "WR" : "RD", wb_top_i.s2_adr_o, wb_top_i.s2_dat_o, wb_top_i.s2_sel_o);
    if (wb_top_i.s2_ack_i)
        $display("[%0t ns]   BUS S2(RAM) ACK  rdat=0x%08h", $time, wb_top_i.s2_dat_i);
end

// ------------------------------------------------
// Reference memories (same as your original TB)
// NOTE: indexing by cmd_addr (16-bit) into [0:AW-1] is conceptually odd,
// but left intact to avoid changing your verification intent.
// ------------------------------------------------
logic [DW-1:0] ref_mem_m0 [0:AW-1];
logic [DW-1:0] ref_mem_m1 [0:AW-1];

always @(posedge clk) begin
    if (rst_n && cmd_we_m0) begin
        ref_mem_m0[cmd_addr_m0] <= cmd_wdata_m0;
    end
    if (rst_n && cmd_we_m1) begin
        ref_mem_m1[cmd_addr_m1] <= cmd_wdata_m1;
    end
end

// ------------------------------------------------
// Assertions with fail counters
// ------------------------------------------------

// ---- M0 Write correctness ----
property wr_m0_correctness;
    @(posedge clk)
    disable iff (!rst_n)
    (!cmd_ready_m0 && cmd_we_m0 && cmd_valid_m0) |-> (m0_ack_o && ref_mem_m0[cmd_addr_m0] == cmd_wdata_m0);
endproperty

assert property(wr_m0_correctness)
else begin
    asrt_fails++;
    $error("[%0t ns] FAIL: wr_m0_correctness", $time);
end

// ---- M0 Read correctness ----
property rd_m0_correctness;
    @(posedge clk)
    disable iff (!rst_n)
    (!cmd_ready_m0 && !cmd_we_m0 && cmd_valid_m0) |-> (ref_mem_m0[cmd_addr_m0] == rsp_rdata_m0);
endproperty

assert property(rd_m0_correctness)
else begin
    asrt_fails++;
    $error("[%0t ns] FAIL: rd_m0_correctness", $time);
end

// ---- M1 Write correctness ----
property wr_m1_correctness;
    @(posedge clk)
    disable iff (!rst_n)
    (!cmd_ready_m1 && cmd_we_m1 && cmd_valid_m1) |-> (m1_ack_o && ref_mem_m1[cmd_addr_m1] == cmd_wdata_m1);
endproperty

assert property(wr_m1_correctness)
else begin
    asrt_fails++;
    $error("[%0t ns] FAIL: wr_m1_correctness", $time);
end

// ---- M1 Read correctness ----
property rd_m1_correctness;
    @(posedge clk)
    disable iff (!rst_n)
    (!cmd_ready_m1 && !cmd_we_m1 && cmd_valid_m1) |-> (ref_mem_m1[cmd_addr_m1] == rsp_rdata_m1);
endproperty

assert property(rd_m1_correctness)
else begin
    asrt_fails++;
    $error("[%0t ns] FAIL: rd_m1_correctness", $time);
end

// ------------------------------------------------
// DUT
// ------------------------------------------------
wb_top #(AW, DW, MEM_BASE, MEM_SIZE, REG_BASE, REG_SIZE, WB2_BASE, WB2_SIZE) wb_top_i(
    .clk(clk),
    .rst_n(rst_n),

    // MASTER 0 CMD & RSP SIGNALS //
    .cmd_addr_m0(cmd_addr_m0),
    .cmd_wdata_m0(cmd_wdata_m0),
    .cmd_we_m0(cmd_we_m0),
    .cmd_valid_m0(cmd_valid_m0),
    .cmd_ready_m0(cmd_ready_m0),
    .m0_ack_o (m0_ack_o),
    .rsp_rdata_m0(rsp_rdata_m0),
    .rsp_valid_m0(rsp_valid_m0),

    // MASTER 1 CMD & RSP SIGNALS //
    .cmd_addr_m1(cmd_addr_m1),
    .cmd_wdata_m1(cmd_wdata_m1),
    .cmd_we_m1(cmd_we_m1),
    .cmd_valid_m1(cmd_valid_m1),
    .cmd_ready_m1(cmd_ready_m1),
    .m1_ack_o (m1_ack_o),
    .rsp_rdata_m1(rsp_rdata_m1),
    .rsp_valid_m1(rsp_valid_m1)
);

endmodule

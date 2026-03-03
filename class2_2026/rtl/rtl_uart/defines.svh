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

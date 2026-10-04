
module cpu_wrapper (input logic clk, input logic reset, input logic rx, output logic tx);
logic uartclkref,uartclk,mclkref,mclk,mclk3;
logic[1:0] clkstate;
logic[7:0] uartdata;
CC_PLL #(
	.REF_CLK(10.0),
	.OUT_CLK(2.4576),
	.LOW_JITTER(1),
	.LOCK_REQ(1),
	.CLK270_DOUB(0),
	.CLK180_DOUB(0),
	) pll_uart (
	.CLK_REF(clk),
	.CLK_FEEDBACK(uartclkref),
	.USR_LOCKED_STDY_RST(reset),
	.CLK0(uartclk),
	.CLK_REF_OUT(uartclkref)
	);
CC_PLL #(
	.REF_CLK(10.0),
	.OUT_CLK(28.63636),
	.LOW_JITTER(1),
	.LOCK_REQ(1),
	.CLK270_DOUB(0),
	.CLK180_DOUB(0),
	) pll_mclk (
	.CLK_REF(clk),
	.CLK_FEEDBACK(mclkref),
	.USR_LOCKED_STDY_RST(reset),
	.CLK0(mclk),
	.CLK_REF_OUT(mclkref)
	);

logic[31:0] adbus, address;
logic read, write, validaddr, validdata, uartcs;
logic[1:0] buswidth;

logic[31:0] ram[32767:0];
logic[31:0] rom[8191:0];

initial begin
	$readmemh("rom.hex",rom);
	end

always_ff @(posedge mclk)
	case (clkstate)
		0: clkstate <= 1;
		1: clkstate <= 2;
		0: clkstate <= 0;
	endcase

always_comb
	if (clkstate == 0)
		mclk3 = 1;
	else
		mclk3 = 0;

//System
processor_core ma10k(mclk3, reset,
			validaddr, validdata, read, write, buswidth,
			adbus);

uartmod uart(uartclk, reset, address[1:0], write, read, uartcs, rx, 
		tx,
		uartdata);

//Address demux
always_ff @(negedge validaddr)
	address <= adbus;

//Decoding logic
always_comb
	if (address < 'h8000)
		if(read & validdata)
			begin
				adbus = rom[address[31:2]];
				uartdata = 'hZ;
			end
		else
			begin
				adbus = 'hZ;
				uartdata = 'hZ;
			end
	
	else if (address >= 'hFFFE0000)
		if (read & validdata)
			begin
				adbus = ram[address[31:2]];
				uartdata = 'hZ;
			end
		else
			begin
				adbus = 'hZ;
				uartdata ='hZ;
			end

	else if (address == 'h0000FFFF)
		if (read)
			begin
				adbus = {24'h0,uartdata};
				uartdata = 'hZ;
			end
		else if (write)
			begin
				adbus = 'hZ;
				uartdata = adbus[7:0];
			end
		else
			begin
				uartdata = 'hZ;
				adbus = 'hZ;
			end
	else
		begin
			uartdata = 'hZ;
			adbus = 'hZ;
		end

always_ff @(negedge write)
	if (validdata)
		if (address >= 'hFFFE0000)
			ram[address[31:2]] <= adbus;

endmodule

module uartmod(input logic clk, input logic reset, input logic[1:0] addr, input logic write, input logic read, input logic cs, input logic rx, 
		output logic tx,
		inout logic[7:0] data);
logic dividedclk, clkdivider;
logic[7:0] clkcounter, registers[3:0];
logic rxstate;
logic[1:0] txstate;
logic[3:0] rxcount, txcount;

localparam IDLE = 0;
localparam DATAIN = 1;

localparam START = 1;
localparam DATA = 2;
localparam STOP = 3;

//Clock generation
always_ff @(posedge clk)
	if (reset)
		clkcounter <= 0;
	else
		clkcounter <= clkcounter + 1;
always_comb
	if (dividedclk == registers[1])
		clkdivider = 1;
	else
		clkdivider = 0;

always_ff @(posedge clkdivider)
	dividedclk <= ~dividedclk; 

//UART RX State machine
always_ff @(negedge dividedclk)
	begin
		if (reset)
			begin
				rxstate <= IDLE;
				registers <= '{0,0,0,0};
			end
		case (rxstate)
			IDLE: if (~rx)
				rxstate <= DATAIN;
			DATAIN: if (rxcount <= registers[0][3:0])
					begin
						rxcount <= rxcount + 1;
						registers[2] <= {registers[2][6:0],rx};
					end
				else if (rxcount == registers[0][3:0] + 1)
					begin
						if (registers[0][4])
							registers[3][0] <= rx;
						else if (~registers[0][4] & rx)
							rxcount <= 0;
							rxstate <= IDLE;
					end
		endcase
		//TX state machine
		case (txstate)
			IDLE: if (write & addr == 1)
				txstate <= START;
			START: txstate <= DATA;
			DATA: if (txcount < registers[0][3:0])
				txcount <= txcount + 1;
			else if (txcount == registers[0][3:0])
					txstate <= STOP;
			STOP: txstate <= IDLE;
		endcase
	end

always_comb
	begin
		case(txstate)
			IDLE: tx = 1;
			START: tx = 0;
			DATA: tx = registers[1][txcount];
			STOP: tx = 1;
			default: tx = 1;
		endcase
		
		if (read & cs)
			data = registers[addr];
		else
			data = 'hZ;
	end
endmodule

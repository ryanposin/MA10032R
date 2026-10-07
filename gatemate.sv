
module cpu_wrapper (input logic mclk, input logic reset, input logic rx, output logic tx);

logic cpuclk, uartclk,c2,locked;

pll clkpll(
	reset,
	mclk,
	cpuclk,
	uartclk,
	c2,
	locked);

logic[1:0] clkstate;
wire[7:0] uartdata;

logic[31:0] adbus, address, adbusi;
logic read, write, validaddr, validdata, uartcs;
logic[1:0] buswidth;

logic[31:0] ram[32767:0];
(* ram_init_file = "echo.mif" *) logic[31:0] rom[8191:0];

//System
processor_core ma10k(cpuclk, ~reset,
			validaddr, validdata, read, write, buswidth,
			adbus);

uartmod uart(uartclk, reset, address[1:0], write, read, uartcs, rx, 
		tx,
		uartdata);

always_comb 
	if (read & validdata & ~write)
		adbus =  adbusi;
	else
		adbus = 'hz;

//Address demux
always_ff @(negedge validaddr)
	address <= adbus;

//Decoding logic
always_comb
	if (address < 'h8000)
		if(read & validdata & ~write)
			begin
				adbusi = rom[address[31:2]];
				uartdata = 'hZ;
			end
		else
			begin
				adbusi = 'hZ;
				uartdata = 'hZ;
			end
	
	else if (address >= 'hFFFE0000)
		if (read & validdata & ~write)
			begin
				adbusi = ram[address[31:2]];
				uartdata = 'hZ;
			end
		else
			begin
				adbusi = 'hZ;
				uartdata ='hZ;
			end

	else if (address <= 'h0000FFFC & address <= 'h0000FFFF)
		if (read & validdata & ~write)
			begin
				adbusi = {24'h0,uartdata};
				uartdata = 'hZ;
			end
		else if (write & validdata & ~read)
			begin
				adbusi = 'hZ;
				uartdata = adbus[7:0];
			end
		else
			begin
				uartdata = 'hZ;
				adbusi = 'hZ;
			end
	else
		begin
			uartdata = 'hZ;
			adbusi = 'hZ;
		end

always_ff @(negedge write)
	if (validdata)
		if (address >= 'hFFFE0000)
			ram[address[31:2]] <= adbusi;

endmodule

module uartmod(input logic clk, input logic reset, input logic[1:0] addr, input logic write, input logic read, input logic cs, input logic rx, 
		output logic tx,
		inout logic[7:0] data);
logic dividedclk, clkdivider;
logic[7:0] clkcounter, registers[4:0];
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
	if (~reset)
		begin
			clkcounter <= 0;
			registers[0] <= 8'b0;
			registers[1] <= 8'b0;
			registers[4] <= 8'b0;
		end
	else
		begin
			clkcounter <= clkcounter + 1;
			if (addr == 0 & write)
				registers[0] <= data;
			else if (addr == 1 & write)
				registers[1] <= data;
			else if (addr == 4 & write)
				registers[4] <= data;
		end
always_comb
	if (dividedclk == registers[1])
		clkdivider = 1;
	else
		clkdivider = 0;

always_ff @(posedge clkdivider)
	begin
		dividedclk <= ~dividedclk; 
	end

//UART RX State machine
always_ff @(negedge dividedclk)
	begin

		if (~reset)
			begin
				rxstate <= IDLE;
				registers[2] <= 8'b0;
				registers[3] <= 8'b0;

			end
		else
			begin	
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
		end

always_comb
	begin
		case(txstate)
			IDLE: tx = 1;
			START: tx = 0;
			DATA: tx = registers[4][txcount];
			STOP: tx = 1;
			default: tx = 1;
		endcase
		
		if (read & cs)
			data = registers[addr];
		else
			data = 'hZ;
	end
endmodule

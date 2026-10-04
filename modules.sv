/* verilator lint_off UNOPTFLAT*/
//Special register, for SP and PC
//Input: clk, reset, increment, decrement, write enable, d
//Output: q
module ma10k_special_reg (input wire clk, input wire reset, input wire inc, input wire dec, input wire we, input logic[31:0] d, output logic[31:0] q);
	always_ff @(negedge clk)//, posedge we)
		begin
			if (reset)
				q <= 0;
			else
				if (we)
				q <= d;
				else if (dec)
				q <= q - 1;
				else if (inc)
					q <= q + 1;
				else if (inc & dec)
					q <= q;
			
		end
endmodule

//32 bit 2:1 MUX
module ttb2inmux (input wire[31:0] i0, input wire[31:0] i1, input wire select, output logic[31:0] q);
	always_comb
		q = select ? i1 : i0; 
endmodule

//32 bit 4:1 MUX
module ttb4inmux (input wire[31:0] i0, input wire[31:0] i1, input wire[31:0] i2, input wire[31:0] i3, input wire[1:0] select, output logic[31:0] q);
	always_comb
		q = select[1] ? (select[0] ? i3 : i2) : (select[0] ? i1 : i0);
endmodule

module ob4inmux (input wire i0, input wire i1, input wire i2, input wire i3, input wire[1:0] select, output logic q);
	always_comb
		q = select[1] ? (select[0] ? i3 : i2) : (select[0] ? i1 : i0);
endmodule

//Register file with hardwired ZERO register (R0), R1-R15 are general purpose 
//Input: clk, reset, portasel, portbsel, writesel, writeenable, writeinput[31:0]
//Output: a, b 
module regfile (input logic clk, input logic reset, input wire[3:0] portasel, input wire[3:0] portbsel, input wire[3:0] writesel, input wire we, input wire[31:0] writeinput, output logic[31:0] a, output logic[31:0] b);

logic[31:0] registers[15:0];

	always_ff @(negedge clk)
		begin
			if (reset)
				registers <= '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
			else if (we & (writesel != 0))
				registers[writesel[3:0]] <= writeinput;
		end
	always_comb
		begin
			a = registers[portasel];
			b = registers[portbsel];
		end
endmodule

//Custom ALU implementation
module alumod (input wire[2:0] s, input wire m, input wire[31:0] a, input wire[31:0] b, output logic[31:0] dout, output logic lt, output logic eq);

	always_comb
		begin
			//Branching flags
			if (a < b)
				lt = 1; //If less than
			else
				lt = 0;

			if (a == b)
				eq = 1; //If equal to
			else
				eq = 0;


			case (m)
				1'b0:
					case (s)
						//Arithmetic
						3'b000:	dout = a - b;
						3'b001:	dout = a + b;
						3'b010: dout = a;
						3'b011: dout = b;
						3'b100: dout = a + 1;	
						default:	dout = 0; 
					endcase
				1'b1:
					case (s)
						//Logic
						3'b000: dout = ~a;	
						3'b001:	dout = a & b;
						3'b010: dout = a | b;
						3'b011:	dout = a ^ b;
						3'b100:	dout = ~(a & b);
						3'b101:	dout = ~(a | b);
						3'b110:	dout = ~(a ^ b);
						3'b111:	dout = 0;
						default:	dout = 0; 
					endcase
			endcase
		end
endmodule

//Shifter unit
//Inputs: clk, reset, shifttype, shiftamt
//Outputs: stalldispatch, shiftdone, shiftout
module shifter_unit(input wire clk, input wire reset, input wire shiften, input wire[31:0] a, input wire[4:0] shiftamt, input logic shiftdir, input logic signextendsel, input logic rotate, output logic stalldispatchout, output logic shiftdone, output logic[31:0] shiftout);
localparam WAITING = 0;
localparam SHIFT1 = 1;
localparam SHIFT2 = 2;
localparam SHIFT4 = 3;
localparam SHIFT8 = 4;
localparam SHIFT16 = 5;

logic[2:0] shiftstate;
logic signextend, shift1sel, shift2sel, shift4sel, shift8sel, shift16sel, notfirstcycle;
logic[31:0] amuxout, shift1out, shift2out, shift4out, shift8out, shift16out, shift1unit, shift2unit, shift4unit, shift8unit, shift16unit;
logic rotate1, shift1rot;
logic[1:0] rotate2, shift2rot;
logic[3:0] rotate4, shift4rot;
logic[7:0] rotate8, shift8rot;
logic[15:0] rotate16, shift16rot;

always_ff @(posedge clk)
	begin
		if (reset)
			shiftstate <= WAITING;
		else if (shiften)
			case (shiftstate)
				WAITING: if (shiftamt[4] == 'b1)
						shiftstate <= SHIFT16;
					else if (shiftamt[4:3] == 'b01)
						shiftstate <= SHIFT8;
					else if (shiftamt[4:2] == 'b001)
						shiftstate <= SHIFT4;
					else if (shiftamt[4:1] == 'b0001)
						shiftstate <= SHIFT2;
					else if (shiftamt[4:0] == 'b00001)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT16: if (shiftamt[3] == 'b1)
						shiftstate <= SHIFT8;
					else if (shiftamt[3:2] == 'b01)
						shiftstate <= SHIFT4;
					else if (shiftamt[3:1] == 'b001)
						shiftstate <= SHIFT2;
					else if (shiftamt[3:0] == 'b0001)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT8: if (shiftamt[2] == 'b1)
						shiftstate <= SHIFT4;
					else if (shiftamt[2:1] == 'b01)
						shiftstate <= SHIFT2;
					else if (shiftamt[2:0] == 'b001)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT4: if (shiftamt[1] == 'b1)
						shiftstate <= SHIFT2;
					else if (shiftamt[1] == 'b01)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT2: if (shiftamt[0] == 'b1)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT1: shiftstate <= WAITING;
			endcase

		shiftout <= shift1out | shift2out | shift4out  | shift8out | shift16out;

		if (shiftstate == SHIFT16 | shiftstate == SHIFT8 | shiftstate == SHIFT4 | shiftstate == SHIFT2 | shiftstate == SHIFT1 & ~notfirstcycle )
			notfirstcycle <= 1;
		else if (reset | shiftstate == WAITING)
			notfirstcycle <= 0;
	end

	always_comb
		begin
			if (shiftstate == SHIFT16 | shiftstate == SHIFT8 | shiftstate == SHIFT4 | shiftstate == SHIFT2 | shiftstate == SHIFT1 | ~notfirstcycle)
				stalldispatchout = 1;
			else
				stalldispatchout = 0;

			case (shiftstate)
				SHIFT16: begin
					shift16sel =  1'b1;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel =  1'b0;
				end
				SHIFT8: begin
					shift16sel =  1'b0;
					shift8sel =  1'b1;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel =  1'b0;
				end
				SHIFT4: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b1;
					shift2sel =  1'b0;
					shift1sel =  1'b0;
				end
				SHIFT2: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b1;
					shift1sel =  1'b0;
				end
				SHIFT1: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel = 1'b1;
				end
				default: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel = 1'b0;
				end
			endcase
			amuxout = notfirstcycle ? shiftout : a;  

			signextend = signextendsel ? a[31] : 0;

			rotate1 = shiftdir ? amuxout[31] : amuxout[0];
			rotate2 = shiftdir ? amuxout[31:30] : amuxout[1:0];
			rotate4 = shiftdir ? amuxout[31:28] : amuxout[3:0];
			rotate8 = shiftdir ? amuxout[31:24] : amuxout[7:0];
			rotate16 = shiftdir ? amuxout[31:16] : amuxout[15:0];

			shift1rot = rotate ? rotate1 : signextend;
			shift2rot = rotate ? rotate2 : {2{signextend}};
			shift4rot = rotate ? rotate4 : {4{signextend}};
			shift8rot = rotate ? rotate8 : {8{signextend}};
			shift16rot = rotate ? rotate16 : {16{signextend}};
			
			shift1unit = shiftdir ? {shift1rot, amuxout[31:1]} : {amuxout[30:0], shift1rot}; //right : left
			shift2unit = shiftdir ? {shift2rot, amuxout[31:2]} : {amuxout[29:0], shift2rot};
			shift4unit = shiftdir ? {shift4rot, amuxout[31:4]} : {amuxout[27:0], shift4rot};
			shift8unit = shiftdir ? {shift8rot, amuxout[31:8]} : {amuxout[23:0], shift8rot};
			shift16unit = shiftdir ? {shift16rot, amuxout[31:16]} : {amuxout[15:0], shift16rot};

			shift1out = shift1sel ? shift1unit : 'h0; 
			shift2out = shift2sel ? shift2unit : 'h0;
			shift4out = shift4sel ? shift4unit : 'h0;
			shift8out = shift8sel ? shift8unit : 'h0;
			shift16out = shift16sel ? shift16unit : 'h0;
		end
endmodule

module multiplier_unit (input wire clk, input wire reset, input wire[31:0] a, input wire[31:0] b, input wire[1:0] muxas, input wire[1:0] muxbs, input wire[2:0] demuxs, input wire highlow, input wire accumulate, output logic[31:0] multout);
	
	logic[7:0] multina;
	logic[7:0] multinb;
	logic[15:0] multtempout;
	logic[63:0] demux;
	logic[63:0] productreg;
	logic carry;

	//8x8 multiplier input MUXes 
	always_comb
		begin
			//00 - 7:0
			//01 - 15:8
			//10 - 23:16
			//11 - 31:24
			multina = muxas[1] ? (muxas[0] ? a[31:24] : a[23:16]) : (muxas[0] ? a[15:8] : a[7:0]);   
			multinb = muxbs[1] ? (muxbs[0] ? b[31:24] : b[23:16]) : (muxbs[0] ? b[15:8] : b[7:0]); 
		end

	assign multtempout = multina * multinb; //Multiply
	
	//Demux multiplier to 64 bit register
	always_comb
		case (demuxs)
			3'b000: demux = {48'b0, multtempout};
			3'b001: demux = {40'b0, multtempout, 8'b0};
			3'b010: demux = {32'b0,multtempout, 16'b0};
			3'b011: demux = {24'b0,multtempout, 24'b0};
			3'b100: demux = {16'b0,multtempout, 32'b0};
			3'b101: demux = {8'b0, multtempout, 40'b0};
			3'b110: demux = {multtempout,48'b0};
			default: demux = 0;
		endcase
	
	//Accumulate
	always_ff @(negedge clk)
		begin
			if (accumulate)
				productreg <= productreg + demux;
			if (reset)
				productreg <= 0;
		end
	always_comb multout = highlow ? productreg[63:32] : productreg[31:0];
endmodule


//Bus unit
//Inputs: clk, reset, qfull, memreq, memreqdir, memaddr, programcounter
//Outputs: validaddr, validdata, read, write, incprefetch, toprefetch, memwait, incpc
//Inout: adbus, memdata
module busunit(input logic clk, input logic reset, input logic qfull, input logic memreq, input logic memreqdir, input logic[31:0] memaddr, input logic[31:0] programcounter, input logic[1:0] buswidth, output logic validaddr, output logic validdata, output logic read, output logic write, output logic incprefetch, output logic[31:0] toprefetch, output logic memwait, output logic incpc, output logic memfinished, output logic[31:0] pcchain, inout logic[31:0] adbus, inout logic[31:0] memdata);

	logic[2:0] busstate;
	logic[31:0] memdatatemp;
	localparam HIGHZ = 3'h0;
	localparam OUTPUTPC = 3'h1;
	localparam LATCHINST = 3'h2;
	localparam OUTPUTMEM = 3'h3;
	localparam OUTPUTDATA = 3'h4;
	localparam LATCHDATA = 3'h5;

	always_ff @(posedge clk)
		begin
			if (reset)
				begin
					busstate <= HIGHZ;
				end
			case (busstate)
				HIGHZ: if (~memreq & qfull)
						busstate <= HIGHZ;
					else if (~memreq & ~qfull)
						busstate <= OUTPUTPC;
					else if (memreq)
						busstate <= OUTPUTMEM;
					else
						busstate <= OUTPUTPC;
				OUTPUTPC: busstate <= LATCHINST;
				LATCHINST: if (~memreq & qfull)
						busstate <= HIGHZ;
					else if (~memreq & ~qfull)
						busstate <= OUTPUTPC;
					else if (memreq)
						busstate <= OUTPUTMEM;
					else
						busstate <= OUTPUTPC;

				OUTPUTMEM:	if (memreqdir) //1 = output
							busstate <= OUTPUTDATA;
						else //0 = input
							busstate <= LATCHDATA;
				OUTPUTDATA: if (~memreq & qfull)
						busstate <= HIGHZ;
					else if (memreq)
						busstate <= OUTPUTMEM; 
					else
						busstate <= OUTPUTPC;
				LATCHDATA: if (~memreq & qfull)
						busstate <= HIGHZ;
					else if (memreq)
						busstate <= OUTPUTMEM;
					else
						busstate <= OUTPUTPC;
				default: busstate <= HIGHZ;
			endcase
		end	
	always_comb
			if (busstate == OUTPUTPC | busstate == LATCHINST)
				memwait = 1;
			else
				memwait = 0;
				
	always_comb	
			case(busstate)
			HIGHZ: begin
				toprefetch = 0;
				pcchain = 0;
				adbus = 'hZ;
				validaddr = 0;
				validdata = 0;
				read = 0;
				write = 0;
				incprefetch = 0;
				incpc = 0;
				memfinished = 0;
				memdata = 'hZ;
					end
			OUTPUTPC: begin
				toprefetch = 0;
				pcchain = 0;
				adbus = programcounter;
				validaddr = 1;
				validdata = 0;
				read = 1;
				write = 0;
				incprefetch = 0;
				incpc = 0;
				memfinished = 0;
				memdata = 'hZ;
			end
			LATCHINST: begin
					toprefetch = adbus;
					pcchain = programcounter;
					adbus = 'hZ;
					validaddr = 0;
					validdata = 1;
					read = 1;
					write = 0;
					incprefetch = 1;
					incpc = 1;
					memfinished = 0;
					memdata = 'hZ;
				end
			OUTPUTMEM: begin
				toprefetch = 0;
				pcchain = 0;
				adbus = memaddr;
				validaddr = 1;
				validdata = 0;
				read = 1;
				write = 0;
				incprefetch = 0;
				incpc = 0;
				memfinished = 0;
				memdata = 'hZ;
			end
			OUTPUTDATA: begin
					toprefetch = 0;
					pcchain = 0;
					case (buswidth)
						0: adbus = memreqdir ? {24'b0,memdata[7:0]} : 'hZ;
						1: adbus = memreqdir ? {16'b0,memdata[15:0]} : 'hZ;
						2: adbus = memreqdir ? memdata : 'hZ;
						default: adbus = 'hZ;
					endcase
					validaddr = 0;
					validdata = 1;
					read = 0;
					write = 1;
					incprefetch = 0;
					incpc = 0;
					memfinished = 1;
					memdata = 'hZ;
				end
			LATCHDATA: begin
					toprefetch = 0;
					pcchain = 0;
					adbus = 'hZ;
					validaddr = 0;
					validdata = 1;
					read = 1;
					write = 0;
					incprefetch = 0;
					incpc = 0;
					memfinished = 1;
					case (buswidth)
						0: memdata = {24'b0,adbus[7:0]};
						1: memdata = {16'b0,adbus[15:0]};
						2: memdata = adbus;
						default: memdata = 32'h0;
					endcase
				end
			default: begin
				toprefetch = 0;
				pcchain = 0;
				adbus = 'hZ;
				validaddr = 0;
				validdata = 0;
				read = 0;
				write = 0;
				incprefetch = 0;
				incpc = 0;
				memfinished = 0;
				memdata = 'hZ;
			end
			endcase
	//always_comb memdata = memreqdir ? 'hZ : adbus; 
	
endmodule

//Prefetch unit
//Inputs: clk, reset, instreq, instadd, insttoadd
//Outputs: qfull, tofetch
module prefetcher(input logic clk, input logic reset, input logic instreq, input logic instadd, input logic[31:0] insttoadd, input logic[31:0] pcchain, output logic qempty, output logic qfull, output logic[31:0] tofetch, output logic[31:0] programcounterinst);
	logic[2:0] ftrack;
	logic[2:0] instqcount[5:0];
	logic[31:0] instq[6];
	logic[31:0] pcq[6];
	localparam QEMPTY = 0;
	localparam Q1 = 1;
	localparam Q2 = 2;
	localparam Q3 = 3;
	localparam Q4 = 4;
	localparam Q5 = 5;
	localparam QFULL = 6;
	
	always_comb
		begin
			if (ftrack == QFULL)
				qfull = 1;
			else
				qfull = 0;

			if (ftrack == QEMPTY)
				qempty = 1;
			else
				qempty = 0;
		end
	

	always_comb
		if (instqcount[0] == 0)
			begin
				tofetch = instq[0];
				programcounterinst = pcq[0];
			end
		else if(instqcount[1] == 0)
			begin
				tofetch = instq[1];
				programcounterinst = pcq[1];
			end
		else if(instqcount[2] == 0)
			begin
				tofetch = instq[2];
				programcounterinst = pcq[2];
			end
		else if(instqcount[3] == 0)
			begin
				tofetch = instq[3];
				programcounterinst = pcq[3];
			end
		else if(instqcount[4] == 0)
			begin
				tofetch = instq[4];
				programcounterinst = pcq[4];
			end
		else if(instqcount[5] == 0)
			begin
				tofetch = instq[5];
				programcounterinst = pcq[5];
			end
		else
			begin
				tofetch = 'h0;
				programcounterinst = 'h0;
			end
	always_ff @(negedge clk)
		if (reset)
			ftrack <= QEMPTY;
		else
			case (ftrack)
				QEMPTY:
					if (instreq & instadd | ~instreq & ~instadd)
						ftrack <= QEMPTY;
					else if (instadd & ~instreq)
						ftrack <= Q1;
				Q1:	if (instreq & instadd | ~instreq & ~instadd)
						ftrack <= Q1;
					else if (instadd & ~instreq)
						ftrack <= Q2;
					else if (~instadd & instreq)
						ftrack <= QEMPTY;
				Q2:
					if (instreq & instadd | ~instreq & ~instadd)
						ftrack <= Q2;
					else if (instadd & ~instreq)
						ftrack <= Q3;
					else if (~instadd & instreq)
						ftrack <= Q1;
				Q3:
					if (instreq & instadd | ~instreq & ~instadd)
						ftrack <= Q3;
					else if (instadd & ~instreq)
						ftrack <= Q4;
					else if (~instadd & instreq)
						ftrack <= Q2;
				Q4:
					if (instreq & instadd | ~instreq & ~instadd)
						ftrack <= Q4;
					else if (instadd & ~instreq)
						ftrack <= Q5;
					else if (~instadd & instreq)
						ftrack <= Q3;
				Q5:
					if (instreq & instadd | ~instreq & ~instadd)
						ftrack <= Q5;
					else if (instadd & ~instreq)
						ftrack <= QFULL;
					else if (~instadd & instreq)
						ftrack <= Q4;
				QFULL:
					if (instreq & instadd | ~instreq & ~instadd)
						ftrack <= QFULL;
					else if (~instadd & instreq)
						ftrack <= Q5;
			endcase
	
	always_ff @(posedge clk)
		begin
			if (reset)
				begin
					instqcount <= '{'b111,'b111,'b111,'b111,'b111,'b111};
//					tofetch <= 0;
//					programcounterinst <= 0;
					instq <= '{0,0,0,0,0,0};
					pcq <= '{0,0,0,0,0,0};
				end
			else
			 	begin
			
			if (instreq)
				begin
					if (instqcount[0] == 0)
						begin
							instqcount[0] <= 3'b111;
//							tofetch <= instq[0];
//							programcounterinst <= pcq[0];
							instq[0] <= 0;
						end
					else if (instqcount[0] != 0 & instqcount[0] != 'b111)
						instqcount[0] <= instqcount[0] - 1;
				
					if (instqcount[1] == 0)
						begin
							instqcount[1] <= 3'b111;
//							tofetch <= instq[1];
//							programcounterinst <= pcq[1];
							instq[1] <= 0;
						end
					else if (instqcount[1] != 0 & instqcount[1] != 'b111)
						instqcount[1] <= instqcount[1] - 1;

					if (instqcount[2] == 0)
						begin
							instqcount[2] <= 3'b111;
//							tofetch <= instq[2];
//							programcounterinst <= pcq[2];
							instq[2] <= 0;
						end
					else if (instqcount[2] != 0 & instqcount[2] != 'b111)
						instqcount[2] <= instqcount[2] - 1;

					if (instqcount[3] == 0)
						begin
							instqcount[3] <= 3'b111;
//							tofetch <= instq[3];
//							programcounterinst <= pcq[3];
							instq[3] <= 0;
						end
					else if (instqcount[3] != 0 & instqcount[3] != 'b111)
						instqcount[3] <= instqcount[3] - 1;

					if (instqcount[4] == 0)
						begin
							instqcount[4] <= 3'b111;
//							tofetch <= instq[4];
//							programcounterinst <= pcq[4];
							instq[4] <= 0;
						end
					else if (instqcount[4] != 0 & instqcount[4] != 'b111)
						instqcount[4] <= instqcount[4] - 1;

					if (instqcount[5] == 0)
						begin
							instqcount[5] <= 3'b111;
//							tofetch <= instq[5];
//							programcounterinst <= pcq[5];
							instq[5] <= 0;
						end
					else if (instqcount[5] != 0 & instqcount[5] != 'b111)
						instqcount[5] <= instqcount[5] - 1;

				end
			if (instadd)
				begin
					if (instqcount[0] == 3'b111)
						begin
							instqcount[0] <= ftrack;
							instq[0] <= insttoadd;
							pcq[0] <= pcchain;
						end
					else if (instqcount[1] == 3'b111)
						begin
							instqcount[1] <= ftrack;
							instq[1] <= insttoadd;
							pcq[1] <= pcchain;
						end
					else if (instqcount[2] == 3'b111)
						begin
							instqcount[2] <= ftrack;
							instq[2] <= insttoadd;
							pcq[2] <= pcchain;
						end
					else if (instqcount[3] == 3'b111)
						begin
							instqcount[3] <= ftrack;
							instq[3] <= insttoadd;
							pcq[3] <= pcchain;
						end
					else if (instqcount[4] == 3'b111)
						begin
							instqcount[4] <= ftrack;
							instq[4] <= insttoadd;
							pcq[4] <= pcchain;
						end
					else if (instqcount[5] == 3'b111)
						begin
							instqcount[5] <= ftrack;
							instq[5] <= insttoadd;
							pcq[5] <= pcchain;
						end
				end
			end
		end
endmodule

//Fetch unit
//Inputs: clk, reset, ready, insin
//Outputs: insreq, insout
module fetcher(input logic clk, input logic reset, input logic ready, input logic[31:0] insin, output logic instreq, output logic[31:0] instout);
	logic fetchstate;
	localparam FSTALL = 1'b0;
	localparam FDECODE = 1'b1;

	always_ff @(posedge clk)
		begin
			if (reset)
				fetchstate <= FSTALL;
			case (fetchstate)
				FSTALL: if (~ready)
						fetchstate <= FSTALL;
					else
						fetchstate <= FDECODE;
				FDECODE:
					begin
						if (~ready)
							fetchstate <= FSTALL;
						else
							fetchstate <= FDECODE;
					end
			endcase			
		end
		
		always_ff @(posedge clk)
			if (fetchstate == FSTALL)
				begin
					instreq <= 0;
				end
			else
				begin
					instreq <= 1;
					instout <= insin;
				end
endmodule


//Microcode
//Inputs: Pointer
//Outputs: Microcode
module microcode_rom(input logic[7:0] pointer, output logic[44:0] microcode_line);
	//(*ramstyle = "M20K"*)
	logic[44:0] microcode[150:0];
	initial $readmemh("microcode.txt", microcode);
	
	always_comb microcode_line = microcode[pointer][44:0];
endmodule

//Decoder
//Inputs: instruction
//Outputs: immediate[15:0], opcode_pointer[6:0]
module ma10k_frontend(input logic[31:0] instruction, output logic[15:0] immediate, output logic[6:0] opcode_pointer);
	
	always_comb
		begin
			if (instruction[18:16] == 'b010)
				immediate = {instruction[31:20], instruction[11:8]};
			else
				immediate = {instruction[31:20], instruction[3:0]};
		end

	//ALU and shift
	localparam SUB = 8'h00;
	localparam ADD = 8'h01;
	localparam SHL = 8'h02;
	localparam SHR = 8'h03;
	localparam ASR = 8'h04;
	localparam ROTL = 8'h06;
	localparam ROTR = 8'h07;
	localparam NOT = 8'h08;
	localparam AND = 8'h09;
	localparam OR = 8'h0A;
	localparam XOR = 8'h0B;
	localparam NAND = 8'h0C;
	localparam NOR = 8'h0D;
	localparam XNOR = 8'h0E;
	localparam SUP = 8'h0F;
	
	//Immediate math
	localparam SUBI = 8'h80;
	localparam ADDI = 8'h81;

	//Multiplication
	localparam MULTQW = 8'h10;
	localparam MULTHW = 8'h11;
	localparam MULTW = 8'h12;
	localparam MULTR = 8'h13;
	localparam RHMULT = 8'h14;
	//Branch and jump
	localparam BREQ = 8'h20;
	localparam BRNEQ = 8'h21;
	localparam BRLT = 8'h22;
	localparam BRLTEQ = 8'h23;
	localparam JUMPREL = 8'h24;
	localparam JUMPR = 8'h26;
	localparam JUMPI = 8'h27;
	localparam CALL = 8'h28;
	localparam RET = 8'h29;
	localparam RETI = 8'h2A;

	//Load/store/stack
	localparam LRR = 8'h30;
	localparam LRI = 8'h31;
	localparam LSPR = 8'h32;
	localparam LUI = 8'h33;
	localparam LLI = 8'h34;
	localparam SSPR = 8'h35;
	localparam STR = 8'h36;
	localparam STI = 8'h37;
	localparam LREL = 8'h38;
	localparam SREL = 8'h39;
	localparam PUSH = 8'h3A;
	localparam POP = 8'h3B;
	localparam STQW = 8'h3C;
	localparam LDQW = 8'h3D;
	localparam STHW = 8'h3E;
	localparam LDHW = 8'h3F;

	//Supervisor instructions
	localparam PRG = 8'h70;
	localparam LPSP = 8'h71;
	localparam RESPSP = 'h72;
	localparam SPSP = 8'h73;
	localparam GPSP = 8'h74;
	localparam SCOP = 8'h75;
	localparam GCOP = 8'h76;
	localparam EI = 8'h77;
	localparam DI = 8'h78;
	localparam GPTIMER = 8'h79;
	localparam RESET = 8'h7A;
	
	always_comb
		case (instruction[19:12])
			SUB: opcode_pointer = 1;
			ADD: opcode_pointer = 2;
			SHL: opcode_pointer = 3;
			SHR: opcode_pointer = 4;
			ASR: opcode_pointer = 5;
			ROTL: opcode_pointer  = 6;
			ROTR: opcode_pointer = 7;
			NOT: opcode_pointer = 8;
			AND: opcode_pointer = 9;
			OR: opcode_pointer = 10;
			XOR: opcode_pointer = 11;
			NAND: opcode_pointer = 12;
			NOR: opcode_pointer = 13;
			XNOR: opcode_pointer = 14;
			SUP: opcode_pointer = 15;
			SUBI: opcode_pointer = 18;
			ADDI: opcode_pointer = 19;
			MULTQW: opcode_pointer = 20;
			MULTHW: opcode_pointer = 22;
			MULTW: opcode_pointer = 27;
			MULTR: opcode_pointer = 44;
			RHMULT: opcode_pointer = 45;
			BREQ: opcode_pointer = 46;
			BRNEQ: opcode_pointer = 49;
			BRLT: opcode_pointer = 52;
			BRLTEQ: opcode_pointer = 55;
			JUMPREL: opcode_pointer = 58;
			JUMPR: opcode_pointer = 59;
			JUMPI: opcode_pointer = 60;
			CALL: opcode_pointer = 61;
			RET: opcode_pointer = 63;
			LRR: opcode_pointer = 65;
			LRI: opcode_pointer = 66;
			LSPR: opcode_pointer = 67;
			LUI: opcode_pointer = 68;
			LLI: opcode_pointer = 69;
			SSPR: opcode_pointer = 70;
			STR: opcode_pointer = 71;
			STI: opcode_pointer = 72;
			LREL: opcode_pointer = 73;
			SREL: opcode_pointer = 74;
			PUSH: opcode_pointer = 75;
			POP: opcode_pointer = 77;
			STQW: opcode_pointer = 79;
			LDQW: opcode_pointer = 80;
			STHW: opcode_pointer = 81;
			LDHW: opcode_pointer = 82;
			PRG: opcode_pointer = 83;
			RESPSP: opcode_pointer = 86;
			SPSP:	opcode_pointer = 87;
			GPSP:	opcode_pointer = 88;
			SCOP: opcode_pointer = 89;
			GCOP: opcode_pointer = 90;
			EI: opcode_pointer = 91;
			DI: opcode_pointer = 92;
			GPTIMER: opcode_pointer = 93;
			RESET: opcode_pointer = 94;
			default: opcode_pointer = 0;
		endcase
endmodule

//Pipeline break
//Inputs: clk, reset, stall, icode[18], a, b, regtowrite
//Outputs: icodefunc, afunc, bfunc, regtowritefunc
module pipebreak(input logic clk, input logic reset, input logic stall, input logic[6:0] icode_pointer, input logic[31:0] a, input logic[31:0] b, input logic[3:0] regtowrite, input logic[31:0] programcounterinst, output logic[6:0] icode_pointero, output logic[31:0] afunc, output logic[31:0] bfunc, output logic[3:0] regtowritefunc, output logic[31:0] programcountero);
	always_ff @(posedge clk)
		begin
			if (reset)
				{afunc, bfunc, regtowritefunc, programcountero} <= {32'b0,32'b0,4'b0, 32'b0};
			else
				if (~stall)
					begin
						{afunc, bfunc, regtowritefunc, programcountero} <= {a, b, regtowrite, programcounterinst};
						icode_pointero <= icode_pointer;
					end
		end
endmodule

//Execution unit
//Inputs: clk, reset, funcsel, ina, inb, pointer[6:0]
//Outputs: execout, stalldispatch, lt, eq, executec, fucode
module execute_unit(input logic clk, input logic reset, input logic newmicrocode, input logic[1:0] funcsel, input logic[31:0] ina, input logic[31:0] inb, input logic[6:0] pointer, input logic memaccess,
							output logic[31:0] execout, output logic stalldispatch, output logic lt, output logic eq, output logic[4:0] executec, output logic[44:0] fucode);
	logic[44:0] microcode_line;
	logic[31:0] aluout, shiftout, multout;
	logic shiftdone, shiften, alufunctype, highlow, accumulate, shiftstalldispatch, multreset, notcount0, shiftdir, rotate, signextend;
	logic[1:0] multmuxas, multmuxbs;
	logic[2:0] alufunc,multdemuxs;
	logic[7:0] linenumber;

	microcode_rom microcode(linenumber, microcode_line);
	
	always_comb fucode = microcode_line;
	always_comb linenumber = pointer + {3'b0, executec};
		
	always_ff @(posedge clk)// or posedge reset)// or posedge newmicrocode)
		begin
			if(reset | microcode_line[1])// | newmicrocode | microcode_line[1])
					executec <= 0;
			else if (notcount0 & ~memaccess)
				executec <= executec + 1'b1;
		end
	always_ff @(negedge clk)// or posedge reset)
		if (~notcount0)
			notcount0 <= 1;
		else if (reset | microcode_line[1])
			notcount0 <= 0;

	always_comb
		case (funcsel)
			2'b00: begin
				execout = aluout;
				multmuxas = 0;
				multmuxbs = 0;
				multdemuxs = 0;
				accumulate = 0;
				stalldispatch = ~microcode_line[31];
				shiften = 0;
				alufunc = microcode_line[19:17];
				alufunctype = microcode_line[20];
				multreset = 0;
				shiftdir = 0;
				signextend = 0;
				rotate = 0;
			end
			2'b01: begin
				execout = multout;
				multmuxas = microcode_line[22:21];
				multmuxbs = microcode_line[24:23];
				multdemuxs = microcode_line[27:25];
				accumulate = microcode_line[28];
				stalldispatch = ~microcode_line[31];
				shiften = 0;
				alufunc = 0;
				alufunctype = 0;
				multreset = reset | microcode_line[30];
				shiftdir = 0;
				signextend = 0;
				rotate = 0;
			end
			2'b10: begin
				case (pointer)
					3: begin //SHL
						shiftdir = 0;
						signextend = 0;
						rotate = 0;
					end
					4: begin //SHR
						shiftdir = 1;
						signextend = 0;
						rotate = 0;
					end
					5: begin //ASR
						shiftdir = 1;
						signextend = 0;
						rotate = 0;
					end
					6: begin //ROTL
						shiftdir = 0;
						signextend = 0;
						rotate = 1;
					end
					7: begin //ROTR
						shiftdir = 1;
						signextend = 0;
						rotate = 1;
					end
					default: begin
						shiftdir = 0;
						signextend = 0;
						rotate = 0;
					end
				endcase

				execout = shiftout;
				multmuxas = 0;
				multmuxbs = 0;
				multdemuxs = 0;
				accumulate = 0;
				stalldispatch = shiftstalldispatch;
				shiften = 1;
				alufunc = 0;
				alufunctype = 0;
				multreset = 0;
			end
			default: begin
				execout = 0;
				multmuxas = 0;
				multmuxbs = 0;
				multdemuxs = 0;
				accumulate = 0;
				stalldispatch = 0;
				shiften = 0;
				alufunc = 0;
				alufunctype = 0;
				multreset = 0;
				shiftdir = 0;
				signextend = 0;
				rotate = 0;
				end
		endcase

	alumod alu(alufunc, alufunctype, ina, inb, aluout, lt, eq);
	multiplier_unit mult(clk, multreset, ina, inb, multmuxas, multmuxbs, multdemuxs, highlow, accumulate, multout);
	shifter_unit shifter(clk, reset, shiften, ina, inb[4:0],  shiftdir, signextend, rotate, shiftstalldispatch, shiftdone, shiftout);
endmodule

//Memory access unit
//Inputs: clk, reset, fromexecute, portb, addrsel, datasel, requestdbus, dbusreqdir, buswait
//Outputs: dbusreq, dbusdir, addr, towriteback, stalldispatch 
//Inout: data
module mem_access_unit(input logic clk, input logic reset, input logic[31:0] fromexecute, input logic[31:0] portb, input logic addrsel, input logic datasel, input logic requestdbus, input logic dbusreqdir, input logic buswait, input logic memfinished, output logic dbusreq, output logic dbusdir, output logic[31:0] addr, output logic[31:0] towriteback, output logic stalldispatch, inout logic[31:0] data);
	/* verilator lint_off ALWCOMBORDER */
	always_comb
		begin
			if (memfinished)
				dbusreq = 0;
			else
				dbusreq = requestdbus;

			//dbusreq = memfinished ? 1'h0 : requestdbus;
			dbusdir = dbusreqdir;
			addr = requestdbus ? (addrsel ? portb : fromexecute) : 32'hZ;
			data = dbusreqdir ? (datasel ? portb : fromexecute) : 'hZ;
			towriteback = dbusreqdir ? 32'hZ : data;
			if (requestdbus & ~memfinished)
				stalldispatch = 1;
			else
				stalldispatch = 0;
		end
	/* verilator lint_on ALWCOMBORDER */
endmodule
/*
module interruptprivilage(input logic[7:0] currentfunc, input logic[2:0] intin, input logic mode, input logic execnotdone,
			output logic[31:0] newpc, output logic pcwe, output logic clearpipe, output logic stall);

	localparam SUP = 8'h0F;


	localparam PRG = 8'h70;
	localparam LPSP = 8'h71;
	localparam RESPSP = 'h72;
	localparam SPSP = 8'h73;
	localparam GPSP = 8'h74;
	localparam SCOP = 8'h75;
	localparam GCOP = 8'h76;
	localparam EI = 8'h77;
	localparam DI = 8'h78;
	localparam GPTIMER = 8'h79;
	localparam RESET = 8'h7A;

	always_comb
		begin
			if (mode) //Program mode
				case (currentfunc)
					LPSP: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					RESPSP: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					SPSP: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					GPSP: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					SCOP: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					GCOP: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					EI: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					DI: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					GPTIMER: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					RESET: begin
						newpc = 32'hFFFFFF00;
						pcwe = 1;
						clearpipe = 1;
					end
					default: begin
						newpc = 32'h0;
						pcwe = 0;
						clearpipe = 0;
					end
				endcase
			else //Supervisor mode
				if (inten)
					case (intin)
						3'b000: begin
							if (execnotdone)
								stall = 1;
								newpc = 32'h0;
								pcwe = 0;
								clearpipe = 0;
							else
								stall = 0;
								newpc = 32'h0;
								pcwe = 0;
								clearpipe = 0;
							end
						3'b001:
						3'b010:
						3'b011:
						3'b100:
						3'b101:
						3'b110:
						3'b111:
					endcase
				else
					begin
						stall = 1'b0;
						newpc = 32'b0;
						pcwe = 1'b0;
						clearpipe = 1'b0
					end
		end
endmodule
*/

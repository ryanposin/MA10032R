//Special register, for SP and PC
module special_reg (input wire[31:0] d, input wire we, output logic[31:0] q);
	always_ff @(posedge we)
		q <= d;
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

//Register file with hardwired ZERO register (R0), R1-R15 are general purpose 
module regfile (input wire[3:0] portasel, input wire[3:0] portbsel, input wire[3:0] writesel, input wire we, input wire reset, input wire[31:0] writeinput, output logic[31:0] a, output logic[31:0] b);

logic[31:0] registers[15:0];

	always_ff @(posedge we | reset)
		begin
			if (~reset)
				registers[15:0] <= {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
			else
				registers[writesel[3:0] + 1] <= writeinput;
		end
	always_comb
		begin
			a = registers[portasel];
			b = registers[portbsel];
		end
endmodule

//Custom ALU implementation
module alumod (input wire[2:0] s, input wire m, input wire[31:0] a, input wire[31:0] b, input wire[3:0] shiftamt, output logic[31:0] dout, output logic lt, output logic eq);

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
						3'b010:	case (shiftamt) //Shift left w/o carry
									0: dout = a << 1;
									1: dout = a << 2;
									3: dout = a << 4;
									7: dout = a << 8;
									15: dout = a << 16;
									default: dout = 32'b0;
								endcase
	
						3'b011:	case (shiftamt) //Shift right w/o carry
									0: dout = a >> 1;
									1: dout = a >> 2;
									3: dout = a >> 4;
									7: dout = a << 8;
									15: dout = a >> 16;
									default: dout = 32'b0;
								endcase							
						3'b100:	case (shiftamt) //Rotate right w/o carry
									0: dout = {a[0],a[31:1]};
									1: dout = {a[1:0],a[31:2]};
									3: dout = {a[3:0],a[31:4]};
									7: dout = {a[7:0],a[31:8]};
									15: dout = {a[15:0],a[31:16]};
									default: dout = 32'b0;
								endcase
						3'b101:	case (shiftamt) //Rotate left w/o carry
									0: dout = {a[30:0],a[31]};
									1: dout = {a[29:0],a[31:30]};
									3: dout = {a[27:0],a[31:28]};
									7: dout = {a[23:0],a[31:24]};
									15: dout = {a[15:0],a[31:16]};
									default: dout = 32'b0;
								endcase
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

module multiplier_unit (input wire clk, input wire[31:0] a, input wire[31:0] b, input wire templatch, input wire[1:0] muxas, input wire[1:0] muxbs, input wire[1:0] demuxs, input wire endmux, input wire accumulate, output logic[31:0] multout);
	
	logic[31:0] ffa;
	logic[31:0] ffb;
	logic[7:0] multina;
	logic[7:0] multinb;
	logic[15:0] multtempout;
	logic[31:0] demux;
	logic[7:0] carrybuf;
	logic[31:0] productreg;
	logic carry;

	//Input flip flop latch
	always_ff @(posedge templatch)
			begin
				ffa <= a;
				ffb <= b;
			end
	//8x8 multiplier input MUXes 
	always_comb
		begin
			//00 - 7:0
			//01 - 15:8
			//10 - 23:16
			//11 - 31:24
			multina = muxas[1] ? (muxas[0] ? ffa[31:24] : ffa[23:16]) : (muxas[0] ? ffa[15:8] : ffa[7:0]);   
			multinb = muxbs[1] ? (muxbs[0] ? ffb[31:24] : ffb[23:16]) : (muxbs[0] ? ffb[15:8] : ffb[7:0]); 
		end

	assign multtempout = multina * multinb; //Multiply
	
	//Demux multiplier to 32 bit register
	always_comb
		case (demuxs)
			2'b00: demux = {16'b0, multtempout};
			2'b01: demux = {8'b0, multtempout, 8'b0};
			2'b10: demux = {multtempout, 16'b0};
			2'b11: demux = {multtempout[7:0], 24'b0};
		endcase
	
	//Carry for 64 bit product
	always_latch
		if (demuxs == 2'b11)
				carrybuf = multtempout[15:8];
	
	//Accumulate
	always_ff @(posedge clk)
		begin
			if (accumulate)
				{carry,productreg} <= endmux ? (productreg + demux) : ({24'b0, carrybuf} + demux + carry);
		end
	always multout = productreg;
	
endmodule


//Bus unit
//Inputs: clk, reset, qfull, todata, memreq
//Outputs: validaddr, validdata, read, write, toexec, toprefetch
//Inout: adbus
module bunit(input logic clk, input logic reset, input logic qfull, input logic memreq, input logic[31:0] todata, output logic validaddr, output logic validdata, output logic read, output logic write, output logic[31:0] toexec, output logic[31:0] toprefetch, inout logic[31:0] adbus);
endmodule

//Prefetch unit
//Inputs: clk, reset, instreq, insttoadd
//Outputs: qfull, tofetch
module prefetcher(input logic clk, input logic reset, input logic instreq, input logic[31:0] insttoadd, output logic qfull, output logic[31:0] tofetch);
endmodule

//Fetch unit
//Inputs: clk, reset, ready, insin
//Outputs: insout
module fetcher(input logic clk, input logic reset, input logic ready, input logic[31:0] insin, output logic[31:0] insout);
endmodule

//Decoder
//Inputs: instruction
//Outputs: icode[18]
module ma10k_frontend(input logic[31:0] instruction, output logic[21:0] icode[18]);
endmodule

//Pipeline break
//Inputs: clk, reset, icode[18], a, b, regtowrite
//Outputs: icodefunc, afunc, bfunc, regtowritefunc
module pipebreak(input logic clk, input logic reset, input logic[21:0] icode[18], input logic[31:0] a, input logic[31:0] b, input logic[3:0] regtowrite, output logic[21:0] icodefunc, output logic[31:0] afunc, output logic[31:0] bfunc, output logic[3:0] regtowritefunc);
endmodule

//Execution unit
//Inputs: clk, reset, funcsel, ina, inb, icode[18]
//Outputs: execout
module execute_unit(input logic clk, input logic[1:0] funcsel, input logic[31:0] ina, input logic[31:0] inb, input logic[21:0] icode[18], output logic[31:0] execout);
	//ALU w/ shifter
	alumod alu(aluop, aluoptype, rega, aluinb, immediate[3:0], aluout, lessthan, equalto);
	//Multiplier
	multiplier_unit mult(clk, rega, aluinb, templatch, multmuxas, multmuxbs, multdemuxs, accumux, accumulate, multout);	
	ttb2inmux alumultmux(aluout, multout, alumuls, wbdata); 
	ttb2inmux addroutput(aluinb, aluout, addroutmuxs, addrout);
endmodule

//Memory access unit
//Inputs: 
//Outputs:
module mem_access_unit();
endmodule



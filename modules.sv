//Special register, for SP and PC
module special_reg (input wire clk, input wire reset, input wire inc, input wire dec, input wire we, input logic[31:0] d, output logic[31:0] q);
	always_ff @(negedge clk)
		if (we)
			q <= d;
		else if (dec)
			q <= q - 1;
		else if (inc)
			q <= q + 1;
		else if (inc & dec)
			q <= q;
		
		if (reset)
			q <= 0;
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
module regfile (input logic clk, input logic reset, input wire[3:0] portasel, input wire[3:0] portbsel, input wire[3:0] writesel, input wire we, input wire[31:0] writeinput, output logic[31:0] a, output logic[31:0] b);

logic[31:0] registers[15:0];

	always_ff @(negedge clk)
		begin
			if (reset)
				registers[15:0] <= {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
			else if (we & writesel != 0)
				registers[writesel[3:0] <= writeinput;
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
						3'b010: dout = a;
						3'b011: dout = b;
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
module shifter_unit(input wire clk, input wire reset, input wire[1:0] shifttype, input wire[4:0] shiftamt, output logic stalldispatch, output logic shiftdone, output logic[31:0] shiftout);
	logic[1:0] currentshiftamount;
	logic[4:0] shiftstate;
	localparam WAIT = 0;
	localparam SH16 = 6'b010000;
	localparam SH8 = 6'b001000;
	localparam SH4 = 6'b000100;
	localparam SH2 = 6'b000010;
	localparam SH1 = 6'b000001;
	localparam SDONE = 6'b100000;
	always_ff @(posedge clk)
		begin
			if (reset)
				begin
					stalldispatch <= 0;
					shiftstate <= WAIT;
					currentshiftamount <= 0;
				end

			case (shiftstate)
				WAIT: if (shiften)
					begin
						stalldispatch <= 1;
						shiftout <= a;
						if (shiftamount[4] == 1'b1)
							shiftstate <= SH16;
						else if (shiftamount[4:3] == 2'b01)
							shiftstate <= SH8;
						else if (shiftamount[4:2] == 3'b001)
							shiftstate <= SH4;
						else if (shiftamount[4:1] == 4'b0001)
							shiftstate <= SH2;
						else if (shiftamount[4:0] == 5'b00001)
							shiftstate <= SH1;
						else
							shiftstate <= SDONE;
					end

				SH16:	if (shiftamount[3] == 1'b1)
						shiftstate <= SH8;
					else if (shiftamount[3:2] == 2'b01)
						shiftstate <= SH4;
					else if (shiftamount[3:1] == 3'b001)
						shiftstate <= SH2;
					else if (shiftamount[3:0] == 4'b0001)
						shiftstate <= SH1;
					else
						shiftstate <= SDONE;

				SH8:	if (shiftamount[2] == 1'b1)
						shiftstate <= SH4;
					else if (shiftamount[2:1] == 2'b01)
						shiftstate <= SH2;
					else if (shiftamount[2:0] == 3'b001)
						shiftstate <= SH1;
					else
						shiftstate <= SDONE;

				SH4:	if (shiftamount[1] == 1'b1)
						shiftstate <= SH2;
					else if (shiftamount[1:0] == 2'b01)
						shiftstate <= SH1;
					else
						shiftstate <= SDONE;

				SH2:	if (shiftamt[0])
						shiftstate <= SH1;
					else
						shiftstate <= SDONE;
				SH1: shiftstate <= SDONE;
				SDONE: begin
					shiftstate <= WAIT;
					stalldispatch <= 0;
				end
			endcase
		end

	always_comb
		begin
			if (shiftstate == SDONE)
				shiftdone = 1;
			else
				shiftdone = 0;

			case(shifttype)
				2'b00:	case (currentshiftamt) //Shift left w/o carry
							SH1: dout = dout << 1;
							SH2: dout = dout << 2;
							SH4: dout = dout << 4;
							SH8: dout = dout << 8;
							SH16: dout = dout << 16;
							default: dout = 32'b0;
						endcase
			
				2'b01:	case (currentshiftamt) //Shift right w/o carry
							SH1: dout = dout >> 1;
							SH2: dout = dout >> 2;
							SH4: dout = dout >> 4;
							SH8: dout = dout << 8;
							SH16: dout = dout >> 16;
							default: dout = 32'b0;
						endcase							
				2'b10:	case (currentshiftamt) //Rotate right w/o carry
							SH1: dout = {a[0],a[31:1]};
							SH2: dout = {a[1:0],a[31:2]};
							SH4: dout = {a[3:0],a[31:4]};
							SH8: dout = {a[7:0],a[31:8]};
							SH16: dout = {a[15:0],a[31:16]};
							default: dout = 32'b0;
						endcase
				3'b11:	case (currentshiftamt) //Rotate left w/o carry
							SH1: dout = {a[30:0],a[31]};
							SH2: dout = {a[29:0],a[31:30]};
							SH4: dout = {a[27:0],a[31:28]};
							SH8: dout = {a[23:0],a[31:24]};
							SH16: dout = {a[15:0],a[31:16]};
							default: dout = 32'b0;
						endcase
				endcase
		end
endmodule

module multiplier_unit (input wire clk, input wire[31:0] a, input wire[31:0] b, input wire[1:0] muxas, input wire[1:0] muxbs, input wire[2:0] demuxs, input wire highlow, input wire accumulate, output logic[31:0] multout);
	
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
		endcase
	
	//Accumulate
	always_ff @(negedge clk)
		begin
			if (accumulate)
				productreg <= productreg + demux;
			if (reset)
				productreg <= 0;
		end
	always multout = highlow ? productreg[63:32] : productreg[31:0];
endmodule


//Bus unit
//Inputs: clk, reset, qfull, memreq, memreqdir, memaddr, programcounter
//Outputs: validaddr, validdata, read, write, incprefetch, toprefetch, memwait
//Inout: adbus, memdata
module busunit(input logic clk, input logic reset, input logic qfull, input logic memreq, input logic memreqdir, input logic[31:0] memaddr, input logic[31:0] programcounter, output logic validaddr, output logic validdata, output logic read, output logic write, output logic incprefetch, output logic[31:0] toprefetch, output logic memwait, inout logic[31:0] adbus, inout logic[31:0] memdata);

	logic[2:0] busstate;
	localparam HIGHZ = 0;
	localparam OUTPUTPC = 1;
	localparam LATCHINST = 2;
	localparam OUTPUTMEM = 3;
	localparam OUTPUTDATA = 4;
	localparam LATCHDATA = 5;

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
				OUTPUTPC: busstate <= LATCHINST;
				LATCHINST: busstate <= HIGHZ;
				OUTPUTMEM:	if (memreqdir) //1 = output
							busstate <= OUTPUTDATA;
						else //0 = input
							busstate <= LATCHDATA;
				OUTPUTDATA: busstate <= HIGHZ;
				LATCHDATA: busstate <= HIGHZ;
			endcase
		end	
	always_comb
		begin
			case(busstate)
			HIGHZ: adbus = 'hZ;
			OUTPUTPC: begin
				adbus = programcounter;
				validaddr = 1;
				read = 1;
			end
			LATCHINST: begin
					toprefetch = adbus;
					validdata = 1;
					read = 1;
					incprefetch = 1;
				end
			OUTPUTMEM: begin
				adbus = memaddr;
				validaddr = 1;
				read = 0;
				write = 1;
			end
			OUTPUTDATA: begin
					adbus = memdata;
					validaddr = 0;
					validdata = 1;
					read = 0;
					write = 1;
				end
			LATCHDATA: begin
					memdata = adbus;
					validaddr = 0;
					validdata = 1;
					read = 1;
					write = 0;
				end
			endcase
		end

endmodule

//Prefetch unit
//Inputs: clk, reset, instreq, instadd, insttoadd
//Outputs: qfull, tofetch
module prefetcher(input logic clk, input logic reset, input logic instreq, input logic instadd, input logic[31:0] insttoadd, output logic qfull, output logic[31:0] tofetch);
	logic[2:0] ftrack;
	logic[2:0] instqcount[6];
	logic[31:0] instq[6];
	localparam QEMPTY = 0;
	localparam Q1 = 1;
	localparam Q2 = 2;
	localparam Q3 = 3;
	localparam Q4 = 4;
	localparam Q5 = 5;
	localparam QFULL = 6;
	
	always_ff @(posedge clk)
		begin
			if (reset)
				begin
					ftrack <= QEMPTY;
					instqcount[5:0][2:0] <= {'b111,'b111,'b111,'b111,'b111,'b111};
					instq[5:0] <= {0,0,0,0,0,0};
				end
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

			if (instreq)
				begin
					if (instqcount[0] == 0)
						begin
							instqcount[0] <= 3'b111;
							tofetch <= instq[0];
						end
					else if (instqcount[0] != 0 | instqcount[0] != 111)
						instqcount[0] <= instqcount[0] - 1;
				
					if (instqcount[1] == 0)
						begin
							instqcount[1] <= 3'b111;
							tofetch <= instq[1];
						end
					else if (instqcount[1] != 0 | instqcount[1] != 111)
						instqcount[1] <= instqcount[1] - 1;

					if (instqcount[2] == 0)
						begin
							instqcount[2] <= 3'b111;
							tofetch <= instq[2];
						end
					else if (instqcount[2] != 0 | instqcount[2] != 111)
						instqcount[2] <= instqcount[2] - 1;

					if (instqcount[3] == 0)
						begin
							instqcount[3] <= 3'b111;
							tofetch <= instq[3];
						end
					else if (instqcount[3] != 0 | instqcount[3] != 111)
						instqcount[3] <= instqcount[3] - 1;

					if (instqcount[4] == 0)
						begin
							instqcount[4] <= 3'b111;
							tofetch <= instq[4];
						end
					else if (instqcount[4] != 0 | instqcount[4] != 111)
						instqcount[4] <= instqcount[4] - 1;

					if (instqcount[5] == 0)
						begin
							instqcount[5] <= 3'b111;
							tofetch <= instq[5];
						end
					else if (instqcount[5] != 0 | instqcount[5] != 111)
						instqcount[5] <= instqcount[5] - 1;

				end
			if (instadd)
				begin
					if (instqcount[0] == 3'b111)
						begin
							instqcount[0] <= ftrack;
							instq[0] <= insttoadd;
						end
					else if (instqcount[1] == 3'b111)
						begin
							instqcount[1] <= ftrack;
							instq[1] <= insttoadd;
						end
					else if (instqcount[2] == 3'b111)
						begin
							instqcount[2] <= ftrack;
							instq[2] <= insttoadd;
						end
					else if (instqcount[3] == 3'b111)
						begin
							instqcount[3] <= ftrack;
							instq[3] <= insttoadd;
						end
					else if (instqcount[4] == 3'b111)
						begin
							instqcount[4] <= ftrack;
							instq[4] <= insttoadd;
						end
					else if (instqcount[5] == 3'b111)
						begin
							instqcount[5] <= ftrack;
							instq[5] <= insttoadd;
						end
				end
		end
endmodule

//Fetch unit
//Inputs: clk, reset, ready, insin
//Outputs: insout
module fetcher(input logic clk, input logic reset, input logic ready, input logic[31:0] insin, output logic[31:0] insout);
	logic fetchstate;
	localparam FSTALL = 0;
	localparam FDECODE = 1;

	always_ff @(posedge clk)
		begin
			if (reset)
				fetchstate <= FSTALL;
			case (fetchstate)
				FSTALL: if (~ready)
						fetchstate <= FSTALL;
					else
						fstate <= FDECODE;
				FDECODE:
					begin
						insout <= insin;
						if (~ready)
							fetchstate <= FSTALL;
						else
							fstate <= FDECODE;
					end
			endcase
		end
endmodule

//Decoder
//Inputs: instruction
//Outputs: icode[18]
module ma10k_frontend(input logic[31:0] instruction, output logic[21:0] icode[17:0]);

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
	localparam RESPSP = 8'h71;
	localparam SCOP = 8'h72;
	localparam GCOP = 8'h73;
	localparam EI = 8'h74;
	localparam DI = 8'h75;
	localparam GPTIMER = 8'h76;
	localparam RESET = 8'h77;
	logic[31:0] microcode[150];
	initial $readmemh(microcode.txt, microcode);

	always_comb
		case (instruction[19:12])
			SUB:
			ADD:
			SHL:
			SHR:
			ASR:
			ROTL:
			ROTR:
			NOT:
			AND:
			OR:
			XOR:
			NAND:
			NOR:
			XNOR:
			SUP:
			SUBI:
			ADDI:
			MULTQW:
			MULTHW:
			MULTW:
			BREQ:
			BRNEQ:
			BRLT:
			BRLTEQ:
			JUMPREL:
			JUMPR:
			JUMPI:
			CALL:
			RET:
			LRR:
			LRI:
			LSPR:
			LUI:
			LLI:
			SSPR:
			STR:
			STI:
			LREL:
			SREL:
			PUSH:
			POP:
			STQW:
			LDQW:
			STHW:
			LDHW:
			PRG:
			RESPSP:
			SCOP:
			GCOP:
			EI:
			DI:
			GPTIMER:
			RESET:
		end
endmodule

//Pipeline break
//Inputs: clk, reset, stall, icode[18], a, b, regtowrite
//Outputs: icodefunc, afunc, bfunc, regtowritefunc
module pipebreak(input logic clk, input logic reset, input logic stall, input logic[21:0] icode[18], input logic[31:0] a, input logic[31:0] b, input logic[3:0] regtowrite, output logic[21:0] icodefunc, output logic[31:0] afunc, output logic[31:0] bfunc, output logic[3:0] regtowritefunc);
	always_ff @(posedge clk)
		begin
			if (reset)
				{icodefunc, afunc, bfunc,regtowritefunc} <= {0,0,0,0};
			else
				if (stall)
					{icodefunc, afunc, bfunc, regtowritefunc} <= {icodefunc, afunc, bfunc, regtowritefunc};
				else 
					{icodefunc, afunc, bfunc, regtowritefunc} <= {icode, a, b, regtowrite};
		end
endmodule

//Execution unit
//Inputs: clk, reset, funcsel, ina, inb, icode[18]
//Outputs: execout, stalldispatch
module execute_unit(input logic clk, input logic reset, input logic[1:0] funcsel, input logic[31:0] ina, input logic[31:0] inb, input logic[21:0] icode[17:0], output logic[31:0] execout, output logic stalldispatch);
	
	logic[4:0] executec;
	always_ff @(posedge clk)
		if(icode[executec][])

		else
			executec = 0;
	always_comb
		case (funcsel)
			2'b00: begin
				execout = aluout;
				alufuncsel = icode[0][];
				alufunctype = icode[0][];
			end
			2'b01: begin
				execout = multout;
				templatch = icode[executec][];
				multmuxas = icode[executec][];
				multmuxbs = icode[executec][];
				multdemuxs = icode[executec][];
				accumux = icode[executec][];
				accumulate = icode[executec][];
				stalldispatch = ~multdone;
			end
			2'b10: begin
				execout = shiftout;
				stalldispatch = ~shiftdone;
			end
			default: execout = 0;
		endcase

	alumod alu(alufunc, alufunctype, ina, inb, immediate[3:0], aluout, lessthan, equalto);
	multiplier_unit mult(clk, ina, inb, templatch, multmuxas, multmuxbs, multdemuxs, accumux, accumulate, multout);
	shifter_unit shifter(clk, ina, immediate[4:0], shiftout);
endmodule

//Memory access unit
//Inputs: fromexecute, portb, addrsel, datasel, requestdbus, dbusreqdir, buswait
//Outputs: dbusreq, dbusdir, addr, towriteback, stalldispatch 
//Inout: data
module mem_access_unit(input logic[31:0] fromexecute, input logic[31:0] portb, input logic addrsel, input logic datasel, input logic requestdbus, input logic dbusreqdir, input logic buswait, output logic dbusreq, output logic dbusdir, output logic[31:0] addr, output logic[31:0] towriteback, output logic stalldispatch, inout logic[31:0] data);
	always_comb
		begin
			dbusreq = requestdbus;
			dbusdir = dbusreqdir;
			addr = requestdbus ? (addrsel ? portb : fromexecute) : 32'hZ;
			towriteback = requestdbus ? ( dbusreqdir ? 32'hZ : data) : fromexecute;
			data = requestdbus ? (datasel ? portb : fromexecute) : 32'hZ;
		
			if (requestdbus)
				stalldispatch = buswait;
			else
				stalldispatch = 0;
		end
endmodule



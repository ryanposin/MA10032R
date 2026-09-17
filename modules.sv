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
	localparam SH16 = 5'b10000;
	localparam SH8 = 5'b01000;
	localparam SH4 = 5'b00100;
	localparam SH2 = 5'b00010;
	localparam SH1 = 5'b00001;

	always_ff @(posedge clk)
		if (reset)
			begin
				stalldispatch <= 0;
				shiftstate <= WAIT;
				currentshiftamount <= 0;
			end

		case (shiftstate)
			STALL: if (shiften)
				begin
					stalldispatch <= 1;
					shiftout <= a;
					case (shiftamt)
						'b1XXXX: shiftstate <= SH16L
						'b01XXX: shiftstate <= SH8;
						'b001XX: shiftstate <= SH4;
						'b0001X: shiftstate <= SH2;
						'b00001: shiftstate <= SH1;
						default: shiftstate <= SDONE;
					endcase
				end
			SH16:	case(shiftamt[3:0])
					'b1XXX: shiftstate <= SH8;
					'b01XX: shiftstate <= SH4;
					'b001X: shiftstate <= SH2;
					'b0001: shiftstate <= SH1;
					default: shiftstate <= SDONE;
				endcase
			SH8:	case(shiftamt[2:0]
					'b1XX: shiftstate <= SH4;
					'b01X: shiftstate <= SH2;
					'b001: shiftstate <= SH1;
					default: shiftstate <= SDONE;
				endcase
			SH4:	case(shiftamt[1:0])
					'b1X: shiftstate <= SH2;
					'b01: shiftstate <= SH1;
					default: shiftstate <= SDONE;
				endcase
			SH2:	case(shiftamt[0])
					'b1: shiftstate <= SH1;
					default: shiftstate <= SDONE;
				endcase
			SH1: shiftstate <= SDONE;
			SDONE: begin
				shiftstate <= STALL;
				stalldispatch <= 0;
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
//Outputs: validaddr, validdata, read, write, toexec, incprefetch, toprefetch, memwait
//Inout: adbus, memdata
module busunit(input logic clk, input logic reset, input logic qfull, input logic memreq, input logic memreqdir, input logic[31:0] memaddr, input logic[31:0] programcounter, output logic validaddr, output logic validdata, output logic read, output logic write, output logic[31:0] toexec, output logic incprefetch, output logic[31:0] toprefetch, output logic memwait, inout logic[31:0] adbus, inout logic[31:0] memdata);

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
			OUTPUTDATA:
				adbus = memdata;
				validaddr = 0;
				validdata = 1;
				read = 0;
				write = 1;
			LATCHDATA:
				memdata = adbus;
				validaddr = 0;
				validdata = 1;
				read = 1;
				write = 0;
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
					instqcount[5:0] <= {'b111,'b111,'b111,'b111,'b111,'b111};
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
					else if (instqcount[0] ~= 0 | instqcount[0] ~= 111)
						instqcount[0] <= instqcount[0] - 1;
				
					if (instqcount[1] == 0)
						begin
							instqcount[1] <= 3'b111;
							tofetch <= instq[1];
						end
					else if (instqcount[1] ~= 0 | instqcount[1] ~= 111)
						instqcount[1] <= instqcount[1] - 1;

					if (instqcount[2] == 0)
						begin
							instqcount[2] <= 3'b111;
							tofetch <= instq[2];
						end
					else if (instqcount[2] ~= 0 | instqcount[2] ~= 111)
						instqcount[2] <= instqcount[2] - 1;

					if (instqcount[3] == 0)
						begin
							instqcount[3] <= 3'b111;
							tofetch <= instq[3];
						end
					else if (instqcount[3] ~= 0 | instqcount[3] ~= 111)
						instqcount[3] <= instqcount[3] - 1;

					if (instqcount[4] == 0)
						begin
							instqcount[4] <= 3'b111;
							tofetch <= instq[4];
						end
					else if (instqcount[4] ~= 0 | instqcount[4] ~= 111)
						instqcount[4] <= instqcount[4] - 1;

					if (instqcount[5] == 0)
						begin
							instqcount[5] <= 3'b111;
							tofetch <= instq[5];
						end
					else if (instqcount[5] ~= 0 | instqcount[5] ~= 111)
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
module ma10k_frontend(input logic[31:0] instruction, output logic[21:0] icode[18]);
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
endmodule

//Execution unit
//Inputs: clk, reset, funcsel, ina, inb, icode[18]
//Outputs: execout, stalldispatch
module execute_unit(input logic clk, input logic[1:0] funcsel, input logic[31:0] ina, input logic[31:0] inb, input logic[21:0] icode[18], output logic[31:0] execout, output logic stalldispatch);
	always_comb
		case (funcsel)
			2'b00: begin
				execout = aluout;
				alufuncsel = icode[executec][];
				alufunctype = icode[executec][];
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
	assign dbusreq = requestdbus;
	assign dbusdir = dbusreqdir;
	assign addr = requestdbus ? (addrsel ? portb : fromexecute) : 32'hZ;
	assign towriteback = requestdbus ? ( dbusreqdir ? 32'hZ : data) : fromexecute;
	assign data = requestdbus ? (datasel ? portb : fromexecute) : 32'hZ;
	
	always_comb
		if (requestdbus)
			stalldispatch = buswait;
		else
			stalldispatch = 0;
endmodule



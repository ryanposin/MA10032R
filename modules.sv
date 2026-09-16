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

//Register file with hardwired ZERO register (R0), R1-R8 are general purpose 
module regfile (input wire[3:0] portasel, input wire[3:0] portbsel, input wire[3:0] writesel, input wire we, input wire reset, input wire[31:0] writeinput, output logic[31:0] a, output logic[31:0] b);

logic[31:0] registers[8:0];

	always_ff @(posedge we | reset)
		begin
			if (~reset)
				registers[8:0] <= {0,0,0,0,0,0,0,0,0};
			else
				registers[writesel[2:0] + 1] <= writeinput;
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
	always_ff @(negedge clk)
		begin
			if (accumulate)
				{carry,productreg} <= endmux ? (productreg + demux) : ({24'b0, carrybuf} + demux + carry);
		end
	always multout = productreg;
	
endmodule

module ma10k_frontend (input wire clk, input wire reset, input wire[31:0] ins, output logic[3:0] portasel, output logic[3:0] portbsel, output logic[3:0] writesel, output logic we, output logic alu_mode, output logic[2:0] alu_function, output logic[15:0] immediate, output wire highz, output logic validaddr, output logic validdata, output logic busrd, output logic buswrite, output logic addroutmuxs);
	
	logic itype;
	logic btype;
	logic qincrease, qdecrease, qfull, stallexec, memaccess;
	logic[31:0] instructionlatch; 
	localparam PCOUNTER = 2'b00;

	//Fetch FSM states
	logic fetchdecode;
	localparam FSTALL = 0;
	localparam FDECODE = 1;

	//Prefetch Queue (Q) states
	logic[2:0] qtrack;
	localparam QEMPTY = 3'b000;
	localparam Q1 = 3'b001;
	localparam Q2 = 3'b010;
	localparam Q3 = 3'b011;
	localparam Q4 = 3'b100;
	localparam Q5 = 3'b101;
	localparam Q6 = 3'b110;
	
	//Execute FSM states
	logic[4:0] etrack;
	localparam EXSTALL = 0;
	localparam EXWB0 = 1;
	//Full word multiply (32b)
	localparam TTMUL0 = 2;
	localparam TTMUL1 = 3;
	localparam TTMUL2 = 4;
	localparam TTMUL3 = 5;
	localparam TTMUL4 = 6;
	localparam TTMUL5 = 7;
	localparam TTMUL6 = 8;
	localparam TTMUL7 = 9;
	localparam TTMUL8 = 10;
	localparam TTMUL9 = 11;
	localparam TTMUL10 = 12;
	localparam TTMUL11 = 13;
	localparam TTMUL12 = 14;
	localparam TTMUL13 = 15;
	localparam TTMUL14 = 16;
	localparam TTMUL15 = 17;
	localparam TTMULWB = 18;
	//Half word multiply (16b)
	localparam HWMUL0 = 19;
	localparam HWMUL1 = 20;
	localparam HWMUL2 = 21;
	localparam HWMUL3 = 22;
	//Quarter word multiply (8b)
	localparam QWMUL = 23;
	//Shift states
	localparam SH16 = 24;
	localparam SH8 = 25;
	localparam SH4 = 26;
	localparam SH2 = 27;
	localparam SH1 = 28;

	//Bus unit FSM states;
	logic[2:0] busunitstate;
	localparam HIGHZ = 3'b000;
	localparam OUTPUTPC = 3'b001;
	localparam LINST = 3'b010;
	localparam OUTPUTMEMADDR = 3'b011;
	localparam OUTPUTMEMDATA = 3'b100;
	localparam LDATA = 3'b101;

	//Bus unit FSM
	always_ff @(negedge clk)
		begin
			if (~reset)
				busunitstate <= HIGHZ;
			case (busunitstate)
				HIGHZ: if (~highz & memaccess)
						busunitstate <= OUTPUTMEMADDR;
					else if (~highz & ~qfull & ~memaccess)
						busunitstate <= OUTPUTPC;
					else if ((~mem & qfull) | highz)
						busunitstate <= HIGHZ;
				OUTPUTPC: busunitstate <= LINST;
				LINST: busunitstate <= HIGHZ;
				OUTPUTMEMADDR: if (~we)
							busunitstate <= OUTPUTMEMDATA;
						else
							busunitstate <= LDATA;
				OUTPUTMEMDATA: busunitstate <= HIGHZ;
				LDATA: busunitstate <= HIGHZ;
				default: busunitstate <= HIGHZ;
			endcase
		end

	//FSMs
	always_ff @(posedge clk)
		begin
			//Fetch from prefetch FIFO
			if (~reset)
				fetchdecode <= FSTALL;

			case (fetchdecode)
				FSTALL: if (qempty)
						fetchdecode <= FSTALL;
					else if (~qempty)
						fetchdecode <= FDECODE;
				FDECODE: fetchdecode <= FSTALL;
			endcase

			//Prefetch Queue Tracker
			if (~reset)
				qtrack <= QEMPTY;

			case (qtrack)
				QEMPTY: if (qincrease & ~qdecrease)
						qtrack <= Q1;
					else if ((~qincrease & ~qdecrease) | (qincrease & qdecrease))
						qtrack <= QEMPTY;

				Q1:	if ((~qincrease & ~qdecrease) | (qincrease & qdecrease))
						qtrack <= Q1;
					else if (qincrease & ~qdecrease)
						qtrack <= Q2;
					else
						qtrack <= QEMPTY;

				Q2:	if ((~qincrease & ~qdecrease) | (qincrease & qdecrease))
						qtrack <= Q2;
					else if (qincrease & ~qdecrease)
						qtrack <= Q3;
					else
						qtrack <= Q1;

				Q3:	if ((~qincrease & ~qdecrease) | (qincrease & qdecrease))
						qtrack <= Q3;
					else if (qincrease & ~qdecrease)
						qtrack <= Q4;
					else
						qtrack <= Q2;

				Q4:	if ((~qincrease & ~qdecrease) | (qincrease & qdecrease))
						qtrack <= Q4;
					else if (qincrease & ~qdecrease)
						qtrack <= Q5;
					else
						qtrack <= Q3;

				Q5:	if ((~qincrease & ~qdecrease) | (qincrease & qdecrease))
						qtrack <= Q5;
					else if (qincrease & ~qdecrease)
						qtrack <= Q6;
					else
						qtrack <= Q4;

				Q6:	if ((~qincrease & ~qdecrease) | (qincrease & qdecrease))
						qtrack <= Q6;
					else if (~qincrease & qdecrease)
						qtrack <= Q5;
				default: qtrack <= QEMPTY;
			endcase	
			
			//Execute Sequencing FSM
			if (~reset)
				etrack <= EXSTALL;

			case (etrack)
			EXSTALL: if (dispatch)
					etrack <= EX0;
				else
					etrack <= EXSTALL;
			EX0:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX1;

			EX1:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX2;

			EX2:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX3;

			EX3:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX4;

			EX4:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX5;

			EX5:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX6;

			EX6:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX7;
			EX7:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX8;
			EX8:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX9;
			EX9:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX10;
			EX10:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX11;
			EX11:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX12;
			EX12:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX13;
			EX13:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX14;
			EX14:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX15;
			EX15:	if (idone)
					etrack <= EXSTALL;
				else
					etrack <= EX16;
			EX16:	if (idone)
					etrack <= EX17;
				else
					etrack <= EXSTALL;
			EX17: etrack <= EXSTALL;
			default: etrack <= EXSTALL;




			default: etrack <= EXSTALL;
			endcase
		end

	//FSM IOs
	always_comb
		begin
			//Bus unit output
			if (busunitstate == HIGHZ)
				highz = 1;
			else
				highz = 0;
			if (busunitstate == OUTPUTPC | busunitstate == OUTPUTMEMADDR | busunitstate == OUTPUTMEMDATA)
				buswrite = 1;
			else
				buswrite = 0;
			if (busunitstate == OUTPUTPC | busunitstate == OUTPUTMEMADDR)
				validaddr = 1;
			else
				validaddr = 0;
			if (busunitstate == OUTPUTMEMDATA)
				validdata = 1;
			else
				validdata = 0;

			if (busunitstate == LDATA | busunitstate == LINST)
				begin
					busread = 1;
					validdata = 1;
				end
			else
				begin
					busread = 0;
					validdata = 0;
				end

			//Prefetch tracker output
			if (qtrack == QEMPTY)
				begin
					stallexec = 1;
					qfull = 0;
				end
			else if (qtrack == Q6)
				begin
					stallexec = 1;
					qfull = 1;
				end
			else
				begin
					stallexec = 0;
					qfull = 0;
				end
		end
	always_latch
		if (busunitstate == LINST)
			instructionlatch = ins;
	always_comb
		begin
			portasel = instructionlatch[7:4];
			portbsel = instructionlatch[3:0];
			writesel = instructionlatch[11:8];
			if (itype) immediate = {instructionlatch[31:20],instructionlatch[3:0]}; 
			else if (btype) immediate = {instructionlatch[31:20],instructionlatch[11:8]};
			else immediate = 0;
		end
	//Decode
	always_comb
		begin
			case (currenti[19:16])
				4'b0000:	if (etrack == EX0)
							begin
								alumode = currenti[15];
								aluop = currenti[14:12];
								pbmuxsel = 4'b00;
								itype = 0;
								alumuls = 0;
								idone = 1;
								regwe = 1;
							end
				4'b0100:	if (etrack == EX0)
							begin
								alumode = currenti[15];
								aluop = currenti[14:12];
								pbmuxsel = 4'b01;
								itype = 1;
								alumuls = 0;
								idone = 1;
								regwe = 1;
							end
						else
							itype = 0;
				4'b0001: case (currenti[15:12])
						4'b0000: case (etrack)
							EX0:
								begin
									pbmuxsel = 4'b00;
									templatch = 1;
									resetmult = 1;
								end
							EX1:
								begin
									resultmult = 0;
									multmuxas = 0;
									multmuxbs = 0;
									multdemuxs = 0;
								end
							EX2: begin
									alumuls = 1;
									idone = 1;
									regwe = 1;
								end
							default:
								idone = 1;
						4'b0001:
							case (ETRACK)
								EX0: begin
									pbmuxsel = 4'b00;
									templatch = 1;
									resetmult = 1;
								end
								EX1: begin
									resetmult = 0;
									multmuxas = 0;
									multmuxbs = 0;
									multdemuxs = 0;
								end
								EX2: begin
									multmuxas = 0;
									multmuxbs = 1;
									multdemuxs = 1;
								end
								EX3: begin
									multmuxas = 1;
									multmuxbs = 0;
									multdemuxs = 1;
								end
								EX4: begin
									multmuxas = 1;
									multmuxbs = 1;
									multdemuxs = 2;
								end
								EX5: begin
									alumuls = 1;
									idone = 1;
									regwe = 1;
								end
								default:
									regwe = 0;
							endcase
						4'b0010:
							case (etrack)
								EX0: begin
									pbmuxsel = 4'b00;
									templatch = 1;
									resetmult = 1;
								end
								EX1: begin //DH
									resetmult = 0;
									multmuxas = 0;
									multmuxbs = 0;
									multdemuxs = 0;
								end
								EX2: begin //DG << 8
									multmuxas = 0;
									multmuxbs = 1;
									multdemuxs = 1;
								end
								EX3: begin //DF << 16
									multmuxas = 0;
									multmuxbs = 2;
									multdemuxs = 2;
								end
								EX4: begin //DE << 24
									multmuxas = 0;
									multmuxbs = 3;
									multdemuxs = 3;
								end
								EX5: begin //CH << 8
									multmuxas = 1;
									multmuxbs = 0;
									multdemuxs = 1;
								end
								EX6: begin //CG << 16
									multmuxas = 1;
									multmuxbs = 1;
									multdemuxs = 2;
								end
								EX7: begin //CF << 24
									multmuxas = 1;
									multmuxbs = 2;
									multdemuxs = 3;
								end
								EX8: begin //CE << 32
									multmuxas = 1;
									multmuxbs = 3;
									multdemuxs = 4;
								end
								EX9: begin //BH << 16
									multmuxas = 2;
									multmuxbs = 0;
									multdemuxs = 2;
								end
								EX10: begin //BG << 24
									multmuxas = 2;
									multmuxbs = 1;
									multdemuxs = 3;
								end
								EX11: begin //BF << 32
									multmuxas = 2;
									multmuxbs = 2;
									multdemuxs = 4;
								end
								EX12: begin //BE << 40
									multmuxas = 2;
									multmuxbs = 3;
									multdemuxs = 5;
								end
								EX13: begin //AH << 24
									multmuxas = 3;
									multmuxbs = 0;
									multdemuxs = 3;
								end
								EX14: begin //AG << 32
									multmuxas = 3;
									multmuxbs = 1;
									multdemuxs = 4;
								end
								EX15: begin //AF << 40
									multmuxas = 3;
									multmuxbs = 2;
									multdemuxs = 5;
								end
								EX16: begin //AE << 48
									multmuxas = 3;
									multmuxbs = 3;
									multdemuxs = 6;
								end
								EX17: begin
									alumuls = 1;
									idone = 1;
									regwe = 1;
								end
								default:
									regwe = 0;
							endcase
						default:
							begin
								multmuxas = 0;
								multmuxbs = 0;
								templatch = 0;
								resetmult = 0;
							end
					endcase
				4'b0010:
					case (currenti[15:12])
						4'b0000: //BREQ
						4'b0001: //BRNEQ
						4'b0010: //BRLT
						4'b0011: //BRLTEQ
						4'b0100: //JUMPREL
						4'b0101: //JUMPA
						4'b0110: //JUMPR
						4'b0111: //JUMPI
						4'b1000: //CALL
						4'b1001: //RET
						default:
					endcase
				4'b0011:
					case(currenti[15:12])
						4'b0000: //LRR
						4'b0001: //LRI
						4'b0010: //LRA
						4'b0011: //LUI
						4'b0100: //LLI
						4'b0101: //STA
						4'b0110: //STR
						4'b0111: //STI
						4'b1000: //LOFST
						4'b1001: //SOFST
						4'b1010: //PUSH
						4'b1011: //POP
						4'b1100: //LL
						4'b1101: //SC
						default:
					endcase
				4'b0111:
					case(currenti[15:12])
						4'b0000: //PRG
						4'b0001: //RESPSP
						4'b0010: //SSYS
						4'b0011: //GSYS
					endcase
				default:
			endcase
		end
endmodule

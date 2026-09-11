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

module ma10k_frontend (input wire clk, input wire reset, input wire[31:0] ins, output logic[3:0] portasel, output logic[3:0] portbsel, output logic[3:0] writesel, output logic we, output logic alu_mode, output logic[2:0] alu_function, output logic[15:0] immediate, output logic datadir);
	logic[6:0] microcode[60];
	logic itype;
	logic btype;
	logic qincrease, qdecrease, qfull;

	//Prefetch FSM states
	logic[2:0] fetchfsm;
	localparam FADDR = 3'b001;
	localparam FDATA = 3'b010;
	localparam FSTALL = 3'b100;

	//Prefetch Queue (Q) states
	logic[2:0] qtrack;
	localparam QEMPTY = 3'b000;
	localparam Q1 = 3'b001;
	localparam Q2 = 3'b010;
	localparam Q3 = 3'b011;
	localparam Q4 = 3'b100;
	localparam Q5 = 3'b101;
	localparam Q6 = 3'b110;

	//FSMs
	always_ff @(posedge clk)
		begin
			//Prefetch FSM
			if (~reset)
				fetchfsm <= FSTALL;
			case (fetchfsm)
				FADDR: fetchfsm <= FDATA;
				FDATA: if (qfull)
						fetchfsm <= FSTALL;
					else
						fetchfsm <= FADDR;
				FSTALL: if (qfull)
						fetchfsm <= FSTALL;
					else
						fetchfsm <= FADDR;
				default: fetchfsm <= FSTALL;
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
		end

	//FSM IOs
	always_comb
		begin
			//Prefetch output
			if (fetchfsm == FDATA)
				qincrease = 1;
			else
				qincrease = 0;
		end

	always_comb
		begin
			portasel = ins[7:4];
			portbsel = ins[3:0];
			writesel = ins[11:8];
			if (itype) immediate = {ins[31:20],ins[3:0]}; 
			else if (btype) immediate = {ins[31:20],ins[11:8]};
			else immediate = 0;
		end
endmodule

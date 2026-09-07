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

reg[31:0] registers[8:0];
always registers[0] = 0;

	always_ff @(posedge we | reset)
		begin
			if (~reset)
				registers[8:1] <= {0,0,0,0,0,0,0,0};
			else
				registers[writesel[2:0] + 1] <= writeinput;
		end
	always_comb
		begin
			a = registers[portasel];
			b = registers[portbsel];
		end
endmodule

//Trimmed 74'181 ALU implementation
//cin active high, cout active high 
module alumod (input wire[3:0] s, input wire m, input wire cin, input wire[31:0] a, input wire[31:0] b, input wire[3:0] shiftamt, output logic[31:0] dout, output logic cout);

	always_comb
		case (m)
			1'b0:
				case (s)
					//Arithmetic
					4'b0000:	{cout,dout} = a + cin;
					4'b0001:	case (shiftamt) //Shift left w/o carry
								0: {cout,dout} = {1'b0, a << 1};
								1: {cout,dout} = {1'b0, a << 2};
								3: {cout,dout} = {1'b0, a << 4};
								7: {cout,dout} = {1'b0, a << 8};
								15: {cout,dout} = {1'b0, a << 16};
								default: {cout,dout} = {1'b0,32'b0};
							endcase

					4'b0010:	case (shiftamt) //Shift right w/o carry
								0: {dout,cout} = {a >> 1,1'b0};
								1: {dout,cout} = {a >> 2,1'b0};
								3: {dout,cout} = {a >> 4,1'b0};
								7: {dout,cout} = {a >> 8,1'b0};
								15: {dout,cout} = {a >> 16,1'b0};
								default: {dout,cout} = {32'b0,1'b0};
							endcase							
					4'b0011: {cout,dout} = {a[31], {a[30:0], cin}}; //Rotate left w/ carry
					4'b0100: {dout,cout} = {{cin,a[31:1]}, a[0]}; //Rotate right w/ carryout
					4'b0101:	case (shiftamt) //Rotate right w/o carry
								0: dout = {a[0],a[31:1]};
								1: dout = {a[1:0],a[31:2]};
								3: dout = {a[3:0],a[31:4]};
								7: dout = {a[7:0],a[31:8]};
								15: dout = {a[15:0],a[31:16]};
								default: dout = 32'b0;
							endcase
					4'b0110:	case (shiftamt) //Rotate left w/o carry
								0: dout = {a[30:0],a[31]};
								1: dout = {a[29:0],a[31:30]};
								3: dout = {a[27:0],a[31:28]};
								7: dout = {a[23:0],a[31:24]};
								15: dout = {a[15:0],a[31:16]};
								default: dout = 32'b0;
							endcase
					4'b0111:	{cout,dout} = a + b + cin;
					default:	dout = 0; 
				endcase
			1'b1:
				case (s)
					//Logic
					4'b0000:	dout = ~a;
					4'b0001:	dout = ~(a | b);
					4'b0011:	dout = 0;
					4'b0100:	dout = ~(a & b);
					4'b0101:	dout = ~b; 
					4'b0110:	dout = a ^ b; 
					4'b0111:	dout = ~(a ^ b);
					4'b1000:	dout = b; 
					4'b1001:	dout = a & b;
					4'b1010:	dout = 1;  
					4'b1011:	dout = a | b;
					4'b1100:	dout = a; 
					default:	dout = 0; 
				endcase
		endcase

endmodule

module multiplier_unit (input wire clk, input wire[31:0] a, input wire[31:0] b, input wire templatch, input wire outlatch, input wire[1:0] muxas, input wire[1:0] muxbs, input wire[1:0] demuxs, input wire endmux, input wire accumulate, output logic[31:0] multout);
	
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

	always_comb multtempout = multina * multinb; //Multiply
	
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
	
endmodule

module ma10k_frontend (input wire[31:0] ins, output logic[3:0] portasel, output logic[3:0] portbsel, output logic[3:0] writesel, output logic we, output logic alu_mode, output logic alu_function, output logic[15:0] immediate);
	logic[6:0] microcode[60];
	logic itype;
	logic btype;
	initial begin
			$readmemh("microcode.txt", microcode);
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

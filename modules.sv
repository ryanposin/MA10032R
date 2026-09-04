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

//Trimmed 74'181 ALU implementation, s[4] = M from original chip, s[3:0] are normal
//select lines, cin active high, cout active high 
module alumod (input wire[3:0] s, input wire m, input wire cin, input wire[31:0] a, input wire[31:0] b, output logic[31:0] dout, output logic cout);

	always_comb
		case (m)
			1'b0:
				case (s)
					//Arithmetic
					4'b0000:	{cout,dout} = a + cin;
					4'b0001:	{cout,dout} = ({a,cin} << 1); 	
					4'b0010:	{dout,cout} = ({cin,a} >> 1);
					4'b0011:	begin dout = a << 1; cout = 0; end
					4'b0100:	begin dout = a >> 1; cout = 0; end
					4'b0101:	{cout,dout} = a + b + cin;
					default:	begin dout = 0; cout = 0; end
				endcase
			1'b1:
				case (s)
					//Logic
					4'b0000:	begin dout = ~a; cout = 0; end
					4'b0001:	begin dout = ~(a | b); cout = 0; end
					4'b0011:	begin dout = 0; cout = 0; end
					4'b0100:	begin dout = ~(a & b); cout = 0; end
					4'b0101:	begin dout = ~b; cout = 0; end
					4'b0110:	begin dout = a ^ b; cout = 0; end
					4'b0111:	begin dout = ~(a ^ b); cout = 0; end
					4'b1000:	begin dout = b; cout = 0; end
					4'b1001:	begin dout = a & b; cout = 0; end
					4'b1010:	begin dout = 1; cout = 0; end
					4'b1011:	begin dout = a | b; cout = 0; end
					4'b1100:	begin dout = a; cout = 0; end
					default:	begin dout = 0; cout = 0; end
				endcase
		endcase

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

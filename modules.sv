//Special register, for SP and PC
module special_reg (input wire[31:0] d, input wire we, output logic[31:0] q);
	always_ff @(posedge we)
		q <= d;
endmodule

//32 bit 2:1 MUX
module 32b2inmux (input wire[31:0] i0, input wire[31:0] i1, input wire select, output wire[31:0] q);
	always_comb
		q = select ? i1 : i0; 
endmodule

//32 bit 4:1 MUX
module 32b4inmux (input wire[31:0] i0, input wire[31:0] i1, input wire[31:0] i2, input wire[31:0], i3, input wire[1:0] select, output wire[31:0] q);
	always_comb
		q = select[1] ? (select[0] ? i3 : i2) : (select[0] ? i1 : i0);
endmodule

//Register file with hardwired ZERO register (R0), R1-R8 are general purpose 
module regfile (input wire[3:0] portasel, input wire[3:0] portbsel, input wire[3:0] writesel, input wire we, input wire reset, input wire[31:0] writeinput, output wire[31:0] a, output wire[31:0] b);

reg[31:0] registers[8:0];
always registers[0] = 0;

	always_ff @(posedge we | reset)
		begin
			if (~reset)
				registers[8:1] <= 0;
			else
				registers[writesel[2:0] + 1] <= writeinput;
		end
	always_comb
		begin
			a = registers[portasel];
			b = registers[portbsel];
		end
endmodule

//74'181 ALU implementation, s[4] = M from original chip, s[3:0] are normal
//select lines, cin active high, cout active high 
module 181alu (input wire[4:0] s, input wire cin, input wire[31:0] a, input wire[31:0] b, output logic[31:0] dout, output logic cout);

	always_comb
		case (s):
			//Arithmetic
			5'b00000:	dout = a + cin;
			5'b00001:	dout = (a | b) + cin;
			5'b00010:	dout = (a | ~b) + cin;
			5'b00011:	dout = -1 + cin;
			5'b00100:	dout = (a + (a | ~b)) + cin;
			5'b00101:	dout = ((a | b) + (a | ~b)) + cin;
			5'b00110:	dout = (a - b - 1) + cin;
			5'b00111:	dout = ((a & ~b) - 1) + cin; 
			5'b01000:	dout = (a + (a & b)) + cin;
			5'b01001:	dout = (a + b) + cin;
			5'b01010:	dout = ((a | ~b) + (a & b)) + cin;
			5'b01011:	dout = (a & b) - 1 + cin;
			5'b01100:	dout = (a << 1) + cin; 	
			5'b01101:	dout = (a | b) + a + cin;
			5'b01110:	dout = (a | ~b) + a + cin;
			5'b01111:	dout = a - 1 + cin;
			
			//Logic
			5'b10000:	dout = ~a;
			5'b10001:	dout = ~(a | b);
			5'b10010:	dout = ~a & b;
			5'b10011:	dout = 0;
			5'b10100:	dout = ~(a & b);
			5'b10101:	dout = ~b;
			5'b10110:	dout = a xor b;
			5'b10111:	dout = a & ~b;
			5'b11000:	dout = a | ~b;
			5'b11001:	dout = a xnor b;
			5'b11010:	dout = b;
			5'b11011:	dout = a & b;
			5'b11100:	dout = 1;
			5'b11101:	dout = a | ~b;
			5'b11110:	dout = a | b;
			5'b11111:	dout = a;
		endcase

endmodule

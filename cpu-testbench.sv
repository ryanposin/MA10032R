`include "cpu.sv"
/* verilator lint_off UNOPTFLAT */
module testbench();
	logic clk, reset, validaddr, validdata, read, write, nmi, intack;
	logic[1:0] buswidth;
	logic[2:0] intin;
	logic[31:0] addr, ram[10];
	logic[31:0] adbusi, adbuso, adbus;


	processor_core ma10032r(clk, reset, nmi, intin,
				validaddr, validdata, read, write, buswidth, intack,
				adbus);
	always_comb
		if (read & validdata)
			adbusi = ram[addr];
		else
			adbusi = 'hZ;

	assign adbus = read ? adbusi : 'hZ;
	assign adbuso = (write | read) ? adbus : 'hZ;

	always_ff @(negedge clk)
		if(validaddr)
			addr = adbuso;

	always_latch
		if (validdata & write)
			ram[addr][31:0] = adbuso;

	initial begin
		$readmemh("ramfile.txt", ram);
		$dumpfile("cputrace");
		$dumpvars();
		clk = 0;
		reset = 0;
		#437;
		reset = 1;
		#50000
		$finish();
	end
	always
		#150 clk = ~clk;
endmodule

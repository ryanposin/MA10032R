`include "cpu.sv"
/* verilator lint_off UNOPTFLAT */
module testbench();
	logic clk, reset, validaddr, validdata, read, write;
	logic[31:0] addr, ram[10];
	logic[31:0] adbusi, adbuso, adbus;


	processor_core ma10032r(clk, reset,
				validaddr, validdata, read, write,
				adbus, adbusi, adbuso);
	always_comb
		if (read)
			adbusi = ram[addr];
		else
			adbusi = 'hZ;

	always_latch
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

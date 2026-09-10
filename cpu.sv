`include modules.sv

module core(input reset);

	logic pspwe, sspwe, pcwe, spsel, regwe, aluoptype, lessthan, equalto;
	logic[1:0] pbmuxsel;
	logic[3:0] regasel, regbsel, regw;
	logic[31:0] wbdata, pspq, sspq, pcq, spmuxout, rega, regb, aluout;

	//Stack pointers
	special_reg psp(wbdata, pspwe, pspq);
	special_reg ssp(wbdata, sspwe, sspq);
	
	//Program counter
	special_reg pc(wbdata, pcwe, pcq);
	
	//Input 0 = Program Stack Pointer
	//Input 1 = Supervisor Stack Pointer
	ttb2inmux spmux(pspq, sspq, spsel, spmuxout);
	
	regfile registers(regasel, regbsel, regw, regwe, reset, wbdata, rega, regb);

	//Input 0 = Register output B
	//Input 1 = Immediate
	//Input 2 = Program Counter
	//Input 3 = SPMux
	ttb4inmux pbmux(regb, 0, pcq, spmuxout, pbmuxsel, aluinb);
	
	//Insert pipeline stage here

	//ALU w/ shifter
	alumod alu(aluop, aluoptype, rega, aluinb, 0, aluout, lessthan, equalto);

	//Multiplier
	multiplier_unit mult(clk, rega, aluinb, templatch, outlatch, 	
endmodule








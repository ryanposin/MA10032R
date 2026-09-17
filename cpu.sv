`include "modules.sv"
/*
module core(input wire reset, input wire clk, inout logic[31:0] addrdata, output logic vdata, output logic vaddr, output logic read, output logic write);

	logic pspwe, sspwe, pcwe, spsel, regwe, aluoptype, lessthan, equalto, accumux, accumulate, templatch, alumuls, bushighz, busvalidaddr, busvaliddata, addroutmuxs;
	logic[1:0] pbmuxsel, multmuxas, multmuxbs, multdemuxs, addrmuxs;
	logic[2:0] aluop;
	logic[3:0] regasel, regbsel, regw;
	logic[15:0] immediate;
	logic[31:0] wbdata, pspq, sspq, pcq, spmuxout, rega, regb, aluinb, aluout, multout, internaldata, addrout;

	//Stack pointers
	special_reg psp(wbdata, pspwe, pspq);
	special_reg ssp(wbdata, sspwe, sspq);
	
	//Program counter
	special_reg pc(wbdata, pcwe, pcq);
	
	//Input 0 = Program Stack Pointer
	//Input 1 = Supervisor Stack Pointer
	ttb2inmux spmux(pspq, sspq, spsel, spmuxout);
	
	//Decode
	//ma10k_frontend decoder(clk, reset, internaldata, regasel, regbsel, regw, regwe, aluoptype, aluop, immediate, bushighz, busvalidaddr, busvaliddata, read, write);

	//Register file
	regfile registers(regasel, regbsel, regw, regwe, reset, wbdata, rega, regb);

	//Input 0 = Register output B
	//Input 1 = Immediate
	//Input 2 = Program Counter
	//Input 3 = SPMux
	ttb4inmux pbmux(regb, {16'b0, immediate}, pcq, spmuxout, pbmuxsel, aluinb);
	
	//Insert pipeline stage here

endmodule
*/

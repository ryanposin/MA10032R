//Inputs: clk, reset
//Outputs: validaddr, validdata, read, write
//Bidirectional: adbus[31:0]

module processor_core(input logic clk, input logic reset,
								output logic validaddr, output logic validdata, output logic read, output logic write,
								inout wire[31:0] adbus);

	logic	mode, ucodereset, pspreset, noteq, pccondout, rawpcwe, lt, eq, condpc, internalreset, qfull, memreq, memreqdir, incprefetch, memwait, instreq, pipeready, pcinc, pcdec, spinc, spdec, spwe, pcwe, regwe, pamuxs, stalldispatchexec, stalldispatchmem, addrsel, datasel, requestdbus, dbusreqdir, dbusdir, dbusreq, pamux_ext, pbmux_ext;
	logic[1:0] immsel, pbmuxs, funcsel, wbmuxsel, pccond;
	logic[3:0] regtowriteo;
	logic[4:0] executec;
	logic[6:0] opcode_pointer, opcode_pointero;
	logic[15:0] immediate;
	logic[39:0] icodeo;
	logic[31:0] immediate32, memaddr, programcounter, toprefetch, tofetch, insout, writeback, programstackpointer, supervisorstackpointer, rega, regb, immsignextend, currentsp, outmuxa, outmuxb, ao, bo, execout, memout;
	wire[31:0] memdata, memdataexec, memdatatemp;
	
	always_comb
		begin
			regwe = icodeo[0];
			pcinc = icodeo[1];
			pcdec = icodeo[2];
			spinc = icodeo[3];
			spdec = icodeo[4];
			spwe = icodeo[5];
			pamuxs = icodeo[6];
			pbmuxs = icodeo[8:7];
			addrsel = icodeo[9];
			datasel = icodeo[10];
			requestdbus = icodeo[11];
			dbusreqdir = icodeo[12];
			wbmuxsel = icodeo[14:13];
			funcsel = icodeo[16:15];
			immsel = icodeo[33:32];
			condpc = icodeo[34];
			pccond = icodeo[36:35];
			ucodereset = icodeo[37];
			pspreset = icodeo[38];
			rawpcwe = icodeo[39];
			pcwe = condpc ? pccondout : rawpcwe;
			internalreset = reset | ucodereset;
			noteq = ~eq;
			pipeready = ~(stalldispatchmem | stalldispatchexec);
	end
	
	always_ff @(posedge clk)
			if (icodeo[39] & ({1'b0,opcode_pointer} == 8'h0F))
				mode <= 0;
			else if (icodeo[39] & ({1'b0,opcode_pointer} == 8'h70))
				mode <= 1;
	
	ob4inmux pccondmux(eq, noteq, lt, lt | eq, pccond, pccondout);
	
	//Inputs: clk, reset, qfull, memreq, memreqdir, memaddr, programcounter
	//Outputs: validaddr, validdata, read, write, incprefetch, toprefetch, memwait
	//Inout: adbus, memdata
	busunit busconnection(clk, internalreset, qfull, memreq, dbusreqdir, memaddr, programcounter,
									validaddr, validdata, read, write, incprefetch, toprefetch, memwait,
									adbus, memdata);

	//Inputs: clk, reset, instreq, instadd, insttoadd
	//Outputs: qfull, tofetch
	prefetcher prefetch(clk, internalreset, instreq, incprefetch, toprefetch,
								qfull, tofetch);
	
	//Inputs: clk, reset, ready, insin
	//Outputs: instreq, instout
	fetcher fetch(clk, internalreset, pipeready, tofetch,
						instreq, insout);
	
	//Input: clk, reset, increment, decrement, write enable, d
	//Output: q
	ma10k_special_reg pc(clk, internalreset, pcinc, pcdec, pcwe, writeback, programcounter);
	ma10k_special_reg psp(clk, internalreset | pspreset, spinc, spdec, spwe, writeback, programstackpointer);
	ma10k_special_reg ssp(clk, internalreset, spinc, spdec, spwe, writeback, supervisorstackpointer);
	
	always_comb currentsp = mode ? programstackpointer : supervisorstackpointer;
	
	//Inputs: instruction
	//Outputs: immediate[15:0], opcode_pointer[6:0], pamux_ext, pbmux_ext
	ma10k_frontend decoder(insout,
									immediate, opcode_pointer);
	
	//Input: clk, reset, portasel, portbsel, writesel, writeenable, writeinput[31:0]
	//Output: a, b 
	regfile registers(clk, internalreset, insout[7:4], insout[3:0], regtowriteo, regwe, writeback,
							rega, regb);
	
	
	ttb4inmux immmux({16'b0,immediate},{immediate,16'b0}, {{16{immediate[15]}},immediate[15:0]}, 0, immsel, immediate32);
	ttb2inmux pamux(rega, programcounter, pamuxs, outmuxa);
	ttb4inmux pbmux(regb, immediate32, currentsp, programcounter, pbmuxs, outmuxb);
	
	//Inputs: clk, reset, stall, icode[18], a, b, regtowrite
	//Outputs: icodefunc, afunc, bfunc, regtowritefunc
	pipebreak pipestage01(clk, internalreset, pipeready, opcode_pointer, outmuxa, outmuxb, insout[11:8],
																opcode_pointero, ao, bo, regtowriteo);
	
	//Inputs: clk, reset, funcsel, ina, inb, pointer[6:0]
//Outputs: execout, stalldispatch, lt, eq, executec, fucode
	execute_unit exec(clk, internalreset, funcsel, ao, bo, opcode_pointero,
														execout, stalldispatchexec, lt, eq, executec, icodeo);
	
	//Inputs: fromexecute, portb, addrsel, datasel, requestdbus, dbusreqdir, buswait
	//Outputs: dbusreq, dbusdir, addr, towriteback, stalldispatch 
	//Inout: data
	mem_access_unit memaccess(execout, bo, addrsel, datasel, requestdbus, dbusreqdir, memwait,
																				memreq, memreqdir, memaddr, memout, stalldispatchmem,
																				memdata);
	
	//Inputs
	ttb4inmux wbmux(execout, memout, bo, 0, wbmuxsel, writeback);
								
endmodule

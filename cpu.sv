//Inputs: clk, reset
//Outputs: validaddr, validdata, read, write, buswidth[1:0] (0 = 8 bit, 1 = 16 bit, 2 = 32 bit)
//Bidirectional: adbus[31:0]

module processor_core(input logic clk, input logic reset, input logic nmi, input logic[2:0] intin,
								output logic validaddr, output logic validdata, output logic read, output logic write, output logic[1:0] buswidth, output logic intack,
								inout wire[31:0] adbus);//, input logic[31:0] adbusi, output logic[31:0] adbuso);

	logic	mode, ucodereset, memfinished, pspreset, noteq, pccondout, rawpcwe, lt, eq, condpc, internalreset, qfull, memreq, memreqdir, incprefetch, memwait, instreq, pipeready, pcinc, pcdec, spinc, spdec, spwe, pcwe, regwe, pamuxs, stalldispatchexec, stalldispatchmem, addrsel, datasel, requestdbus, dbusreqdir, dbusdir, dbusreq, pamux_ext, pbmux_ext, newmicrocode, qempty, incpcfetch, breset, feq, fneq, flt, ppas, injectinst, nmilatched, inten;
	logic[1:0] immsel, pbmuxs, funcsel, wbmuxsel, pccond, ppbs;
	logic[2:0] intlatched;
	logic[3:0] regtowriteo;
	logic[4:0] executec;
	logic[6:0] opcode_pointer, opcode_pointero, injectpointer;
	logic[15:0] immediate;
	logic[47:0] icodeo, icode;
	logic[31:0] immediate32, memaddr, programcounter, toprefetch, tofetch, insout, writeback, programstackpointer, supervisorstackpointer, rega, regb, immsignextend, currentsp, outmuxa, outmuxb, ao, bo, execout, memout, pipea, pipeb, pcchain, programcounterinst, programcountero;
	wire[31:0] memdata, memdataexec, memdatatemp;
	logic[31:0] tempimm, aforward, bforward, intaddr;
	microcode_rom microcode2({1'b0, opcode_pointer}, icode);
	
	always_ff @(posedge clk)
		{feq, fneq, flt} <= {eq, noteq, lt};
	always_ff @(posedge clk)
		if (opcode_pointer >= 46 & opcode_pointer <= 60)
			tempimm <= {{16{insout[31]}},insout[31:20],insout[11:8]};
	always_ff @(posedge clk)
		if (opcode_pointero == 91 | opcode_pointero == 92)
			inten <= icodeo[47];
	/* verilator lint_off ALWCOMBORDER */
	always_comb
		begin
			if (requestdbus)
				regwe = memfinished ? icodeo[0] : 0;
			else
				regwe = icodeo[0];

			pcinc = incpcfetch; //(icodeo[1] & pipeready & incpcfetch);
			pcdec = icodeo[2];
			spinc = icodeo[3];
			spdec = icodeo[4];
			spwe = icodeo[5];
			pamuxs = icode[6];
			pbmuxs = icode[8:7];
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
			ppas = icodeo[41];
			ppbs = icodeo[43:42];
			buswidth = icodeo[45:44];
			intack = icodeo[46];
			pcwe = condpc ? pccondout : rawpcwe;
			internalreset = ~reset | ucodereset;
			noteq = ~eq;
			pipeready = ~(stalldispatchmem | stalldispatchexec);
			newmicrocode = icodeo[31];
			

			/*if (opcode_pointero >= 46 & opcode_pointero <= 59)
				breset = 1;
			else
				breset = 0;*/
			/* verilator lint_off ALWCOMBORDER */
			/* verilator lint_off MULTIDRIVEN */
			/*if ((validdata) & read)
				adbus = adbusi;
			else
				adbus = 'hZ;
			if (validaddr | write)
				adbuso =  adbus;
			else
				adbuso = 'hZ;*/
	end
	
	always_ff @(posedge clk)
			if (icodeo[40] & ({1'b0,opcode_pointer} == 8'h0F))
				mode <= 0;
			else if (icodeo[40] & ({1'b0,opcode_pointer} == 8'h70))
				mode <= 1;
	
	ob4inmux pccondmux(feq, fneq, flt, flt | feq, pccond, pccondout);
	
	//Inputs: clk, reset, qfull, memreq, memreqdir, memaddr, programcounter
	//Outputs: validaddr, validdata, read, write, incprefetch, toprefetch, memwait, memfinished
	//Inout: adbus, memdata
	busunit busconnection(clk, internalreset | pcwe, qfull, memreq, dbusreqdir, memaddr, programcounter, buswidth,
									validaddr, validdata, read, write, incprefetch, toprefetch, memwait, incpcfetch, memfinished, pcchain,
									adbus, memdata);

	//Inputs: clk, reset, instreq, instadd, insttoadd
	//Outputs: qfull, tofetch
	prefetcher prefetch(clk, internalreset | pcwe, pipeready & ~injectinst, incprefetch, toprefetch, pcchain,
								qempty, qfull, insout, programcounterinst);
	
	//Inputs: clk, reset, ready, insin
	//Outputs: instreq, instout
	//fetcher fetch(clk, internalreset, pipeready, tofetch,
	//					instreq, insout);
	
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
	
	interruptprivilage intprivarbiter(insout[19:12], intin, nmi, mode, inten,
				injectinst, injectpointer);

	//Input: clk, reset, portasel, portbsel, writesel, writeenable, writeinput[31:0]
	//Output: a, b 
	regfile registers(clk, internalreset, insout[7:4], insout[3:0], regtowriteo, regwe, writeback,
							rega, regb);
	
	//Port A and Port B muxes	
	ttb4inmux immmux({16'b0,immediate},{immediate,16'b0}, {{16{immediate[15]}},immediate[15:0]}, 0, immsel, immediate32);
	ttb2inmux pamux(rega, programcounter, pamuxs, outmuxa);
	ttb4inmux pbmux(regb, immediate32, currentsp, programcounter, pbmuxs, outmuxb);


	//Pipeline forwarding
	always_comb
		if (insout[3:0] == regtowriteo)
			begin
				aforward = writeback;
				bforward = outmuxb;
			end
		else if (insout[7:4] == regtowriteo)
			begin
				aforward = outmuxa;
				bforward = writeback;
			end
		else
			begin
				aforward = outmuxa;
				bforward = outmuxb;
			end

	//Inputs: clk, reset, stall, icode[18], a, b, regtowrite
	//Outputs: icodefunc, afunc, bfunc, regtowritefunc
	pipebreak pipestage01(clk, internalreset, ~pipeready | pcwe, (injectinst ? injectpointer : opcode_pointer), aforward, bforward, insout[11:8], programcounterinst, intin, nmi,
															opcode_pointero, ao, bo, regtowriteo, programcountero, intlatched, nmilatched);
	
	//Grab PC or port A
	ttb2inmux postpipea(ao, programcountero, ppas, pipea);
	//Grab port B or latched immediate
	assign intaddr = nmilatched ? 32'hFFFF_FFE0 : (intlatched[2] ? (intlatched[1] ? (intlatched[0] ? 32'hFFFF_FFFC : 32'hFFFF_FFF8 ) : (intlatched[0] ? 32'hFFFF_FFF4 : 32'hFFFF_FFF0 )) : (intlatched[1] ? (intlatched[0] ? 32'hFFFF_FFEC: 32'hFFFF_FFE8 ) : (intlatched[0] ? 32'hFFFF_FFE4 : 32'hFFFF_FFE0 )));
	ttb4inmux postpipeb(bo, tempimm, intaddr, 32'hFFFF_FFDC, ppbs, pipeb);
	//Inputs: clk, reset, funcsel, ina, inb, pointer[6:0]
//Outputs: execout, stalldispatch, lt, eq, executec, fucode
	execute_unit exec(clk, internalreset, newmicrocode, funcsel, pipea, pipeb, opcode_pointero, memwait,
														execout, stalldispatchexec, lt, eq, executec, icodeo);
	
	//Inputs: fromexecute, portb, addrsel, datasel, requestdbus, dbusreqdir, buswait, memfinished
	//Outputs: dbusreq, dbusdir, addr, towriteback, stalldispatch 
	//Inout: data
	mem_access_unit memaccess(clk, internalreset, execout, pipeb, addrsel, datasel, requestdbus, dbusreqdir, memwait, memfinished,
																				memreq, memreqdir, memaddr, memout, stalldispatchmem,
																				memdata);
	
	//Writeback multiplexer
	ttb4inmux wbmux(execout, memout, bo, 0, wbmuxsel, writeback);
								
endmodule

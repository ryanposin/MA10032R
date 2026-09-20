`include "modules.sv"

//Inputs: clk, reset
//Outputs: validaddr, validdata, read, write
//Bidirectional: adbus[31:0]
module core(input logic clk, reset, output logic validaddr, validdata, read, write, inout logic[31:0] adbus);

logic qfull, memreq, memreqdir, incprefetch, memwait;
logic[31:0] memaddr;
logic instreq;
logic execready, execbothready;
logic pcinc, pcdec, rawpcwe, pcwe, pspinc, pspdec, pspwe, sspinc, sspdec, sspwe, spwe, condpc;
logic[1:0] pccond;
logic mode;
logic[31:0] toprefetch, immsignextend, memdata, tofetch, todecode, writeback, rega, regb, memout, pcount, progspoint, supspoint, currentsp, outmuxa;
logic pamuxs;
logic[1:0] pbmuxs, immhighlows;
logic[38:0] ucodebank[18], fucodebank[18];
logic[3:0] regtowrite;
logic regwe;
logic[31:0] outmuxb, funca, funcb;
logic[31:0] execout;
logic[15:0] immediate;
logic[31:0] immediate32;
logic addrsel, datasel, requestdbus, dbusreqdir, memready, pccondout, spdec, spinc, eq, lt;
logic[1:0] wbmuxs, execmode;
logic[4:0] fcount;
logic internalreset;
logic pspreset;

always_comb
	begin
		regwe = fucodebank[fcount][0];
		pcinc = fucodebank[fcount][1];
		pcdec = fucodebank[fcount][2];
		spinc = fucodebank[fcount][3];
		spdec = fucodebank[fcount][4];
		spwe = fucodebank[fcount][5];
		pamuxs = ucodebank[0][6];
		pbmuxs = ucodebank[0][8:7];
		addrsel = fucodebank[fcount][9];
		datasel = fucodebank[fcount][10];
		requestdbus = fucodebank[fcount][11];
		dbusreqdir = fucodebank[fcount][12];
		wbmuxs = fucodebank[fcount][14:13];
		execmode = fucodebank[fcount][16:15];
		immhighlows = fucodebank[fcount][33:32];
		condpc = fucodebank[fcount][34];
		pccond = fucodebank[fcount][36:35];
		internalreset = fucodebank[fcount][37];
		pspreset = fucodebank[fcount][38];
	end

//From external: clk, reset
//To external: validaddr, validdata, read, write
//Bidirectional external: adbus
busunit busfrontend(clk, ~reset, qfull, memreq, memreqdir, memaddr, pcount, validaddr, validdata, read, write, incprefetch, toprefetch, memwait, adbus, memdata);


prefetcher prefetch(clk, ~reset, instreq, incprefetch, toprefetch, qfull, tofetch);

fetcher fetch(clk, ~reset, execbothready, tofetch, todecode);

ob4inmux pccondmux(eq, ~eq, lt, lt | eq, pccond, pccondout);
always pcwe = condpc ? pccondout : rawpcwe;

//00 - Equal
//01 - Not equal
//10 - Less than
//11 - Less than or equal to

special_reg pc(clk, ~reset, pcinc, pcdec, pcwe, writeback, pcount);

always_comb
	begin
		pspinc = mode ? spinc : 0;
		pspdec = mode ? spdec : 0;
		sspinc = mode ? 0 : spinc;
		sspdec = mode ? 0 : spdec;
		pspwe = mode ? spwe : 0;
		sspwe = mode ? 0 : spwe;
	end

special_reg psp(clk, ~reset, pspinc, pspdec, pspwe, writeback, progspoint);
special_reg ssp(clk, ~reset, sspinc, sspdec, sspwe, writeback, supspoint);

ma10k_frontend decode(todecode, immediate, ucodebank);

regfile registers(clk, ~reset, todecode[7:4],todecode[3:0],regtowrite, regwe, writeback, rega, regb);

always_comb currentsp = mode ? progspoint : supspoint;

always_comb
	if (immediate[15])
		immsignextend = {16'b1,immediate[15:0]};
	else
		immsignextend = {16'b0,immediate[15:0]};

ttb4inmux immmux({16'b0,immediate},{immediate,16'b0}, immsignextend, 0, immhighlows, immediate32);
ttb4inmux pbmux(regb, immediate32, currentsp, pcount, pbmuxs, outmuxb);
ttb2inmux pamux(rega, pcount, pamuxs, outmuxa);

pipebreak pipestage01(clk, ~reset, execbothready, ucodebank, outmuxa, outmuxb, todecode[11:8], fucodebank[17:0], funca, funcb, regtowrite);

execute_unit execution(clk, ~reset, execmode, funca, funcb, fucodebank[17:0], execout, ~execready, lt, eq, fcount);

mem_access_unit memaccess(execout, funcb, addrsel, datasel, requestdbus, dbusreqdir, memwait, memreq, memreqdir, memaddr, memout, ~memready, memdata);

ttb4inmux wbmux(execout, memout, funcb, 0, wbmuxs, writeback);

always_comb execbothready = memready | execready;
endmodule

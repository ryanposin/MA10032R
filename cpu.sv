`include "modules.sv"

//Inputs: clk, reset
//Outputs: validaddr, validdata, read, write
//Bidirectional: adbus[31:0]
module core(input logic clk, reset, output logic validaddr, validdata, read, write, inout logic[31:0] adbus);

logic qfull, memreq, memreqdir, incprefetch, memwait;
logic[31:0] memaddr;
logic instreq, incprefetch, qfull;
logic execready, execbothready;
logic pcinc, pcdec, rawpcwe, pcwe, pspinc, pspdec, pspwe, sspinc, sspdec, sspwe;
logic[1:0] pccond;
logic mode;
logic[31:0] toprefetch, memdata, tofetch, todecode, writeback, rega, regb, memout, pcount, progspoint, supspoint, currentsp outmuxa;
logic pamuxs;
logic[1:0] pbmuxs;
logic[21:0] ucodebank[], fucodebank[18];
logic[3:0] regtowrite;
logic regwe;
logic[31:0] outmuxb, funca, funcb;
logic[31:0] execout;
logic addrsel, datasel, requestdbus, dbusreqdir, memready;
logic[1:0] wbmuxs;

//From external: clk, reset
//To external: validaddr, validdata, read, write
//Bidirectional external: adbus
busunit busfrontend(clk, ~reset, qfull, memreq, memreqdir, memaddr, programcounter, validaddr, validdata, read, write, incprefetch, toprefetch, memwait, adbus, memdata);


prefetcher prefetch(clk, ~reset, instreq, incprefetch, toprefetch, qfull, tofetch);

fetcher fetch(clk, ~reset, execbothready, tofetch, todecode);

pcwe = condpc ? ( pccond[1] ? ((pccond[0] ? (lt & eq) : lt) : (pccond[0] ? ~eq : eq))) : rawpcwe;

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

ma10k_frontend decode(todecode, ucodebank);

regfile registers(clk, ~reset, todecode[7:4],todecode[3:0],regtowrite, regwe, writeback, rega, regb);

always_comb currentsp = mode ? progspoint : supspoint;

ttb4inmux immmux({16'b0,immediate},{immediate,16'b0}, {immediate[15],immediate[15:0]} immhighlows, immediate32);
ttb4inmux pbmux(regb, immediate32, currentsp, pcount, pbmuxs, outmuxb);
ttb2inmux pamux(rega, pcount, pamuxs, outmuxa);

pipebreak pipestage01(clk, ~reset, execbothready, ucodebank, outmuxa, outmuxb, todecode[11:8], fucodebank, funca, funcb, regtowrite);

execute_unit execution(clk, ~reset, fucodebank[], funca, funcb, fucodebank[], execout, ~execready);

mem_access_unit memaccess(execout, funcb, addrsel, datasel, requestdbus, dbusreqdir, memwait, memreq, memreqdir, memaddr, memout, ~memready, memdata);

ttb4inmux wbmux(execout, memout, funcb, 0, wbmuxs, writeback);

always_comb execbothready = memready | execready;
endmodule

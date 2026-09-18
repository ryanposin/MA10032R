`include "modules.sv"

//Inputs: clk, reset
//Outputs: validaddr, validdata, read, write
//Bidirectional: adbus[31:0]
module core(input logic clk, reset, output logic validaddr, validdata, read, write, inout logic[31:0] adbus);

logic qfull, memreq, memreqdir, memaddr, incprefetch, memwait;
logic instreq, incprefetch, qfull;
logic execready, execbothready;
logic pcinc, pcdec, pcwe, pspinc, pspdec, pspwe, sspinc, sspdec, sspwe;
logic[31:0] toprefetch, memdata, tofetch, todecode, writeback, rega, regb;
logic[21:0] ucodebank[], fucodebank[18];
logic[3:0] regtowrite;
logic regwe;
logic[31:0] outmuxb, funca, funcb;
logic[31:0] execout;
logic addrsel, datasel, requestdbus, dbusreqdir, memready;

//From external: clk, reset
//To external: validaddr, validdata, read, write
//Bidirectional external: adbus
busunit busfrontend(clk, ~reset, qfull, memreq, memreqdir, memaddr, programcounter, validaddr, validdata, read, write, incprefetch, toprefetch, memwait, adbus, memdata);


prefetcher prefetch(clk, ~reset, instreq, incprefetch, toprefetch, qfull, tofetch);

fetcher fetch(clk, ~reset, execbothready, tofetch, todecode);

special_reg pc(clk, ~reset, pcinc, pcdec, pcwe, writeback);

special_reg psp(clk, ~reset, pspinc, pspdec, pspwe, writeback);
special_reg ssp(clk, ~reset, sspinc, sspdec, sspwe, writeback);

ma10k_frontend decode(todecode, ucodebank);

regfile registers(clk, ~reset, todecode[7:4],todecode[3:0],regtowrite, regwe, rega, regb);

pipebreak pipestage01(clk, ~reset, execbothready, ucodebank, rega, outmuxb, todecode[11:8], fucodebank, funca, funcb, regtowrite);

execute_unit execution(clk, ~reset, fucodebank[], funca, funcb, fucodebank[], execout, ~execready);

mem_access_unit memaccess(execout, funcb, addrsel, datasel, requestdbus, dbusreqdir, memwait, memreq, memreqdir, memaddr, writeback, ~memready, memdata);

always execbothready = memready | execready;
endmodule

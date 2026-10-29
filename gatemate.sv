interface mabus();
    logic[31:0] WDATA, RDATA, WADDR, RADDR;
    logic READ, WRITE;
    logic[1:0] WWIDTH, RWIDTH;
    logic READWAIT;
    modport master (output WADDR, output RADDR, output WDATA, input RDATA, output READ, output WRITE, output WWIDTH, output RWIDTH, input READWAIT);
    modport slave (input WADDR, input RADDR, input WDATA, output RDATA, input READ, input WRITE, input WWIDTH, input RWIDTH, output READWAIT);
endinterface
    

module cpu_wrapper (input logic mclk, input logic reset, input logic[2:0] intin, input logic nonmi, output logic intack, input logic rx, output logic tx);

logic cpuclk, uartclk,c2,locked, fbclk;

logic ar_ready, r_ready, aw_ready, w_ready, b_ready, r_valid, aw_valid, w_valid, b_valid;
logic[1:0] clkstate, b_response;
logic[7:0] uartdata;
logic[3:0] r_width, w_width;
logic[31:0] ar_addr, r_data, aw_addr, w_data, r_data_uart, ar_addr_uart, aw_addr_uart, w_data_uart;
logic uartcs, aw_valid_uart, w_valid_uart,
            ar_valid_uart, r_ready_uart, aw_ready_uart, w_ready_uart, ar_ready_uart, r_valid_uart,
            b_valid_uart, b_ready_uart,pcasserted,resetout;
logic[1:0] buswidth, rresp, b_response_uart, pcstatus;

    mabus uartmabus();
    mabus rommabus();
    mabus cpumabus();
    mabus rammabus();
    mabus vectormabus();
    
clk_wiz_0 mcmm_clk (cpuclk,mclk);

//System
processor_core ma10k(cpuclk, reset, nonmi, intin, cpumabus.READWAIT,
			intack,
			cpumabus.WDATA, cpumabus.RDATA,
			cpumabus.WADDR, cpumabus.RADDR,
			cpumabus.READ, cpumabus.WRITE, cpumabus.WWIDTH, cpumabus.RWIDTH);

maswitch mabusswitch(
cpumabus,
rommabus,
uartmabus,
rammabus,
vectormabus);

uartmod uart (cpuclk, ~reset, uartmabus, rx, tx);

rammod ram(cpuclk, rammabus);
vectors vector(cpuclk, vectormabus);

instmem instrom(rommabus);

endmodule

module instmem(mabus.slave MABUS);
    logic[31:0] rom[2048];
    
    initial begin
        $readmemh("monitor.hex",rom);
    end
    
    always_comb
        if (MABUS.READ)
            MABUS.RDATA = rom[MABUS.RADDR];
        else
            MABUS.RDATA = 0;
endmodule

module maswitch(mabus.slave MASLAVE0, mabus.master MAMASTER0, mabus.master MAMASTER1, mabus.master MAMASTER2, mabus.master MAMASTER3);

always_comb
    begin
        if (MASLAVE0.RADDR < 'h4000)
            begin
                MAMASTER0.RADDR = MASLAVE0.RADDR[13:2];
                MASLAVE0.RDATA =  MAMASTER0.RDATA;
                MAMASTER0.READ = MASLAVE0.READ;
                MASLAVE0.READWAIT = 0;
                
                MAMASTER1.RADDR = 0;
                MAMASTER1.READ = 0;
                
                MAMASTER2.RADDR = 0;
                MAMASTER2.READ = 0;
                
                MAMASTER3.RADDR = 0;
                MAMASTER3.READ = 0;
            end
        else if (MASLAVE0.RADDR >= 'hFFF0 & MASLAVE0.RADDR <= 'hFFFF)
            begin
                MAMASTER0.RADDR = 0;
                MAMASTER0.READ = 0;
                
                MAMASTER1.RADDR = {28'b0,MASLAVE0.RADDR};
                MASLAVE0.RDATA =  MAMASTER1.RDATA;
                MAMASTER1.READ = MASLAVE0.READ;
                MASLAVE0.READWAIT = 0;
                
                MAMASTER2.RADDR = 0;
                MAMASTER2.READ = 0;
                
                MAMASTER3.RADDR = 0;
                MAMASTER3.READ = 0;
            end
            else if (MASLAVE0.RADDR >= 'h4000 & MASLAVE0.RADDR <= 'h7FFF)
            begin
                MAMASTER0.RADDR = 0;
                MAMASTER0.READ = 0;
                
                MAMASTER1.RADDR = 0;
                MAMASTER1.READ = 0;
                MASLAVE0.READWAIT = MAMASTER2.READWAIT;
                
                MAMASTER2.RADDR = MASLAVE0.RADDR[13:2];
                MASLAVE0.RDATA =  MAMASTER2.RDATA;
                MAMASTER2.READ = MASLAVE0.READ;
                
                MAMASTER3.RADDR = 0;
                MAMASTER3.READ = 0;
            end
            else if (MASLAVE0.RADDR >= 'hFFFFFFE0 & MASLAVE0.RADDR <= 'hFFFFFFFF)
            begin
                MAMASTER0.RADDR = 0;
                MAMASTER0.READ = 0;
                
                MAMASTER1.RADDR = 0;
                MAMASTER1.READ = 0;
                
                MAMASTER2.RADDR = 0;
                MAMASTER2.READ = 0;
                
                MASLAVE0.READWAIT = MAMASTER3.READWAIT;
                
                MAMASTER3.RADDR = MASLAVE0.RADDR[11:2];
                MASLAVE0.RDATA =  MAMASTER3.RDATA;
                MAMASTER3.READ = MASLAVE0.READ;
            end
        else
            begin
                MAMASTER0.RADDR = 0;
                MAMASTER0.READ = 0;
                MASLAVE0.READWAIT = 0;
                MAMASTER1.RADDR = 0;
                MAMASTER1.READ = 0;
                
                MAMASTER2.RADDR = 0;
                MASLAVE0.RDATA =  0;
                MAMASTER2.READ = 0;
                
                MAMASTER3.RADDR = 0;
                MAMASTER3.READ = 0;
            end
        
        if (MASLAVE0.WADDR < 'h4000)
            begin
                MAMASTER0.WADDR = MASLAVE0.WADDR;
                MAMASTER0.WDATA =  MASLAVE0.WDATA;
                MAMASTER0.WRITE = MASLAVE0.WRITE;
                
                MAMASTER1.WADDR = 0;
                MAMASTER1.WDATA = 0;
                MAMASTER1.WRITE = 0;
                
                MAMASTER2.WADDR = 0;
                MAMASTER2.WDATA = 0;
                MAMASTER2.WRITE = 0;
                
                MAMASTER3.WADDR = 0;
                MAMASTER3.WDATA = 0;
                MAMASTER3.WRITE = 0;
            end
        else if (MASLAVE0.WADDR >= 32'hFFF0 & MASLAVE0.WADDR <= 32'hFFFF)
            begin
                MAMASTER0.WADDR = 0;
                MAMASTER0.WDATA = 0;
                MAMASTER0.WRITE = 0;
                
                MAMASTER1.WADDR = {28'b0,MASLAVE0.WADDR[3:0]};
                MAMASTER1.WDATA =  {24'b0,MASLAVE0.WDATA};
                MAMASTER1.WRITE = MASLAVE0.WRITE;
                
                MAMASTER2.WADDR = 0;
                MAMASTER2.WDATA = 0;
                MAMASTER2.WRITE = 0;
                
                MAMASTER3.WADDR = 0;
                MAMASTER3.WDATA = 0;
                MAMASTER3.WRITE = 0;
            end
         else if (MASLAVE0.WADDR >= 'h4000 & MASLAVE0.WADDR <= 'h7FFF)
            begin
                MAMASTER0.WADDR = 0;
                MAMASTER0.WDATA = 0;
                MAMASTER0.WRITE = 0;
                
                MAMASTER1.WADDR = 0;
                MAMASTER1.WDATA = 0;
                MAMASTER1.WRITE = 0;
                
                MAMASTER2.WADDR = MASLAVE0.WADDR[13:2];
                MAMASTER2.WDATA =  MASLAVE0.WDATA;
                MAMASTER2.WRITE = MASLAVE0.WRITE;
                
                MAMASTER3.WADDR = 0;
                MAMASTER3.WDATA = 0;
                MAMASTER3.WRITE = 0;
            end
          else if (MASLAVE0.WADDR >= 'hFFFFFFE0 & MASLAVE0.WADDR <= 'hFFFFFFFF)
            begin
                MAMASTER0.WADDR = 0;
                MAMASTER0.WDATA = 0;
                MAMASTER0.WRITE = 0;
                
                MAMASTER1.WADDR = 0;
                MAMASTER1.WDATA = 0;
                MAMASTER1.WRITE = 0;
                
                MAMASTER2.WADDR = 0;
                MAMASTER2.WDATA = 0;
                MAMASTER2.WRITE = 0;
                
                MAMASTER3.WADDR = MASLAVE0.WADDR[11:2];
                MAMASTER3.WDATA =  MASLAVE0.WDATA;
                MAMASTER3.WRITE = MASLAVE0.WRITE;
            end
        else
            begin
                MAMASTER0.WADDR = 0;
                MAMASTER0.WDATA = 0;
                MAMASTER0.WRITE = 0;
                
                MAMASTER1.WADDR = 0;
                MAMASTER1.WDATA = 0;
                MAMASTER1.WRITE = 0;
                
                MAMASTER2.WADDR = 0;
                MAMASTER2.WDATA =  0;
                MAMASTER2.WRITE = 0;
                
                MAMASTER3.WADDR = 0;
                MAMASTER3.WDATA = 0;
                MAMASTER3.WRITE = 0;
            end
    end

endmodule

module rammod(input clk, mabus.slave MABUS);
(* ram_style = "block" *) logic[31:0] ram[4096];
logic readdone;
    always_ff @(posedge clk)
        begin
        if (MABUS.WRITE)
            ram[MABUS.WADDR] <= MABUS.WDATA;
       
        if (MABUS.READ)
            begin
                MABUS.RDATA <= ram[MABUS.RADDR];
                readdone <= 1;
            end
            else
                readdone <= 0;
        end
        
        always_comb
            if (MABUS.READ & ~readdone)
                MABUS.READWAIT = 1;
            else
                MABUS.READWAIT = 0;
endmodule

module vectors(input clk, mabus.slave MABUS);
(* ram_style = "block" *) logic[31:0] ram[8];
logic readdone;
    always_ff @(posedge clk)
        begin
        if (MABUS.WRITE)
            ram[MABUS.WADDR] <= MABUS.WDATA;
       
        if (MABUS.READ)
            begin
                MABUS.RDATA <= ram[MABUS.RADDR];
                readdone <= 1;
            end
            else
                readdone <= 0;
        end
        
        always_comb
            if (MABUS.READ & ~readdone)
                MABUS.READWAIT = 1;
            else
                MABUS.READWAIT = 0;
endmodule


module uartmod(input logic clk, reset, mabus.slave MABUS, input logic rx, output logic tx);
logic[7:0] registers[3:0];
//Registers 0 = TX  
//Registers 1 = RX
//Registers 2 = Status
//Registers 3 = Control

logic[31:0] clkcounter;
logic rxstate;
logic[2:0] txstate;
logic[3:0] rxcount, txcount;
logic[3:0] oversamplediv;
localparam IDLE = 0;
localparam DATAIN = 1;

localparam START = 1;
localparam DATA = 2;
localparam STOP = 3;
localparam WAIT = 4;

//Clock generation
always_ff @(posedge clk)
	if (reset)
		begin
		    registers[0] <= 8'b0;
		    registers[2] <= 8'b0;
		    registers[3] <= 8'b0;
			clkcounter <= 32'b0;
		end
	else
	   begin
	        if (MABUS.WADDR == 32'h0 & MABUS.WRITE == 1)
	            begin
	                registers[0] <= MABUS.WDATA[7:0];
	                registers[2][1] <= 1;
                 end
            else if (MABUS.WADDR == 32'hC & MABUS.WRITE == 1)
                registers[3] <= MABUS.WDATA[7:0];
	        
	        if (txstate == STOP)
                begin
                    registers[0] <= 0;
                end
            else if (txstate == IDLE & registers[0] == 0 & MABUS.WRITE != 1)
                registers[2][1] <= 0;
	           
		    clkcounter <= clkcounter + 32'd131941395;
		    
		    //RX full clear
		    if (MABUS.RADDR == 32'h4)
		      registers[2][0] <= 0;
		    else if (rxcount == 8)
		      registers[2][0] <= 1;
		    
		    
		end

always_ff @(posedge clkcounter[27] or posedge reset) //Recieve at x16 oversampling
    if (reset)
        begin
            rxstate <= IDLE;
            rxcount <= 0;
            registers[1] <= 8'b0;
        end
     else
        begin
             case (rxstate)
                IDLE: if (rx == 0)
                    begin
                        rxstate <= DATAIN;
                        registers[1] <= 0;
                        oversamplediv <= 0;
                    end
                DATAIN: begin
                          oversamplediv <= oversamplediv + 1;
                          if (oversamplediv == 15)
                            begin
                                registers[1][rxcount] <= rx;
                                if (rxcount == 7)
                                    rxstate <= IDLE;
                                else
                                    rxcount <= rxcount + 1;
                            end
                        end
            endcase
        end

always_ff @(posedge clkcounter[31] or posedge reset)
    if (reset)
        begin
            txstate <= IDLE;
            //registers[1] = 8'b0;
            txcount <= 0;
        end
    else
        begin
            case(txstate)
                IDLE: if (registers[0][7:0] != 8'b0)//(registers[2][1])
                        txstate <= START;
                START: txstate <= DATA;
                DATA: if (txcount >= 7)
                        txstate <= STOP;
                      else
                        txcount <= txcount + 1;
                STOP: begin
                        txstate <= IDLE;
                        txcount <= 0;
                      end
            endcase
        end
        

always_comb
    begin
        MABUS.RDATA = {24'b0, registers[MABUS.RADDR[3:2]]};
        
        case(txstate)
            IDLE: tx = 1;
            START: tx = 0;
            DATA: tx = registers[0][txcount];
            STOP: tx = 1;
            WAIT: tx = 1;
            default: tx = 1;
        endcase
        
    end

endmodule
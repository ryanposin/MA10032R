/* verilator lint_off UNOPTFLAT*/
//Special register, for SP and PC
//Input: clk, reset, increment, decrement, write enable, d
//Output: q
module ma10k_special_reg (input wire clk, input wire reset, input wire inc, input wire dec, input wire we, input logic[31:0] d, output logic[31:0] q);
	always_ff @(posedge clk)
		begin
			if (reset)
				q <= 0;
			else
				if (we)
				    q <= d;
				else if (~we & dec)
				    q <= q - 4;
				else if (~we & inc)
					q <= q + 4;
				else if (~we & inc & dec)
					q <= q;
			
		end
endmodule

//32 bit 2:1 MUX
module ttb2inmux (input wire[31:0] i0, input wire[31:0] i1, input wire select, output logic[31:0] q);
	always_comb
		q = select ? i1 : i0; 
endmodule

//32 bit 4:1 MUX
module ttb4inmux (input wire[31:0] i0, input wire[31:0] i1, input wire[31:0] i2, input wire[31:0] i3, input wire[1:0] select, output logic[31:0] q);
	always_comb
		q = select[1] ? (select[0] ? i3 : i2) : (select[0] ? i1 : i0);
endmodule

module ob4inmux (input wire i0, input wire i1, input wire i2, input wire i3, input wire[1:0] select, output logic q);
	always_comb
		q = select[1] ? (select[0] ? i3 : i2) : (select[0] ? i1 : i0);
endmodule

//Register file with hardwired ZERO register (R0), R1-R15 are general purpose 
//Input: clk, reset, portasel, portbsel, writesel, writeenable, writeinput[31:0]
//Output: a, b 
module regfile (input logic clk, input logic reset, input wire[3:0] portasel, input wire[3:0] portbsel, input wire[3:0] writesel, input wire we, input wire[31:0] writeinput, output logic[31:0] a, output logic[31:0] b);

logic[31:0] registers[15:0];

	always_ff @(negedge clk)
		begin
			if (reset)
				registers <= '{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
			else if (we & (writesel != 0))
				registers[writesel[3:0]] <= writeinput;
		end
	always_comb
		begin
			a = registers[portasel];
			b = registers[portbsel];
		end
endmodule

//Custom ALU implementation
module alumod (input wire[2:0] s, input wire m, input wire[31:0] a, input wire[31:0] b, output logic[31:0] dout, output logic lt, output logic eq);
logic[31:0] tempsub;
	always_comb
		begin
			//Branching flags
			tempsub = a + ~b + 1;
			if (tempsub[31])
				lt = 1; //If less than
			else
				lt = 0;

			if (a == b)
				eq = 1; //If equal to
			else
				eq = 0;


			case (m)
				1'b0:
					case (s)
						//Arithmetic
						3'b000:	dout = a - b;
						3'b001:	dout = a + b;
						3'b010: dout = a;
						3'b011: dout = b;
						3'b100: dout = a + 4;
						3'b101: dout = b + 4;
						default:	dout = 0; 
					endcase
				1'b1:
					case (s)
						//Logic
						3'b000: dout = ~a;	
						3'b001:	dout = a & b;
						3'b010: dout = a | b;
						3'b011:	dout = a ^ b;
						3'b100:	dout = ~(a & b);
						3'b101:	dout = ~(a | b);
						3'b110:	dout = ~(a ^ b);
						3'b111:	dout = 0;
						default:	dout = 0; 
					endcase
			endcase
		end
endmodule

//Shifter unit
//Inputs: clk, reset, shifttype, shiftamt
//Outputs: stalldispatch, shiftdone, shiftout
module shifter_unit(input wire clk, input wire reset, input wire shiften, input wire[31:0] a, input wire[4:0] shiftamt, input logic shiftdir, input logic signextendsel, input logic rotate, output logic stalldispatchout, output logic shiftdone, output logic[31:0] shiftout);
localparam WAITING = 0;
localparam SHIFT1 = 1;
localparam SHIFT2 = 2;
localparam SHIFT4 = 3;
localparam SHIFT8 = 4;
localparam SHIFT16 = 5;

logic[2:0] shiftstate;
logic signextend, shift1sel, shift2sel, shift4sel, shift8sel, shift16sel, notfirstcycle;
logic[31:0] amuxout, shift1out, shift2out, shift4out, shift8out, shift16out, shift1unit, shift2unit, shift4unit, shift8unit, shift16unit;
logic rotate1, shift1rot;
logic[1:0] rotate2, shift2rot;
logic[3:0] rotate4, shift4rot;
logic[7:0] rotate8, shift8rot;
logic[15:0] rotate16, shift16rot;

always_ff @(posedge clk)
	begin
		if (reset)
			shiftstate <= WAITING;
		else if (shiften | shiftstate != WAITING)
			case (shiftstate)
				WAITING: if (shiftamt[4] == 'b1)
						shiftstate <= SHIFT16;
					else if (shiftamt[4:3] == 'b01)
						shiftstate <= SHIFT8;
					else if (shiftamt[4:2] == 'b001)
						shiftstate <= SHIFT4;
					else if (shiftamt[4:1] == 'b0001)
						shiftstate <= SHIFT2;
					else if (shiftamt[4:0] == 'b00001)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT16: if (shiftamt[3] == 'b1)
						shiftstate <= SHIFT8;
					else if (shiftamt[3:2] == 'b01)
						shiftstate <= SHIFT4;
					else if (shiftamt[3:1] == 'b001)
						shiftstate <= SHIFT2;
					else if (shiftamt[3:0] == 'b0001)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT8: if (shiftamt[2] == 'b1)
						shiftstate <= SHIFT4;
					else if (shiftamt[2:1] == 'b01)
						shiftstate <= SHIFT2;
					else if (shiftamt[2:0] == 'b001)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT4: if (shiftamt[1] == 'b1)
						shiftstate <= SHIFT2;
					else if (shiftamt[1] == 'b01)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT2: if (shiftamt[0] == 'b1)
						shiftstate <= SHIFT1;
					else
						shiftstate <= WAITING;
				SHIFT1: shiftstate <= WAITING;
			endcase

		shiftout <= shift1out | shift2out | shift4out  | shift8out | shift16out;

		if (shiftstate == SHIFT16 | shiftstate == SHIFT8 | shiftstate == SHIFT4 | shiftstate == SHIFT2 | shiftstate == SHIFT1 & ~notfirstcycle )
			notfirstcycle <= 1;
		else if (reset | shiftstate == WAITING)
			notfirstcycle <= 0;
	end

	always_comb
		begin
			if (shiftstate == SHIFT16 | shiftstate == SHIFT8 | shiftstate == SHIFT4 | shiftstate == SHIFT2 | shiftstate == SHIFT1 | ~notfirstcycle)
				stalldispatchout = 1;
			else
				stalldispatchout = 0;

			case (shiftstate)
				SHIFT16: begin
					shift16sel =  1'b1;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel =  1'b0;
				end
				SHIFT8: begin
					shift16sel =  1'b0;
					shift8sel =  1'b1;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel =  1'b0;
				end
				SHIFT4: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b1;
					shift2sel =  1'b0;
					shift1sel =  1'b0;
				end
				SHIFT2: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b1;
					shift1sel =  1'b0;
				end
				SHIFT1: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel = 1'b1;
				end
				default: begin
					shift16sel =  1'b0;
					shift8sel =  1'b0;
					shift4sel =  1'b0;
					shift2sel =  1'b0;
					shift1sel = 1'b0;
				end
			endcase
			amuxout = notfirstcycle ? shiftout : a;  

			signextend = signextendsel ? a[31] : 0;

			rotate1 = shiftdir ? amuxout[31] : amuxout[0];
			rotate2 = shiftdir ? amuxout[31:30] : amuxout[1:0];
			rotate4 = shiftdir ? amuxout[31:28] : amuxout[3:0];
			rotate8 = shiftdir ? amuxout[31:24] : amuxout[7:0];
			rotate16 = shiftdir ? amuxout[31:16] : amuxout[15:0];

			shift1rot = rotate ? rotate1 : signextend;
			shift2rot = rotate ? rotate2 : {2{signextend}};
			shift4rot = rotate ? rotate4 : {4{signextend}};
			shift8rot = rotate ? rotate8 : {8{signextend}};
			shift16rot = rotate ? rotate16 : {16{signextend}};
			
			shift1unit = shiftdir ? {shift1rot, amuxout[31:1]} : {amuxout[30:0], shift1rot}; //right : left
			shift2unit = shiftdir ? {shift2rot, amuxout[31:2]} : {amuxout[29:0], shift2rot};
			shift4unit = shiftdir ? {shift4rot, amuxout[31:4]} : {amuxout[27:0], shift4rot};
			shift8unit = shiftdir ? {shift8rot, amuxout[31:8]} : {amuxout[23:0], shift8rot};
			shift16unit = shiftdir ? {shift16rot, amuxout[31:16]} : {amuxout[15:0], shift16rot};

			shift1out = shift1sel ? shift1unit : 'h0; 
			shift2out = shift2sel ? shift2unit : 'h0;
			shift4out = shift4sel ? shift4unit : 'h0;
			shift8out = shift8sel ? shift8unit : 'h0;
			shift16out = shift16sel ? shift16unit : 'h0;
		end
endmodule

module multiplier_unit (input wire clk, input wire reset, input wire[31:0] a, input wire[31:0] b, input wire[1:0] muxas, input wire[1:0] muxbs, input wire[2:0] demuxs, input wire highlow, input wire accumulate, output logic[31:0] multout);
	
	logic[7:0] multina;
	logic[7:0] multinb;
	(* use_dsp = "yes" *) logic[15:0] multtempout;
	logic[63:0] demux;
	logic[63:0] productreg;
	logic carry;

	//8x8 multiplier input MUXes 
	always_comb
		begin
			//00 - 7:0
			//01 - 15:8
			//10 - 23:16
			//11 - 31:24
			multina = muxas[1] ? (muxas[0] ? a[31:24] : a[23:16]) : (muxas[0] ? a[15:8] : a[7:0]);   
			multinb = muxbs[1] ? (muxbs[0] ? b[31:24] : b[23:16]) : (muxbs[0] ? b[15:8] : b[7:0]); 
		end

	always_comb multtempout = multina * multinb;
	       
	//Demux multiplier to 64 bit register
	always_comb
		case (demuxs)
			3'b000: demux = {48'b0, multtempout};
			3'b001: demux = {40'b0, multtempout, 8'b0};
			3'b010: demux = {32'b0,multtempout, 16'b0};
			3'b011: demux = {24'b0,multtempout, 24'b0};
			3'b100: demux = {16'b0,multtempout, 32'b0};
			3'b101: demux = {8'b0, multtempout, 40'b0};
			3'b110: demux = {multtempout,48'b0};
			default: demux = 0;
		endcase
	
	//Accumulate
	always_ff @(negedge clk)
		begin
			if (accumulate)
				productreg <= productreg + demux;
			if (reset)
				productreg <= 0;
		end
	always_comb multout = highlow ? productreg[63:32] : productreg[31:0];
endmodule


//Bus unit
//Inputs: clk, reset, qfull, memreq, memreqdir, memaddr, programcounter
//Outputs: validaddr, validdata, read, write, incprefetch, toprefetch, memwait, incpc
//Inout: adbus, memdata
module busunit(input logic clk, input logic reset, input logic instreq, input logic memreq, input logic memreqdir, input logic[31:0] memaddr, input logic[31:0] programcounter, input logic[1:0] buswidth, input logic readwait,
                output logic[31:0] toprefetch, output logic prefetchwait, output logic memwait, output logic incpc, output logic memfinished, output logic[31:0] pcchain,
                output logic[31:0] memdatai, input logic[31:0] memdatao,
                output logic[31:0] membuso, input logic[31:0] membusi,
                output logic[31:0] writeaddr, readaddr,
                output logic datareq, output logic datasend, output logic[1:0] membuswidth, output logic[1:0] readmembuswidth);
                
                localparam TRANSMIT_WAIT = 0;
                localparam TRANSMIT = 1;
                localparam TRANSMIT_DONE = 2;
                
                localparam RECIEVE_IDLE = 0;
                localparam RECIEVE_DATA = 1;
                localparam RECIEVE_INST = 2;
                localparam RECIEVE_DATA_DONE = 3;
                
                logic[1:0] txstate, rxstate;
                
                always_ff @(posedge clk)
                    if (reset)
                        begin
                            txstate <= TRANSMIT_WAIT;
                            rxstate <= RECIEVE_IDLE;
                            memdatai <= 0;
                        end
                    else
                        begin
                        case (txstate)
                            TRANSMIT_WAIT: if (memreq & memreqdir)
                                                txstate <= TRANSMIT;
                            TRANSMIT: txstate <= TRANSMIT_DONE;
                            TRANSMIT_DONE: txstate <= TRANSMIT_WAIT;
                        endcase
                        
                        case (rxstate)
                            RECIEVE_IDLE: if (memreq & ~memreqdir)
                                                rxstate <= RECIEVE_DATA;
                                          else if (instreq)
                                                rxstate <= RECIEVE_INST;
                            RECIEVE_DATA: begin
                                            if (~readwait)
                                                begin
                                                    memdatai <= membusi;
                                                    rxstate <= RECIEVE_DATA_DONE;
                                                end
                                         end
                            RECIEVE_INST: begin
                                             if (memreq & ~memreqdir)
                                                rxstate <= RECIEVE_DATA;
                                             else if (instreq)
                                                rxstate <= RECIEVE_INST;
                                             else
                                                rxstate <= RECIEVE_IDLE;
                                          end
                                                
                            RECIEVE_DATA_DONE: if (memreq & ~memreqdir)
                                                rxstate <= RECIEVE_DATA;
                                          else if (instreq)
                                                rxstate <= RECIEVE_INST;
                                          else
                                                rxstate <= RECIEVE_IDLE;
                                                
                        endcase
                    end
                
                always_comb
                    begin
                        case (txstate)
                            TRANSMIT_WAIT: begin
                                            membuso = 0;
                                            datasend = 0;
                                            membuswidth = 0;
                                            writeaddr = 0;
                                           end
                            TRANSMIT: begin
                                        membuso = memdatao;
                                        datasend = 1;
                                        membuswidth = buswidth;
                                        writeaddr = memaddr;
                                      end
                            TRANSMIT_DONE: begin
                                            membuso = 0;
                                            datasend = 0;
                                            membuswidth = 0;
                                            writeaddr = 0;
                                           end
                            default: begin
                                        membuso = 0;
                                        datasend = 0;
                                        membuswidth = 0;
                                        writeaddr = 0;
                                     end
                        endcase
                        
                        case (rxstate)
                            RECIEVE_IDLE: begin
                                            toprefetch = membusi;
                                            incpc = 0;
                                            datareq = 0;
                                            readmembuswidth = 0;
                                            readaddr = 0;
                                            pcchain = 0;
                                          end
                            RECIEVE_DATA: begin
                                            toprefetch = 0;
                                            incpc = 0;
                                            datareq = 1;
                                            readmembuswidth = buswidth;
                                            readaddr = memaddr;
                                            pcchain = 0;
                                          end
                            RECIEVE_INST: begin
                                            toprefetch = membusi;
                                            incpc = instreq;
                                            datareq = 1;
                                            readmembuswidth = 2;
                                            readaddr = programcounter;
                                            pcchain = programcounter;
                                          end
                            RECIEVE_DATA_DONE: begin
                                            toprefetch = 0;
                                            incpc = 0;
                                            datareq = 0;
                                            readmembuswidth = buswidth;
                                            readaddr = memaddr;
                                            pcchain = 0;
                                          end
                        endcase
                        
                        if (memreq | txstate != TRANSMIT_WAIT | (rxstate != RECIEVE_IDLE & rxstate != RECIEVE_INST & readwait == 1))
                            memwait = 1;
                        else
                            memwait = 0;
                            
                        if (txstate == TRANSMIT | rxstate == RECIEVE_DATA_DONE )
                            memfinished = 1;
                        else
                            memfinished = 0;
                            
                        if (instreq  & (rxstate != RECIEVE_INST & rxstate != RECIEVE_IDLE) & readwait == 1)
                            prefetchwait = 1;
                        else
                            prefetchwait = 0; 
                    end
                
endmodule

//Prefetch unit
//Inputs: clk, reset, instreq, instadd, insttoadd
//Outputs: qfull, tofetch
module prefetcher(input logic clk, input logic reset, input logic prefetchwait, input logic instreq, input logic[31:0] insttoadd, input logic[31:0] pcchain,
                output logic stallpipe, output logic addinst, output logic[31:0] tofetch, output logic[31:0] programcounterinst);
localparam IDLE = 0;
localparam FETCHDISPATCH = 1;
localparam FETCHQUEUE = 2;
localparam DISPATCH = 3;
logic[1:0] prefetchstate, laststate;
logic qfull;
logic[2:0] qstatus, nextq;
logic[2:0] qpos[6];
logic[31:0] queue[6];
logic[31:0] qpc[6];

	always_ff @(posedge clk)
	   begin
	       if (reset)
	           begin
	               prefetchstate <= IDLE;
	               qpos <= '{3'b111, 3'b111, 3'b111, 3'b111, 3'b111, 3'b111};
	               queue <= '{32'b0, 32'b0, 32'b0, 32'b0, 32'b0, 32'b0};
	               qpc <= '{32'b0, 32'b0, 32'b0, 32'b0, 32'b0, 32'b0};
	               qstatus <= 0;
	               tofetch <= 0;
	           end
	       else
	           begin
	               if (~prefetchwait)
	                   begin
	                       qstatus <= nextq;
                           case (prefetchstate)
                               IDLE: if (~qfull & ~instreq)
                                       prefetchstate <= FETCHQUEUE;
                                     else if (~qfull & instreq)
                                       prefetchstate <= FETCHDISPATCH;
                                     else if (qfull & ~instreq)
                                       prefetchstate <= IDLE;
                                     else if (qfull & instreq)
                                       prefetchstate <= DISPATCH;
                               FETCHDISPATCH: if (~qfull & ~instreq)
                                       prefetchstate <= FETCHQUEUE;
                                     else if (~qfull & instreq)
                                       prefetchstate <= FETCHDISPATCH;
                                     else if (qfull & ~instreq)
                                       prefetchstate <= IDLE;
                                     else if (qfull & instreq)
                                       prefetchstate <= DISPATCH;
                               FETCHQUEUE: if (~qfull & ~instreq)
                                       prefetchstate <= FETCHQUEUE;
                                     else if (~qfull & instreq)
                                       prefetchstate <= FETCHDISPATCH;
                                     else if (qfull & ~instreq)
                                       prefetchstate <= IDLE;
                                     else if (qfull & instreq)
                                       prefetchstate <= DISPATCH;
                               DISPATCH: if (~qfull & ~instreq)
                                       prefetchstate <= FETCHQUEUE;
                                     else if (~qfull & instreq)
                                       prefetchstate <= FETCHDISPATCH;
                                     else if (qfull & ~instreq)
                                       prefetchstate <= IDLE;
                                     else if (qfull & instreq)
                                       prefetchstate <= DISPATCH;
                                endcase
                                    
                                    if (instreq)
                                   if (qpos[0] == 0)
                                       begin
                                           qpos[0] <= 7;
                                           programcounterinst <= qpc[0];
                                           qpc[0] <= 0;
                                           tofetch <= queue[0];
                                           
                                           if (qpos[1] != 0 & qpos[1] != 7)
                                               qpos[1] <= qpos[1] - 1;
                                           if (qpos[2] != 0 & qpos[2] != 7)
                                               qpos[2] <= qpos[2] - 1;
                                           if (qpos[3] != 0 & qpos[3] != 7)
                                               qpos[3] <= qpos[3] - 1;
                                           if (qpos[4] != 0 & qpos[4] != 7)
                                               qpos[4] <= qpos[4] - 1;
                                           if (qpos[5] != 0 & qpos[5] != 7)
                                               qpos[5] <= qpos[5] - 1;
                                       end
                                   else if (qpos[1] == 0)
                                       begin
                                           qpos[1] <= 7;
                                           programcounterinst <= qpc[1];
                                           qpc[1] <= 0;
                                           tofetch <= queue[1];
                                           
                                           if (qpos[0] != 0 & qpos[0] != 7)
                                               qpos[0] <= qpos[0] - 1;
                                           if (qpos[2] != 0 & qpos[2] != 7)
                                               qpos[2] <= qpos[2] - 1;
                                           if (qpos[3] != 0 & qpos[3] != 7)
                                               qpos[3] <= qpos[3] - 1;
                                           if (qpos[4] != 0 & qpos[4] != 7)
                                               qpos[4] <= qpos[4] - 1;
                                           if (qpos[5] != 0 & qpos[5] != 7)
                                               qpos[5] <= qpos[5] - 1; 
                                       end
                                   else if (qpos[2] == 0)
                                       begin
                                           qpos[2] <= 7;
                                           programcounterinst <= qpc[2];
                                           qpc[2] <= 0;
                                           tofetch <= queue[2];
                                           
                                           if (qpos[0] != 0 & qpos[0] != 7)
                                               qpos[0] <= qpos[0] - 1;
                                           if (qpos[1] != 0 & qpos[1] != 7)
                                               qpos[1] <= qpos[1] - 1;
                                           if (qpos[3] != 0 & qpos[3] != 7)
                                               qpos[3] <= qpos[3] - 1;
                                           if (qpos[4] != 0 & qpos[4] != 7)
                                               qpos[4] <= qpos[4] - 1;
                                           if (qpos[5] != 0 & qpos[5] != 7)
                                               qpos[5] <= qpos[5] - 1;
                                       end
                                   else if (qpos[3] == 0)
                                       begin
                                           qpos[3] <= 7;
                                           programcounterinst <= qpc[3];
                                           qpc[3] <= 0;
                                           tofetch <= queue[3];
                                           
                                           if (qpos[0] != 0 & qpos[0] != 7)
                                               qpos[0] <= qpos[0] - 1;
                                           if (qpos[1] != 0 & qpos[1] != 7)
                                               qpos[1] <= qpos[1] - 1;
                                           if (qpos[2] != 0 & qpos[2] != 7)
                                               qpos[2] <= qpos[2] - 1;
                                           if (qpos[4] != 0 & qpos[4] != 7)
                                               qpos[4] <= qpos[4] - 1;
                                           if (qpos[5] != 0 & qpos[5] != 7)
                                               qpos[5] <= qpos[5] - 1;
                                       end
                                   else if (qpos[4] == 0)
                                       begin
                                           qpos[4] <= 7;
                                           programcounterinst <= qpc[4];
                                           qpc[4] <= 0;
                                           tofetch <= queue[4];
                                           
                                           if (qpos[0] != 0 & qpos[0] != 7)
                                               qpos[0] <= qpos[0] - 1;
                                           if (qpos[1] != 0 & qpos[1] != 7)
                                               qpos[1] <= qpos[1] - 1;
                                           if (qpos[2] != 0 & qpos[2] != 7)
                                               qpos[2] <= qpos[2] - 1;
                                           if (qpos[3] != 0 & qpos[3] != 7)
                                               qpos[3] <= qpos[3] - 1;
                                           if (qpos[5] != 0 & qpos[5] != 7)
                                               qpos[5] <= qpos[5] - 1;
                                       end
                                   else if (qpos[5] == 0)
                                       begin
                                           qpos[5] <= 7;
                                           programcounterinst <= qpc[5];
                                           qpc[5] <= 0;
                                           tofetch <= queue[5];
                                           
                                           if (qpos[0] != 0 & qpos[0] != 7)
                                               qpos[0] <= qpos[0] - 1;
                                           if (qpos[1] != 0 & qpos[1] != 7)
                                               qpos[1] <= qpos[1] - 1;
                                           if (qpos[2] != 0 & qpos[2] != 7)
                                               qpos[2] <= qpos[2] - 1;
                                           if (qpos[3] != 0 & qpos[3] != 7)
                                               qpos[3] <= qpos[3] - 1;
                                           if (qpos[4] != 0 & qpos[4] != 7)
                                               qpos[4] <= qpos[4] - 1;
                                       end
                                       
                                       if (addinst)
                           if (qpos[0] == 7)
                               begin
                                   queue[0] <= insttoadd;
                                   qpos[0] <= nextq;
                                   qpc[0] <= pcchain;
                               end
                           else if (qpos[1] == 7)
                               begin
                                   queue[1] <= insttoadd;
                                   qpos[1] <= nextq;
                                   qpc[1] <= pcchain;
                               end
                           
                           else if (qpos[2] == 7)
                               begin
                                   queue[2] <= insttoadd;
                                   qpos[2] <= nextq;
                                   qpc[2] <= pcchain;
                               end
                           
                           else if (qpos[3] == 7)
                               begin
                                   queue[3] <= insttoadd;
                                   qpos[3] <= nextq;
                                   qpc[3] <= pcchain;
                               end
                           
                           else if (qpos[4] == 7)
                               begin
                                   queue[4] <= insttoadd;
                                   qpos[4] <= nextq;
                                   qpc[4] <= pcchain;
                               end
                           
                           else if (qpos[5] == 7)
                               begin
                                   queue[5] <= insttoadd;
                                   qpos[5] <= nextq;
                                   qpc[5] <= pcchain;
                               end
                       end
	           end
	   end
	   
	   always_comb
	       begin
	           if (qstatus >= 5)
	               qfull = 1;
	           else
	               qfull = 0;
	               
	           if (qpos[5] == 3'b111 & qpos[4] == 3'b111 & qpos[3] == 3'b111 & qpos[2] == 3'b111 & qpos[1] == 3'b111 & qpos[0] == 3'b111)
	               stallpipe = 1;
	           else
	               stallpipe = 0;
	               
	           if (~qfull & ~instreq)
	               begin
	                   if (qpos[5] == 3'b111 & qpos[4] == 3'b111 & qpos[3] == 3'b111 & qpos[2] == 3'b111 & qpos[1] == 3'b111 & qpos[0] == 3'b111)
	                       begin
	                           addinst = 1;
	                           nextq = qstatus;
	                       end
	                   else
	                       begin
	                           addinst = 1;
	                           nextq = qstatus + 1;
	                       end
                   end
               else if (~qfull & instreq)
                   begin
	                   nextq = qstatus;
	                   addinst = 1;
                   end
               else if (qfull & ~instreq)
                 begin
	                   nextq = qstatus;
	                   addinst = 0;
                   end
               else if (qfull & instreq)
                   begin
	                   nextq = qstatus - 1;
	                   addinst = 0;
                   end
              else
                begin
                    addinst = 0;
                    nextq = qstatus;
                end

	       end
	   
endmodule

//Fetch unit
//Inputs: clk, reset, ready, insin
//Outputs: insreq, insout
module fetcher(input logic clk, input logic reset, input logic ready, input logic[31:0] insin, output logic instreq, output logic[31:0] instout);
	logic fetchstate;
	localparam FSTALL = 1'b0;
	localparam FDECODE = 1'b1;

	always_ff @(posedge clk)
		begin
			if (reset)
				fetchstate <= FSTALL;
			case (fetchstate)
				FSTALL: if (~ready)
						fetchstate <= FSTALL;
					else
						fetchstate <= FDECODE;
				FDECODE:
					begin
						if (~ready)
							fetchstate <= FSTALL;
						else
							fetchstate <= FDECODE;
					end
			endcase			
		end
		
		always_ff @(posedge clk)
			if (fetchstate == FSTALL)
				begin
					instreq <= 0;
				end
			else
				begin
					instreq <= 1;
					instout <= insin;
				end
endmodule


//Microcode
//Inputs: Pointer
//Outputs: Microcode
module microcode_rom(input logic[7:0] pointer, output logic[49:0] microcode_line);
    logic[49:0] microcode[114];
    assign microcode_line = microcode[pointer];
    initial begin
        $readmemh("microcode.hex", microcode);
    end
endmodule

//Decoder
//Inputs: instruction
//Outputs: immediate[15:0], opcode_pointer[6:0]
module ma10k_frontend(input logic[31:0] instruction, output logic[15:0] immediate, output logic[6:0] opcode_pointer);
	
	always_comb
		begin
			if (instruction[18:16] == 'b010)
				immediate = {instruction[31:20], instruction[11:8]};
			else
				immediate = {instruction[31:20], instruction[3:0]};
		end

	//ALU and shift
	localparam SUB = 8'h00;
	localparam ADD = 8'h01;
	localparam SHL = 8'h02;
	localparam SHR = 8'h03;
	localparam ASR = 8'h04;
	localparam ROTL = 8'h06;
	localparam ROTR = 8'h07;
	localparam NOT = 8'h08;
	localparam AND = 8'h09;
	localparam OR = 8'h0A;
	localparam XOR = 8'h0B;
	localparam NAND = 8'h0C;
	localparam NOR = 8'h0D;
	localparam XNOR = 8'h0E;
	localparam SUP = 8'h0F;
	
	//Immediate math
	localparam SUBI = 8'h80;
	localparam ADDI = 8'h81;

	//Multiplication
	localparam MULTQW = 8'h10;
	localparam MULTHW = 8'h11;
	localparam MULTW = 8'h12;
	localparam MULTR = 8'h13;
	localparam RHMULT = 8'h14;
	//Branch and jump
	localparam BREQ = 8'h20;
	localparam BRNEQ = 8'h21;
	localparam BRLT = 8'h22;
	localparam BRLTEQ = 8'h23;
	localparam JUMPREL = 8'h24;
	localparam JUMPR = 8'h26;
	localparam JUMPI = 8'h27;
	localparam CALL = 8'h28;
	localparam RET = 8'h29;
	localparam RETI = 8'h2A;

	//Load/store/stack
	localparam LRR = 8'h30;
	localparam LRI = 8'h31;
	localparam LSPR = 8'h32;
	localparam LUI = 8'h33;
	localparam LLI = 8'h34;
	localparam SSPR = 8'h35;
	localparam STR = 8'h36;
	localparam STI = 8'h37;
	localparam LREL = 8'h38;
	localparam SREL = 8'h39;
	localparam PUSH = 8'h3A;
	localparam POP = 8'h3B;
	localparam STQW = 8'h3C;
	localparam LDQW = 8'h3D;
	localparam STHW = 8'h3E;
	localparam LDHW = 8'h3F;

	//Supervisor instructions
	localparam PRG = 8'h70;
	localparam LPSP = 8'h71;
	localparam RESPSP = 'h72;
	localparam SPSP = 8'h73;
	localparam GPSP = 8'h74;
	localparam SCOP = 8'h75;
	localparam GCOP = 8'h76;
	localparam EI = 8'h77;
	localparam DI = 8'h78;
	localparam GPTIMER = 8'h79;
	localparam RESET = 8'h7A;
	
	always_comb
		case (instruction[19:12])
			SUB: opcode_pointer = 1;
			ADD: opcode_pointer = 2;
			SHL: opcode_pointer = 3;
			SHR: opcode_pointer = 4;
			ASR: opcode_pointer = 5;
			ROTL: opcode_pointer  = 6;
			ROTR: opcode_pointer = 7;
			NOT: opcode_pointer = 8;
			AND: opcode_pointer = 9;
			OR: opcode_pointer = 10;
			XOR: opcode_pointer = 11;
			NAND: opcode_pointer = 12;
			NOR: opcode_pointer = 13;
			XNOR: opcode_pointer = 14;
			SUP: opcode_pointer = 15;
			SUBI: opcode_pointer = 18;
			ADDI: opcode_pointer = 19;
			MULTQW: opcode_pointer = 20;
			MULTHW: opcode_pointer = 22;
			MULTW: opcode_pointer = 27;
			MULTR: opcode_pointer = 44;
			RHMULT: opcode_pointer = 45;
			BREQ: opcode_pointer = 46;
			BRNEQ: opcode_pointer = 49;
			BRLT: opcode_pointer = 52;
			BRLTEQ: opcode_pointer = 55;
			JUMPREL: opcode_pointer = 58;
			JUMPR: opcode_pointer = 59;
			JUMPI: opcode_pointer = 60;
			CALL: opcode_pointer = 62;
			RET: opcode_pointer = 64;
			LRR: opcode_pointer = 67;
			LRI: opcode_pointer = 68;
			LSPR: opcode_pointer = 70;
			LUI: opcode_pointer = 71;
			LLI: opcode_pointer = 72;
			SSPR: opcode_pointer = 73;
			STR: opcode_pointer = 74;
			STI: opcode_pointer = 75;
			LREL: opcode_pointer = 77;
			SREL: opcode_pointer = 78;
			PUSH: opcode_pointer = 79;
			POP: opcode_pointer = 82;
			STQW: opcode_pointer = 85;
			LDQW: opcode_pointer = 86;
			STHW: opcode_pointer = 87;
			LDHW: opcode_pointer = 88;
			PRG: opcode_pointer = 89;
			RESPSP: opcode_pointer = 92;
			SPSP:	opcode_pointer = 93;
			GPSP:	opcode_pointer = 94;
			SCOP: opcode_pointer = 95;
			GCOP: opcode_pointer = 96;
			EI: opcode_pointer = 97;
			DI: opcode_pointer = 98;
			GPTIMER: opcode_pointer = 99;
			RESET: opcode_pointer = 100;
			RETI: opcode_pointer = 108;
			default: opcode_pointer = 0;
		endcase
endmodule

//Pipeline break
//Inputs: clk, reset, stall, icode[18], a, b, regtowrite
//Outputs: icodefunc, afunc, bfunc, regtowritefunc
module pipebreak(input logic clk, input logic reset, input logic stall, input logic[6:0] icode_pointer, input logic[31:0] a, input logic[31:0] b, input logic[3:0] regtowrite, input logic[31:0] programcounterinst, input logic[2:0] intin, input logic nonmi, output logic[6:0] icode_pointero, output logic[31:0] afunc, output logic[31:0] bfunc, output logic[3:0] regtowritefunc, output logic[31:0] programcountero, output logic[2:0] intout, output logic nmiout);
	always_ff @(posedge clk)
		begin
			if (reset)
				{afunc, bfunc, regtowritefunc, programcountero, intout, nmiout, icode_pointero} <= {32'b0,32'b0,4'b0, 32'b0, 3'b0, 1'b0, 7'b0};
			else
				if (~stall)
					begin
						{afunc, bfunc, regtowritefunc, programcountero, intout, nmiout} <= {a, b, regtowrite, programcounterinst, intin, nonmi};
						icode_pointero <= icode_pointer;
					end
		end
endmodule

//Execution unit
//Inputs: clk, reset, funcsel, ina, inb, pointer[6:0]
//Outputs: execout, stalldispatch, lt, eq, executec, fucode
module execute_unit(input logic clk, input logic reset, input logic newmicrocode, input logic[1:0] funcsel, input logic[31:0] ina, input logic[31:0] inb, input logic[6:0] pointer, input logic memaccess,
							output logic[31:0] execout, output logic stalldispatch, output logic lt, output logic eq, output logic[4:0] executec, output logic[49:0] fucode);
	logic[49:0] microcode_line;
	logic[31:0] aluout, shiftout, multout;
	logic shiftdone, shiften, alufunctype, highlow, accumulate, shiftstalldispatch, multreset, shiftdir, rotate, signextend;
	logic[1:0] multmuxas, multmuxbs;
	logic[2:0] alufunc,multdemuxs;
	logic[7:0] linenumber;

	microcode_rom microcode(linenumber, microcode_line);
	
	always_comb fucode = microcode_line;
	always_comb linenumber = pointer + {3'b0, executec};
		
	always_ff @(posedge clk)// or posedge reset)// or posedge newmicrocode)
		begin
			if(reset | microcode_line[32])// | newmicrocode | microcode_line[1])
					executec <= 0;
			else if (~memaccess)
				executec <= executec + 1'b1;
		end

	always_comb
		case (funcsel)
			2'b00: begin
				execout = aluout;
				multmuxas = 0;
				multmuxbs = 0;
				multdemuxs = 0;
				accumulate = 0;
				stalldispatch = ~microcode_line[32];
				shiften = 0;
				alufunc = microcode_line[20:18];
				alufunctype = microcode_line[21];
				multreset = 0;
				shiftdir = 0;
				signextend = 0;
				rotate = 0;
				highlow = 0;
			end
			2'b01: begin
				execout = multout;
				multmuxas = microcode_line[23:22];
				multmuxbs = microcode_line[25:24];
				multdemuxs = microcode_line[28:26];
				accumulate = microcode_line[29];
				stalldispatch = ~microcode_line[32];
				shiften = 0;
				alufunc = 0;
				alufunctype = 0;
				multreset = reset | microcode_line[31];
				shiftdir = 0;
				signextend = 0;
				rotate = 0;
				highlow = microcode_line[30];
			end
			2'b10: begin
				case (pointer)
					3: begin //SHL
						shiftdir = 0;
						signextend = 0;
						rotate = 0;
					end
					4: begin //SHR
						shiftdir = 1;
						signextend = 0;
						rotate = 0;
					end
					5: begin //ASR
						shiftdir = 1;
						signextend = 0;
						rotate = 0;
					end
					6: begin //ROTL
						shiftdir = 0;
						signextend = 0;
						rotate = 1;
					end
					7: begin //ROTR
						shiftdir = 1;
						signextend = 0;
						rotate = 1;
					end
					default: begin
						shiftdir = 0;
						signextend = 0;
						rotate = 0;
					end
				endcase

				execout = shiftout;
				multmuxas = 0;
				multmuxbs = 0;
				multdemuxs = 0;
				accumulate = 0;
				stalldispatch = shiftstalldispatch;
				shiften = 1;
				alufunc = 0;
				alufunctype = 0;
				multreset = 0;
				highlow = 0;
			end
			default: begin
				execout = 0;
				multmuxas = 0;
				multmuxbs = 0;
				multdemuxs = 0;
				accumulate = 0;
				stalldispatch = 0;
				shiften = 0;
				alufunc = 0;
				alufunctype = 0;
				multreset = 0;
				shiftdir = 0;
				signextend = 0;
				rotate = 0;
				highlow = 0;
				end
		endcase

	alumod alu(alufunc, alufunctype, ina, inb, aluout, lt, eq);
	multiplier_unit mult(clk, multreset, ina, inb, multmuxas, multmuxbs, multdemuxs, highlow, accumulate, multout);
	shifter_unit shifter(clk, reset, shiften, ina, inb[4:0],  shiftdir, signextend, rotate, shiftstalldispatch, shiftdone, shiftout);
endmodule

//Memory access unit
//Inputs: clk, reset, fromexecute, portb, addrsel, datasel, requestdbus, dbusreqdir, buswait
//Outputs: dbusreq, dbusdir, addr, towriteback, stalldispatch 
//Inout: data
module mem_access_unit(input logic[31:0] fromexecute, input logic[31:0] portb, input logic addrsel, input logic datasel, input logic requestdbus, input logic dbusreqdir, input logic buswait, input logic memfinished, output logic dbusreq, output logic dbusdir, output logic[31:0] addr, output logic[31:0] towriteback, output logic stalldispatch, input logic[31:0] datai, output logic[31:0] datao);
	/* verilator lint_off ALWCOMBORDER */
	
	logic[31:0] currentdata;
	always_comb
		begin
			if (memfinished)
				dbusreq = 0;
			else
				dbusreq = requestdbus;

			//dbusreq = memfinished ? 1'h0 : requestdbus;
			dbusdir = dbusreqdir;
			addr = addrsel ? portb : fromexecute;
			datao = datasel ? portb : fromexecute; //datasel ? portb : fromexecute;
			towriteback = datai;
			if (~memfinished & requestdbus)
				stalldispatch = 1;
			else
				stalldispatch = 0;
		end
	/* verilator lint_on ALWCOMBORDER */
endmodule

module interruptprivilage(input logic[7:0] currentfunc, input logic[2:0] intin, input logic nonmi, input logic mode, input logic inten,
			output logic injectinst, output logic[6:0] injectpointer);

	localparam SUP = 8'h0F;


	localparam PRG = 8'h70;
	localparam LPSP = 8'h71;
	localparam RESPSP = 'h72;
	localparam SPSP = 8'h73;
	localparam GPSP = 8'h74;
	localparam SCOP = 8'h75;
	localparam GCOP = 8'h76;
	localparam EI = 8'h77;
	localparam DI = 8'h78;
	localparam GPTIMER = 8'h79;
	localparam RESET = 8'h7A;

	always_comb
		begin
			if (mode & currentfunc <= RESET & currentfunc >= PRG) //Program mode
				begin
					injectinst = 1;
					injectpointer = 110;
				end
			else if (~mode & currentfunc <= RESET & currentfunc >= PRG) //Supervisor mode
				begin
					injectinst = 0;
					injectpointer = 0;
				end
			else if (inten & |intin[2:0])
				begin
					injectinst = 1;
					injectpointer = 100; 
				end
			else if (nonmi)
				begin
					injectinst = 1;
					injectpointer = 103;
				end
			else
				begin
					injectinst = 0;
					injectpointer = 0;
				end
		end
endmodule


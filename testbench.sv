`include "modules.sv"

module testbench();
	logic[31:0] a,b,c,d,y,y2, execout, writeinput, aout, bout, aluout;
	logic[1:0] s2, funcsel;
	logic s, clk, reset, we, lt, eq, m, stalldispatch, elt, eeq, newmicrocode;
	logic[5:0] testcount, testfail;
	logic[6:0] pointer;
	logic[4:0] executec;
	logic[39:0] fucode;
	logic[2:0] s3;
	ttb2inmux twoinmux(a,b,s,y);
	ttb4inmux fourinmux(a,b,c,d,s2,y2);
	alumod alu(s3, m, a, b, aluout, lt, eq);
	regfile registers(clk, reset, portasel, portbsel, writesel, we, writeinput, aout, bout); 
	execute_unit execution(clk, reset, newmicrocode, funcsel, a, b, pointer,
				execout, stalldispatch, elt, eeq, executec, fucode);
	logic[3:0] portasel, portbsel, writesel;
	always begin
		#125 clk = ~clk;
	end

	initial begin
	$dumpfile("tracefile");
	$dumpvars();
	testcount = 0;
	testfail = 0;
	reset = 1; #10;
	reset = 0; #10;
	{a,b,c,d} = {32'd1,32'd2,32'd3,32'd4};	
	#10;
	#10 s = 0; #10;
	if (y == 1)
		testcount += 1;
	else
		testfail += 1;
	#10 s = 1; #10;
	if (y == 2)
		testcount += 1;
	else
		testfail += 1;

	#10 s2 = 0; #10;
	if (y2 == 1)
		testcount += 1;
	else
		testfail += 1;
	
	#10 s2 = 1; #10;
	if (y2 == 2)
		testcount += 1;
	else
		testfail += 1;
	#10 s2 = 2; #10;
	if (y2 == 3)
		testcount += 1;
	else
		testfail += 1;
	#10 s2 = 3; #10;
	
	if (y2 == 4)
		testcount += 1;
	else
		testfail += 1;
	$display("%d tests. %d tests passed. %d tests failed. (Mux tests)\n", testcount + testfail, testcount, testfail);
	testcount = 0;
	testfail = 0;
	writeinput = 1;
	portasel = 0;
	portbsel = 1;
	writesel = 0;
	we = 0;
	#10;
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
	
	portasel = 2;
	portbsel = 3;
	#10;
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
	
	portasel = 4;
	portbsel = 5;
	#10;
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
	
	portasel = 6;
	portbsel = 7;
	#10
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
	
	portasel = 7;
	portbsel = 8;
	#10
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
	
	portasel = 9;
	portbsel = 10;
	#10
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
	
	portasel = 11;
	portbsel = 12;
	#10
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
	
	portasel = 13;
	portbsel = 14;
	#10
	if (aout == 0 & bout == 0)
		testcount += 1;
	else
		testfail += 1;
		
	portasel = 0;
	we = 1;
	writeinput = 1;
	writesel = 0;
	#250;
	if (aout == 0)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	portasel = 1;
	we = 1;
	writeinput = 1;
	writesel = 1;
	#250;
	if (aout == 1)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 2;
	we = 1;
	writeinput = 2;
	writesel = 2;
	#250;
	if (aout == 2)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 3;
	we = 1;
	writeinput = 3;
	writesel = 3;
	#250;
	if (aout == 3)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 4;
	we = 1;
	writeinput = 4;
	writesel = 4;
	#250;
	if (aout == 4)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 5;
	we = 1;
	writeinput = 5;
	writesel = 5;
	#250;
	if (aout == 5)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 6;
	we = 1;
	writeinput = 6;
	writesel = 6;
	#250;
	if (aout == 6)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 7;
	we = 1;
	writeinput = 7;
	writesel = 7;
	#250;
	if (aout == 7)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 8;
	we = 1;
	writeinput = 8;
	writesel = 8;
	#250;
	if (aout == 8)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 9;
	we = 1;
	writeinput = 9;
	writesel = 9;
	#250;
	if (aout == 9)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 10;
	we = 1;
	writeinput = 10;
	writesel = 10;
	#250;
	if (aout == 10)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 11;
	we = 1;
	writeinput = 11;
	writesel = 11;
	#250;
	if (aout == 11)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 12;
	we = 1;
	writeinput = 12;
	writesel = 12;
	#250;
	if (aout == 12)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 13;
	we = 1;
	writeinput = 13;
	writesel = 13;
	#250;
	if (aout == 13)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	testcount = 0;
	
	portasel = 14;
	we = 1;
	writeinput = 14;
	writesel = 14;
	#250;
	if (aout == 14)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	
	portasel = 15;
	we = 1;
	writeinput = 15;
	writesel = 15;
	#250;
	if (aout == 15)
		testcount += 1;
	else
		begin
		testfail += 1;
		$display("Failed: \nportasel = %d\nwe = %d\nwriteinput = %d\nwritesel = %d\n", portasel, we, writeinput, writesel);
		end
	$display("%d tests. %d tests passed. %d tests failed. (Register tests)\n", testcount + testfail, testcount, testfail);

	testcount = 0;
	testfail = 0;
	s3 = 0;
	m = 0;
	a = 20;
	b = 20;
	#250;
	if (eq)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 0;
	m = 0;
	a = 20;
	b = 30;
	#250;
	if (lt)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 0;
	m = 0;
	a = 30;
	b = 20;
	#250;
	if (aluout == 10)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 1;
	m = 0;
	a = 20;
	b = 30;
	#250;
	if (aluout == 50)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 2;
	m = 0;
	a = 20;
	b = 30;
	#250;
	if (aluout == a)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 3;
	m = 0;
	a = 20;
	b = 30;
	#250;
	if (aluout == b)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 0;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == ~a)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 1;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == (a & b))
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
		
	s3 = 2;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == (a | b))
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 3;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == (a ^ b))
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 4;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == ~(a & b))
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 5;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == ~(a | b))
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 6;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == ~(a ^ b))
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	s3 = 7;
	m = 1;
	a = 20;
	b = 30;
	#250;
	if (aluout == 0)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed:\ns = %d\nm = %d\na = %d\nb = %d\n", s, m, a, b);
		end
	
	$display("%d tests. %d tests passed. %d tests failed. (ALU tests)\n", testcount + testfail, testcount, testfail);
	testcount = 0;
	testfail = 0;
	
	pointer = 7'd44;
	newmicrocode = 1;
	a = 0;
	b = 0;
	#125 newmicrocode = 0;
	
	funcsel = 1;
	a = 211;
	b = 124;
	pointer = 7'd20;
	newmicrocode = 1;
	#125 newmicrocode = 0;
	#125;
	if (execout == a * b)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed 8 bit multiplication:\na = %d\nb = %d\nresult = %d\nfucode = %h\nexecutec = %d\n", a, b, execout, fucode, executec);
		end
	
	pointer = 7'd44;
	newmicrocode = 1;
	a = 0;
	b = 0;
	#125 newmicrocode = 0;
	#125;
		
	funcsel = 1;
	a = 1;
	b = 1;
	pointer = 7'd22;
	newmicrocode = 1;
	#125 newmicrocode = 0;
	#1000;
	if (execout == a * b)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed 16 bit multiplication:\na = %d\nb = %d\nresult = %d\nfucode = %h\nexecutec = %d\n", a, b, execout, fucode, executec);
		end
	
	pointer = 7'd44;
	newmicrocode = 1;
	a = 0;
	b = 0;
	#125 newmicrocode = 0;
	 
	funcsel = 1;
	a = 70000;
	b = 6000;
	pointer = 7'd27;
	newmicrocode = 1;
	#125 newmicrocode = 0;
	#4000
	if (execout == a * b)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed 32 bit multiplication:\na = %d\nb = %d\nresult = %d\nfucode = %h\nexecutec = %d\n", a, b, execout, fucode, executec);
		end

	$display("%d tests. %d tests passed. %d tests failed. (Multiplier tests)\n", testcount + testfail, testcount, testfail);
	
	testcount = 0;
	testfail = 0;
	funcsel = 2;
	a = 1241;
	b = 16;
	pointer = 7'd3;
	newmicrocode = 1;
	#125 newmicrocode = 0;
	#2500
	if (execout == 1241 << 16)
		testcount += 1;
	else
		begin
			testfail += 1;
			$display("Failed shift left test:\ninput = %d\nshift amount = %d\nstall dispatch = %b\nresult = %d\n", a, b, stalldispatch, execout);
		end
	
	$finish();
	end

endmodule

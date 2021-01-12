module onepulse(s_op, s, clk);
	input s, clk;
	output reg s_op;
	reg s_delay;
	always @(posedge clk) begin
		s_op <= s&(!s_delay);
		s_delay <= s;
	end
endmodule

module onepulse_lengthen(s_op, s, clk, vsync);
	input s, clk, vsync;
	output reg s_op;
    reg pre_s_op;
	reg s_delay;
	always @(posedge clk) begin
		pre_s_op <= s&(!s_delay);
		s_delay <= s;
	end
    always @(posedge clk) begin
        if(vsync)
            s_op <= 0;
        else if(pre_s_op)
            s_op <= 1;
        else 
            s_op <= s_op;
    end
endmodule

module debounce(s_db, s, clk);
	input s, clk;
	output s_db;
	reg [3:0] DFF;
	
	always @(posedge clk) begin
		DFF[3:1] <= DFF[2:0];
		DFF[0] <= s;
	end
	assign s_db = &DFF;
endmodule
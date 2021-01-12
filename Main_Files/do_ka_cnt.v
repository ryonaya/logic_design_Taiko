module do_ka_cnt(
    input clk,
    input rst,
    input vsync,
    output [1:0] request        // request 0 for do, 1 for ka
);

    // 10 = ka, 11 = do
    parameter [0:32-1] note_list = 32'b11100010_11111010_10101110_00001010;
    // parameter [0:32-1] note_list = 32'b11111111_11111111_11111111_11111111;

    /// Timer
    reg [5-1:0] counter;        // Count up every 2^n *(1/60) seconds, this signal last for a frame
    reg [4-1:0] note_index;
    wire note_delay;
    assign note_delay = &counter;   
    always @(posedge clk) begin         
        if(rst)         counter <= 0;
        else if(vsync)  counter <= counter + 1;
        else            counter <= counter;
    end
    always @(posedge clk) begin         
        if(rst)                         note_index <= 0;
        else if(vsync & note_delay)     note_index <= note_index + 2;
        else                            note_index <= note_index;
    end

    /// Output request
    reg do_rq, ka_rq;
    always @* begin
        case ({note_list[note_index], note_list[note_index+1]})
            2'b11   : begin
                do_rq = 1'b1;
                ka_rq = 1'b0;
            end
            2'b10   : begin
                do_rq = 1'b0;
                ka_rq = 1'b1;
            end
            default : begin
                do_rq = 1'b0;
                ka_rq = 1'b0;
            end
        endcase
    end

    onepulse op_do_note (.s_op(request[0]), .s( do_rq ), .clk(vsync));
    onepulse op_ka_note (.s_op(request[1]), .s( ka_rq ), .clk(vsync));
endmodule

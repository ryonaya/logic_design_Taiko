module top(
   input clk,
   input pre_rst,               // button D as reset button
   input pre_left,
   input pre_right,
   output [3:0] vgaRed,
   output [3:0] vgaGreen,
   output [3:0] vgaBlue,
   output hsync,
   output vsync
);

    /// <Basic Wires>
    /// 
    /// </Basic Wires>
    wire db_rst, rst;
    wire left, right;
    wire [12-1:0] data;
    wire [2-1:0] data_2b;
    wire [7-1:0] data_7b;
    wire clk_25MHz, op_clk_25MHz;
    wire [10-1:0] h_cnt;    //640
    wire [10-1:0] v_cnt;    //480
    wire valid;
    wire op_vsync;
    integer i;
    genvar  j;


    /// <Color Wires>
    /// 
    /// </Color Wires>
    wire [16-1:0] slide_pixel_addr;                         // 512*96
    wire [2-1:0]  pre_slide_pixel; 
    wire [12-1:0] pre_do_pixel_addr [0:8-1];
    wire [12-1:0] pre_ka_pixel_addr [0:8-1];
    wire [12-1:0] do_pixel_addr, ka_pixel_addr;             // 4096
    wire [14-1:0] good_efx_pixel_addr, ok_efx_pixel_addr;   // 96*96 = 9216
    wire [10-1:0] good_pixel_addr;                          // 60*32 = 1920, v2 = 32*32
    wire [10-1:0] ok_pixel_addr;                            // 60*32 = 1920
    wire [14-1:0] ui_pixel_addr;                            // 128*96= 12288
    wire [17-1:0] background_pixel_addr;                    // 76800
    wire [13-1:0] combo_pixel_addr;                         // 160*32
    wire [7-1:0]  pre_background_pixel; 

    wire [12-1:0] slide_pixel, good_efx_pixel, good_pixel, ok_efx_pixel, ok_pixel, 
                  do_pixel, ka_pixel,
                  ui_pixel, background_pixel, combo_pixel;
    reg  [12-1:0] color;

    wire ui;
    wire slide, good_efx, good, ok_efx, ok, combo;
    wire [ 8-1:0] pre_do, pre_ka;
    wire do, ka;


    /// <Note gen>
    /// 
    /// </Note gen>
    reg [8-1:0] do_cnt,             ka_cnt;
    reg [3-1:0] do_head, do_tail,   ka_head, ka_tail;
    reg [4-1:0] do_init,            ka_init;                // 0 means no init, 1~8 means init a note (0~7)
    wire[8-1:0] pre_do_expired,     pre_ka_expired;
    wire do_expired,                ka_expired;
    wire do_request,                ka_request;
    wire[8-1:0] pre_do_good_hit,    pre_ka_good_hit;
    wire do_good_hit,               ka_good_hit;
    wire[8-1:0] pre_do_ok_hit,      pre_ka_ok_hit;
    wire do_ok_hit,                 ka_ok_hit;
    wire pre_do_hit_1, pre_do_hit_2,pre_ka_hit_1, pre_ka_hit_2;
    wire do_hit_1, do_hit_2,        ka_hit_1, ka_hit_2;

    assign do_good_hit = |pre_do_good_hit;
    assign ka_good_hit = |pre_ka_good_hit;
    assign pre_do_hit_1 = (do_good_hit & left);
    assign pre_ka_hit_1 = (ka_good_hit & right);
    assign do_ok_hit = |pre_do_ok_hit;
    assign ka_ok_hit = |pre_ka_ok_hit;
    assign pre_do_hit_2 = (do_ok_hit & left);
    assign pre_ka_hit_2 = (ka_ok_hit & right);

    /// <Note gen>
    /// 
    /// </Note gen>
    reg [10-1:0] streak;
    always @(posedge clk) begin
        if(rst)             
            streak <= 4'd0;
        else if(op_vsync) begin
            if( (do_hit_1 | do_hit_2) |
                (ka_hit_1 | ka_hit_2) )
                streak <= streak + 4'b1;
            else if(do_expired | ka_expired)
                streak <= 4'b0;
            else 
                streak <= streak;
        end
        else                
            streak <= streak;
    end


    /// <Do Ka Gen>
    /// 
    /// </Do Ka Gen>
    onepulse_lengthen ople_do1 (.s_op(do_hit_1), .s(pre_do_hit_1), .clk(clk), .vsync(op_vsync)); 
    onepulse_lengthen ople_ka1 (.s_op(ka_hit_1), .s(pre_ka_hit_1), .clk(clk), .vsync(op_vsync)); 
    onepulse_lengthen ople_do2 (.s_op(do_hit_2), .s(pre_do_hit_2), .clk(clk), .vsync(op_vsync)); 
    onepulse_lengthen ople_ka2 (.s_op(ka_hit_2), .s(pre_ka_hit_2), .clk(clk), .vsync(op_vsync)); 
    do_ka_cnt               temp_do_note_gen(               // Output note every 2^n /60 seconds, according to my kimochi
        .clk(clk),
        .rst(rst),
        .vsync(op_vsync),
        .request({ka_request, do_request})
    );
    reg do_expired_flag, ka_expired_flag;   // Avoid double hit
    always @(posedge clk) begin         // Enable and disable do notes
        if(rst) begin
            do_cnt <= 8'b0;
            do_head<= 3'b0;
            do_tail<= 3'b0;
            do_expired_flag <= 0;
        end
        else if(op_vsync) begin
            if(do_request) begin
                do_cnt[do_head] <= 1'b1;
                do_head <= do_head + 1;
                do_expired_flag <= 0;
            end
            else if( (do_expired | do_hit_1 | do_hit_2) && (do_tail != do_head && !do_expired_flag) ) begin
                do_cnt[do_tail] <= 1'b0;
                do_tail <= do_tail + 1;
                do_expired_flag <= 1;
            end
            else begin
                do_cnt <= do_cnt;
                do_head<= do_head;
                do_tail<= do_tail;
                do_expired_flag <= 0;
            end
        end
        else begin
            do_cnt <= do_cnt;
            do_head<= do_head;
            do_tail<= do_tail;
            do_expired_flag <= do_expired_flag;
        end
    end
    always @(posedge clk) begin         // Enable and initiate do's pos
        if(rst)             do_init <= 4'd0;
        else if(op_vsync) begin
            if(do_request)  do_init <= {1'b0, do_head} + 4'b1;
            else            do_init <= 4'b0;
        end
        else                do_init <= do_init;
    end
    always @(posedge clk) begin         // Enable and disable ka notes
        if(rst) begin
            ka_cnt <= 8'b0;
            ka_head<= 3'b0;
            ka_tail<= 3'b0;
            ka_expired_flag <= 0;
        end
        else if(op_vsync) begin
            if(ka_request) begin
                ka_cnt[ka_head] <= 1'b1;
                ka_head <= ka_head + 1;
                ka_expired_flag <= 0;
            end
            else if( (ka_expired | ka_hit_1 | ka_hit_2) && (ka_tail != ka_head && !ka_expired_flag) ) begin
                ka_cnt[ka_tail] <= 1'b0;
                ka_tail <= ka_tail + 1;
                ka_expired_flag <= 1;
            end
            else begin
                ka_cnt <= ka_cnt;
                ka_head<= ka_head;
                ka_tail<= ka_tail;
                ka_expired_flag <= 0;
            end
        end
        else begin
            ka_cnt <= ka_cnt;
            ka_head<= ka_head;
            ka_tail<= ka_tail;
            ka_expired_flag <= ka_expired_flag;
        end
    end
    always @(posedge clk) begin         // Enable and initiate ka's pos
        if(rst)             ka_init <= 4'd0;
        else if(op_vsync) begin
            if(ka_request)  ka_init <= {1'b0, ka_head} + 4'b1;
            else            ka_init <= 4'b0;
        end
        else                ka_init <= ka_init;
    end

    assign do            = |pre_do;
    assign do_expired    = |pre_do_expired;
    assign do_pixel_addr = ( (pre_do_pixel_addr[0] | pre_do_pixel_addr[1]) | (pre_do_pixel_addr[2] | pre_do_pixel_addr[3]) ) |
                           ( (pre_do_pixel_addr[4] | pre_do_pixel_addr[5]) | (pre_do_pixel_addr[6] | pre_do_pixel_addr[7]) );
    assign ka            = |pre_ka;
    assign ka_expired    = |pre_ka_expired;
    assign ka_pixel_addr = ( (pre_ka_pixel_addr[0] | pre_ka_pixel_addr[1]) | (pre_ka_pixel_addr[2] | pre_ka_pixel_addr[3]) ) |
                           ( (pre_ka_pixel_addr[4] | pre_ka_pixel_addr[5]) | (pre_ka_pixel_addr[6] | pre_ka_pixel_addr[7]) );


    /// <Color>
    /// 
    /// </Color>
    assign {vgaRed, vgaGreen, vgaBlue} = color;
    always @* begin         // Layering
        if(valid) begin
            if     (combo && combo_pixel != 12'hfff)
                color = combo_pixel;
            else if(ui)
                color = ui_pixel;
            else if(do   && do_pixel != 12'hf6f)
                color = do_pixel;
            else if(ka   && ka_pixel != 12'hf6f)
                color = ka_pixel;
            else if(good && good_pixel != 12'hf6f) 
                color = good_pixel;
            else if(ok   && ok_pixel != 12'hf6f) 
                color = ok_pixel;
            else if(good_efx) 
                color = good_efx_pixel;
            else if(ok_efx) 
                color = ok_efx_pixel;
            else if(slide)
                color = slide_pixel;
            else
                color = background_pixel;
        end
        else begin
            color = 12'b0;
        end
    end


    /// <Basic Modules>
    /// 
    /// </Basic Modules>
    clock_divisor           clk_wiz_0_inst(
        .clk(clk),
        .clk1(clk_25MHz)
    );
    vga_controller          vga_inst(
        .pclk(clk_25MHz),
        .reset(rst),
        .hsync(hsync),
        .vsync(vsync),
        .valid(valid),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt)
    );


    /// <Slide>
    /// 
    /// </Slide>
    slide_mem_addr_gen      slide_mem_addr_gen_inst(
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .slide(slide),
        .slide_pixel_addr(slide_pixel_addr)
    );
    blk_mem_gen_0           slide_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(slide_pixel_addr),
        .dina(data_2b),
        .douta(pre_slide_pixel)
    );
    slide_pixel_decode      slide_decode(
        .pre_slide_pixel(pre_slide_pixel),
        .slide_pixel(slide_pixel)
    );


    /// <Background>
    /// 
    /// </Background>
    background_mem_addr_gen         background_mem_addr_gen_inst(
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .background_pixel_addr(background_pixel_addr)
    );
    blk_mem_gen_7                   background_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(background_pixel_addr),
        .dina(data_7b),
        .douta(pre_background_pixel)
    );
    background_pixel_decode         background_decode(
        .pre_background_pixel(pre_background_pixel),
        .background_pixel(background_pixel)
    );

    /// <UI>
    /// Numbers in combo (x1, y1) = (80->96->112, 145)
    /// When only two digit :       (88->104    , 145)
    /// </UI>
    ui_mem_addr_gen         ui_mem_addr_gen_inst(
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .ui(ui),
        .ui_pixel_addr(ui_pixel_addr)
    );
    blk_mem_gen_8           ui_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(ui_pixel_addr),
        .dina(data),
        .douta(ui_pixel)
    );
    combo_mem_addr_gen      combo_mem_addr_gen_inst(
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .streak(streak),

        .combo(combo),
        .combo_pixel_addr(combo_pixel_addr)
    );
    blk_mem_gen_9           combo_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(combo_pixel_addr),
        .dina(data),
        .douta(combo_pixel)
    );

    /// <Do>
    /// 
    /// </Do>
generate    
    for (j = 0; j < 8; j = j+1) begin
    do_mem_addr_gen #(.H_SIZE(32), .SPEED(2), .NUM(j)) do_mem_addr_gen_inst(
        .clk(clk), 
        .rst(rst),
        .vsync(op_vsync),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .do_cnt(do_cnt[j]),             // 0~7, total of 8 objects, 1 means on the track
        .been_hit(do_hit_1 | do_hit_2),
        .init(do_init),

        .expired(pre_do_expired[j]),
        .do(pre_do[j]),                 // x, y = slide x1 + 37, y1 + 12
        .good_hit(pre_do_good_hit[j]),
        .ok_hit(pre_do_ok_hit[j]),
        .do_pixel_addr(pre_do_pixel_addr[j])
    );
    end 
endgenerate
    blk_mem_gen_1           do_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(do_pixel_addr),
        .dina(data),
        .douta(do_pixel)
    );


    /// <Ka>
    /// 
    /// </Ka>
generate    
    for (j = 0; j < 8; j = j+1) begin
    do_mem_addr_gen #(.H_SIZE(32), .SPEED(2), .NUM(j)) ka_mem_addr_gen_inst(
        .clk(clk), 
        .rst(rst),
        .vsync(op_vsync),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .do_cnt(ka_cnt[j]),             // 0~7, total of 8 objects, 1 means on the track
        .been_hit(ka_hit_1 | ka_hit_2),
        .init(ka_init),

        .expired(pre_ka_expired[j]),
        .do(pre_ka[j]),                 // x, y = slide x1 + 37, y1 + 12
        .good_hit(pre_ka_good_hit[j]),
        .ok_hit(pre_ka_ok_hit[j]),
        .do_pixel_addr(pre_ka_pixel_addr[j])
    );
    end 
endgenerate
    blk_mem_gen_2           ka_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(ka_pixel_addr),
        .dina(data),
        .douta(ka_pixel)
    );
      

    /// <Good Effect>
    /// 
    /// </Good Effect>
    good_efx_mem_addr_gen   good_efx_mem_addr_gen_inst(
        .clk(clk),
        .clk_25MHz(op_clk_25MHz),
        .rst(rst),
        .vsync(op_vsync),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .request((do_hit_1 | ka_hit_1) & !(do_hit_2 | ka_hit_2)),

        .good_efx(good_efx),
        .good(good),
        .good_efx_pixel_addr(good_efx_pixel_addr),
        .good_pixel_addr(good_pixel_addr)
    );
    blk_mem_gen_3           good_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(good_pixel_addr),
        .dina(data),
        .douta(good_pixel)
    );
    blk_mem_gen_4           good_efx_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(good_efx_pixel_addr),
        .dina(data),
        .douta(good_efx_pixel)
    );


    /// <OK>
    /// 
    /// </OK>
    ok_mem_addr_gen         ok_mem_addr_gen_inst(
        .clk(clk),
        .clk_25MHz(op_clk_25MHz),
        .rst(rst),
        .vsync(op_vsync),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),

        .request(do_hit_2 | ka_hit_2 & !(do_hit_1 | ka_hit_1)),

        .ok_efx(ok_efx),
        .ok(ok),
        .ok_efx_pixel_addr(ok_efx_pixel_addr),
        .ok_pixel_addr(ok_pixel_addr)
    );
    blk_mem_gen_5           ok_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(ok_pixel_addr),
        .dina(data),
        .douta(ok_pixel)
    );
    blk_mem_gen_6           ok_efx_inst(
        .clka(clk_25MHz),
        .wea(0),
        .addra(ok_efx_pixel_addr),
        .dina(data),
        .douta(ok_efx_pixel)
    );


    /// <Util>
    /// 
    /// </Util>
    onepulse opvsync (.s_op(op_vsync), .s(vsync),       .clk(clk));
    debounce dbrst   (.s_db(db_rst),   .s(pre_rst),     .clk(clk));
    onepulse oprst   (.s_op(rst),      .s(db_rst),      .clk(clk));
    debounce dbleft  (.s_db(left),  .s(pre_left),       .clk(clk));
    debounce dbright (.s_db(right), .s(pre_right),      .clk(clk));
    onepulse op25M   (.s_op(op_clk_25MHz),.s(clk_25MHz),.clk(clk));
endmodule

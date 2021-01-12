module slide_pixel_decode(
    input  [2-1:0]  pre_slide_pixel,
    output [12-1:0] slide_pixel
);

parameter [12-1:0] list [0:3] = {
    12'h444,
    12'h666,
    12'h777,
    12'hBBB 
};
assign slide_pixel = list[pre_slide_pixel];

endmodule

module rt_top
    import rt_pkg::*;
(
    input  logic         clk,
    input  logic         rst_n,

    input  logic         frame_start,
    output logic         frame_done,
    output logic         frame_id,

    input  logic [11:0]  cfg_width,
    input  logic [11:0]  cfg_height,
    input  vec3_pos_t    cam_origin,
    input  vec3_dir_t    cam_dir_pix0,
    input  vec3_dir_t    cam_step_x,
    input  vec3_dir_t    cam_step_y,

    input  vec3_pos_t    cfg_light_pos,
    input  rgb_t         cfg_light_rgb,
    input  rgb_t         cfg_albedo,
    input  q16_16_t      cfg_bias,

    output logic         pix_valid,
    input  logic         pix_ready,
    output pixel_wr_t    pix,

    output logic         mem_req,
    input  logic         mem_ready,
    output logic [31:0]  mem_addr,
    input  logic         mem_valid,
    output logic         mem_rready,
    input  logic [127:0] mem_rdata
);

    logic  rg_valid, rg_ready;
    ray_t  rg_ray;

    logic  fifo_valid, fifo_ready;
    ray_t  fifo_ray;
    ray_kind_t fifo_kind;

    logic  rtu_hit_valid, rtu_hit_ready;
    hit_t  rtu_hit;

    logic  sec_valid, sec_ready;
    ray_t  sec_ray;
    ray_kind_t sec_kind;
    light_id_t sec_light_id;

    ray_gen u_ray_gen (
        .clk, 
        .rst_n,

        .frame_start, 
        .frame_done, 
        .frame_id,

        .out_ready(rg_ready), 
        .out_valid(rg_valid), 
        .out_ray(rg_ray),

        .cfg_width, 
        .cfg_height,

        .cam_origin, 
        .cam_dir_pix0, 
        .cam_step_x, 
        .cam_step_y
    );

    fifo_ray_in u_fifo (
        .clk, 
        .rst_n,

        .prim_valid(rg_valid), 
        .prim_ready(rg_ready), 
        .prim_ray(rg_ray),

        .shad_valid(sec_valid), 
        .shad_ready(sec_ready), 
        .shad_ray(sec_ray),

        .out_valid(fifo_valid), 
        .out_ready(fifo_ready),

        .out_ray(fifo_ray), 
        .out_kind(fifo_kind)
    );

    rtu_core u_rtu (
        .clk, 
        .rst_n,

        .in_valid(fifo_valid), 
        .in_ready(fifo_ready),
        .in_ray(fifo_ray), 
        .in_kind(fifo_kind),

        .out_valid(rtu_hit_valid), 
        .out_ready(rtu_hit_ready), 
        .out_hit(rtu_hit),

        .mem_req, 
        .mem_ready, 
        .mem_addr, 
        .mem_valid, 
        .mem_rready, 
        .mem_rdata
    );

    shu_core u_shu (
        .clk, 
        .rst_n,

        .in_valid(rtu_hit_valid), 
        .in_ready(rtu_hit_ready), 
        .in_hit(rtu_hit),

        .out_valid(pix_valid), 
        .out_ready(pix_ready), 
        .out_pixel(pix),

        .sec_valid, 
        .sec_ready, 
        .sec_ray, 
        .sec_kind, 
        .sec_light_id,

        .cfg_light_pos, 
        .cfg_light_rgb, 
        .cfg_albedo, 
        .cfg_bias
    );

endmodule
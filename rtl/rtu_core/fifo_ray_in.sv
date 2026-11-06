module fifo_ray_in #(
    parameter RTU_UNITS   = 3
    parameter PRIMARY_RAY = 16,
    parameter SHADOW_RAY  = 16
)(
    input logic rst_n,

    input  logic clk_out,
    input  logic enable_rd,
    output logic fifo_empty_out
    output ray_t [RTU_UNITS-1:0] fifo_out,

    input  logic clk_in_prim,
    input  logic enable_wr_prim,
    output logic fifo_prim_full,
    input  ray_t  fifo_in_primary,

    input  logic clk_in_shad,
    input  logic enable_wr_shad,
    output logic fifo_shad_full,
    input  ray_t  fifo_in_shadow
);

ray_t [PRIMARY_RAY-1 : 0] ray_primary_reg;
ray_t [SHADOW_RAY-1  : 0] ray_shadow_reg;

logic [PRIMARY_RAY-1 : 0] cnt_primary;
logic [SHADOW_RAY-1  : 0] cnt

assign fifo_empty_out = 

endmodule
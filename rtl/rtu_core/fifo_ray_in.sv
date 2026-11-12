module fifo_ray_in
    import rt_pkg::*;
#(
    parameter int DEPTH_PRIM = 16,
    parameter int DEPTH_SHAD = 16
)(
    input logic clk,
    input logic rst_n,

    // PRIMARY RAY //
    input  logic     prim_valid,
    output logic     prim_ready,
    input  ray_t     prim_ray,

    // SHADOW RAY //
    input  logic     shad_valid,
    output logic     shad_ready,
    input  ray_t     shad_ray,

    // FIFO -> RTU_CORE //
    output logic      out_valid,
    input  logic      out_ready,
    output ray_t      out_ray,
    output ray_kind_t out_kind
);

    localparam int W_PRIM = $clog2(DEPTH_PRIM);
    localparam int W_SHAD = $clog2(DEPTH_SHAD);

    ray_t prim_mem [0:DEPTH_PRIM-1];
    ray_t shad_mem [0:DEPTH_SHAD-1];

    logic [W_PRIM:0] prim_count;
    logic [W_SHAD:0] shad_count;

    logic [W_PRIM-1:0] prim_wr, prim_rd;
    logic [W_SHAD-1:0] shad_wr, shad_rd;

    wire prim_empty = (prim_count == '0);
    wire shad_empty = (shad_count == '0);
    wire prim_full  = (prim_count == DEPTH_PRIM[W_PRIM:0]);
    wire shad_full  = (shad_count == DEPTH_SHAD[W_SHAD:0]);

    assign prim_ready = !prim_full;
    assign shad_ready = !shad_full;

    wire take_shad = out_ready && !shad_empty;
    wire take_prim = out_ready &&  shad_empty && !prim_empty;
    wire take_any  = take_shad || take_prim;

    assign out_valid = !shad_empty || !prim_empty;
    assign out_ray   = !shad_empty ? shad_mem[shad_rd] : prim_mem[prim_rd];
    assign out_kind  = !shad_empty ? SHADOW : PRIMARY;

    wire push_prim = prim_valid && prim_ready;
    wire push_shad = shad_valid && shad_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prim_count <= '0;
            shad_count <= '0;
            prim_wr    <= '0;
            prim_rd    <= '0;
            shad_wr    <= '0;
            shad_rd    <= '0;
        end else begin
            if (push_prim) begin
                prim_mem[prim_wr] <= prim_ray;
                prim_wr <= prim_wr + 1'b1;
            end

            if (push_shad) begin
                shad_mem[shad_wr] <= shad_ray;
                shad_wr <= shad_wr + 1'b1;
            end

            if (take_shad)
                shad_rd <= shad_rd + 1'b1;
            else if (take_prim)
                prim_rd <= prim_rd + 1'b1;
            
            // update fifo counters //
            unique case ({push_prim, take_prim})
                2'b10: prim_count <= prim_count + 1'b1;
                2'b01: prim_count <= prim_count - 1'b1;
                default: ;
            endcase

            unique case ({push_shad, take_shad})
                2'b10: shad_count <= shad_count + 1'b1;
                2'b01: shad_count <= shad_count - 1'b1;
                default: ;
            endcase
        end
    end

endmodule
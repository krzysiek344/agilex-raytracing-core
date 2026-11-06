module rtu_core
    import rt_pkg::*;
(
    input  logic         clk,
    input  logic         rst_n,

    input  logic         in_valid,
    output logic         in_ready,
    input  ray_t         in_ray,
    input  ray_kind_t    in_kind,

    output logic         out_valid,
    input  logic         out_ready,
    output hit_t         out_hit,

    output logic         mem_req,
    input  logic         mem_ready,
    output logic [31:0]  mem_addr,
    input  logic         mem_valid,
    output logic         mem_rready,
    input  logic [127:0] mem_rdata
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_FETCH,
        ST_DECODE,
        ST_AABB,
        ST_SPHERE,
        ST_DONE
    } state_t;

    state_t state, state_n;

    ray_t      ray_r;
    ray_kind_t kind_r;

    logic        best_hit;
    q16_16_t     best_t;
    vec3_pos_t   best_pos;
    vec3_dir_t   best_n;
    logic [15:0] best_prim;

    logic [31:0]  node_addr_r;
    logic [127:0] node_word_r;

    wire is_leaf = node_word_r[0];

    localparam int STACK_DEPTH = 16;
    logic [31:0] stack_mem [0:STACK_DEPTH-1];
    logic [$clog2(STACK_DEPTH):0] sp;

    assign in_ready  = (state == ST_IDLE);
    assign out_valid = (state == ST_DONE);

    wire accept_ray = in_valid && in_ready;
    wire accept_hit = out_valid && out_ready;

    always_comb begin
        state_n    = state;
        mem_req    = 1'b0;
        mem_addr   = node_addr_r;
        mem_rready = 1'b0;

        unique case (state)
            ST_IDLE: begin
                if (accept_ray)
                    state_n = ST_FETCH;
            end

            ST_FETCH: begin
                mem_req    = 1'b1;
                mem_addr   = node_addr_r;
                mem_rready = 1'b1;
                if (mem_valid)
                    state_n = ST_DECODE;
            end

            ST_DECODE: begin
                if (is_leaf)
                    state_n = ST_SPHERE;
                else
                    state_n = ST_AABB;
            end

            ST_AABB: begin
                state_n = ST_FETCH;
            end

            ST_SPHERE: begin
                state_n = ST_DONE;
            end

            ST_DONE: begin
                if (accept_hit)
                    state_n = ST_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            sp       <= '0;
            best_hit <= 1'b0;
            best_t   <= T_MAX;
            ray_r    <= '0;
            kind_r   <= PRIMARY;
            node_addr_r <= '0;
            node_word_r <= '0;
            best_pos <= '0;
            best_n   <= '0;
            best_prim <= '0;
            out_hit  <= '0;
        end else begin
            state <= state_n;

            if (accept_ray) begin
                ray_r       <= in_ray;
                kind_r      <= in_kind;
                node_addr_r <= 32'd0;
                sp          <= '0;
                best_hit    <= 1'b0;
                best_t      <= T_MAX;
                best_pos    <= '0;
                best_n      <= '0;
                best_prim   <= '0;
            end

            if (state == ST_FETCH && mem_valid)
                node_word_r <= mem_rdata;

            if (state_n == ST_DONE) begin
                out_hit.pixel_id <= ray_r.pixel_id;
                out_hit.frame_id <= ray_r.frame_id;
                out_hit.kind     <= kind_r;
                out_hit.hit      <= best_hit;
                out_hit.t        <= best_t;
                out_hit.pos      <= best_pos;
                out_hit.normal   <= best_n;
                out_hit.prim_id  <= best_prim;
            end
        end
    end

endmodule
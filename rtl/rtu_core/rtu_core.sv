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
        ST_FETCH0, 
        ST_FETCH1,
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

    // memory 
    logic [15:0]  node_idx_r;
    logic [127:0] node_w0_r;
    logic [127:0] node_w1_r;

    wire        is_leaf    =  node_w0_r[0];
    wire [31:0] mem_addr_w = {15'd0, node_idx_r, 1'b0};

    wire [15:0] child_l = node_w0_r[31:16];
    wire [15:0] child_r = node_w0_r[47:32];

    wire [15:0]   leaf_prim = node_w0_r[15:1];
    wire q16_16_t leaf_cx   = node_w0_r[79:48];
    wire q16_16_t leaf_cy   = node_w0_r[111:80];
    wire q16_16_t leaf_cz   = node_w1_r[31:0];
    wire q16_16_t leaf_r    = node_w1_r[63:32];

    localparam int STACK_DEPTH = 16;
    logic [31:0] stack_mem [0:STACK_DEPTH-1];
    logic [$clog2(STACK_DEPTH):0] sp;

    assign in_ready  = (state == ST_IDLE);
    assign out_valid = (state == ST_DONE);

    wire accept_ray = in_valid && in_ready;
    wire accept_hit = out_valid && out_ready;

    always_comb begin
        state_n    = state;
        mem_addr   = 32'd0;
        mem_req    = 1'b0;
        mem_rready = 1'b0;

        unique case (state)
            ST_IDLE: begin
                if (accept_ray)
                    state_n = ST_FETCH0;
            end

            ST_FETCH0: begin
                mem_req    = 1'b1;
                mem_addr   = {15'b0, node_idx_r, 1'b0};
                mem_rready = 1'b1;
                if (mem_valid)
                    state_n = ST_FETCH1;
            end

            ST_FETCH1: begin
                mem_req = 1'b1;
                mem_addr = {15'd0, node_idx_r, 1'b1};
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
                state_n = ST_FETCH0;
            end

            ST_SPHERE: begin
                state_n = ST_DONE;
            end

            ST_DONE: begin
                if (accept_hit)
                    state_n = ST_IDLE;
            end
	    default: state_n = ST_IDLE;
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
            node_idx_r <= '0;
            node_w0_r  <= '0;
            node_w1_r  <= '0;
            best_pos <= '0;
            best_n   <= '0;
            best_prim <= '0;
            out_hit  <= '0;
        end else begin
            state <= state_n;

            if (accept_ray) begin
                ray_r       <= in_ray;
                kind_r      <= in_kind;
                node_idx_r  <= '0;
                sp          <= '0;
                best_hit    <= 1'b0;
                best_t      <= T_MAX;
                best_pos    <= '0;
                best_n      <= '0;
                best_prim   <= '0;
            end

            if (state == ST_FETCH0 && mem_valid)
                node_w0_r <= mem_rdata;

            if (state == ST_FETCH1 && mem_valid)
                node_w1_r <= mem_rdata;

            if (state == ST_AABB)
                node_idx_r <= child_l;  

            if (state == ST_SPHERE) begin
                if ( (ray_r.origin.x - leaf_cx) * (ray_r.origin.x - leaf_cx) +
                    (ray_r.origin.y - leaf_cy) * (ray_r.origin.y - leaf_cy)
                    <= leaf_r * leaf_r ) begin
                    best_hit   <= 1'b1;
                    best_t     <= leaf_cz - ray_r.origin.z;
                    best_pos.x <= leaf_cx;
                    best_pos.y <= leaf_cy;
                    best_pos.z <= leaf_cz;
                    best_n.x   <= 16'sh0;
                    best_n.y   <= 16'sh0;
                    best_n.z   <= 16'sh7FFF;
                    best_prim  <= leaf_prim;
                end
            end

            if (state == ST_DONE) begin
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

module shu_core
    import rt_pkg::*;
#(
    parameter int NUM_LIGHTS = 1
)(
    input  logic         clk,
    input  logic         rst_n,

    input  logic         in_valid,
    output logic         in_ready,
    input  hit_t         in_hit,

    output logic         out_valid,
    input  logic         out_ready,
    output pixel_wr_t    out_pixel,

    output logic         sec_valid,
    input  logic         sec_ready,
    output ray_t         sec_ray,
    output ray_kind_t    sec_kind,
    output light_id_t    sec_light_id,

    input  vec3_pos_t    cfg_light_pos,
    input  rgb_t         cfg_light_rgb,
    input  rgb_t         cfg_albedo,
    input  q16_16_t      cfg_bias
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_SHADE,
        ST_EMIT_SEC,
        ST_WAIT_SEC,
        ST_APPLY,    
        ST_EMIT_PIX
    } state_t;

    state_t state, state_n;

    hit_t        hit_r;
    rgb_t        partial_rgb_r;
    q1_15_t      ndotl_r;
    vec3_dir_t   ldir_r;
    logic        pending_r;
    logic [20:0] pix_r;
    logic        frame_r;

    assign in_ready  = (state == ST_IDLE) || (state == ST_WAIT_SEC);
    assign out_valid = (state == ST_EMIT_PIX);
    assign sec_valid = (state == ST_EMIT_SEC);
    assign sec_kind  = SHADOW;
    assign sec_light_id = '0;

    wire accept_in  = in_valid && in_ready;
    wire accept_out = out_valid && out_ready;
    wire accept_sec = sec_valid && sec_ready;

    function automatic q1_15_t sat_ndotl(vec3_dir_t n, vec3_dir_t l);
        sat_ndotl = '0;
    endfunction

    function automatic rgb_t scale_rgb(rgb_t a, q1_15_t w, rgb_t light);
        scale_rgb = '0;
    endfunction

    function automatic vec3_dir_t dir_to_light(vec3_pos_t from, vec3_pos_t light);
        dir_to_light = '0;
    endfunction

    always_comb begin
        state_n = state;

        unique case (state)
            ST_IDLE: begin
                if (accept_in) begin
                    if (in_hit.kind == PRIMARY)
                        state_n = ST_SHADE;
                end
            end

            ST_SHADE: begin
                if (!hit_r.hit)
                    state_n = ST_EMIT_PIX;
                else if (NUM_LIGHTS > 0)
                    state_n = ST_EMIT_SEC;
                else
                    state_n = ST_EMIT_PIX;
            end

            ST_EMIT_SEC: begin
                if (accept_sec)
                    state_n = ST_WAIT_SEC;
            end

            ST_WAIT_SEC: begin
                if (accept_in && in_hit.kind == SHADOW &&
                    in_hit.pixel_id == pix_r &&
                    in_hit.frame_id == frame_r)
                    state_n = ST_APPLY;
            end

            ST_APPLY: begin
                state_n = ST_EMIT_PIX;
            end

            ST_EMIT_PIX: begin
                if (accept_out)
                    state_n = ST_IDLE;
            end

	    default: state_n = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            hit_r         <= '0;
            partial_rgb_r <= '0;
            ndotl_r       <= '0;
            ldir_r        <= '0;
            pending_r     <= 1'b0;
            pix_r         <= '0;
            frame_r       <= 1'b0;
            out_pixel     <= '0;
            sec_ray       <= '0;
        end else begin
            state <= state_n;

            if (state == ST_IDLE && accept_in && in_hit.kind == PRIMARY) begin
                hit_r     <= in_hit;
                pix_r     <= in_hit.pixel_id;
                frame_r   <= in_hit.frame_id;
                pending_r <= 1'b0;
            end

            if (state == ST_SHADE) begin
                if (!hit_r.hit) begin
                    partial_rgb_r <= '0;
                end else begin
                    ldir_r  <= dir_to_light(hit_r.pos, cfg_light_pos);
                    ndotl_r <= sat_ndotl(hit_r.normal, ldir_r);
                    partial_rgb_r <= scale_rgb(cfg_albedo, ndotl_r, cfg_light_rgb);

                    sec_ray.pixel_id <= hit_r.pixel_id;
                    sec_ray.frame_id <= hit_r.frame_id;
                    sec_ray.origin   <= hit_r.pos;
                    sec_ray.dir      <= ldir_r;
                    pending_r        <= 1'b1;
                end
            end

            if (state == ST_WAIT_SEC && accept_in && in_hit.kind == SHADOW) begin
                if (in_hit.hit)
                    partial_rgb_r <= '0;
                pending_r <= 1'b0;
            end

            if (state_n == ST_EMIT_PIX || state == ST_APPLY) begin
                out_pixel.pixel_id     <= pix_r;
                out_pixel.frame_id     <= frame_r;
                out_pixel.rgb          <= partial_rgb_r;
                out_pixel.last_in_frame <= 1'b0;
            end
        end
    end

endmodule

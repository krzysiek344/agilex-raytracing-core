module shu_core
    import rt_pkg::*;
#(
    parameter int NUM_LIGHTS = 1   // v1: 1; kontrakt gotowy pod MAX_LIGHTS
)(
    input  logic         clk,
    input  logic         rst_n,

    // ---- hit z RTU ----
    input  logic         in_valid,
    output logic         in_ready,
    input  hit_t         in_hit,

    // ---- pixel do FB writera ----
    output logic         out_valid,
    input  logic         out_ready,
    output pixel_wr_t    out_pixel,

    // ---- secondary (SHADOW) z powrotem do RTU / FIFO sec ----
    output logic         sec_valid,
    input  logic         sec_ready,
    output ray_t         sec_ray,
    output ray_kind_t    sec_kind,
    output light_id_t    sec_light_id,

    // ---- cfg światła / materiału (v1: jedno światło punktowe) ----
    input  vec3_pos_t    cfg_light_pos,
    input  rgb_t         cfg_light_rgb,   // I_i w UQ8.8
    input  rgb_t         cfg_albedo,
    input  q16_16_t      cfg_bias         // epsilon od powierzchni (np. 1/256)
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_SHADE,       // PRIMARY: miss→pixel; hit→N·L + przygotuj shadow
        ST_EMIT_SEC,    // wypchnij SHADOW ray
        ST_WAIT_SEC,    // czekaj na hit kind=SHADOW tego piksela
        ST_APPLY,       // visibility → final rgb
        ST_EMIT_PIX
    } state_t;

    state_t state, state_n;

    hit_t        hit_r;
    rgb_t        partial_rgb_r;
    q1_15_t      ndotl_r;
    vec3_dir_t   ldir_r;
    logic        pending_r;      // czeka na shadow
    logic [20:0] pix_r;
    logic        frame_r;

    // --- handshake ---
    assign in_ready  = (state == ST_IDLE) || (state == ST_WAIT_SEC);
    assign out_valid = (state == ST_EMIT_PIX);
    assign sec_valid = (state == ST_EMIT_SEC);
    assign sec_kind  = SHADOW;
    assign sec_light_id = '0;    // v1: light 0

    wire accept_in  = in_valid && in_ready;
    wire accept_out = out_valid && out_ready;
    wire accept_sec = sec_valid && sec_ready;

    // --- stub Lambert: N·L (q15) — docelowo q15_mul / shade_diffuse ---
    function automatic q1_15_t sat_ndotl(vec3_dir_t n, vec3_dir_t l);
        // placeholder: max(0, n·l) — wymaga q15_mul + sumy w pkg
        sat_ndotl = '0;
        // TODO: ndot = q15_mul(n.x,l.x)+...; if (ndot<0) 0 else ndot
    endfunction

    function automatic rgb_t scale_rgb(rgb_t a, q1_15_t w, rgb_t light);
        scale_rgb = '0;
        // TODO: a * w * light w UQ8.8 (po q15→uq8 cast)
    endfunction

    // kierunek do światła (stub: bez normalizacji — v1 może założyć pre-norm w cfg)
    function automatic vec3_dir_t dir_to_light(vec3_pos_t from, vec3_pos_t light);
        dir_to_light = '0;
        // TODO: (light-from) → Q1.15 (normalize później / approx)
    endfunction

    always_comb begin
        state_n = state;

        unique case (state)
            ST_IDLE: begin
                if (accept_in) begin
                    if (in_hit.kind == PRIMARY)
                        state_n = ST_SHADE;
                    // SHADOW w IDLE ignorujemy (nieoczekiwany)
                end
            end

            ST_SHADE: begin
                if (!hit_r.hit)
                    state_n = ST_EMIT_PIX;          // miss → czarny
                else if (NUM_LIGHTS > 0)
                    state_n = ST_EMIT_SEC;          // v1: 1 shadow
                else
                    state_n = ST_EMIT_PIX;          // shade bez cienia
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

            // przyjęcie PRIMARY
            if (state == ST_IDLE && accept_in && in_hit.kind == PRIMARY) begin
                hit_r     <= in_hit;
                pix_r     <= in_hit.pixel_id;
                frame_r   <= in_hit.frame_id;
                pending_r <= 1'b0;
            end

            // SHADE
            if (state == ST_SHADE) begin
                if (!hit_r.hit) begin
                    partial_rgb_r <= '0;
                end else begin
                    ldir_r  <= dir_to_light(hit_r.pos, cfg_light_pos);
                    ndotl_r <= sat_ndotl(hit_r.normal, ldir_r);
                    // wkład bez visibility — doliczymy po shadow
                    partial_rgb_r <= scale_rgb(cfg_albedo, ndotl_r, cfg_light_rgb);

                    // przygotuj shadow ray: origin = hit + bias*N, dir → light
                    sec_ray.pixel_id <= hit_r.pixel_id;
                    sec_ray.frame_id <= hit_r.frame_id;
                    sec_ray.origin   <= hit_r.pos;   // TODO: + bias * normal
                    sec_ray.dir      <= ldir_r;
                    pending_r        <= 1'b1;
                end
            end

            // powrót SHADOW (one-shot: nie emitujemy kolejnego sec)
            if (state == ST_WAIT_SEC && accept_in && in_hit.kind == SHADOW) begin
                // hit==1 ⇒ zasłonięte ⇒ visibility=0
                if (in_hit.hit)
                    partial_rgb_r <= '0;
                // else: partial już ma albedo*(N·L)*I
                pending_r <= 1'b0;
            end

            if (state_n == ST_EMIT_PIX || state == ST_APPLY) begin
                out_pixel.pixel_id     <= pix_r;
                out_pixel.frame_id     <= frame_r;
                out_pixel.rgb          <= partial_rgb_r;
                out_pixel.last_in_frame <= 1'b0; // parent / ray_gen liczy koniec klatki
            end
        end
    end

endmodule
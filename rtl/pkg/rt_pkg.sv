package rt_pkg;

    typedef logic signed [31:0] q16_16_t;
    typedef logic signed [15:0] q1_15_t;
    typedef logic        [15:0] uq8_8_t;

    localparam int MAX_LIGHTS = 4;
    typedef logic [$clog2(MAX_LIGHTS)-1:0] light_id_t;

    localparam q16_16_t T_MAX    = 32'sh7FFF_FFFF;
    localparam q16_16_t Q16_ONE  = 32'sh0001_0000;
    localparam q1_15_t  Q15_ONE  = 16'sh7FFF;
    localparam uq8_8_t  UQ8_ONE  = 16'h0100;

    typedef struct packed {
        q16_16_t x, y, z;
    } vec3_pos_t;

    typedef struct packed {
        q1_15_t x, y, z;
    } vec3_dir_t;

    typedef struct packed {
        uq8_8_t r, g, b;
    } rgb_t;

    typedef enum logic {
        PRIMARY,
        SHADOW
    } ray_kind_t;

    typedef struct packed {
        logic [20:0] pixel_id;
        vec3_pos_t   origin;
        vec3_dir_t   dir;
        logic        frame_id;
    } ray_t;

    typedef struct packed {
        logic [20:0] pixel_id;
        logic        frame_id;
        logic        hit;
        q16_16_t     t;
        vec3_pos_t   pos;
        vec3_dir_t   normal;
        logic [15:0] prim_id;
        ray_kind_t   kind;
        light_id_t   light_id;
    } hit_t;

    typedef struct packed {
        logic [20:0] pixel_id;
        rgb_t        rgb;
        logic        frame_id;
        logic        last_in_frame;
    } pixel_wr_t;

endpackage : rt_pkg
module ray_gen
    import rt_pkg::*;
(
    input logic         clk,
    input logic         rst_n,

    input  logic        frame_start,
    output logic        frame_done,
    output logic        frame_id,
    
    input  logic        out_ready,
    output logic        out_valid,
    output ray_t        out_ray,

    input logic [11:0]  cfg_width,
    input logic [11:0]  cfg_height,
    
    input vec3_pos_t    cam_origin,
    input vec3_dir_t    cam_dir_pix0,
    input vec3_dir_t    cam_step_x,
    input vec3_dir_t    cam_step_y
);

typedef enum logic {
    ST_IDLE,
    ST_RUN
} state_t;

state_t     state, state_nxt;

logic [11:0]    x, x_nxt;
logic [11:0]    y, y_nxt;
logic [20:0]    pixel_id, pixel_id_nxt;

vec3_dir_t      cur_dir, cur_dir_nxt;
vec3_dir_t      line_dir, line_dir_nxt;

logic       frame_done_nxt;
logic       out_valid_nxt;
ray_t       out_ray_nxt; 

logic       handshake;
logic       last_pixel;
logic       end_of_row;

assign handshake  = out_valid && out_ready;
assign end_of_row = (x == cfg_width - 1);
assign last_pixel = end_of_row && (y == cfg_height - 1);


always_ff @(posedge clk) begin
    if(!rst_n) begin
        state    <= ST_IDLE;
        x        <= '0;
        y        <= '0;
        pixel_id <= '0;
        cur_dir  <= '0;
        line_dir <= '0;
        
        frame_done <= '0;
        out_valid  <= '0;
        out_ray    <= '0;
    end else begin
        state      <= state_nxt;
        x          <= x_nxt;
        y          <= y_nxt;
        pixel_id   <= pixel_id_nxt;
        cur_dir    <= cur_dir_nxt;
        line_dir   <= line_dir_nxt; 
        
        frame_done <= frame_done_nxt;
        out_valid  <= out_valid_nxt;
        out_ray    <= out_ray_nxt;
    end
end

always_comb begin
    state_nxt      = state;
    x_nxt          = x;
    y_nxt          = y;
    pixel_id_nxt   = pixel_id;
    cur_dir_nxt    = cur_dir;
    line_dir_nxt   = line_dir;

    frame_done_nxt = 1'b0;
    out_valid_nxt  = out_valid;
    out_ray_nxt    = out_ray;

    unique case (state) 
        ST_IDLE: begin
            out_valid_nxt = 1'b0;
            if (frame_start) begin
                state_nxt    = ST_RUN;
                x_nxt        = '0;
                y_nxt        = '0;
                pixel_id_nxt = '0;

                cur_dir_nxt  = cam_dir_pix0;
                line_dir_nxt = cam_dir_pix0;
                
                out_valid_nxt        = 1'b1;
                out_ray_nxt.pixel_id = '0;
                out_ray_nxt.origin   = cam_origin;
                out_ray_nxt.dir      = cam_dir_pix0;
                out_ray_nxt.frame_id = frame_id;
            end
        end

        ST_RUN: begin
            out_valid_nxt = 1'b1;
            out_ray_nxt.pixel_id = pixel_id;
            out_ray_nxt.origin   = cam_origin;
            out_ray_nxt.dir      = cur_dir;
            out_ray_nxt.frame_id = frame_id;

            if (handshake) begin
                if (last_pixel) begin
                    state_nxt      = ST_IDLE;
                    out_valid_nxt  = 1'b0;
                    frame_done_nxt = 1'b1;
                end else begin
                    pixel_id_nxt += 1;

                    if (end_of_row) begin
                        x_nxt = '0;
                        y_nxt += 1;
                        
                        line_dir_nxt.x = line_dir.x + cam_step_y.x;
                        line_dir_nxt.y = line_dir.y + cam_step_y.y;
                        line_dir_nxt.z = line_dir.z + cam_step_y.z;
                        
                        cur_dir_nxt = line_dir_nxt;
                    end else begin
                        x_nxt += 1;
                        
                        cur_dir_nxt.x = cur_dir.x + cam_step_x.x;
                        cur_dir_nxt.y = cur_dir.y + cam_step_x.y;
                        cur_dir_nxt.z = cur_dir.z + cam_step_x.z;
                    end
                end
            end
        end

        default:
            state_nxt = ST_IDLE;
    endcase
end

endmodule : ray_gen

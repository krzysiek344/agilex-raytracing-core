`timescale 1ps/1ps

module tb_ray_gen;
    import rt_pkg::*;

    logic        clk, rst_n;
    logic        frame_start, frame_done, frame_id;
    logic        out_ready, out_valid;
    ray_t        out_ray;

    logic [11:0] cfg_width, cfg_height;
    vec3_pos_t   cam_origin;
    vec3_dir_t   cam_dir_pix0, cam_step_x, cam_step_y;

    ray_gen dut (
        .clk, .rst_n,
        .frame_start, .frame_done, .frame_id,
        .out_ready, .out_valid, .out_ray,
        .cfg_width, .cfg_height,
        .cam_origin, .cam_dir_pix0, .cam_step_x, .cam_step_y
    );

    task automatic reset();
        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask

    task automatic start_frame();
        @(negedge clk);
        frame_start = 1'b1;
        @(negedge clk);
        frame_start = 1'b0;
    endtask

    task automatic check_ray(
        int      exp_pid,
        q1_15_t  exp_dx,
        q1_15_t  exp_dy,
        q1_15_t  exp_dz
    );
        out_ready = 1'b1;
        do @(negedge clk); while (!(out_valid && out_ready));

        assert (out_ray.pixel_id === exp_pid)
        else $error("pixel_id: got %0d exp %0d", out_ray.pixel_id, exp_pid);

        assert (out_ray.dir.x === exp_dx &&
                out_ray.dir.y === exp_dy &&
                out_ray.dir.z === exp_dz)
        else $error("dir pid=%0d: got (%0d,%0d,%0d) exp (%0d,%0d,%0d)",
                    exp_pid,
                    out_ray.dir.x, out_ray.dir.y, out_ray.dir.z,
                    exp_dx, exp_dy, exp_dz);

        $display("OK ray pid=%0d dir=(%0d,%0d,%0d)",
                 out_ray.pixel_id, out_ray.dir.x, out_ray.dir.y, out_ray.dir.z);

        @(negedge clk);
    endtask

    initial begin
        clk = 1'b0;
        forever #5ns clk = ~clk;
    end

    initial begin
        rst_n        = 1'b1;
        frame_start  = 1'b0;
        out_ready    = 1'b0;
        cfg_width    = 12'd2;
        cfg_height   = 12'd2;
        cam_origin   = '{x: 0, y: 0, z: 0};
        cam_dir_pix0 = '{x: 0, y: 0, z: 16'sh1000};
        cam_step_x   = '{x: 16'sh0100, y: 0, z: 0};
        cam_step_y   = '{x: 0, y: 16'sh0100, z: 0};

        reset();
        start_frame();

        check_ray(0, 16'sh0000, 16'sh0000, 16'sh1000);
        check_ray(1, 16'sh0100, 16'sh0000, 16'sh1000);
        check_ray(2, 16'sh0000, 16'sh0100, 16'sh1000);
        check_ray(3, 16'sh0100, 16'sh0100, 16'sh1000);

        $display("DONE tb_ray_gen");
        $finish;
    end

    initial begin
        #1ms;
        $error("TIMEOUT tb_ray_gen");
        $finish;
    end

endmodule
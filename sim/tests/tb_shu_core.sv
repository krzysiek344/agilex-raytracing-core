`timescale 1ps/1ps

module tb_shu_core;
    import rt_pkg::*;

    logic      clk, rst_n;
    logic      in_valid, in_ready;
    hit_t      in_hit;

    logic      out_valid, out_ready;
    pixel_wr_t out_pixel;

    logic      sec_valid, sec_ready;
    ray_t      sec_ray;
    ray_kind_t sec_kind;
    light_id_t sec_light_id;

    vec3_pos_t cfg_light_pos;
    rgb_t      cfg_light_rgb, cfg_albedo;
    q16_16_t   cfg_bias;

    shu_core dut (
        .clk, .rst_n,
        .in_valid, .in_ready, .in_hit,
        .out_valid, .out_ready, .out_pixel,
        .sec_valid, .sec_ready, .sec_ray, .sec_kind, .sec_light_id,
        .cfg_light_pos, .cfg_light_rgb, .cfg_albedo, .cfg_bias
    );

    task automatic reset();
        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask

    task automatic drive_hit(hit_t h);
        in_hit = h;

        do @(negedge clk); while (!in_ready);

        in_valid = 1'b1;
        @(negedge clk);
        in_valid = 1'b0;
    endtask

    task automatic wait_pixel();
        out_ready = 1'b1;
        do @(negedge clk); while (!(out_valid && out_ready));
        $display("PIX: pid=%0d rgb=(%0d,%0d,%0d)",
                 out_pixel.pixel_id, out_pixel.rgb.r, out_pixel.rgb.g, out_pixel.rgb.b);
        @(negedge clk);
        out_ready = 1'b0;
    endtask

    task automatic wait_sec_and_reply(logic shadowed);
        hit_t sh;
        sec_ready = 1'b1;
        do @(negedge clk); while (!(sec_valid && sec_ready));

        assert (sec_kind === SHADOW)
        else $error("sec_kind: expected SHADOW");

        $display("SEC: pid=%0d", sec_ray.pixel_id);
        @(negedge clk);
        sec_ready = 1'b0;

        sh = '0;
        sh.pixel_id = sec_ray.pixel_id;
        sh.frame_id = sec_ray.frame_id;
        sh.kind     = SHADOW;
        sh.hit      = shadowed;
        drive_hit(sh);
    endtask

    initial begin
        clk = 1'b0;
        forever #5ns clk = ~clk;
    end

    initial begin
        hit_t h;

        rst_n         = 1'b1;
        in_valid      = 1'b0;
        out_ready     = 1'b0;
        sec_ready     = 1'b0;
        in_hit        = '0;
        cfg_light_pos = '{x: 0, y: 32'sh0001_0000, z: 0};
        cfg_light_rgb = '{r: 16'h0100, g: 16'h0100, b: 16'h0100};
        cfg_albedo    = '{r: 16'h0100, g: 16'h0080, b: 16'h0040};
        cfg_bias      = 32'sh0000_0100;

        reset();

        // A: PRIMARY miss → pixel
        h = '0;
        h.pixel_id = 21'd1;
        h.kind     = PRIMARY;
        h.hit      = 1'b0;
        drive_hit(h);
        wait_pixel();

        assert (out_pixel.pixel_id === 21'd1)
        else $error("miss pixel_id: got %0d", out_pixel.pixel_id);

        assert (out_pixel.rgb.r === '0 &&
                out_pixel.rgb.g === '0 &&
                out_pixel.rgb.b === '0)
        else $error("miss rgb: expected black");

        // B: PRIMARY hit → shadow → pixel
        h = '0;
        h.pixel_id = 21'd2;
        h.kind     = PRIMARY;
        h.hit      = 1'b1;
        h.pos      = '{x: 0, y: 0, z: 0};
        h.normal   = '{x: 0, y: 16'sh7FFF, z: 0};
        drive_hit(h);
        wait_sec_and_reply(1'b0);
        wait_pixel();

        assert (out_pixel.pixel_id === 21'd2)
        else $error("hit pixel_id: got %0d", out_pixel.pixel_id);

        $display("DONE tb_shu_core");
        $finish;
    end

    initial begin
        #1ms;
        $error("TIMEOUT tb_shu_core");
        $finish;
    end

endmodule

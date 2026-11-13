`timescale 1ps/1ps

module tb_top;
    import rt_pkg::*;

    logic         clk, rst_n;
    logic         frame_start, frame_done, frame_id;

    logic [11:0]  cfg_width, cfg_height;
    vec3_pos_t    cam_origin;
    vec3_dir_t    cam_dir_pix0, cam_step_x, cam_step_y;

    vec3_pos_t    cfg_light_pos;
    rgb_t         cfg_light_rgb, cfg_albedo;
    q16_16_t      cfg_bias;

    logic         pix_valid, pix_ready;
    pixel_wr_t    pix;

    logic         mem_req, mem_ready, mem_valid, mem_rready;
    logic [31:0]  mem_addr;
    logic [127:0] mem_rdata;

    int pix_cnt;

    rt_top dut (
        .clk, .rst_n,
        .frame_start, .frame_done, .frame_id,
        .cfg_width, .cfg_height,
        .cam_origin, .cam_dir_pix0, .cam_step_x, .cam_step_y,
        .cfg_light_pos, .cfg_light_rgb, .cfg_albedo, .cfg_bias,
        .pix_valid, .pix_ready, .pix,
        .mem_req, .mem_ready, .mem_addr,
        .mem_valid, .mem_rready, .mem_rdata
    );

    mem_model u_mem (
        .clk, .rst_n,
        .mem_req, .mem_ready, .mem_addr,
        .mem_valid, .mem_rready, .mem_rdata
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

    initial begin
        clk = 1'b0;
        forever #5ns clk = ~clk;
    end

    assign pix_ready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pix_cnt <= 0;
        else if (pix_valid && pix_ready) begin
            pix_cnt <= pix_cnt + 1;
            $display("TOP PIX #%0d pid=%0d", pix_cnt + 1, pix.pixel_id);
        end
    end

    initial begin
        rst_n         = 1'b1;
        frame_start   = 1'b0;
        cfg_width     = 12'd2;
        cfg_height    = 12'd2;
        cam_origin    = '{x: 0, y: 0, z: -32'sh0003_0000};
        cam_dir_pix0  = '{x: 0, y: 0, z: 16'sh7FFF};
        cam_step_x    = '{x: 16'sh0100, y: 0, z: 0};
        cam_step_y    = '{x: 0, y: 16'sh0100, z: 0};
        cfg_light_pos = '{x: 0, y: 32'sh0002_0000, z: 0};
        cfg_light_rgb = '{r: 16'h0100, g: 16'h0100, b: 16'h0100};
        cfg_albedo    = '{r: 16'h0100, g: 16'h0100, b: 16'h0100};
        cfg_bias      = 32'sh0000_0100;

        reset();
        start_frame();

        while (pix_cnt < 4)
            @(negedge clk);

        assert (pix_cnt === 4)
        else $error("expected 4 pixels, got %0d", pix_cnt);

        $display("DONE tb_top");
        $finish;
    end

    initial begin
        #5ms;
        assert (pix_cnt === 4)
        else $error("TIMEOUT tb_top: pix_cnt=%0d", pix_cnt);
        $finish;
    end

endmodule
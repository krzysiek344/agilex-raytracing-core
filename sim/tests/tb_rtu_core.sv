`timescale 1ps/1ps

module tb_rtu_core;
    import rt_pkg::*;

    logic         clk, rst_n;
    logic         in_valid, in_ready;
    ray_t         in_ray;
    ray_kind_t    in_kind;

    logic         out_valid, out_ready;
    hit_t         out_hit;

    logic         mem_req, mem_ready, mem_valid, mem_rready;
    logic [31:0]  mem_addr;
    logic [127:0] mem_rdata;

    rtu_core dut (
        .clk, .rst_n,
        .in_valid, .in_ready, .in_ray, .in_kind,
        .out_valid, .out_ready, .out_hit,
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

    task automatic send_ray(ray_t r, ray_kind_t k);
        in_ray  = r;
        in_kind = k;
        @(negedge clk);
        in_valid = 1'b1;
        do @(negedge clk); while (!in_ready);
        @(negedge clk);
        in_valid = 1'b0;
    endtask

    task automatic recv_hit();
        out_ready = 1'b1;
        do @(negedge clk); while (!(out_valid && out_ready));
        $display("HIT: pid=%0d kind=%0d hit=%0b t=%0d",
                 out_hit.pixel_id, out_hit.kind, out_hit.hit, out_hit.t);
        @(negedge clk);
        out_ready = 1'b0;
    endtask

    initial begin
        clk = 1'b0;
        forever #5ns clk = ~clk;
    end

    initial begin
        rst_n     = 1'b1;
        in_valid  = 1'b0;
        out_ready = 1'b0;
        in_ray    = '0;
        in_kind   = PRIMARY;

        reset();

        in_ray.pixel_id = 21'd7;
        in_ray.origin   = '{x: 0, y: 0, z: -32'sh0002_0000};
        in_ray.dir      = '{x: 0, y: 0, z: 16'sh7FFF};
        in_ray.frame_id = 1'b0;

        send_ray(in_ray, PRIMARY);
        recv_hit();

        assert (out_hit.pixel_id === 21'd7)
        else $error("pixel_id: got %0d exp 7", out_hit.pixel_id);

        assert (out_hit.kind === PRIMARY)
        else $error("kind: expected PRIMARY");

        // obecny stub RTU nie ustawia best_hit
        assert (out_hit.hit === 1'b0)
        else $error("hit: expected 0 for current stub");

        $display("DONE tb_rtu_core");
        $finish;
    end

    initial begin
        #1ms;
        $error("TIMEOUT tb_rtu_core");
        $finish;
    end

endmodule
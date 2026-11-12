`timescale 1ps/1ps

module mem_model
#(
    parameter string HEX_FILE = "tools/out/scene_sphere.hex",
    parameter int    DEPTH    = 256
)(
    input  logic         clk,
    input  logic         rst_n,

    input  logic         mem_req,
    output logic         mem_ready,
    input  logic [31:0]  mem_addr,

    output logic         mem_valid,
    input  logic         mem_rready,
    output logic [127:0] mem_rdata
);

    logic [127:0] mem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; ++i)
            mem[i] = '0;
        $readmemh(HEX_FILE, mem);
    end

    assign mem_ready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_valid <= 1'b0;
            mem_rdata <= '0;
        end else begin
            if (mem_req && mem_ready) begin
                mem_valid <= 1'b1;
                mem_rdata <= mem[mem_addr[$clog2(DEPTH)-1:0]];
            end else if (mem_valid && mem_rready) begin
                mem_valid <= 1'b0;
            end
        end
    end

endmodule
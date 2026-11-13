#   vsim -c -do "do sim/run.do tb_ray_gen"
#   vsim -c -do "set TB tb_shu_core; do sim/run.do"

if {![info exists TB]} {
    if {[llength $argv] > 0} {
        set TB [lindex $argv 0]
    } else {
        set TB tb_ray_gen
    }
}
echo "Simulating: $TB"

catch {vlib work}

vlog -sv -svinputport=var \
    rtl/pkg/rt_pkg.sv \
    rtl/ray_gen/ray_gen.sv \
    rtl/rtu_core/fifo_ray_in.sv \
    rtl/rtu_core/rtu_core.sv \
    rtl/shu_core/shu_core.sv \
    rtl/rt_top.sv \
    sim/common/mem_model.sv \
    sim/tests/tb_ray_gen.sv \
    sim/tests/tb_rtu_core.sv \
    sim/tests/tb_shu_core.sv \
    sim/tests/tb_top.sv

vsim -voptargs=+acc work.$TB

if {![batch_mode]} {
    add wave -recursive sim:/$TB/*
}

run -all

if {[batch_mode]} {
    quit -f
}

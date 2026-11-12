# użycie:
#   vsim -c -do "do sim/run.do tb_ray_gen"
#   vsim -c -do "do sim/run.do tb_rtu_core"
# GUI:
#   do sim/run.do tb_ray_gen

if {[llength $argv] == 0} {
    set TB tb_ray_gen
} else {
    set TB [lindex $argv 0]
}

catch {vlib work}

vlog -sv \
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

vsim -voptargs="+acc" $TB

add wave -recursive sim:/$TB/*

run -all

if {[batch_mode]} {
    quit -f
}
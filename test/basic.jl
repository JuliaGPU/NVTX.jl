using NVTX, Test

using Colors

@assert NVTX.isactive()

domain = NVTX.Domain("Custom domain")
NVTX.name_category(domain, 1, "boo")
NVTX.name_category(domain, 2, "blah")


NVTX.mark(domain; message="mark 1", category=1)

outer_range = NVTX.range_start(domain; message="outer range", color=colorant"red")

Threads.@threads for i = 1:5
    inner_range = NVTX.range_push(domain; message="inner range", category=2, payload=i)
    sleep(0.1)
    NVTX.range_pop(domain)
end

GC.gc(false)
GC.gc(true)

module TestMod
using NVTX
function dostuff(x)
    NVTX.@mark "a mark"
    NVTX.@mark "mark $x" payload=x

    NVTX.@range "sleeping" begin
        sleep(0.3)
    end
end
end

@test NVTX.Domain(TestMod) === NVTX.Domain(TestMod)

TestMod.dostuff(1)
TestMod.dostuff(2)

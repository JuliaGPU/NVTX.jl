filename = tempname()

@show pwd()
run(`nsys profile --output=$filename --export=json,sqlite --trace=nvtx $(Base.julia_cmd()) --project=$(Base.active_project()) --threads=3 run.jl`)
run(`nsys stats --report nvtxsum $(filename).sqlite`)


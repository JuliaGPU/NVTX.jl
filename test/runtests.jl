
if haskey(ENV, "GITHUB_WORKSPACE")
    dirname = mkdir(joinpath(ENV["GITHUB_WORKSPACE"], "output"))
else
    dirname = mktempdir()
end

nsys = get(ENV, "JULIA_NSYS", "nsys")

run(`$nsys profile --output=$(joinpath(dirname, "basic")) --export=json,sqlite --trace=nvtx $(Base.julia_cmd()) --project=$(Base.active_project()) --threads=3 basic.jl`)
run(`$nsys stats --report nvtxsum $(joinpath(dirname, "basic.sqlite"))`)

using NVTX

using Colors

NVTX.name_threads_julia()

domain = NVTX.Domain("Custom domain")
NVTX.name_category(domain, 1, "boo")
NVTX.name_category(domain, 2, "blah")


NVTX.mark(domain; message="mark 1", category=1)

outer_range = NVTX.range_start(domain; message="outer range", color=colorant"red")

Threads.@threads for i = 1:5
  inner_range = NVTX.range_start(domain; message="inner range", category=2, payload=i)
  sleep(0.1)
  NVTX.range_end(inner_range)
end

NVTX.mark(domain; message="mark 2", category=2, payload=1.2)

NVTX.range_end(outer_range)

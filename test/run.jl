using NVTX

domain = NVTX.Domain("Custom domain")

NVTX.name_category(1, "boo")
NVTX.name_category(2, "blah")

NVTX.mark(domain; message="mark 1")
NVTX.mark(domain; message="mark 2", category=2, payload=1.2)

range1 = NVTX.range_start(domain; message="range 1")
range2 = NVTX.range_start(domain; message="range 2")
NVTX.range_push(domain; message="range 3")

sleep(0.3)
NVTX.range_end(range1)
NVTX.range_end(range2)
NVTX.range_pop(domain)

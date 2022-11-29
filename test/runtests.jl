
if haskey(ENV, "GITHUB_WORKSPACE")
    dirname = mkdir(joinpath(ENV["GITHUB_WORKSPACE"], "output"))
else
    dirname = mktempdir()
end

nsys = get(ENV, "JULIA_NSYS", "nsys")

run(`$nsys profile --env-var="JULIA_NVTX_CALLBACKS=gc|alloc|free" --output=$(joinpath(dirname, "basic")) --export=json,sqlite --trace=nvtx $(Base.julia_cmd()) --project=$(Base.active_project()) --threads=3 basic.jl`)

using DataFrames, SQLite, DBInterface, Colors, Test

db = SQLite.DB(joinpath(dirname, "basic.sqlite"))

# NVTX Event Type Values:
const NvtxCategory = 33
const NvtxMark = 34
const NvtxThread = 39
const NvtxPushPopRange = 59
const NvtxStartEndRange = 60
const NvtxDomainCreate = 75
const NvtxDomainDestroy = 76

# Domains
df_threads = DataFrame(DBInterface.execute(db, """
    SELECT text
    FROM NVTX_EVENTS
    WHERE eventType = $NvtxThread
    ORDER BY text
    """))
@test df_threads.text == ["julia thread $i" for i = 1:3]

df_domains = DataFrame(DBInterface.execute(db, """
    SELECT domainId, text
    FROM NVTX_EVENTS
    WHERE eventType = $NvtxDomainCreate
    ORDER BY text
    """))
@test df_domains.text == ["Custom domain", "Julia", "Main.TestMod"]
custom_domainId  = df_domains.domainId[1]
julia_domainId   = df_domains.domainId[2]
testmod_domainId = df_domains.domainId[3]

# Julia Domain (GC)
julia_categories = DataFrame(DBInterface.execute(db, """
    SELECT category, text
    FROM NVTX_EVENTS
    WHERE eventType = $NvtxCategory AND domainId = $julia_domainId
    ORDER BY category
    """))
@test julia_categories.category == [1, 2]
@test julia_categories.text == ["full", "incremental"]

julia_teststrs = DataFrame(DBInterface.execute(db, """
    SELECT *
    FROM StringIds
    """))
julia_ranges = DataFrame(DBInterface.execute(db, """
    SELECT COALESCE(text, value) as text, category, color
    FROM NVTX_EVENTS
    LEFT JOIN StringIds on textId == id
    WHERE eventType = $NvtxPushPopRange AND domainId = $julia_domainId AND category IS NOT NULL
    ORDER BY start
    """))
@test julia_ranges.text == ["GC" for i = 1:2]
@test julia_ranges.category == [2, 1]
@test all(julia_ranges.color .== ARGB32(colorant"brown").color)

julia_marks = DataFrame(DBInterface.execute(db, """
    SELECT COALESCE(text, value) as text, sum(uint64Value) as alloc
    FROM NVTX_EVENTS
    LEFT JOIN StringIds on textId == id
    WHERE eventType = $NvtxMark AND domainId = $julia_domainId
    GROUP BY textId, text
    """))
@test julia_marks.text == ["alloc", "free"]
@test julia_marks.alloc[1] > 0

# TestMod Domain
testmod_ranges = DataFrame(DBInterface.execute(db, """
    SELECT start, end, end-start as time_ns, COALESCE(text, value) as text
    FROM NVTX_EVENTS
    LEFT JOIN StringIds on textId == id
    WHERE eventType IN ($NvtxPushPopRange,$NvtxStartEndRange) AND domainId = $testmod_domainId
    ORDER BY start
    """))

@test testmod_ranges.text == ["sleeping" for _ = 1:2]
@test all(time_ns -> 0.3 < time_ns/10^9 < 0.31, testmod_ranges.time_ns)

testmod_marks = DataFrame(DBInterface.execute(db, """
    SELECT start, COALESCE(text, value) as text, COALESCE(uint64Value, int64Value, doubleValue, uint32Value, int32Value, floatValue) as payload
    FROM NVTX_EVENTS
    LEFT JOIN StringIds on textId == id
    WHERE eventType = $NvtxMark AND domainId = $testmod_domainId
    ORDER BY start
    """))

@test testmod_marks.text == ["a mark", "mark 1", "a mark", "mark 2"]
@test isequal(testmod_marks.payload, [missing, 1, missing, 2])

# summary
run(`$nsys stats --report nvtxsum $(joinpath(dirname, "basic.sqlite"))`)

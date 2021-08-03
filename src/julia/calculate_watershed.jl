using HDF5
include("./karger.jl")
using .Karger

# USAGE: julia src/julia/calculate_watershed.jl filename
# where filename is just the name (without path or .h5).
# The file has to be an HDF5 file with fields n, edges, weights and seeds. The output
# will be written in a file with the same name in the "watershed" directory

graph_path = "results/graphs/" * ARGS[1] * ".h5"
result_path = "results/watershed/" * ARGS[1] * ".h5"

n = h5read(graph_path, "n")
edges = h5read(graph_path, "edges")
weights = h5read(graph_path, "weights")
seeds = h5read(graph_path, "seeds")
g = Graph(n, transpose(edges) .+ 1, weights)
mkpath(dirname(result_path))
cp(graph_path, result_path, force=true)
h5write(result_path, "potential", watershed(g, seeds))

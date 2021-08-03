using HDF5
include("./karger.jl")
using .Karger

# USAGE: julia src/julia/calculate_power_watershed.jl filename
# where filename is just the name (without path or .h5).
# The file has to be an HDF5 file with fields n, edges, weights and seeds. The output
# will be written in a file with the same name in the "power_watershed" directory

graph_path = "data/graphs/" * ARGS[1] * ".h5"
result_path = "results/power_watershed/" * ARGS[1] * ".h5"

n = h5read(graph_path, "n")
edges = h5read(graph_path, "edges")
weights = h5read(graph_path, "weights")
min_weight = minimum(weights)
max_weight = maximum(weights)
# normalize weights to range [0, 1]
weights ./= (max_weight - min_weight)
weights .+= min_weight
# discretize to 8bit
weights .*= 255
weights .= round.(weights)

seeds = h5read(graph_path, "seeds")
g = Graph(n, transpose(edges) .+ 1, weights)
mkpath("results/power_watershed")
cp(graph_path, result_path, force=true)

pots = power_watershed_multi(g, seeds)
segmentation = Vector{Int}(undef, n)
max_pots = zeros(n)
for (key, pot) in pots
    h5write(result_path, "potential/" * string(key), pot)
    for i in 1:n
        if pot[i] > max_pots[i]
            segmentation[i] = key
            max_pots[i] = pot[i]
        end
    end
end
h5write(result_path, "segmentation", segmentation)
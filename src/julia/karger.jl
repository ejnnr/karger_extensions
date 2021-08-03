module Karger
using Base.Threads
using SparseArrays
include("./utilities.jl")
struct Graph
    n :: Int
    edges :: Matrix{Int}
    weights :: Vector{Float64}
end

struct SeedData
    uf :: UnionFind
    is_fixed :: Vector{Bool}
    seed_list :: Vector{Int}
end

function init_seeds(seeds :: Vector{Int})
    uf = UnionFind(length(seeds))
    # True if a seed is at that position
    is_fixed = (seeds .> 0)
    # Dictionary label => union-find index
    seed_roots = Dict{Int, Int}()
    # precontract all seeds
    for i in 1:length(seeds)
        if is_fixed[i]
            if haskey(seed_roots, seeds[i])
                uf[i] = seed_roots[seeds[i]]
            else
                seed_roots[seeds[i]] = i
            end
        end
    end
    return SeedData(uf, is_fixed, collect(keys(seed_roots)))
end

function karger(g :: Graph, s :: Int, t :: Int)
    seeds = zeros(Int, g.n)
    seeds[s] = 1
    seeds[t] = 2
    karger(g, seeds)
end

function karger(g :: Graph, seeds :: Vector{Int})
    karger(g, seeds, init_seeds(seeds))
end

function karger_initialized(g :: Graph, seeds :: Vector{Int}, sd :: SeedData)
    m = size(g.edges, 2)
    karger!(g, seeds, sd, Vector{Float64}(undef, m))
end

function karger_initialized!(g :: Graph, seeds :: Vector{Int}, sd :: SeedData, scores :: Vector{Float64})
    # randexp samples from the exponential distribution with scale 1.
    # We want to sample from p(score > t) = exp(-wt). This means we have to
    # _divide by_ w! See e.g. http://www.math.wm.edu/~leemis/chart/UDR/PDFs/ExponentialS.pdf
    randexp!(scores)
    scores .= scores ./ g.weights
    # this would be argsort in numpy
    perm = sortperm(scores)

    uf, is_fixed = copy(sd.uf), copy(sd.is_fixed)
    
    num_clusters = g.n
    for i in 1:length(g.weights)
        u, v = g.edges[:, perm[i]]
        u_root, v_root = find(uf, u), find(uf, v)
        
        if is_fixed[u_root]
            if !is_fixed[v_root]
                # u has a fixed label, so merge v into u
                merged = union!(uf, u, v)
            else
                # u and v's labels are both fixed and they can't be contracted
                continue
            end
        else
            # merge u into v
            merged = union!(uf, v, u)
        end

        if merged
            num_clusters -= 1
            if num_clusters == length(sd.seed_list)
                break
            end
        end
    end
    return uf
end

function potential(g :: Graph, N :: Int, seeds :: Vector{Int})
    sd = init_seeds(seeds)
    probs = Dict(seed => zeros(g.n, nthreads()) for seed in sd.seed_list)
    scores = [Vector{Float64}(undef, size(g.edges, 2)) for i in 1:nthreads()]
    @threads for i in 1:N
        uf = karger_initialized!(g, seeds, sd, scores[threadid()])
        for j in 1:g.n
            probs[seeds[find(uf, j)]][j, threadid()] += 1/N
        end
    end
    return Dict(seed => sum(probs[seed], dims=2) for seed in sd.seed_list)
end

function watershed(g :: Graph, seeds :: Vector{Int})
    m = size(g.edges, 2)
    sd = init_seeds(seeds)

    # We want to merge edges in order of descending weight
    perm = sortperm(g.weights, rev=true)

    uf, is_fixed = sd.uf, sd.is_fixed

    num_clusters = g.n
    for i in 1:length(g.weights)
        u, v = g.edges[:, perm[i]]
        u_root, v_root = find(uf, u), find(uf, v)

        if is_fixed[u_root]
            if !is_fixed[v_root]
                # u has a fixed label, so merge v into u
                merged = union!(uf, u, v)
            else
                # u and v's labels are both fixed and they can't be contracted
                continue
            end
        else
            # merge u into v
            merged = union!(uf, v, u)
        end

        if merged
            num_clusters -= 1
            if num_clusters == length(sd.seed_list)
                break
            end
        end
    end
    segmentation = Vector{Float64}(undef, g.n)
    for i in 1:g.n
        segmentation[i] = seeds[find(uf, i)]
    end
    return segmentation
end

function power_watershed(g :: Graph, seeds :: Vector{Int})
    m = size(g.edges, 2)
    sd = init_seeds(seeds)

    # We want to merge edges in order of descending weight
    perm = sortperm(g.weights, rev=true)
    weights = g.weights[perm]
    edges = g.edges[:, perm]

    uf, is_fixed = sd.uf, sd.is_fixed

    num_unfixed_clusters = g.n

    potential = Vector{Float64}(undef, g.n)
    for i in 1:g.n
        if is_fixed[i]
            num_unfixed_clusters -= 1
            # seeds are 1 and 2, we want to make those 0 or 1
            potential[i] = convert(Float64, seeds[i]) - 1
        end
    end

    # we pre-allocate arrays for the local seeds, is_fixed values and edges
    # in each plateau. These are too large but it's still a small speed-up
    # compared to re-allocating an array for each plateau
    seeds_ = Vector{Float64}(undef, g.n)
    is_fixed_ = falses(g.n)
    edges_ = Matrix{Int}(undef, 2, length(edges))
    # we also pre-allocate buffers needed internally by find_plateaus
    label_buffer = Vector{Int}(undef, g.n)
    uf_buffer = Vector{Int}(undef, g.n)

    i = 0
    # we use a while loop so that we can skip a chunk of iterations later
    # by modifying i
    while i < m
        if num_unfixed_clusters == 0
            break
        end

        i += 1

        if i == m || weights[i + 1] < weights[i]
            # no plateau (only one edge), so just do the watershed procedure
            # to save time
            
            u, v = edges[:, i]
            u_root, v_root = find(uf, u), find(uf, v)

            if is_fixed[u_root] && is_fixed[v_root]
                # u and v's potentials are both fixed and they can't be contracted
                continue
            end
            if is_fixed[u_root]
                # u has a fixed potential, so merge v into u
                merged = union!(uf, u, v)
            else
                # merge u into v
                merged = union!(uf, v, u)
            end
            if merged
                num_unfixed_clusters -= 1
            end

            continue
        end

        indices = i:m
        plateau_nodes, plateau_edges, num_edges = find_plateaus!(weights[indices], edges[:, indices], uf, label_buffer, uf_buffer)
        # solve each plateau individually.
        for (key, nodes_) in plateau_nodes
            # translate the node ids to 1:length(nodes_):
            old_to_new_id = Dict{Int, Int}()
            fill!(is_fixed_, false)
            found_potentials = Set{Float64}()
            n_ = length(nodes_)
            m_ = length(plateau_edges[key])
            for (j, node) in enumerate(nodes_)
                old_to_new_id[node] = j
                if is_fixed[find(uf, node)]
                    seeds_[j] = potential[find(uf, node)]
                    is_fixed_[j] = true
                    push!(found_potentials, seeds_[j])
                end
            end

            if length(found_potentials) == 0
                # no fixed nodes found in this plateau, just merge the nodes
                for node in nodes_
                    if union!(uf, node, nodes_[1])
                        num_unfixed_clusters -= 1
                    end
                end
                continue
            elseif length(found_potentials) == 1
                # Only one potential occurs in this plateau, assign that to every node.
                # This isn't necessary but it's much faster than constructing the Laplacian
                # and solving the Random Walker for the plateau
                pot = first(found_potentials)
                for node in nodes_
                    if !is_fixed[find(uf, node)]
                        num_unfixed_clusters -= 1
                        is_fixed[find(uf, node)] = true
                        potential[find(uf, node)] = pot
                    end
                end
                continue
            end

            # Create a list of the edges themselves from the list of edge indices.
            # Additionally, we use old_to_new_id to transform the node identifiers
            # (we want edge entries to be wrt the local node ids for the plateau).
            for (j, edge_idx) in enumerate(plateau_edges[key])
                edge_idx += i - 1
                edges_[1, j] = old_to_new_id[find(uf, edges[1, edge_idx])]
                edges_[2, j] = old_to_new_id[find(uf, edges[2, edge_idx])]
            end

            # Now we construct the Laplacian for the plateau.
            # We need to be careful about the fact that we are working
            # with a multi-graph: there might be self-loops (which we ignore)
            # and multiple edges between the same nodes (in which case we add up the weights)

            # if the plateau is relatively small, we just construct and solve
            # a dense system
            if n_ <= 500
                lap = zeros(n_, n_)
                for j in 1:m_
                    # ignore self-loops
                    if edges_[1, j] == edges_[2, j]
                        continue
                    end
                    # Fill the Laplacian with the negative adjacency matrix.
                    # Note that there may be multiple edges between two nodes,
                    # so we need -= 1 instead of = -1. We can use 1 instead of
                    # the actual weight because all edges inside the plateau
                    # have the same weight.
                    lap[edges_[1, j], edges_[2, j]] -= 1
                    lap[edges_[2, j], edges_[1, j]] -= 1
                end
                # add the diagonal, which contains the degrees of each node
                degrees = -sum(lap, dims=1)
                for j in 1:length(nodes_)
                    lap[j, j] = degrees[j]
                end

            # if the plateau is large, it is likely very sparse and we
            # use a sparse Laplacian matrix instead
            else
                row_indices = Vector{Int}()
                col_indices = Vector{Int}()
                values = Vector{Float64}()
                for j in 1:m_
                    # ignore self-loops
                    if edges_[1, j] == edges_[2, j]
                        continue
                    end
                    # we don't need to worry about multi-edges,
                    # they will be combined anyway when forming the sparse
                    # array
                    push!(row_indices, edges_[1, j])
                    push!(col_indices, edges_[2, j])
                    push!(values, -1)

                    # also add the edge in the other direction
                    push!(row_indices, edges_[2, j])
                    push!(col_indices, edges_[1, j])
                    push!(values, -1)

                    # Finally, we add a 1 on the diagonal for both nodes
                    # (again, they are added up later automatically)
                    push!(row_indices, edges_[1, j])
                    push!(col_indices, edges_[1, j])
                    push!(values, 1)

                    push!(row_indices, edges_[2, j])
                    push!(col_indices, edges_[2, j])
                    push!(values, 1)
                end
                lap = sparse(row_indices, col_indices, values, length(nodes_), length(nodes_))
            end

            # then, we construct the linear system
            # TODO: this indexing is slow for sparse matrices,
            # is there a way to do this already during construction?
            # is_fixed_ is too long, we only need the first n_ entries
            is_fixed_view = is_fixed_[1:n_]
            lap_unseeded = lap[.!is_fixed_view, .!is_fixed_view]
            BT = lap[.!is_fixed_view, is_fixed_view]
            # seeds_ is just as long as is_fixed, so use everything here
            b = - BT * seeds_[is_fixed_]
            # TODO: should we tell Julia that the Laplacian is symmetric
            # and positive definite, to improve performance?
            x = lap_unseeded \ b

            # We now have the solution for the unseeded nodes of the
            # current plateau in x. We just need to fill them into
            # the right places.
            # k is the index for x, i.e. it enumerates the unseeded nodes
            # in the plateau. j enumerates all nodes in the plateau.
            # node gives the global index of the node j in the plateau.
            k = 1
            for (j, node) in enumerate(nodes_)
                if is_fixed_[j]
                    continue
                end
                potential[find(uf, node)] = x[k]
                is_fixed[find(uf, node)] = true
                num_unfixed_clusters -= 1
                k += 1
            end
        end
        # now we skip the remaining edges in the plateau
        i += num_edges - 1
    end

    for j in 1:g.n
        if !is_fixed[find(uf, j)]
            error("Something went wrong, not all nodes are fixed yet")
        end
        potential[j] = potential[find(uf, j)]
    end
    return potential
end

function power_watershed_multi(g :: Graph, seeds :: Vector{Int})
    m = size(g.edges, 2)
    sd = init_seeds(seeds)

    # We want to merge edges in order of descending weight
    perm = sortperm(g.weights, rev=true)
    weights = g.weights[perm]
    edges = g.edges[:, perm]

    uf, is_fixed, seed_list = sd.uf, sd.is_fixed, sd.seed_list

    num_unfixed_clusters = g.n
    num_seeds = length(seed_list)

    potentials = zeros(Float64, g.n, num_seeds)
    for i in 1:g.n
        if is_fixed[i]
            num_unfixed_clusters -= 1
            potentials[i, seeds[i]] = 1
        end
    end

    # we pre-allocate arrays for the local seeds, is_fixed values and edges
    # in each plateau. These are too large but it's still a small speed-up
    # compared to re-allocating an array for each plateau
    seeds_ = Matrix{Float64}(undef, g.n, num_seeds)
    is_fixed_ = falses(g.n)
    edges_ = Matrix{Int}(undef, 2, length(edges))
    # we also pre-allocate buffers needed internally by find_plateaus
    label_buffer = Vector{Int}(undef, g.n)
    uf_buffer = Vector{Int}(undef, g.n)

    i = 0
    # we use a while loop so that we can skip a chunk of iterations later
    # by modifying i
    while i < m
        if num_unfixed_clusters == 0
            break
        end

        i += 1

        if i == m || weights[i + 1] < weights[i]
            # no plateau (only one edge), so just do the watershed procedure
            # to save time
            
            u, v = edges[:, i]
            u_root, v_root = find(uf, u), find(uf, v)

            if is_fixed[u_root] && is_fixed[v_root]
                # u and v's potentials are both fixed and they can't be contracted
                continue
            end
            if is_fixed[u_root]
                # u has a fixed potential, so merge v into u
                merged = union!(uf, u, v)
            else
                # merge u into v
                merged = union!(uf, v, u)
            end
            if merged
                num_unfixed_clusters -= 1
            end

            continue
        end

        indices = i:m
        plateau_nodes, plateau_edges, num_edges = find_plateaus!(weights[indices], edges[:, indices], uf, label_buffer, uf_buffer)
        # solve each plateau individually.
        for (key, nodes_) in plateau_nodes
            # translate the node ids to 1:length(nodes_):
            old_to_new_id = Dict{Int, Int}()
            fill!(is_fixed_, false)
            fill!(seeds_, false)
            found_potentials = false
            n_ = length(nodes_)
            m_ = length(plateau_edges[key])
            for (j, node) in enumerate(nodes_)
                old_to_new_id[node] = j
                if is_fixed[find(uf, node)]
                    seeds_[j, :] .= potentials[find(uf, node), :]
                    is_fixed_[j] = true
                    found_potentials = true
                end
            end

            if !found_potentials
                # no fixed nodes found in this plateau, just merge the nodes
                for node in nodes_
                    if union!(uf, node, nodes_[1])
                        num_unfixed_clusters -= 1
                    end
                end
                continue
            end

            # Create a list of the edges themselves from the list of edge indices.
            # Additionally, we use old_to_new_id to transform the node identifiers
            # (we want edge entries to be wrt the local node ids for the plateau).
            for (j, edge_idx) in enumerate(plateau_edges[key])
                edge_idx += i - 1
                edges_[1, j] = old_to_new_id[find(uf, edges[1, edge_idx])]
                edges_[2, j] = old_to_new_id[find(uf, edges[2, edge_idx])]
            end

            # Now we construct the Laplacian for the plateau.
            # We need to be careful about the fact that we are working
            # with a multi-graph: there might be self-loops (which we ignore)
            # and multiple edges between the same nodes (in which case we add up the weights)

            # if the plateau is relatively small, we just construct and solve
            # a dense system
            if n_ <= 500
                lap = zeros(n_, n_)
                for j in 1:m_
                    # ignore self-loops
                    if edges_[1, j] == edges_[2, j]
                        continue
                    end
                    # Fill the Laplacian with the negative adjacency matrix.
                    # Note that there may be multiple edges between two nodes,
                    # so we need -= 1 instead of = -1. We can use 1 instead of
                    # the actual weight because all edges inside the plateau
                    # have the same weight.
                    lap[edges_[1, j], edges_[2, j]] -= 1
                    lap[edges_[2, j], edges_[1, j]] -= 1
                end
                # add the diagonal, which contains the degrees of each node
                degrees = -sum(lap, dims=1)
                for j in 1:length(nodes_)
                    lap[j, j] = degrees[j]
                end

            # if the plateau is large, it is likely very sparse and we
            # use a sparse Laplacian matrix instead
            else
                row_indices = Vector{Int}()
                col_indices = Vector{Int}()
                values = Vector{Float64}()
                for j in 1:m_
                    # ignore self-loops
                    if edges_[1, j] == edges_[2, j]
                        continue
                    end
                    # we don't need to worry about multi-edges,
                    # they will be combined anyway when forming the sparse
                    # array
                    push!(row_indices, edges_[1, j])
                    push!(col_indices, edges_[2, j])
                    push!(values, -1)

                    # also add the edge in the other direction
                    push!(row_indices, edges_[2, j])
                    push!(col_indices, edges_[1, j])
                    push!(values, -1)

                    # Finally, we add a 1 on the diagonal for both nodes
                    # (again, they are added up later automatically)
                    push!(row_indices, edges_[1, j])
                    push!(col_indices, edges_[1, j])
                    push!(values, 1)

                    push!(row_indices, edges_[2, j])
                    push!(col_indices, edges_[2, j])
                    push!(values, 1)
                end
                lap = sparse(row_indices, col_indices, values, length(nodes_), length(nodes_))
            end

            # then, we construct the linear system
            # TODO: this indexing is slow for sparse matrices,
            # is there a way to do this already during construction?
            # is_fixed_ is too long, we only need the first n_ entries
            is_fixed_view = is_fixed_[1:n_]
            lap_unseeded = lap[.!is_fixed_view, .!is_fixed_view]
            BT = lap[.!is_fixed_view, is_fixed_view]
            # seeds_ is just as long as is_fixed, so use everything here
            b = - BT * seeds_[is_fixed_, :]
            # TODO: should we tell Julia that the Laplacian is symmetric
            # and positive definite, to improve performance?
            x = lap_unseeded \ b

            # We now have the solution for the unseeded nodes of the
            # current plateau in x. We just need to fill them into
            # the right places.
            # k is the index for x, i.e. it enumerates the unseeded nodes
            # in the plateau. j enumerates all nodes in the plateau.
            # node gives the global index of the node j in the plateau.
            k = 1
            for (j, node) in enumerate(nodes_)
                if is_fixed_[j]
                    continue
                end
                potentials[find(uf, node), :] .= x[k, :]
                is_fixed[find(uf, node)] = true
                num_unfixed_clusters -= 1
                k += 1
            end
        end
        # now we skip the remaining edges in the plateau
        i += num_edges - 1
    end

    for j in 1:g.n
        if !is_fixed[find(uf, j)]
            error("Something went wrong, not all nodes are fixed yet")
        end
        potentials[j, :] .= potentials[find(uf, j), :]
    end

    return Dict(seed => potentials[:, seed] for seed in seed_list)
end

export Graph, karger, sample_cuts, potential, watershed, power_watershed, power_watershed_multi
end

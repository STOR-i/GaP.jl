module TestGaussianProcesses
@time include("utils.jl")
@time include("gp.jl")
@time include("means.jl")
@time include("kernels.jl")
@time include("optim.jl")
@time include("mcmc.jl")
@time include("GPA.jl")
@time include("elastic.jl")
@time include("memory.jl")
@time include("test_crossvalidation.jl")
@time include("test_sparse.jl")
end

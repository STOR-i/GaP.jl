
function mcmc(gp::GPBase; nIter::Int=1000, burn::Int=100, thin::Int=1, ε::Float64=0.1,
              Lmin::Int=5, Lmax::Int=15, lik::Bool=true, noise::Bool=true,
              domean::Bool=true, kern::Bool=true)
    return hmc(gp, nIter=nIter, burn=burn, thin=thin, ε=ε, Lmin=Lmin, Lmax=Lmax,
               lik=lik, noise=noise, domean=domean, kern=kern)
end

"""
    nuts_hamiltonian(gp::GPBase, metric::AdvancedHMC.AbstractMetric)

Generate Hamiltonian for the GP target. A stupid API hack but it works?
"""
function nuts_hamiltonian(gp::GPBase; lik::Bool=true, noise::Bool=true, domean::Bool=true, kern::Bool=true,
                          metric=DiagEuclideanMetric(num_params(gp; get_params_kwargs(gp, domean=domean, kern=kern, noise=noise, lik=lik)...)))
    precomp = init_precompute(gp)
    params_kwargs = get_params_kwargs(gp; domean=domean, kern=kern, noise=noise, lik=lik)
    function calc_target_and_dtarget!(θ::AbstractVector)
        set_params!(gp, θ; params_kwargs...)
        # Cholesky exceptions are handled by DynamicHMC
        update_target_and_dtarget!(gp, precomp; params_kwargs...)
        return (gp.target, gp.dtarget)
    end

    function calc_target!(θ::AbstractVector)
        set_params!(gp, θ; params_kwargs...)
        update_target!(gp; params_kwargs...)
        return gp.target
    end
    return Hamiltonian(metric, calc_target!, calc_target_and_dtarget!)
end

"""
    nuts(gp::GPBase; kwargs...)

Runs Hamiltonian Monte Carlo algorithm for estimating the hyperparameters of 
Gaussian process `GPE` and the latent function in the case of `GPA`.
Refer to AdvancedHMC.jl for more info about the keyword options.
"""
function nuts(gp::GPBase; nIter::Int=1000, burn::Int=100, thin::Int=1,
              lik::Bool=true, noise::Bool=true, domean::Bool=true, kern::Bool=true,
              metric=DiagEuclideanMetric(num_params(gp; get_params_kwargs(gp, domean=domean, kern=kern, noise=noise, lik=lik)...)),
              hamiltonian=nuts_hamiltonian(gp; metric=metric),
              ε::Float64=find_good_eps(hamiltonian, get_params(gp; get_params_kwargs(gp, domean=domean, kern=kern, noise=noise, lik=lik)...)),
              maxDepth::Int64=10, δ::Float64=0.8, integrator=Leapfrog(ε),
              proposals=NUTS{MultinomialTS, GeneralisedNoUTurn}(integrator, maxDepth),
              adaptor=StanHMCAdaptor(Preconditioner(metric), NesterovDualAveraging(δ, integrator)),
              progress=true)
    params_kwargs = get_params_kwargs(gp; domean=domean, kern=kern, noise=noise, lik=lik)
    θ_init = get_params(gp; params_kwargs...)
    dim = length(θ_init)
    post, stats = sample(hamiltonian, proposals, θ_init, nIter - burn, adaptor,
                         burn; drop_warmup=true, progress=progress, verbose=false)
    post = hcat(post...)
    post = post[:,1:thin:end]
    set_params!(gp, θ_init; params_kwargs...)

    step_stats = [[step_stat.acceptance_rate, step_stat.tree_depth] for step_stat in stats]
    avg_accept, avg_depth = mean(step_stats)
    ε = stats[end-1].step_size
    @printf("Number of iterations = %d, Thinning = %d, Burn-in = %d \n", nIter,thin,burn)
    @printf("Step size = %f, Average tree depth = %f \n", ε,avg_depth)
    @printf("Acceptance rate: %f \n", avg_accept)
    return post
end

"""
    hmc(gp::GPBase; kwargs...)

Runs Hamiltonian Monte Carlo algorithm for estimating the hyperparameters of 
Gaussian process `GPE` and the latent function in the case of `GPA`.
"""
function hmc(gp::GPBase; nIter::Int=1000, burn::Int=100, thin::Int=1, ε::Float64=0.1,
             Lmin::Int=5, Lmax::Int=15, lik::Bool=true, noise::Bool=true,
             domean::Bool=true, kern::Bool=true)
    precomp = init_precompute(gp)
    params_kwargs = get_params_kwargs(gp; domean=domean, kern=kern, noise=noise, lik=lik)
    count = 0
    function calc_target!(gp::GPBase, θ::AbstractVector) #log-target and its gradient
        count += 1
        try
            set_params!(gp, θ; params_kwargs...)
            update_target_and_dtarget!(gp, precomp; params_kwargs...)
            return true
        catch err
            if !all(isfinite.(θ))
                return false
            elseif isa(err, ArgumentError)
                return false
            elseif isa(err, LinearAlgebra.PosDefException)
                return false
            else
                throw(err)
            end
        end
    end

    θ_cur = get_params(gp; params_kwargs...)
    D = length(θ_cur)
    leapSteps = 0                   #accumulator to track number of leap-frog steps
    post = Array{Float64}(undef, D, nIter)     #posterior samples
    post[:,1] = θ_cur

    @assert calc_target!(gp, θ_cur)
    target_cur, grad_cur = gp.target, gp.dtarget

    num_acceptances = 0
    for t in 1:nIter
        θ, target, grad = θ_cur, target_cur, grad_cur

        ν_cur = randn(D)
        ν = ν_cur + 0.5 * ε * grad

        reject = false
        L = rand(Lmin:Lmax)
        leapSteps +=L
        for l in 1:L
            θ += ε * ν
            if  !calc_target!(gp,θ)
                reject=true
                break
            end
            target, grad = gp.target, gp.dtarget
            ν += ε * grad
        end
        ν -= 0.5*ε * grad

        if reject
            post[:,t] = θ_cur
        else
            α = target - 0.5 * ν'ν - target_cur + 0.5 * ν_cur'ν_cur
            u = log(rand())

            if u < α
                num_acceptances += 1
                θ_cur = θ
                target_cur = target
                grad_cur = grad
            end
            post[:,t] = θ_cur
        end
    end
    post = post[:,burn:thin:end]
    set_params!(gp, θ_cur; params_kwargs...)
    @printf("Number of iterations = %d, Thinning = %d, Burn-in = %d \n", nIter,thin,burn)
    @printf("Step size = %f, Average number of leapfrog steps = %f \n", ε,leapSteps/nIter)
    println("Number of function calls: ", count)
    @printf("Acceptance rate: %f \n", num_acceptances/nIter)
    return post
end

function get_joint_priors(gp::GPE; noise::Bool=true, domean::Bool=true, kern::Bool=true)
    priors = UnivariateDistribution[]
    if noise && num_params(gp.logNoise) != 0
        noise_priors = get_priors(gp.logNoise)
        @assert !isempty(noise_priors) "prior distributions of logNoise should be set"
        append!(priors, noise_priors)
    end
    if domean && num_params(gp.mean) != 0
        mean_priors = get_priors(gp.mean)
        @assert !isempty(mean_priors) "prior distributions of mean should be set"
        append!(priors, mean_priors)
    end
    if kern && num_params(gp.kernel) != 0
        kernel_priors = get_priors(gp.kernel)
        @assert !isempty(kernel_priors) "prior distributions of kernel should be set"
        append!(priors, kernel_priors)
    end
    @assert all([typeof(prior) <: Normal for prior in priors]) "ess requires prior distributions to be Normal"
    mu = mean.(priors)
    sigma = std.(priors)
    joint_prior = MvNormal(mu, sigma)
    return joint_prior
end

"""
    ess(gp::GPBase; kwargs...)

Sample GP hyperparameters using the elliptical slice sampling algorithm described in,

Murray, Iain, Ryan P. Adams, and David JC MacKay. "Elliptical slice sampling." 
Journal of Machine Learning Research 9 (2010): 541-548.

Requires hyperparameter priors to be Gaussian.
"""
function ess(gp::GPE; nIter::Int=1000, burn::Int=1, thin::Int=1, noise::Bool=true,
             domean::Bool=true, kern::Bool=true, lik::Bool=false)
    params_kwargs = get_params_kwargs(gp; domean=domean, kern=kern, noise=noise, lik=false)
    count = 0
    prior = get_joint_priors(gp; params_kwargs...)
    means = mean(prior)

    function calc_target!(θ::AbstractVector)
        count += 1
        try
            set_params!(gp, θ; params_kwargs...)
            update_target!(gp; params_kwargs...)
            return gp.target
        catch err
            if(!all(isfinite.(θ))
               || isa(err, ArgumentError)
               || isa(err, LinearAlgebra.PosDefException))
                return -Inf
            else
                throw(err)
            end
        end
    end

    function sample!(f::AbstractVector)
        v     = rand(prior) - means
        u     = rand()
        logy  = calc_target!(f) + log(u);
        θ     = rand()*2*π;
        θ_min = θ - 2*π;
        θ_max = θ;
        f_prime = (f - means) * cos(θ) + v * sin(θ);
        props = 1
        while calc_target!(f_prime + means) <= logy
            props += 1
            if θ < 0
                θ_min = θ;
            else
                θ_max = θ;
            end
            θ = rand() * (θ_max - θ_min) + θ_min;
            f_prime = (f - means) * cos(θ) + v * sin(θ);
        end
        return f_prime + means, props
    end

    total_proposals = 0
    θ_cur = get_params(gp; params_kwargs...)
    D = length(θ_cur)
    post = Array{Float64}(undef, D, nIter)

    for i = 1:nIter
        θ_cur, num_proposals = sample!(θ_cur)
        post[:,i] = θ_cur
        total_proposals += num_proposals
    end

    post = post[:,burn:thin:end]
    set_params!(gp, θ_cur; params_kwargs...)
    @printf("Number of iterations = %d, Thinning = %d, Burn-in = %d \n", nIter,thin,burn)
    println("Number of function calls: ", count)
    @printf("Acceptance rate: %f \n", nIter / total_proposals)
    return post
end



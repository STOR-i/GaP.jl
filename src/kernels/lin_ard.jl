#Linear ARD Covariance Function

"""
    LinArd <: Kernel

ARD linear kernel (covariance)
```math
k(x,x') = xᵀL⁻²x'
```
with length scale ``ℓ = (ℓ₁, ℓ₂, …)`` and ``L = diag(ℓ₁, ℓ₂, …)``.
"""
mutable struct LinArd <: Kernel
    "Length scale"
    ℓ::Vector{Float64}
    "Priors for kernel parameters"
    priors::Array

    """
        LinArd(ll::Vector{Float64})

    Create `LinArd` with length scale `exp.(ll)`.
    """
    LinArd(ll::Vector{Float64}) = new(exp.(ll), [])
end

Statistics.cov(lin::LinArd, x::AbstractVector, y::AbstractVector) = dot(x./lin.ℓ, y./lin.ℓ)

struct LinArdData{D} <: KernelData
    XtX_d::D
end

function KernelData(k::LinArd, X::AbstractMatrix)
    dim, nobs = size(X)
    XtX_d = Array{Float64}(undef, nobs, nobs, dim)
    @inbounds @simd for d in 1:dim
        for i in 1:nobs
            for j in 1:i
                XtX_d[i, j, d] = XtX_d[j, i, d] = X[d, i] * X[d, j]
            end
        end
    end
    LinArdData(XtX_d)
end
kernel_data_key(k::LinArd, X::AbstractMatrix) = "LinArdData"
function Statistics.cov(lin::LinArd, X::AbstractMatrix)
    K = (X./lin.ℓ)' * (X./lin.ℓ)
    LinearAlgebra.copytri!(K, 'U')
    return K
end
function cov!(cK::AbstractMatrix, lin::LinArd, X::AbstractMatrix, data::LinArdData)
    dim, nobs = size(X)
    fill!(cK, 0)
    for d in 1:dim
        LinearAlgebra.axpy!(1/lin.ℓ[d]^2, view(data.XtX_d,1:nobs, 1:nobs ,d), cK)
    end
    return cK
end
function Statistics.cov(lin::LinArd, X::AbstractMatrix, data::LinArdData)
    nobs = size(X,2)
    K = zeros(Float64, nobs, nobs)
    cov!(K, lin, X, data)
end
@inline @inbounds function cov_ij(lin::LinArd, X::AbstractMatrix, data::LinArdData, i::Int, j::Int, dim::Int)
    ck = 0.0
    for d in 1:dim
        ck += data.XtX_d[i,j,d] * 1/lin.ℓ[d]^2
    end
    return ck
end

get_params(lin::LinArd) = log.(lin.ℓ)
get_param_names(lin::LinArd) = get_param_names(lin.ℓ, :ll)
num_params(lin::LinArd) = length(lin.ℓ)

function set_params!(lin::LinArd, hyp::AbstractVector)
    length(hyp) == num_params(lin) || throw(ArgumentError("Linear ARD kernel has $(num_params(lin)) parameters"))
    @. lin.ℓ = exp(hyp)
end

@inline dk_dll(lin::LinArd, xy::Float64, d::Int) = -2 * xy / lin.ℓ[d]^2
@inline function dKij_dθp(lin::LinArd, X::AbstractMatrix, i::Int, j::Int, p::Int, dim::Int)
    if p<=dim
        return dk_dll(lin, dotijp(X,i,j,p), p)
    else
        return NaN
    end
end
@inline function dKij_dθp(lin::LinArd, X::AbstractMatrix, data::LinArdData, i::Int, j::Int, p::Int, dim::Int)
    if p <= dim
        return dk_dll(lin, data.XtX_d[i,j,p],p)
    else
        return NaN
    end
end

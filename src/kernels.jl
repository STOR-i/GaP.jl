import Distributions.params

# Here will go built-in covariance functions

#See Chapter 4 Page 90 of Rasumussen and Williams Gaussian Processes for Machine Learning

abstract Kernel

#Squared Exponential Function
type SE <: Kernel
    ll::Float64      # Log of Length scale 
    lσ::Float64      # Log of Signal std
    SE(l::Float64=1.0, σ::Float64=1.0) = new(log(l),log(σ))
end

function kern(se::SE, x::Vector{Float64}, y::Vector{Float64})
    ell = exp(se.ll)
    sigma2 = exp(2*se.lσ)
    
    sigma2*exp(-0.5*norm(x-y)^2/ell^2) 
end    
params(se::SE) = exp(Float64[se.ll, se.lσ])
num_params(se::SE) = 2
function set_params!(se::SE, hyp::Vector{Float64})
    length(hyp) == 2 || throw(ArgumentError("Squared exponential only has two parameters"))
    se.ll, se.lσ = hyp
end
function grad_kern(se::SE, x::Vector{Float64}, y::Vector{Float64})
     ell = exp(se.ll)
     sigma2 = exp(2*se.lσ)
    
       dK_ell = sigma2*norm(x-y)^2/ell^2*exp(-0.5*norm(x-y)^2/ell^2)
       dK_sigma = 2.0*sigma2*exp(-0.5*norm(x-y)^2/ell^2)
    
    dK_theta = [dK_ell,dK_sigma]
    return(dK_theta)
end    


#Matern 3/2 Function
type MAT32 <: Kernel
    l::Float64      #Length scale 
    σ::Float64      #Signal std
    MAT32(l::Float64=1.0, σ::Float64=1.0) = new(l, σ)
end

kern(mat32::MAT32, x::Vector{Float64}, y::Vector{Float64}) = mat32.σ^2*(1+sqrt(3)*norm(x-y)/mat32.l)*exp(-sqrt(3)*norm(x-y)/mat32.l)
params(mat32::MAT32) = Float64[mat32.l, mat32.σ]
num_params(mat32::MAT32) = 2
function set_params!(mat32::MAT32, hyp::Vector{Float64})
    length(hyp) == 2 || throw(ArgumentError("Matern 3/2 only has two parameters"))
    mat32.l, mat32.σ = hyp
end
grad_kern(mat32::MAT32, x::Vector{Float64}, y::Vector{Float64}) = [mat32.σ^2*(sqrt(3)*norm(x-y)/mat32.l)^2*exp(-sqrt(3)*norm(x-y)/mat32.l), 2.0*mat32.σ*(1+sqrt(3)*norm(x-y)/mat32.l)*exp(-sqrt(3)*norm(x-y)/mat32.l)]



#Matern 5/2 Function
type MAT52 <: Kernel
    l::Float64      #Length scale 
    σ::Float64     #Signal std
    MAT52(l::Float64=1.0, σ::Float64=1.0) = new(l, σ)
end

kern(mat52::MAT52, x::Vector{Float64}, y::Vector{Float64}) = mat52.σ^2*(1+sqrt(5)*norm(x-y)/mat52.l+sqrt(5)*norm(x-y)/(3*mat52.l^2))*exp(-sqrt(5)*norm(x-y)/mat52.l)   
params(mat52::MAT52) = Float64[mat52.l, mat52.σ]

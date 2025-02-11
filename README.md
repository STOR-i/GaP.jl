# GaussianProcesses.jl
[![Build Status](https://travis-ci.org/STOR-i/GaussianProcesses.jl.png)](https://travis-ci.org/STOR-i/GaussianProcesses.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/github/STOR-i/GaussianProcesses.jl?branch=master&svg=true)](https://ci.appveyor.com/project/STOR-i/gaussianprocesses-jl)
[![Coverage Status](https://coveralls.io/repos/github/STOR-i/GaussianProcesses.jl/badge.svg?branch=master)](https://coveralls.io/github/STOR-i/GaussianProcesses.jl?branch=master)
[![codecov](https://codecov.io/gh/STOR-i/GaussianProcesses.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/STOR-i/GaussianProcesses.jl)

[![](https://img.shields.io/badge/docs-stable-blue.svg)](http://STOR-i.github.io/GaussianProcesses.jl/latest)

A Gaussian Processes package for Julia.

If you have any suggestions to improve the package, or if you've noticed a bug, then please post an [issue](https://github.com/STOR-i/GaussianProcesses.jl/issues/new) for us and we'll get to it as quickly as we can. Pull requests are also welcome.


## Citing GaussianProcesses.jl

To cite GaussianProcesses.jl, please reference the [paper](http://statistik-jstat.uibk.ac.at/article/view/v102i01). Sample Bibtex is given below:

```bibtex
@article{fairbrother2022gaussianprocesses,
  title={GaussianProcesses. jl: A Nonparametric Bayes Package for the Julia Language},
  author={Fairbrother, Jamie and Nemeth, Christopher and Rischard, Maxime and Brea, Johanni and Pinder, Thomas},
  journal={Journal of Statistical Software},
  volume={102},
  pages={1--36},
  year={2022}
}
```

## Introduction

Gaussian processes are a family of stochastic processes which provide a flexible nonparametric tool for modelling data. A Gaussian Process places a prior over functions, and can be described as an infinite dimensional generalisation of a multivariate Normal distribution. Moreover, the joint distribution of any finite collection of points is a multivariate Normal. This process can be fully characterised by its mean and covariance functions, where the mean of any point in the process is described by the *mean function* and the covariance between any two observations is specified by the *kernel*. Given a set of observed real-valued points over a space, the Gaussian Process is used to make inference on the values at the remaining points in the space.

For an extensive review of Gaussian Processes there is an excellent book [Gaussian Processes for Machine Learning](http://www.gaussianprocess.org/gpml/chapters/RW.pdf) by Rasmussen and Williams, (2006).

## Installation

GaussianProcesses.jl requires Julia version 0.7 or above. To install GaussianProcesses.jl run the following command inside a Julia session:

```julia
julia> using Pkg
julia> Pkg.add("GaussianProcesses")
```
## Functionality

The package allows the user to fit exact **Gaussian process** models when the observations are Gaussian distributed about the latent function. In the case where the *observations are non-Gaussian*, the posterior distribution of the latent function is intractable. The package allows for Monte Carlo sampling from the posterior.

The main function of the package is `GP`, which fits the Gaussian process
```julia
gp = GP(x, y, mean, kernel)
gp = GP(x, y, mean, kernel, likelihood)
```
for Gaussian and non-Gaussian data respectively.

The package has a number of *mean*, *kernel* and *likelihood* functions available. See the documentation for further details.

### Inference

The parameters of the model can be estimated by maximizing the log-likelihood (where the latent function is integrated out) using the `optimize!` function, or in the case of *non-Gaussian data*, an `mcmc` function is available, utilizing the Hamiltonian Monte Carlo sampler. In addition to a HMC sampler, it is possible to sample from the posterior using an elliptical slice sampler, provided that the data exhibits a Gaussian likelihood. Finally, for fast, yet approximate inference in the case of Poisson data, a variational approximation can be used to infer the model parameters and latent function values.
```julia
optimize!(gp)    # Find parameters which maximize the log-likelihood
mcmc(gp)         # Sample from the GP posterior
ess(gp)          # Sample from the GP posterior using an elliptical slice sampler
vi(gp)           # Create a variational approximation
```
See the [notebooks](https://github.com/STOR-i/GaussianProcesses.jl/tree/master/notebooks) for examples of the functions used in the package.

## Documentation

Documentation is accessible in the Julia REPL in help mode. Help mode can be started by typing '?' at the prompt.

```
julia> ?GP
search: GP GPE GPMC GPBase gperm log1p getpid getproperty MissingException

  GP(x, y, mean::Mean, kernel::Kernel[, logNoise::Float64=-2.0])

  Fit a Gaussian process that is defined by its mean, its kernel, and the
  logarithm logNoise of the standard deviation of its observation noise to a
  set of training points x and y.

  See also: GPE

  ────────────────────────────────────────────────────────────────────────────

  GP(x, y, mean::Mean, kernel::Kernel, lik::Likelihood)

  Fit a Gaussian process that is defined by its mean, its kernel, and its
  likelihood function lik to a set of training points x and y.

  See also: GPA
```

Alternatively, [online documentation](http://stor-i.github.io/GaussianProcesses.jl/latest/index.html) and is under development.

## Notebooks

Sample code is available from the [notebooks](https://github.com/STOR-i/GaussianProcesses.jl/tree/master/notebooks).

## Related packages

[GeoStats](https://github.com/JuliaEarth/GeoStats.jl) - Geostatistics in native Julia, including Kriging estimation, Gaussian processes, and more.

## ScikitLearn

This package also supports the [ScikitLearn](https://github.com/cstjean/ScikitLearn.jl) interface. ScikitLearn provides many tools for machine learning such as hyperparameter tuning and cross-validation. See [here](https://github.com/cstjean/ScikitLearn.jl/blob/master/examples/Gaussian_Processes_Julia.ipynb) for an example of its usage with this package.

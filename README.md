# Scalable Linked Integrated Dynamic Equilibrium Model

| **Documentation**                       | **License**                     |
|:---------------------------------------:|:-------------------------------:|
| [![][docs-stable-img]][docs-stable-url] | [![][license-img]][license-url] |

## Installation

Clone this repo to your local machine.

```
> git clone https://github.com/NREL/SLiDE.git
```

From the SLiDE directory, open Julia using

```
> julia --project
```

Build the SLiDE package from the Pkg REPL. Type `]` to enter the Pkg REPL and run:

```julia
(SLiDE) pkg> build
```

This will generate the `Manifest.toml` file, including the package dependencies. If the directory `SLiDE/data/` does not exist, this will download SLiDE input data.

Precompile the SLiDE package and build the model input data by running:

```julia
julia> using SLiDE
julia> (d, set) = build()
```

Reference [`build()` documentation](https://nrel.github.io/SLiDE/man/build/overview.html#SLiDE.build) for options.


## References
- Thomas F. Rutherford and Andrew Schreiber, "Tools for Open Source, Subnational CGE
    Modeling with an Illustrative Analysis of Carbon Leakage,"
    [*J Global Econ Anal* 4(2): 1-66](https://doi.org/10.21642/JGEA.040201AF).


[license-img]: https://img.shields.io/badge/license-BDS%203--Clause-lightgrey.svg
[license-url]: https://github.com/NREL/SLiDE/blob/master/LICENSE

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://NREL.github.io/SLiDE

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://NREL.github.io/SLiDE
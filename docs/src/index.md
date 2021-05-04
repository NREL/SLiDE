
# SLiDE Documentation

*Intro to SLiDE*

## Getting Started: Installation and First Steps

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
julia> dataset = Dataset( ; eem=true)
julia> d, set = build(dataset)
```

## References
- Thomas F. Rutherford and Andrew Schreiber, "Tools for Open Source, Subnational CGE
    Modeling with an Illustrative Analysis of Carbon Leakage,"
    [*J Global Econ Anal* 4(2): 1-66](https://doi.org/10.21642/JGEA.040201AF).

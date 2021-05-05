# Build

The buildstream process and all of the notation included in the SLiDE documentation here is
meant to replicate the WiNDC buildstream. For more information, please reference:

- Thomas F. Rutherford and Andrew Schreiber, "Tools for Open Source, Subnational CGE
    Modeling with an Illustrative Analysis of Carbon Leakage,"
    [*J Global Econ Anal* 4(2): 1-66](https://doi.org/10.21642/JGEA.040201AF).

## Input

Build stream preferences can be specified using the [`SLiDE.Dataset`](@ref) input type.

- `name::String`: dataset identifier. Data produced by the build stream will be saved in
    the directory `data/<name>`. If no name is specified, `"state_model"` will be used.

The following options can be specified using keyword arguments.
- `overwrite::Bool`. Would you like to overwrite the existing dataset with this name?
    If set to true, the existing directory will be renamed.
- `eem::Bool`. Would you like to build the Energy-Environment Module?
    By default, this is set to `false`.


### Examples

Build model data, using the default name and all default options:

```julia
d, set = build()
```

Build model data, using the default name but enabling the Energy-Environment Module.

```julia
d, set = build( ; eem=true)
```

Build model data, naming the dataset `"slug_trails"` and using all default options:

```julia
d, set = build("slug_trails")
```

Build model data, naming the dataset `"slug_trails"` and overwriting the previous `"slug_trails"` dataset:

```julia
d, set = build("slug_trails"; overwrite=true)
```

## Process

The buildstream is executed using the `build` function.

```@docs
build
SLiDE.build_io
SLiDE.build_eem
```
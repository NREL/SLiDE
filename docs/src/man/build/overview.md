# Build

There are four steps required to build the cleaned input data for use in the model:
1. Partition
2. Calibrate
3. Share
4. Disaggregate

The buildstream process and all of the notation included in the SLiDE documentation here is
meant to replicate the WiNDC buildstream. For more information, please reference:

- Thomas F. Rutherford and Andrew Schreiber, "Tools for Open Source, Subnational CGE
    Modeling with an Illustrative Analysis of Carbon Leakage,"
    [*J Global Econ Anal* 4(2): 1-66](https://doi.org/10.21642/JGEA.040201AF).

```@docs
build
```

### Partition

Divide BEA supply/use data into parameters.

```@docs
partition
```

### Calibrate

```@docs
calibrate_national
```

### Share

Divide data into regional component. This will guide how to break the national data into
regional components by state or county.

```@docs
share
```



### Disaggregate

```@docs
disagg
```
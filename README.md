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

Build the model input data by running:

```julia
> (d, set) = build_data()
```

Where `d` is a dictionary of DataFrames containing the model data and `s` is a dictionary of sets describing region, sector, final demand, etc.
By default, this will save data to a directory in `SLiDE/data/default/build/`:

```
data/default/build/
├── partition/
└── calibrate/
└── share/
└── disagg/
```

If data already exists in this directory, running `build_data()` will read it.

Adding keyword arguments to `build_data()` can customize `build_data()`:
  - `save::String = path/to/file`: Replace `default` in the built data path.
  - `overwrite = false`: If data exists, do not read it. Rebuild the data from scratch.

[license-img]: https://img.shields.io/badge/license-BDS%203--Clause-lightgrey.svg
[license-url]: https://github.com/NREL/SLiDE/blob/master/LICENSE

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://NREL.github.io/SLiDE

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://NREL.github.io/SLiDE
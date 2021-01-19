# Scalable Linked Integrated Dynamic Equilibrium Model

## Installation

Clone this repo to your local machine.

```
% git clone https://github.com/NREL/SLiDE.git
```

From the SLiDE directory, open Julia using

```julia
>julia --project
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

Where `d` is a dictionary of DataFrames containing the model data and `set` is a dictionary of sets describing region, sector, final demand, etc.
By default, this will save data to a directory in `SLiDE/data/<date>/build/`, where `<date>` is the date on which the data is built.
If data already exists in this directory, running `build_data()` will read it.

Adding keyword arguments to `build_data()` can customize `build_data()`:
  - `save::String = path/to/file`: Replace `<date>` in the built data path.
  - `overwrite = false`: If data exists, do not read it. Rebuild the data from scratch.

## License
NREL/SLiDE is licensed under the BSD 3-Clause "New" or "Revised" [License](https://github.com/NREL/SLiDE/blob/master/LICENSE)


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

Build the model input data by running:

```julia
> (d, set) = build_data()
```
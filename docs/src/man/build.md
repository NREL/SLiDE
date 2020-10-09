# Build

There are four steps required to build the cleaned input data for use in the model:
1. Partition
2. Calibrate
3. Share
4. Disaggregate

```@docs
build_data
```

# Partition

Divide BEA supply/use data into parameters.

```@docs
partition!
```

# Calibrate

```@docs
calibrate
```

# Share

Divide data into regional component. This will guide how to break the national data into regional components by state or county.

```@docs
share!
```

# Disaggregate

```@docs
disagg!
```
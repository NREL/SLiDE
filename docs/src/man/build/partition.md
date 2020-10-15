# Partition

The first step in the build stream involves partitioning BEA supply and use data, by
filtering this data based on sectors and goods. Generally, BEA input (`i`) maps to goods
(`g`), and BEA output (`j`) maps to sectors (`s`).

```@docs
SLiDE._partition_io!
```

## Use

```@docs
SLiDE._partition_ts0!
SLiDE._partition_va0!
SLiDE._partition_x0!
SLiDE._partition_fd0!
SLiDE._partition_fs0!
```

### Calculate aggregates

```@docs
SLiDE._partition_s0!
SLiDE._partition_a0!
```

## Supply

### Make insurance adjustments.

```@docs
SLiDE._partition_cif0!
SLiDE._partition_m0!
SLiDE._partition_trn0!
```

### Calculate margin supply and demand.

```@docs
SLiDE._partition_mrg0!
SLiDE._partition_md0!
SLiDE._partition_ms0!
```

```@docs
SLiDE._partition_y0!
```

### Calculate import tariffs.

```@docs
SLiDE._partition_tax0!
SLiDE._partition_sbd0!
SLiDE._partition_ta0!
```

### Calculate tax rate on intermediate demand.

```@docs
SLiDE._partition_duty0!
SLiDE._partition_tm0!
```

```@docs
SLiDE._partition_bop!
```
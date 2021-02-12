# Sectoral Scaling

The build stream produces state-level (regionally) model parameters at the summary-level (sectorally).
By default, there are 73 summary-level goods/sectors.
These can be disaggregated into 409 detail-level goods/sectors
using the [blueNOTE sectoral scaling map](https://github.com/NREL/SLiDEData/blob/master/coremaps/scale/sector/bluenote.csv).

Scaling features enable the following options:
1. Select a subset of summary-level or detail-level goods/sectors to examine.
2. Select a combination of summary- and detail-level goods/sectors.
3. Aggregate summary- and/or detail-level goods/sectors into those specified in a user-defined map.

## Share

```@docs
share_sector!
SLiDE.share_sector
SLiDE._combine_sector_levels
```

## Disaggregate

```@docs
disagg_sector!
SLiDE._disagg_sector_share
SLiDE._compound_for
SLiDE._disagg_sector_map
```

## Aggregate

```@docs
aggregate_sector!
SLiDE._aggregate_tax_with!
SLiDE._aggregate_sector_map
```
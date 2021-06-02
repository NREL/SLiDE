# Scaling

The build stream produces state-level (regionally) model parameters at the summary-level (sectorally).

## Regional Scaling

### Aggregation

By default, the SLiDE build stream produces regional data at the state level.
However, setting `region_level` enables regional aggregation to the region- or division-level, using the [regional scaling map](https://github.com/NREL/SLiDEData/blob/master/coremaps/scale/region/region.csv).

BEA and Census Bureau used to produce shares via [`SLiDE.share_region`](@ref) and applied
via [`SLiDE.disaggregate_region`](@ref) is aggregated to the desired level immediately upon being
read into the build stream.

### Disaggregation
*Regional disaggregation will be tackeled during future development phases*
Source data is regional-specific and available for a variety of regional divisions: state, CBSA, CSA.

| Source | Data         | Region | State | County | CSA | CBSA |
|:-------|:-------------|:-------|:------|:-------|:----|:-----|
| BEA    |   Supply/Use | N/A    | N/A   | N/A    | N/A | N/A  |
|        |   GSP        | ✅      | ✅     | ✅      | ❌   | ✅    |
|        |   PCE        | ✅      | ✅     | ❌      | ❌   | ❌    |
| Census |   CFS        | ❌      | ✅     | ❌      | ✅   | ✅    |
|        |   SGF        |        |       |        |     |      |
|        |   UTD        |        |       |        |     |      |
|        |   NASS       | ❌      | ✅     | ❌      | ❌   | ❌    |
|        |              |        |       |        |     |      |
|        |              |        |       |        |     |      |

The regional level identifiers used are consistent with those from the [2010 Census Summary File 1](https://usa.ipums.org/usa/resources/voliii/pubdocs/2010/Technical%20Documentation/sf1.pdf).
Codes listed in the [Census Delineation Files](https://www.census.gov/geographies/reference-files/time-series/demo/metro-micro/delineation-files.html) are used to identify regions.

## Sectoral Scaling

By default, there are 73 summary-level goods/sectors.
These can be disaggregated into 409 detail-level goods/sectors
using the [blueNOTE sectoral scaling map](https://github.com/NREL/SLiDEData/blob/master/coremaps/scale/sector/bluenote.csv).

Scaling features enable the following options:
1. Select a subset of summary-level or detail-level goods/sectors to examine.
1. Select a combination of summary- and detail-level goods/sectors.
1. Aggregate summary- and/or detail-level goods/sectors into those specified in a user-defined map.

```@docs
SLiDE.scale_sector
```

### Aggregation

```@docs
SLiDE.aggregate_sector!
SLiDE.aggregate_tax_with!
```

### Disaggregation

```@docs
SLiDE.disaggregate_sector!
```
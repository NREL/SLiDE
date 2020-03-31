# Scaling

## Regional Scaling

Source data is regional-specific and available for a variety of regional divisions: state, CBSA, CSA

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

### BEA



### NAICS

The [NAICS Codes](https://www.census.gov/programs-surveys/economic-census/guidance/understanding-naics.html) are structured into the following levels, indicated by the number of digits in the code:

| Digits | Level             |
|--------|:------------------|
| 2      | Sector            |
| 3      | Subsector         |
| 4      | Industry Group    |
| 5      | NAICS Industry    |
| 6      | National Industry |
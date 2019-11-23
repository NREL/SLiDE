# Data

The data necessary to execute the SLiDE datastream is stored in the following structure:

```
data/
├── core_maps/
└── datasources/
└── readfiles/
```

**`core_maps`** contains .csv files that standardize DataFrame values for consistency. For example, `regions.csv` maps `CO, Colo., Colorado, COLORADO, colorado -> co`. Many files are from the WiNDC Data Stream, but some have been edited for simplicity.

**`datasources`** stores the original input data.
This must be downloaded from the WiNDC Data Stream [datasources.zip](https://windc.wisc.edu/datasources.zip) file. This includes:
* Bureau of Economic Analysis
    * Supply and Use Tables ([BEA](https://www.bea.gov/industry/io_annual.htm))
    * Gross State Product ([GSP](https://www.bea.gov/newsreleases/regional/gdp_state/qgsp_newsrelease.htm))
    * Personal Consumer Expenditures ([PCE](https://www.bea.gov/newsreleases/regional/pce/pce_newsrelease.htm))
* Census Bureau
    * Commodity Flow Survey ([CFS](https://www.census.gov/econ/cfs/))
    * State Government Finance ([SGF](https://www.census.gov/programs-surveys/state/data/tables.All.html))
    * State Exports/Imports ([UTD](https://usatrade.census.gov))
* Energy Information Administration
    * State Energy Data System ([SEDS](https://www.eia.gov/state/seds))

**`readfiles`** contains a file for each output file produced by the datastream.
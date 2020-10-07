# Parameters

## BEA Supply/Use

| Parameter | Variables   | Description                                   |
|:----------|:------------|:----------------------------------------------|
| `id0`     | `(yr,i,j)`  | *Intermediate demand*                         |
| `fd0`     | `(yr,i,fd)` | *Final demand*                                |
| `va0`     | `(yr,va,j)` | *Value added*                                 |
| `ts0`     | `(yr,ts,j)` | *Taxes and subsidies*                         |
| `x0`      | `(yr,i)`    | *Exports of goods and services*               |
| `ys0`     | `(yr,i,j)`  | *Sectoral supply*                             |
| `m0`      | `(yr,i)`    | *Imports*                                     |
| `mrg0`    | `(yr,i)`    | *Trade margins*                               |
| `trn0`    | `(yr,i)`    | *Transportation costs*                        |
| `cif0`    | `(yr,i)`    | *CIF/FOB Adjustments on Imports*              |
| `duty0`   | `(yr,i)`    | *Import duties*                               |
| `tax0`    | `(yr,i)`    | *Taxes on products*                           |
| `sbd0`    | `(yr,i)`    | *Subsidies on products*                       |
| `s0`      | `(yr,j)`    | *Aggregate supply*                            |
| `y0`      | `(yr,i)`    | *Gross output*                                |
| `bopdef0` | `(yr)`      | *Balance of payments deficit*                 |
| `ms0`     | `(yr,i,m)`  | *Margin supply*                               |
| `md0`     | `(yr,m,i)`  | *Margin demand*                               |
| `fs0`     | `(yr,i,fd)` | *Household supply*                            |
| `a0`      | `(yr,i)`    | *Armington supply*                            |
| `tm0`     | `(yr,i)`    | *Tax net subsidy rate on intermediate demand* |
| `ta0`     | `(yr,i)`    | *Import tariff*                               |
| `lshr0`   | `(yr,g)`    | *Labor share of value added*                  |


## Sharing

| Parameter     | Variables    | Description                                        |
|:--------------|:-------------|:---------------------------------------------------|
| `pce`         | `(yr,r,g)`   | *Regional shares of final consumption*             |
| `utd`         | `(yr,r,s,t)` | *Share of total trade by region*                   |
| `gsp`         | `(yr,r,s)`   | *Annual gross state product*                       |
| `region`      | `(yr,r,s)`   | *Regional shares of value added*                   |
| `labor`       | `(yr,r,s)`   | *Share of regional value added due to labor*       |
| `rpc`         | `(r,g)`      | *Regional purchase coefficient*                    |

Intermediate values

| Parameter     | Variables    | Description                                        |
|:--------------|:-------------|:---------------------------------------------------|
| `netval`      | `(yr,r,s)`   | *Net value added (compensation + surplus)*         |
| `seclaborshr` | `(yr,s)`     | *Sector level average labor shares*                |
| `avgwgshr`    | `(r,s)`      | *Average wage share*                               |
| `d0`          | `(r,g)`      | *Local supply-demand*                              |
| `mrt0`        | `(r,r,g)`    | *Interstate trade*                                 |
| `xn0`         | `(r,g)`      | *National exports*                                 |
| `mn0`         | `(r,g)`      | *National demand*                                  |
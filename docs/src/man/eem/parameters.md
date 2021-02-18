# Energy Parameters

## convfac
```math
\tilde{convfac}_{yr,r} \text{ [million btu/barrel]}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, src=cru,\, sec=supply
\right\}
```

## cprice

```math
\tilde{cprice}_{yr,r} \text{ [usd/million btu]}
=
\dfrac{\bar{crude oil}_{yr} \text{ [usd/barrel]}}
        {\tilde{convfac}_{yr,r} \text{ [million btu/barrel]}}
```

## prodbtu
```math
\tilde{prodbtu}_{yr,r} \text{ [trillion btu]}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, as\in src,\, sec=supply
\right\}
```

## pedef

This parameter can be calculated from prices ``\tilde{p}_{yr,r,src,sec}`` and quantities 
``\tilde{q}_{yr,r,src,sec}`` for the following (``src``,``sec``).

```math
\left(\tilde{p}, \tilde{q}\right)_{yr,r,src,sec}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, (ff,ele)\in src,\, demsec\in sec
\right\}
```

Average energy demand price ``\tilde{pedef}_{yr,r,src}`` and its regional average
``\hat{pedef}_{yr,src}`` are calculated as follows:

```math
\begin{aligned}
\tilde{pedef}_{yr,r,src}
&=
\dfrac{\sum_{sec} \left( \tilde{p}_{yr,r,src,sec} \cdot \tilde{q}_{yr,r,src,sec} \right)}
      {\sum_{sec} \tilde{q}_{yr,r,src,sec}}
\\
\hat{pedef}_{yr,src}
&=
\dfrac{\sum_{r} \left( \tilde{pedef}_{yr,r,src} \cdot \sum_{sec} \tilde{q}_{yr,r,src,sec} \right)}
      {\sum_{r} \sum_{sec} \tilde{q}_{yr,r,src,sec}}
\end{aligned}
```

## pe0

## ps0

## prodval

## shrgas



# Electricity Parameters

## elegen

## netgen

## trdele
```math
\tilde{trdele}_{yr,r,t} \text{ [billion usd]}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, src=ele,\, [imports,exports]\in sec
\right\}
```

## pctgen

## eq0
```math
\tilde{eq}_{yr,r,src,sec}
= \left\{
    energy \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, e\in src,\, demsec\in sec
\right\}
```

## ed0
```math
\tilde{ed}_{yr,r,src,sec} = \dfrac
    {\tilde{pe}_{yr,r,src,sec}}
    {\tilde{eq}_{yr,r,src,sec}}
```

## emarg0
```math
\tilde{emarg}_{yr,r,src,sec} = \dfrac
    {\tilde{pe}_{yr,r,src,sec} - \tilde{ps}_{yr,src}}
    {\tilde{eq}_{yr,r,src,sec}}
```

## ned0
```math
\tilde{ned}_{yr,r,src,sec} = \tilde{ed}_{yr,r,src,sec} - \tilde{emarg}_{yr,r,src,sec}
```

# Emissions
## btus
## co2emiss
## usatotalco2
## resco2
## secco2
## nomatch

# Parameters


## mrgshr
```math
\begin{aligned}
mrgshr_{yr,r,m,g=trn} &= \dfrac
    {md_{yr,r,m,g=trn}}
    {\sum_m md_{yr,r,m,g=trn}}
mrgshr_{yr,r,m,g=trd} &= 1 - mrgshr_{yr,r,m,g=trn}
\end{aligned}
```

## md0
```math
md_{yr,r,m,g} = mrgshr_{yr,r,m,g} \cdot \sum_{sec} emrg_{yr,r,src\rightarrow g, sec}
```

## cd0
```math
\tilde{cd}_{yr,r,g}
= \left\{
    ed \left(yr,r,src\rightarrow g, sec\right) \;\vert\; yr,\, r,\, g,\, sec=res
\right\}
```
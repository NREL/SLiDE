# Energy Parameters

## convfac
```math
k_{yr,r,src} \text{ [million btu/barrel]}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, src=cru,\, sec=supply
\right\}
```

## cprice

```math
p_{yr,r,src} \text{ [usd/million btu]}
=
\dfrac{\overline{crude oil}_{yr} \text{ [usd/barrel]}}
        {k_{yr,r,src} \text{ [million btu/barrel]}}
```

## prodbtu
```math
q_{yr,r,src} \text{ [trillion btu]}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, as\in src,\, sec=supply
\right\}
```

## pedef

This parameter can be calculated from prices ``p_{yr,r,src,sec}`` and quantities 
``q_{yr,r,src,sec}`` for the following (``src``,``sec``).

```math
\left(p, q\right)_{yr,r,src,sec}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, (ff,ele)\in src,\, demsec\in sec
\right\}
```

Average energy demand price ``p_{yr,r,src}`` and its regional average
``p_{yr,src}`` are calculated as follows:

```math
\begin{aligned}
\bar{p}_{yr,r,src}
&=
\dfrac{\sum_{sec} \left( p_{yr,r,src,sec} \cdot q_{yr,r,src,sec} \right)}
      {\sum_{sec} q_{yr,r,src,sec}}
\\
\bar{p}_{yr,src}
&=
\dfrac{\sum_{r} \left( \bar{p}_{yr,r,src} \cdot \sum_{sec} q_{yr,r,src,sec} \right)}
      {\sum_{r} \sum_{sec} q_{yr,r,src,sec}}
\\&\\
\bar{p}_{yr,r,src} &=
\begin{cases}
\bar{p}_{yr,r,src} & \sum_{sec} q_{yr,r,src,sec} \neq 0
\\
\bar{p}_{yr,src}   & \sum_{sec} q_{yr,r,src,sec} = 0
\end{cases}
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
trdele_{yr,r,t} \text{ [billion usd]}
= \left\{
    seds \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, src=ele,\, [imports,exports]\in sec
\right\}
```

## pctgen

## eq0
```math
eq_{yr,r,src,sec}
= \left\{
    energy \left( yr, r, src, sec \right) \;\vert\; yr,\, r,\, e\in src,\, demsec\in sec
\right\}
```

## ed0
```math
ed_{yr,r,src,sec} = \dfrac
    {pe_{yr,r,src,sec}}
    {eq_{yr,r,src,sec}}
```

## emarg0
```math
emarg_{yr,r,src,sec} = \dfrac
    {pe_{yr,r,src,sec} - ps_{yr,src}}
    {eq_{yr,r,src,sec}}
```

## ned0
```math
ned_{yr,r,src,sec} = ed_{yr,r,src,sec} - emarg_{yr,r,src,sec}
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
\\
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

## m0
```math
\tilde{m}_{yr,r,g=ele}
= \left\{
    trdele \left(yr,r,t\right) \;\vert\; yr,\, r,\, t=imports
\right\}
```

## x0
```math
\tilde{x}_{yr,r,g=ele}
= \left\{
    trdele \left(yr,r,t\right) \;\vert\; yr,\, r,\, t=exports
\right\}
```

## ys0


## inpshr
```math
\begin{aligned}
inp_{yr,r,g,s,sec} &= 
\big\{
    id_{yr,r,g,s} \circ map_{s\rightarrow sec} \;\vert\; yr,\, r,\, src\in g,\, s
    \\&\qquad\wedge\; pctgen_{yr,r,src\rightarrow g,sec} > 0.01
\big\}
\\&\\
\alpha^{inp}_{yr,r,g,s,sec} &= \dfrac
    {inp_{yr,r,g,s,sec}}
    {\sum_s inp_{yr,r,g,s,sec}}
\end{aligned}
```

```math
\begin{aligned}
inp_{yr,r,g,s,sec} &= 
\big\{
    inp_{yr,r,g,s,sec} \;\vert\; yr,\, r,\, src\in g,\, s,\, sec
    \\&\qquad\wedge\; ed_{yr,r,src\rightarrow g,sec} > 0
    \\&\qquad\wedge\; ys_{yr,r,s,g=s} > 0
\big\}
\\&\\
\hat{\alpha}^{inp}_{yr,r,g,s,sec} &= \dfrac
    {\sum_r inp_{yr,r,g,s,sec}}
    {\sum_{r,s} inp_{yr,r,g,s,sec}}
\end{aligned}
```

```math
\alpha^{inp}_{yr,r,g,s,sec} =
\begin{cases}
\alpha^{inp}_{yr,r,g,s,sec} & \sum_s inp_{yr,r,g,s,sec} \neq 0
\\
\hat{\alpha}^{inp}_{yr,r,g,s,sec} & \sum_s inp_{yr,r,g,s,sec} = 0
\end{cases}
```

## id0

```math
id_{yr,r,g,s} =
\begin{cases}
\sum_{sec} \left\( ed_{yr,r,src\rightarrow g, sec} \cdot \alpha^{inp}_{yr,r,g,s,sec} \right\)
& e \in g
\\
id_{yr,r,g,s} & e\ni g
\end{cases}
```
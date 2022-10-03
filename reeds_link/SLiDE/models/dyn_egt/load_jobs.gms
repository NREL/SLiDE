$stitle load in jobs data for postprocessing and/or calibration

* !!!! bring the preprocessing into the repo
* !!!! mostly hardcoded - quickly hacked in here

parameter avg_wages	average us wages across all industries (BEA);

* * USD/yr
* avg_wages = 60872;

* *scale to USD billions/yr
* avg_wages = avg_wages*1e-9;


* parameters
* 	fte_wage(*)	US FTE wages from external source by industry
* 	fte_jobs(*)	US FTE jobs from external source by industry
* 	rpp(*)			Regional price parities by state
* ;

* set s_map_bea(*,*)	mapping between bea and slide sectors;
* set r_map_bea(*,*) 	mapping between bea and slide states;

* Load in data and map to slide set elements
* rescale fte_wage by rpp to get state scaled wages

parameter	fte_wage(s)	fte wages
/	
gas 168544
col 78150
con 63439
cru 168544
eint 77004
ele 110850
oil 115123
omnf 82736
osrv 60644
roe 57915
trn 60939
/
; 

* convert to usd billions
fte_wage(s) = fte_wage(s)*1e-9;


$if %rmap%=="census"	$goto	mapcensus

parameter   rpp(r)  regional price parities by state	/
AL	90.296
AK	106.041
AZ	98.072
AR	89.108
CA	109.765
CO	102.695
CT	106.33
DE	98.399
DC	109.386
FL	101.291
GA	95.606
HI	110.03
ID	94.908
IL	100.488
IN	91.559
IA	89.516
KS	92.094
KY	90.211
LA	93.476
ME	96.547
MD	106.662
MA	106.209
MI	92.546
MN	96.643
MS	88.134
MO	92.466
MT	95.501
NE	90.838
NV	100.221
NH	104.205
NJ	109.23
NM	95.598
NY	109.755
NC	93.681
ND	90.005
OH	91.983
OK	91.662
OR	101.032
PA	98.982
RI	100.932
SC	93.512
SD	88.701
TN	93.544
TX	97.88
UT	98.853
VT	100.638
VA	101.362
WA	107.048
WV	89.066
WI	93.222
WY	97.468
/
;

$goto skipmapcensus
$label mapcensus

parameter rpp(r)	regional price multiplier;
rpp(r)=100;

$label skipmapcensus

* rescale wages by regional cost of living multiplier
avg_wages(r,s) = fte_wage(s) * rpp(r)/100;

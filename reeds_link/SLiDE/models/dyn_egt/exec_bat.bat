@echo off

if not exist lst mkdir lst
if not exist g00files mkdir g00files
if not exist gdx mkdir gdx
if not exist bases mkdir bases
if exist lst del lst\*.lst
if exist log.txt del log.txt

if exist set_t.inc del set_t.inc

set gams_call=gams
set gams_lic=""

set bmkyr=2017
set endyr=2050
set tintval=1

set /a nper=%endyr%-%bmkyr%
set nperdup=%nper%

set /a remainder=%nperdup% %% %tintval%
if %remainder% equ 0 goto endtintloop
:tintloop
set /a nperdup-=1
set /a remainder=%nperdup% %% %tintval%
if %remainder% gtr 0 (goto tintloop) else (goto endtintloop)
:endtintloop

set /a yrintstart = %endyr%-%nperdup%
echo the first period where remainder is integer is when nper=%nperdup%
echo this corresponds to the year %yrintstart%

set firstyr=%yrintstart%
if %bmkyr% equ %firstyr% (set /a firstyr=%bmkyr%+%tintval%)
set /a tintfirst=%firstyr%-%bmkyr%

echo set t(yr) solve year / >> set_t.inc
echo %bmkyr%, >> set_t.inc
if %firstyr% gtr %bmkyr% (echo %firstyr%, >> set_t.inc)

set /a nextyr = %firstyr%+%tintval%

:writetloop
if %nextyr% lss %endyr% (echo %nextyr%, >> set_t.inc)
if %nextyr% equ %endyr% (echo %nextyr% >> set_t.inc)
if %nextyr% equ %endyr% goto endwritetloop
set /a nextyr = %nextyr% + %tintval%
goto writetloop
:endwritetloop

echo /; >> set_t.inc

rem goto :end

set curyr=%bmkyr%
rem set curyr=2050

if %curyr% lss %bmkyr%  echo "current year earlier than benchmark year" goto end
if %endyr% lss %bmkyr%  echo "end year earlier than benchmark year"     goto end

rem set scn=BAU_pin
rem set bauscn=not_specified
rem set rmap=state
rem set etaval=0.02
rem set swcarbval=0
rem set swbtval=1
rem set thetaxval=0.3
rem set thetaxegtval=0.7
rem set swsspinval=0
rem set swloadval=0
rem set swloaditval=0
rem set switerpinval=1
rem set iternum=30
rem set adjstepval=0.001
rem set swsubegtval=0
rem set swdecarbval=0
rem set decarbval=0.90
rem set capyrval=2023
rem set ssctaxele=0
rem set lsusval=0
rem set capendyrval=2050
rem set aeeirateval=0.0
rem set swperfval=0
rem set swctaxval=0
rem set subexodep=0
rem set swelbsval=0
rem set jpowval=0
rem set swvdeprval=1
rem set swvextval=1
rem set swhhextval=0
rem set swrksval=0

rem set scn=BAU_rep
rem set bauscn=BAU_pin
rem set rmap=state
rem set etaval=0.02
rem set swcarbval=0
rem set swbtval=1
rem set thetaxval=0.3
rem set thetaxegtval=0.7
rem set swsspinval=0
rem set swloadval=0
rem set swloaditval=1
rem set switerpinval=0
rem set iternum=30
rem set adjstepval=0.001
rem set swsubegtval=0
rem set swdecarbval=0
rem set decarbval=0.90
rem set capyrval=2023
rem set ssctaxele=0
rem set lsusval=0
rem set capendyrval=2050
rem set aeeirateval=0.0
rem set swperfval=0
rem set swctaxval=0
rem set subexodep=0
rem set swelbsval=0
rem set swvdeprval=1
rem set swvextval=1
rem set swhhextval=0
rem set swrksval=0

rem set scn=CAP_EW
rem set bauscn=BAU_rep
rem set rmap=state
rem set etaval=0.02
rem set swcarbval=0
rem set swbtval=1
rem set thetaxval=0.3
rem set thetaxegtval=0.7
rem set swsspinval=0
rem set swloadval=0
rem set swloaditval=1
rem set switerpinval=0
rem set iternum=30
rem set adjstepval=0.001
rem set swsubegtval=0
rem set swdecarbval=1
rem set decarbval=0.80
rem set capyrval=2023
rem set ssctaxele=0
rem set lsusval=1
rem set capendyrval=2050
rem set aeeirateval=0.0
rem set swperfval=0
rem set swctaxval=0
rem set subexodep=0
rem set swelbsval=1
rem set swvdeprval=1
rem set swvextval=1
rem set swhhextval=0
rem set swrksval=1

set scn=BAU
set bauscn=not_specified
set rmap=census
set etaval=0.02
set swcarbval=0
set swbtval=1
set thetaxval=0.3
set thetaxegtval=0.7
set swsspinval=0
set swloadval=0
set swloaditval=0
set switerpinval=0
set iternum=30
set adjstepval=0.001
set swsubegtval=0
set swdecarbval=0
set decarbval=0.80
set capyrval=2023
set ssctaxele=0
set lsusval=0
set capendyrval=2050
set aeeirateval=0.0
set swperfval=0
set swctaxval=0
set subexodep=0
set swelbsval=0
set jpowval=0
set swvdeprval=0
set swvextval=0
set swhhextval=0
set swrksval=1
set swegtval=0

rem set scn=CAP_ew_putty
rem set bauscn=not_specified
rem set rmap=census
rem set etaval=0.02
rem set swcarbval=0
rem set swbtval=1
rem set thetaxval=0
rem set thetaxegtval=0
rem set swsspinval=0
rem set swloadval=0
rem set swloaditval=0
rem set switerpinval=0
rem set iternum=30
rem set adjstepval=0.001
rem set swsubegtval=0
rem set swdecarbval=1
rem set decarbval=0.80
rem set capyrval=2023
rem set ssctaxele=0
rem set lsusval=1
rem set capendyrval=2050
rem set aeeirateval=0.0
rem set swperfval=0
rem set swctaxval=0
rem set subexodep=0
rem set swelbsval=1
rem set jpowval=0
rem set swvdeprval=0
rem set swvextval=0
rem set swhhextval=0
rem set swrksval=0
rem set swegtval=1

rem set scn=CAP_ele
rem set bauscn=not_specified
rem set rmap=census
rem set etaval=0.02
rem set swcarbval=0
rem set swbtval=1
rem set thetaxval=0.3
rem set thetaxegtval=0.7
rem set swsspinval=0
rem set swloadval=0
rem set swloaditval=0
rem set switerpinval=0
rem set iternum=30
rem set adjstepval=0.001
rem set swsubegtval=0
rem set swdecarbval=1
rem set decarbval=0.80
rem set capyrval=2023
rem set ssctaxele=1
rem set lsusval=1
rem set capendyrval=2050
rem set aeeirateval=0.0
rem set swperfval=0
rem set swctaxval=0
rem set subexodep=0
rem set swelbsval=1
rem set jpowval=0
rem set swvdeprval=0
rem set swvextval=0
rem set swhhextval=0
rem set swrksval=1
rem set swegtval=0

:SLiDE

if %curyr% equ %bmkyr% (set loadyr=%curyr%) else (set /a loadyr=%curyr%-%tintval%)
if %curyr% equ %firstyr% set loadyr=%bmkyr%
if %curyr% equ %bmkyr% (set loadfile=loop_%scn%_%rmap%_%loadyr%) else (set loadfile=loop_%scn%_%rmap%_%loadyr%)

TITLE Running %curyr%

if %curyr% gtr %bmkyr% goto loop

call %gams_call% exec_core.gms --scn=%scn% --rmap=%rmap% --bmkyr=%bmkyr% --endyr=%endyr% --tintval=%tintval% --tintfirst=%tintfirst% --etaval=%etaval% --swcarbval=%swcarbval% --swbtval=%swbtval% --thetaxval=%thetaxval% --thetaxegtval=%thetaxegtval% --swsspinval=%swsspinval% --swloadval=%swloadval% --swloaditval=%swloaditval% --bauscn=%bauscn% --switerpinval=%switerpinval% --iternum=%iternum% --adjstepval=%adjstepval% --swsubegtval=%swsubegtval% --solveyr=%curyr% --swdecarbval=%swdecarbval% --decarbval=%decarbval% --capyrval=%capyrval% --ssctaxele=%ssctaxele% --lsusval=%lsusval% --capendyrval=%capendyrval% --aeeirateval=%aeeirateval% --swperfval=%swperfval% --swctaxval=%swctaxval% --subexodep=%subexodep% --swelbsval=%swelbsval% --jpowval=%jpowval% --swvdeprval=%swvdeprval% --swvextval=%swvextval% --swhhextval=%swhhextval% --swrksval=%swrksval% --swegtval=%swegtval% s=g00files\loop_%scn%_%rmap%_%curyr%.g00 o=lst\loop_%scn%_%rmap%_%curyr%.lst sysout=1 license=%gams_lic%

rem goto end
goto endslide

:loop

if not exist g00files\%loadfile%.g00 goto end

call %gams_call% exec_loop.gms --scn=%scn% --rmap=%rmap% --bmkyr=%bmkyr% --endyr=%endyr% --etaval=%etaval% --swcarbval=%swcarbval% --swbtval=%swbtval% --thetaxval=%thetaxval% --thetaxegtval=%thetaxegtval% --swsspinval=%swsspinval% --swloadval=%swloadval% --swloaditval=%swloaditval% --bauscn=%bauscn% --switerpinval=%switerpinval% --iternum=%iternum% --adjstepval=%adjstepval% --swsubegtval=%swsubegtval% --solveyr=%curyr% --swdecarbval=%swdecarbval% --decarbval=%decarbval% --capyrval=%capyrval% --ssctaxele=%ssctaxele% --lsusval=%lsusval% --capendyrval=%capendyrval% --aeeirateval=%aeeirateval% --swperfval=%swperfval% --swctaxval=%swctaxval% --subexodep=%subexodep% --swelbsval=%swelbsval% --jpowval=%jpowval% --swvdeprval=%swvdeprval% --swvextval=%swvextval% --swhhextval=%swhhextval% --swrksval=%swrksval% --swegtval=%swegtval% r=g00files\%loadfile%.g00 s=g00files\loop_%scn%_%rmap%_%curyr%.g00 o=lst\loop_%scn%_%rmap%_%curyr%.lst sysout=1 license=%gams_lic%

:endslide

if %curyr% gtr %bmkyr% set /a curyr=%curyr%+%tintval%
if %curyr% equ %bmkyr% set curyr=%firstyr%
if %curyr% leq %endyr% goto SLiDE
if %curyr% gtr %endyr% set curyr=%bmkyr%
goto end

:end
TITLE DONE

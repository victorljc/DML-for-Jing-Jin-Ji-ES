*******************************************************************************
* Environmental regulation and urban energy security
* DML-DID estimation, robustness, endogeneity, and mechanisms
*
* NPJ-style output: exact two-sided P values, no significance stars
*
* Requirements : ddml, pystacked (Python/scikit-learn), winsor2, didplacebo
* Reproducibility: pystacked uses randomised learners; seeds are fixed per
*                  specification and MUST be preserved to reproduce the
*                  reported estimates. Do not change kfolds, learner, or seed.
*******************************************************************************

version 17
clear all
set more off

*------------------------------------------------------------------------------
* Paths and globals
*------------------------------------------------------------------------------
* Set to your dataset filename (renamed to an ASCII name recommended).
global DATA    "analysis_sample.dta"

* Baseline control set reused throughout.
global controls "education people ngdp open c3 finance c5"

*------------------------------------------------------------------------------
* ddml helper: one call = one DML-partial specification with a unique model
* name, so multiple models coexist in memory without reloading the data.
*   usage: ddml_fit  mname  yvar  dvar  seed  kfolds  method
* Reads the covariate list from the global $X set by the caller.
*------------------------------------------------------------------------------
capture program drop ddml_fit
program define ddml_fit
    args mname yvar dvar seed kfolds method
    ddml init partial, kfolds(`kfolds') mname(`mname')
    ddml E[Y|X], mname(`mname'): pystacked `yvar' $X, type(reg) method(`method')
    ddml E[D|X], mname(`mname'): pystacked `dvar' $X, type(reg) method(`method')
    set seed `seed'
    ddml crossfit, mname(`mname')
    ddml estimate, mname(`mname') robust
end

*------------------------------------------------------------------------------
* Load once and harmonise variable names.
* This is the ONLY block that references the original (non-ASCII) names;
* delete it if the variables are already renamed in the .dta.
*------------------------------------------------------------------------------
use "$DATA", clear
xtset id year

capture rename 供暖              heating
capture rename smart_city        smart_city
capture rename carbon_trading    carbon_trading
capture rename 地势起伏度_time    terrain_trend
capture rename 气温_time          temp_trend
capture rename yali              pressure
capture rename index3            index_pca


*==============================================================================
* Table 1. Effect of the Action Plan on overall urban energy security
*==============================================================================
eststo clear

* (1) Two-way FE only, no controls
global X i.year i.id
ddml_fit a1 index did 42 3 rf
estadd local Controls "No"  : estadd local Quadratic "No"
estadd local CityFE   "Yes" : estadd local YearFE    "Yes"
estadd local Kfolds   "3"   : estadd local Learner   "Random forest"
eststo a1

* (2) Controls only, no FE
global X $controls
ddml_fit a2 index did 42 3 rf
estadd local Controls "Yes" : estadd local Quadratic "No"
estadd local CityFE   "No"  : estadd local YearFE    "No"
estadd local Kfolds   "3"   : estadd local Learner   "Random forest"
eststo a2

* (3) Controls + two-way FE
global X $controls i.year i.id
ddml_fit a3 index did 42 3 rf
estadd local Controls "Yes" : estadd local Quadratic "No"
estadd local CityFE   "Yes" : estadd local YearFE    "Yes"
estadd local Kfolds   "3"   : estadd local Learner   "Random forest"
eststo a3

* Quadratic control terms (generated once, reused by models 4-6)
foreach v in $controls {
    capture drop `v'2
    gen double `v'2 = `v'^2
}
global controls2 education2 people2 ngdp2 open2 c32 finance2 c52

* (4) Controls + quadratics + FE, k = 3
global X $controls $controls2 i.year i.id
ddml_fit a4 index did 42 3 rf
estadd local Controls "Yes" : estadd local Quadratic "Yes"
estadd local CityFE   "Yes" : estadd local YearFE    "Yes"
estadd local Kfolds   "3"   : estadd local Learner   "Random forest"
eststo a4

* (5) Same specification, k = 5
ddml_fit a5 index did 42 5 rf
estadd local Controls "Yes" : estadd local Quadratic "Yes"
estadd local CityFE   "Yes" : estadd local YearFE    "Yes"
estadd local Kfolds   "5"   : estadd local Learner   "Random forest"
eststo a5

* (6) Same specification, k = 7
ddml_fit a6 index did 42 7 rf
estadd local Controls "Yes" : estadd local Quadratic "Yes"
estadd local CityFE   "Yes" : estadd local YearFE    "Yes"
estadd local Kfolds   "7"   : estadd local Learner   "Random forest"
eststo a6

esttab a1 a2 a3 a4 a5 a6 using "Table_Main_DML_DID_NPJ.rtf", replace rtf ///
    keep(did) ///
    cells("b(fmt(4)) se(par fmt(4)) t(par fmt(3)) p(par fmt(6))") ///
    stats(N Controls Quadratic CityFE YearFE Kfolds Learner, ///
          fmt(0 %9s %9s %9s %9s %9s %9s) ///
          labels("Observations" "Controls" "Quadratic terms" "City FE" ///
                 "Year FE" "K-folds" "Learner")) ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)") ///
    title("Table 1. Effect of the Action Plan on overall urban energy security") ///
    addnotes("Coefficient, robust standard error, test statistic, and exact two-sided P value. Significance stars are not used.")


*==============================================================================
* Supplementary Table S4. Robustness checks
*==============================================================================
eststo clear

* (1) Alternative dependent variable: principal-component index
global X $controls i.year i.id
ddml_fit w1 index_pca did 42 3 rf
estadd local Specification "PCA index"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Random forest"
eststo w1

* (2) Add centralised-heating control
global X $controls heating i.year i.id
ddml_fit w2 index did 42 3 rf
estadd local Specification "Heating control"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Random forest"
eststo w2

* (3) Add smart-city-pilot control
global X $controls smart_city i.year i.id
ddml_fit w3 index did 42 3 rf
estadd local Specification "Smart city pilot"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Random forest"
eststo w3

* (4) Add carbon-trading-pilot control
global X $controls carbon_trading i.year i.id
ddml_fit w4 index did 42 3 rf
estadd local Specification "Carbon trading pilot"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Random forest"
eststo w4

* (5) Exclude municipalities (sample change -> isolate with preserve/restore)
preserve
    drop if inlist(id, 1, 2, 58, 224)
    global X $controls i.year i.id
    ddml_fit w5 index did 42 3 rf
    estadd local Specification "Excluding municipalities"
    estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
    estadd local Kfolds   "3"   : estadd local Learner "Random forest"
    eststo w5
restore

* (6) Truncated sample 2012-2019 (sample change -> preserve/restore)
preserve
    keep if inrange(year, 2012, 2019)
    global X $controls i.year i.id
    ddml_fit w6 index did 42 3 rf
    estadd local Specification "2012-2019 sample"
    estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
    estadd local Kfolds   "3"   : estadd local Learner "Random forest"
    eststo w6
restore

* (7) Alternative learner: LassoCV
global X $controls i.year i.id
ddml_fit w7 index did 42 3 lassocv
estadd local Specification "LassoCV learner"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "LassoCV"
eststo w7

* (8) Alternative learner: gradient boosting
ddml_fit w8 index did 42 3 gradboost
estadd local Specification "Gradient boosting learner"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Gradient boosting"
eststo w8

esttab w1 w2 w3 w4 w5 w6 w7 w8 using "Table_Robustness_NPJ.rtf", replace rtf ///
    keep(did) ///
    cells("b(fmt(4)) se(par fmt(4)) t(par fmt(3)) p(par fmt(6))") ///
    stats(N Specification Controls CityFE YearFE Kfolds Learner, ///
          fmt(0 %24s %9s %9s %9s %9s %18s) ///
          labels("Observations" "Specification" "Controls" "City FE" ///
                 "Year FE" "K-folds" "Learner")) ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)") ///
    title("Supplementary Table S4. Robustness checks for the effect on urban energy security") ///
    addnotes("Coefficient, robust standard error, test statistic, and exact two-sided P value. Significance stars are not used. All models estimate the effect of the 2017-2018 Action Plan using DML-DID.")


*==============================================================================
* Placebo test (exported separately as Supplementary Fig. S1)
*==============================================================================
xtreg index did $controls i.year, fe vce(cluster id)
estimates store did_fe
didplacebo did_fe, treatvar(did) pbotime(1(1)4)
capture graph export "Fig_S1_placebo_test.tif", replace width(2400)


*==============================================================================
* Supplementary Table S5. Endogeneity and differential-trend checks
*==============================================================================
eststo clear

* (1) System-GMM dynamic panel
*     twostep + conventional VCE reproduces the reported (biased) SE; Stata will
*     warn accordingly. For Windmeijer-corrected SE add vce(robust) -- note this
*     CHANGES the SE and P value, so update the table if you switch.
xtdpdsys index did $controls, lags(2) twostep artests(3)
capture estat abond
capture estat sargan
estadd local Specification "System GMM"
estadd local Controls "Yes" : estadd local CityFE "Dynamic panel"
estadd local YearFE   "No"  : estadd local Kfolds "-"
estadd local Learner  "System GMM"
eststo e1

* (2) DML-DID + terrain-specific time trend
global X $controls terrain_trend i.year i.id
ddml_fit e2 index did 42 3 gradboost
estadd local Specification "Terrain trend"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Gradient boosting"
eststo e2

* (3) DML-DID + temperature-specific time trend
global X $controls temp_trend i.year i.id
ddml_fit e3 index did 42 3 gradboost
estadd local Specification "Temperature trend"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Gradient boosting"
eststo e3

* (4) DML-DID + terrain and temperature trends
global X $controls terrain_trend temp_trend i.year i.id
ddml_fit e4 index did 42 3 gradboost
estadd local Specification "Terrain and temperature trends"
estadd local Controls "Yes" : estadd local CityFE "Yes" : estadd local YearFE "Yes"
estadd local Kfolds   "3"   : estadd local Learner "Gradient boosting"
eststo e4

esttab e1 e2 e3 e4 using "Table_Endogeneity_NPJ.rtf", replace rtf ///
    keep(did) ///
    cells("b(fmt(4)) se(par fmt(4)) t(par fmt(3)) p(par fmt(6))") ///
    stats(N Specification Controls CityFE YearFE Kfolds Learner, ///
          fmt(0 %30s %9s %18s %9s %9s %20s) ///
          labels("Observations" "Specification" "Controls" "City FE" ///
                 "Year FE" "K-folds" "Estimator / learner")) ///
    mtitles("(1)" "(2)" "(3)" "(4)") ///
    title("Supplementary Table S5. Endogeneity and differential-trend checks") ///
    addnotes("Coefficient, standard error, test statistic, and exact two-sided P value. Column (1) is a system-GMM dynamic panel; columns (2)-(4) are DML-DID with gradient boosting and added differential trends.")


*==============================================================================
* Supplementary Table S3. Mechanism and moderation analysis
*   Sample edits (city drops, winsorisation) isolated with preserve/restore.
*   Seeds match the original run (m1: 42, m2: 43, m3: 43) and are preserved.
*==============================================================================
eststo clear
preserve
    drop if inlist(id, 1, 2, 68, 224)
    winsor2 priority1 x, replace cuts(2.5 97.5)
    replace pressure = 0 if missing(pressure)
    gen double did_pressure = pressure * did

    * (1) Infrastructure-priority channel
    global X $controls i.year i.id
    ddml_fit m1 priority1 did 42 3 rf
    eststo m1

    * (2) Digital-economy channel (suggestive)
    ddml_fit m2 x did 43 3 rf
    eststo m2

    * (3) Policy-pressure moderation (interaction as the target)
    global X did $controls i.year i.id
    ddml_fit m3 index did_pressure 43 3 rf
    eststo m3
restore

esttab m1 m2 m3 using "Table_Mechanism_NPJ.rtf", replace rtf ///
    keep(did did_pressure) ///
    order(did did_pressure) ///
    coeflabels(did "DiD" did_pressure "DiD x policy pressure") ///
    cells("b(fmt(4)) se(par fmt(4)) t(par fmt(3)) p(par fmt(6))") ///
    stats(N, fmt(0) labels("Observations")) ///
    mtitles("Infrastructure priority" "Digital economy" "Policy pressure") ///
    title("Supplementary Table S3. Mechanism analysis") ///
    addnotes("Coefficient, robust standard error, test statistic, and exact two-sided P value. Column (1) tests the infrastructure-priority channel. Column (2) tests the digital-economy channel and is interpreted as suggestive evidence. Column (3) tests whether policy pressure moderates the treatment effect. Significance stars are not used.")

*******************************************************************************
* End of file
*******************************************************************************

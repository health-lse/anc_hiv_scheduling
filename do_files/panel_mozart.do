
************************************************************************************
*** 0. Preliminary
************************************************************************************
 
*** 0.1. Description:
* This scripts runs the hiv analyses on mozart data

*** 0.1.1. Input datasets
*	panel_new_30.dta: 
*   panel_new_all.dta, 
*   "${DATA}cleaned_data/hiv_complier_facilities.dta", from hiv_regressions.do, used to add the complier variables

*** 0.1.2. Output datasets

*** 0.1.3. Legend:
// [QUESTION] 	look up this expression to find questions or doubts throughout the code
// [ISSUE]		look up this expression to find issues and things that need to be improved
// [ADD]		look up this expression to find notes on what needs to be added to the code


*** 0.2. MACRO definition
clear
set more off

global HOME     "/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling/"
cd              "${HOME}"
global DATA     "${HOME}data/"
global MOZART     "${HOME}data/cleaned_data/mozart/"

*** 0.3. import the relevant packages and programs
do do_files/mozart_reg_functions
*ssc install erepost
*ssc install fuzzydid

************************************************************************************
*** 1. Regressions
************************************************************************************
 
*** 1.1. Panel with patients that got 30 pills in all their pickups ---------------
use "${MOZART}panel_new_30.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

// function to generate controls
gen_controls

gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

mozart_reg days_without_med , controls($controls) filename("tables/new_30_days.tex")
mozart_reg mpr , controls($controls) filename("tables/new_30_mpr.tex")
mozart_reg mpr_95 , controls($controls) filename("tables/new_30_mpr_95.tex")
mozart_reg delay_7 , controls($controls) filename("tables/new_30_delay_7.tex")


*** 1.2. Panel with new patients that got any amount of pills ---------------
use "${MOZART}panel_new_all.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen_controls
gen mpr_95 = mpr > 0.95

mozart_reg days_without_med , controls($controls) filename("tables/new_all_days.tex")
mozart_reg mpr , controls($controls) filename("tables/new_all_mpr.tex")
mozart_reg mpr_95 , controls($controls) filename("tables/new_all_mpr_95.tex")
mozart_reg delay_7 , controls($controls) filename("tables/new_all_delay_7.tex")



 
*** 1.3. 2 MONTHS (?) ---------------
* [ISSUE] find panel_2m
use "${MOZART}panel_2m.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen_controls

global controls $controls baseline_pickups_per_month

mozart_reg days_without_med , controls($controls) filename("tables/days_without_2m.tex")
mozart_reg mpr , controls($controls) filename("tables/mpr_2m.tex")


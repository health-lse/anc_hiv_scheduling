
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
*   "${DATA}cleaned_data/hiv_pickups_ym.dta", with number of pickups and patients by facility-month
*   "${DATA}cleaned_data/hiv_patients_pickups.dta", with number of pickups by patient (from 11_2020 onwards)
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

label_vars_hiv

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

label_vars_hiv

mozart_reg days_without_med , controls($controls) filename("tables/new_all_days.tex")
mozart_reg mpr , controls($controls) filename("tables/new_all_mpr.tex")
mozart_reg mpr_95 , controls($controls) filename("tables/new_all_mpr_95.tex")
mozart_reg delay_7 , controls($controls) filename("tables/new_all_delay_7.tex")



 
*** 1.3. 2 MONTHS (?) ---------------
/* [ISSUE] find panel_2m
use "${MOZART}panel_2m.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen_controls

global controls $controls baseline_pickups_per_month

mozart_reg days_without_med , controls($controls) filename("tables/days_without_2m.tex")
mozart_reg mpr , controls($controls) filename("tables/mpr_2m.tex")
*/

************************************************************************************
*** 2. Generate the dataset for the volume analysis
************************************************************************************
 
use "${MOZART}data_merge_pre_stata.dta", clear

preserve 
    use "${DATA}aux/facility_characteristics.dta", clear

    * facility_name has spaces in using but not in master data
    replace facility_name = subinstr(facility_name," ","",.)
    keep facility*
    tempfile facility_characteristics
    save `facility_characteristics'
restore

merge m:1 facility_name using `facility_characteristics'
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                       155,534
        from master                   155,534  (_merge==1)
        from using                          0  (_merge==2)

    Matched                         2,415,345  (_merge==3)
    -----------------------------------------
*/
keep if _m==3
drop _m

* generate the monthly pickup date
gen pickup_date = date(trv_date_pickup_drug, "YMD")
gen pickup_month = mofd(pickup_date)
format pickup_month %tm
gen quarter = quarter(pickup_date)
gen month = month(pickup_date)

* [ISSUE] sometimes more than one observation with same nid and pickup date 
bys nid trv_date_pickup_drug: gen dups = _N
*bro if dups > 1 // should drop one of the two duplicates?
duplicates drop nid trv_date_pickup_drug dups, force

* keep observations from 2020
keep if year(pickup_date) > 2019

* collapse at the facility - month level
bys nid pickup_month: gen n_nid = (_n==1)
gen npickups = 1
collapse (sum) npickups n_nid, by(facility_cod pickup_month quarter month)

label var npickups  "Total no of pickups in the facility for that month"
label var n_nid     "Total no of different hiv patients in the facility for that month"

save "${DATA}cleaned_data/hiv_pickups_ym.dta", replace

************************************************************************************
*** 3. Generate the dataset for the number of visits analysis
************************************************************************************
 
use "${MOZART}data_merge_pre_stata.dta", clear

preserve 
    use "${DATA}aux/facility_characteristics.dta", clear

    * facility_name has spaces in using but not in master data
    replace facility_name = subinstr(facility_name," ","",.)
    keep facility*
    tempfile facility_characteristics
    save `facility_characteristics'
restore

merge m:1 facility_name using `facility_characteristics'

keep if _m==3
drop _m

gen pickup_date = date(trv_date_pickup_drug, "YMD")
gen pickup_month = mofd(pickup_date)
format pickup_month %tm

* generate first month of pickup
bys nid (pickup_date): gen first_month_overall = pickup_month[1]

* keep only observations after the beginning of the treatment period
keep if pickup_month > ym(2020,10)

* generate first month of pickup after the beginning of treatment
bys nid (pickup_date): gen first_month_treat = pickup_month[1]


* [ISSUE] sometimes more than one observation with same nid and pickup date 
bys nid trv_date_pickup_drug: gen dups = _N
*bro if dups > 1 // should drop one of the two duplicates?
duplicates drop nid trv_date_pickup_drug dups, force

gen nid_nvisits = 1
collapse (sum) nid_nvisits (firstnm) first_month*, by(nid facility_cod)
label var nid_nvisits    "Number of pickpus by patient"

save "${DATA}cleaned_data/hiv_patients_pickups.dta", replace

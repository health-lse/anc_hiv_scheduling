
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


local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(period province) filename("tables/new_30_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(period) filename("tables/new_30_`q'_maputo.tex") het_var(maputo)

    local ++i
}



*** 1.2. Panel with new patients that got any amount of pills ---------------
use "${MOZART}panel_new_all.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen_controls
gen mpr_95 = mpr > 0.95

label_vars_hiv

local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(period province) filename("tables/new_all_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(period) filename("tables/new_all_`q'_maputo.tex") het_var(maputo)

    local ++i
}
 
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
*** 2. Generate the datasets for the volume analysis 
************************************************************************************
 

 * ----------- NEW ATTEMPT --------------- *
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
format pickup_date %td
format pickup_month %tm
gen quarter = quarter(pickup_date)
gen month = month(pickup_date)

* keep observations from 2018 (in that year there was a major shift in the way the service was provided)
keep if year(pickup_date) > 2017

* create new trip counter variable as the one already existing seems wrong
preserve 
    gen trip = 1
    collapse trip, by(nid trv_date_pickup_drug)
    bysort nid (trv_date_pickup_drug): replace trip = _n

    tempfile trips
    save `trips'
restore
merge m:1 nid trv_date_pickup_drug using  `trips', nogen 

* drop observations referring to the same pickup 
bys nid trv_date_pickup_drug: gen dups = _N
duplicates drop nid trv_date_pickup_drug, force

destring trv_quantity_taken, replace force // 8488 "NA" observations replaced as .
// [ISSUE] quantity taken needs to be cleaned 
/*
                        trv_quantity_taken
    -------------------------------------------------------------
        Percentiles      Smallest
    1%            0             -8
    5%           30             -4
    10%           30             -1       Obs           1,987,751
    25%           30              0       Sum of wgt.   1,987,751

    50%           30                      Mean           82.12888
                            Largest       Std. dev.      897.5556
    75%           90          76680
    90%           90          76860       Variance       805606.1
    95%           90          77340       Skewness       45.68512
    99%          180          77460       Kurtosis       2551.362
*/

* for now I winsorize at 95%: !!!strong assumption, maybe it is just better to drop those observations/patients?
replace trv_quantity_taken = 90 if trv_quantity_taken > 90

* create the patient-month panel:
bys nid (trip): gen day_pickup1 = pickup_date[1]
bys nid (trip): gen month_pickup1 = pickup_month[1]

format day_pickup1 %td
format month_pickup1 %tm

* create a monthly dataset for each nid, to fill in months without pickups
preserve 
    keep nid day_pickup1 pickup_month 
    duplicates drop nid day_pickup1, force 

    bys nid: gen e = 50 // the number of months between the earliest pickup_month and march 2022, the latest month in the sample.
    expand e
    bys nid: replace pickup_month=pickup_month[_n-1]+1 if _n>1
    format pickup_month %tm
    drop if pickup_month>ym(2022,3)
    drop e day_pickup1

    unique nid pickup_month

    tempfile balancedpanel
    save `balancedpanel'
restore

merge m:1 nid pickup_month using `balancedpanel'
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     3,278,352
        from master                         0  (_merge==1)
        from using                  3,278,352  (_merge==2)

    Matched                         1,996,168  (_merge==3)
    -----------------------------------------
*/
replace pickup_date = dofm(pickup_month) if _m==2
gen nopickup=_m==2
drop _m


*bys nid pickup_month: egen npills_pickedup_m = total(trv_quantity_taken)
bys nid pickup_month: gen pickups_per_m = _N
by nid pickup_month: gen pickcount = _n


bys nid (pickup_date): gen expiry = pickup_date + trv_quantity_taken - 1
by nid: replace expiry = expiry[_n-1] + trv_quantity_taken - 1 if expiry[_n-1] > pickup_date & trip>1
format expiry %td

by nid: gen last_expiry = expiry[_n-1] if _n>1 
format last_expiry %td

by nid: gen days_without = max(0,pickup_date-last_expiry-1) if _n>1 
by nid: replace days_without = day(pickup_date)-1 if _n>1 & days_without>(day(pickup_date)-1)

* clean cases with multiple pickups in a month
by nid: replace days_without = pickup_date-pickup_date[_n-1] if _n>1 & days_without>(pickup_date-pickup_date[_n-1]) & pickup_month==pickup_month[_n-1]

* sum the cumulated number of days without pills until the last pickup of the month:
bys nid pickup_month (pickup_date): egen days_without_med = total(days_without)

* count the number of days without pills after the pickup and until the end of the month
by nid pickup_month: replace days_without_med = days_without_med + max(0,(lastdayofmonth(pickup_date)-expiry[_N])) if _n==_N

by nid pickup_month: gen mpr= 1-(days_without_total/daysinmonth(pickup_date))

* create the post intervention variable
gen post = inrange(pickup_month, ym(2021,1), ym(2021,12))
replace post = 1 if inrange(pickup_month, ym(2020,11), ym(2020,12)) & facility_cod > 41

* label patients that had their first pickup after the intervention
bys nid (pickup_month): gen new_patient = (post[1])

* label patients that picked up 30 pills in all their pickups
gen pick30 = trv_quantity_taken==30

collapse (mean) pick30 (sum) npills_pickedup_m=trv_quantity_taken (last) new_patient month_pickup1 day_pickup1 mpr days_without_med, by(nid pickup_month facility_cod facility_name)

label var pick30                    "Share of pickups with 30 pills"
label var npills_pickedup_m         "NUmber of pills picked per month"
label var new_patient               "Patient that had the first pickup after the intervention"
label var days_without_med          "Number of days without pills in a month"


save "${DATA}cleaned_data/panel_monthly.dta", replace


*** 2.1. 
use "${DATA}cleaned_data/panel_monthly.dta", clear 

gen new_patient2 = month_pickup1>ym(2020,10)

collapse mpr days_without_med new_patient2, by(facility_cod pickup_month)


merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

// function to generate controls
global controls index_hiv_care_readiness art_different_lines art_general hand_wash dayaverage urban cd4 score_basic_amenities score_basic_equipment hiv_diagnostic_capacity index_general_service

gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

rename pickup_month period
label_vars_hiv


local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(period province) filename("tables/facility_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(period) filename("tables/facility_`q'_maputo.tex") het_var(maputo)

    local ++i
}

************************************************************************************
*** 2. Generate the datasets for the volume analysis
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

* keep observations from 2018 (in that year there was a major shift in the way the service was provided)
keep if year(pickup_date) > 2017

* create new trip counter variable as the one already existing seems wrong
preserve 
    gen trip = 1
    collapse trip, by(nid trv_date_pickup_drug)
    bysort nid (trv_date_pickup_drug): replace trip = _n

    tempfile trips
    save `trips'
restore
merge m:1 nid trv_date_pickup_drug using  `trips', nogen 

*** CHECKS 
* [ISSUE] sometimes more than one observation with same nid and pickup date 
bys nid trv_date_pickup_drug: gen dups = _N
/*
bro if dups > 1 // should drop one of the two duplicates?
order dups trip, after(trv_date_pickup_drug)

count if trv_actual_next_pickup=="NA"
gen temp = trv_actual_next_pickup=="NA"
bysort nid (trv_date_pickup_drug): gen last_trip = _n == _N

cap drop na_check 
by nid: egen na_check = max(temp) 

bysort nid (trv_date_pickup_drug): gen next_pickup = trv_actual_next_pickup[_n+1] 

order next_pickup, after(trv_date_pickup_drug)
*/
duplicates drop nid trv_date_pickup_drug, force

* create the metrics needed for the volume analysis and collapse at the facility - month level
bys nid pickup_month: gen n_nids = (_n==1)
gen npickups = 1
gen new_patients = (trip == 1)

destring trv_quantity_take, replace force
gen npills = trv_quantity_taken
gen avg_npills = trv_quantity_taken

collapse (mean) avg_npills (sum) new_patients npickups n_nids npills, by(facility_cod pickup_month quarter month)

label var npickups       "Total no of pickups in the facility for that month"
label var n_nid          "Total no of different hiv patients in the facility for that month"
label var new_patients   "Number of patients that did their first trip in that month"
label var npills         "Total no of pills distributed by the facility in that month"
label var avg_npills     "Average no of pills distributed by the facility in that month"

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

*** hiv_regression.do

************************************************************************************
*** 0. Preliminary
************************************************************************************
 
*** 0.1. Description:
* This scripts replicates the analysis in anc_regressions.do carried out by Rafael on the hiv data

*** 0.1.1. Input datasets
*	hiv_endline.csv: dataset produced by the hiv_clean_aws_response.py
*   ${csv_review}##.csv, hiv_endline but reviewed
*   ${DATA}aux/facility_characteristics.dta
*	hiv_baseline.csv: dataset produced by the hiv_baseline_aws_clean.py
*   opening_time.dta: in the cleaned_data folder, used for the opening time analysis
*   "${DATA}cleaned_data/hiv_pickups_ym.dta", from panel_mozart.do used for the volume analysis

*** 0.1.2. Output datasets
*   hiv_endline.dta
*   hiv_baseline.dta
*   hiv_complier_facilities.dta: classifying each facility as complier and complier10 based on hiv scheduled_time data

*** 0.1.3. Legend:
// [QUESTION] 	look up this expression to find questions or doubts throughout the code
// [ISSUE]		look up this expression to find issues and things that need to be improved
// [ADD]		look up this expression to find notes on what needs to be added to the code


*** 0.2. MACRO definition
set more off

global HOME     "/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling/"
cd              "${HOME}"
global DATA     "${HOME}data/"
global RAW      "${DATA}hiv/endline/extracted_data/" 
global hiv_dataset "data/cleaned_data/anc_cpn_endline_v20230704.dta"

*** 0.3. import the relevant packages and programs
do do_files/hiv_programs
*ssc install erepost
*ssc install fuzzydid


************************************************************************************
*** 1. Cleaning
************************************************************************************
 
import delimited "${RAW}hiv_endline.csv", clear


* add facility variables
rename facility facility_cod
local fac_vars province maputo high_quality gaza_inhambane score_basic_amenities ///
    score_basic_equipment urban hospital volume_base_total index_*
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", keepusing(`fac_vars') ///
    keep(match) nogen


* manual cleaning
do do_files/hiv_manual_cleaning

*** 1.1. create the complier definitions based on hiv data  ------------------------
clean_timevar scheduled_time

preserve
    gen scheduled = scheduled_time > 0
    gen scheduled10 = scheduled_time > 1000 

    collapse (mean) treatment  scheduled_share=scheduled scheduled10_share=scheduled10, by(facility_cod)
    gen complier = (treatment*scheduled_share)>=0.2
*    gen full_complier_hiv = (treatment*scheduled_share) > 0.7
    gen complier10 = (treatment*scheduled10_share)>=0.2

    label var scheduled_share       "Share of scheduled consultations in the facility"
    label var complier       "This (treated) facility scheduled more than 20% of the hiv consultations"
*    label var full_complier_hiv      "This (treated) facility scheduled more than 70% of the hiv consultations"
    label var complier10        "This (treated) facility scheduled after 10am more than 20% of the hiv consultations"
 
    sum scheduled_share if treatment==0, d
/*  Some control facilities scheduled some consultations. Issue? Especially facility code 61 has a 22% of scheduled visits
 
        Share of scheduled consultations in the facility
    -------------------------------------------------------------
        Percentiles      Smallest
    1%            0              0
    5%            0              0
    10%            0              0       Obs                  40
    25%            0              0       Sum of wgt.          40

    50%     .0071608                      Mean           .0294342
                            Largest       Std. dev.      .0514655
    75%     .0287366       .1027668
    90%     .1022719       .1164021       Variance       .0026487
    95%     .1552599       .1941177       Skewness       2.337361
    99%     .2175573       .2175573       Kurtosis       7.977706
*/

    save "${DATA}cleaned_data/hiv_complier_facilities.dta", replace
restore

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 

save "${DATA}cleaned_data/hiv_endline.dta", replace



*** CHECKS
*use "${DATA}aux/facility_characteristics.dta", clear
*use "${DATA}/cleaned_data/anc_cpn_endline_v20230704.dta", clear


*** 1.2. import csv after review ------------------------
global csv_review "/Users/vincenzoalfano/Library/CloudStorage/Dropbox/Simon/Health/Data/OCR_HIV/csvs_after_review/"
import delimited "${csv_review}1.csv", clear

forvalues i=2/83 {
    preserve 
    capture import delimited "${csv_review}`i'.csv", clear
    dis "`i'"
    tempfile csv
    save `csv'
    restore 
    append using `csv'
}

keep file_name line *time
rename (arrival_time consultation_time waiting_time) (arrival_time2 consultation_time2 waiting_time2)
duplicates drop 

* merged with the new data
replace line = line + 1
merge 1:1 file_name line using "${DATA}cleaned_data/hiv_endline.dta"

* keep the reviewed arrival and consultation time when possible
replace arrival_time = arrival_time2 if !missing(arrival_time2)
replace consultation_time = consultation_time2 if !missing(consultation_time2)

clean_timevar arrival_time consultation_time 

* compute new time floats:
cap drop consultation_time_float
timestr_to_float arrival_time, varname("arrival_time_float")
timestr_to_float consultation_time, varname("consultation_time_float")

gen new_wait = round((consultation_time_float - arrival_time_float)*60,1)
replace new_wait = -1 if new_wait<0

* drop other observations with errors
drop if consultation_time > 1600
drop if arrival_time > 1600

* drop observations with minutes of arrival/consultation above 59
drop if flag_m_arrival_time
drop if flag_m_consultation_time

replace waiting_time = new_wait
drop new_wait _m *2 flag_*

*** 1.3. Flag observations  ------------------------
gen before_7 = (arrival_time <= 700)
gen more_than_3 = (waiting_time >= 180) if !missing(waiting_time)

label_vars_hiv
label var before_7      "The patient arrived before 7am"
label var more_than_3   "The patient waited for more than 3 hours" 


save "${DATA}cleaned_data/hiv_endline.dta", replace


************************************************************************************
*** 2. Endline regressions
************************************************************************************

global controls score_basic_amenities score_basic_equipment index_general_service index_hiv_care_readiness index_hiv_counseling_readiness urban hospital volume_base_total
global controls_without_urban score_basic_amenities score_basic_equipment index_general_service index_hiv_care_readiness index_hiv_counseling_readiness hospital volume_base_total

*** 2.1. WAITING TIME ------------------------

use "${DATA}cleaned_data/hiv_endline.dta", clear

* create the control macros 
gen_controls

* drop outliers (above 99%) 
sum waiting_time, d
*keep if waiting_time <  r(p95) | missing(waiting_time)
keep if waiting_time <  r(p99)

* should we drop outliers in time_arrived_float as well?
sum time_arrived_float, d
keep if time_arrived_float <  r(p99)

/*
                        time_arrived_float
    -------------------------------------------------------------
        Percentiles      Smallest
    1%            6           1.02
    5%          6.5            1.1
    10%            7           1.23       Obs              24,562
    25%         8.22           1.42       Sum of wgt.      24,562

    50%         9.42                      Mean           9.489071
                            Largest       Std. dev.      1.822012
    75%        10.67          15.33
    90%        11.88          15.33       Variance       3.319729
    95%        12.65          15.38       Skewness       .1988616
    99%        14.03          15.45       Kurtosis       2.914319
*/

foreach var in time_arrived_float waiting_time more_than_3  before_7 {

    global outcome_var `var'
    hiv_group_reg $outcome_var , suffix("hiv")
}

*** 2.2. OPENING TIME  ------------------------

use "data/cleaned_data/opening_time.dta", clear

capture drop _merge

preserve
    use "${DATA}cleaned_data/hiv_endline.dta", clear
    local fac_vars maputo high_quality gaza_inhambane score_basic_amenities ///
        score_basic_equipment urban hospital volume_base_total index_*
    desc `fac_vars' 
    collapse `fac_vars' treatment complier complier10, by(facility_cod province)

    tempfile facility_characteristics
    save `facility_characteristics'
restore

merge m:1 facility_cod using `facility_characteristics', keep(match) nogen
gen_controls
label_vars_hiv

sum opening_time, d
/*
                        opening_time
-------------------------------------------------------------
      Percentiles      Smallest
 1%           -8           -196
 5%           17           -178
10%           60           -115       Obs                 926
25%          120            -61       Sum of wgt.         926

50%          188                      Mean           184.4611
                        Largest       Std. dev.      95.22223
75%          250            420
90%          305            435       Variance       9067.274
95%          340            435       Skewness      -.1505885
99%          393            445       Kurtosis       2.989339
*/

global outcome_var opening_time
hiv_group_reg $outcome_var , suffix("hiv")


*** 2.3. NUMBER OF VISITS  ------------------------

use "${DATA}cleaned_data/hiv_patients_pickups.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

* create the control macros 
gen_controls
label_vars_hiv

label var nid_nvisits "Number of visits"

hiv_group_reg_custom_fe nid_nvisits , suffix("hiv_1stoverall") absorb(province first_month_overall) absorb_maputo_reg(first_month_overall)
hiv_group_reg_custom_fe nid_nvisits , suffix("hiv_1st") absorb(province first_month_treat) absorb_maputo_reg(first_month_treat)


*** 2.4. VOLUME  ------------------------
 
* import the dataset at the facility - month level (from panel_mozart.do)
use "${DATA}cleaned_data/hiv_pickups_ym.dta", clear

* merge facility characteristics
merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

tab quarter, gen(quarter)

gen_controls
label_vars_hiv

* create the post variable [QUESTION] defined in the same way as the one used for anc, is it
gen post = inrange(pickup_month, ym(2021,1), ym(2021,12))
replace post = 1 if inrange(pickup_month, ym(2020,11), ym(2020,12)) & facility_cod > 41

* post 42 onwards


* [QUESTION] long time series, should I drop some of the earier years?


global controls_vol score_basic_amenities score_basic_equipment index_general_service index_hiv_care_readiness index_hiv_counseling_readiness urban hospital

*hiv_volume_reg npickups, filename("tables/vol_test_hiv.tex") controls($controls_vol ) // the program gives an error

foreach var in npickups n_nid {
    global outcome `var'
    preserve
        global outcome `var'
        eststo clear
        estimates clear

        reghdfe $outcome c.treatment##c.post##c.maputo, absorb( month) vce(cl facility_cod)
        estimates store model1, title("OLS")

        reghdfe $outcome c.treatment##c.post##c.maputo $controls_vol, absorb( month) vce(cl facility_cod)
        estimates store model2, title("OLS")

        rename treatment treatment_iv
        rename complier treatment
        ivreghdfe $outcome c.post (treatment c.treatment##c.post = treatment_iv c.treatment_iv##c.post) , absorb(month province) cluster(facility_cod)
        estimates store model3, title("IV")

        ivreghdfe $outcome c.post (treatment c.treatment##c.post = treatment_iv c.treatment_iv##c.post)  $controls_vol , absorb(month province) cluster(facility_cod)
        estimates store model4, title("IV")

        drop treatment
        rename complier10 treatment
        ivreghdfe $outcome c.post (treatment c.treatment##c.post = treatment_iv c.treatment_iv##c.post) , absorb(month province) cluster(facility_cod)
        estimates store model5, title("IV")

        ivreghdfe $outcome c.post (treatment c.treatment##c.post = treatment_iv c.treatment_iv##c.post)  $controls_vol , absorb(month province) cluster(facility_cod)
        estimates store model6, title("IV")

        estfe . model*, labels(province "Province FE" month "Month FE")

        local filename "tables/vol_test_hiv_`var'.tex"
        esttab model*  using "`filename'", style(tex) stats(r2 N) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_vol" `r(indicate_fe)') drop(_cons ) se replace mlabels(,titles)

        estfe . model*, restore
    restore 
}




reghdfe npickups c.treatment##c.quarter1 c.treatment##c.quarter2 c.treatment##c.quarter3 $controls_vol, a(province) vce(cl facility_cod)

ivreghdfe npickups c.quarter1 c.quarter2 c.quarter3 (complier c.complier##c.quarter1 c.complier##c.quarter2 c.complier##c.quarter3 = treatment c.treatment##c.quarter1 c.treatment##c.quarter2 c.treatment##c.quarter3) $controls_vol if maputo==1, a(month) cluster(facility_cod)

ivreghdfe $outcome c.post (complier10 c.complier10##c.post = treatment c.treatment##c.post)  $controls_vol , absorb(month ) cluster(facility_cod)


************************************************************************************
*** 3. Baseline regressions
************************************************************************************

*** 3.1. Cleaning of baseline data -------------------------------
import delimited "${DATA}cleaned_data/hiv_baseline.csv", clear

rename (waiting_time facility) (waiting_time_str facility_cod)
rename waiting_time_minutes waiting_time

preserve
    use "${DATA}cleaned_data/hiv_endline.dta", clear
    local fac_vars maputo high_quality gaza_inhambane score_basic_amenities ///
        score_basic_equipment urban hospital volume_base_total index_*
    desc `fac_vars' 
    collapse `fac_vars' treatment complier complier10, by(facility_cod province)

    tempfile facility_characteristics
    save `facility_characteristics'
restore

merge m:1 facility_cod using `facility_characteristics'
drop if _m != 3
drop _m
/* [ISSUE]? facility 11 from baseline does not have endline data, facilities 6 9 45 55 58 79 the other way around
    tab _m  facility_cod if _m!=3

    Matching result from |                                 facility_cod
                    merge |         6          9         11         45         55         58         79 |     Total
    ----------------------+-----------------------------------------------------------------------------+----------
        Master only (1) |         0          0        217          0          0          0          0 |       217 
        Using only (2) |         1          1          0          1          1          1          1 |         6 
    ----------------------+-----------------------------------------------------------------------------+----------
                    Total |         1          1        217          1          1          1          1 |       223 
*/

save "${DATA}cleaned_data/hiv_baseline.dta", replace

*** 3.2. Regressions -------------------------------

global controls score_basic_amenities score_basic_equipment index_general_service index_hiv_care_readiness index_hiv_counseling_readiness urban hospital volume_base_total
global controls_without_urban score_basic_amenities score_basic_equipment index_general_service index_hiv_care_readiness index_hiv_counseling_readiness hospital volume_base_total

use "${DATA}cleaned_data/hiv_baseline.dta", clear

* drop outliers (above 99%) 
sum waiting_time, d
keep if waiting_time <  r(p99)

* create the control macros 
gen_controls
label_vars_hiv

global outcome waiting_time
global absorb province
local suffix "hiv_baseline"
hiv_reg $outcome , controls($controls) absorb($absorb) filename("tables/waiting_time_`suffix'.tex")

*hiv_reg_het_noabsorb $outcome , controls($controls) filename("tables/waiting_time_maputo_`suffix'.tex") het_var(maputo)
hiv_reg_het $outcome , controls($controls) absorb($absorb) filename("tables/waiting_time_maputo_`suffix'.tex") het_var(maputo)

hiv_reg_het $outcome , controls($controls_without_urban) absorb($absorb) filename("tables/waiting_time_urban_`suffix'.tex") het_var(urban)

hiv_reg_het $outcome , controls($controls_without_quality) absorb($absorb) filename("tables/waiting_time_high_quality_`suffix'.tex") het_var(high_quality)



************************************************************************************
*** 4. DiD REGRESSIONS
************************************************************************************

use "${DATA}cleaned_data/hiv_baseline.dta", clear

gen post = 0
append using "${DATA}cleaned_data/hiv_endline.dta"
replace post = 1 if missing(post)

* drop facilities appearing only in baseline or endline
bys facility_cod (post): egen temp = mean(post) 
tab facility_cod if inlist(temp,0,1)
drop if inlist(temp,0,1)
drop temp

* drop outliers (above 99%) 
sum waiting_time, d
keep if waiting_time <  r(p99)

* create the control macros 
gen_controls
label_vars_hiv

global outcome waiting_time
global absorb province
local suffix "hiv_did"

hiv_did $outcome , controls($controls) absorb($absorb) filename("tables/$outcome_`suffix'.tex")

hiv_did_het $outcome , controls($controls) absorb($province) filename("tables/$outcome_maputo_`suffix'.tex") het_var(maputo)

hiv_did_het $outcome , controls($controls_without_urban) absorb($absorb) filename("tables/$outcome_urban_`suffix'.tex") het_var(urban)

hiv_did_het $outcome , controls($controls_without_quality) absorb($absorb) filename("tables/$outcome_high_quality_`suffix'.tex") het_var(high_quality)


* Fuzzy 
encode province, gen(province_id)
fuzzydid $outcome treatment post complier, did cluster(facility_cod) 
fuzzydid $outcome treatment post complier, did cluster(facility_cod) qualitative(facility_cod province_id) 
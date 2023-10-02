*** hiv_regression.do

************************************************************************************
*** 0. Preliminary
************************************************************************************
 
*** 0.1. Description:
* This scripts replicates the analysis in anc_regressions.do carried out by Rafael on the hiv data

*** 0.1.1. Input datasets
*	hiv_endline.csv: dataset produced by the hiv_clean_aws_response.py
*   ${DATA}aux/facility_characteristics.dta

*** 0.1.2. Output datasets


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
do do_files/anc_programs


************************************************************************************
*** 1. Cleaning
************************************************************************************
 
import delimited "${RAW}hiv_endline.csv", clear

* add facility variables
rename facility facility_cod
local fac_vars complier* province maputo high_quality gaza_inhambane score_basic_amenities ///
    score_basic_equipment index_general_service index_anc_readiness urban hospital volume_base_total
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", keepusing(`fac_vars') ///
    keep(match) nogen

label_vars_anc

*** 1.1. create the complier definition based on hiv data  ------------------------
preserve

    gen scheduled = scheduled_time > 0
    gen scheduled10 = scheduled_time > 1000 

    collapse (mean) treatment  scheduled_share=scheduled scheduled10_share=scheduled10, by(facility_cod)
    gen complier_hiv = (treatment*scheduled_share)>=0.2
*    gen full_complier_hiv = (treatment*scheduled_share) > 0.7
    gen complier10_hiv = (treatment*scheduled10_share)>=0.2

    label var scheduled_share       "Share of scheduled consultations in the facility"
    label var complier_hiv          "This (treated) facility scheduled more than 20% of the hiv consultations"
*    label var full_complier_hiv      "This (treated) facility scheduled more than 70% of the hiv consultations"
    label var complier10_hiv          "This (treated) facility scheduled after 10am more than 20% of the hiv consultations"
 
/*  Some control facilities scheduled some consultations. Issue? Especially facility code 61 has a 22% of scheduled visits
    sum scheduled_share if treatment==0, d

                      (mean) scheduled
    -------------------------------------------------------------
        Percentiles      Smallest
    1%            0              0
    5%            0              0
    10%            0              0       Obs                  40
    25%            0              0       Sum of wgt.          40

    50%     .0071608                      Mean           .0295734
                            Largest       Std. dev.      .0520933
    75%     .0287366       .1027668
    90%     .1022719       .1164021       Variance       .0027137
    95%     .1523187       .1882353       Skewness       2.398116
    99%     .2290076       .2290076       Kurtosis       8.410827
*/

    tempfile complier 
    save `complier'
restore
merge m:1 facility_cod using `complier', nogen 

tab complier complier_hiv, m 
/*
           |    This (treated)
           |  facility scheduled
           | more than 20% of the
           |     hiv check-ups
 Treatment |         0          1 |     Total
-----------+----------------------+----------
         0 |    17,120      1,572 |    18,692 
         1 |     5,422      5,245 |    10,667 
         . |       346          0 |       346 
-----------+----------------------+----------
     Total |    22,888      6,817 |    29,705 

*/

*** 1.2. Flag observations  ------------------------
gen before_7 = (arrival_time <= 700)
gen more_than_3 = (waiting_time >= 180) if !missing(waiting_time)

label var before_7      "The patient arrived before 7am"
label var more_than_3   "The patient waited for more than 3 hours" 

save "${DATA}cleaned_data/hiv_endline.dta", replace




*use "${DATA}aux/facility_characteristics.dta", clear


************************************************************************************
*** 2. Regressions
************************************************************************************

global controls score_basic_amenities score_basic_equipment index_general_service index_anc_readiness urban hospital volume_base_total
global controls_without_urban score_basic_amenities score_basic_equipment index_general_service index_anc_readiness hospital volume_base_total

*** 2.1. WAITING TIME ------------------------

use "${DATA}cleaned_data/hiv_endline.dta", clear

* create the control macros (necessary?)
gen_controls

sum waiting_time, d
keep if waiting_time < 228 // remove outliers 5%


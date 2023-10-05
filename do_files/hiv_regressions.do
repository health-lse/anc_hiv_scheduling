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
do do_files/hiv_programs
*ssc install erepost


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

/*
* manual cleaning
replace consultation_time = 11:42 if file_name=="endline_US43_day12_page4.txt" & line==1 


facility-day-page with no consultation time in the split image:
--- endline_US25_day1_page5.png

--- endline_US43_day12_page4.txt
*/

************************************************************************************
*** 2. Regressions
************************************************************************************

global controls score_basic_amenities score_basic_equipment index_general_service index_hiv_care_readiness index_hiv_counseling_readiness urban hospital volume_base_total
global controls_without_urban score_basic_amenities score_basic_equipment index_general_service index_hiv_care_readiness index_hiv_counseling_readiness hospital volume_base_total

*** 2.1. WAITING TIME ------------------------

use "${DATA}cleaned_data/hiv_endline.dta", clear

* create the control macros 
gen_controls

* drop outliers (above 95%) 
sum waiting_time, d
*keep if waiting_time <  r(p95) | missing(waiting_time)
keep if waiting_time <  r(p99)

* should we drop outliers in time_arrived_float as well?
sum time_arrived_float, d
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

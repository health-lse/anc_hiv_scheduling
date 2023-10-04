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
    score_basic_equipment index_general_service index_anc_readiness urban hospital /// 
    volume_base_total index_*
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", keepusing(`fac_vars') ///
    keep(match) nogen

*** 1.1. clean the waiting time variable  ------------------------
sum waiting_time, d 
* by construction, if one of the two columns has less than 3 digits, the value is set to -1. Also, 
*       in some cases consultation time may be misread by textract --> negative value
*   [ISSUE] large positive values when arrival time is misread: harder to fix this. Should we winsorize at the 99%?
*   [QUESTION] sometimes,the time is in the format: HH:M, it should be HH:0M. Maybe worth fixing in the script
replace waiting_time = . if waiting_time < 0


*** 1.2. create the complier definitions based on hiv data  ------------------------
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

/*
tab complier complier_hiv, m 
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

label_vars_hiv
label var before_7      "The patient arrived before 7am"
label var more_than_3   "The patient waited for more than 3 hours" 

save "${DATA}cleaned_data/hiv_endline.dta", replace



*** CHECKS
*use "${DATA}aux/facility_characteristics.dta", clear
*use "${DATA}/cleaned_data/anc_cpn_endline_v20230704.dta", clear


*** 1.3. import csv after review  ------------------------
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

rename (arrival_time consultation_time waiting_time) (arrival_time2 consultation_time2 waiting_time2)
duplicates drop 

replace line = line + 1
merge 1:1 file_name line using "${DATA}cleaned_data/hiv_endline.dta"

order file_name facility facility_cod page day line arri* cons* wait*
bro file_name facility facility_cod page day line arri* cons* wait*

gen diff_arrival = (arrival_time2 != arrival_time)
gen diff_consultation = (consultation_time2 != consultation_time)
gen diff_waiting = (waiting_time2 != waiting_time)
gen diff_any = diff_arrival + diff_consultation + diff_waiting

order file_name facility facility_cod day page line diff* arri* consultation_time consultation_time2 wait* 
bro file_name facility facility_cod day page line arri* consultation_time consultation_time2 wait* if diff_any> 0


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
keep if waiting_time <  r(p95)

* should we drop outliers in time_arrived_float as well?
sum time_arrived_float, d
/*
                        time_arrived_float
    -------------------------------------------------------------
        Percentiles      Smallest
    1%         5.98              1
    5%         6.67              1
    10%            7              1       Obs              19,545
    25%         8.27              1       Sum of wgt.      19,545

    50%         9.45                      Mean           9.508135
                            Largest       Std. dev.      1.843707
    75%        10.67          15.28
    90%        11.95          15.33       Variance       3.399257
    95%        12.67          15.33       Skewness       .0470113
    99%        14.05          15.38       Kurtosis       3.595751
*/


foreach var in time_arrived_float waiting_time more_than_3  before_7 {

    global outcome_var `var'
    hiv_group_reg $outcome_var , suffix("hiv")

}

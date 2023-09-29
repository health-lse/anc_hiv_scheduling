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

/// where to find consultation_reason? [ISSUE]
keep if consultation_reason == 1
keep if waiting_time < 281 // remove outliers 5% - 1st

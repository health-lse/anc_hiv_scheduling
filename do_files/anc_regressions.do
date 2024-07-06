
// NOT SAVED
use $anc_dataset, clear
capture drop high_quality
gen high_quality = 0
replace high_quality = 1 if quality_pca >= .543
label var high_quality "High Quality"
save $anc_dataset, replace

use "data/aux/facility_characteristics.dta", clear
gen high_quality = 0
replace high_quality = 1 if quality_pca >= .543
label var high_quality "High Quality"
save "data/aux/facility_characteristics.dta", replace


set more off
global HOME 	"/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling/"
global DATA     "${HOME}data/"

global anc_dataset "${DATA}cleaned_data/anc_cpn_endline_v20230704.dta"
use "$anc_dataset", clear
do "${HOME}/do_files/anc_programs.do"

use "${DATA}cleaned_data/anc_cpn_endline_v20230704.dta", clear

/* CONTROLS */
gen_controls

keep if consultation_reason == 1
keep if waiting_time < 281 // remove outliers 5% - 1st

foreach x in waiting_time  more_than_3  before_7 time_arrived_float  {
	global outcome_var `x'
	anc_group_reg $outcome_var , suffix("1st")
}

use "$anc_dataset", clear

keep if consultation_reason == 2
keep if waiting_time < 249 // remove outliers 5% - followups

foreach x in waiting_time  more_than_3  before_7 time_arrived_float  {
	global outcome_var `x'
	anc_group_reg $outcome_var , suffix("followup")
}


/* STANDARD DEVIATION OF THE WAITING TIME */
use "$anc_dataset", clear
keep if consultation_reason == 1
collapse (sd) waiting_time  (first) treatment consultation_reason province day_of_week complier complier10 maputo gaza_inhambane high_quality $controls, by (facility_cod day)

label_vars_anc
rename waiting_time std_waiting_time

anc_group_reg std_waiting_time , suffix("1st")

use "$anc_dataset", clear

keep if consultation_reason == 2
collapse (sd) waiting_time  (first) treatment consultation_reason province day_of_week complier complier10 maputo gaza_inhambane high_quality $controls, by (facility_cod day)

label_vars_anc
rename waiting_time std_waiting_time

anc_group_reg std_waiting_time , suffix("followup")





/* OPENING TIME */

use "${DATA}/cleaned_data/opening_time.dta", clear
capture drop _merge

merge m:1 facility_cod using "$DATA/aux/facility_characteristics.dta"
drop _merge
label_vars_anc

anc_group_reg opening_time , suffix("")


/* REGISTRY BOOK: NUMBER OF VISITS */
cd "$HOME"
use "${DATA}/cleaned_data/anc_registry_book.dta", clear
label_vars_anc

gen number_of_visits = anc_total
label var number_of_visits "Number of visits"


gen_controls 
mdesc $controls volume_base_total 
tab facility_cod if missing(index_general_service ) | missing(volume_base_total), m
// two facility codes (36 and 54) have all the observations missing for the control variables.

** regression adjustment approach to fill in missing values:
gen miss_control1 = missing(index_general_service) if !missing(facility_cod)
gen miss_control2 = missing(volume_base_total) if !missing(facility_cod)

qui sum volume_base_total
replace volume_base_total =  r(mean) if miss_control2 == 1

foreach var in score_basic_amenities  score_basic_equipment index_general_service index_anc_readiness {
	qui sum `var'
	replace `var' =  r(mean) if miss_control1 == 1
}

* add the two missing dummies as controls:
global controls $controls miss_control1 miss_control2 gestational_age_1st
global controls_without_urban $controls_without_urban miss_control1 miss_control2 gestational_age_1st
global controls_without_quality $controls_without_quality miss_control1 miss_control2 gestational_age_1st

anc_group_reg_custom_fe number_of_visits , suffix("") absorb(province month_1st) absorb_maputo_reg(month_1st)





/* EXIT INTERVIEW: PROCEDURES */
use "${DATA}/cleaned_data/anc_exit_interview_cleaned.dta", clear


merge m:1 facility_cod using  "${DATA}/aux/facility_characteristics.dta"
drop _merge
label_vars_anc

gen day_of_week = interview_weekday

egen proc_index = rowmean(HIV_test syphilis_test malaria_test malaria_pills malaria_net tetanus blood_pressure blood_test urine  weight examine_belly height uterine_height folic_acid ask_history delivery_place delivery_plan estimated  complications_sign nutrition questions)
egen proc_index_1st = rowmean(HIV_test syphilis_test  malaria_net  blood_test urine  height  ask_history  estimated)
egen proc_index_followup = rowmean(  malaria_test malaria_pills  tetanus blood_pressure  weight examine_belly uterine_height folic_acid  delivery_place delivery_plan estimated  complications_sign nutrition questions)


* controls

//global controls_facility volume_base_total  urban  score_basic_amenities score_basic_equipment  index_general_service index_ANC_readiness      
gen_controls

global controls_patient demog_age read_and_write educ_high_school married demog_kids demog_hh_kids_under5 

global controls $controls $controls_patient
global controls_without_urban $controls_without_urban $controls_patient
global controls_without_quality $controls_without_quality $controls_patient


* check missing values
mdesc $controls  
tab facility_cod if missing(index_general_service ) | missing(volume_base_total), m
// two facility codes (36 and 54) have all the observations missing for the control variables.

** regression adjustment approach to fill in missing values:
gen miss_control1 = missing(index_general_service) if !missing(facility_cod)
gen miss_control2 = missing(volume_base_total) if !missing(facility_cod)

qui sum volume_base_total
replace volume_base_total =  r(mean) if miss_control2 == 1

foreach var in score_basic_amenities  score_basic_equipment index_general_service index_anc_readiness {
	qui sum `var'
	replace `var' =  r(mean) if miss_control1 == 1
}

gen_controls

global controls $controls $controls_patient  miss_control1 miss_control2 
global controls_without_urban $controls_without_urban $controls_patient  miss_control1 miss_control2 
global controls_without_quality $controls_without_quality $controls_patient  miss_control1 miss_control2 


anc_group_reg proc_index_followup if anc_total == 1, suffix("on_1st_patients")


global controls score_basic_amenities   index_anc_readiness  index_general_service urban hospital  miss_control1 miss_control2 volume_base_total

* without volume_base_total all columns are significant

/*
foreach v in proc_index proc_index_1st proc_index_followup {
	anc_group_reg `v' if anc_total == 1, suffix("on_1st_patients")

	anc_group_reg `v' if anc_total > 1, controls($control_proc) absorb(province) filename("tables/procedures_followup_`v'.tex")

}*/

/* PATIENTS WAITING */
import delimited data/cleaned_data/patients_waiting.csv, clear

merge m:1 facility_cod using  "${DATA}/aux/facility_characteristics.dta"
drop _merge
label_vars_anc
gen_controls

anc_group_reg n_waiting_8 , suffix("")
anc_group_reg n_waiting_10 , suffix("")


/* VOLUME */

set more off
cd "$HOME"
use "${DATA}/cleaned_data/sisma_volume.dta", clear


drop _merge
merge m:1 facility_cod using "${DATA}/aux/facility_characteristics.dta", keepusing (complier complier10)
drop _merge

replace quarter2 = 1 if quarter2 == 2
replace quarter3 = 1 if quarter3 == 3

gen maputo = 0
replace maputo = 1 if province == "Maputo Cidade"
replace maputo = 1 if province == "Maputo Província"


global controls_vol score_basic_amenities score_basic_equipment index_general_service index_anc_readiness urban hospital

anc_volume_reg anc_followup , absorb(province ) filename("vol_test.tex") controls($controls_vol )

rename index_ANC_readiness index_anc_readiness
reghdfe anc_followup c.treatment##c.quarter1 c.treatment##c.quarter2 c.treatment##c.quarter3 $controls_vol, a(province) vce(cl facility_cod)

ivreghdfe anc_followup c.quarter1 c.quarter2 c.quarter3 (complier c.complier##c.quarter1 c.complier##c.quarter2 c.complier##c.quarter3 = treatment c.treatment##c.quarter1 c.treatment##c.quarter2 c.treatment##c.quarter3) $controls_vol if maputo==1, a(month) cluster(facility_cod)


ivreghdfe $outcome c.post (complier10 c.complier10##c.post = treatment c.treatment##c.post)  $controls_vol , absorb(month ) cluster(facility_cod)


/* WT - OPENING TIME */
// updated on 17/11/2023
use "${DATA}/cleaned_data/anc_opening_time.dta", clear

drop if opening_time == 0 // only one patient in that facility-day

merge m:1 facility_cod using "${DATA}/aux/facility_characteristics.dta"
drop _merge
label_vars_anc

anc_reg opening_time , controls($controls) absorb(province day_of_week) filename("tables/opening_time.tex")

anc_reg_het opening_time , controls($controls) absorb( day_of_week) filename("tables/opening_time_maputo_followup.tex") het_var(maputo)

anc_reg_het opening_time , controls($controls_without_urban) absorb( province day_of_week) filename("tables/opening_time_urban_followup.tex") het_var(urban)

anc_reg_het opening_time , controls($controls_without_quality) absorb( province day_of_week) filename("tables/opening_time_high_quality_followup.tex") het_var(high_quality)

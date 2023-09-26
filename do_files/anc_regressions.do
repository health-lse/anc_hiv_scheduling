
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
cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"
global anc_dataset "data/cleaned_data/anc_cpn_endline_v20230704.dta"
use $anc_dataset, clear
do do_files/anc_programs


/* CONTROLS */
gen_controls

keep if consultation_reason == 1
keep if waiting_time < 281 // remove outliers 5% - 1st

foreach x in waiting_time  more_than_3  before_7 time_arrived_float  {
	global outcome_var `x'
	anc_group_reg $outcome_var , suffix("1st")
}

use $anc_dataset, clear

keep if consultation_reason == 2
keep if waiting_time < 249 // remove outliers 5% - followups

foreach x in waiting_time  more_than_3  before_7 time_arrived_float  {
	global outcome_var `x'
	anc_group_reg $outcome_var , suffix("followup")
}


/* STANDARD DEVIATION OF THE WAITING TIME */
use $anc_dataset, clear
keep if consultation_reason == 1
collapse (sd) waiting_time  (first) treatment consultation_reason province day_of_week complier complier10 maputo gaza_inhambane high_quality $controls, by (facility_cod day)

label_vars_anc
rename waiting_time std_waiting_time

anc_group_reg std_waiting_time , suffix("1st")

use $anc_dataset, clear

keep if consultation_reason == 2
collapse (sd) waiting_time  (first) treatment consultation_reason province day_of_week complier complier10 maputo gaza_inhambane high_quality $controls, by (facility_cod day)

label_vars_anc
rename waiting_time std_waiting_time

anc_group_reg std_waiting_time , suffix("followup")





/* OPENING TIME */

use "data/cleaned_data/opening_time.dta", clear
capture drop _merge
label_vars_anc

merge m:1 facility_cod using "data/aux/facility_characteristics.dta"
drop _merge
label_vars_anc

anc_group_reg opening_time , suffix("")


/* REGISTRY BOOK: NUMBER OF VISITS */
cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"
use data/cleaned_data/anc_registry_book.dta, clear
label_vars_anc

gen number_of_visits = anc_total
label var number_of_visits "Number of visits"

anc_group_reg_custom_fe number_of_visits , suffix("") absorb(province month_1st) absorb_maputo_reg(month_1st)



/* EXIT INTERVIEW: PROCEDURES */
use "data/cleaned_data/anc_exit_interview_cleaned.dta", clear


merge m:1 facility_cod using  "data/aux/facility_characteristics.dta"
drop _merge
label_vars_anc

gen day_of_week = interview_weekday

egen proc_index = rowmean(HIV_test syphilis_test malaria_test malaria_pills malaria_net tetanus blood_pressure blood_test urine  weight examine_belly height uterine_height folic_acid ask_history delivery_place delivery_plan estimated  complications_sign nutrition questions)
egen proc_index_1st = rowmean(HIV_test syphilis_test  malaria_net  blood_test urine  height  ask_history  estimated)
egen proc_index_followup = rowmean(  malaria_test malaria_pills  tetanus blood_pressure  weight examine_belly uterine_height folic_acid  delivery_place delivery_plan estimated  complications_sign nutrition questions)

* controls

//global controls_facility volume_base_total  urban  score_basic_amenities score_basic_equipment  index_general_service index_ANC_readiness      

global controls_patient demog_age read_and_write educ_high_school married demog_kids demog_hh_kids_under5

global controls $controls $controls_patient
global controls_without_urban $controls_without_urban $controls_patient
global controls_without_quality $controls_without_quality $controls_patient

anc_group_reg proc_index_followup if anc_total == 1, suffix("on_1st_patients")

/*
foreach v in proc_index proc_index_1st proc_index_followup {
	anc_group_reg `v' if anc_total == 1, suffix("on_1st_patients")

	anc_group_reg `v' if anc_total > 1, controls($control_proc) absorb(province) filename("tables/procedures_followup_`v'.tex")

}*/

/* PATIENTS WAITING */
import delimited data/cleaned_data/patients_waiting.csv, clear

merge m:1 facility_cod using  "data/aux/facility_characteristics.dta"
drop _merge
label_vars_anc
gen_controls

anc_group_reg n_waiting_8 , suffix("")
anc_group_reg n_waiting_10 , suffix("")


/* VOLUME */

set more off
cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"
use "data/cleaned_data/sisma_volume.dta", clear


drop _merge
merge m:1 facility_cod using "data/aux/facility_characteristics.dta", keepusing (complier complier10)
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



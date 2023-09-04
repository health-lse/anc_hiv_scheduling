cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"

// merge facility characteristics with complier dataset
use "data/aux/facility_characteristics.dta", clear
capture drop _merge complier complier10
merge m:1 facility_cod using  "data/cleaned_data/complier.dta", keepusing(complier complier10)
drop _merge
save "data/aux/facility_characteristics.dta", replace

cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"

// load anc programs
do do_files/anc_programs

import delimited "data/cleaned_data/anc_cpn_endline_v20230704.csv", clear
label_vars_anc
save $anc_dataset, replace



global anc_dataset "data/cleaned_data/anc_cpn_endline_v20230704.dta"


global controls score_basic_amenities score_basic_equipment index_general_service index_anc_readiness urban hospital volume_base_total

global controls_without_urban score_basic_amenities score_basic_equipment index_general_service index_anc_readiness hospital volume_base_total

/* WAITING TIME */
global anc_dataset "data/cleaned_data/anc_cpn_endline_v20230704.dta"
do do_files/anc_programs
use $anc_dataset, clear
keep if consultation_reason == 1
keep if waiting_time < 281 // remove outliers 5% - 1st



anc_reg waiting_time if maputo == 1, controls($controls) absorb(province day_of_week) filename("tables/wt_1st_maputo_sample.tex") title("Waiting time - 1st visits") graph_name("graphics/wt_1st_maputo_sample.png")

anc_reg_het waiting_time , controls($controls) absorb( day_of_week) filename("tables/wt_maputo_interaction.tex") het_var(maputo)

gen gaza_inham = 0
replace gaza_inham = 1 if maputo == 0

anc_reg waiting_time if gaza_inham == 1, controls($controls) absorb(province day_of_week) filename("tables/wt_1st_gaza_sample.tex") title("Waiting time - 1st visits") graph_name("graphics/wt_1st_gaza_sample.png")

anc_reg_het waiting_time , controls($controls) absorb( day_of_week) filename("tables/wt_gaza_interaction.tex") het_var(gaza_inham)


anc_reg_het waiting_time , controls($controls) absorb( day_of_week) filename("tables/wt_gaza_fol.tex") het_var(gaza_inham)


anc_reg waiting_time , controls($controls) absorb(province day_of_week) filename("tables/wt_1st.tex")

anc_reg_het waiting_time , controls($controls) absorb( day_of_week) filename("tables/wt_maputo_1st.tex") het_var(maputo)

anc_reg_het waiting_time , controls($controls_without_urban) absorb(province day_of_week) filename("tables/wt_urban_1st.tex") het_var(urban)

anc_reg_het waiting_time , controls($controls) absorb(province day_of_week) filename("tables/wt_lowpat_1st.tex") het_var(low_pat_nurses)


use $anc_dataset, clear
keep if consultation_reason == 2
keep if waiting_time < 249 // remove outliers 5% - followups

anc_reg waiting_time , controls($controls) absorb(province day_of_week) filename("tables/wt_followup.tex")

anc_reg_het waiting_time , controls($controls) absorb( day_of_week) filename("tables/wt_maputo_followup.tex") het_var(maputo)

anc_reg_het waiting_time , controls($controls_without_urban) absorb(province day_of_week) filename("tables/wt_urban_followup.tex") het_var(urban)

anc_reg_het waiting_time , controls($controls) absorb(province day_of_week) filename("tables/wt_lowpat_followup.tex") het_var(low_pat_nurses)

anc_reg waiting_time if inlist(province, "Gaza", "Inhambane"), controls($controls) absorb(province day_of_week) filename("tables/wt_followup_gaza_inham.tex")




/* MORE THAN 3H */
use $anc_dataset, clear
keep if consultation_reason == 1
anc_reg more_than_3 , controls($controls) absorb(province day_of_week) filename("tables/wt_more_than_3_1st.tex")

anc_reg_het more_than_3 , controls($controls) absorb( day_of_week) filename("tables/wt_more_than_3_maputo_1st.tex") het_var(maputo)

anc_reg_het more_than_3 , controls($controls_without_urban) absorb(province day_of_week) filename("tables/wt_more_than_3_urban_1st.tex") het_var(urban)


use $anc_dataset, clear
keep if consultation_reason == 2
anc_reg more_than_3 , controls($controls) absorb(province day_of_week) filename("tables/wt_more_than_3_followup.tex")

anc_reg_het more_than_3 , controls($controls) absorb( day_of_week) filename("tables/wt_more_than_3_maputo_followup.tex") het_var(maputo)

anc_reg_het more_than_3 , controls($controls_without_urban) absorb(province day_of_week) filename("tables/wt_more_than_3_urban_followup.tex") het_var(urban)




/* WT - STANDARD DEVIATION */
use $anc_dataset, clear
collapse (sd) waiting_time (first) treatment consultation_reason province day_of_week complier complier10 maputo $controls, by (facility_cod day)

label_vars_anc
rename waiting_time std_waiting_time

keep if consultation_reason == 1
anc_reg std_waiting_time  , controls($controls) absorb(province day_of_week) filename("tables/std_waiting_time_1st.tex")

anc_reg_het std_waiting_time , controls($controls) absorb( day_of_week) filename("tables/std_waiting_time_maputo_1st.tex") het_var(maputo)

anc_reg_het std_waiting_time , controls($controls_without_urban) absorb( province day_of_week) filename("tables/std_waiting_time_urban_1st.tex") het_var(urban)

use $anc_dataset, clear
collapse (sd) waiting_time (first) treatment consultation_reason province day_of_week complier complier10 maputo $controls, by (facility_cod day)

label_vars_anc
rename waiting_time std_waiting_time
keep if consultation_reason == 2

anc_reg std_waiting_time , controls($controls) absorb(province day_of_week) filename("tables/std_waiting_time_followup.tex")

anc_reg_het std_waiting_time , controls($controls) absorb( day_of_week) filename("tables/std_waiting_time_maputo_followup.tex") het_var(maputo)

anc_reg_het std_waiting_time , controls($controls_without_urban) absorb( province day_of_week) filename("tables/std_waiting_time_urban_followup.tex") het_var(urban)


/* Percent that arrive before 7 */

use $anc_dataset, clear
collapse (mean) before_7 (first) treatment consultation_reason province day_of_week complier complier10 maputo $controls, by (facility_cod day)

label_vars_anc
keep if consultation_reason == 2

anc_reg before_7 , controls($controls) absorb(province day_of_week) filename("tables/before_7_followup.tex")

anc_reg_het before_7 , controls($controls) absorb( day_of_week) filename("tables/before_7_maputo_followup.tex") het_var(maputo)

anc_reg_het before_7 , controls($controls_without_urban) absorb( day_of_week) filename("tables/before_7_urban_followup.tex") het_var(urban)


/* Arrival time */
use $anc_dataset, clear
keep if consultation_reason == 2

anc_reg time_arrived_float , controls($controls) absorb(province day_of_week) filename("tables/arrival_time_followup.tex")

anc_reg time_arrived_float  if inlist(province, "Gaza", "Inhambane") , controls($controls) absorb(province day_of_week) filename("tables/arrival_time_followup_gaza_inhambane.tex")

anc_reg_het time_arrived_float , controls($controls) absorb( day_of_week) filename("tables/arrival_time_maputo_followup.tex") het_var(maputo)

anc_reg_het time_arrived_float , controls($controls_without_urban) absorb( province day_of_week) filename("tables/arrival_time_urban_followup.tex") het_var(urban)


/* WT - OPENING TIME */
use "data/cleaned_data/opening_time.dta", clear
capture drop _merge

merge m:1 facility_cod using "data/aux/facility_characteristics.dta"
drop _merge
label_vars_anc

anc_reg opening_time , controls($controls) absorb(province day_of_week) filename("tables/opening_time.tex")

anc_reg_het opening_time , controls($controls) absorb( day_of_week) filename("tables/opening_time_maputo_followup.tex") het_var(maputo)

anc_reg_het opening_time , controls($controls_without_urban) absorb( province day_of_week) filename("tables/opening_time_urban_followup.tex") het_var(urban)


/* Registry Book: Number of consultations */

cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"
use data/cleaned_data/anc_registry_book.dta, clear

merge m:1 facility_cod using "data/aux/facility_characteristics.dta"
drop _merge

//gen log_total = log(anc_total)
destring gestational_age_1st, replace
replace gestational_age_1st=. if gestational_age_1st > 45  //65 changes

global controls_rb $controls gestational_age_1st
global controls_rb_without_urban $controls_without_urban gestational_age_1st

label_vars_anc

capture drop last_consultation
gen last_consultation = date_1st_1
replace last_consultation = date_2nd_2 if last_consultation == ""
replace last_consultation = date_3rd_3 if last_consultation == ""
replace last_consultation = date_4th_4 if last_consultation == ""
replace last_consultation = date_5th_5 if last_consultation == ""
replace last_consultation = date_6th_6 if last_consultation == ""
drop if last_consultation == ""
drop date_last
gen date_last = date(last_consultation, "YMD")
replace date_last = date(last_consultation, "DMY") if date_last == .

// not affected by intervention
drop if date_last < mdy(10, 26, 2020) & maputo == 1
drop if date_last < mdy(12, 7, 2020) & maputo == 0

anc_reg anc_total , controls($controls_rb) absorb(province) filename("tables/registry_book.tex")

anc_reg_het anc_total , controls($controls_rb) absorb(  first_month) filename("tables/registry_book_maputo.tex") het_var(maputo)

anc_reg_het anc_total , controls($controls_rb_without_urban) absorb( province first_month) filename("tables/registry_book_urban.tex") het_var(urban)


//anc_reg anc_total if maputo == 0, controls($controls_rb) absorb(province) filename("tables/registry_book_test.tex")
//
//anc_reg anc_total if maputo == 1, controls($controls_rb) absorb(province) filename("tables/registry_book_test.tex")
//
//
//anc_reg gestational_age_1st if maputo == 0, controls($controls) absorb(province) filename("tables/registry_book_test.tex")
//
//
//anc_reg gestational_age_1st if maputo == 1, controls($controls) absorb(province) filename("tables/registry_book_test.tex")
//

/* Exit interview */
use "data/cleaned_data/anc_exit_interview_cleaned.dta", clear

merge m:1 facility_cod using  "data/aux/facility_characteristics.dta"
drop _merge


// index amanda
gen HIV_test = (consultation_HIV_test == "SIM, realizou durante a consulta")
gen syphilis_test = (consultation_syphilis_test == "SIM, realizou durante a consulta")
gen malaria_test = (consultation_malaria_test == "SIM, realizou durante a consulta")
gen malaria_pills = (consultation_malaria_pills != "NÃO")
gen tetanus = (consultation_tetanus != "NÃO")
foreach x in ask_history blood_pressure blood_test delivery_place delivery_plan estimated folic_acid height malaria_net  nutrition questions uterine_height urine weight examine_belly complications_sign {
gen `x' = (consultation_`x' == "Sim")
}

egen proc_index = rowmean(HIV_test syphilis_test malaria_test malaria_pills malaria_net tetanus blood_pressure blood_test urine  weight examine_belly height uterine_height folic_acid ask_history delivery_place delivery_plan estimated  complications_sign nutrition questions)
egen proc_index_1st = rowmean(HIV_test syphilis_test  malaria_net  blood_test urine  height  ask_history  estimated)
egen proc_index_followup = rowmean(  malaria_test malaria_pills  tetanus blood_pressure  weight examine_belly uterine_height folic_acid  delivery_place delivery_plan estimated  complications_sign nutrition questions)



* controls
replace demog_age=. if demog_age<10
gen read_and_write = (demog_read_and_write == "Sim")
gen educ_high_school = (demog_education == "11 .Superior" | demog_education == "6 .Ensino Secundário Geral do 2º Ciclo" | demog_education == "7 .Ensino Técnico Elementar" |  demog_education == "8 .Ensino Técnico Básico" |  demog_education == "9 .Ensino Técnico Médio" )
gen married = (demog_marital == "Casada / Mora com companheiro(a)")
replace demog_kids=0 if demog_kids==.
replace demog_hh_kids_under5=0 if demog_hh_kids_under5==.

global controls_facility volume_base_total  urban  score_basic_amenities score_basic_equipment  index_general_service index_ANC_readiness      

global controls_patient demog_age read_and_write educ_high_school married demog_kids demog_hh_kids_under5


reg proc_index treatment  if anc_total == 1
reg proc_index treatment  if anc_total > 1

reg proc_index_1st treatment if anc_total == 1
reg proc_index_1st treatment if anc_total > 1

reg proc_index_followup treatment if anc_total==1,cluster(facility_cod)
reg proc_index_followup treatment if anc_total > 1

global controls_patient demog_age read_and_write educ_high_school married demog_kids demog_hh_kids_under5

global control_proc $controls $controls_patient

anc_reg proc_index_followup if anc_total == 1, controls($control_proc) absorb(province) filename("tables/procedures_1st_proc_index_followup.tex")

foreach v in proc_index proc_index_1st proc_index_followup {
	anc_reg `v' if anc_total == 1, controls($control_proc) absorb(province) filename("tables/procedures_1st_`v'.tex")

	anc_reg `v' if anc_total > 1, controls($control_proc) absorb(province) filename("tables/procedures_followup_`v'.tex")

}

/**** OLD ****/

/* Arrived after 10 */
clear
import delimited "data/anc_cpn_endline_v20230704.csv"

gen arrived_after_10 = 0
replace arrived_after_10 = 1 if time_arrived >= 1000
anc_reg arrived_after_10 if consultation_reason==2 , controls($controls) absorb(province day_of_week) filename("tables/arrived_after_10.tex")


anc_reg time_arrived_float if consultation_reason == 2, controls($controls) absorb(province day_of_week) filename("tables/time_arrived.tex")

// volume - sisma
use "data/sisma/sisma_volume.dta", clear
//rename index_ANC_readiness index_anc_readiness

drop _merge
merge m:1 facility_cod using data/complier

keep if post == 0 | quarter1 == 1 |  quarter2 == 1 |  quarter3 == 1

gen log_1st = log(anc_1st)
gen log_followup = log(anc_followup)
gen log_total = log(anc_total)

do do_files/anc_programs
global controls score_basic_amenities score_basic_equipment index_ANC_readiness index_general_service urban hospital

gen maputo = 0
replace maputo = 1 if inlist( province, "Maputo Cidade", "Maputo Província")


foreach x in  log_1st log_followup  log_total {
	global outcome `x'

	anc_volume_reg $outcome , controls($controls) absorb(province month) filename("tables/`x'_volume.tex")
}

reghdfe log_total c.treatment##c.post $controls if maputo == 1, a( province month) vce(cl facility_cod)


/* REG COMPLIERS */

use "data/aux/facility_characteristics.dta", clear


reg complier distance_to_maputo $controls 
reg complier distance_to_maputo $controls if inlist( province, "Gaza", "Inhambane")


eststo clear
estimates clear

sysuse auto, clear
reghdfe price mpg turn, a(foreign)
estadd scalar wl_1 = 42
estimates store model1, title("OLS")

reghdfe price mpg turn, a(foreign)
estimates store model2, title("OLS")

estfe . model*, labels(foreign "foreign")


esttab *, stats(wl_1 r2 N)  indicate( "turn=turn" `r(indicate_fe)') star(* 0.10 ** 0.05 *** 0.01) drop(_cons) b(2) se(2) mlabels(,titles) replace

estfe . model*, restore

use "data/anc_registry_book.dta", clear 

replace facility_cod = 50 if facility_name == "CS Urbano" & facility_cod == .
replace facility_cod = 66 if facility_name == "CS Unidade 7"& facility_cod == .
replace facility_cod = 4 if facility_name == "CS Porto"& facility_cod == .


merge m:1 facility_cod using "data/facility_characteristics.dta"
drop _merge

merge m:1 facility_cod using "data/complier.dta"
drop _merge

global controls score_basic_amenities score_basic_equipment index_ANC_readiness index_general_service urban hospital volume_base_total

gen log_total = log(anc_total)
destring gestational_age_1st, replace
replace gestational_age_1st=. if gestational_age_1st > 45  //65 changes

global controls_registry_book $controls gestational_age_1st

gen pat_nurses = n_nurses / volume_base_total
anc_reg anc_total , controls($controls_registry_book) absorb(province) filename("tables/registry_book.tex")




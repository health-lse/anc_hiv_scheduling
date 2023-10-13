// This file contains functions to run regressions on the mozart and panel data and generate an output using esttab

// generate controls
capture program drop gen_controls
program gen_controls
	gen woman = (pac_sex=="F")
	rename pac_age age
	global controls_patient woman age 

	global controls_facility index_hiv_care_readiness art_different_lines art_general hand_wash dayaverage urban cd4 score_basic_amenities score_basic_equipment hiv_diagnostic_capacity index_general_service

	global controls index_hiv_care_readiness art_different_lines art_general hand_wash dayaverage urban cd4 score_basic_amenities score_basic_equipment hiv_diagnostic_capacity index_general_service $controls_patient 

	di "controls generated"
end


/* Add scalar info to the bottom of the tables */
capture program drop add_scalars_hiv
program add_scalars_hiv

	qui distinct facility_cod
	qui estadd scalar n_facilities = r(ndistinct)
	qui distinct facility_cod if treatment == 1
	qui estadd scalar n_compliers = r(ndistinct)
	qui capture estadd scalar iv_stat = e(widstat)
	
end

// Run 4 regressions:
// 1. no controls, period and province FE, cluster: facility
// 2.    controls, period and province FE, cluster: facility
// ADD IV REGRESSIONS
capture program drop mozart_reg
program mozart_reg
	syntax varlist(max=1) [if] [ , filename(string) controls(namelist) ]
	preserve
	if `"`if'"' != "" {
		keep `if'
	}

	global outcome `1'
	local controls `namelist'

	eststo clear
	estimates clear

	reghdfe $outcome treatment, a( period province) cluster(facility_cod)
	qui sum `e(depvar)' if e(sample)
	qui estadd scalar control_mean= r(mean)
	qui estadd scalar control_std= r(sd)
	*add_scalars_hiv
	qui estimates store model1, title("OLS")

	reghdfe $outcome treatment $controls, a( period province)  cluster(facility_cod)
	add_scalars_hiv
	qui estimates store model2, title("OLS")


	rename treatment treatment_iv
	rename complier treatment
	qui ivreghdfe $outcome (treatment=treatment_iv), absorb(period province) cluster(facility_cod)
	add_scalars_hiv
	qui estimates store model3, title("IV")

	qui ivreghdfe $outcome $controls (treatment=treatment_iv), absorb(period province) cluster(facility_cod)
	add_scalars_hiv
	qui estimates store model4, title("IV")

	drop treatment
	rename complier10 treatment
	qui ivreghdfe $outcome (treatment=treatment_iv), absorb(period province) cluster(facility_cod)
	add_scalars_hiv
	qui estimates store model5, title("IV ( \geq 10am) ")

	qui ivreghdfe $outcome $controls (treatment=treatment_iv), absorb(period province) cluster(facility_cod)
	add_scalars_hiv
	qui estimates store model6, title("IV ( \geq 10am) ")



	estfe . model* , labels(province "Province FE" period "Month FE")
	
	esttab  *, stats(control_mean control_std iv_stat  n_compliers  r2 N, label( "Control Mean" "Control SD"  "Kleibergen-Paap Wald F stat." "Compliers" "R2" "N" )) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace label


	estfe . model*, labels(province "Province FE" period "Month FE")

	esttab * using "`filename'", style(tex) stats(control_mean control_std iv_stat  n_compliers  r2 N, label( "Control Mean" "Control SD" "Kleibergen-Paap Wald F stat."  "Compliers" "R2" "N" )) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace label
	estfe . model*, restore

	restore
end


// Function with regressions for the panel with old patients. Includes a treatment#post interaction.	
capture program drop mozart_old_reg
program mozart_old_reg
	syntax varlist(max=1) [if] [ , filename(string) controls(namelist) ]
	preserve
	if `"`if'"' != "" {
		keep `if'
	}

	global outcome `1'
	local controls `namelist'

	eststo clear
	estimates clear

	reghdfe $outcome c.treatment##c.post, a( province ) vce(cl facility_cod)
	estimates store model1


	reghdfe $outcome c.treatment##c.post $controls, a( province)  vce(cl facility_cod)
	estimates store model2

	estfe . model*, labels(province "Province FE" district "District FE" )
		
	esttab model*  using "`filename'", style(tex) stats(r2 N) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls" `r(indicate_fe)') se replace
	estfe . model*, restore

	restore
end


// Function used for regressions at the patient level. Different from the functions above because it does not include period FE
capture program drop mozart_reg_patient_data
program mozart_reg_patient_data
	syntax varlist(max=1) [if] [ , filename(string) controls(namelist) ]
	preserve
	if `"`if'"' != "" {
		keep `if'
	}

	global outcome `1'
	local controls `namelist'

	eststo clear
	estimates clear

	reghdfe $outcome treatment, a( province ) vce(cl facility_cod)
	estimates store model1

	reghdfe $outcome treatment, a( district ) vce(cl facility_cod)
	estimates store model2

	reghdfe $outcome treatment $controls, a( province)  vce(cl facility_cod)
	estimates store model3

	reghdfe $outcome treatment $controls, a( district)  vce(cl facility_cod)
	estimates store model4

	estfe . model*, labels(province "Province FE" district "District FE" period "Period FE")
		
	esttab model*  using "`filename'", style(tex) stats(r2 N) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls" `r(indicate_fe)') se replace
	estfe . model*, restore

	restore
end

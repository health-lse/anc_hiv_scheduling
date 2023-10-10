// This file contains functions to run regressions on the mozart and panel data and generate an output using esttab

// generate controls
capture program drop gen_controls
program gen_controls
	gen woman = (pac_sex=="F")
	rename pac_age age
	global controls_patient woman age 

	global controls_facility index_HIV_care_readiness ART_different_lines ART_general hand_wash dayaverage urban CD4 score_basic_amenities score_basic_equipment HIV_diagnostic_capacity index_general_service

	global controls index_HIV_care_readiness ART_different_lines ART_general hand_wash dayaverage urban CD4 score_basic_amenities score_basic_equipment HIV_diagnostic_capacity index_general_service $controls_patient 

	di "controls generated"
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

	reghdfe $outcome treatment, a( period province) vce(cl facility_cod)
	qui sum `e(depvar)' if e(sample)
	estadd scalar Mean= r(mean)
	estimates store model1

	reghdfe $outcome treatment $controls, a( period province)  vce(cl facility_cod)
	estimates store model2

	estfe . model* , labels(province "Province FE" period "Month FE")
	esttab model*   using "`filename'", drop(_cons) style(tex) stats(Mean r2 N) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls" `r(indicate_fe)') se replace
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

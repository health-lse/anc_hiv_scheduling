/*Functions to run ANC regressions. It runs:
	* one regression with controls without fe
	* one regression without controls with fe
	* one regression witho controls and fe
	* save the results in a tex file using the filename param
*/
capture program drop anc_reg
program anc_reg
	syntax varlist( max=1) [if] [ , absorb(namelist) filename(string) controls(namelist)  ]
	preserve
	if `"`if'"' != "" {
		keep `if'
	}

	di `interaction'
	global outcome `1'
	global fixed_effects `absorb'
	global controls_reg `controls'

	eststo clear
	estimates clear

	qui reg $outcome treatment 
	

	qui reghdfe $outcome treatment, a($fixed_effects) vce(cl facility_cod)
	qui sum $outcome if treatment==0
	qui estadd scalar control_mean= r(mean)
	qui estimates store model1, title("OLS")

	qui reghdfe $outcome treatment $controls_reg , a( $fixed_effects ) vce(cl facility_cod)
	qui estimates store model2, title("OLS")

	qui ivreghdfe $outcome (complier=treatment), absorb($fixed_effects) cluster(facility_cod)
	qui estimates store model3, title("IV")

	qui ivreghdfe $outcome $controls_reg (complier=treatment), absorb($fixed_effects) cluster(facility_cod)
	qui estimates store model4, title("IV")

	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE")
	
	esttab  *, stats(control_mean r2 N)star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace
	
	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE")
	
	esttab * using "`filename'", style(tex) stats(control_mean r2 N)star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace
	estfe . model*, restore

	restore
end

capture program drop anc_reg_het
program anc_reg_het
	syntax varlist( max=1) [if] [ , absorb(namelist) filename(string) controls(namelist) het_var(namelist) ]
	preserve
	if `"`if'"' != "" {
		keep `if'
	}

	di `interaction'
	global outcome `1'
	global fixed_effects `absorb'
	local controls_reg `controls'

	eststo clear
	estimates clear

	qui reghdfe $outcome c.treatment##c.`het_var', a($fixed_effects) vce(cl facility_cod)
	qui sum $outcome if treatment==0
	qui estadd scalar control_mean= r(mean)
	qui estimates store model1, title("OLS")

	qui reghdfe $outcome c.treatment##c.`het_var' $controls_reg, a($fixed_effects) vce(cl facility_cod)
	qui estimates store model2, title("OLS")
	
	qui ivreghdfe $outcome c.complier##c.`het_var' (complier=treatment), absorb($fixed_effects) cluster(facility_cod)
	qui estimates store model3, title("IV")

	qui ivreghdfe $outcome c.complier##c.`het_var' (complier=treatment) $controls_reg, absorb($fixed_effects) cluster(facility_cod)
	qui estimates store model4, title("IV")

	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE" district "District FE")
	//return list

	esttab  *, stats(control_mean r2 N)star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace
	
	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE" district "District FE")
	
	esttab * using "`filename'", style(tex) stats(control_mean r2 N)star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace
	estfe . model*, restore

	restore
end

/*
/*reghdfe $outcome treatment pat_nurses $controls , a( $fixed_effects ) vce(cl facility_cod)
	estimates store model3, title("OLS")*/
	
/*ivreghdfe $outcome pat_nurses $controls (complier=treatment), absorb($fixed_effects) cluster(facility_cod)
	estimates store model6, title("IV")*/


reg $outcome treatment, cluster(facility_cod)
	qui sum `e(depvar)' if e(sample) & treatment==0
	estadd scalar Mean= r(mean)
	estimates store model1

if `log_reg' != 0 {
		gen log_outcome = log($outcome)
	reghdfe log_outcome treatment $controls , a( $fixed_effects ) vce(cl facility_cod)
	estimates store model5
	}
	
if `log_reg' != 0 {
		gen log_complier = log($outcome)
		ivreghdfe log_complier $controls (complier=treatment), absorb($fixed_effects) cluster(facility_cod)
	estimates store model8
	}
*/


capture program drop anc_volume_reg
program anc_volume_reg
	syntax varlist(max=1) [if] [ , absorb(namelist) filename(string) controls(namelist) ]
	preserve
	if `"`if'"' != "" {
		keep `if'
	}

	global outcome `1'
	global fixed_effects `absorb'
	local controls_reg `namelist'

	eststo clear
	estimates clear

	reghdfe $outcome c.treatment##c.post##maputo, a( month) vce(cl facility_cod)
	estimates store model1, title("OLS")

	reghdfe $outcome c.treatment##c.post##maputo $controls_reg, a(  month) vce(cl facility_cod)
	estimates store model2, title("OLS")

	ivreghdfe $outcome c.post (complier c.complier##c.post = treatment c.treatment##c.post)  $controls_reg , absorb(month province) cluster(facility_cod)
	estimates store model3, title("IV")

/*	ivreghdfe $outcome (complier complier##quarter1 complier##quarter2 complier##quarter3 = treatment treatment##quarter1 treatment##quarter2 treatment##quarter3) $controls, absorb($fixed_effects) cluster(facility_cod)
	estimates store model4, title("IV")*/

	estfe . model*, labels(province "Province FE" month "Month FE")

esttab model*  using "`filename'", style(tex) stats(r2 N) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons ) se replace mlabels(,titles)

estfe . model*, restore

	restore
end


capture program drop anc_test
program anc_test
syntax varlist() [if] [ , absorb(namelist) filename(string) controls(namelist) log_reg(integer 1) ]
	reg `varlist'
end




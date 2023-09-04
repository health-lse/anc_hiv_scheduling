/*Functions to run ANC regressions. It runs:
	* one regression with controls without fe
	* one regression without controls with fe
	* one regression witho controls and fe
	* save the results in a tex file using the filename param
*/

capture program drop gen_high_quality
program define gen_high_quality
	capture drop high_quality
	gen high_quality = 0
	replace high_quality = 1 if quality_pca >= .543
end

capture program drop label_vars_anc
program define label_vars_anc
	label var treatment "Treatment"
	label var complier "Treatment"
	label var complier10 "Treatment"
	capture label var high_quality "High Quality"
	capture label var urban "Urban"
	capture label var maputo "Maputo"
	capture label var gaza_inhambane "Gaza/Inhamb."
end

/* Add scalar info to the bottom of the tables */
capture program drop add_scalars_anc
program add_scalars_anc

	qui distinct facility_cod
	qui estadd scalar n_facilities = r(ndistinct)
	qui distinct facility_cod if treatment == 1
	qui estadd scalar n_compliers = r(ndistinct)
end

capture program drop coefplot_anc
program coefplot_anc
	// coefplot
		coefplot (model1, label("OLS-No controls") msymbol(S) ) ///
		(model2, label("OLS")) ///
		(model3, label("IV-No controls")  msymbol(S)) ///
		(model4, label("IV")) ///
		(model5, label("IV 10am - No controls") msymbol(S))/// 
		(model6, label("IV 10am")), keep(treatment) xline(0) format(%9.2g) mlabel mlabposition(14) title("`title'", span size(medium) color(gs5)) xscale(lcolor(gs5)) xlabel("", labels labsize(small) labcolor(gs5) tlcolor(gs5) nogrid) yscale(lcolor(gs5)) ylabel(, labels labsize(small) labcolor(gs5) tlcolor(gs5)) graphregion(fcolor(white) lcolor(white)) plotregion(fcolor(white) lcolor(white)) legend(rows(3) size(small) symplacement(center) color(gs5)) xscale(r(0))
		graph export "`graph_name'", as(png) replace
		restore
end


capture program drop anc_reg
program anc_reg
	syntax varlist( max=1) [if] [ , absorb(namelist) filename(string) graph_name(string) title(string) controls(namelist) ]
	preserve
	if `"`if'"' != "" {
		keep `if'
	}

	global outcome `1'
	global fixed_effects `absorb'
	global controls_reg `controls'

	eststo clear
	estimates clear


	qui reghdfe $outcome treatment, a($fixed_effects) vce(cl facility_cod)
	qui sum $outcome if treatment==0
	qui estadd scalar control_mean= r(mean)
	qui estadd scalar control_std= r(sd)

	add_scalars_anc
	qui estimates store model1, title("OLS")

	qui reghdfe $outcome treatment $controls_reg , a( $fixed_effects ) vce(cl facility_cod)
	add_scalars_anc
	qui estimates store model2, title("OLS")

	// so that we have only one row in the regression table,
	// I change the name of complier to treatment 
	rename treatment treatment_iv
	rename complier treatment
	//qui ivreghdfe $outcome (complier=treatment), absorb($fixed_effects) cluster(facility_cod)
	qui ivreghdfe $outcome (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model3, title("IV")

	qui ivreghdfe $outcome $controls_reg (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model4, title("IV")

	drop treatment
	rename complier10 treatment
	qui ivreghdfe $outcome (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model5, title("IV ( \geq 10am) ")

	qui ivreghdfe $outcome $controls_reg (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model6, title("IV ( \geq 10am) ")

	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE" first_month "First Month FE")

	esttab  *, stats(control_mean control_std  n_compliers  r2 N, label( "Control Mean" "Control SD" "Compliers" "R2" "N" )) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace label

	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE" first_month "First Month FE")

	esttab * using "`filename'", style(tex) stats(control_mean control_std  n_compliers  r2 N, label( "Control Mean" "Control SD"  "Compliers" "R2" "N" )) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace label
	estfe . model*, restore

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
	global controls_reg `controls'

	eststo clear
	estimates clear

	qui reghdfe $outcome c.treatment##c.`het_var', a($fixed_effects) vce(cl facility_cod)
	qui sum $outcome if treatment==0
	qui estadd scalar control_mean= r(mean)
	qui estadd scalar control_std= r(sd)
	add_scalars_anc
	qui estimates store model1, title("OLS")

	qui reghdfe $outcome c.treatment##c.`het_var' $controls_reg, a($fixed_effects) vce(cl facility_cod)
	add_scalars_anc
	qui estimates store model2, title("OLS")
	
	rename treatment treatment_iv
	rename complier treatment
	
	qui ivreghdfe $outcome c.`het_var' (treatment c.treatment##c.`het_var' = treatment_iv c.treatment_iv##c.`het_var'), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model3, title("IV")

	qui ivreghdfe $outcome c.`het_var' (treatment c.treatment##c.`het_var' = treatment_iv c.treatment_iv##c.`het_var') $controls_reg, absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model4, title("IV")
	
	drop treatment
	rename complier10 treatment
	qui ivreghdfe $outcome c.`het_var' (treatment c.treatment##c.`het_var' = treatment_iv c.treatment_iv##c.`het_var'), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model5, title("IV ( \geq 10am) ")

	qui ivreghdfe $outcome c.`het_var' (treatment c.treatment##c.`het_var' = treatment_iv c.treatment_iv##c.`het_var') $controls_reg, absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model6, title("IV ( \geq 10am) ")
	
	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE" district "District FE")
	//return list

	esttab  *, stats(control_mean control_std  n_compliers  r2 N, label( "Control Mean" "Control SD" "Compliers" "R2" "N" )) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace interaction(" X ") label
	
	estfe . model*, labels(province "Province FE" day_of_week "Day of week FE" district "District FE")
	
	esttab * using "`filename'", style(tex) stats(control_mean control_std  n_compliers  r2 N, label( "Control Mean" "Control SD" "Compliers" "R2" "N" )) star(* 0.10 ** 0.05 *** 0.01) indicate("Controls=$controls_reg" `r(indicate_fe)') drop(_cons) se  mlabels(,titles) replace interaction(" X ") label
	estfe . model*, restore

	restore
end

capture program drop anc_group_reg
program anc_group_reg
	syntax varlist( max=1) [if] [ , suffix(string) ]
	global outcome `1'
	//anc_reg $outcome , controls($controls) absorb(province day_of_week) filename("tables/`1'_`suffix'.tex")

	//anc_reg_het $outcome , controls($controls) absorb( day_of_week) filename("tables/`1'_maputo_`suffix'.tex") het_var(maputo)


	//anc_reg_het $outcome , controls($controls) absorb( day_of_week) filename("tables/`1'_gaza_inhambane_`suffix'.tex") het_var(gaza_inhambane)

	//anc_reg_het $outcome , controls($controls_without_urban) absorb(province day_of_week) filename("tables/`1'_urban_`suffix'.tex") het_var(urban)

	//anc_reg_het $outcome , controls($controls_without_quality) absorb(province day_of_week) filename("tables/`1'_quality_pca_`suffix'.tex") het_var(quality_pca)
	
	anc_group_reg_custom_fe $outcome , suffix(`suffix') absorb(province day_of_week) absorb_maputo_reg(day_of_week)

end


capture program drop anc_group_reg_custom_fe
program anc_group_reg_custom_fe
	syntax varlist( max=1) [if] [ , suffix(string) absorb(namelist) absorb_maputo_reg(namelist) ]

	global absorb `absorb'
	global absorb_maputo_reg `absorb_maputo_reg'

	global outcome `1'
	anc_reg $outcome , controls($controls) absorb($absorb) filename("tables/`1'_`suffix'.tex")

	anc_reg_het $outcome , controls($controls) absorb($absorb_maputo_reg) filename("tables/`1'_maputo_`suffix'.tex") het_var(maputo)

	anc_reg_het $outcome , controls($controls) absorb( $absorb_maputo_reg) filename("tables/`1'_gaza_inhambane_`suffix'.tex") het_var(gaza_inhambane)

	anc_reg_het $outcome , controls($controls_without_urban) absorb($absorb) filename("tables/`1'_urban_`suffix'.tex") het_var(urban)

	anc_reg_het $outcome , controls($controls_without_quality) absorb($absorb) filename("tables/`1'_high_quality_`suffix'.tex") het_var(high_quality)

end

/* Generate the pca of quality indicators */
capture program drop gen_quality_pca
program gen_quality_pca
	qui pca index_anc_readiness index_general_service score_basic_amenities score_basic_equipment
	qui predict quality_pca
end



/*

	qui ivreghdfe $outcome c.treatment##c.`het_var' (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model3, title("IV")

	qui ivreghdfe $outcome c.treatment##c.`het_var' (treatment=treatment_iv) $controls_reg, absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model4, title("IV")
	
	drop treatment
	rename complier10 treatment
	qui ivreghdfe $outcome c.treatment##c.`het_var' (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model5, title("IV ( \geq 10am) ")

	qui ivreghdfe $outcome c.treatment##c.`het_var' (treatment=treatment_iv) $controls_reg, absorb($fixed_effects) cluster(facility_cod)
	add_scalars_anc
	qui estimates store model6, title("IV ( \geq 10am) ")



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




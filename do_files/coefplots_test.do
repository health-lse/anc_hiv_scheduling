cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"

do do_files/anc_programs

import delimited "data/cleaned_data/anc_cpn_endline_v20230704.csv", clear
label_vars_anc

use $anc_dataset, clear
keep if consultation_reason == 1
keep if waiting_time < 281

global outcomes waiting_time before_7 more_than_3 time_arrived_float


capture drop program anc_var_reg
program anc_var_reg
	syntax varlist( max=1) [if] [ , file_sufix(string)
	
	anc_reg $outcome_var if consultation_reason == 1, controls($controls) absorb(province day_of_week) filename("tables/`x'_1st.tex")

	anc_reg_het $outcome_var , controls($controls) absorb( day_of_week) filename("tables/`x'_maputo_`file_sufix'.tex") het_var(maputo)

	anc_reg_het $outcome_var , controls($controls_without_urban) absorb(province day_of_week) filename("tables/`x'_urban_1st.tex") het_var(urban)

end

foreach x of varlist $outcomes {
	di `x'
	global outcome_var `x'
	// first visits
	anc_var_reg $outcome_var if consultation_reason == 1, file_sufix("1st")

	// followup
	anc_var_reg $outcome_var if consultation_reason == 2, file_sufix("followup")

}


std_waiting_time  opening_time


/* TESTE */
sysuse auto, clear

regress price mpg trunk length turn if foreign==0

estimates store D

regress price mpg trunk length turn if foreign==1

estimates store F

regress weight mpg trunk length turn if foreign==0

estimates store D_weight

regress weight mpg trunk length turn if foreign==1

estimates store F_weight


coefplot (D, label(Domestic)) (F, label(Foreign)), bylabel(Price)   ///
       || (D_weight) (F_weight) , bylabel(Weight)  ///
       ||, drop(_cons) xline(0) byopts(xrescale)


use $anc_dataset, clear
keep if consultation_reason == 1
global controls score_basic_amenities score_basic_equipment index_general_service index_anc_readiness urban hospital volume_base_total

global fixed_effects province day_of_week
qui reghdfe waiting_time treatment, a($fixed_effects) vce(cl facility_cod)
estimates store WT_no_c

qui reghdfe waiting_time treatment $controls , a( $fixed_effects ) vce(cl facility_cod)
estimates store WT_c

rename treatment treatment_iv	
rename complier treatment

qui ivreghdfe waiting_time (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
qui estimates store IV_no_C, title("IV")

qui ivreghdfe waiting_time $controls (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
qui estimates store IV_C, title("IV")

drop treatment
rename complier10 treatment
qui ivreghdfe waiting_time (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
qui estimates store IV_10_no_C, title("IV ( \geq 10am) ")

qui ivreghdfe waiting_time $controls (treatment=treatment_iv), absorb($fixed_effects) cluster(facility_cod)
qui estimates store IV_10_C, title("IV ( \geq 10am) ")

global color1 "ebblue"

coefplot (WT_no_c, label("OLS-No controls") msymbol(S) ciopts(color($color1 )) color($color1 ) ) (WT_c, label("OLS") ciopts(color(ebblue)) color(ebblue)) (IV_no_C, label("IV-No controls")  msymbol(S) color(erose) ciopts(color(erose))) (IV_C, label("IV")) (IV_10_no_C, label("IV 10am - No controls")  msymbol(S)) (IV_10_C, label("IV 10am")), keep(treatment) xline(0) format(%9.2g) mlabel mlabsize(large) mlabposition(14) title("Waiting time - 1st visits", span  color(gs5)) ///
		xscale(lcolor(gs5)) xlabel("", labels labsize(medium) labcolor(gs5) tlcolor(gs5) nogrid) ///
		yscale(lcolor(gs5)) ylabel(, labels labsize(medium) labcolor(gs5) tlcolor(gs5)) ///
		graphregion(fcolor(white) lcolor(white)) plotregion(fcolor(white) lcolor(white)) ///
		legend(rows(3) size(medium) symplacement(center) color(gs5)) xscale(r(0)) ysize(7) xsize(13)




 span size(medium) color(gs5)) ///
		xscale(lcolor(gs5)) xlabel("", labels labsize(small) labcolor(gs5) tlcolor(gs5) nogrid) ///
		yscale(lcolor(gs5)) ylabel(, labels labsize(small) labcolor(gs5) tlcolor(gs5)) ///
		graphregion(fcolor(white) lcolor(white)) plotregion(fcolor(white) lcolor(white)) ///
		legend(rows(1) size(small) symplacement(center) color(gs5)) //
	graph export "${graphics}\d_mpr_affected_refill_FINAL.png", as(png) replace

cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"

// load anc programs
do do_files/anc_programs











qui reghdfe waiting_time treatment, a($fixed_effects) vce(cl facility_cod)
estimates store WT
coefplot (WT, label(Waiting Time)), drop(_cons) xline(0) byopts(xrescale) title("Waiting Time")



forvalues i=2017/2020 {
	global save d_mpr_cohort_affected_refill.xls
	global outcome d_mpr 
	global est_d_mpr d_mpr_`i'
	reghdfe  $outcome c.treatment##c.post if cohort==`i'  , absorb(nid facility_cod id_month pick_up_month pick_up_dow) vce(cl nid facility_cod )
	//outreg2 using $save, addt(Month FE , Y,  Clinic FE, Y, Patient FE , Y, Day of the week FE , Y, Month of the year FE , Y)  adjr2  append label nocons ct(`i') 
	estimates store $est_d_mpr 
}
coefplot  (d_mpr_2020, label(2020)) (d_mpr_2019, label(2019)) (d_mpr_2018, label(2018)) (d_mpr_2017, label(<2017))  , ///
		drop(_cons post)  vertical  yline(0) ///
		title("Effect on P(MPR > .95) for different cohorts", span size(medium) color(gs5)) ///
		xscale(lcolor(gs5)) xlabel("", labels labsize(small) labcolor(gs5) tlcolor(gs5) nogrid) ///
		yscale(lcolor(gs5)) ylabel(, labels labsize(small) labcolor(gs5) tlcolor(gs5)) ///
		graphregion(fcolor(white) lcolor(white)) plotregion(fcolor(white) lcolor(white)) ///
		legend(rows(1) size(small) symplacement(center) color(gs5)) //
	graph export "${graphics}\d_mpr_affected_refill_FINAL.png", as(png) replace


//reghdfe complier $controls distance_to_province_capital if treatment == 1, vce(cl province) absorb(district)

//reghdfe complier10 $controls distance_to_province_capital if treatment == 1, vce(cl province) absorb(district)

//logistic complier urban hospital distance_to_province_capital if treatment == 1

//ivreghdfe waiting_time c.maputo (complier10 c.complier10##c.maputo = treatment c.treatment##c.maputo) $controls , absorb(day_of_week) cluster(facility_cod)

//ivreghdfe waiting_time complier (complier = treatment)  if maputo == 1, absorb(day_of_week) cluster(facility_cod)


use $anc_dataset, clear
keep if consultation_reason == 1
keep if waiting_time < 281

anc_reg waiting_time if maputo == 0, controls($controls) absorb( day_of_week) filename("tables/wt_followup_test.tex")

anc_reg waiting_time if maputo == 1, controls($controls) absorb( day_of_week) filename("tables/wt_followup_test.tex")

gen gaza_inham = 0
replace gaza_inham = 1 if maputo == 0
anc_reg_het waiting_time , controls($controls) absorb( day_of_week) filename("tables/test_.tex") het_var(gaza_inham)

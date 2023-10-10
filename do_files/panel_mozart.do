// Run the regressions on the mozart data
clear
set more off, perm

// set the root, from here on I use only relative paths
cd /Users/rafaelfrade/arquivos/desenv/lse/adm_data/art_intervention/panel/

// load regression functions
do do_files/mozart_reg_functions

// *****
// Panel with patients that got 30 pills in all their pickups
use data/panel_new_30.dta, clear
merge m:1 facility_cod using "data/facility_characteristics.dta"
drop _merge

// function to generate controls
gen_controls

gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

mozart_reg days_without_med , controls($controls) filename("tables/new_30_days.tex")
mozart_reg mpr , controls($controls) filename("tables/new_30_mpr.tex")
mozart_reg mpr_95 , controls($controls) filename("tables/new_30_mpr_95.tex")
mozart_reg delay_7 , controls($controls) filename("tables/new_30_delay_7.tex")

// *****
// Panel with new patients that got any amount of pills
use data/panel_new_all.dta,clear
merge m:1 facility_cod using "data/facility_characteristics.dta"
drop _merge

gen_controls
gen mpr_95 = mpr > 0.95

mozart_reg days_without_med , controls($controls) filename("tables/new_all_days.tex")
mozart_reg mpr , controls($controls) filename("tables/new_all_mpr.tex")
mozart_reg mpr_95 , controls($controls) filename("tables/new_all_mpr_95.tex")
mozart_reg delay_7 , controls($controls) filename("tables/new_all_delay_7.tex")



// 2 MONTHS
// set the root, from here on I use only relative paths
cd /Users/rafaelfrade/arquivos/desenv/lse/adm_data/art_intervention/panel/

use data/panel_2m.dta,clear
// load regression functions
do do_files/mozart_reg_functions
merge m:1 facility_cod using "data/facility_characteristics.dta"
drop _merge

gen_controls

global controls $controls baseline_pickups_per_month

mozart_reg days_without_med , controls($controls) filename("tables/days_without_2m.tex")


mozart_reg mpr , controls($controls) filename("tables/mpr_2m.tex")


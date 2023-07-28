clear
local n=1000
set obs `n'
set seed 1234

* X-var
gen x=runiform()
* True fun
gen mu=4*x-2+0.8*exp(-256*(x-0.5)^2)
* A continuous covariate
gen w=runiform()*2-1
* A binary covariate
gen t=(runiform()>0.5)
* error term
gen eps=rnormal()
* A cluster id, only for illustration purpose
gen id=ceil(_n/2)
* Y-var
gen y=mu+w+t+eps
* A binary outcome
gen d=(runiform()<=x/(.5+x))

keep y x w t d id

binsreg y x w, absorb(t) at(mean) dots(0,0) line(3,3) ci(3,3) cb(3,3)


cd "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"

global anc_dataset "data/cleaned_data/anc_cpn_endline_v20230704.dta"
use $anc_dataset, clear


global controls_without_urban score_basic_amenities score_basic_equipment index_general_service index_anc_readiness hospital volume_base_total

global controls score_basic_amenities score_basic_equipment index_general_service index_anc_readiness urban hospital volume_base_total

global controls score_basic_amenities score_basic_equipment index_general_service index_anc_readiness  hospital volume_base_total 


use $anc_dataset, clear
keep if consultation_reason == 2
binsreg waiting_time urban $controls  if province == "Maputo Cidade", absorb(day_of_week) ci(3,3) by(treatment) vce(cl facility_cod)

binsreg waiting_time urban $controls  if province == "Maputo Província", absorb(day_of_week) ci(3,3) by(treatment) vce(cl facility_cod)

binsreg waiting_time urban $controls  if province == "Gaza", absorb(day_of_week) ci(3,3) by(treatment) vce(cl facility_cod)

binsreg waiting_time urban $controls  if province == "Inhambane", absorb(day_of_week) ci(3,3) by(treatment) vce(cl facility_cod)


binsreg waiting_time  $controls  if urban == 0, absorb(day_of_week) ci(3,3) by(treatment) vce(cl facility_cod)

binsreg waiting_time province_cod $controls  if urban == 1, absorb(day_of_week) ci(3,3) by(treatment) vce(cl facility_cod)


// Binscatter by provider survey - baseline


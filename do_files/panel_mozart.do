
************************************************************************************
*** 0. Preliminary
************************************************************************************
 
*** 0.1. Description:
* This scripts runs the hiv analyses on mozart data

*** 0.1.1. Input datasets
*	panel_new_30.dta: 
*   panel_new_all.dta, 
*   "${DATA}cleaned_data/hiv_complier_facilities.dta", from hiv_regressions.do, used to add the complier variables

*** 0.1.2. Output datasets
*   "${DATA}cleaned_data/hiv_pickups_ym.dta", with number of pickups and patients by facility-month
*   "${DATA}cleaned_data/hiv_patients_pickups.dta", with number of pickups by patient (from 11_2020 onwards)

*** 0.1.3. Legend:
// [QUESTION] 	look up this expression to find questions or doubts throughout the code
// [ISSUE]		look up this expression to find issues and things that need to be improved
// [ADD]		look up this expression to find notes on what needs to be added to the code


*** 0.2. MACRO definition
clear
set more off

global HOME     "/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling/"
cd              "${HOME}"
global DATA     "${HOME}data/"
global MOZART     "${HOME}data/cleaned_data/mozart/"
global graphs   "${HOME}graphs/mozart/"
global white    "graphregion(fcolor(white))"

*** 0.3. import the relevant packages and programs
do do_files/mozart_reg_functions
*ssc install erepost
*ssc install fuzzydid
*net install catcibar, from("https://aarondwolf.github.io/catcibar")

************************************************************************************
*** 1. Generate the datasets for the volume analysis 
************************************************************************************
 
 * 1.1. Create the monthly panel
use "${MOZART}data_merge_pre_stata.dta", clear

preserve 
    use "${DATA}aux/facility_characteristics.dta", clear

    * facility_name has spaces in using but not in master data
    replace facility_name = subinstr(facility_name," ","",.)
    keep facility* maputo
    tempfile facility_characteristics
    save `facility_characteristics'
restore

merge m:1 facility_name using `facility_characteristics'
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                       155,534
        from master                   155,534  (_merge==1)
        from using                          0  (_merge==2)

    Matched                         2,415,345  (_merge==3)
    -----------------------------------------
*/
keep if _m==3
drop _m

* generate the monthly pickup date
gen pickup_date = date(trv_date_pickup_drug, "YMD")
gen pickup_month = mofd(pickup_date)
format pickup_date %td
format pickup_month %tm
gen quarter = quarter(pickup_date)
gen month = month(pickup_date)

destring trv_quantity_taken, replace force // 8488 "NA" observations replaced as .
// [ISSUE] quantity taken needs to be cleaned  // rafael dropped observations with more than 360 pills
/*
                        trv_quantity_taken
    -------------------------------------------------------------
        Percentiles      Smallest
    1%            0             -8
    5%           30             -4
    10%           30             -1       Obs           1,987,751
    25%           30              0       Sum of wgt.   1,987,751

    50%           30                      Mean           82.12888
                            Largest       Std. dev.      897.5556
    75%           90          76680
    90%           90          76860       Variance       805606.1
    95%           90          77340       Skewness       45.68512
    99%          180          77460       Kurtosis       2551.362
*/

* for now I winsorize at 95%: !!!strong assumption, maybe it is just better to drop those observations/patients?
replace trv_quantity_taken = 90 if trv_quantity_taken > 90

* keep pickups with trv_quantity_taken>=0
drop if trv_quantity_taken<=0

* record the date of the first pickup for each patient (needed to label new patients)
bys nid (pickup_date): gen day_pickup1 = pickup_date[1]
bys nid (pickup_date): gen month_pickup1 = pickup_month[1]
format day_pickup1 %td
format month_pickup1 %tm

/*  # of pickups before 2018 is much smaller, and after September 2021 as well
    tab pickup_month 

    pickup_month |      Freq.     Percent        Cum.
    ------------+-----------------------------------
        2016m1 |      6,228        0.26        9.45
        2016m2 |      6,268        0.26        9.71
        2016m3 |      6,730        0.28        9.99
        2016m4 |      6,508        0.27       10.26
        2016m5 |      6,941        0.29       10.54
        2016m6 |      7,173        0.30       10.84
        2016m7 |      7,102        0.29       11.13
        2016m8 |      7,590        0.31       11.45
        2016m9 |      7,506        0.31       11.76
        2016m10 |      7,521        0.31       12.07
        2016m11 |      7,570        0.31       12.38
        2016m12 |      7,661        0.32       12.70
        2017m1 |      8,302        0.34       13.04
        2017m2 |      8,031        0.33       13.38
        2017m3 |      9,154        0.38       13.76
        2017m4 |      8,583        0.36       14.11
        2017m5 |      9,237        0.38       14.49
        2017m6 |      9,513        0.39       14.89
        2017m7 |      9,471        0.39       15.28
        2017m8 |      9,841        0.41       15.69
        2017m9 |      9,277        0.38       16.07
        2017m10 |      9,714        0.40       16.47
        2017m11 |      9,962        0.41       16.89
        2017m12 |      9,609        0.40       17.28
        2018m1 |     14,700        0.61       17.89
        2018m2 |     16,831        0.70       18.59
        2018m3 |     20,781        0.86       19.45
        2018m4 |     23,956        0.99       20.44
        2018m5 |     27,508        1.14       21.58
        2018m6 |     28,839        1.19       22.77
        2018m7 |     32,338        1.34       24.11
        2018m8 |     35,760        1.48       25.59
        2018m9 |     33,789        1.40       26.99
        2018m10 |     39,878        1.65       28.64
        2018m11 |     40,459        1.68       30.32
        2018m12 |     39,093        1.62       31.94
        2019m1 |     45,361        1.88       33.82
        2019m2 |     44,246        1.83       35.65
        2019m3 |     49,028        2.03       37.68
        2019m4 |     51,001        2.11       39.79
        2019m5 |     52,957        2.19       41.98
        2019m6 |     49,111        2.03       44.01
        2019m7 |     55,291        2.29       46.30
        2019m8 |     54,539        2.26       48.56
        2019m9 |     52,305        2.17       50.73
        2019m10 |     55,020        2.28       53.00
        2019m11 |     53,962        2.23       55.24
        2019m12 |     54,846        2.27       57.51
        2020m1 |     59,362        2.46       59.97
        2020m2 |     54,748        2.27       62.23
        2020m3 |     60,774        2.52       64.75
        2020m4 |     58,530        2.42       67.17
        2020m5 |     36,825        1.52       68.70
        2020m6 |     33,525        1.39       70.09
        2020m7 |     51,190        2.12       72.21
        2020m8 |     38,701        1.60       73.81
        2020m9 |     37,414        1.55       75.36
        2020m10 |     50,838        2.10       77.46
        2020m11 |     44,852        1.86       79.32
        2020m12 |     47,463        1.97       81.28
        2021m1 |     54,694        2.26       83.55
        2021m2 |     47,078        1.95       85.50
        2021m3 |     52,559        2.18       87.67
        2021m4 |     55,670        2.30       89.98
        2021m5 |     50,024        2.07       92.05
        2021m6 |     50,696        2.10       94.15
        2021m7 |     56,360        2.33       96.48
        2021m8 |     51,916        2.15       98.63
        2021m9 |     32,804        1.36       99.99
        2021m10 |         45        0.00       99.99
        2021m11 |         48        0.00       99.99
        2021m12 |         51        0.00      100.00
        2022m1 |         46        0.00      100.00
        2022m2 |         47        0.00      100.00
        2022m3 |         27        0.00      100.00
    ------------+-----------------------------------
        Total |  2,415,345      100.00
*/

* keep observations from 2018 (in that year there was a major shift in the way the service was provided) and before October 2021
keep if inrange(pickup_month, ym(2018,1),ym(2021,9)) // [QUESTION] september 2021 could be dropped as well. Pickups go from 50k to 32k

* drop observations referring to the same pickup 
bys nid pickup_date (trv_quantity_taken): gen dups = _N>1 // label the duplicate pickups
duplicates drop nid pickup_date, force

keep nid pickup* trv_quantity_taken facility* maputo trv_date_pickup_drug pac_sex pac_age dups *pickup1

* create new trip counter variable as the one already existing seems wrong
preserve 
    gen trip = 1
    collapse trip, by(nid trv_date_pickup_drug)
    bysort nid (trv_date_pickup_drug): replace trip = _n

    tempfile trips
    save `trips'
restore
merge m:1 nid trv_date_pickup_drug using  `trips', nogen 

gen intervention_date =  mdy(10,26,2020) if maputo
replace intervention_date = mdy(12,07,2020) if !maputo
format intervention_date  %td

* record the date of the last visit
bys nid (pickup_date): gen date_last_visit = pickup_date[_N]

* record if the patients stopped picking up pills before the intervention
by nid: gen stopped_before_intervention = date_last_visit < intervention_date

* create the post intervention variable
gen post = pickup_date>= intervention_date

* create a counter of trips after the intervention
bys nid post (pickup_date): gen trips_from_intervention = _n if post==1

*bys nid pickup_month: egen npills_pickedup_m = total(trv_quantity_taken)
bys nid pickup_month: gen pickups_per_m = _N
by nid pickup_month: gen pickcount = _n 

* create a monthly observation for each nid, to fill in months without pickups
preserve 
    keep nid day_pickup1 pickup_month 
    duplicates drop nid day_pickup1, force 

    bys nid: gen e = 44 // the number of months between the earliest pickup_month and September 2021, the latest month in the sample.
    expand e
    bys nid: replace pickup_month=pickup_month[_n-1]+1 if _n>1
    format pickup_month %tm
    drop if pickup_month>ym(2021,9)
    drop e day_pickup1

    unique nid pickup_month

    tempfile balancedpanel
    save `balancedpanel'
restore

merge m:1 nid pickup_month using `balancedpanel'
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     3,278,352
        from master                         0  (_merge==1)
        from using                  3,278,352  (_merge==2)

    Matched                         1,996,168  (_merge==3)
    -----------------------------------------
*/
replace pickup_date = dofm(pickup_month) if _m==2
gen nopickup=_m==2
drop _m trv_date_pickup_drug

* replace missing values of trv_quantity_taken
replace trv_quantity_taken = 0 if missing(trv_quantity_taken)

bys nid (pickup_date): gen expiry = pickup_date + trv_quantity_taken - 1 if trv_quantity_taken > 0
by nid: replace expiry = expiry[_n-1] if trv_quantity_taken==0 
by nid: replace expiry = expiry[_n-1] + trv_quantity_taken - 1 if expiry[_n-1] > pickup_date & trip>1 & nopickup==0 & !missing(expiry[_n-1])
format expiry %td

by nid: gen last_expiry = expiry[_n-1] if _n>1 
format last_expiry %td

by nid: gen days_without = max(0,pickup_date-last_expiry-1) if _n>1 
by nid: replace days_without = day(pickup_date)-1 if _n>1 & days_without>(day(pickup_date)-1)

* clean cases with multiple pickups in a month
by nid: replace days_without = pickup_date-pickup_date[_n-1] if _n>1 & days_without>(pickup_date-pickup_date[_n-1]) & pickup_month==pickup_month[_n-1]

* sum the cumulated number of days without pills until the last pickup of the month:
bys nid pickup_month (pickup_date): egen days_without_med = total(days_without)

* count the number of days without pills after the pickup and until the end of the month
by nid pickup_month: replace days_without_med = days_without_med + max(0,(lastdayofmonth(pickup_date)-expiry[_N])) if _n==_N
by nid pickup_month: replace days_without_med = min(days_without_med, daysinmonth(pickup_date)) // cap days_without_med at the no. of days in the month

by nid pickup_month: gen mpr= 1-(days_without_med/daysinmonth(pickup_date))

* make sure the facility code is never missing
sort nid pickup_date
foreach var in  facility_cod facility_name maputo month_pickup1 day_pickup1 pac_sex pac_age ///
                date_last_visit stopped_before_intervention intervention_date {
    by nid: replace `var' = `var'[1]
}

* create the post intervention variable
cap drop post
gen post = pickup_date>= intervention_date

bys nid (pickup_date): replace trip = trip[_n-1] if missing(trip)
by nid: replace trips_from_intervention = trips_from_intervention[_n-1] if missing(trips_from_intervention)

gen temp = trip if trips_from_intervention==1 
by nid: egen trip_first_interv = max(temp)
gen trip_counter = trip - trip_first_interv
by nid: egen npickups = max(trips)
by nid: replace trip_counter = trip_counter - npickups if missing(trip_first_interv)

drop temp 

replace dups = 0 if missing(dups)


* label patients that had their first pickup after the intervention
bys nid (pickup_date): gen new_patient = (post[1])

*keep only the year before and after the intervention
gen months_from_intervention = pickup_month - mofd(intervention_date)

* label patients for the old_panel
bys nid (pickup_date): gen old_patient = months_from_intervention[1]>=-12 & !new_patient

* create the loss to follow up variable (did not have any pills in the past 6 months) [QUESTION] plls or pickup?
by nid: gen losstofollowup = (mpr + mpr[_n-1] + mpr[_n-2] + mpr[_n-3] + mpr[_n-4] + mpr[_n-5])==0 if _n>5

* keep only observations within 8 months frmo the intervention
keep if months_from_intervention >= -8

* label the 5 and 10 months after the intervention
gen pick_5months = inrange(months_from_intervention, 0,5)
gen pick_8months = inrange(months_from_intervention, 0,8)
gen pick_8range = inrange(months_from_intervention, -8,8)

* label patients that picked up 30 pills in all of their pickups in the 5 months after the intervention
gen temp = (trv_quantity_taken==30 | nopickup)
gen temp2 = pick_5months*temp
bys nid pick_5months: egen temp3 = min(temp2)
bys nid: egen pick30_5months = max(temp3)

gen temp2b = pick_8months*temp
bys nid pick_8months: egen temp3b = min(temp2b)
bys nid: egen pick30_8months = max(temp3b)

gen temp2c = pick_8range*temp
bys nid pick_8range: egen temp3c = min(temp2c)
bys nid: egen pick30_8range = max(temp3c)
drop temp*

destring pac_age, replace

collapse pac_age dups trip_counter (sum) npills_pickedup_m=trv_quantity_taken (last) old_patient new_patient month_pickup1 months_from_intervention ///
        pick30_5months pick_5months pick30_8months pick_8months pick_8range pick30_8range maputo day_pickup1 mpr days_without_med ///
        trips_from_intervention losstofollowup intervention_date pac_sex npickups trip_first_interv date_last_visit stopped_before_intervention, ///
    by(nid pickup_month facility_cod facility_name)

label var npills_pickedup_m             "NUmber of pills picked per month"
label var new_patient                   "Patient that had the first pickup after the intervention"
label var old_patient                   "Patient that had the first pickup in the 12 months before the intervention"
label var days_without_med              "Number of days without pills in a month"
label var pick_5months                  "Within 5 months from the intervention"
label var pick30_5months                "30 pills in all the pickups in the 5 months after the intervention "
label var pick_8months                  "Within 10 months from the intervention"
label var pick30_8months                "30 pills in all the pickups in the 10 months after the intervention "
label var trip_counter                  "trips from first trip after intervention"
label var npickups                      "no of pickups done by a patient"
label var trip_first_interv             "Number of the first pickup after the intervention"
label var date_last_visit               "Date of the alst pickup"
label var stopped_before_intervention   "No pickup after the intervention for the patient"

merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", keepusing(treat) nogen 
gen treatment_status = cond(treatment==0,"control", "treatment") 

save "${DATA}cleaned_data/panel_monthly.dta", replace

* 1.2. Create the new version of the panels:
use "${DATA}cleaned_data/panel_monthly.dta", clear 

preserve 
    *foreach value in 5 10 {
    *keep if new_patient & pick_5months
    keep if new_patient & pick_8months

    * keep only observations from the second pickup after the intervention (since the treatment would not be effective on the first)
    keep if trips_from_intervention>1

* drop patients with duplicate pickups observations in the period considered
    bys nid: egen todrop = max(dups)
    keep if todrop==0 //543 nids

    *drop if months_from_intervention==0
    *bys nid: gen full = _N==5
    *keep if full // should I? alternatively we could drop if pickup_month==month_pickup1 
    * note: Rafael kept also nids that had the first pickup some months after the intervention. 
    *   By keeping only new_patients and a balanced panel, I am restricting to patients starting in month 0 
    drop if pickup_month==month_pickup1 
    rename months_from_intervention period
    gen delay_7 = days_without_med >= 7

    save "${DATA}cleaned_data/panel_visit2_all_updated", replace

    drop delay_7
 *   keep if pick30_5months
    keep if pick30_8months
    save "${DATA}cleaned_data/panel_visit2_30_updated", replace
restore 


** dataset for the analysis starting from the second pickup after the intervention
preserve 
    *foreach value in 5 10 {
    *keep if new_patient & pick_5months
    keep if new_patient & pick_8months

* drop patients with duplicate pickups observations in the period considered
    bys nid: egen todrop = max(dups)
    keep if todrop==0 //543 nids

    *drop if months_from_intervention==0
    *bys nid: gen full = _N==5
    *keep if full // should I? alternatively we could drop if pickup_month==month_pickup1 
    * note: Rafael kept also nids that had the first pickup some months after the intervention. 
    *   By keeping only new_patients and a balanced panel, I am restricting to patients starting in month 0 
    drop if pickup_month==month_pickup1 
    rename months_from_intervention period
    gen delay_7 = days_without_med >= 7

    save "${DATA}cleaned_data/panel_new_all_updated", replace

    drop delay_7
 *   keep if pick30_5months
    keep if pick30_8months
    save "${DATA}cleaned_data/panel_new_30_updated", replace
restore 

** old_panel: // this should be aggregate at the three months period:
keep if old_patient
keep if inrange(months_from_intervention,-12,10)
bys nid: egen todrop = max(dups)
keep if todrop==0 //106 nids

drop if pickup_month==month_pickup1 

gen intervention_month=mofd(intervention_date)
gen period = floor(months_from_intervention/3)

gen ndays_month = daysinmonth(pickup_month)
bys nid period: egen ndays = total(ndays)
by nid period: egen days_without_med_period = total(days_without_med)
gen mpr_period = 1 - (days_without_med_period/ndays)

global controls pac_sex pac_age facility_cod facility_name maputo day_pickup1 month_pickup1 pickup_month intervention_date treat*
collapse mpr=mpr_period days_without_med=days_without_med_period ndays (first) $controls, by(nid period)

save "${DATA}cleaned_data/panel_old_updated", replace

************************************************************************************
*** 2. Exploratory data analysis 
************************************************************************************

*** 2.1. Congestion effect: treatment vs control - months_from_intervention: -12 to 8
use "${DATA}cleaned_data/panel_monthly.dta", clear 
bys nid: egen todrop = max(dups)
keep if todrop==0 //106 nids
/* to compare with rafael's panel
    frame change ciao
    frame create panel_new_30 
    frame panel_new_30: use "${MOZART}panel_new_30.dta", clear
    frame panel_new_30: drop if missing(mpr)
    frame panel_new_30: duplicates drop nid, force
    frame panel_new_30: gen new_30_bis = 1
    frame panel_new_30: tab pac_start_date_arv if nid=="$a"
    frame panel_new_30: list if nid=="$a"
    frame panel_new_30: tab period if !missing(mpr)

    frlink m:1 nid, frame(panel_new_30)
    frget new_30_bis, from(panel_new_30)
    frame drop panel_new_30
*/

*drop if pickup_month==ym(2021,09)
drop if months_from_intervention>8

cap gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

gen npatients = 1
*keep if pick30_12range

*  tab pick30_8range stopped_before_intervention, m
/* most of the observations in the pick30_8range sample did not have pickups after the intervention 
            |  No pickup after the
        (last) | intervention for the
    pick30_8ra |        patient
        nge |         0          1 |     Total
    -----------+----------------------+----------
            0 | 1,446,299     92,612 | 1,538,911 
            1 |   128,818    573,609 |   702,427 
    -----------+----------------------+----------
        Total | 1,575,117    666,221 | 2,241,338 
*/
drop if pickup_month > (mofd(date_last_visit) + 3)

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen zeropills = npills_pickedup_m==0

collapse mpr* days_without_med delay_7 npills losstofollowup (sum) npatients n_newpatients = new_patient zeropills , by(treatment months_from_intervention)

gen share_new = n_newpatients / npatients 

label var  months_from_intervention     "Months from intervention"
label var  treatment                   "Treatment status"
label var  npatients                    "No. of patients"
label var  n_newpatients                "No. of new patients"
label var  share_new                    "Share of new patients"
label var  days_without_med             "Days without medicine"
label var  mpr                          "MPR"


bytwoway line npatients months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}npatients_trend_TC.png", replace
// the drop in the last two months is due to the fact that some facilities had the treatment in december and since 
*   the data stops in August/Septemebr 2021, we do not have data for 9 and 10 months after the intervenion
bytwoway line share_new months_from_intervention, by(treatment) xline(0) $white // share of new patients follows a similar trend for treated and control facilities
graph export "${graphs}share_newpatients_trend_TC.png", replace

gen zeropill_share = zeropills / npatients
bytwoway line zeropills months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}zeropills_trend_TC.png", replace

bytwoway line zeropill_share months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}zeropills_share_trend_TC.png", replace

bytwoway line npills_pickedup_m months_from_intervention, by(treatment) xline(0) $white

bytwoway line n_newpatients months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}n_newpatients_trend_TC.png", replace



bytwoway line days_without_med months_from_intervention, by(treatment) xline(0) $white // volatility driven by nomber of days in a month probably, look at mpr
graph export "${graphs}days_without_meds_trend_TC.png", replace

bytwoway line mpr months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}mpr_trend_TC.png", replace

bytwoway line losstofollowup months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}losstofollowup_trend_TC.png", replace



*** 2.2. Congestion effect: 30pills - treatment vs control - months_from_intervention: -12 to 8
use "${DATA}cleaned_data/panel_monthly.dta", clear 
bys nid: egen todrop = max(dups)
keep if todrop==0 //106 nids

drop if months_from_intervention>8

cap gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

gen npatients = 1

keep if pick30_8range

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen zeropills = npills_pickedup_m==0
gen empty_month = mpr==0
gen lost=zeropills*empty_month


collapse mpr* days_without_med delay_7 npills losstofollowup (sum) npatients n_newpatients = new_patient zeropills, by(treatment months_from_intervention)

gen share_new = n_newpatients / npatients 

label var  months_from_intervention     "Months from intervention"
label var  treatment                   "Treatment status"
label var  npatients                    "No. of patients"
label var  n_newpatients                "No. of new patients"
label var  share_new                    "Share of new patients"
label var  days_without_med             "Days without medicine"
label var  mpr                          "MPR"


bytwoway line npatients months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}npatients_30_trend_TC.png", replace
// the drop in the last two months is due to the fact that some facilities had the treatment in december and since 
*   the data stops in August/Septemebr 2021, we do not have data for 9 and 10 months after the intervenion
bytwoway line share_new months_from_intervention, by(treatment) xline(0) $white // share of new patients follows a similar trend for treated and control facilities
graph export "${graphs}share_newpatients_30_trend_TC.png", replace

gen zeropill_share = zeropills / npatients
bytwoway line zeropills months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}zeropills_30_trend_TC.png", replace

bytwoway line zeropill_share months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}zeropills_share_30_trend_TC.png", replace

bytwoway line npills_pickedup_m months_from_intervention, by(treatment) xline(0) $white

bytwoway line n_newpatients months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}n_newpatients_30_trend_TC.png", replace

*bytwoway line lost months_from_intervention, by(treatment) xline(0) $white


bytwoway line days_without_med months_from_intervention, by(treatment) xline(0) $white // volatility driven by nomber of days in a month probably, look at mpr
graph export "${graphs}days_without_meds_30_trend_TC.png", replace

bytwoway line mpr months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}mpr_trend_30_TC.png", replace

bytwoway line losstofollowup months_from_intervention, by(treatment) xline(0) $white
graph export "${graphs}losstofollowup_trend_30_TC.png", replace


*** 2.3.facility level - months_from_intervention: -12 to 8
use "${DATA}cleaned_data/panel_monthly.dta", clear 
bys nid: egen todrop = max(dups)
keep if todrop==0 //106 nids

*drop if pickup_month==ym(2021,09)
drop if months_from_intervention>8

cap gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

gen npatients = 1

keep if pick30_8range



collapse  mpr* days_without_med delay_7 maputo new_patient pick30* (sum) n_newpatients = new_patient npatients, by(facility_cod months_from_intervention facility_name)

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen share_new = n_newpatients / npatients 

label var  months_from_intervention     "Months from intervention"
label var  treatment                   "Treatment status"
label var  npatients                    "No. of patients"
label var  n_newpatients                "No. of new patients"
label var  share_new                    "Share of new patients"
label var  days_without_med             "Days without medicine"
label var  mpr                          "MPR"


rename months_from_intervention period
label_vars_hiv

gen post = period>=0
tab period, gen(periods)
gen periode = period + 12

gen treat = treatment*post


reghdfe npatients treatment##post, vce(cl facility_cod)
reghdfe npatients treatment##post,  a(province) vce(cl facility_cod)



** first stage
reghdfe scheduled_share treat i.periode [aw=npatients], a(province) vce(cl facility_cod)

** reduced form
reghdfe mpr treat i.periode [aw=npatients], a(province) vce(cl facility_cod)

* 2SLS
ivreghdfe mpr (scheduled_share=treat) i.periode [aw=npatients], a(province) cluster(facility_cod)


reghdfe npatients treatment##i.periode,  a(province) vce(cl facility_cod)
reghdfe n_newpatients treatment##i.periode,  a(province) vce(cl facility_cod)
reghdfe mpr treatment##i.periode,  a(province) vce(cl facility_cod)
reghdfe days_without_med treatment##i.periode,  a(province) vce(cl facility_cod)

reghdfe npatients treatment##post maputo##treatment##post, vce(cl facility_cod)
reghdfe npatients treatment##post maputo##treatment##post a(period province), vce(cl facility_cod)

reghdfe npatients complier##post, a(period province) vce(cl facility_cod)
reghdfe npatients complier##post, a(period province) vce(cl facility_cod)

reghdfe npatients complier_next##post, vce(cl facility_cod)
reghdfe npatients complier_next##post, a(period province) vce(cl facility_cod)

local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_old_reg $outcome, controls($controls) absorb(province) filename("tables/facility_`q'.tex")

    * heterogeneity analysis with maputo:
    *mozart_reg_het $outcome, controls($controls) absorb(period) filename("tables/facility_`q'_maputo.tex") het_var(maputo)

    local ++i
}

reghdfe mpr_95 treatment##post $controls [weight=npatients], vce(cl facility_cod)
reghdfe mpr_95 treatment##post $controls [weight=npatients],  a(province) vce(cl facility_cod)
reghdfe mpr_95 treatment##post $controls [weight=npatients],  a( province) vce(cl facility_cod)



*** 2.4. Congestion effect: treatment vs control - months_from_intervention: -12 to 8

use "${DATA}cleaned_data/panel_new_all_updated", clear
use "${DATA}cleaned_data/panel_new_30_updated", clear
*use "${DATA}cleaned_data/panel_old_updated", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen_controls
cap gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95
label_vars_hiv

catcibar mpr, over(treatment)  $white
catcibar mpr, over(treatment) yaxis(0.5 1)  $white 

catcibar mpr, over(complier)  $white
catcibar mpr, over(complier_next)  $white


global controls index_hiv_care_readiness art_different_lines art_general hand_wash dayaverage urban cd4 score_basic_amenities score_basic_equipment hiv_diagnostic_capacity index_general_service $controls_patient 

global controls urban cd4 score_basic_amenities score_basic_equipment hiv_diagnostic_capacity index_general_service $controls_patient 
global controls urban cd4 score_basic_amenities score_basic_equipment hiv_diagnostic_capacity index_general_service

// taking out art_general makes everything almost significant...

// there is a significant positive difference between treated and control facilities, but:
//     - nocontrols: it loses significance when clustering at the facility level (std err 10x larger)
//     - controls: adding the controls it changes sign and has huge pvalue (> 0.9) with or without clustering
reghdfe mpr treatment, absorb(period province) 
reghdfe mpr treatment, absorb(period province) cluster(facility_cod) // when you cluster you lose the significance
reghdfe mpr treatment $controls, absorb(period province) 
reghdfe mpr treatment $controls, absorb(period province) cluster(facility_cod)


reghdfe mpr complier, absorb(period province) 
reghdfe mpr complier, absorb(period province) cluster(facility_cod)
reghdfe mpr complier $controls, absorb(period province) 
reghdfe mpr complier $controls, absorb(period province) cluster(facility_cod)

// complier_next remains significant in the first three regressions, loses significance (pvalue 0.2) with controls and clustering
reghdfe mpr complier_next, absorb(period province) 
reghdfe mpr complier_next, absorb(period province) cluster(facility_cod)
reghdfe mpr complier_next $controls, absorb(period province) 
reghdfe mpr complier_next $controls, absorb(period province) cluster(facility_cod)


reghdfe mpr scheduled_next_share, absorb(period province) 
reghdfe mpr scheduled_next_share, absorb(period province) cluster(facility_cod)
reghdfe mpr scheduled_next_share $controls, absorb(period province) 
reghdfe mpr scheduled_next_share $controls, absorb(period province) cluster(facility_cod)

reghdfe scheduled_next_share treatment maputo, absorb(period province) cluster(facility_cod)



ivreghdfe mpr (complier=treatment), absorb(period province) cluster(facility_cod)
ivreghdfe mpr (complier_next=treatment), absorb(period province) cluster(facility_cod)
*ivreghdfe mpr (scheduled_next_share=treatment), absorb(period province) cluster(facility_cod)


ivreghdfe mpr $controls (complier=treatment), absorb(period province) cluster(facility_cod)
ivreghdfe mpr $controls (complier_next=treatment), absorb(period province) cluster(facility_cod)
*ivreghdfe mpr $controls (scheduled_next_share=treatment), absorb(period province) cluster(facility_cod)


local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(pickup_month province) filename("tables/new_30_10m_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(pickup_month) filename("tables/new_30_10m_`q'_maputo.tex") het_var(maputo)

    local ++i
}

************************************************************************************
*** 3. Regressions
************************************************************************************
 
*** 3.1. Panel with patients that got 30 pills in all their pickups ---------------

* 3.1.1. 8 months range, starting from month of intervention
*use "${MOZART}panel_new_30.dta", clear
use "${DATA}cleaned_data/panel_new_30_updated.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

// function to generate controls
gen_controls

gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

label_vars_hiv

drop if pickup_month==ym(2021,9)

local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(pickup_month province) filename("tables/new_30_10m_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(pickup_month) filename("tables/new_30_10m_`q'_maputo.tex") het_var(maputo)

    local ++i
}


* 3.1.2. 8 months range, starting from the second pickup after the intervention
use "${DATA}cleaned_data/panel_visit2_30_updated.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

// function to generate controls
gen_controls

gen delay_7 = days_without_med >= 7
gen mpr_95 = mpr > 0.95

label_vars_hiv

drop if pickup_month==ym(2021,9)

local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(pickup_month province) filename("tables/visit2_30_10m_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(pickup_month) filename("tables/visit2_30_10m_`q'_maputo.tex") het_var(maputo)

    local ++i
}


*** 3.2. Panel with new patients that got any amount of pills ---------------

* 3.2.1. 8 months range, starting from month of intervention
*use "${MOZART}panel_new_all.dta", clear
use "${DATA}cleaned_data/panel_new_all_updated.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen_controls
gen mpr_95 = mpr > 0.95

label_vars_hiv
drop if pickup_month==ym(2021,9)

local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(pickup_month province) filename("tables/new_all_10m_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(pickup_month) filename("tables/new_all_10m_`q'_maputo.tex") het_var(maputo)

    local ++i
}


* 3.2.2. 8 months range, starting from second visit after the intervention
*use "${MOZART}panel_new_all.dta", clear
use "${DATA}cleaned_data/panel_visit2_all_updated.dta", clear

merge m:1 facility_cod using "${DATA}cleaned_data/hiv_complier_facilities.dta", nogen 
merge m:1 facility_cod using "${DATA}aux/facility_characteristics.dta", nogen 

gen_controls
gen mpr_95 = mpr > 0.95

label_vars_hiv
drop if pickup_month==ym(2021,9)

local names " "days" "mpr" "mpr_95" "delay_7" "
local i = 1
foreach var in days_without_med mpr mpr_95 delay_7 {
    global outcome `var'
    local q: word `i' of `names'
    dis `i' " - " "`q'"
    mozart_reg $outcome, controls($controls) absorb(pickup_month province) filename("tables/visit2_all_10m_`q'.tex")

    * heterogeneity analysis with maputo:
    mozart_reg_het $outcome, controls($controls) absorb(pickup_month) filename("tables/visit2_all_10m_`q'_maputo.tex") het_var(maputo)

    local ++i
}

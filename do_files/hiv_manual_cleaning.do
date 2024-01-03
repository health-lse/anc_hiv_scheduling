
*** this dofile manually cleans observations. At the moment the cleaning is not systematic:
*       when I spot errors in the values for some variables, if I realize they cannot be fixed in a 
*       automated way I manually clean them here.


* manual cleaning

** arrival_time
replace arrival_time = 1032 if file_name=="endline_US10_day5_page5.txt" & line==3
replace arrival_time = 848 if file_name=="endline_US10_day7_page7.txt" & line==3
replace arrival_time = 849 if file_name=="endline_US10_day7_page7.txt" & line==4
replace arrival_time = 1040 if file_name=="endline_US13_day2_page6.txt" & line==8
replace arrival_time = 800 if file_name=="endline_US13_day8_page6.txt" & line==4
replace arrival_time = 800 if file_name=="endline_US21_day3_page4.txt" & line==3
replace arrival_time = 830 if file_name=="endline_US21_day6_page3.txt" & line==6
replace arrival_time = 1000 if file_name=="endline_US29_day6_page6.txt" & line==4


** consultation_time
replace consultation_time = 1142 if file_name=="endline_US43_day12_page4.txt" & line==1 
replace consultation_time = 1100 if file_name=="endline_US13_day2_page6.txt" & line==8
replace consultation_time = 830 if file_name=="endline_US13_day8_page6.txt" & line==4
replace consultation_time = 917 if file_name=="endline_US10_day11_page5.txt" & line==1
replace consultation_time = 1122 if file_name=="endline_US16_day10_page4.txt" & line==7

** waiting_time_selfr
replace waiting_time_sr = 60 if file_name=="endline_US10_day10_page7.txt" & line==6 //1 hour 
replace waiting_time_sr = 60 if file_name=="endline_US10_day10_page8.txt" & line==3 
replace waiting_time_sr = 60 if file_name=="endline_US10_day10_page8.txt" & line==4 
replace waiting_time_sr = 305 if file_name=="endline_US24_day10_page6.txt" & line==33
replace waiting_time_sr = 250 if file_name=="endline_US24_day10_page3.txt" & line==3
replace waiting_time_sr = 203 if file_name=="endline_US24_day10_page5.txt" & line==6
replace waiting_time_sr = 207 if file_name=="endline_US24_day4_page6.txt" & line==9
replace waiting_time_sr = 201 if file_name=="endline_US24_da5_page3.txt" & line==8


** scheduled_time
replace scheduled_time = 1030 if file_name=="endline_US30_day10_page5.txt" & line==5
replace scheduled_time = 830 if file_name=="endline_US30_day10_page5.txt" & line==6
replace scheduled_time = 830 if file_name=="endline_US30_day4_page5.txt" & line==2
replace scheduled_time = 1030 if file_name=="endline_US30_day4_page8.txt" & line==5
replace scheduled_time = 830 if file_name=="endline_US30_day6_page6.txt" & line==6
replace scheduled_time = 1030 if file_name=="endline_US30_day7_page8.txt" & line==7 // it is equal ot 1041111, should be 10H11H
replace scheduled_time = 0 if file_name=="endline_US61_day5_page3.txt"  // the whole page
replace scheduled_time = 0 if file_name=="endline_US13_day2_page6.txt" & line==8
replace arrival_time = 0 if file_name=="endline_US13_day8_page6.txt" & line==4
replace scheduled_time = 900 if file_name=="endline_US16_day9_page4.txt" & inrange(line, 3,4)
replace scheduled_time = 0 if file_name=="endline_US21_day5_page7.txt" & line==4
replace scheduled_time = 1 if file_name=="endline_US24_day10_page3.txt" & line==6 // facility 24 weird scheduled time
replace scheduled_time = 5 if file_name=="endline_US24_day11_page6.txt" & line==7 
replace scheduled_time = 10 if file_name=="endline_US24_day12_page3.txt" & line==9 
replace scheduled_time = 0 if file_name=="endline_US25_day12_page6.txt"
replace scheduled_time = 0 if file_name=="endline_US29_day6_page6.txt"



** next_scheduled_time
tostring scheduled_time, gen(scheduled_time_str) force
replace next_scheduled_time = "8h" if file_name=="endline_US14_day7_page5.txt" & line==6
replace next_scheduled_time = "8h" if file_name=="endline_US14_day9_page7.txt" & line==6
replace next_scheduled_time = scheduled_time_str if file_name=="endline_US16_day9_page4.txt" 
replace next_scheduled_time = "9h" if file_name=="endline_US18_day8_page6.txt" & line==4
replace next_scheduled_time = "" if file_name=="endline_US19_day12_page3.txt" & line==5
replace next_scheduled_time = "" if file_name=="endline_US21_day4_page3.txt" & line==7
replace next_scheduled_time = "" if file_name=="endline_US29_day6_page6.txt"


replace next_scheduled_time = "" if next_scheduled_time=="A" // to check

/*
facility-day-page with no consultation time in the split image:
--- endline_US25_day1_page5.png

--- endline_US43_day12_page4.txt

*/

/*
* Test to compute metrics on goodness of the cleaning

use "${DATA}cleaned_data/hiv_endline.dta", clear

set seed 37
sample 5

keep file_name line facility_cod day page arrival_time consultation_time scheduled_time next_scheduled_time

sort file_name line
export excel "${DATA}temp/cleaning_test_data.xlsx", firstrow(variables) replace
*/
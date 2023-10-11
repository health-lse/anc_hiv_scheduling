# anc_hiv_scheduling
OCR, cleaning scripts, graph generation and estimation of scheduling RCT for ANC and HIV in mozambique

Run anc_clean_aws_response.py to generate the ANC dta file

Run hiv_clean_aws_response.py  to generate the HIV dta file (currently has an error)

Run anc_graphs.py to generate ANC graphs

Run anc_regressions.do to generate the ANC tables

# Mozart data:
Mozart contains data of the HIV patient pickups. One issue with this data is that some patients get their medication every month, others every 3 months. Usually patients starts in the 1 month regime and then at some point change to the 3 month regime. In order to make these groups comparable, we selected 


Definitions:

Old patients: patients who started before the intervetion

New patients: patients who started after the intervetion

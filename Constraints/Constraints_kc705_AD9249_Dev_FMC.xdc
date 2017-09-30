#
# Pinout for the AD9249_Dev_FMC on kc705
#

# ADC clock pins
set_property -dict {PACKAGE_PIN C25 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports DCO_clk_p]
set_property -dict {PACKAGE_PIN B25 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports DCO_clk_n]
set_property -dict {PACKAGE_PIN D29 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FCO_clk_p]
set_property -dict {PACKAGE_PIN C30 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports FCO_clk_n]

# ADC data pins
#set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[0]}]
#set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[0]}]
# KC705 can't put these pins in the right bank to make them accessible, so cheat and use different ones from this bank
set_property -dict {PACKAGE_PIN C24 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[0]}]
set_property -dict {PACKAGE_PIN B24 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[0]}]

set_property -dict {PACKAGE_PIN A25 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[1]}]
set_property -dict {PACKAGE_PIN A26 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[1]}]
set_property -dict {PACKAGE_PIN B27 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[2]}]
set_property -dict {PACKAGE_PIN A27 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[2]}]
set_property -dict {PACKAGE_PIN C29 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[3]}]
set_property -dict {PACKAGE_PIN B29 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[3]}]
set_property -dict {PACKAGE_PIN G28 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[4]}]
set_property -dict {PACKAGE_PIN F28 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[4]}]
set_property -dict {PACKAGE_PIN B30 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[5]}]
set_property -dict {PACKAGE_PIN A30 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[5]}]
set_property -dict {PACKAGE_PIN G29 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[6]}]
set_property -dict {PACKAGE_PIN F30 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[6]}]
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_p[7]}]
set_property -dict {PACKAGE_PIN C26 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {adc_raw_samples_in_n[7]}]
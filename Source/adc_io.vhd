library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;
library UNISIM;
	use UNISIM.vcomponents.all;

entity adc_io is
port (
  DCLK_p_i : in  std_logic;
  DCLK_n_i : in  std_logic;
  FCLK_p_i : in  std_logic;
  FCLK_n_i : in  std_logic;
  ADC_DATA_p_i : in  std_logic_vector(7 downto 0);
  ADC_DATA_n_i : in  std_logic_vector(7 downto 0);
  
  DCLK_o   : out std_logic;
  FCLK_p_o : out std_logic;
  FCLK_n_o : out std_logic;
  ADC_DATA_p_o : out std_logic_vector(7 downto 0);
  ADC_DATA_n_o : out std_logic_vector(7 downto 0)
);
end adc_io;

architecture RTL of adc_io is
begin

  -- DCLK
  DCLK_OUT : IBUFGDS
    generic map (DIFF_TERM => TRUE, IOSTANDARD => "LVDS_25")
    port map (I => DCLK_p_i, IB => DCLK_n_i, O => DCLK_o);
  
  -- FCLK
  FCLK_OUT : IBUFDS_DIFF_OUT
    generic map (DIFF_TERM => TRUE, IOSTANDARD => "LVDS_25")
    port map (I => FCLK_p_i, IB => FCLK_n_i, O => FCLK_p_o, OB => FCLK_n_o);
  
  -- Data  
  G_ADC_DATA_OUT : for i in 0 to 7 generate
    DATA_OUT : IBUFDS_DIFF_OUT
      generic map (DIFF_TERM => TRUE, IOSTANDARD => "LVDS_25")
      port map ( I => ADC_DATA_p_i(i), IB => ADC_DATA_n_i(i), O => ADC_DATA_p_o(i), OB =>ADC_DATA_n_o(i));
  end generate G_ADC_DATA_OUT;
  
end RTL;
  
library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;
library UNISIM;
  use UNISIM.vcomponents.all;

entity AD9249_top is 
  port (	
	-- AD9249 Clocks
	FCO_clk_p : in std_logic; -- Frame Clock
	FCO_clk_n : in std_logic;
	DCO_clk_p : in std_logic; -- Data Clock (7x frame clock, phase shifted)
	DCO_clk_n : in std_logic;
	
	-- AD9249 Data	
	adc_raw_samples_in_p  : in std_logic_vector(7 downto 0);
	adc_raw_samples_in_n  : in std_logic_vector(7 downto 0)
  );
end AD9249_top;

architecture STRUCTURE of AD9249_top is
 
-- Signals
signal SYS_CLK : std_logic;
signal CLK_EN  : std_logic;
signal CLK_RST : std_logic;
signal MEM_CLK : std_logic;

signal DCLK : std_logic;
signal FCLK_p, FCLK_n : std_logic;
signal ADC_DATA_p, ADC_DATA_n : std_logic_vector(7 downto 0);

signal D_CH0, D_CH1, D_CH2, D_CH3, D_CH4, D_CH5, D_CH6, D_CH7 : std_logic_vector(13 downto 0);

attribute mark_debug : string;
attribute keep : string;

--attribute mark_debug of debug_sample : signal is "true";
    
begin
 
-- -- MMCM clock setup
-- U_CAR : entity work.clocks_and_resets 
-- port map (
--   SYS_CLK  => SYS_CLK,
--   RST      => '0',
   
--   CLK_EN   => CLK_EN,
--   CLK_RST  => CLK_RST,
--   CLK_O    => MEM_CLK
-- );
 CLK_EN <= '1';
 CLK_RST <= '0';
 -- Bring in ADC inputs
 U_ADC_IO : entity work.adc_io
 port map (
   DCLK_p_i => DCO_clk_p,
   DCLK_n_i => DCO_clk_n,
   FCLK_p_i => FCO_clk_p,
   FCLK_n_i => FCO_clk_n,
   ADC_DATA_p_i => adc_raw_samples_in_p,
   ADC_DATA_n_i => adc_raw_samples_in_n,
   
   DCLK_o => DCLK,
   FCLK_p_o => FCLK_p,
   FCLK_n_o => FCLK_n,
   ADC_DATA_p_o => ADC_DATA_p,
   ADC_DATA_n_o => ADC_DATA_n
 );
 
 -- align clocks and frame sample data, ILA on output will capture samples 
 U_ADC_CAPTURE : entity work.adc_capture
 port map (
   -- Clocks / Reset
   capture_ena     => CLK_EN,
   capture_rst     => CLK_RST,
   capture_mem_clk => '0',
   capture_mem_ena => '1',
   capture_mem_rst => CLK_RST,
   -- Interface
   capture_data_p  => ADC_DATA_p,
   capture_data_n  => ADC_DATA_n,
   DCLK_p          => DCLK,
   FCLK_p          => FCLK_p,
   FCLK_n          => FCLK_n,
   -- Data out
   D_CH0 => D_CH0,
   D_CH1 => D_CH1,
   D_CH2 => D_CH2,
   D_CH3 => D_CH3,
   D_CH4 => D_CH4,
   D_CH5 => D_CH5,
   D_CH6 => D_CH6,
   D_CH7 => D_CH7   
 );
 
  
--  reset <= delay_rst_q(15);
  
--  S_RESET : process (DCO_clk, delay_rst_q)
--  begin 
--    delay_rst_d <= delay_rst_q(14 downto 0) & '0';
--    if (rising_edge(DCO_clk)) then
--      delay_rst_q <= delay_rst_d;
--    end if;
--  end process S_RESET;
    
end STRUCTURE;
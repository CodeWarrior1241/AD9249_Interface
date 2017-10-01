library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;
library UNISIM;
  use UNISIM.vcomponents.all;
  
entity adc_capture is 
  port (
   -- Clocks / Reset
   capture_ena     : in  std_logic;
   capture_rst     : in  std_logic;
   capture_mem_clk : in  std_logic;
   capture_mem_ena : in  std_logic;
   capture_mem_rst : in  std_logic;
   -- Interface
   capture_data_p  : in  std_logic_vector(7 downto 0);
   capture_data_n  : in  std_logic_vector(7 downto 0);
   DCLK_p          : in  std_logic;
   FCLK_p          : in  std_logic;
   FCLK_n          : in  std_logic;
   -- Data out
   D_CH0           : out std_logic_vector(13 downto 0);
   D_CH1           : out std_logic_vector(13 downto 0);
   D_CH2           : out std_logic_vector(13 downto 0);
   D_CH3           : out std_logic_vector(13 downto 0);
   D_CH4           : out std_logic_vector(13 downto 0);
   D_CH5           : out std_logic_vector(13 downto 0);
   D_CH6           : out std_logic_vector(13 downto 0);
   D_CH7           : out std_logic_vector(13 downto 0)
  );
end adc_capture;

architecture STRUCTURE of adc_capture is

signal intBitClkRef : std_logic;
signal intBitClk    : std_logic;
signal intBitClkDone : std_logic;
signal intReSync : std_logic;
signal intBitSlip_p, intBitSlip_n : std_logic;
signal intMsbEna, intLsbEna : std_logic;
type array2d is array (natural range <>) of std_logic_vector(13 downto 0);
signal sample_collection : array2d(7 downto 0);

begin

u_adc_frame_capture : entity work.adc_frame_sync
  port map (
      BitClk         => intBitClk,
      BitClkRef      => intBitClkRef,
      BitClkDone     => intBitClkDone,
      BitClkENA      => capture_ena,
      BitClkRST      => capture_rst,
      FCLK_p         => FCLK_p,
      FCLK_n         => FCLK_n,
      FCLK_BitSlip_p => intBitSlip_p,
      FCLK_BitSlip_n => intBitSlip_n,
      FCLKReSyncOut  => intReSync,
      FClkMsbEna     => intMsbEna,
      FCLKLsbEna     => intLsbEna
  );

G_adc_data_capture : for i in 0 to 7 generate
  u_adc_data_capture : entity work.adc_data_sync
    port map (
      DatIn_p      => capture_data_p(i),
      DatIn_n      => capture_data_n(i),
      DatClk       => intBitClk,
      DatClkDiv    => intBitClkRef,
      DatRst       => capture_rst,
      DatEna       => '1',
      DatDone      => intBitClkDone,
      DatBitSlip_p => intBitSlip_p,
      DatBitSlip_n => intBitSlip_n,
      DatMsbRegEna => intMsbEna,
      DatLsbRegEna => intLsbEna,
      DatReSync    => intReSync,
      DatOut       => sample_collection(i)
    );
end generate G_adc_data_capture;

u_adc_dclk_sync : entity work.adc_dclk_sync
  port map (
    DCLK         => DCLK_p,
    BitClk_i     => intBitClk,
    BitClkRef_i  => intBitClkRef,
    BitClkRST    => capture_rst,
    BitClkENA    => capture_ena,
    BitClk_o     => intBitClk,
    BitClkRef_o  => intBitClkRef,
    ClkAlignDone => intBitClkDone    
  );
  
  D_CH0 <= sample_collection(0);
  D_CH1 <= sample_collection(1);
  D_CH2 <= sample_collection(2);
  D_CH3 <= sample_collection(3);
  D_CH4 <= sample_collection(4);
  D_CH5 <= sample_collection(5);
  D_CH6 <= sample_collection(6);
  D_CH7 <= sample_collection(7);

end STRUCTURE;
    
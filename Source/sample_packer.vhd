library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity sample_packer is 
  port (
    RESET         : in  std_logic;
    FRAME_CLK     : in  std_logic;
	DATA_CLK      : in  std_logic;
	DATA_SAMPLE_R : in  std_logic;
    DATA_SAMPLE_F : in  std_logic;
    
    PACKED_SAMPLE : out std_logic_vector(13 downto 0);
    PACKED_VALID  : out std_logic
  );
end sample_packer;

architecture RTL of sample_packer is

-- Signals
signal frame_clk_q, frame_clk_qq : std_logic;
signal samp_store_d, samp_store_q : std_logic_vector(13 downto 0);
signal bit_pos_d, bit_pos_q, bit_pos_qq : natural;
begin

 -- Outputs
 PACKED_SAMPLE <= samp_store_q;
 PACKED_VALID <= '1' when bit_pos_qq = 1 else '0';
 
  C_SAMPLE : process(frame_clk_qq, frame_clk_q, bit_pos_q)
  begin
    samp_store_d <= samp_store_q;
    
    if(frame_clk_qq = '0' and frame_clk_q = '1') then
      bit_pos_d <= 13; 
    else
      bit_pos_d <= bit_pos_q - 2;
    end if;
    
    samp_store_d(bit_pos_d)   <= DATA_SAMPLE_R;
    samp_store_d(bit_pos_d-1) <= DATA_SAMPLE_F;
  end process C_SAMPLE;
   
   
  S_CLK : process(DATA_CLK, RESET)
  begin
    if(RESET = '1') then
      frame_clk_q  <= '0';
      frame_clk_qq <= '0';
      bit_pos_q    <= 13; -- MSB is first
      bit_pos_qq   <= bit_pos_q;
      samp_store_q <= (others => '0');
    elsif(rising_edge(DATA_CLK)) then
      frame_clk_q  <= FRAME_CLK;
      frame_clk_qq <= frame_clk_q;
      bit_pos_q    <= bit_pos_d;
      bit_pos_qq   <= bit_pos_qq;
      samp_store_q <= samp_store_d;
    end if;
    
  end process S_CLK;
  
  
end RTL;
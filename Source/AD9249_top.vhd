library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity AD9249_top is 
  port (	
	-- AD9249 Clocks
	--SAMP_CLK_P : in std_logic; -- Not needed
	--SAMP_CLK_M : in std_logic;
	
	FCO_clk_p : in std_logic; -- Frame Clock
	FCO_clk_n : in std_logic;
	DCO_clk_p : in std_logic; -- Data Clock (7x frame clock, phase shifted)
	DCO_clk_n : in std_logic;
	
	-- AD9249 Data	
	adc_raw_samples_in_p  : in std_logic_vector(7 downto 0);
	adc_raw_samples_in_n  : in std_logic_vector(7 downto 0)
	
	-- AD9249 SPI
	--CSB1 : out std_logic;
	--CSB2 : out std_logic;
	--SCLK : out std_logic;
	--SDIO : out std_logic; -- technically inout
	
	--PDWN : out std_logic	
  );
end AD9249_top;

architecture STRUCTURE of AD9249_top is
  component sample_packer
  port (
    RESET         : in  std_logic;
    FRAME_CLK     : in  std_logic;
	DATA_CLK      : in  std_logic;
	DATA_SAMPLE_R : in  std_logic;
    DATA_SAMPLE_F : in  std_logic;
    
    PACKED_SAMPLE : out std_logic_vector(13 downto 0);
    PACKED_VALID  : out std_logic
  );
  end component sample_packer;
  
  component sample_ram
  port (
    clka  : IN STD_LOGIC;
    wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    dina  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    clkb  : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(13 DOWNTO 0)
  );
  end component sample_ram; 
     
  component IBUFDS
  port (
	  O  : out std_logic;
	  I  : in  std_logic;
	  IB : in  std_logic
	);
  end component IBUFDS;
         
  component IBUFGDS
  port (
    O  : out std_logic;
    I  : in  std_logic;
    IB : in  std_logic
  );
  end component IBUFDS;
  
  component IDDR
  generic (
    DDR_CLK_EDGE : string
  );
  port (
    Q1 : out std_logic;
	Q2 : out std_logic;
	C  : in  std_logic;
	CE : in  std_logic;
	D  : in  std_logic;
	R  : in  std_logic;
	S  : in  std_logic
  );
  end component IDDR;
-- Signals
signal DCO_clk : std_logic;
signal FCO_clk : std_logic;
signal DATA_BANK_BUF_o : std_logic_vector(7 downto 0);
signal DATA_BANK_DDR_i : std_logic_vector(7 downto 0);
signal DATA_BANK_R, DATA_BANK_F : std_logic_vector(7 downto 0);

type T_2Dsample is array (natural range <>) of std_logic_vector(13 downto 0);
signal PACKED_SAMPLE : T_2Dsample(7 downto 0);
signal PACKED_VALID  : std_logic_vector(7 downto 0);

signal sample_count_d, sample_count_q : std_logic_vector(5 downto 0);
signal debug_sample : T_2Dsample(7 downto 0);
signal delay_rst_q, delay_rst_d : std_logic_vector(15 downto 0) := (others => '1');
signal reset : std_logic;

attribute mark_debug : string;
attribute keep : string;

attribute mark_debug of debug_sample : signal is "true";
    
begin
  
  ---------------
  -- Data Capture
  ---------------
  G_PACK : for i in 0 to 7 generate
    U_SAMPLE_PACKER : sample_packer
    port map (
      RESET         => reset,
      FRAME_CLK     => FCO_clk, 
      DATA_CLK      => DCO_clk,
      DATA_SAMPLE_R => DATA_BANK_R(i),
      DATA_SAMPLE_F => DATA_BANK_F(i),
      
      PACKED_SAMPLE => PACKED_SAMPLE(i),
      PACKED_VALID  => PACKED_VALID(i)
    );
  end generate G_PACK;
  
  -----------
  -- Storage
  -----------
  C_SAMPLE_COUNT : process (FCO_clk, PACKED_VALID)
  begin
    if(PACKED_VALID(0) = '1') then
      sample_count_d <= sample_count_q + 1;
    else
      sample_count_d <= sample_count_q;
    end if;
    
    if(reset = '1') then
      sample_count_q <= (others => '0');
    elsif(rising_edge(FCO_clk)) then
      sample_count_q <= sample_count_d;       
    end if;
  end process C_SAMPLE_COUNT;
      
  G_FILL : for i in 0 to 7 generate
   U_STORE_SAMPLE : sample_ram
   port map (
     clka  => FCO_clk,
     wea   => PACKED_VALID(i downto i),
     addra => sample_count_q,
     dina  => PACKED_SAMPLE(i),
     clkb  => FCO_clk,
     addrb => sample_count_q,
     doutb => debug_sample(i)
   ); 
   end generate G_FILL;          
  
  -------------------
  -- LVDS Conversion
  -------------------
  
  -- Clocks
  DCO_CLK : IBUFDS 
  port map (
    O  => DCO_clk,
    I  => DCO_clk_p,
    IB => DCO_clk_n
  );  
  
  
  FCO_CLK : IBUFDS 
  port map (
    O  => FCO_clk,
    I  => FCO_clk_p,
    IB => FCO_clk_n
  );  
  
  DATA_BANK_DDR_i <= DATA_BANK_BUF_o;
  -- Data
  G_DATA : for i in 0 to 7 generate
    DATA_BANK_1 : IBUFDS
    port map (
      O  => DATA_BANK_BUF_o(i),
      I  => adc_raw_samples_in_p(i),
      IB => adc_raw_samples_in_n(i)
    );
	
	SAMP_1 : IDDR
	generic map (
	  DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"
    ) port map (
	  Q1 => DATA_BANK_R(i),
	  Q2 => DATA_BANK_F(i),
	  C  => DCO_clk,
	  CE => '1',
	  D  => DATA_BANK_DDR_i(i) ,
	  R  => reset,
	  S  => '0'
	);
  end generate G_DATA;
  
  reset <= delay_rst_q(15);
  
  S_RESET : process (DCO_clk, delay_rst_q)
  begin 
    delay_rst_d <= delay_rst_q(14 downto 0) & '0';
    if (rising_edge(DCO_clk)) then
      delay_rst_q <= delay_rst_d;
    end if;
  end process S_RESET;
    
end STRUCTURE;
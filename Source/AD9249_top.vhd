library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity AD9249_top is 
  port (
    RESET     : in  std_logic;
	
	-- AD9249 Clocks
	--SAMP_CLK_P : in std_logic; -- Not needed
	--SAMP_CLK_M : in std_logic;
	
	FCO_1_P : in std_logic; -- Frame Clock
	FCO_1_M : in std_logic;
	FCO_2_P : in std_logic;
	FCO_2_M : in std_logic;
	
	DCO_1_P : in std_logic; -- Data Clock (7x frame clock, phase shifted)
	DCO_1_M : in std_logic;
	DCO_2_P : in std_logic;
	DCO_2_M : in std_logic;
	
	-- AD9249 Data	
	DATA_BANK_1_P  : in std_logic_vector(7 downto 0);
	DATA_BANK_1_M  : in std_logic_vector(7 downto 0);
	DATA_BANK_2_P  : in std_logic_vector(7 downto 0);
	DATA_BANK_2_M  : in std_logic_vector(7 downto 0);
	
	-- AD9249 SPI
	CSB1 : out std_logic;
	CSB2 : out std_logic;
	SCLK : out std_logic;
	SDIO : out std_logic; -- technically inout
	
	PDWN : out std_logic	
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
      
  component IBUFDS
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
signal DCO_1, DCO_2 : std_logic;
signal FCO_1, FCO_2 : std_logic;
signal DATA_BANK_1_BUF_o, DATA_BANK_2_BUF_o : std_logic_vector(7 downto 0);
signal DATA_BANK_1_DDR_i, DATA_BANK_2_DDR_i : std_logic_vector(7 downto 0);
signal DATA_BANK_1_R, DATA_BANK_1_F : std_logic_vector(7 downto 0);
signal DATA_BANK_2_R, DATA_BANK_2_F : std_logic_vector(7 downto 0);

type T_2Dsample is array (natural range <>) of std_logic_vector(13 downto 0);
signal PACKED_SAMPLE_1, PACKED_SAMPLE_2 : T_2Dsample(7 downto 0);
signal PACKED_VALID_1, PACKED_VALID_2 : std_logic_vector(7 downto 0);

type RAM is array (1024 downto 0) of T_2Dsample(7 downto 0);
signal DATA_STORE_1, DATA_STORE_2 : RAM;

attribute mark_debug : string;
attribute keep : string;

attribute mark_debug of DATA_STORE_1 : signal is "true";
attribute mark_debug of DATA_STORE_2 : signal is "true";
    
begin
  -----------
  -- Outputs 
  -----------
  CSB1 <= '1';
  CSB2 <= '1';
  SCLK <= '0';
  SDIO <= '0';
  PDWN <= '0';
  
  ---------------
  -- Data Capture
  ---------------
  G_PACK : for i in 0 to 7 generate
    BANK1 : sample_packer
    port map (
      RESET         => RESET,
      FRAME_CLK     => FCO_1, 
      DATA_CLK      => DCO_1,
      DATA_SAMPLE_R => DATA_BANK_1_R(i),
      DATA_SAMPLE_F => DATA_BANK_1_F(i),
      
      PACKED_SAMPLE => PACKED_SAMPLE_1(i),
      PACKED_VALID  => PACKED_VALID_1(i)
    );
   
    BANK2 : sample_packer
    port map (
      RESET         => RESET,
      FRAME_CLK     => FCO_2, 
      DATA_CLK      => DCO_2,
      DATA_SAMPLE_R => DATA_BANK_2_R(i),
      DATA_SAMPLE_F => DATA_BANK_2_F(i),
            
      PACKED_SAMPLE => PACKED_SAMPLE_2(i),
      PACKED_VALID  => PACKED_VALID_2(i)
    );
  end generate G_PACK;
  
  -----------
  -- Storage
  -----------
  G_FILL : for i in 0 to 7 generate
    S_FILL_1 : process (PACKED_VALID_1(i))
    variable samp_count : integer range 0 to 1023 := 0;
    begin
      if (PACKED_VALID_1(i) = '1') then 
        DATA_STORE_1(samp_count)(i) <= PACKED_SAMPLE_1(i);
        samp_count := samp_count + 1;
      end if;
    end process S_FILL_1;  
    
    S_FILL_2 : process (PACKED_VALID_2(i))
      variable samp_count : integer range 0 to 1023 := 0;
      begin
        if (PACKED_VALID_2(i) = '1') then 
          DATA_STORE_2(samp_count)(i) <= PACKED_SAMPLE_2(i);
          samp_count := samp_count + 1;
        end if;
     end process S_FILL_2; 
   end generate G_FILL;          
  
  -------------------
  -- LVDS Conversion
  -------------------
  
  -- Clocks
  DCO_1_CLK : IBUFDS  -- IBUFGDS may be necessary
  port map (
    O  => DCO_1,
    I  => DCO_1_P,
    IB => DCO_1_M
  );  
  
  DCO_2_CLK : IBUFDS
  port map (
    O  => DCO_2,
    I  => DCO_2_P,
    IB => DCO_2_M
  ); 
  
  FCO_1_CLK : IBUFDS 
  port map (
    O  => FCO_1,
    I  => FCO_1_P,
    IB => FCO_1_M
  );  
  
  FCO_2_CLK : IBUFDS
  port map (
    O  => FCO_2,
    I  => FCO_2_P,
    IB => FCO_2_M
  ); 
  
  DATA_BANK_1_DDR_i <= DATA_BANK_1_BUF_o;
  DATA_BANK_2_DDR_i <= DATA_BANK_2_BUF_o;
  -- Data
  G_DATA : for i in 0 to 7 generate
    DATA_BANK_1 : IBUFDS
    port map (
      O  => DATA_BANK_1_BUF_o(i),
      I  => DATA_BANK_1_P(i),
      IB => DATA_BANK_1_M(i)
    );
	
	SAMP_1 : IDDR
	generic map (
	  DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"
    ) port map (
	  Q1 => DATA_BANK_1_R(i),
	  Q2 => DATA_BANK_1_F(i),
	  C  => DCO_1,
	  CE => '1',
	  D  => DATA_BANK_1_DDR_i(i) ,
	  R  => RESET,
	  S  => '0'
	);
	
    DATA_BANK_2 : IBUFDS
    port map (
      O  => DATA_BANK_2_BUF_o(i),
      I  => DATA_BANK_2_P(i),
      IB => DATA_BANK_2_M(i)
    );
          
    SAMP_2 : IDDR
    generic map (
      DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"
    ) port map (
      Q1 => DATA_BANK_2_R(i),
      Q2 => DATA_BANK_2_F(i),
      C  => DCO_2,
      CE => '1',
      D  => DATA_BANK_2_DDR_i(i) ,
      R  => RESET,
      S  => '0'
    );    
  end generate G_DATA;
end STRUCTURE;
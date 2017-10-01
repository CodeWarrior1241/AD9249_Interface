library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;
library UNISIM;
  use UNISIM.vcomponents.all;

entity adc_data_sync is
  port (
    DatIn_p      : in  std_logic;
    DatIn_n      : in  std_logic;
    DatClk       : in  std_logic;
    DatClkDiv    : in  std_logic;
    DatRst       : in  std_logic;
    DatEna       : in  std_logic;
    DatDone      : in  std_logic;
    DatBitSlip_p : in  std_logic;
    DatBitSlip_n : in  std_logic;
    DatMsbRegEna : in  std_logic;
    DatLsbRegEna : in  std_logic;
    DatReSync    : in  std_logic;
    DatOut       : out std_logic_vector(13 downto 0)
  );
end adc_data_sync;

architecture RTL of adc_data_sync is

signal IntDatClk		: std_logic;
signal IntDatClk_n		: std_logic;
signal IntDatDone		: std_logic;
signal IntDatEna 		: std_logic;
signal IntDatSrdsOut    : std_logic_vector(7 downto 0);
signal IntDatSrds       : std_logic_vector(7 downto 0);
begin
--
-- DatRst and DatEna are synchronised to DatClkDiv on the level were this component "AdcData"
-- is used. This higher level is "AdcToplevel".
AdcData_Done_PROCESS : process (DatClkDiv, DatRst)
begin
	if (DatRst = '1') then
		IntDatDone <= '0';
	elsif (DatClkDiv'event and DatClkDiv = '1') then
        IntDatDone <= DatDone;
	end if;
end process;
--
-----------------------------------------------------------------------------------------------
IntDatClk <= DatClk;			-- CLOCK FOR P-side ISERDES
IntDatClk_n <= not DatClk;		-- CLOCK FOR N_side ISERDES

-----------------------------------------------------------------------------------------------
-- ISERDES 
-----------------------------------------------------------------------------------------------
  Isrds_Data_p : ISERDESE2
    generic map (
		SERDES_MODE			=> "MASTER",		
		INTERFACE_TYPE		=> "NETWORKING",		
		IOBDELAY			=> "NONE",				
		DATA_RATE 			=> "SDR", 				
		DATA_WIDTH 			=> 4,               
		DYN_CLKDIV_INV_EN	=> "FALSE", 
		DYN_CLK_INV_EN		=> "FALSE",
		NUM_CE				=> 1, 		
		OFB_USED			=> "FALSE",
        INIT_Q1             => '0',         
        INIT_Q2             => '0',         
        INIT_Q3             => '0',       
        INIT_Q4             => '0',       
        SRVAL_Q1            => '0',        
        SRVAL_Q2            => '0',         
        SRVAL_Q3            => '0',       
        SRVAL_Q4            => '0'         
    )
    port map (
		D				=> DatIn_p,
		DDLY			=> '0', 	 
		OFB				=> '0', 	
		BITSLIP			=> DatBitSlip_p,
		CE1				=> IntDatDone,
		CE2				=> '0',		
		RST				=> DatRst,	
		CLK				=> IntDatClk,
		CLKB			=> '0', 	
		CLKDIV			=> DatClkDiv,
        CLKDIVP         => '0',    
		OCLK			=> '0', 	
        OCLKB           => '0',    
		DYNCLKDIVSEL	=> '0', 	
		DYNCLKSEL		=> '0', 	
		SHIFTOUT1		=> open, 	
		SHIFTOUT2		=> open, 	
		O				=> open, 	
		Q1				=> IntDatSrdsOut(6), 
		Q2				=> IntDatSrdsOut(4), 
		Q3				=> IntDatSrdsOut(2), 
		Q4				=> IntDatSrdsOut(0), 
		Q5				=> open, 		--out
		Q6				=> open, 		--out
        Q7              => open,        --out
        Q8              => open,        --out
		SHIFTIN1		=> '0', 		--in
		SHIFTIN2		=> '0' 			--in
  );
  Isrds_Data_n : ISERDESE2
    generic map (
	  SERDES_MODE			=> "MASTER",			
	  INTERFACE_TYPE		=> "NETWORKING",		
	  IOBDELAY			    => "NONE",				
	  DATA_RATE 			=> "SDR", 				
	  DATA_WIDTH 			=> 4,	
	  DYN_CLKDIV_INV_EN  	=> "FALSE",      		
	  DYN_CLK_INV_EN		=> "FALSE", 			
	  NUM_CE				=> 1, 					
	  OFB_USED			    => "FALSE", 			
      INIT_Q1               => '0',        
      INIT_Q2               => '0',        
      INIT_Q3               => '0',        
      INIT_Q4               => '0',        
      SRVAL_Q1              => '0',        
      SRVAL_Q2              => '0',        
      SRVAL_Q3              => '0',        
      SRVAL_Q4              => '0'         
    )
    port map (
    D				=> DatIn_n,		
	DDLY			=> '0', 		   
	OFB				=> '0', 		
	BITSLIP			=> DatBitSlip_n,
	CE1				=> IntDatDone,	
	CE2				=> '0',			
	RST				=> DatRst,	    
	CLK				=> IntDatClk_n,
	CLKB			=> '0', 		
	CLKDIV			=> DatClkDiv, 	
    CLKDIVP         => '0',        
	OCLK			=> '0', 		
    OCLKB           => '0',        
	DYNCLKDIVSEL	=> '0', 		
	DYNCLKSEL		=> '0', 		
	SHIFTOUT1		=> open, 		
	SHIFTOUT2		=> open, 		
	O				=> open, 		
	Q1				=> IntDatSrdsOut(7), 
	Q2				=> IntDatSrdsOut(5), 
	Q3				=> IntDatSrdsOut(3), 
	Q4				=> IntDatSrdsOut(1), 
	Q5				=> open, 		
	Q6				=> open, 		
    Q7              => open,        
    Q8              => open,        
	SHIFTIN1		=> '0', 		
	SHIFTIN2		=> '0' 			
  );

  IntDatSrds  <= not IntDatSrdsOut(7) & IntDatSrdsOut(6) &
				 not IntDatSrdsOut(5) & IntDatSrdsOut(4) &
				 not IntDatSrdsOut(3) & IntDatSrdsOut(2) &
				 not IntDatSrdsOut(1) & IntDatSrdsOut(0);
				 
   Gen_1_HL : for n in 0 to 7 generate
     I_Fdce_HH : FDCE
       generic map (INIT => '0')
       port map (D => IntDatSrds(n), CE => DatMsbRegEna, C => DatClkDiv,
                 CLR => DatReSync, Q => DatOut(n+6));
     REMOVE_LSB : if n > 1 generate
       I_Fdce_LL : FDCE
         generic map (INIT => '0')
         port map (D => IntDatSrds(n), CE => DatLsbRegEna, C => DatClkDiv,
                   CLR => DatReSync, Q => DatOut(n-2));
     end generate REMOVE_LSB;
  end generate Gen_1_HL;
	
end RTL;
 
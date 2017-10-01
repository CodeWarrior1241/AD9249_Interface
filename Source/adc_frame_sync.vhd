library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;
library UNISIM;
  use UNISIM.vcomponents.all;
  
entity adc_frame_sync is 
  port (
    BitClk         : in  std_logic;
    BitClkRef      : in  std_logic;
    BitClkDone     : in  std_logic;
    BitClkENA      : in  std_logic;
    BitClkRST      : in  std_logic;
    FCLK_p         : in  std_logic;
    FCLK_n         : in  std_logic;
    FCLK_BitSlip_p : out std_logic;
    FCLK_BitSlip_n : out std_logic;
    FClkReSyncOut  : out std_logic;
    FClkMsbEna     : out std_logic;
    FCLKLsbEna     : out std_logic
  );
end adc_frame_sync;

architecture RTL of adc_frame_sync is
    function SymChck (Inp: std_logic_vector) return std_logic is
	variable Temp : std_logic_vector ((Inp'left-1)/2 downto 0) := (others => '0');
	variable Sym : std_logic := '0';
	begin
		for n in (Inp'left-1)/2 downto 0 loop
			Temp(n) := Inp((n*2)+1) xor Inp(n*2);
			Sym := Temp(n) or Sym;
		end loop;
	return Sym;
	end function SymChck;
	
	function BitShft(Inp: std_logic_vector) return std_logic_vector is
	variable Temp : std_logic_vector (Inp'range):= (others => '0');
	begin
-- Bit shift all bits.
-- Example: 16-bit frame word = 11111111_00000000 or 00000000_11110000
-- After shifting the word returned looks as: 11111110_00000001 and 00000000_01111000
		if (SymChck(Inp) = '0') then
		  for n in Inp'left downto 0 loop
		    if (n /= 0) then
			  Temp(n) := Inp(n-1);
			elsif (n = 0) then
			  Temp(Temp'right) := Inp(Inp'left);
			end if;
		  end loop;
		elsif (SymChck(Inp) = '1') then
		-- Don't do anything, return the word as it came in.
			Temp := Inp;
		end if;
		--
	return Temp;
	end function BitShft;
	function BitSwap(Inp: std_logic_vector) return std_logic_vector is
	variable Temp : std_logic_vector (Inp'range);
	begin
		for n in (Inp'left-1)/2 downto 0 loop
			Temp((n*2)+1) := Inp(n*2);
			Temp(n*2) := Inp((n*2)+1);
		end loop;
	return Temp;
	end function BitSwap;

constant IntPattern	: std_logic_vector(13 downto 0)	:= "11111110000000";
-- Shift the pattern for one bit.
constant IntPatternBitShifted :	std_logic_vector(13 downto 0)	:= BitShft(IntPattern);
-- Define the bytes for pattern comparison.
-- Bit swap the by one bit shifted pattern.
constant IntPatternBitSwapped : std_logic_vector(13 downto 0)	:= BitSwap(IntPatternBitShifted);
constant IntPatternA : std_logic_vector(6 downto 0) := IntPatternBitShifted(13 downto 7);
constant IntPatternB : std_logic_vector(6 downto 0) := IntPatternBitShifted(6 downto 0);
constant IntPatternC : std_logic_vector(6 downto 0) := IntPatternBitSwapped(13 downto 7);
constant IntPatternD : std_logic_vector(6 downto 0) := IntPatternBitSwapped(6 downto 0);
		
signal IntFrmClk, IntFrmClk_n : std_logic;
signal IntFrmEna : std_logic;
signal IntFrmSrdsOut : std_logic_vector(7 downto 0);
signal IntFrmBitSlip : std_logic_vector(5 downto 0);
signal IntFrmSrdsDatEvn, IntFrmSrdsDatOdd : std_logic_vector(3 downto 0);
signal IntFrmSrdsDatEvn_d, IntFrmSrdsDatOdd_d : std_logic_vector(3 downto 0);
signal IntFrmDbleNibFnlEvn, IntFrmDbleNibFnlOdd : std_logic;
signal IntFrmDbleNibFnlEvn_d, IntFrmDbleNibFnlOdd_d : std_logic;
signal IntFrmDbleNibFnl : std_logic;
--
signal IntFrmEvntCnt		        : std_logic_vector (3 downto 0); -- count event counter
signal IntFrmEvntCntTc		        : std_logic;
signal IntFrmEvntCntTc_d	        : std_logic;
signal IntFrmSlipCnt		        : std_logic_vector (3 downto 0); -- count to 8
signal IntFrmSlipCntTc		        : std_logic;
signal IntFrmSlipCntTc_d1           : std_logic;
signal IntFrmSlipCntTc_d	        : std_logic;
signal IntFrmSlipCntTc_d2Ena        : std_logic;
signal IntFrmSlipCntTc_d2           : std_logic;
signal IntFrmClkReSync              : std_logic;
signal IntFrmReSyncOut		        : std_logic; 
--
signal IntFrmEquSet_d		        : std_Logic;
signal IntFrmEqu_d                  : std_logic;
signal IntFrmEquGte                 : std_logic;
signal IntFrmCmp                    : std_logic_vector(3 downto 0);
signal IntFrmSrdsDat                : std_logic_vector(7 downto 0);
--
signal IntFrmSwapMux_d		        : std_logic;
signal IntFrmSwapMux_d_Ena          : std_logic;
signal IntFrmLsbMsb_d 		        : std_logic;
signal IntFrmLsbMsb_d_Ena           : std_logic;
signal IntFrmMsbAllZero_d 	        : std_logic;
signal IntFrmMsbAllZero_d_Ena       : std_logic;
--
signal IntFrmRegEna_d		        : std_logic;
signal IntFrmMsbRegEna_d	        : std_logic;
signal IntFrmLsbRegEna_d	        : std_logic;
begin
-----------------------------------------------------------------------------------------------
-- ISERDES FOR FRAME CAPTURE
-----------------------------------------------------------------------------------------------
IntFrmClk <= BitClk;
IntFrmClk_n <= not BitClk;

frame_i_srds_p : ISERDESE2
  generic map (
    SERDES_MODE         => "MASTER",         
    INTERFACE_TYPE      => "NETWORKING",     
    IOBDELAY            => "NONE",           
    DATA_RATE           => "SDR",            
    DATA_WIDTH          => 4,
    DYN_CLKDIV_INV_EN   => "FALSE",          
    DYN_CLK_INV_EN      => "FALSE",          
    NUM_CE              => 1,                
    OFB_USED            => "FALSE",          
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
    D				     => FCLK_p,		 
    DDLY                 => '0',             
    OFB                  => '0',             
    BITSLIP              => IntFrmBitSlip(0),
    CE1                  => IntFrmEna,       
    CE2                  => '0',             
    RST                  => BitClkRST,       
    CLK                  => IntFrmClk,       
    CLKB                 => '0',             
    CLKDIV               => BitClkRef,       
    CLKDIVP              => '0',             
    OCLK                 => '0',             
    OCLKB                => '0',             
    DYNCLKDIVSEL         => '0',             
    DYNCLKSEL            => '0',             
    SHIFTOUT1            => open,            
    SHIFTOUT2            => open,            
    O                    => open,            
    Q1                   => IntFrmSrdsOut(6),
    Q2                   => IntFrmSrdsOut(4),
    Q3                   => IntFrmSrdsOut(2),
    Q4                   => IntFrmSrdsOut(0),
    Q5                   => open,            
    Q6                   => open,            
    Q7                   => open,            
    Q8                   => open,            
    SHIFTIN1             => '0',             
    SHIFTIN2             => '0'              
  );
 
 frame_i_srds_n : ISERDESE2
   generic map (
     SERDES_MODE         => "MASTER",         
     INTERFACE_TYPE      => "NETWORKING",     
     IOBDELAY            => "NONE",           
     DATA_RATE           => "SDR",            
     DATA_WIDTH          => 4,
     DYN_CLKDIV_INV_EN   => "FALSE",          
     DYN_CLK_INV_EN      => "FALSE",          
     NUM_CE              => 1,                
     OFB_USED            => "FALSE",          
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
     D                    => FCLK_n,         
     DDLY                 => '0',             
     OFB                  => '0',             
     BITSLIP              => IntFrmBitSlip(1),
     CE1                  => IntFrmEna,       
     CE2                  => '0',             
     RST                  => BitClkRST,       
     CLK                  => IntFrmClk_n,       
     CLKB                 => '0',             
     CLKDIV               => BitClkRef,       
     CLKDIVP              => '0',             
     OCLK                 => '0',             
     OCLKB                => '0',             
     DYNCLKDIVSEL         => '0',             
     DYNCLKSEL            => '0',             
     SHIFTOUT1            => open,            
     SHIFTOUT2            => open,            
     O                    => open,            
     Q1                   => IntFrmSrdsOut(7),
     Q2                   => IntFrmSrdsOut(5),
     Q3                   => IntFrmSrdsOut(3),
     Q4                   => IntFrmSrdsOut(1),
     Q5                   => open,            
     Q6                   => open,            
     Q7                   => open,            
     Q8                   => open,            
     SHIFTIN1             => '0',             
     SHIFTIN2             => '0'              
   );
   
   IntFrmSrdsDatEvn <= IntFrmSrdsOut(6) & IntFrmSrdsOut(4) &
                       IntFrmSrdsOut(2) & IntFrmSrdsOut(0);
   IntFrmSrdsDatOdd <= not IntFrmSrdsOut(7) & not IntFrmSrdsOut(5) &
                       not IntFrmSrdsOut(3) & not IntFrmSrdsOut(1); 
                       
   u_DblNibDetectEvn : entity work.DoubleNibbleDetect
     port map (
       Clock   => BitClkRef, 
       RstIn   => BitClkRST,
       Final   => IntFrmDbleNibFnlEvn,
       DataIn  => IntFrmSrdsDatEvn,
       DataOut => IntFrmSrdsDatEvn_d
     );
     
     u_DblNibDetectOdd : entity work.DoubleNibbleDetect
       port map (
         Clock   => BitClkRef, 
         RstIn   => BitClkRST,
         Final   => IntFrmDbleNibFnlOdd,
         DataIn  => IntFrmSrdsDatOdd,
         DataOut => IntFrmSrdsDatOdd_d
       );
       
     C_DblNib : process (BitClkRef, BitClkRST)
     begin
       if (BitClkRST = '1' ) then
           IntFrmDbleNibFnlOdd_d <= '0';
           IntFrmDbleNibFnlEvn_d <= '0';
       elsif (BitClkRef'event and BitClkRef = '1') then
           if (IntFrmDbleNibFnlOdd = '1') then
               IntFrmDbleNibFnlOdd_d <= '1';
           else --(IntFrmDbleNibFnlOdd = '0')
               IntFrmDbleNibFnlOdd_d <= '0';
           end if;
           if (IntFrmDbleNibFnlEvn = '1') then
               IntFrmDbleNibFnlEvn_d <= '1';
           else --(IntFrmDbleNibFnlOdd = '0')
               IntFrmDbleNibFnlEvn_d <= '0';
           end if;
       end if;
     end process C_DblNib;
    
     IntFrmDbleNibFnl <= IntFrmDbleNibFnlOdd_d and IntFrmDbleNibFnlEvn_d;
     -----------------------------------------------------------------------------------------------
     -- OUTPUT REGISTER ENABLER
     -----------------------------------------------------------------------------------------------
     AdcFrame_EnaSel_PROCESS : process (BitClkRef, IntFrmMsbAllZero_d, IntFrmEqu_d)
     subtype IntFrmRegEnaCase is std_logic_vector(4 downto 0);
     begin
         if (IntFrmMsbAllZero_d = '1') then
             IntFrmRegEna_d <= '0';
             IntFrmMsbRegEna_d <= '1';
             IntFrmLsbRegEna_d <= '1';
         elsif (BitClkRef'event and BitClkRef = '1') then
             case IntFrmRegEnaCase'(IntFrmLsbMsb_d, IntFrmEqu_d, IntFrmRegEna_d,
                                         IntFrmMsbRegEna_d, IntFrmLsbRegEna_d) is
                 when "00001" =>    IntFrmRegEna_d <= '0';
                                 IntFrmMsbRegEna_d <= '0'; -- A
                                 IntFrmLsbRegEna_d <= '1'; --
                 when "01001" =>    IntFrmRegEna_d <= '1';
                                 IntFrmMsbRegEna_d <= '0'; -- B
                                 IntFrmLsbRegEna_d <= '1'; --
                 when "01101" =>    IntFrmRegEna_d <= '1';
                                 IntFrmMsbRegEna_d <= '1'; -- C
                                 IntFrmLsbRegEna_d <= '0'; --
                 when "01110" =>    IntFrmRegEna_d <= '1';
                                 IntFrmMsbRegEna_d <= '0'; -- D, goto C 
                                 IntFrmLsbRegEna_d <= '1'; --
                 --
                 when "11001" =>    IntFrmRegEna_d <= '1';
                                 IntFrmMsbRegEna_d <= '1'; -- E
                                 IntFrmLsbRegEna_d <= '0'; --
                 when "11110" =>    IntFrmRegEna_d <= '1';
                                 IntFrmMsbRegEna_d <= '0'; -- F
                                 IntFrmLsbRegEna_d <= '1'; --
                 when "11101" =>    IntFrmRegEna_d <= '1';
                                 IntFrmMsbRegEna_d <= '1'; -- G, goto F
                                 IntFrmLsbRegEna_d <= '0'; --
                 --
                 when others =>    IntFrmRegEna_d <= '0';
                                 IntFrmMsbRegEna_d <= '0';
                                 IntFrmLsbRegEna_d <= '1';
             end case;
         end if;
     end process;
     FClkMsbEna <= IntFrmMsbRegEna_d;
     FClkLsbEna <= IntFrmLsbRegEna_d;
     -----------------------------------------------------------------------------------------------
     -- SAMPLE EVENT COUNTER
     -- Take a frame sample every 16 ClkDiv cycles.
     -----------------------------------------------------------------------------------------------
     C_event_cnt : process (BitClkRef, IntFrmReSyncOut)
     begin
         if (IntFrmReSyncOut = '1') then
             IntFrmEvntCnt <= (others => '0');
             IntFrmEvntCntTc_d <= '0';
         elsif (BitClkRef'event and BitClkRef = '1') then
             if (IntFrmEquSet_d = '0' and IntFrmEna = '1') then
                 IntFrmEvntCnt <= IntFrmEvntCnt + "01";
                 IntFrmEvntCntTc_d <= IntFrmEvntCntTc;
             end if;
         end if;
     end process;
     IntFrmEvntCntTc <= '1' when (IntFrmEvntCnt = "1110") else '0';
   
   -----------------------------------------------------------------------------------------------
     -- BITSLIP EVENT COUNTER
     -- Bitslip 8 times for a 8-bit ISERDES and 6 times for a 6-bit ISERDES.
     -----------------------------------------------------------------------------------------------
     C_slip_cnt : process (BitClkRef, IntFrmReSyncOut)
     begin
         if (IntFrmReSyncOut = '1') then
             IntFrmSlipCnt <= (others => '0');
         elsif (BitClkRef'event and BitClkRef = '1') then
             if (IntFrmEvntCntTc_d = '1') then
                 IntFrmSlipCnt <= IntFrmSlipCnt + "01";
             end if;
             if (IntFrmEvntCntTc_d = '1' and IntFrmSlipCntTc = '1') then
                 IntFrmSlipCntTc_d <= '1';
             else 
                 IntFrmSlipCntTc_d <= '0';
             end if;
         end if;
     end process;
     IntFrmSlipCntTc <= '1' when (IntFrmSlipCnt = "1101") else '0'; -- 14 bit adc
     
     SlipCntTc_1_reg : FDCE
         generic map (INIT => '0')
         port map (D => '1', CE => IntFrmSlipCntTc_d, C => BitClkRef,
                   CLR => IntFrmSlipCntTc_d2, Q => IntFrmSlipCntTc_d1);
     IntFrmSlipCntTc_d2Ena <= IntFrmSlipCntTc_d and IntFrmSlipCntTc_d1;
     SlipCntTc_2_reg : FDCE
         generic map (INIT => '0')
         port map (D => IntFrmSlipCntTc_d2Ena, CE => '1', C => BitClkRef,
                   CLR => IntFrmReSyncOut, Q => IntFrmSlipCntTc_d2);

     -----------------------------------------------------------------------------------------------
     -- Enable, RESYNC or INTERNAL RESET
     -- This is the reset logic for the whole design.
     -- Whenever one of these signals (IntFrmSlipCntTc_d2, IntFrmDbleNibFnl, FrmClkReSync, FrmClkRst)
     -- is high the circuit is pulled int reset (call it a re-sync operation).
     -- 
     -- The only components not influenced by this are the ISERDES and the Sync Warning Counter.
     -- they only act on the extrenal "FrmClkRst" input.
     -- 
     -- A circuit enable "IntFrmEna" is generated when the inputs "FrmClkDone" and "FrmClkEna" are
     -- high and when the "IntFrmReSync" reset is released.
     -----------------------------------------------------------------------------------------------
     IntFrmReSyncOut <= IntFrmSlipCntTc_d2 or IntFrmDbleNibFnl or BitClkRST;
     FClkReSyncOut <= IntFrmReSyncOut;
     --
     Done_reg : FDCE
         generic map (INIT => '0')
         port map(D => BitClkDone, CE => BitClkENA, C => BitClkRef, CLR => IntFrmReSyncOut,
                  Q => IntFrmEna);
     
     -----------------------------------------------------------------------------------------------
     -- BITSLIP STATE MACHINE.
     -----------------------------------------------------------------------------------------------
     C_Bitslip : process (IntFrmReSyncOut, BitClkRef)
     subtype IntFrmBitSlipCase is std_logic_vector(5 downto 0);
     begin
         if (IntFrmReSyncOut = '1') then
             IntFrmBitSlip <= (others => '0');
         elsif (BitClkRef'event and BitClkRef = '1') then
             if (IntFrmEna = '1' and IntFrmEquSet_d = '0') then
                 case IntFrmBitSlipCase'(IntFrmEqu_d, IntFrmEvntCntTc_d, IntFrmBitSlip(5),
                                         IntFrmBitSlip(4), IntFrmBitSlip(3), IntFrmBitSlip(2)) is
                     when "000000" => IntFrmBitSlip <= "000000"; -- B 
                     when "010000" => IntFrmBitSlip <= "000101"; -- C Slip_p
                     when "000001" => IntFrmBitSlip <= "000100"; -- D
                     when "010001" => IntFrmBitSlip <= "001010"; -- E Slip_n
                     when "000010" => IntFrmBitSlip <= "001000"; -- F
                     when "010010" => IntFrmBitSlip <= "000101"; -- G Slip_p and goto D
                     --
                     when "100000" => IntFrmBitSlip <= "000000"; -- H 
                     when "110000" => IntFrmBitSlip <= "100101"; -- K Slip_p
                     when "101001" => IntFrmBitSlip <= "110000"; -- L EquSet
                     when "101100" => IntFrmBitSlip <= "110000"; -- M Halt
                     --
                     when "100001" => IntFrmBitSlip <= "000100"; -- N
                     when "110001" => IntFrmBitSlip <= "101010"; -- P Slip_n
                     when "101010" => IntFrmBitSlip <= "110000"; -- R EquSet goto M
                     --
                     when "100010" => IntFrmBitSlip <= "001000"; -- S
                     when "110010" => IntFrmBitSlip <= "100101"; -- T Slip_p goto L
                     --
                     when others => IntFrmBitSlip <= "110000";
                 end case;
             end if;
         end if;
     end process;
     FCLK_BitSlip_p <= IntFrmBitSlip(0);
     FCLK_BitSlip_n <= IntFrmBitSlip(1);
     IntFrmEquSet_d <= IntFrmBitSlip(4); 
     
     -----------------------------------------------------------------------------------------------
     -- FRAME PATTERN COMPARATOR 
     -----------------------------------------------------------------------------------------------
     Gen_1_DatBus : for n in 4 downto 1 generate
         IntFrmSrdsDat((n*2)-1) <= IntFrmSrdsDatOdd_d(n-1);
         IntFrmSrdsDat((n*2)-2) <= IntFrmSrdsDatEvn_d(n-1);
     end generate Gen_1_DatBus;
     
     IntFrmCmp(2 downto 0) <= "101" when (IntFrmSrdsDat = IntPatternA) else    -- Equ,     , Msb
                              "100" when (IntFrmSrdsDat = IntPatternB) else    -- Equ,     , Lsb
                              "111" when (IntFrmSrdsDat = IntPatternC) else    -- Equ, swpd, Msb
                              "110" when (IntFrmSrdsDat = IntPatternD) else    -- Equ, Swpd, Lsb
                              "000";
     IntFrmCmp(3) <= '0'; -- Msb = all zero
     IntFrmEquGte <= (IntFrmCmp(2) or IntFrmEqu_d) and IntFrmEna;
     IntFrmMsbAllZero_d_Ena <= IntFrmCmp(2) and not IntFrmEqu_d;
     IntFrmLsbMsb_d_Ena <= IntFrmCmp(2) and not IntFrmEqu_d;
     
     FrmMsbAllZero_d_reg : FDCE
         generic map (INIT => '0')
         port map (D => IntFrmCmp(3), CE => IntFrmMsbAllZero_d_Ena, C => BitClkRef,
                   CLR => IntFrmReSyncOut, Q => IntFrmMsbAllZero_d);
     FrmEqu_reg : FDCE
         generic map (INIT => '0')
         port map (D => IntFrmEquGte, CE => '1', C => BitClkRef,
                   CLR => IntFrmReSyncOut, Q => IntFrmEqu_d);
      FrmLsbMsb_d_reg : FDCE
        generic map (INIT => '0')
        port map (D => IntFrmCmp(0), CE => IntFrmLsbMsb_d_Ena, C => BitClkRef,
                  CLR => IntFrmReSyncOut, Q => IntFrmLsbMsb_d);
     
               
end RTL;
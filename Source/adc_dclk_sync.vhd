library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;
library UNISIM;
  use UNISIM.vcomponents.all;

entity adc_dclk_sync is
  port (
    DCLK         : in  std_logic;
    BitClk_i     : in  std_logic;
    BitClkRef_i  : in  std_logic;
    BitClkRST    : in  std_logic;
    BitClkENA    : in  std_logic;
    BitClk_o     : out std_logic;
    BitClkRef_o  : out std_logic;
    ClkAlignDone : out std_logic
  );
end adc_dclk_sync;

architecture RTL of adc_dclk_sync is
signal IntBitClkRst				: std_logic;
---------- ISRDS signals ------------------
signal IntClkCtrlDlyCe			: std_logic;
signal IntClkCtrlDlyInc			: std_logic;
signal IntClkCtrlDlyRst			: std_logic;

signal IntBitClk_Ddly			: std_logic;
signal IntBitClk				: std_logic;
signal IntClkCtrlIsrdsMtoS1		: std_logic;
signal IntClkCtrlIsrdsMtoS2		: std_logic;
signal IntClkCtrlOut			: std_logic_vector(7 downto 0);
---------- Controller signals -------------
signal IntCal					: std_logic;
signal IntVal					: std_logic;
signal IntCalVal				: std_logic_vector (1 downto 0);
signal IntProceedCnt			: std_logic_vector (2 downto 0);
signal IntproceedCntTc			: std_logic;
signal IntproceedCntTc_d		: std_logic;
signal IntProceed				: std_logic;
signal IntProceedDone			: std_logic;

type StateType is (Idle, A, B, C, D, E, F, G, G1, H, K, K1, K2, IdlyIncDec, Done);
signal State : StateType;
signal ReturnState : StateType;

signal PassedSubState		: std_logic;
signal IntNumIncDecIdly		: std_logic_vector (3 downto 0);
signal IntAction			: std_logic_vector (1 downto 0);
signal IntClkCtrlDone 		: std_logic;
signal IntTurnAroundBit		: std_logic;
signal IntCalValReg			: std_logic_vector (1 downto 0);
signal IntTimeOutCnt		: std_logic_vector (3 downto 0);
signal IntStepCnt	 		: std_logic_vector (3 downto 0);

begin

dclk_i_iodly : IDELAYE2
  generic map (
    SIGNAL_PATTERN          => "CLOCK",
    REFCLK_FREQUENCY        => 200.0,
    HIGH_PERFORMANCE_MODE   => "TRUE",
    DELAY_SRC               => "IDATAIN",
    CINVCTRL_SEL            => "FALSE",
    IDELAY_TYPE             => "VARIABLE",
    IDELAY_VALUE            => 16,
    PIPE_SEL                => "FALSE"
  )
  port map (
    DATAIN      => '0',
    IDATAIN     => DCLK,
    CE          => IntClkCtrlDlyCe,
    INC         => IntClkCtrlDlyInc,
    C           => BitClkRef_i,
    LD          => IntClkCtrlDlyRst,
    LDPIPEEN    => '0',
    REGRST      => IntClkCtrlDlyRst,
    DATAOUT     => IntBitClk_Ddly,
    CINVCTRL    => '0',
    CNTVALUEOUT => open,
    CNTVALUEIN  => (others => '0')
  );

IntClkCtrlDlyRst <= BitClkRST; 

dclk_i_srds : ISERDESE2
  generic map (
    SERDES_MODE         => "MASTER",
    INTERFACE_TYPE      => "NETWORKING",        
    IOBDELAY            => "IBUF",
    DATA_RATE           => "SDR",
    DATA_WIDTH          => 8,
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
    D               => DCLK,
    DDLY            => IntBitClk_Ddly,
    DYNCLKDIVSEL    => '0',
    DYNCLKSEL       => '0',
    OFB             => '0',
    BITSLIP         => '0',
    CE1             => BitClkEna,
    CE2             => '0',
    RST             => IntBitClkRst,
    CLK             => BitClk_i,
    CLKB            => '0',
    CLKDIV          => BitClkRef_i,
    CLKDIVP         => '0',
    OCLK            => '0',
    OCLKB           => '0',
    SHIFTIN1        => '0',
    SHIFTIN2        => '0',
    O               => IntBitClk,
    Q1              => IntClkCtrlOut(0),
    Q2              => IntClkCtrlOut(1),
    Q3              => IntClkCtrlOut(2),
    Q4              => IntClkCtrlOut(3),
    Q5              => IntClkCtrlOut(4),
    Q6              => IntClkCtrlOut(5),
    Q7              => IntClkCtrlOut(6),
    Q8              => IntClkCtrlOut(7),
    SHIFTOUT1       => open,
    SHIFTOUT2       => open
  );
  
  -- Outputs
  dclk_i_bufio : BUFIO
    port map (I => IntBitClk, O => BitClkRef_o);
  
  dclk_i_bufr : BUFR
    generic map (BUFR_DIVIDE => "4", SIM_DEVICE => "7SERIES")
    port map  (I => IntBitClk, O => BitClk_o, CE => '1', CLR => '0');
    
  ClkAlignDone <= IntClkCtrlDone;
-----------------------------------------------------------------------------------------------
-- Bit clock re-synchronizer
-----------------------------------------------------------------------------------------------
IntBitClkRst <= BitClkRST;
-----------------------------------------------------------------------------------------------
-- Bit clock controller for clock alignment input.
-----------------------------------------------------------------------------------------------
-- This input section makes sure 64 bits are captured before action is taken to pass to
-- the statemachine for evaluation.
-- 8 samples of the Bit Clock are taken by the ISERDES and then transferred to the parallel
-- FPGA world. The Proceed counter needs 8 reference clock rising edges before terminal count.
-- The Proceed counter terminal count then loads the 2 control bits (made from sampled clock)
-- into an intermediate register (IntCalVal).
--
-- IntCal = '1' when all outputs of the ISERDES are '1 else it's '0'.
-- IntVal = '1' when all outputs are '0' or '1'.
--
IntCal <= IntClkCtrlOut(7) and IntClkCtrlOut(6) and IntClkCtrlOut(5) and
			IntClkCtrlOut(4) and IntClkCtrlOut(3) and IntClkCtrlOut(2) and
			IntClkCtrlOut(1) and IntClkCtrlOut(0);
IntVal <= '1' when (IntClkCtrlOut = "11111111" or IntClkCtrlOut = "00000000") else '0';

  C_start : process (BitClkENA, IntBitClkRst, BitClkRef_i, IntProceedDone, IntClkCtrlDone)
  begin
  	if (IntBitClkRst = '1') then
  		IntProceedCnt <= (others => '0');
  		IntProceedCntTc_d <= '0';
  		IntCalVal <= (others => '0');
  		IntProceed <= '0';
  	elsif (BitClkRef_i'event and BitClkRef_i = '1') then
  		if (BitClkENA = '1' and IntClkCtrlDone = '0') then
  			IntProceedCnt <= IntProceedCnt + 1;
  			IntProceedCntTc_d <= IntProceedCntTc;
  			if (IntProceedCntTc_d = '1') then
  				IntCalVal <= IntCal & IntVal;
  			end if;
  			if (IntProceedCntTc_d = '1') then
  				IntProceed <= '1';
  			elsif (IntProceedDone = '1') then
  				IntProceed <= '0';
  			end if;
  		end if;
  	end if;
  end process;
  
  IntProceedCntTc <= '1' when (IntProceedCnt = "110") else '0';
  
  -- Alignment state machine
  C_align_clk : process (BitClkRef_i, IntBitClkRst, BitClkENA, IntProceed, IntCalVal)
  subtype ActCalVal is std_logic_vector (4 downto 0);
  begin
    if (IntBitClkRst = '1') then
          State               <= Idle;
          ReturnState         <= Idle;
          PassedSubState      <= '0';
          --
          IntNumIncDecIdly    <= "0000";    -- Max. 16
          IntAction           <= "00";            
          IntClkCtrlDlyInc    <= '1';
          IntClkCtrlDlyCe     <= '0';
          IntClkCtrlDone      <= '0';
          IntTurnAroundBit    <= '0';
          IntProceedDone      <= '0';
          IntClkCtrlDone      <= '0';
          IntCalValReg        <= (others => '0');        -- 2-bit
          IntTimeOutCnt       <= (others => '0');        -- 4-bit
          IntStepCnt          <= (others => '0');        -- 4-bit (16)
      elsif (BitClkRef_i'event and BitClkRef_i = '1') then
          if (BitClkENA = '1' and IntClkCtrlDone = '0') then
          case State is 
              when Idle =>
                  IntProceedDone <= '0';
                  PassedSubState <= '0';
                  case ActCalVal'(IntAction(1 downto 0) & IntCalVal (1 downto 0) & IntProceed) is
                      when "00001" => State <= A;
                      when "01001" => State <= B;
                      when "10001" => State <= B;
                      when "11001" => State <= B;
                      when "01111" => State <= C;
                      when "01101" => State <= D;
                      when "01011" => State <= D;
                      when "00011" => State <= E;
                      when "00101" => State <= E;
                      when "00111" => State <= E;
                      when "10011" => State <= F;
                      when "11011" => State <= F;
                      when "10101" => State <= F;
                      when "11101" => State <= F;
                      when "10111" => State <= F;
                      when "11111" => State <= F;
                      when others => State <= Idle;
                  end case;
              when A =>                         -- First time and sampling in jitter or cross area.
                  IntAction <= "01";                    -- Set the action bits and go to next step.
                  State <= B;
              when B =>                        -- Input is samples in jitter or clock cross area.
                  if (PassedSubState = '1') then
                      PassedSubState <= '0';            -- Clear the pass through the substate bit.
                      IntProceedDone <= '1';            -- Reset the proceed bit.
                      State <= Idle;                    -- Return for a new sample of the input.
                  elsif (IntTimeOutCnt = "1111") then    -- When arriving here something is wrong.
                      IntTimeOutCnt <= "0000";        -- Reset the counter.
                      IntAction <= "00";                -- reset the action bits.
                      IntProceedDone <= '1';            -- Reset the proceed bit.
                      State <= Idle;                    -- Retry, return for new sample of input.
                  else
                      IntTimeOutCnt <= IntTimeOutCnt + 1;
                      IntNumIncDecIdly <= "0010";        -- Number increments or decrements to do.
                      ReturnState <= State;            -- This state is the state to return too.
                      IntProceedDone <= '1';            -- Reset the proceed bit.
                      IntClkCtrlDlyInc <= '1';        -- Set for increment.
                      State <= IdlyIncDec;            -- Jump to Increment/decrement sub-state.
                  end if;
              when C =>                        -- After first sample, jitter or cross, is now high.
                  IntNumIncDecIdly <= "0010";            -- Number increments or decrements to do.
                  ReturnState <= Done;                -- This state is the state to return too.
                  IntClkCtrlDlyInc    <= '0';            -- Set for decrement.
                  State <= IdlyIncDec;
              when D =>                        -- Same as C but with indication of 180-deg shift.
                  State <= C;
              when E =>                        -- First saple with valid data.
                  IntCalValReg <= IntCalVal;            -- Register the sampled value
                  IntAction <= "10";
                  IntProceedDone <= '1';                -- Reset the proceed bit.
                  IntNumIncDecIdly <= "0001";            -- Number increments or decrements to do.
                  ReturnState <= Idle;                -- When increment is done return sampling.
                  IntClkCtrlDlyInc <= '1';            -- Set for increment
                  State <= IdlyIncDec;                -- Jump to Increment/decrement sub-state.
              when F =>                        -- Next samples with valid data.
                  if (IntCalVal /= IntCalValReg) then
                      State <= G;                -- The new CalVal value is different from the first.
                  else
                      if (IntStepCnt = "1111") then     -- Step counter at the end, 15
                          if (IntTurnAroundBit = '0') then 
                              State <= H;                -- No edge found and first time here.
                          elsif (IntCalValReg = "11") then
                              State <= K;            -- A turnaround already happend.
                          else                    -- No edge is found (large 1/2 period).
                              State <= K1;        -- Move the clock edge to near the correct
                          end if;                    -- edge.
                      else
                          IntStepCnt <= IntStepCnt + 1;
                          IntNumIncDecIdly <= "0001";    -- Number increments or decrements to do.
                          IntProceedDone <= '1';        -- Reset the proceed bit.
                          ReturnState <= Idle;        -- When increment is done return sampling.
                          IntClkCtrlDlyInc <= '1';    -- Set for increment
                          State <= IdlyIncDec;        -- Jump to Increment/decrement sub-state.
                      end if;
                  end if;
              when G =>
                  if (IntCalValReg /= "01") then
                      State <= G1;
                  else
                      State <= G1;
                  end if;
              when G1 =>
                  if (IntTimeOutCnt = "00") then
                      State <= Done;
                  else
                      IntNumIncDecIdly <= "0010";    -- Number increments or decrements to do.
                      ReturnState <= Done;        -- After decrement it's finished.
                      IntClkCtrlDlyInc <= '0';    -- Set for decrement
                      State <= IdlyIncDec;        -- Jump to the Increment/decrement sub-state.
                  end if;
              when H =>
                  IntTurnAroundBit <= '1';        -- Indicate that the Idelay jumps to 0.
                  IntStepCnt <= IntStepCnt + 1;    -- Set all registers to zero.
                  IntAction <= "00";                -- Take one step, let the counter flow over 
                  IntCalValReg <= "00";            -- The idelay turn over to 0.
                  IntTimeOutCnt <= "0000";        -- Start sampling from scratch.
                  IntNumIncDecIdly <= "0001";        -- Number increments or decrements to do.
                  IntProceedDone <= '1';            -- Reset the proceed bit.
                  ReturnState <= Idle;            -- After increment go sampling for new.
                  IntClkCtrlDlyInc <= '1';        -- Set for increment.
                  State <= IdlyIncDec;            -- Jump to the Increment/decrement sub-state.
              when K =>
                  IntNumIncDecIdly <= "1111";        -- Number increments or decrements to do.
                  ReturnState <= K2;                -- After increment it is done.
                  IntClkCtrlDlyInc <= '1';        -- Set for increment.
                  State <= IdlyIncDec;            -- Jump to the Increment/decrement sub-state.
              when K1 =>
                  IntNumIncDecIdly <= "1110";        -- Number increments or decrements to do.
                  ReturnState <= K2;                -- After increment it is done.
                  IntClkCtrlDlyInc <= '1';        -- Set for increment.
                  State <= IdlyIncDec;            -- Jump to the Increment/decrement sub-state.
              when K2 =>
                  IntNumIncDecIdly <= "0001";        -- Number increments or decrements to do.
                  ReturnState <= Done;            -- After increment it is done.
                  IntClkCtrlDlyInc <= '1';        -- Set for increment.
                  State <= IdlyIncDec;            -- Jump to the Increment/decrement sub-state.
              --
              when IdlyIncDec =>                -- Increment or decrement by enable.
                  if (IntNumIncDecIdly /= "0000") then            -- Check number of tap jumps
                      IntNumIncDecIdly <= IntNumIncDecIdly - 1;    -- If not 0 jump and decrement.
                      IntClkCtrlDlyCe <= '1';                        -- Do the jump. enable it.
                  else
                      IntClkCtrlDlyCe <= '0';        -- when it is enabled, disbale it
                      PassedSubState <= '1';        -- Set a check bit "I've been here and passed".
                      State <= ReturnState;        -- Return to origin.
                  end if;
              when Done =>                    -- Alignment done.
                  IntClkCtrlDone <= '1';                -- Alignment is done.
          end case;
          end if;
      end if;
  end process;
end RTL;
  
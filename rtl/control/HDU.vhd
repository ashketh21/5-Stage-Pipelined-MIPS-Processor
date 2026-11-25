--------------------------------------------------------------------------------
-- Module      : HazardDetectionUnit
-- Description : Detects load-use data hazards between ID/EX and IF/ID and
--               stalls the PC and IF/ID pipeline register while inserting a
--               bubble (NOP) via ControlMux. Uses Stall_DFF to extend the stall
--               an additional cycle so loaded data completes MEM/WB.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

entity HazardDetectionUnit is
    port (
        GClock           : in  std_logic;
        ID_EX_MemRead    : in  std_logic;
        ID_EX_RegisterRt : in  std_logic_vector(4 downto 0);
        IF_ID_RegisterRs : in  std_logic_vector(4 downto 0);
        IF_ID_RegisterRt : in  std_logic_vector(4 downto 0);
        PCWrite          : out std_logic; -- 1 = normal, 0 = stall
        IF_ID_Write      : out std_logic; -- 1 = normal, 0 = stall
        ControlMux       : out std_logic  -- 1 = insert bubble/NOP, 0 = normal
    );
end entity HazardDetectionUnit;

architecture structural of HazardDetectionUnit is
    signal ID_EX_Rt_EQ_IF_ID_Rs : std_logic;
    signal ID_EX_Rt_EQ_IF_ID_Rt : std_logic;
    signal Hazard_Detected      : std_logic;
    signal Stall_DFF            : std_logic;
begin
    EQ1 : entity work.comparator5Bit(structural)
        port map (
            A       => ID_EX_RegisterRt,
            B       => IF_ID_RegisterRs,
            AequalB => ID_EX_Rt_EQ_IF_ID_Rs
        );

    EQ2 : entity work.comparator5Bit(structural)
        port map (
            A       => ID_EX_RegisterRt,
            B       => IF_ID_RegisterRt,
            AequalB => ID_EX_Rt_EQ_IF_ID_Rt
        );

    Hazard_Detected <= ID_EX_MemRead and (ID_EX_Rt_EQ_IF_ID_Rs or ID_EX_Rt_EQ_IF_ID_Rt);

    -- Extend stall signal by one additional clock cycle
    Stall_DFF_DFF : entity work.enARdFF_2(rtl)
        port map (
            i_reset => '1',
            i_D     => Hazard_Detected,
            i_EN    => '1',
            i_clock => GClock,
            o_Q     => Stall_DFF,
            o_Qn    => open
        );

    PCWrite     <= not (Hazard_Detected or Stall_DFF);
    IF_ID_Write <= not (Hazard_Detected or Stall_DFF);
    ControlMux  <= Hazard_Detected or Stall_DFF;
end architecture structural;

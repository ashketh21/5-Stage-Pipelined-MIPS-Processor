--------------------------------------------------------------------------------
-- Module      : registerFile
-- Description : 32x8-bit MIPS Register File with two asynchronous read ports
--               and one synchronous write port. Register $0 is hardwired to 0.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

entity registerFile is
    port (
        reset     : in  std_logic;
        clk       : in  std_logic;
        RegWrite  : in  std_logic;
        ReadReg1  : in  std_logic_vector(4 downto 0);
        ReadReg2  : in  std_logic_vector(4 downto 0);
        WriteReg  : in  std_logic_vector(4 downto 0);
        WriteData : in  std_logic_vector(7 downto 0);
        ReadData1 : out std_logic_vector(7 downto 0);
        ReadData2 : out std_logic_vector(7 downto 0)
    );
end entity registerFile;

architecture structural of registerFile is
    type R_out_array is array (0 to 31) of std_logic_vector(7 downto 0);

    signal decOut   : std_logic_vector(31 downto 0);
    signal R_out    : R_out_array;
    signal regClock : std_logic_vector(31 downto 0);
begin
    decoder5to32 : entity work.decoder5to32(structural)
        port map (
            s          => WriteReg,
            enable     => '1',
            out_signal => decOut
        );

    gen_clock_signals : for i in 0 to 31 generate
        regClock(i) <= decOut(i) and clk;
    end generate gen_clock_signals;

    gen_registers : for i in 0 to 31 generate
        R0 : entity work.register8Bit(structural)
            port map (
                i_reset => reset,
                i_load  => RegWrite,
                i_clock => regClock(i),
                i_Value => WriteData,
                o_Value => R_out(i)
            );
    end generate gen_registers;

    RegisterFileMUX1 : entity work.mux32to1_8Bit(structural)
        port map (
            sel     => ReadReg1,
            input0  => X"00",
            input1  => R_out(1),
            input2  => R_out(2),
            input3  => R_out(3),
            input4  => R_out(4),
            input5  => R_out(5),
            input6  => R_out(6),
            input7  => R_out(7),
            input8  => R_out(8),
            input9  => R_out(9),
            input10 => R_out(10),
            input11 => R_out(11),
            input12 => R_out(12),
            input13 => R_out(13),
            input14 => R_out(14),
            input15 => R_out(15),
            input16 => R_out(16),
            input17 => R_out(17),
            input18 => R_out(18),
            input19 => R_out(19),
            input20 => R_out(20),
            input21 => R_out(21),
            input22 => R_out(22),
            input23 => R_out(23),
            input24 => R_out(24),
            input25 => R_out(25),
            input26 => R_out(26),
            input27 => R_out(27),
            input28 => R_out(28),
            input29 => R_out(29),
            input30 => R_out(30),
            input31 => R_out(31),
            output  => ReadData1
        );

    RegisterFileMUX2 : entity work.mux32to1_8Bit(structural)
        port map (
            sel     => ReadReg2,
            input0  => X"00",
            input1  => R_out(1),
            input2  => R_out(2),
            input3  => R_out(3),
            input4  => R_out(4),
            input5  => R_out(5),
            input6  => R_out(6),
            input7  => R_out(7),
            input8  => R_out(8),
            input9  => R_out(9),
            input10 => R_out(10),
            input11 => R_out(11),
            input12 => R_out(12),
            input13 => R_out(13),
            input14 => R_out(14),
            input15 => R_out(15),
            input16 => R_out(16),
            input17 => R_out(17),
            input18 => R_out(18),
            input19 => R_out(19),
            input20 => R_out(20),
            input21 => R_out(21),
            input22 => R_out(22),
            input23 => R_out(23),
            input24 => R_out(24),
            input25 => R_out(25),
            input26 => R_out(26),
            input27 => R_out(27),
            input28 => R_out(28),
            input29 => R_out(29),
            input30 => R_out(30),
            input31 => R_out(31),
            output  => ReadData2
        );
end architecture structural;

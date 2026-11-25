--------------------------------------------------------------------------------
-- Module      : CU
-- Description : Main Control Unit for the pipelined MIPS processor.
--               Decodes 6-bit opcodes for R-format, lw, sw, beq, bne, and j,
--               masks write/memory signals during load-use stalls (Hazard = '1'),
--               and asserts IF_Flush on taken branches or jumps.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

entity CU is
    port (
        OPCODE   : in  std_logic_vector(5 downto 0);
        Zero     : in  std_logic;
        Hazard   : in  std_logic;
        RegDst   : out std_logic;
        ALUSrc   : out std_logic;
        MemtoReg : out std_logic;
        RegWrite : out std_logic;
        MemRead  : out std_logic;
        MemWrite : out std_logic;
        Branch   : out std_logic;
        Bne      : out std_logic;
        Jump     : out std_logic;
        IF_Flush : out std_logic;
        ALUOp    : out std_logic_vector(1 downto 0)
    );
end entity CU;

architecture structural of CU is
    signal rformat, lw, sw, beq, bne_int, jump_int : std_logic;
begin
    -- Opcode decoding
    rformat  <= not OPCODE(5) and not OPCODE(4) and not OPCODE(3) and not OPCODE(2) and not OPCODE(1) and not OPCODE(0); -- 000000
    lw       <=     OPCODE(5) and not OPCODE(4) and not OPCODE(3) and not OPCODE(2) and     OPCODE(1) and     OPCODE(0); -- 100011
    sw       <=     OPCODE(5) and not OPCODE(4) and     OPCODE(3) and not OPCODE(2) and     OPCODE(1) and     OPCODE(0); -- 101011
    jump_int <= not OPCODE(5) and not OPCODE(4) and not OPCODE(3) and not OPCODE(2) and     OPCODE(1) and not OPCODE(0); -- 000010
    beq      <= not OPCODE(5) and not OPCODE(4) and not OPCODE(3) and     OPCODE(2) and not OPCODE(1) and not OPCODE(0); -- 000100
    bne_int  <= not OPCODE(5) and not OPCODE(4) and not OPCODE(3) and     OPCODE(2) and not OPCODE(1) and     OPCODE(0); -- 000101

    -- Control signal outputs (MEM/WB enables gated with not Hazard for NOP insertion)
    RegDst   <= rformat;
    ALUSrc   <= lw or sw;
    MemtoReg <= lw and not Hazard;
    RegWrite <= (rformat or lw) and not Hazard;
    MemRead  <= lw and not Hazard;
    MemWrite <= sw and not Hazard;
    Branch   <= beq;
    Bne      <= bne_int;
    Jump     <= jump_int;
    ALUOp(1) <= rformat;
    ALUOp(0) <= beq or bne_int;
    IF_Flush <= (bne_int and not Zero) or (beq and Zero) or jump_int;
end architecture structural;

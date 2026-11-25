--------------------------------------------------------------------------------
-- Module      : TopLevel
-- Description : 5-stage pipelined MIPS-style RISC processor (IF, ID, EX, MEM, WB)
--               with 32-bit instruction format, 8-bit datapath, data forwarding,
--               load-use hazard detection/stalling, and branch/jump flushing.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

entity TopLevel is
    port (
        GClock, GReset : in  std_logic;
        ValueSelect    : in  std_logic_vector(2 downto 0);
        MuxOut         : out std_logic_vector(7 downto 0);  -- Debug multiplexer output
        InstructionOut : out std_logic_vector(31 downto 0); -- Current fetched instruction
        ALUOut_out     : out std_logic_vector(7 downto 0);
        ReadData1_out  : out std_logic_vector(7 downto 0);
        ReadData2_out  : out std_logic_vector(7 downto 0);
        WriteData_out  : out std_logic_vector(7 downto 0);

        -- External Data Memory Interface
        DataAddress     : out std_logic_vector(7 downto 0);
        DataMemIn       : out std_logic_vector(7 downto 0);
        WriteDataEnable : out std_logic;
        ReadDataMem     : in  std_logic_vector(7 downto 0);

        -- External Instruction Memory Interface
        InstructionAddress : out std_logic_vector(7 downto 0);
        InstructionIn      : in  std_logic_vector(31 downto 0)
    );
end entity TopLevel;

architecture structural of TopLevel is

    -- Active-low reset for enARdFF_2 flip-flops
    signal notGReset : std_logic;

    -- Control Unit signals
    signal OPCODE : std_logic_vector(5 downto 0);
    signal RegDst, Branch, Bne, MemRead, MemToReg, MemWrite, ALUSrc, RegWrite, Jump : std_logic;
    signal ALUOp  : std_logic_vector(1 downto 0);

    -- Branch / Jump / ALU signals
    signal B_Extend, B_Shift : std_logic_vector(31 downto 0);
    signal ALUControl        : std_logic_vector(2 downto 0);
    signal ALUOut            : std_logic_vector(7 downto 0);

    -- Register File & Data Memory signals
    signal Instruction                      : std_logic_vector(31 downto 0);
    signal ReadReg1, ReadReg2, WriteReg     : std_logic_vector(4 downto 0);
    signal ReadData1, ReadData2, WriteData  : std_logic_vector(7 downto 0);
    signal DataMemOut                       : std_logic_vector(7 downto 0);
    signal RR1equalRR2                      : std_logic;

    -- Forwarding Unit signals
    signal ForwardA, ForwardB     : std_logic_vector(1 downto 0);
    signal EX_MuxOut1, EX_MuxOut2 : std_logic_vector(7 downto 0);

    -- PC & Branch/Jump path signals
    signal PCIncrementOut, PCOut, PCMux_in, PCIn, JumpAddress : std_logic_vector(31 downto 0);

    -- Hazard Detection & Control Hazard signals
    signal PCWrite, IF_Flush, IF_ID_Write, ControlMux : std_logic;

    -- IF/ID Pipeline Register Outputs
    signal ID_Instruction, ID_PCIncrementOut : std_logic_vector(31 downto 0);

    -- ID/EX Pipeline Register Outputs
    signal EX_MemtoReg, EX_MemRead, EX_MemWrite, EX_RegWrite, EX_RegDst, EX_ALUSrc : std_logic;
    signal EX_ALUOp       : std_logic_vector(1 downto 0);
    signal EX_Instruction : std_logic_vector(31 downto 0);
    signal EX_ReadData1   : std_logic_vector(7 downto 0);
    signal EX_ReadData2   : std_logic_vector(7 downto 0);
    signal EX_WriteReg    : std_logic_vector(4 downto 0);

    -- EX/MEM Pipeline Register Outputs
    signal MEM_WriteReg : std_logic_vector(4 downto 0);
    signal MEM_ALUOut   : std_logic_vector(7 downto 0);
    signal MEM_MuxOut2  : std_logic_vector(7 downto 0);
    signal MEM_MemtoReg, MEM_MemRead, MEM_MemWrite, MEM_RegWrite : std_logic;

    -- MEM/WB Pipeline Register Outputs
    signal WB_ALUOut, WB_DataMemOut : std_logic_vector(7 downto 0);
    signal WB_WriteReg              : std_logic_vector(4 downto 0);
    signal WB_MemtoReg, WB_RegWrite : std_logic;

begin

    notGReset <= not GReset;

    ----------------------------------------------------------------------------
    -- Stage 1: Instruction Fetch (IF)
    ----------------------------------------------------------------------------
    PCMux : entity work.mux2to1_32bit(struct)
        port map (PCIncrementOut, PCMux_in, IF_Flush, PCIn);

    PC : entity work.register8Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => PCWrite,
            i_Value => PCIn(7 downto 0),
            o_Value => PCOut(7 downto 0)
        );

    PCIncrementer : entity work.ALU_32b_G1(struct)
        port map (PCOut, X"00000001", PCIncrementOut);

    InstructionAddress <= PCOut(7 downto 0);
    Instruction        <= InstructionIn;

    ----------------------------------------------------------------------------
    -- IF/ID Pipeline Register
    ----------------------------------------------------------------------------
    IF_ID_InstructionCounter : entity work.register32Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset or IF_Flush,
            i_load  => IF_ID_Write,
            i_Value => PCIncrementOut,
            o_Value => ID_PCIncrementOut
        );

    IF_ID_32BitRegister : entity work.register32Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset or IF_Flush,
            i_load  => IF_ID_Write,
            i_Value => Instruction,
            o_Value => ID_Instruction
        );

    ----------------------------------------------------------------------------
    -- Stage 2: Instruction Decode (ID)
    ----------------------------------------------------------------------------
    JumpAddress(31 downto 26) <= ID_PCIncrementOut(31 downto 26);
    JumpAddress(25 downto 0)  <= ID_Instruction(25 downto 0);

    OPCODE   <= ID_Instruction(31 downto 26);
    ReadReg1 <= ID_Instruction(25 downto 21);
    ReadReg2 <= ID_Instruction(20 downto 16);

    B_Extend(15 downto 0)  <= ID_Instruction(15 downto 0);
    B_Extend(31 downto 16) <= (others => '0');
    B_Shift                <= B_Extend(31 downto 0);

    HazardUnit : entity work.HazardDetectionUnit(structural)
        port map (
            GClock           => GClock,
            ID_EX_MemRead    => EX_MemRead,
            ID_EX_RegisterRt => EX_Instruction(20 downto 16),
            IF_ID_RegisterRs => ReadReg1,
            IF_ID_RegisterRt => ReadReg2,
            PCWrite          => PCWrite,
            IF_ID_Write      => IF_ID_Write,
            ControlMux       => ControlMux
        );

    ControlUnit : entity work.CU(structural)
        port map (
            OPCODE   => OPCODE,
            ALUSrc   => ALUSrc,
            RegDst   => RegDst,
            Branch   => Branch,
            Bne      => Bne,
            MemRead  => MemRead,
            MemToReg => MemToReg,
            MemWrite => MemWrite,
            RegWrite => RegWrite,
            ALUOp    => ALUOp,
            Jump     => Jump,
            IF_Flush => IF_Flush,
            Zero     => RR1equalRR2,
            Hazard   => ControlMux
        );

    ALUAdder : entity work.ALU_32b_G1(struct)
        port map (ID_PCIncrementOut, B_Shift, PCMux_in);

    RegisterFile : entity work.registerFile(structural)
        port map (
            reset     => GReset,
            clk       => GClock,
            RegWrite  => WB_RegWrite,
            ReadReg1  => ReadReg1,
            ReadReg2  => ReadReg2,
            WriteReg  => WriteReg,
            WriteData => WriteData,
            ReadData1 => ReadData1,
            ReadData2 => ReadData2
        );

    RegisterFileComp : entity work.comparator5Bit(structural)
        port map (
            A       => ReadReg1,
            B       => ReadReg2,
            AequalB => RR1equalRR2
        );

    ----------------------------------------------------------------------------
    -- ID/EX Pipeline Register
    ----------------------------------------------------------------------------
    -- MEM control signals
    ID_EX_MemReadDFF  : entity work.enARdFF_2(rtl) port map (notGReset, MemRead,  '1', GClock, EX_MemRead,  open);
    ID_EX_MemWriteDFF : entity work.enARdFF_2(rtl) port map (notGReset, MemWrite, '1', GClock, EX_MemWrite, open);

    -- WB control signals
    ID_EX_RegWriteDFF : entity work.enARdFF_2(rtl) port map (notGReset, RegWrite, '1', GClock, EX_RegWrite, open);
    ID_EX_MemtoRegDFF : entity work.enARdFF_2(rtl) port map (notGReset, MemToReg, '1', GClock, EX_MemtoReg, open);

    -- EX control signals
    ID_EX_RegDstDFF : entity work.enARdFF_2(rtl) port map (notGReset, RegDst,   '1', GClock, EX_RegDst,   open);
    ID_EX_ALUSrcDFF : entity work.enARdFF_2(rtl) port map (notGReset, ALUSrc,   '1', GClock, EX_ALUSrc,   open);
    ID_EX_ALUOp1DFF : entity work.enARdFF_2(rtl) port map (notGReset, ALUOp(1), '1', GClock, EX_ALUOp(1), open);
    ID_EX_ALUOp2DFF : entity work.enARdFF_2(rtl) port map (notGReset, ALUOp(0), '1', GClock, EX_ALUOp(0), open);

    ID_EX_8BitRegister1 : entity work.register8Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => ReadData1,
            o_Value => EX_ReadData1
        );

    ID_EX_8BitRegister2 : entity work.register8Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => ReadData2,
            o_Value => EX_ReadData2
        );

    ID_EX_32BitRegister : entity work.register32Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => Instruction,
            o_Value => EX_Instruction
        );

    ----------------------------------------------------------------------------
    -- Stage 3: Execute (EX)
    ----------------------------------------------------------------------------
    EX_Mux4to1_8Bit1 : entity work.mux4to1_8Bit(structural)
        port map (ForwardA, EX_ReadData1, MEM_ALUOut, WriteData, X"00", EX_MuxOut1);

    EX_Mux4to1_8Bit2 : entity work.mux4to1_8Bit(structural)
        port map (ForwardB, EX_ReadData2, MEM_ALUOut, WriteData, X"00", EX_MuxOut2);

    ALUControlLogic : entity work.ALU_CU_G1(struct)
        port map (
            F      => EX_Instruction(5 downto 0),
            ALUOp  => EX_ALUOp,
            OPCODE => ALUControl
        );

    ALU : entity work.ALU(structural)
        port map (
            A         => EX_MuxOut1,
            B         => EX_MuxOut2,
            OPCODE    => ALUControl,
            ALUResult => ALUOut,
            Zero      => open
        );

    MUX1_5B : entity work.mux2to1_5bit(struct)
        port map (EX_Instruction(20 downto 16), EX_Instruction(15 downto 11), EX_RegDst, EX_WriteReg);

    ForwardingUnit : entity work.ForwardingUnit(structural)
        port map (
            ID_EX_RegisterRs  => EX_Instruction(25 downto 21),
            ID_EX_RegisterRt  => EX_Instruction(20 downto 16),
            EX_MEM_RegisterRd => MEM_WriteReg,
            MEM_WB_RegisterRd => WB_WriteReg,
            EX_MEM_RegWrite   => MEM_RegWrite,
            MEM_WB_RegWrite   => WB_RegWrite,
            ForwardA          => ForwardA,
            ForwardB          => ForwardB
        );

    ----------------------------------------------------------------------------
    -- EX/MEM Pipeline Register
    ----------------------------------------------------------------------------
    -- MEM control signals
    EX_MEM_MemReadDFF  : entity work.enARdFF_2(rtl) port map (notGReset, EX_MemRead,  '1', GClock, MEM_MemRead,  open);
    EX_MEM_MemWriteDFF : entity work.enARdFF_2(rtl) port map (notGReset, EX_MemWrite, '1', GClock, MEM_MemWrite, open);

    -- WB control signals
    EX_MEM_MemtoRegDFF : entity work.enARdFF_2(rtl) port map (notGReset, EX_MemtoReg, '1', GClock, MEM_MemtoReg, open);
    EX_MEM_RegWriteDFF : entity work.enARdFF_2(rtl) port map (notGReset, EX_RegWrite, '1', GClock, MEM_RegWrite, open);

    EX_MEM_WriteReg5Bit : entity work.register5Bit(Structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => EX_WriteReg,
            o_Value => MEM_WriteReg
        );

    EX_MEM_ALUOut8Bit : entity work.register8Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => ALUOut,
            o_Value => MEM_ALUOut
        );

    EX_MEM_MuxOut2_8Bit : entity work.register8Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => EX_MuxOut2,
            o_Value => MEM_MuxOut2
        );

    ----------------------------------------------------------------------------
    -- Stage 4: Memory Access (MEM)
    ----------------------------------------------------------------------------
    DataAddress     <= MEM_ALUOut;
    DataMemIn       <= MEM_MuxOut2;
    WriteDataEnable <= MEM_MemWrite;
    DataMemOut      <= ReadDataMem;

    ----------------------------------------------------------------------------
    -- MEM/WB Pipeline Register
    ----------------------------------------------------------------------------
    MEM_WB_MemtoRegDFF : entity work.enARdFF_2(rtl) port map (notGReset, MEM_MemtoReg, '1', GClock, WB_MemtoReg, open);
    MEM_WB_RegWriteDFF : entity work.enARdFF_2(rtl) port map (notGReset, MEM_RegWrite, '1', GClock, WB_RegWrite, open);

    MEM_WB_WriteReg5Bit : entity work.register5Bit(Structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => MEM_WriteReg,
            o_Value => WB_WriteReg
        );

    MEM_WB_ALUOut8Bit : entity work.register8Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => MEM_ALUOut,
            o_Value => WB_ALUOut
        );

    MEM_WB_DataMemOut8Bit : entity work.register8Bit(structural)
        port map (
            i_clock => GClock,
            i_reset => GReset,
            i_load  => '1',
            i_Value => DataMemOut,
            o_Value => WB_DataMemOut
        );

    ----------------------------------------------------------------------------
    -- Stage 5: Write Back (WB)
    ----------------------------------------------------------------------------
    MUX2_8B : entity work.mux2to1_8bit(structural)
        port map (WB_ALUOut, WB_DataMemOut, WB_MemtoReg, WriteData);

    WriteReg <= WB_WriteReg;

    ----------------------------------------------------------------------------
    -- Debug & Board Display Outputs
    ----------------------------------------------------------------------------
    DebugMUX : entity work.mux8to1_8Bit(structural)
        port map (
            sel    => ValueSelect,
            input0 => PCOut(7 downto 0),
            input1 => ALUOut,
            input2 => ReadData1,
            input3 => ReadData2,
            input4 => WriteData,
            input5 => '0' & RegDst & Jump & MemRead & MemToReg & ALUOp & ALUSrc,
            input6 => X"FF",
            input7 => X"FF",
            output => MuxOut
        );

    InstructionOut <= Instruction;
    ALUOut_out     <= ALUOut;
    ReadData1_out  <= ReadData1;
    ReadData2_out  <= ReadData2;
    WriteData_out  <= WriteData;

end architecture structural;

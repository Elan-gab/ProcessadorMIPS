library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Datapath is
    port (
        Clk     : in std_logic;
        Rst     : in std_logic;

        -- =========================================================================
        -- ENTRADAS DE CONTROLE (Vindas da Control Unit)
        -- =========================================================================
        RegWrite      : in std_logic;
        FP_RegWrite   : in std_logic;
        RegDst        : in std_logic;
        Branch        : in std_logic;
        Branch_Cond   : in std_logic; -- '0' para BEQ, '1' para BNE
        Jump          : in std_logic;
        MemWrite      : in std_logic;
        MemRead       : in std_logic;
        ALUSrc        : in std_logic;
        ALU_Sel       : in std_logic_vector(3 downto 0);
        FP_Op_Sel     : in std_logic;
        WriteBack_Sel : in std_logic_vector(1 downto 0);

        -- =========================================================================
        -- SAÍDAS PARA A CONTROL UNIT (Para ela saber qual instrução é)
        -- =========================================================================
        Opcode_out : out std_logic_vector(5 downto 0);
        Funct_out  : out std_logic_vector(5 downto 0);
        
        -- Saída de Debug (Opcional, útil para ver o resultado no Waveform)
        ALU_Result_Debug : out std_logic_vector(31 downto 0)
    );
end entity Datapath;

architecture Structural of Datapath is

    -- Declaração dos Componentes Internos (PC, Memórias, ALUs, RegFiles)
    -- NOTA: Assumo que as 'entities' (Program_Counter, Integer_ALU, etc.) 
    -- já estão compiladas no seu projeto.
    
    component Program_Counter is
        port (
            Clk, Rst : in std_logic;
            Branch_Addr : in std_logic_vector(31 downto 0);
            PC_Sel : in std_logic;
            PC_Out : out std_logic_vector(31 downto 0)
        );
    end component;

    component Instruction_Memory is
        port (
            Address : in std_logic_vector(31 downto 0);
            Instruction : out std_logic_vector(31 downto 0)
        );
    end component;

    component register_file is
        port (
            Clock, RegWrite : in std_logic;
            ReadReg1, ReadReg2, WriteReg : in std_logic_vector(4 downto 0);
            WriteData : in std_logic_vector(31 downto 0);
            ReadData1, ReadData2 : out std_logic_vector(31 downto 0)
        );
    end component;

    component FP_Register_File is
        port (
            Clk, Rst, Write_Enable : in std_logic;
            Read_Addr_1, Read_Addr_2, Write_Addr : in std_logic_vector(4 downto 0);
            Data_In : in std_logic_vector(31 downto 0);
            Data_Out_1, Data_Out_2 : out std_logic_vector(31 downto 0)
        );
    end component;

    component Integer_ALU is
        port (
            A, B : in std_logic_vector(31 downto 0);
            ALU_Sel : in std_logic_vector(3 downto 0);
            R : out std_logic_vector(31 downto 0);
            Zero : out std_logic
        );
    end component;

    component Data_Memory is
        port (
            Clk, MemWrite, MemRead : in std_logic;
            Address, DataIn : in std_logic_vector(31 downto 0);
            DataOut : out std_logic_vector(31 downto 0)
        );
    end component;

    component FP_ALU_Wrapper is
        port (
            X_in, Y_in : in std_logic_vector(31 downto 0);
            Op_sel : in std_logic;
            R_out : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Sinais Internos
    signal s_PC_Addr, s_PC_Plus_4, s_Instruction : std_logic_vector(31 downto 0);
    signal s_Extended_Immediate, s_LUI_Data : std_logic_vector(31 downto 0);
    signal s_Branch_Target_Addr, s_Jump_Target_Addr, s_Next_PC_Addr_Mux : std_logic_vector(31 downto 0);
    signal s_PC_Load_Enable, s_Branch_Decision : std_logic;
    
    signal s_Int_Read_Data_1, s_Int_Read_Data_2 : std_logic_vector(31 downto 0);
    signal s_FP_Read_Data_1, s_FP_Read_Data_2 : std_logic_vector(31 downto 0);
    signal s_Int_Write_Addr, s_FP_Write_Addr : std_logic_vector(4 downto 0);
    signal s_Write_Back_Data : std_logic_vector(31 downto 0);
    
    signal s_ALU_Input_B, s_Int_ALU_Result, s_FP_ALU_Result : std_logic_vector(31 downto 0);
    signal s_Int_ALU_Zero : std_logic;
    signal s_Memory_Read_Data : std_logic_vector(31 downto 0);

begin

    -- Roteamento para saídas do Datapath
    Opcode_out <= s_Instruction(31 downto 26);
    Funct_out  <= s_Instruction(5 downto 0);
    ALU_Result_Debug <= s_Int_ALU_Result; -- Apenas para debug

    -- =========================================================================
    -- LÓGICA DE DATAPATH (Extensores, MUXes e Aritmética de Endereço)
    -- =========================================================================

    s_Extended_Immediate <= std_logic_vector(resize(signed(s_Instruction(15 downto 0)), 32));
    s_LUI_Data <= s_Instruction(15 downto 0) & x"0000";

    -- Mux RegDst
    s_Int_Write_Addr <= s_Instruction(20 downto 16) when RegDst = '0' else s_Instruction(15 downto 11);
    s_FP_Write_Addr  <= s_Instruction(20 downto 16) when RegDst = '0' else s_Instruction(15 downto 11);

    -- Mux ALUSrc
    s_ALU_Input_B <= s_Int_Read_Data_2 when ALUSrc = '0' else s_Extended_Immediate;

    -- Mux WriteBack
    with WriteBack_Sel select
        s_Write_Back_Data <= s_Int_ALU_Result    when "00",
                             s_Memory_Read_Data  when "01",
                             s_FP_ALU_Result     when "10",
                             s_LUI_Data          when "11",
                             (others => 'X')     when others;

    -- Lógica de Branch/Jump
    s_PC_Plus_4 <= std_logic_vector(signed(s_PC_Addr) + 4);
    s_Branch_Target_Addr <= std_logic_vector(signed(s_PC_Plus_4) + signed(s_Extended_Immediate(29 downto 0) & "00"));
    s_Jump_Target_Addr <= s_PC_Plus_4(31 downto 28) & s_Instruction(25 downto 0) & "00";
    
    s_Next_PC_Addr_Mux <= s_Jump_Target_Addr when Jump = '1' else s_Branch_Target_Addr;
    s_Branch_Decision <= (s_Int_ALU_Zero and (not Branch_Cond)) or ((not s_Int_ALU_Zero) and Branch_Cond);
    s_PC_Load_Enable <= (Branch and s_Branch_Decision) or Jump;

    -- =========================================================================
    -- INSTANCIAÇÃO DOS COMPONENTES
    -- =========================================================================

    u_PC: Program_Counter port map (
        Clk => Clk, Rst => Rst, Branch_Addr => s_Next_PC_Addr_Mux, PC_Sel => s_PC_Load_Enable, PC_Out => s_PC_Addr
    );

    u_IMem: Instruction_Memory port map (
        Address => s_PC_Addr, Instruction => s_Instruction
    );

    u_Int_Reg_File: register_file port map (
        Clock => Clk, RegWrite => RegWrite,
        ReadReg1 => s_Instruction(25 downto 21), ReadReg2 => s_Instruction(20 downto 16),
        WriteReg => s_Int_Write_Addr, WriteData => s_Write_Back_Data,
        ReadData1 => s_Int_Read_Data_1, ReadData2 => s_Int_Read_Data_2
    );

    u_FP_Reg_File: FP_Register_File port map (
        Clk => Clk, Rst => Rst, Write_Enable => FP_RegWrite,
        Read_Addr_1 => s_Instruction(25 downto 21), Read_Addr_2 => s_Instruction(20 downto 16),
        Write_Addr => s_FP_Write_Addr, Data_In => s_Write_Back_Data,
        Data_Out_1 => s_FP_Read_Data_1, Data_Out_2 => s_FP_Read_Data_2
    );

    u_Int_ALU: Integer_ALU port map (
        A => s_Int_Read_Data_1, B => s_ALU_Input_B, ALU_Sel => ALU_Sel,
        R => s_Int_ALU_Result, Zero => s_Int_ALU_Zero
    );

    u_FP_ALU: FP_ALU_Wrapper port map (
        X_in => s_FP_Read_Data_1, Y_in => s_FP_Read_Data_2, Op_sel => FP_Op_Sel, R_out => s_FP_ALU_Result
    );

    u_DMem: Data_Memory port map (
        Clk => Clk, MemWrite => MemWrite, MemRead => MemRead,
        Address => s_Int_ALU_Result, DataIn => s_Int_Read_Data_2, DataOut => s_Memory_Read_Data
    );

end architecture Structural;
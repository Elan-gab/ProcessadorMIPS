library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Datapath is
    port (
        Clk     : in std_logic;
        Rst     : in std_logic;

        -- =========================================================================
        -- ENTRADAS DE CONTROLE (Vindas da Control Unit - Estágio ID)
        -- =========================================================================
        RegWrite      : in std_logic;
        FP_RegWrite   : in std_logic;
        RegDst        : in std_logic;
        Branch        : in std_logic;
        Branch_Cond   : in std_logic; 
        Jump          : in std_logic;
        MemWrite      : in std_logic;
        MemRead       : in std_logic;
        ALUSrc        : in std_logic;
        ALU_Sel       : in std_logic_vector(3 downto 0);
        FP_Op_Sel     : in std_logic;
        WriteBack_Sel : in std_logic_vector(1 downto 0);

        -- =========================================================================
        -- SAÍDAS PARA A CONTROL UNIT (Opcode vai para o ID)
        -- =========================================================================
        Opcode_out : out std_logic_vector(5 downto 0);
        Funct_out  : out std_logic_vector(5 downto 0);
        
        -- Saída de Debug
        ALU_Result_Debug : out std_logic_vector(31 downto 0)
    );
end entity Datapath;

architecture Structural of Datapath is

    -- =========================================================================
    -- DECLARAÇÃO DOS COMPONENTES BÁSICOS
    -- =========================================================================
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

    -- =========================================================================
    -- DECLARAÇÃO DOS REGISTRADORES DE PIPELINE
    -- =========================================================================
    component Reg_IF_ID is
        port (
            Clk, Rst, Stall, Flush : in std_logic;
            PC_Plus_4_in, Instruction_in : in std_logic_vector(31 downto 0);
            PC_Plus_4_out, Instruction_out : out std_logic_vector(31 downto 0)
        );
    end component;

    component Reg_ID_EX is
        port (
            Clk, Rst, Flush : in std_logic;
            RegWrite_in, FP_RegWrite_in, MemWrite_in, MemRead_in, ALUSrc_in, FP_Op_Sel_in, RegDst_in : in std_logic;
            WriteBack_Sel_in : in std_logic_vector(1 downto 0);
            ALU_Sel_in : in std_logic_vector(3 downto 0);
            PC_Plus_4_in, ReadData1_Int_in, ReadData2_Int_in, ReadData1_FP_in, ReadData2_FP_in, Immediate_in : in std_logic_vector(31 downto 0);
            Rs_Addr_in, Rt_Addr_in, Rd_Addr_in : in std_logic_vector(4 downto 0);
            
            RegWrite_out, FP_RegWrite_out, MemWrite_out, MemRead_out, ALUSrc_out, FP_Op_Sel_out, RegDst_out : out std_logic;
            WriteBack_Sel_out : out std_logic_vector(1 downto 0);
            ALU_Sel_out : out std_logic_vector(3 downto 0);
            PC_Plus_4_out, ReadData1_Int_out, ReadData2_Int_out, ReadData1_FP_out, ReadData2_FP_out, Immediate_out : out std_logic_vector(31 downto 0);
            Rs_Addr_out, Rt_Addr_out, Rd_Addr_out : out std_logic_vector(4 downto 0)
        );
    end component;

    component Reg_EX_MEM is
        port (
            Clk, Rst : in std_logic;
            RegWrite_in, FP_RegWrite_in, MemWrite_in, MemRead_in : in std_logic;
            WriteBack_Sel_in : in std_logic_vector(1 downto 0);
            ALU_Result_Int_in, ALU_Result_FP_in, WriteData_Mem_in : in std_logic_vector(31 downto 0);
            WriteReg_Addr_in : in std_logic_vector(4 downto 0);
            
            RegWrite_out, FP_RegWrite_out, MemWrite_out, MemRead_out : out std_logic;
            WriteBack_Sel_out : out std_logic_vector(1 downto 0);
            ALU_Result_Int_out, ALU_Result_FP_out, WriteData_Mem_out : out std_logic_vector(31 downto 0);
            WriteReg_Addr_out : out std_logic_vector(4 downto 0)
        );
    end component;

    component Reg_MEM_WB is
        port (
            Clk, Rst : in std_logic;
            RegWrite_in, FP_RegWrite_in : in std_logic;
            WriteBack_Sel_in : in std_logic_vector(1 downto 0);
            ReadData_Mem_in, ALU_Result_Int_in, ALU_Result_FP_in : in std_logic_vector(31 downto 0);
            WriteReg_Addr_in : in std_logic_vector(4 downto 0);
            
            RegWrite_out, FP_RegWrite_out : out std_logic;
            WriteBack_Sel_out : out std_logic_vector(1 downto 0);
            ReadData_Mem_out, ALU_Result_Int_out, ALU_Result_FP_out : out std_logic_vector(31 downto 0);
            WriteReg_Addr_out : out std_logic_vector(4 downto 0)
        );
    end component;

    -- =========================================================================
    -- SINAIS DO SISTEMA (Pipeline Stage Signals)
    -- =========================================================================
    
    -- Sinais de Controle de Hazard (Futuros)
    signal s_Stall, s_Flush : std_logic := '0'; 

    -- === Estágio IF (Instruction Fetch) ===
    signal s_PC_IF, s_PC_Plus_4_IF, s_Instruction_IF : std_logic_vector(31 downto 0);
    signal s_Next_PC, s_Branch_Target, s_Jump_Target : std_logic_vector(31 downto 0);
    signal s_PC_Src : std_logic; 

    -- === Estágio ID (Instruction Decode) ===
    signal s_PC_Plus_4_ID, s_Instruction_ID : std_logic_vector(31 downto 0);
    signal s_Ext_Imm_ID : std_logic_vector(31 downto 0);
    signal s_RD1_Int_ID, s_RD2_Int_ID : std_logic_vector(31 downto 0);
    signal s_RD1_FP_ID, s_RD2_FP_ID   : std_logic_vector(31 downto 0);
    
    -- Lógica de Branch no ID
    signal s_Branch_Taken_ID : std_logic;
    signal s_Comp_Equal_ID : std_logic; -- Comparador simples para BEQ

    -- === Estágio EX (Execute) ===
    -- Sinais de Controle EX
    signal s_RegWrite_EX, s_FP_RegWrite_EX, s_MemWrite_EX, s_MemRead_EX, s_ALUSrc_EX, s_FP_Op_Sel_EX, s_RegDst_EX : std_logic;
    signal s_WriteBack_Sel_EX : std_logic_vector(1 downto 0);
    signal s_ALU_Sel_EX : std_logic_vector(3 downto 0);
    -- Dados EX
    signal s_PC_Plus_4_EX, s_RD1_Int_EX, s_RD2_Int_EX, s_RD1_FP_EX, s_RD2_FP_EX, s_Ext_Imm_EX : std_logic_vector(31 downto 0);
    signal s_Rs_EX, s_Rt_EX, s_Rd_EX : std_logic_vector(4 downto 0);
    signal s_ALU_In_B_Int : std_logic_vector(31 downto 0);
    signal s_ALU_Res_Int_EX, s_ALU_Res_FP_EX : std_logic_vector(31 downto 0);
    signal s_WriteReg_Addr_EX : std_logic_vector(4 downto 0);
    signal s_LUI_Data_EX : std_logic_vector(31 downto 0);

    -- === Estágio MEM (Memory) ===
    -- Sinais de Controle MEM
    signal s_RegWrite_MEM, s_FP_RegWrite_MEM, s_MemWrite_MEM, s_MemRead_MEM : std_logic;
    signal s_WriteBack_Sel_MEM : std_logic_vector(1 downto 0);
    -- Dados MEM
    signal s_ALU_Res_Int_MEM, s_ALU_Res_FP_MEM, s_WriteData_Mem_MEM : std_logic_vector(31 downto 0);
    signal s_WriteReg_Addr_MEM : std_logic_vector(4 downto 0);
    signal s_ReadData_Mem_Out : std_logic_vector(31 downto 0);

    -- === Estágio WB (Write Back) ===
    -- Sinais de Controle WB
    signal s_RegWrite_WB, s_FP_RegWrite_WB : std_logic;
    signal s_WriteBack_Sel_WB : std_logic_vector(1 downto 0);
    -- Dados WB
    signal s_ReadData_Mem_WB, s_ALU_Res_Int_WB, s_ALU_Res_FP_WB : std_logic_vector(31 downto 0);
    signal s_WriteReg_Addr_WB : std_logic_vector(4 downto 0);
    signal s_Final_Write_Data_WB : std_logic_vector(31 downto 0);
    signal s_LUI_Data_WB : std_logic_vector(31 downto 0); -- Simplificação: LUI gerado antes

begin

    -- =========================================================================
    -- ESTÁGIO 1: IF (INSTRUCTION FETCH)
    -- =========================================================================
    
    u_PC: Program_Counter port map (
        Clk => Clk, Rst => Rst, 
        Branch_Addr => s_Next_PC, 
        PC_Sel => '1', -- PC sempre atualiza (Stall será logicado dentro do PC ou via Enable aqui futuramente)
        PC_Out => s_PC_IF
    );

    s_PC_Plus_4_IF <= std_logic_vector(unsigned(s_PC_IF) + 4);

    u_IMem: Instruction_Memory port map (
        Address => s_PC_IF, Instruction => s_Instruction_IF
    );

    -- Mux do Próximo PC (Resolvido no estágio ID para simplicidade)
    s_Jump_Target <= s_PC_Plus_4_ID(31 downto 28) & s_Instruction_ID(25 downto 0) & "00";
    s_Branch_Target <= std_logic_vector(unsigned(s_PC_Plus_4_ID) + unsigned(s_Ext_Imm_ID(29 downto 0) & "00"));
    
    -- Lógica Combinacional do PC (Prioridade: Reset > Jump > Branch > PC+4)
    process(s_Jump_Target, s_Branch_Target, s_PC_Plus_4_IF, Jump, s_Branch_Taken_ID)
    begin
        if Jump = '1' then
            s_Next_PC <= s_Jump_Target;
        elsif s_Branch_Taken_ID = '1' then
            s_Next_PC <= s_Branch_Target;
        else
            s_Next_PC <= s_PC_Plus_4_IF;
        end if;
    end process;

    -- REGISTRADOR IF/ID
    u_Reg_IF_ID: Reg_IF_ID port map (
        Clk => Clk, Rst => Rst, Stall => s_Stall, Flush => s_Flush,
        PC_Plus_4_in => s_PC_Plus_4_IF, Instruction_in => s_Instruction_IF,
        PC_Plus_4_out => s_PC_Plus_4_ID, Instruction_out => s_Instruction_ID
    );

    -- =========================================================================
    -- ESTÁGIO 2: ID (DECODE)
    -- =========================================================================
    
    -- Saídas para Control Unit (Topo)
    Opcode_out <= s_Instruction_ID(31 downto 26);
    Funct_out  <= s_Instruction_ID(5 downto 0);

    -- Extensão de Sinal
    s_Ext_Imm_ID <= std_logic_vector(resize(signed(s_Instruction_ID(15 downto 0)), 32));

    -- Banco de Registradores INTEIRO (Leitura em ID, Escrita vem de WB)
    u_Int_Reg_File: register_file port map (
        Clock => Clk, RegWrite => s_RegWrite_WB, -- Loopback do WB
        ReadReg1 => s_Instruction_ID(25 downto 21), 
        ReadReg2 => s_Instruction_ID(20 downto 16),
        WriteReg => s_WriteReg_Addr_WB,          -- Loopback do WB
        WriteData => s_Final_Write_Data_WB,      -- Loopback do WB
        ReadData1 => s_RD1_Int_ID, ReadData2 => s_RD2_Int_ID
    );

    -- Banco de Registradores FLOAT (Leitura em ID, Escrita vem de WB)
    u_FP_Reg_File: FP_Register_File port map (
        Clk => Clk, Rst => Rst, Write_Enable => s_FP_RegWrite_WB, -- Loopback
        Read_Addr_1 => s_Instruction_ID(25 downto 21), 
        Read_Addr_2 => s_Instruction_ID(20 downto 16),
        Write_Addr => s_WriteReg_Addr_WB,          -- Loopback
        Data_In => s_Final_Write_Data_WB,          -- Loopback
        Data_Out_1 => s_RD1_FP_ID, Data_Out_2 => s_RD2_FP_ID
    );

    -- Lógica de Branch no ID (Comparador Simples)
    s_Comp_Equal_ID <= '1' when (s_RD1_Int_ID = s_RD2_Int_ID) else '0';
    s_Branch_Taken_ID <= (Branch and not Branch_Cond and s_Comp_Equal_ID) or -- BEQ
                         (Branch and Branch_Cond and not s_Comp_Equal_ID);   -- BNE

    -- REGISTRADOR ID/EX
    u_Reg_ID_EX: Reg_ID_EX port map (
        Clk => Clk, Rst => Rst, Flush => s_Flush,
        -- Controle Entrada
        RegWrite_in => RegWrite, FP_RegWrite_in => FP_RegWrite, MemWrite_in => MemWrite, 
        MemRead_in => MemRead, ALUSrc_in => ALUSrc, FP_Op_Sel_in => FP_Op_Sel, RegDst_in => RegDst,
        WriteBack_Sel_in => WriteBack_Sel, ALU_Sel_in => ALU_Sel,
        -- Dados Entrada
        PC_Plus_4_in => s_PC_Plus_4_ID, 
        ReadData1_Int_in => s_RD1_Int_ID, ReadData2_Int_in => s_RD2_Int_ID,
        ReadData1_FP_in => s_RD1_FP_ID, ReadData2_FP_in => s_RD2_FP_ID,
        Immediate_in => s_Ext_Imm_ID,
        Rs_Addr_in => s_Instruction_ID(25 downto 21), 
        Rt_Addr_in => s_Instruction_ID(20 downto 16), 
        Rd_Addr_in => s_Instruction_ID(15 downto 11),
        
        -- Controle Saída (Indo para EX)
        RegWrite_out => s_RegWrite_EX, FP_RegWrite_out => s_FP_RegWrite_EX, MemWrite_out => s_MemWrite_EX,
        MemRead_out => s_MemRead_EX, ALUSrc_out => s_ALUSrc_EX, FP_Op_Sel_out => s_FP_Op_Sel_EX, RegDst_out => s_RegDst_EX,
        WriteBack_Sel_out => s_WriteBack_Sel_EX, ALU_Sel_out => s_ALU_Sel_EX,
        -- Dados Saída
        PC_Plus_4_out => s_PC_Plus_4_EX,
        ReadData1_Int_out => s_RD1_Int_EX, ReadData2_Int_out => s_RD2_Int_EX,
        ReadData1_FP_out => s_RD1_FP_EX, ReadData2_FP_out => s_RD2_FP_EX,
        Immediate_out => s_Ext_Imm_EX,
        Rs_Addr_out => s_Rs_EX, Rt_Addr_out => s_Rt_EX, Rd_Addr_out => s_Rd_EX
    );

    -- =========================================================================
    -- ESTÁGIO 3: EX (EXECUTE)
    -- =========================================================================
    
    -- Mux ALUSrc (Inteiro)
    s_ALU_In_B_Int <= s_RD2_Int_EX when s_ALUSrc_EX = '0' else s_Ext_Imm_EX;

    -- ULA Inteira
    u_Int_ALU: Integer_ALU port map (
        A => s_RD1_Int_EX, B => s_ALU_In_B_Int, ALU_Sel => s_ALU_Sel_EX,
        R => s_ALU_Res_Int_EX, Zero => open -- Zero usado no ID
    );
    ALU_Result_Debug <= s_ALU_Res_Int_EX;

    -- ULA Ponto Flutuante
    u_FP_ALU: FP_ALU_Wrapper port map (
        X_in => s_RD1_FP_EX, Y_in => s_RD2_FP_EX, Op_sel => s_FP_Op_Sel_EX, R_out => s_ALU_Res_FP_EX
    );

    -- Mux RegDst (Define em qual registrador salvar: rt ou rd)
    s_WriteReg_Addr_EX <= s_Rt_EX when s_RegDst_EX = '0' else s_Rd_EX;

    -- REGISTRADOR EX/MEM
    u_Reg_EX_MEM: Reg_EX_MEM port map (
        Clk => Clk, Rst => Rst,
        RegWrite_in => s_RegWrite_EX, FP_RegWrite_in => s_FP_RegWrite_EX, 
        MemWrite_in => s_MemWrite_EX, MemRead_in => s_MemRead_EX,
        WriteBack_Sel_in => s_WriteBack_Sel_EX,
        ALU_Result_Int_in => s_ALU_Res_Int_EX, ALU_Result_FP_in => s_ALU_Res_FP_EX,
        WriteData_Mem_in => s_RD2_Int_EX, -- Dado para Store Word
        WriteReg_Addr_in => s_WriteReg_Addr_EX,

        RegWrite_out => s_RegWrite_MEM, FP_RegWrite_out => s_FP_RegWrite_MEM, 
        MemWrite_out => s_MemWrite_MEM, MemRead_out => s_MemRead_MEM,
        WriteBack_Sel_out => s_WriteBack_Sel_MEM,
        ALU_Result_Int_out => s_ALU_Res_Int_MEM, ALU_Result_FP_out => s_ALU_Res_FP_MEM,
        WriteData_Mem_out => s_WriteData_Mem_MEM,
        WriteReg_Addr_out => s_WriteReg_Addr_MEM
    );

    -- =========================================================================
    -- ESTÁGIO 4: MEM (MEMORY ACCESS)
    -- =========================================================================

    u_DMem: Data_Memory port map (
        Clk => Clk, MemWrite => s_MemWrite_MEM, MemRead => s_MemRead_MEM,
        Address => s_ALU_Res_Int_MEM, DataIn => s_WriteData_Mem_MEM,
        DataOut => s_ReadData_Mem_Out
    );

    -- REGISTRADOR MEM/WB
    u_Reg_MEM_WB: Reg_MEM_WB port map (
        Clk => Clk, Rst => Rst,
        RegWrite_in => s_RegWrite_MEM, FP_RegWrite_in => s_FP_RegWrite_MEM,
        WriteBack_Sel_in => s_WriteBack_Sel_MEM,
        ReadData_Mem_in => s_ReadData_Mem_Out,
        ALU_Result_Int_in => s_ALU_Res_Int_MEM, ALU_Result_FP_in => s_ALU_Res_FP_MEM,
        WriteReg_Addr_in => s_WriteReg_Addr_MEM,

        RegWrite_out => s_RegWrite_WB, FP_RegWrite_out => s_FP_RegWrite_WB,
        WriteBack_Sel_out => s_WriteBack_Sel_WB,
        ReadData_Mem_out => s_ReadData_Mem_WB,
        ALU_Result_Int_out => s_ALU_Res_Int_WB, ALU_Result_FP_out => s_ALU_Res_FP_WB,
        WriteReg_Addr_out => s_WriteReg_Addr_WB
    );

    -- =========================================================================
    -- ESTÁGIO 5: WB (WRITE BACK)
    -- =========================================================================
    
    -- Simplificação do LUI (geralmente tratado com Shift na ALU, mas aqui via Mux)
    s_LUI_Data_WB <= s_ALU_Res_Int_WB(15 downto 0) & x"0000"; -- Apenas ilustrativo, o dado LUI idealmente viaja pelo pipeline

    with s_WriteBack_Sel_WB select
        s_Final_Write_Data_WB <= s_ALU_Res_Int_WB    when "00",
                                 s_ReadData_Mem_WB   when "01",
                                 s_ALU_Res_FP_WB     when "10",
                                 s_LUI_Data_WB       when "11",
                                 (others => '0')     when others;

end architecture Structural;
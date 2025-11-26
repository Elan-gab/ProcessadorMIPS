library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =========================================================================
-- ARQUIVO: Pipeline_Registers.vhd
-- DESCRIÇÃO: Contém os 4 registradores de barreira para o Pipeline MIPS
--            (IF/ID, ID/EX, EX/MEM, MEM/WB).
-- =========================================================================

-- #########################################################################
-- 1. REGISTRADOR IF/ID (Fetch -> Decode)
-- #########################################################################
entity Reg_IF_ID is
    port (
        Clk      : in  std_logic;
        Rst      : in  std_logic;
        Stall    : in  std_logic; -- 1 = Mantém o valor anterior (Congela)
        Flush    : in  std_logic; -- 1 = Zera o conteúdo (Insere NOP)
        
        -- Entradas (Vindas do IF)
        PC_Plus_4_in    : in  std_logic_vector(31 downto 0);
        Instruction_in  : in  std_logic_vector(31 downto 0);
        
        -- Saídas (Indo para o ID)
        PC_Plus_4_out   : out std_logic_vector(31 downto 0);
        Instruction_out : out std_logic_vector(31 downto 0)
    );
end entity Reg_IF_ID;

architecture Behavioral of Reg_IF_ID is
begin
    process(Clk, Rst)
    begin
        if Rst = '1' then
            PC_Plus_4_out   <= (others => '0');
            Instruction_out <= (others => '0');
        elsif rising_edge(Clk) then
            if Flush = '1' then
                -- Transforma em NOP (Instruction 0 é sll $0,$0,0 que é NOP)
                Instruction_out <= (others => '0');
                PC_Plus_4_out   <= (others => '0'); 
            elsif Stall = '0' then
                -- Operação normal: passa o dado adiante
                PC_Plus_4_out   <= PC_Plus_4_in;
                Instruction_out <= Instruction_in;
            end if;
            -- Se Stall = '1', não faz nada (mantém o valor antigo)
        end if;
    end process;
end architecture Behavioral;


-- #########################################################################
-- 2. REGISTRADOR ID/EX (Decode -> Execute)
-- #########################################################################
library ieee;
use ieee.std_logic_1164.all;

entity Reg_ID_EX is
    port (
        Clk      : in  std_logic;
        Rst      : in  std_logic;
        Flush    : in  std_logic; -- Usado para limpar se houver branch tomado

        -- === SINAIS DE CONTROLE ===
        -- WB (Write Back)
        RegWrite_in     : in std_logic;
        FP_RegWrite_in  : in std_logic;
        WriteBack_Sel_in: in std_logic_vector(1 downto 0);
        -- MEM (Memory)
        MemWrite_in     : in std_logic;
        MemRead_in      : in std_logic;
        -- EX (Execute)
        ALUSrc_in       : in std_logic;
        ALU_Sel_in      : in std_logic_vector(3 downto 0);
        FP_Op_Sel_in    : in std_logic;
        RegDst_in       : in std_logic;

        -- === DADOS ===
        PC_Plus_4_in    : in std_logic_vector(31 downto 0);
        
        -- Inteiros
        ReadData1_Int_in: in std_logic_vector(31 downto 0);
        ReadData2_Int_in: in std_logic_vector(31 downto 0);
        
        -- Float (Para FPU)
        ReadData1_FP_in : in std_logic_vector(31 downto 0);
        ReadData2_FP_in : in std_logic_vector(31 downto 0);
        
        -- Imediato Estendido
        Immediate_in    : in std_logic_vector(31 downto 0);
        
        -- Endereços de Registradores (Para Forwarding e WriteBack)
        Rs_Addr_in      : in std_logic_vector(4 downto 0);
        Rt_Addr_in      : in std_logic_vector(4 downto 0);
        Rd_Addr_in      : in std_logic_vector(4 downto 0);

        -- === SAÍDAS (Mesmos nomes com sufixo _out) ===
        RegWrite_out     : out std_logic;
        FP_RegWrite_out  : out std_logic;
        WriteBack_Sel_out: out std_logic_vector(1 downto 0);
        MemWrite_out     : out std_logic;
        MemRead_out      : out std_logic;
        ALUSrc_out       : out std_logic;
        ALU_Sel_out      : out std_logic_vector(3 downto 0);
        FP_Op_Sel_out    : out std_logic;
        RegDst_out       : out std_logic;

        PC_Plus_4_out    : out std_logic_vector(31 downto 0);
        ReadData1_Int_out: out std_logic_vector(31 downto 0);
        ReadData2_Int_out: out std_logic_vector(31 downto 0);
        ReadData1_FP_out : out std_logic_vector(31 downto 0);
        ReadData2_FP_out : out std_logic_vector(31 downto 0);
        Immediate_out    : out std_logic_vector(31 downto 0);
        Rs_Addr_out      : out std_logic_vector(4 downto 0);
        Rt_Addr_out      : out std_logic_vector(4 downto 0);
        Rd_Addr_out      : out std_logic_vector(4 downto 0)
    );
end entity Reg_ID_EX;

architecture Behavioral of Reg_ID_EX is
begin
    process(Clk, Rst)
    begin
        if Rst = '1' or Flush = '1' then
            -- Reseta controles críticos para evitar escritas indesejadas
            RegWrite_out     <= '0';
            FP_RegWrite_out  <= '0';
            MemWrite_out     <= '0';
            -- Demais saídas podem ir para 0 ou 'X'
            WriteBack_Sel_out<= (others => '0');
            MemRead_out      <= '0';
            ALUSrc_out       <= '0';
            ALU_Sel_out      <= (others => '0');
            FP_Op_Sel_out    <= '0';
            RegDst_out       <= '0';
            PC_Plus_4_out    <= (others => '0');
            ReadData1_Int_out<= (others => '0');
            ReadData2_Int_out<= (others => '0');
            ReadData1_FP_out <= (others => '0');
            ReadData2_FP_out <= (others => '0');
            Immediate_out    <= (others => '0');
            Rs_Addr_out      <= (others => '0');
            Rt_Addr_out      <= (others => '0');
            Rd_Addr_out      <= (others => '0');
        elsif rising_edge(Clk) then
            -- Passagem direta
            RegWrite_out     <= RegWrite_in;
            FP_RegWrite_out  <= FP_RegWrite_in;
            WriteBack_Sel_out<= WriteBack_Sel_in;
            MemWrite_out     <= MemWrite_in;
            MemRead_out      <= MemRead_in;
            ALUSrc_out       <= ALUSrc_in;
            ALU_Sel_out      <= ALU_Sel_in;
            FP_Op_Sel_out    <= FP_Op_Sel_in;
            RegDst_out       <= RegDst_in;
            
            PC_Plus_4_out    <= PC_Plus_4_in;
            ReadData1_Int_out<= ReadData1_Int_in;
            ReadData2_Int_out<= ReadData2_Int_in;
            ReadData1_FP_out <= ReadData1_FP_in;
            ReadData2_FP_out <= ReadData2_FP_in;
            Immediate_out    <= Immediate_in;
            Rs_Addr_out      <= Rs_Addr_in;
            Rt_Addr_out      <= Rt_Addr_in;
            Rd_Addr_out      <= Rd_Addr_in;
        end if;
    end process;
end architecture Behavioral;


-- #########################################################################
-- 3. REGISTRADOR EX/MEM (Execute -> Memory)
-- #########################################################################
library ieee;
use ieee.std_logic_1164.all;

entity Reg_EX_MEM is
    port (
        Clk      : in  std_logic;
        Rst      : in  std_logic;

        -- === CONTROLE ===
        RegWrite_in      : in std_logic;
        FP_RegWrite_in   : in std_logic;
        WriteBack_Sel_in : in std_logic_vector(1 downto 0);
        MemWrite_in      : in std_logic;
        MemRead_in       : in std_logic;

        -- === DADOS ===
        ALU_Result_Int_in: in std_logic_vector(31 downto 0); -- Endereço calculado ou resultado Int
        ALU_Result_FP_in : in std_logic_vector(31 downto 0); -- Resultado da FPU
        WriteData_Mem_in : in std_logic_vector(31 downto 0); -- Dado para salvar na memória (sw/swc1)
        
        -- ENDEREÇO DE DESTINO (Já calculado pelo Mux RegDst no estágio EX)
        WriteReg_Addr_in : in std_logic_vector(4 downto 0);

        -- === SAÍDAS ===
        RegWrite_out      : out std_logic;
        FP_RegWrite_out   : out std_logic;
        WriteBack_Sel_out : out std_logic_vector(1 downto 0);
        MemWrite_out      : out std_logic;
        MemRead_out       : out std_logic;

        ALU_Result_Int_out: out std_logic_vector(31 downto 0);
        ALU_Result_FP_out : out std_logic_vector(31 downto 0);
        WriteData_Mem_out : out std_logic_vector(31 downto 0);
        WriteReg_Addr_out : out std_logic_vector(4 downto 0)
    );
end entity Reg_EX_MEM;

architecture Behavioral of Reg_EX_MEM is
begin
    process(Clk, Rst)
    begin
        if Rst = '1' then
            RegWrite_out      <= '0';
            FP_RegWrite_out   <= '0';
            MemWrite_out      <= '0';
            MemRead_out       <= '0';
            WriteBack_Sel_out <= (others => '0');
            ALU_Result_Int_out<= (others => '0');
            ALU_Result_FP_out <= (others => '0');
            WriteData_Mem_out <= (others => '0');
            WriteReg_Addr_out <= (others => '0');
        elsif rising_edge(Clk) then
            RegWrite_out      <= RegWrite_in;
            FP_RegWrite_out   <= FP_RegWrite_in;
            WriteBack_Sel_out <= WriteBack_Sel_in;
            MemWrite_out      <= MemWrite_in;
            MemRead_out       <= MemRead_in;
            ALU_Result_Int_out<= ALU_Result_Int_in;
            ALU_Result_FP_out <= ALU_Result_FP_in;
            WriteData_Mem_out <= WriteData_Mem_in;
            WriteReg_Addr_out <= WriteReg_Addr_in;
        end if;
    end process;
end architecture Behavioral;


-- #########################################################################
-- 4. REGISTRADOR MEM/WB (Memory -> WriteBack)
-- #########################################################################
library ieee;
use ieee.std_logic_1164.all;

entity Reg_MEM_WB is
    port (
        Clk      : in  std_logic;
        Rst      : in  std_logic;

        -- === CONTROLE ===
        RegWrite_in      : in std_logic;
        FP_RegWrite_in   : in std_logic;
        WriteBack_Sel_in : in std_logic_vector(1 downto 0);

        -- === DADOS ===
        ReadData_Mem_in  : in std_logic_vector(31 downto 0); -- Dado lido da memória
        ALU_Result_Int_in: in std_logic_vector(31 downto 0); -- Passou direto pelo estágio MEM
        ALU_Result_FP_in : in std_logic_vector(31 downto 0); -- Passou direto pelo estágio MEM
        
        WriteReg_Addr_in : in std_logic_vector(4 downto 0);

        -- === SAÍDAS ===
        RegWrite_out      : out std_logic;
        FP_RegWrite_out   : out std_logic;
        WriteBack_Sel_out : out std_logic_vector(1 downto 0);

        ReadData_Mem_out  : out std_logic_vector(31 downto 0);
        ALU_Result_Int_out: out std_logic_vector(31 downto 0);
        ALU_Result_FP_out : out std_logic_vector(31 downto 0);
        WriteReg_Addr_out : out std_logic_vector(4 downto 0)
    );
end entity Reg_MEM_WB;

architecture Behavioral of Reg_MEM_WB is
begin
    process(Clk, Rst)
    begin
        if Rst = '1' then
            RegWrite_out      <= '0';
            FP_RegWrite_out   <= '0';
            WriteBack_Sel_out <= (others => '0');
            ReadData_Mem_out  <= (others => '0');
            ALU_Result_Int_out<= (others => '0');
            ALU_Result_FP_out <= (others => '0');
            WriteReg_Addr_out <= (others => '0');
        elsif rising_edge(Clk) then
            RegWrite_out      <= RegWrite_in;
            FP_RegWrite_out   <= FP_RegWrite_in;
            WriteBack_Sel_out <= WriteBack_Sel_in;
            ReadData_Mem_out  <= ReadData_Mem_in;
            ALU_Result_Int_out<= ALU_Result_Int_in;
            ALU_Result_FP_out <= ALU_Result_FP_in;
            WriteReg_Addr_out <= WriteReg_Addr_in;
        end if;
    end process;
end architecture Behavioral;
library ieee;
use ieee.std_logic_1164.all;

entity MIPS_Processor is
    port (
        Clk : in  std_logic;
        Rst : in  std_logic
    );
end entity MIPS_Processor;

architecture Structural of MIPS_Processor is

    -- Declaração do Datapath
    component Datapath
        port (
            Clk, Rst      : in std_logic;
            -- Entradas de Controle
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
            -- Saídas para Controle
            Opcode_out    : out std_logic_vector(5 downto 0);
            Funct_out     : out std_logic_vector(5 downto 0);
            ALU_Result_Debug : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Declaração da Unidade de Controle
    component Control_Unit
        port (
            Opcode        : in  std_logic_vector(5 downto 0);
            Funct         : in  std_logic_vector(5 downto 0);
            RegWrite      : out std_logic;
            FP_RegWrite   : out std_logic;
            RegDst        : out std_logic;
            Branch        : out std_logic;
            Branch_Cond   : out std_logic;
            Jump          : out std_logic;
            MemWrite      : out std_logic;
            MemRead       : out std_logic;
            ALUSrc        : out std_logic;
            ALU_Sel       : out std_logic_vector(3 downto 0);
            FP_Op_Sel     : out std_logic;
            WriteBack_Sel : out std_logic_vector(1 downto 0) 
        );
    end component;

    -- Sinais de Interconexão (Fios entre Control e Datapath)
    signal w_Opcode, w_Funct : std_logic_vector(5 downto 0);
    
    signal w_RegWrite, w_FP_RegWrite, w_RegDst : std_logic;
    signal w_Branch, w_Branch_Cond, w_Jump : std_logic;
    signal w_MemWrite, w_MemRead, w_ALUSrc : std_logic;
    signal w_ALU_Sel : std_logic_vector(3 downto 0);
    signal w_FP_Op_Sel : std_logic;
    signal w_WriteBack_Sel : std_logic_vector(1 downto 0);
    
    -- Sinal de Debug (Não conectado a saída externa por enquanto)
    signal w_ALU_Result_Debug : std_logic_vector(31 downto 0);

begin

    -- Instância do Datapath
    u_Datapath: Datapath
        port map (
            Clk => Clk,
            Rst => Rst,
            -- Conectando entradas de controle aos fios 'w_'
            RegWrite      => w_RegWrite,
            FP_RegWrite   => w_FP_RegWrite,
            RegDst        => w_RegDst,
            Branch        => w_Branch,
            Branch_Cond   => w_Branch_Cond,
            Jump          => w_Jump,
            MemWrite      => w_MemWrite,
            MemRead       => w_MemRead,
            ALUSrc        => w_ALUSrc,
            ALU_Sel       => w_ALU_Sel,
            FP_Op_Sel     => w_FP_Op_Sel,
            WriteBack_Sel => w_WriteBack_Sel,
            -- Conectando saídas de status aos fios 'w_'
            Opcode_out    => w_Opcode,
            Funct_out     => w_Funct,
            ALU_Result_Debug => w_ALU_Result_Debug
        );

    -- Instância da Unidade de Controle
    u_Control_Unit: Control_Unit
        port map (
            Opcode        => w_Opcode, -- Recebe do Datapath
            Funct         => w_Funct,  -- Recebe do Datapath
            -- Gera os sinais de controle
            RegWrite      => w_RegWrite,
            FP_RegWrite   => w_FP_RegWrite,
            RegDst        => w_RegDst,
            Branch        => w_Branch,
            Branch_Cond   => w_Branch_Cond,
            Jump          => w_Jump,
            MemWrite      => w_MemWrite,
            MemRead       => w_MemRead,
            ALUSrc        => w_ALUSrc,
            ALU_Sel       => w_ALU_Sel,
            FP_Op_Sel     => w_FP_Op_Sel,
            WriteBack_Sel => w_WriteBack_Sel
        );

end architecture Structural;
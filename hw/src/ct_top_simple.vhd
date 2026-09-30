library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ct_top_simple is
    port (
        clk_axi      : in  std_logic;
        clk_fast     : in  std_logic;
        rst          : in  std_logic;
        
        diff_in_p    : in  std_logic_vector(3 downto 0);
        diff_in_n    : in  std_logic_vector(3 downto 0);
        diff_out_p_0 : out std_logic;
        diff_out_n_0 : out std_logic;
        term         : out std_logic_vector(4 downto 0);
        oe           : out std_logic_vector(4 downto 0);
        
        en_i         : in  std_logic_vector(1 downto 0); -- [0]=Enable, [1]=Pop
        config       : in  std_logic_vector(7 downto 0);
        
        fifo_ts      : out std_logic_vector(31 downto 0);
        fifo_data    : out std_logic_vector(31 downto 0)
    );
end ct_top_simple;

architecture rtl of ct_top_simple is
    signal se_a, se_b, se_c, se_d : std_logic;
    signal se_out : std_logic := '0';
    
    signal en_i_s1, en_i_s2 : std_logic_vector(1 downto 0) := "00";
    signal pop_prev, fifo_rd_pulse : std_logic := '0';
    signal en_sync, rst_combined : std_logic := '0';
    
    signal fifo_dout_raw : std_logic_vector(47 downto 0);
    signal fifo_empty_raw : std_logic;
    signal fifo_dout_s1, fifo_dout_s2 : std_logic_vector(47 downto 0) := (others => '0');
    signal fifo_empty_s1, fifo_empty_s2 : std_logic := '1';
begin

    u_diff_a: entity work.diff_to_se_1ch port map (diff_in_p => diff_in_p(0), diff_in_n => diff_in_n(0), se_out => se_a);
    u_diff_b: entity work.diff_to_se_1ch port map (diff_in_p => diff_in_p(1), diff_in_n => diff_in_n(1), se_out => se_b);
    u_diff_c: entity work.diff_to_se_1ch port map (diff_in_p => diff_in_p(2), diff_in_n => diff_in_n(2), se_out => se_c);
    u_diff_d: entity work.diff_to_se_1ch port map (diff_in_p => diff_in_p(3), diff_in_n => diff_in_n(3), se_out => se_d);
    
    se_out <= '0'; 
    u_diff_out: entity work.se_to_diff_1ch port map (se_in => se_out, diff_out_p => diff_out_p_0, diff_out_n => diff_out_n_0);

    term <= "11111"; -- Termination ON for all
    oe <= "01111";   -- Ch5(oe[4]) = 0 (Output), Ch1-4(oe[3:0]) = 1 (Inputs)

    process(clk_fast) begin
        if rising_edge(clk_fast) then
            en_i_s1 <= en_i; en_i_s2 <= en_i_s1; pop_prev <= en_i_s2(1);
            if en_i_s2(1) = '1' and pop_prev = '0' then fifo_rd_pulse <= '1'; else fifo_rd_pulse <= '0'; end if;
        end if;
    end process;
    en_sync <= en_i_s2(0);
    rst_combined <= rst or (not en_sync);

    u_ct: entity work.four_fold_coincidence_simple
        port map (
            clk_fast => clk_fast, rst => rst_combined,
            in_A => se_a, in_B => se_b, in_C => se_c, in_D => se_d,
            window_width => config, fifo_dout => fifo_dout_raw,
            fifo_empty => fifo_empty_raw, fifo_rd_en => fifo_rd_pulse
        );

    process(clk_axi) begin
        if rising_edge(clk_axi) then
            fifo_dout_s1 <= fifo_dout_raw; fifo_dout_s2 <= fifo_dout_s1;
            fifo_empty_s1 <= fifo_empty_raw; fifo_empty_s2 <= fifo_empty_s1;
        end if;
    end process;

    fifo_ts   <= std_logic_vector(resize(unsigned(fifo_dout_s2(47 downto 32)), 32));
    fifo_data <= X"0000" & fifo_empty_s2 & fifo_dout_s2(15 downto 0);
end rtl;

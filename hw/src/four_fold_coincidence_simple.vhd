library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity four_fold_coincidence_simple is
    generic (FIFO_DEPTH : integer := 512);
    port (
        clk_fast       : in  std_logic;
        rst            : in  std_logic;
        in_A, in_B, in_C, in_D : in  std_logic;
        window_width   : in  std_logic_vector(7 downto 0);
        fifo_dout      : out std_logic_vector(47 downto 0);
        fifo_empty     : out std_logic;
        fifo_rd_en     : in  std_logic
    );
end entity;

architecture rtl of four_fold_coincidence_simple is
    type sr_array is array (0 to 255) of std_logic;
    signal sync1_A, sync2_A, sync1_B, sync2_B : std_logic := '0';
    signal sync1_C, sync2_C, sync1_D, sync2_D : std_logic := '0';
    signal sr_stretch_A, sr_stretch_B, sr_stretch_C, sr_stretch_D : sr_array := (others => '0');
    signal A_wide, B_wide, C_wide, D_wide : std_logic := '0';
    signal coinc_raw, coinc_reg, coinc_prev : std_logic_vector(15 downto 0) := (others => '0');
    signal timestamp : unsigned(15 downto 0) := (others => '0');

    type fifo_mem_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(47 downto 0);
    signal fifo_mem     : fifo_mem_t := (others => (others => '0'));
    signal wr_ptr, rd_ptr : integer range 0 to FIFO_DEPTH-1 := 0;
    signal fifo_count   : integer range 0 to FIFO_DEPTH   := 0;
    signal fifo_wr_en   : std_logic := '0';
    signal fifo_wr_data : std_logic_vector(47 downto 0) := (others => '0');
    signal fifo_empty_i : std_logic := '1';
    signal fifo_dout_i  : std_logic_vector(47 downto 0) := (others => '0');
begin

    process(clk_fast) begin
        if rising_edge(clk_fast) then
            sync1_A <= in_A; sync2_A <= sync1_A; sync1_B <= in_B; sync2_B <= sync1_B;
            sync1_C <= in_C; sync2_C <= sync1_C; sync1_D <= in_D; sync2_D <= sync1_D;
            sr_stretch_A <= sync2_A & sr_stretch_A(0 to 254);
            sr_stretch_B <= sync2_B & sr_stretch_B(0 to 254);
            sr_stretch_C <= sync2_C & sr_stretch_C(0 to 254);
            sr_stretch_D <= sync2_D & sr_stretch_D(0 to 254);
        end if;
    end process;

    process(clk_fast)
        variable or_a, or_b, or_c, or_d : std_logic;
        variable win_int : integer range 1 to 256;
    begin
        if rising_edge(clk_fast) then
            if rst = '1' then A_wide <= '0'; B_wide <= '0'; C_wide <= '0'; D_wide <= '0';
            else
                win_int := to_integer(unsigned(window_width));
                if win_int = 0 then win_int := 1; end if;
                or_a := '0'; or_b := '0'; or_c := '0'; or_d := '0';
                for i in 0 to 255 loop
                    if i < win_int then
                        or_a := or_a or sr_stretch_A(i); or_b := or_b or sr_stretch_B(i);
                        or_c := or_c or sr_stretch_C(i); or_d := or_d or sr_stretch_D(i);
                    end if;
                end loop;
                A_wide <= or_a; B_wide <= or_b; C_wide <= or_c; D_wide <= or_d;
            end if;
        end if;
    end process;

    coinc_raw(15) <= A_wide and B_wide and C_wide and D_wide;
    coinc_raw(14) <= A_wide and B_wide and C_wide and D_wide;
    coinc_raw(13) <= B_wide and C_wide and D_wide; coinc_raw(12) <= A_wide and C_wide and D_wide;
    coinc_raw(11) <= A_wide and B_wide and D_wide; coinc_raw(10) <= A_wide and B_wide and C_wide;
    coinc_raw(9)  <= C_wide and D_wide; coinc_raw(8)  <= B_wide and D_wide;
    coinc_raw(7)  <= B_wide and C_wide; coinc_raw(6)  <= A_wide and D_wide;
    coinc_raw(5)  <= A_wide and C_wide; coinc_raw(4)  <= A_wide and B_wide;
    coinc_raw(3)  <= D_wide; coinc_raw(2)  <= C_wide; coinc_raw(1)  <= B_wide; coinc_raw(0)  <= A_wide;

    process(clk_fast) begin
        if rising_edge(clk_fast) then
            if rst = '1' then coinc_reg <= (others => '0'); coinc_prev <= (others => '0');
            else coinc_reg <= coinc_raw; coinc_prev <= coinc_reg; end if;
            if rst = '1' then timestamp <= (others => '0'); else timestamp <= timestamp + 1; end if;
        end if;
    end process;

    process(clk_fast) begin
        if rising_edge(clk_fast) then
            fifo_wr_en <= '0';
            if rst = '1' then fifo_wr_data <= (others => '0');
            elsif coinc_reg /= X"0000" and coinc_reg /= coinc_prev then
                fifo_wr_data <= std_logic_vector(resize(timestamp, 32)) & coinc_reg;
                fifo_wr_en   <= '1';
            end if;
        end if;
    end process;

    process(clk_fast) begin
        if rising_edge(clk_fast) then
            if rst = '1' then
                wr_ptr <= 0; rd_ptr <= 0; fifo_count <= 0; fifo_empty_i <= '1';
            else
                if fifo_wr_en = '1' and fifo_count < FIFO_DEPTH then
                    fifo_mem(wr_ptr) <= fifo_wr_data;
                    if wr_ptr = FIFO_DEPTH-1 then wr_ptr <= 0; else wr_ptr <= wr_ptr + 1; end if;
                end if;
                if fifo_rd_en = '1' and fifo_count > 0 then
                    fifo_dout_i <= fifo_mem(rd_ptr);
                    if rd_ptr = FIFO_DEPTH-1 then rd_ptr <= 0; else rd_ptr <= rd_ptr + 1; end if;
                end if;
                if fifo_wr_en = '1' and fifo_rd_en = '0' and fifo_count < FIFO_DEPTH then
                    fifo_count <= fifo_count + 1; fifo_empty_i <= '0';
                elsif fifo_rd_en = '1' and fifo_wr_en = '0' and fifo_count > 0 then
                    fifo_count <= fifo_count - 1; if fifo_count = 0 then fifo_empty_i <= '1'; end if;
                end if;
            end if;
        end if;
    end process;

    fifo_dout <= fifo_dout_i; fifo_empty <= fifo_empty_i;
end architecture;

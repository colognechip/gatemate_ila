library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity gol_tb is

end gol_tb;


architecture dut of gol_tb is
	constant CLKFRQ           : natural := 10_000_000;
	constant clk_half_periode : time    := 0.5 sec / CLKFRQ;
	-- component ports
    signal  reset_s, clk_s, set_s, nextGen_s, CPUin_s, L_s, stil_s : std_ulogic;
	signal N_s : std_ulogic_vector(0 to 7);
begin
    DUT : entity work.gol
    port map(
        clk   => clk_s,
        N => N_s,
        reset => reset_s,
        set => set_s,
        nextGen => nextGen_s,
        CPUin => CPUin_s,
        L => L_s,
        stil => stil_s

    );

    p_clock : process
	begin
		clk_s <= '0'; 
		wait for clk_half_periode;
		clk_s <= '1'; 
		wait for clk_half_periode;
	end process p_clock;
	
	wnr_start : process
	begin
		reset_s <= '0';
        N_s <= (others => '0');
        nextGen_s <= '0';
		wait for 20 * clk_half_periode;
		reset_s <= '1';
        set_s <= '1';
        CPUin_s <= '1';
		wait for 2 * clk_half_periode;
        set_s <= '0';
        for i in 0 to 254 loop

            N_s <= std_ulogic_vector(to_unsigned(i, N_s'length));
            wait for 2 * clk_half_periode;
            nextGen_s <= '1';
            wait for 2 * clk_half_periode;
            nextGen_s <= '0';
        end loop;
		wait;
	end process wnr_start;
	
end architecture dut;
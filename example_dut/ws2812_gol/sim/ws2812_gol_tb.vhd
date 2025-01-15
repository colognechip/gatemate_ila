library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity ws2812_gol_tb is

end ws2812_gol_tb;



architecture dut of ws2812_gol_tb is
	constant CLKFRQ           : natural := 10_000_000;
	constant clk_half_periode : time    := 0.5 sec / CLKFRQ;
	-- component ports

	constant gol_len_cnt : natural := 1;
	constant gol_wd_cnt : natural := 1;

	signal  reset_s, reset_2_s : std_ulogic;
	signal clk_s              : std_ulogic;
	signal ws2812_out_s : std_ulogic_vector((gol_len_cnt*gol_wd_cnt)-1 downto 0);
  	 
	signal stswi : std_ulogic_vector(15 downto 0) := "0000000000000001";

	signal stled : std_ulogic_vector(15 downto 0);
	begin  -- architecture dut
	-- component instantiation
	DUT : entity work.ws2812_gol
	generic map(
		sim  => True
	)

	port map (
		clk   => clk_s,
		reset => reset_s,
		reset_2 => reset_2_s,
		ws2812_out => ws2812_out_s,
		stswi => stswi
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
		reset_2_s <= '1';
		wait for 20 * clk_half_periode;
		reset_s <= '1';
		wait for 2000 * clk_half_periode;
		reset_s <= '0';
		wait for 200 * clk_half_periode;
		reset_s <= '1';
		wait;
	end process wnr_start;
	
end architecture dut;

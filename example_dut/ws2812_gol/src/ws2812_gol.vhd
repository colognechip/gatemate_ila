library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ws2812_gol is
	generic(
        sim : boolean := False;
		gol_64_len_cnt : natural := 1;
		gol_64_wd_cnt : natural := 1
    );
port (
	led					: out std_ulogic_vector(7 downto 0);
	clk : in std_ulogic;  
	reset : in std_ulogic; 
	ws2812_out : out std_ulogic_vector(((gol_64_len_cnt*gol_64_wd_cnt)-1) downto 0);
	stswi : in  std_ulogic_vector(15 downto 0);
	stled : out  std_ulogic_vector(15 downto 0);
	sthex0 : out std_ulogic_vector(7 downto 0);
	sthex1 : out std_ulogic_vector(7 downto 0);
	sthex2 : out std_ulogic_vector(7 downto 0);
	sthex3 : out std_ulogic_vector(7 downto 0);
	sthex4 : out std_ulogic_vector(7 downto 0);
	sthex5 : out std_ulogic_vector(7 downto 0)
	);
end entity;

architecture beh of ws2812_gol is
signal ma_choise :	integer range 0 to ((gol_64_len_cnt*gol_64_wd_cnt)-1);

TYPE STATE_NextGen_Type IS (IDLE, Data_to_WS2812, wait_for_finish); 
SIGNAL state_nextGen   : STATE_NextGen_Type := IDLE;

signal raddr_s, waddr_s, din_s, dout_s 			: std_ulogic_vector(7 downto 0);

signal wnr_led, ws2812_out_single, write_en_s : std_ulogic; 

signal start_ram_to_bit : std_ulogic;

signal next_gen_cnt_v : std_ulogic_vector(23 downto 0);



signal ws2812_ready_s : std_ulogic;

signal reset_stable : std_ulogic;
component CC_USR_RSTN is 
	port(
		USR_RSTN : out std_ulogic
	);
end component;


signal CC_reset, reset_all, clk0 : std_ulogic;
begin

	stled <= stswi;

	rst_deouncer : entity work.debouncer
	generic map (
		sync_len => 8
	)
	port map(
		btn => reset,
		clk => clk0,
		reset => CC_reset,
		btn_state_stable => reset_stable
	);
    gen_reset: if sim = false generate
        usr_rstn_inst: CC_USR_RSTN
        port map (
            USR_RSTN => CC_reset -- reset signal to CPE array
        );
    end generate;

    gen_direct_reset: if sim = true generate
		wnr_start : process
		begin
        CC_reset <= '0'; -- permanent high reset signal for simulation
		wait for (5 sec / 10_000_000);
		CC_reset <= '1';
		wait;
		end process wnr_start;
    end generate;


	reset_all <= CC_reset AND reset_stable;
	clk0 <= clk;
	ram_to_bit : entity work.ram_to_bit
	port map(
		    reset => reset_all,
			clk => clk0,
			start => start_ram_to_bit,
			working => wnr_led,
			raddr => raddr_s,
			dataRead => dout_s,
			ws2812_out => ws2812_out_single
	);
	dualPortRam : entity work.ram
	generic map(
		addr_width => 8,
		data_width => 8
	)
		port map(
			write_en => write_en_s,
			waddr => waddr_s,
			clk => clk0,
			raddr => raddr_s,
			din => din_s,
			dout => dout_s
			);

to_seven_0 : entity work.hexdigit
		port map(
			value_in => next_gen_cnt_v(3 downto 0),
			value_out => sthex0,
			p_n => '0'
		);

		to_seven_1 : entity work.hexdigit
		port map(
			value_in => next_gen_cnt_v(7 downto 4),
			value_out => sthex1,
			p_n => '0'
		);

		to_seven_2 : entity work.hexdigit
		port map(
			value_in => next_gen_cnt_v(11 downto 8),
			value_out => sthex2,
			p_n => '0'
		);

		to_seven_3 : entity work.hexdigit
		port map(
			value_in => next_gen_cnt_v(15 downto 12),
			value_out => sthex3,
			p_n => '0'
		);
		to_seven_4 : entity work.hexdigit
		port map(
			value_in => next_gen_cnt_v(19 downto 16),
			value_out => sthex4,
			p_n => '0'
		);
		to_seven_5 : entity work.hexdigit
		port map(
			value_in => next_gen_cnt_v(23 downto 20),
			value_out => sthex5,
			p_n => '0'
		);


Golx64 : entity work.gol_control
	generic map(
		gol_width => 8*gol_64_wd_cnt,
		gol_length => 8*gol_64_len_cnt,
		gol_64_len_cnt => gol_64_len_cnt,
		gol_64_wd_cnt => gol_64_wd_cnt
	)
	port map(
	    clk   		=> clk0,
		reset 		=> reset_all,
		write_en_RAM  => write_en_s,
		ws2812_rgb_byte	=> din_s,
		ws2812_ram_addr_wr 	=> waddr_s,
		ws2812_ready => ws2812_ready_s,
		ma_choise => ma_choise,
		stswi => stswi,
		next_gen_cnt_v => next_gen_cnt_v
		);

		gol_ws2812_i: for i in 0 to (gol_64_len_cnt-1) generate
			gol_ws2812_j: for j in 0 to (gol_64_wd_cnt-1) generate
				ws2812_out((i*gol_64_wd_cnt)+j) <= ws2812_out_single when (ma_choise = ((i*gol_64_wd_cnt)+j)) else '0';
			end generate gol_ws2812_j;
		end generate gol_ws2812_i;

show_reset : process (clk0) is
begin
if rising_edge(clk0) then      
  if reset_all = '0' then               
	led <= "00001111";
  else
	led <= "11110000";
  end if;
end if;
end process;

nextGen : process (clk0) is
		begin
		if rising_edge(clk0) then      
		  if reset_all = '0' then               
			state_nextGen <= IDLE;
			start_ram_to_bit <= '0';
			ws2812_ready_s <= '0';
		  else
			case state_nextGen is
				when  IDLE =>
					start_ram_to_bit <= '0';
					ws2812_ready_s <= '0';
					if write_en_s = '1' then
						state_nextGen <= Data_to_WS2812;
					end if;
		  		when Data_to_WS2812 =>
					start_ram_to_bit <= '1';
					if  wnr_led = '1' then
						state_nextGen <= wait_for_finish;  
					end if;
				when wait_for_finish =>
					start_ram_to_bit <= '0';
					if wnr_led = '0' then
						state_nextGen <= IDLE;
						ws2812_ready_s <= '1';
					end if;
				when others =>
					state_nextGen <= IDLE;
				end case;
			end if;
		end if;
	end process nextGen;
	
end architecture;

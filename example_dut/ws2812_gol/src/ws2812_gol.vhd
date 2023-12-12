library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ws2812_gol is
port (
    i_sclk              : in std_ulogic;
    i_ss                : in std_ulogic;
    i_mosi              : in std_ulogic;
	o_miso              : out std_ulogic;
	led					: out std_ulogic_vector(7 downto 0);
	clk : in std_ulogic;  
	reset : in std_ulogic; 
	ws2812_out : out std_ulogic  
	);
end entity;


architecture beh of ws2812_gol is



TYPE STATE_NextGen_Type IS (IDLE, Data_to_WS2812, wait_for_finish); 
SIGNAL state_nextGen   : STATE_NextGen_Type := IDLE;




-- Signals for RAM
signal write_en_s 		: std_ulogic;		
signal waddr_s 			: std_ulogic_vector(7 downto 0) := "00000000";
signal raddr_s 			: std_ulogic_vector(7 downto 0) := "00000000";
signal din_s 			: std_ulogic_vector(7 downto 0);
signal dout_s  			: std_ulogic_vector(7 downto 0);

signal wnr_led : std_ulogic := '0'; 

signal start_ram_to_bit : std_ulogic;

signal ws2812_out_s : std_ulogic;

signal write_ws2812_s : std_ulogic;

signal ws2812_busy_s : std_ulogic;

signal byte_send : std_ulogic_vector (7 downto 0);
signal byte_receive : std_ulogic_vector (7 downto 0);
signal rec_byte_ready : std_ulogic;

signal read_ready, start_write : std_ulogic;

signal write_en_init_bram : std_ulogic;
signal waddr_init_bram : std_ulogic_vector(2 downto 0);
signal spi_cycle, wr_done_cnt : std_ulogic;

begin


ram_to_bit : entity work.ram_to_bit
	port map(
		    reset => reset,
			clk => clk,
			start => start_ram_to_bit,
			working => wnr_led,
			raddr => raddr_s,
			dataRead => dout_s,
			ws2812_out => ws2812_out_s
	);


dualPortRam : entity work.ram
generic map(
	addr_width => 8,
	data_width => 8
)
	port map(
		write_en => write_en_s,
		waddr => waddr_s,
		clk => clk,
		raddr => raddr_s,
		din => din_s,
		dout => dout_s
		);

    spi_slave : entity work.spi_slave
    port map(
        i_sclk => i_sclk,
        i_ss => i_ss,
        i_mosi => i_mosi,
        i_byte_send => byte_send,
        o_miso => o_miso,
        o_rec_byte_ready => rec_byte_ready,
        o_byte_rec => byte_receive
    );

	spi_edge_detect : entity work.edge_detection
    port map(
        i_clk => clk,
        i_reset => reset,
        i_signal => rec_byte_ready,
        o_post_edge => spi_cycle
    );

    write_bram_rec_cmd : entity work.receive_command
    generic map(
        addr => "01010101"
    )
    port map(
        i_clk => clk,
        i_reset => reset, 
        i_ready_read  => read_ready,
        i_Byte => byte_receive,
        i_done => wr_done_cnt, 
        o_hold => start_write
    );




Golx64 : entity work.gol_8x8_control
	port map(
	    clk   		=> clk,
		reset 		=> reset,
		write_en_RAM  => write_en_s,
		ws2812_rgb_byte	=> din_s,
		ws2812_ram_addr_wr 	=> waddr_s,
		write_ws2812_out => write_ws2812_s,
		ws2812_busy => ws2812_busy_s,
		din_spi => byte_receive,
		waddr_spi => waddr_init_bram,
		write_en => write_en_init_bram,
		start_sm_new => wr_done_cnt
		);

write_bram_rec : process (clk) is
		begin
			if rising_edge(clk) then
				if reset = '0' then
					write_en_init_bram <= '0';
				elsif start_write = '1' and spi_cycle = '1'  then
					write_en_init_bram <= '1';
				elsif start_write = '0' then
					write_en_init_bram <= '0';
				end if;
			end if;
		end process write_bram_rec;

		read_ready <= not start_write;

write_bram_cnt : process (clk) is
	begin
	if rising_edge(clk) then
		if reset = '0' then
			waddr_init_bram <= (others => '0');
		elsif (write_en_init_bram = '1' and spi_cycle = '1' and waddr_init_bram /= "111") then
			waddr_init_bram <=  std_ulogic_vector((unsigned(waddr_init_bram)) + 1);
		elsif (write_en_init_bram = '0') then
			waddr_init_bram <= (others => '0');
		end if;
	end if;
end process;

write_bra_cnt : process (clk) is
begin
if rising_edge(clk) then
	if reset = '0' then
		wr_done_cnt <= '0';
	elsif waddr_init_bram = "111" and spi_cycle = '1' then
		wr_done_cnt <= '1';
	else
		wr_done_cnt <= '0';
	end if;
end if;
end process;

show_reset : process (clk) is
begin
if rising_edge(clk) then      
  if reset = '0' then               
	led <= "00001111";
  else
	led <= "11110000";
  end if;
end if;
end process;

nextGen : process (clk) is
		begin
		if rising_edge(clk) then      
		  if reset = '0' then               
			state_nextGen <= IDLE;
			start_ram_to_bit <= '0';
			ws2812_busy_s <= '0';
		  else
			case state_nextGen is
				when  IDLE =>
					start_ram_to_bit <= '0';
					ws2812_busy_s <= '0';
					if write_ws2812_s = '1' then
						state_nextGen <= Data_to_WS2812;
					end if;
		  		when Data_to_WS2812 =>
				  	ws2812_busy_s <= '1';
					start_ram_to_bit <= '1';
					if  wnr_led = '1' then
						state_nextGen <= wait_for_finish;  
					end if;
				when wait_for_finish =>
					start_ram_to_bit <= '0';
					if wnr_led = '0' then
						state_nextGen <= IDLE;
					end if;
				when others =>
					state_nextGen <= IDLE;
				end case;
			end if;
		end if;
	end process nextGen;


    ws2812_out <= ws2812_out_s;
	
end architecture;

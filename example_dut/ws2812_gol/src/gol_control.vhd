-- #################################################################################################
-- #   << ws2812gol - gol_8x8_control >>                                               			#
-- #  a matrix is created from individual game of life cells. the initialisation and calculation   #
-- #  of a new generation is also controlled.     													#
-- # ********************************************************************************************* #
-- #    Copyright (C) 2023 Cologne Chip AG & TH Köln                             				  	#
-- #    Developed by Dave Fohrn                                                                    #
-- #                                                                                               #
-- #    This program is free software: you can redistribute it and/or modify                       #
-- #    it under the terms of the GNU General Public License as published by                       #
-- #    the Free Software Foundation, either version 3 of the License, or                          #
-- #    (at your option) any later version.                                                        #
-- #                                                                                               #
-- #    This program is distributed in the hope that it will be useful,                            #
-- #    but WITHOUT ANY WARRANTY; without even the implied warranty of                             #
-- #    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                              #
-- #    GNU General Public License for more details.                                               #
-- #                                                                                               #
-- #    You should have received a copy of the GNU General Public License                          #
-- #    along with this program.  If not, see <https://www.gnu.org/licenses/>.                     #
-- #                                                                                               #
-- # ********************************************************************************************* #
-- #################################################################################################


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gol_control is
	generic(
        gol_width : natural := 16;
		gol_length : natural := 16;
		gol_64_len_cnt : natural := 2;
		gol_64_wd_cnt : natural := 2
    );
  port (
    clk         : in  std_ulogic;
    reset       : in std_ulogic;
	write_en_RAM : out std_ulogic;
	ws2812_rgb_byte	: out std_ulogic_vector(7 downto 0);
	ws2812_ram_addr_wr	: out std_ulogic_vector(7 downto 0);
	ws2812_ready	: in std_ulogic;
	ma_choise : out integer range 0 to ((gol_64_len_cnt*gol_64_wd_cnt)+1);
	stswi : in  std_ulogic_vector(15 downto 0);
	next_gen_cnt_v : out  std_ulogic_vector(23 downto 0)  
	);
  end gol_control;

architecture verhalten of gol_control is

-- Nachbarn sind [x][y][z]
-- 983:966, 957:940, 931:914, 905:888, 879:862, 853:836, 827:810, 801:784, 775:758, 749:732, 723:706, 697:680, 671:654, 645:628, 619:602, 593:576, 567:550, 541:524, 515:498, 489:472, 463:446, 437:420, 411:394, 385:368, 359:342, 333:316, 307:290, 281:264, 255:238, 229:212, 203:186, 177:160, 151:134, 125:108
-- 612
signal ma_choise_s : integer range 0 to ((gol_64_len_cnt*gol_64_wd_cnt)+1);

signal write_en_RAM_s, start_cnt : std_ulogic; 

type in_array_t is array (0 to (gol_width-1)) of std_ulogic_vector(0 to 7); -- [y = Breite][z = 8 = Nachbarn pro Zelle]
type in_matrix_t is array (0 to (gol_length-1)) of in_array_t;  				-- [x = Breite]
signal neighbours_in  			: in_matrix_t;

type out_matrix_t is array (0 to (gol_length+1)) of std_ulogic_vector((gol_width+1) downto 0); 
signal life_out 				: out_matrix_t;

signal write_RAM_gol_reg, ser_out : std_ulogic_vector(((gol_64_len_cnt * gol_64_wd_cnt)-1) downto 0);

signal writeRam 	: std_ulogic := '0'; 

signal gol_init : std_ulogic;

signal write_to_ram_ws28_12_done : std_ulogic;
--signal blp_di, blp_do  : std_ulogic_vector(39 downto 0);
--signal blp_addr_write, blp_addr_read : std_ulogic_vector(4 downto 0);

signal ma_next : std_ulogic;

signal gol_next_gen : std_ulogic := '0';


TYPE TL_GOL_STATE_TYPE IS (gol_init_st, gol_init_done, wait_write, wait_break, next_gen, next_gen_done);
SIGNAL TL_GOL_STATE : TL_GOL_STATE_TYPE := gol_init_st;  

signal break_counter : unsigned(24 downto 0);

signal next_gen_cnt : unsigned(23 downto 0);

type ram is array (0 to (gol_length-1)) of std_ulogic_vector((gol_width-1) downto 0);
signal init_pattern : ram;


signal write_to_ram_ws28_12_done_hold : std_ulogic;
signal life_shift_cnt : integer range 0 to 7; 
signal rgb_color : integer range 0 to 2;
signal counter_index : integer range 0 to 7;

signal rgb_color_2, life_shift_cnt_7, write_start : std_ulogic;

signal first_time : std_ulogic := '0';

signal ws2812_ram_addr_wr_s : std_ulogic_vector(7 downto 0) := "00000000";



begin

	
gol_row: for x in 0 to (gol_length-1) generate
   gol_column: for y in 0 to (gol_width-1) generate
    gol : entity work.gol
    port map (
        N       => neighbours_in(x)(y),
        clk     => clk,
        set    	=> gol_init, 
        nextGen => gol_next_gen,
        CPUin   => init_pattern(x)(y), 
        L       => life_out(x+1)(y+1),
        reset   => reset
    );
	neighbours_in(x)(y)(0) <= life_out((x+1)-1)((y+1)-1);	
    neighbours_in(x)(y)(1) <= life_out((x+1)-1)((y+1));	    
    neighbours_in(x)(y)(2) <= life_out((x+1)-1)((y+1)+1);	
    neighbours_in(x)(y)(3) <= life_out((x+1))((y+1)-1);   	
    neighbours_in(x)(y)(4) <= life_out((x+1))((y+1)+1);	    
    neighbours_in(x)(y)(5) <= life_out((x+1)+1)((y+1)-1);   
    neighbours_in(x)(y)(6) <= life_out((x+1)+1)((y+1));	   
    neighbours_in(x)(y)(7) <= life_out((x+1)+1)((y+1)+1); 
    end generate gol_column;
end generate gol_row;




-- Zellen miteinander verbinden
--xIndex: for x in 0 to (gol_length-1) generate
--    yIndex: for y in 0 to (gol_width-1) generate
--        neighbours_in(x)(y)(0) <= life_out((x+1)-1)((y+1)-1);	
--        neighbours_in(x)(y)(1) <= life_out((x+1)-1)((y+1));	    
--        neighbours_in(x)(y)(2) <= life_out((x+1)-1)((y+1)+1);	
--        neighbours_in(x)(y)(3) <= life_out((x+1))((y+1)-1);   	
--        neighbours_in(x)(y)(4) <= life_out((x+1))((y+1)+1);	    
--        neighbours_in(x)(y)(5) <= life_out((x+1)+1)((y+1)-1);   
--        neighbours_in(x)(y)(6) <= life_out((x+1)+1)((y+1));	   
--        neighbours_in(x)(y)(7) <= life_out((x+1)+1)((y+1)+1); 	         
--   end generate;
--end generate;

-- BLO
xIndexNachbarn: for x in 0 to gol_width generate
		life_out(0)(x) 								<= '0'; --Nachbarn(x);                           
		life_out((gol_length+1))((gol_width+1)-x) 	<= '0'; --Nachbarn((gol_width+1)+(gol_length+1) +x);
	end generate;
-- BLO
yIndexNachbarn: for y in 0 to gol_length generate                    
		life_out(y)((gol_width+1)) 				<= '0';--Nachbarn((gol_width+1)+y);
		life_out((gol_length+1)-y)(0) 			<= '0';--Nachbarn((2*(gol_width+1))+(gol_length+1)+y);
	end generate;



	next_gen_cnt_v <= std_ulogic_vector(next_gen_cnt);
state_maschine : process (clk) is   
	begin
	if rising_edge(clk) then
			if reset = '0'  then
				TL_GOL_STATE <= gol_init_st;
				gol_next_gen <= '0';
				writeRam <= '0';
				gol_init <= '0';
				break_counter <= (others => '0');
				next_gen_cnt <= (others => '0');
			else
				case TL_GOL_STATE IS
					when gol_init_st => 
						gol_init <= '1';
						TL_GOL_STATE <= gol_init_done;
					when gol_init_done =>
						gol_init <= '0';
						TL_GOL_STATE <= wait_write;
					when wait_write => 
						writeRam <= '1';
						if (ma_next = '0') and (ws2812_ready = '1') then
							TL_GOL_STATE <= wait_break;
						end if;
					when wait_break =>
						writeRam <= '0';
						if std_ulogic_vector(break_counter(24 downto 9)) /= stswi then
							break_counter <= break_counter+1;
						else
							TL_GOL_STATE <= next_gen;
						end if; 
					when next_gen =>
						gol_next_gen <= '1';
						next_gen_cnt <= next_gen_cnt +1; 
						break_counter <= (others => '0');
						TL_GOL_STATE <= next_gen_done;
					when next_gen_done =>
						gol_next_gen <= '0';
						TL_GOL_STATE <= wait_write;
				end case;
			end if;
	end if;
end process state_maschine;

--bram_load_pattern : entity work.bram_pattern
--	generic map(
--		DATA_WIDTH => 40,
--		ADDR_WIDTH => 5
--	)
--    port map (
--		we => blp_we,
--		clk => clk,
--		di => blp_di,
--		addr_read => blp_addr_read,
--		addr_write => blp_addr_write,
--		do => blp_do
--	);




random_shift_0 : process(clk) is
begin
if rising_edge(clk) then
	if (reset = '0') then
		if (first_time = '0') then
			init_pattern(0) <= "00000001"; --"0000000000000000000000000000000000000001";
			first_time <= '1';
		end if;
	else
		-- init_pattern(0) <= (init_pattern(0)((gol_width-2) downto 0) & (init_pattern(gol_length-1)(gol_width-1) xor init_pattern(gol_length-1)(gol_width-8) xor init_pattern(gol_length-1)(gol_width-15) xor init_pattern(gol_length-1)(gol_width-21)));
		-- 64: 63,63, 61, 60 -> 
		init_pattern(0) <= (init_pattern(0)((gol_width-2) downto 0) & (init_pattern(gol_length-1)(gol_width-1) xor init_pattern(gol_length-1)(gol_width-2) xor init_pattern(gol_length-1)(gol_width-4) xor init_pattern(gol_length-1)(gol_width-5) ));  
	end if;
end if;
end process;

-- 960, 954, 946, 939 
-- -1, -7, 14, 21


	random : for y in 1 to (gol_length-1) generate
		random_init_process : process(clk) is
		begin
			if rising_edge(clk) then
				if (reset = '0') then
					if (first_time = '0') then
						init_pattern(y) <=  (others => '0');
					end if;
				else
					init_pattern(y) <= init_pattern(y)((gol_width-2) downto 0) & init_pattern(y-1)(gol_width-1);
				end if;
			end if;
		end process;
	end generate;
--setGolpattern : process (clk) is
--begin
--	if rising_edge(clk) then
--		if reset = '0' then
--			blp_we <= '0';
--			blp_di <= (others => '0');
--			
--			cnt_start <= '0';
--		elsif ram_load = '1' then
--			if cnt_bram < 24 then
--				cnt_start <= '1';
--				init_pattern(cnt_bram) <= blp_do;
--			else
--				load_done <= '1';
--				cnt_start <= '0';
--			end if;
--		end if;
--	end if;
--end process;
--
--addr_cnt_proc :  process (clk) is
--begin
--	if rising_edge(clk) then
--		if reset = '0' then
--			cnt_bram <= 0;
--		elsif cnt_start = '1' then
--			cnt_bram <= cnt_bram+1;
--		end if;
--	end if;
--end process; 



	-- blp_addr_read <= std_ulogic_vector(to_unsigned(cnt_bram, blp_addr_read'length));


		--setGol : process (clk) is
		--begin
		--	if rising_edge(clk) then
		--		if reset = '0' then
		--			init_pattern(0) <=  "0000000000000000000000000000000000000000";--"00000000";--"00011000"; -- "00000000";
		--			init_pattern(1) <=  "0000000000000000000000000000000000000000";--"01110000";--"00111100"; -- "01110000";
		--			init_pattern(2) <=  "0000000000000000000000000000000000000000";--"00000000";--"01000010"; -- "00000000";
		--			init_pattern(3) <=  "0000000000000000000000000000000000000000";--"00000000";--"11000011"; -- "00000000";
		--			init_pattern(4) <=  "0000000000000000000000000000000000000000";--"00001000";--"11000011"; -- "00001000";
		--			init_pattern(5) <=  "0000000000000000000000000000000000000000";--"00001000";--"01000010"; -- "00001000";
		--			init_pattern(6) <=  "0000000000000000000000000000000000000000";--"00001000";--"00111100"; -- "00001000";
		--			init_pattern(7) <=  "0000000000000000000000000000000000000000";--"00000000";--"00011000"; -- "00000000";
		--			init_pattern(8) <=  "0000000000000000000000000000000000000000";--"00000000";--"00011000"; -- "00000000";
		--			init_pattern(9) <=  "0000000000000000000000000000000000000000";--"01110000";--"00111100"; -- "01110000";
		--			init_pattern(10) <= "0000000000000000000000000000000000000000"; --"00000000";--"01000010"; -- "00000000";
		--			init_pattern(11) <= "0000000000000000000000000000000000000000"; --"00000000";--"11000011"; -- "00000000";
		--			init_pattern(12) <= "0000000000000000111011100000000000000000"; --"00001000";--"11000011"; -- "00001000";
		--			init_pattern(13) <= "0000000000000000100000100000000000000000"; --"00001000";--"01000010"; -- "00001000";
		--			init_pattern(14) <= "0000000000000000111011100000000000000000"; --"00001000";--"00111100"; -- "00001000";
		--			init_pattern(15) <= "0000000000000000000000000000000000000000"; --"00000000";--"00011000"; -- "00000000";
		--			init_pattern(16) <= "0000000000000000000000000000000000000000"; --"00000000";--"00011000"; -- "00000000";
		--			init_pattern(17) <= "0000000000000000000000000000000000000000"; --"01110000";--"00111100"; -- "01110000";
		--			init_pattern(18) <= "0000000000000000000000000000000000000000"; --"00000000";--"01000010"; -- "00000000";
		--			init_pattern(19) <= "0000000000000000000000000000000000000000"; --"00000000";--"11000011"; -- "00000000";
		--			init_pattern(20) <= "0000000000000000000000000000000000000000"; --"00001000";--"11000011"; -- "00001000";
		--			init_pattern(21) <= "0000000000000000000000000000000000000000"; --"00001000";--"01000010"; -- "00001000";
		--			init_pattern(22) <= "0000000000000000000000000000000000000000"; --"00001000";--"00111100"; -- "00001000";
		--			init_pattern(23) <= "0000000000000000000000000000000000000000"; --"00000000";--"00011000"; -- "00000000";
		--		end if;
		--	end if;
		--end process;
	--end generate yMaIndexInit;
	--end generate xMaIndexInit;


	ma_next <= '1' when ma_choise_s /= ((gol_64_len_cnt*gol_64_wd_cnt)-1) else '0';

 ma_cnt : process (clk) is
 begin
 	if rising_edge(clk) then
 		if reset = '0' or (writeRam = '0') then 
			ma_choise_s <= 0;
		elsif (ws2812_ready = '1') and (ma_next = '1') then
			ma_choise_s <= ma_choise_s +1;
		end if;
	end if;
end process; 

ma_choise <= ma_choise_s;

gol_to_ram : process (clk) is
	begin
		if rising_edge(clk) then
			if reset = '0' or writeRam = '0' then
				write_RAM_gol_reg <= (others => '0');
				write_start <= '0';
			else 
				if write_start = '0' then
					write_RAM_gol_reg(0) <= '1';
					write_start <= '1';
				elsif (ws2812_ready = '1') and (ma_next = '1') then
						write_RAM_gol_reg <= write_RAM_gol_reg(write_RAM_gol_reg'high - 1 downto 0) & '0';
				end if;
			end if;
		end if;
	end process;

xMaIndex: for x in 0 to (gol_64_wd_cnt-1) generate -- gol_64_len_cnt + gol_64_wd_cnt
	yMaIndex : for y in 0 to (gol_64_len_cnt-1) generate
		gol_ser : entity work.gol_8x8_ser
		port map (
			clk     => clk,
			reset   => reset,
			row_0	=> life_out((8*y)+1)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))),  
			row_1	=> life_out((8*y)+2)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))), 
			row_2	=> life_out((8*y)+3)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))), 
			row_3	=> life_out((8*y)+4)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))), 
			row_4	=> life_out((8*y)+5)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))), 
			row_5	=> life_out((8*y)+6)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))), 
			row_6	=> life_out((8*y)+7)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))), 
			row_7	=> life_out((8*y)+8)((gol_width - (8*x)) downto ((gol_width-7) - (8*x))),
			ser_out => ser_out((y*gol_64_wd_cnt)+x),
			write_en_s => write_RAM_gol_reg((y*gol_64_wd_cnt)+x),
			rgb_color_2 => rgb_color_2,  
			life_shift_cnt_7 => life_shift_cnt_7,
			counter_index => counter_index 
		);
	end generate yMaIndex;
end generate xMaIndex;

ram_write_control : process (clk) is
begin
	if rising_edge(clk) then
		if reset = '0' or writeRam = '0' then 
			write_en_RAM_s <= '0';
			start_cnt <= '0';
		else
			if write_to_ram_ws28_12_done = '1' then
				write_en_RAM_s <= '0';
			elsif ((ws2812_ready = '1' and ma_next = '1') or write_start = '0') then
				write_en_RAM_s <= '1';
			end if;
			start_cnt <= write_en_RAM_s;

		end if;
	end if;
end process;

write_en_RAM <= write_en_RAM_s;

	index_cnt : process (clk) is
    begin
        if rising_edge(clk) then
            if reset = '0' or write_en_RAM_s = '0' then
                counter_index <= 0;
                write_to_ram_ws28_12_done_hold <= '0';
            else
                if life_shift_cnt = 6 and rgb_color = 2 then
                    if counter_index < 7 then
                        counter_index <= counter_index + 1;
                    else
                        counter_index <= 1;
                        write_to_ram_ws28_12_done_hold <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    
    
    
    output_counter : process (clk) is
    begin
        if rising_edge(clk) then
            if reset = '0' or write_en_RAM_s = '0' then
                life_shift_cnt <= 0;
                write_to_ram_ws28_12_done <= '0';
                
            else
                if rgb_color = 2 then
                    if life_shift_cnt = 6 then
                        life_shift_cnt <= life_shift_cnt+1;
                    elsif life_shift_cnt = 7 then
                        life_shift_cnt <= 0;
                        write_to_ram_ws28_12_done <= write_to_ram_ws28_12_done_hold;
                    else
                        life_shift_cnt <= life_shift_cnt+1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    shift_counter : process (clk) is
    begin
        if rising_edge(clk) then
            if reset = '0' or write_en_RAM_s = '0' then
                rgb_color <= 0;
            else
                if rgb_color = 2 then
                    rgb_color <= 0;
                else
                    rgb_color <=  rgb_color + 1;
				end if;
            end if;
        end if;
    end process;
    
        
        ram_adress_counter : process (clk) is
        begin
            if rising_edge(clk) then
                if reset = '0' or write_en_RAM_s = '0'  then
                    ws2812_ram_addr_wr_s <= (others => '0');
				elsif (start_cnt = '1') then
                    ws2812_ram_addr_wr_s <= std_ulogic_vector((unsigned(ws2812_ram_addr_wr_s)) + 1);
                elsif (ws2812_ready = '0') then
					ws2812_ram_addr_wr_s <= (others => '0');
				end if;
            end if;
        end process;
		ws2812_ram_addr_wr <= ws2812_ram_addr_wr_s;
		rgb_color_2 <= '1' when (rgb_color = 2) else '0';
		life_shift_cnt_7 <= '1' when (life_shift_cnt = 7) else '0';

	color_process : process (clk) is
	begin
		if rising_edge(clk) then
			if reset = '0' or write_en_RAM_s = '0' then
				ws2812_rgb_byte <= (others => '0');
			else
				if ser_out(ma_choise_s) = '1' then
					case rgb_color is
						when 0 => ws2812_rgb_byte <= "00011111";
						when 1 => ws2812_rgb_byte <= "00000000";
						when 2 => ws2812_rgb_byte <= "00000000";
						when others => ws2812_rgb_byte <= "00000000";
					end case;
					else
					case rgb_color is
						when 0 => ws2812_rgb_byte <= "00000000";
						when 1 => ws2812_rgb_byte <= "00000000";
						when 2 => ws2812_rgb_byte <= "00000001";
						when others => ws2812_rgb_byte <= "00000000";
					end case;
						end if;
				end if;
			end if;
	end process;


end verhalten;

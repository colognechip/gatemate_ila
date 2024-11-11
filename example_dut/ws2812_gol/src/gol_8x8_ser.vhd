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

entity gol_8x8_ser is
    port(
        clk         : in  std_ulogic;
        reset       : in std_ulogic;
        row_0 : in std_ulogic_vector(7 downto 0);
        row_1 : in std_ulogic_vector(7 downto 0);
        row_2 : in std_ulogic_vector(7 downto 0);
        row_3 : in std_ulogic_vector(7 downto 0);
        row_4 : in std_ulogic_vector(7 downto 0);
        row_5 : in std_ulogic_vector(7 downto 0);
        row_6 : in std_ulogic_vector(7 downto 0);
        row_7 : in std_ulogic_vector(7 downto 0);
        ser_out : out std_ulogic;
        write_en_s : in std_ulogic;
        rgb_color_2 : in std_ulogic;
        life_shift_cnt_7 : in std_ulogic;
        counter_index : in integer range 0 to 7

    );
end gol_8x8_ser;

architecture verhalten of gol_8x8_ser is

    type out_matrix_t is array (0 to 7) of std_ulogic_vector(7 downto 0); 
    signal life_out 				: out_matrix_t;

signal shift_life_row	   : std_ulogic_vector (7 downto 0);



begin

    life_out(0) <= row_0;
    life_out(1) <= row_1;
    life_out(2) <= row_2;
    life_out(3) <= row_3;
    life_out(4) <= row_4;
    life_out(5) <= row_5;
    life_out(6) <= row_6;
    life_out(7) <= row_7;
     



    load_life : process (clk) is
    begin
        if rising_edge(clk) then
            if reset = '0' or write_en_s = '0' then
                shift_life_row <= life_out(counter_index);
            elsif rgb_color_2 = '1' then
                if life_shift_cnt_7 = '1' then
                    shift_life_row <= life_out(counter_index);
                else
                    shift_life_row <=  shift_life_row(6 downto 0) & '0';
                end if;
            end if;
        end if;
    end process;
    
    

        

        ser_out <= shift_life_row(7);

        

        

    end verhalten;





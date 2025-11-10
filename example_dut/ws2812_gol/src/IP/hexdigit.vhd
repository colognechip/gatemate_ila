library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hexdigit is
    port (
        value_in  : in  std_ulogic_vector(3 downto 0);
        value_out : out std_ulogic_vector(7 downto 0);
        p_n : in std_ulogic

    );
end hexdigit;

architecture behavior of hexdigit is
begin
    process (value_in)
    begin
        case value_in is
            when "0000" => value_out <= "1000000" & (not p_n); -- '0'
            when "0001" => value_out <= "1111001" & (not p_n); -- '1'
            when "0010" => value_out <= "0100100" & (not p_n); -- '2'
            when "0011" => value_out <= "0110000" & (not p_n); -- '3'
            when "0100" => value_out <= "0011001" & (not p_n); -- '4'
            when "0101" => value_out <= "0010010" & (not p_n); -- '5'
            when "0110" => value_out <= "0000010" & (not p_n); -- '6'
            when "0111" => value_out <= "1111000" & (not p_n); -- '7'
            when "1000" => value_out <= "0000000" & (not p_n); -- '8'
            when "1001" => value_out <= "0010000" & (not p_n); -- '9'
            when "1010" => value_out <= "0001000" & (not p_n); -- 'A' or 'a'
            when "1011" => value_out <= "0000011" & (not p_n); -- 'B' or 'b'
            when "1100" => value_out <= "1000110" & (not p_n); -- 'C' or 'c'
            when "1101" => value_out <= "0100001" & (not p_n); -- 'D' or 'd'
            when "1110" => value_out <= "0000110" & (not p_n); -- 'E' or 'e'
            when "1111" => value_out <= "0001110" & (not p_n); -- 'F' or 'f'
            when others  => value_out <="1111111" & (not p_n);        -- default
        end case;
    end process;
end behavior;
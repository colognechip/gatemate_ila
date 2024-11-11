library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer is
    generic(
        sync_len : natural := 8
    );
    port(
    btn                 : in  std_ulogic;
    clk                 : in  std_ulogic;
    reset               : in std_ulogic;
    btn_state_stable    : out std_ulogic -- nextgen_btn_state_s
);
    end debouncer;


    architecture behv of debouncer is 
        constant btn_1_value : std_ulogic_vector(sync_len-1 downto 0) := (others => '1');
        constant btn_0_value : std_ulogic_vector(sync_len-1 downto 0) := (others => '0');
        signal btn_reg : std_ulogic_vector(sync_len-1 downto 0) := (others => '0');
        signal stable_state : std_ulogic;




    begin


        get_signal  : process (clk) is
        begin 
            if rising_edge(clk) then
                if (reset = '0') then
                    btn_reg <= (others => '0');
                else
                    btn_reg <= btn_reg(sync_len-2 downto 0) & btn;
                end if;
            end if;
        end process;

        get_stable_signal  : process (clk) is
        begin 
            if rising_edge(clk) then
                if (reset = '0') then
                    stable_state <= btn;
                elsif (btn_reg = btn_1_value) then
                    stable_state <= '1';
                elsif (btn_reg = btn_0_value) then
                    stable_state <= '0';
                end if;
            end if;
        end process;

        btn_state_stable <= stable_state;

        end behv;


library ieee;
use ieee.std_logic_1164.all;

entity gol is
  port (
    N       : in std_ulogic_vector(0 to 7);
    reset   : in std_ulogic;
    clk     : in std_ulogic;
    set    : in std_ulogic;
    nextGen : in std_ulogic;
    CPUin   : in std_ulogic;
    L       : out std_ulogic;
    stil : out std_ulogic);
     
end gol;

architecture behv of gol is
  signal g3, s, h, state_1, state_2 : std_logic;
  type one_bit_adder_res_t is array (3 downto 0) of std_ulogic_vector(1 downto 0);
  signal one_bit_adder_res : one_bit_adder_res_t;
  type two_bit_adder_half_t is array (1 downto 0) of std_ulogic_vector(3 downto 0);
  signal two_bit_adder_half : two_bit_adder_half_t;
  type two_bit_adder_res_t is array (1 downto 0) of std_ulogic_vector(2 downto 0);
  signal two_bit_adder_res : two_bit_adder_res_t;
  signal tmp : std_logic; 

  signal end_res : std_ulogic_vector(2 downto 0);
  signal sum_last :  std_ulogic_vector(3 downto 0);


begin

  bit_adder_gen: for x in 0 to 3 generate
    one_bit_adder_res(x)(1) <= (N(x*2) and N((x*2)+1));
    one_bit_adder_res(x)(0) <= (N(x*2) xor N((x*2)+1)); 
  end generate bit_adder_gen;

    
  two_bit_adder_gen: for x in 0 to 1 generate
    two_bit_adder_res(x)(0) <= one_bit_adder_res((x*2)+1)(0) xor one_bit_adder_res(x*2)(0); -- Q0
    two_bit_adder_half(x)(0) <= one_bit_adder_res((x*2)+1)(0) and one_bit_adder_res(x*2)(0);
    two_bit_adder_half(x)(1) <= one_bit_adder_res((x*2)+1)(1) xor one_bit_adder_res(x*2)(1);
    two_bit_adder_half(x)(2) <= one_bit_adder_res((x*2)+1)(1) and one_bit_adder_res(x*2)(1);
    two_bit_adder_res(x)(1) <= two_bit_adder_half(x)(0) xor two_bit_adder_half(x)(1); -- Q1
    two_bit_adder_half(x)(3) <= two_bit_adder_half(x)(0) and two_bit_adder_half(x)(1); 
    two_bit_adder_res(x)(2) <= two_bit_adder_half(x)(3) or two_bit_adder_half(x)(2);  -- C0
  end generate two_bit_adder_gen;

    end_res(0)  <= two_bit_adder_res(0)(0) xor two_bit_adder_res(1)(0);
    sum_last(0) <= two_bit_adder_res(0)(0) and two_bit_adder_res(1)(0);
    sum_last(1) <= two_bit_adder_res(0)(1) xor two_bit_adder_res(1)(1);
    sum_last(2) <= two_bit_adder_res(0)(1) and two_bit_adder_res(1)(1);
    end_res(1) <= sum_last(0) xor sum_last(1);
    sum_last(3) <= sum_last(0) and sum_last(1);
    end_res(2) <=  sum_last(2) or sum_last(3);
    
    g3 <= end_res(2) or two_bit_adder_res(0)(2) or two_bit_adder_res(1)(2);
    
    s <= end_res(0) and end_res(1) and (not g3);

    h <= (not end_res(0)) and end_res(1) and (not g3);
  
  
  gol_find_stil : process (clk)
  begin
    if falling_edge(clk) then
      if (reset = '0' or set = '1') then 
        state_1 <= '0';
        state_2 <= '0';
      elsif (nextGen = '1') then
        state_1 <= tmp;
        state_2 <= state_1;
      end if;
      stil <= not (tmp xor state_2);
    end if;
    end process;

  
    gol_p : process (clk)
    begin
	if falling_edge(clk) then
		if (reset = '0') then 
			tmp <= '0';
    elsif (set = '1') then
      tmp <= CPUin;
    elsif (nextGen = '1') then
        if(s='1')then
          tmp <= '1';
        elsif(h='0')then
          tmp <= '0';
        end if; 
    end if;
  end if;
end PROCESS;
    
L <= tmp;
    
end behv;
  
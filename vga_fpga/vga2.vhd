----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Michael A. Kohn (mike from mikekohn.net)
-- 
-- Create Date:    17:11:12 04/21/2008 
-- Design Name: 
-- Module Name:    vga2 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Bounce a square around a VGA display while changing colors 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: https://www.mikekohn.net/ 
--                      Copyright 2008 by Michael Kohn
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga2 is
    Port ( mclk : in  STD_LOGIC;
           rgb : out  STD_LOGIC_VECTOR (2 downto 0);
           hs : out  STD_LOGIC;
           vs : out  STD_LOGIC);
end vga2;

architecture Behavioral of vga2 is

signal clk: STD_LOGIC;
signal horz_scan: STD_LOGIC_VECTOR (9 downto 0);
signal vert_scan: STD_LOGIC_VECTOR (9 downto 0);
signal vinc_flag: STD_LOGIC;
signal dx: STD_LOGIC;
signal dy: STD_LOGIC;
signal block_color: STD_LOGIC_VECTOR (2 downto 0);
signal refresh_counter: STD_LOGIC;
signal posx: integer := 300;
signal posy: integer := 300;
signal color: STD_LOGIC_VECTOR (2 downto 0) := "111";

begin

  -- Clock divide by 1/2
  process(mclk)
  begin
    if mclk = '1' and mclk'Event then
      clk <= not clk;
    end if;
  end process;

  -- horizonal clock
  process(clk)
  begin
    if clk = '1' and clk'Event then
      if horz_scan = "1100100000" then
        horz_scan <= "0000000000";
      else
        horz_scan <= horz_scan + 1;
      end if;
    end if;
  end process;

  -- vertial clock (increments when the horizontal clock is on the front porch
  process(vinc_flag)
  begin
    if vinc_flag = '1' and vinc_flag'Event then
      if vert_scan = "1000001001" then
        vert_scan <= "0000000000";
		  refresh_counter <= refresh_counter xor '1';
      else
        vert_scan <= vert_scan + 1;
      end if;
    end if;
  end process;

  process(refresh_counter)
  begin

    if refresh_counter = '1' and refresh_counter'Event then

      if dx = '0' then
        posx <= posx + 1;
		else
		  posx <= posx -1;
		end if;
		
		if dy = '0' then
        posy <= posy + 1;
      else
        posy <= posy -1;
		end if;

		color <= color + 1;
	 end if;
  end process;

  process(posx)
  begin
    if posx = 144 then
	   dx <= '0';
	 elsif posx = 734 then
	   dx <= '1';
	 end if;
  end process;

  process(posy)
  begin
    if posy = 35 then
	   dy <= '0';	 
	 elsif posy = 465 then
	   dy <= '1';
	 end if;
  end process;

  -- horizontal sync for 96 horizontal clocks (96 pixels)
  hs <= '1' when horz_scan < 96 else '0';
  -- vertial sync for 2 scan lines
  vs <= '1' when vert_scan(9 downto 1) = "000000000" else '0';

  rgb <= color when vert_scan >= posy and vert_scan < (posy+50) and horz_scan >= posx and horz_scan < posx+50 else "000";
  vinc_flag <= '1' when horz_scan = "1100011000" else '0';

end Behavioral;


----------------------------------------------------------------------------------
-- Company:
-- Engineer: Michael A. Kohn (mike from mikekohn.net)
-- 
-- Create Date:    09:36:48 04/20/2008 
-- Design Name: 
-- Module Name:    vga - Behavioral 
-- Project Name: 
-- Target Devices: Spartan 3 from DigilentInc.com
-- Tool versions: 
-- Description: Display 3 colors on the vga screen
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

entity vga is
  Port ( mclk : in  STD_LOGIC;
         red : out  STD_LOGIC;
         grn : out  STD_LOGIC;
         blu : out  STD_LOGIC;
         hs : out  STD_LOGIC;
         vs : out  STD_LOGIC);
end vga;

architecture Behavioral of vga is

signal clk: STD_LOGIC;
signal horz_scan: STD_LOGIC_VECTOR (9 downto 0);
signal vert_scan: STD_LOGIC_VECTOR (9 downto 0);
signal vinc_flag: STD_LOGIC;

begin

  -- Clock divide by 1/2  
  process(mclk)
  begin
    if mclk = '1' and mclk'Event then
	   -- clk <= clk xor mclk;
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
      else
		  vert_scan <= vert_scan + 1;
      end if;
    end if;

  end process;

  -- horizontal sync for 96 horizontal clocks (96 pixels)
  -- hs <= '1' when horz_scan(9 downto 7) = "000" else '0';
  hs <= '1' when horz_scan < 96 else '0';
  -- vertial sync for 2 scan lines
  vs <= '1' when vert_scan(9 downto 1) = "000000000" else '0';

  red <= '1' when vert_scan > 100 and vert_scan < 310 and horz_scan >= 144 and horz_scan < 784 else '0';
  grn <= '1' when vert_scan >= 300 and vert_scan < 350 and horz_scan >= 144 and horz_scan < 784 else '0';
  blu <= '1' when vert_scan >= 350 and vert_scan < 515 and horz_scan >= 144 and horz_scan < 784 else '0';

  vinc_flag <= '1' when horz_scan = "1100011000" else '0';

end Behavioral;


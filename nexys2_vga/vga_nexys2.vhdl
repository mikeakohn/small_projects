
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga is
  Port (mclk : in  STD_LOGIC;
        red : out  STD_LOGIC_VECTOR(2 downto 0);
        grn : out  STD_LOGIC_VECTOR(2 downto 0);
        blu : out  STD_LOGIC_VECTOR(1 downto 0);
        hs : out  STD_LOGIC;
        vs : out  STD_LOGIC);
end vga;

architecture Behavioral of vga is

signal clk: STD_LOGIC;
signal horz_scan: STD_LOGIC_VECTOR (9 downto 0);
signal vert_scan: STD_LOGIC_VECTOR (9 downto 0);
signal vinc_flag: STD_LOGIC;

signal start_red: STD_LOGIC_VECTOR (5 downto 0);
signal delta_red: STD_LOGIC_VECTOR (2 downto 0);
signal delta_green: STD_LOGIC_VECTOR (2 downto 0);
signal green_y: STD_LOGIC_VECTOR (9 downto 0) := "0100000000";
signal green_dy: STD_LOGIC;
signal blue_x: STD_LOGIC_VECTOR (9 downto 0) := "0100000000";
signal blue_y: STD_LOGIC_VECTOR (9 downto 0) := "0100000000";
signal blue_dx: STD_LOGIC;
signal blue_dy: STD_LOGIC;

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

      if horz_scan(3 downto 0) = "0000" then
        if horz_scan(9 downto 0) < 70 then
          delta_red <= start_red(3 downto 1);
        else
          delta_red <= delta_red + 1;
        end if;
      end if;
    end if;
  end process;

  -- vertial clock (increments when the horizontal clock is on the front porch
  process(vinc_flag)
  begin
    if vinc_flag = '1' and vinc_flag'Event then
      if vert_scan = "1000001001" then
        vert_scan <= "0000000000";
        delta_green <= "000";
        start_red <= start_red + 1;

        if green_dy = '1' then
          green_y <= green_y + 1;
          if green_y = 320 then
            green_dy <= '0';
          end if;
        else
          if green_y = 42 then
            green_dy <= '1';
          end if;
          green_y <= green_y - 1;
        end if;

        if blue_dx = '1' then
          blue_x <= blue_x + 1;
          if blue_x >= 700 then
            blue_dx <= '0';
          end if;
        else
          blue_x <= blue_x - 1;
          if blue_x <= 145 then
            blue_dx <= '1';
          end if;
        end if;

        if blue_dy = '1' then
          blue_y <= blue_y + 1;
          if blue_y = 470 then
            blue_dy <= '0';
          end if;
        else
          if blue_y = 42 then
            blue_dy <= '1';
          end if;
          blue_y <= blue_y - 1;
        end if;

      else
        vert_scan <= vert_scan + 1;
        delta_green <= delta_green + 1;
      end if;
    end if;
  end process;

  -- horizontal sync for 96 horizontal clocks (96 pixels)
  hs <= '1' when horz_scan < 96 else '0';
  -- vertial sync for 2 scan lines
  vs <= '1' when vert_scan(9 downto 1) = "000000000" else '0';

  red <= delta_red when vert_scan > 42 and
                    vert_scan < 520 and
                    horz_scan >= 144 and
                    horz_scan < 784
               else "000";

  grn <= delta_green when vert_scan >= green_y and
                    vert_scan < green_y+200 and
                    horz_scan >= 144 and
                    horz_scan < 784
               else "000";

  blu <= vert_scan(1 downto 0) when vert_scan >= blue_y and
                   vert_scan < blue_y+50 and
                   horz_scan >= blue_x and
                   horz_scan < blue_x+50
              else "00";

  vinc_flag <= '1' when horz_scan = "1100011000" else '0';

end Behavioral;


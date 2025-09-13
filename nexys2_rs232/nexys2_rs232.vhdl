
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity nexys2_rs232 is
  Port (btns: in STD_LOGIC_VECTOR(3 downto 0);
        rx: in STD_LOGIC;
        lclk: in STD_LOGIC;
        tx: out STD_LOGIC;
        leds: out STD_LOGIC_VECTOR(7 downto 0));

end nexys2_rs232;

architecture Behavioral of nexys2_rs232 is
signal count_out: STD_LOGIC_VECTOR(12 downto 0);
signal count_in: STD_LOGIC_VECTOR(12 downto 0);
--signal data_out: STD_LOGIC_VECTOR(9 downto 0) := "0100000101";
signal data_out: STD_LOGIC_VECTOR(9 downto 0) := "0000000001";
signal data_in: STD_LOGIC_VECTOR(9 downto 0) := "0000000000";
signal holding: STD_LOGIC_VECTOR(7 downto 0) := "00000000";
signal data_ready: STD_LOGIC := '0';
signal busy_out: STD_LOGIC;
signal key_down: STD_LOGIC_VECTOR(1 downto 0) := "00";
begin
  process(lclk)
  begin
    if lclk = '1' and lclk'Event then

      if btns(0) = '0' then
        key_down <= "00";
      elsif btns(0) = '1' and key_down = "00" then
        key_down <= "01";
      end if;

      if busy_out = '1' then
        if count_out = 5208 then
          for i in 0 to 8 loop
            data_out(i) <= data_out(i+1);
          end loop;
          data_out(9) <= '0';

          count_out <= "0000000000000";
        else
          count_out <= count_out + 1;
        end if;
      else
        if data_ready = '1' then
          data_out(8 downto 1) <= holding;
          data_out(9) <= '1';
          data_out(0) <= '0';
          --data_out <= "0100000101";
          data_ready <= '0';
        elsif key_down = "01" then
          key_down <= "10";
          data_out <= "1010000110";
        end if;

        count_out <= "0000000000000";
      end if;

      if data_in(0) = '1' then
        if count_in = 5208 then
          count_in <= "0000000000000";
          for i in 0 to 8 loop
            data_in(i) <= data_in(i+1);
          end loop;
          data_in(9) <= rx;
          if data_in(1) = '0' then
            data_ready <= '1';
            holding(7 downto 0) <= data_in(9 downto 2);
          end if;
        else
          count_in <= count_in + 1;
        end if;
      elsif rx = '0' then
        count_in <= "1111000000000";
        data_in <= "0111111111";
      end if;
    end if;
  end process;

  leds(0) <= '1' when rx = '0' else '0';
  --leds(0) <= '0';
  leds(1) <= '1' when data_out(0) = '0' else '0';
  leds(2) <= busy_out;
  leds(3) <= data_in(0);
  leds(4) <= btns(0);
  leds(5) <= btns(1);
  leds(6) <= btns(2);
  leds(7) <= btns(3);
  tx <= data_out(0);

  busy_out <= '0' when data_out = "0000000001" else '1';

end Behavioral;


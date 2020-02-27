----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/02/2020 08:41:56 PM
-- Design Name: 
-- Module Name: sev_seg_driver - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sev_seg_driver is Port (in_bin : in std_logic_vector (3 downto 0);
                               an_en : in std_logic_vector (3 downto 0);
                               an : out std_logic_vector (3 downto 0);
                               A,B,C,D,E,F,G : out std_logic);
end sev_seg_driver;

architecture Behavioral of sev_seg_driver is

begin
an <= an_en;
process (in_bin) begin
    case in_bin is
        when "0000" => A<='0';B<='0';C<='0';D<='0';E<='0';F<='0';G<='1';    --0
        when "0001" => A<='1';B<='0';C<='0';D<='1';E<='1';F<='1';G<='1';    --1
        when "0010" => A<='0';B<='0';C<='1';D<='0';E<='0';F<='1';G<='0';    --2
        when "0011" => A<='0';B<='0';C<='0';D<='0';E<='1';F<='1';G<='0';    --3
        when "0100" => A<='1';B<='0';C<='0';D<='1';E<='1';F<='0';G<='0';    --4
        when "0101" => A<='0';B<='1';C<='0';D<='0';E<='1';F<='0';G<='0';    --5
        when "0110" => A<='0';B<='1';C<='0';D<='0';E<='0';F<='0';G<='0';    --6
        when "0111" => A<='0';B<='0';C<='0';D<='1';E<='1';F<='1';G<='0';    --7
        when "1000" => A<='0';B<='0';C<='0';D<='0';E<='0';F<='0';G<='0';    --8
        when "1001" => A<='0';B<='0';C<='0';D<='1';E<='1';F<='0';G<='0';    --9
        when "1010" => A<='0';B<='0';C<='0';D<='1';E<='0';F<='0';G<='0';    --10 A
        when "1011" => A<='1';B<='1';C<='0';D<='0';E<='0';F<='0';G<='0';    --11 B   
        when "1100" => A<='0';B<='1';C<='1';D<='0';E<='0';F<='0';G<='1';    --12 C
        when "1101" => A<='1';B<='0';C<='0';D<='0';E<='0';F<='1';G<='0';    --13 D
        when "1110" => A<='0';B<='1';C<='1';D<='0';E<='0';F<='0';G<='0';    --14 E
        when "1111" => A<='0';B<='1';C<='1';D<='1';E<='0';F<='0';G<='0';    --15 F
        when others => A<='1';B<='1';C<='1';D<='1';E<='1';F<='1';G<='1';    --turn off
    end case;
end process;
end Behavioral;

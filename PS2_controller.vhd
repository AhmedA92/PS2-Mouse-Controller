library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity PS2_controller is Port (rst : in std_logic;
                             clk_100MHz : in std_logic; --10 nanoseconds period
                             PS2_clk : inout std_logic;
                             PS2_data: inout std_logic;
                             --to_sev_seg: out std_logic_vector (3 downto 0)
                             an: out std_logic_vector (3 downto 0);
                             A,B,C,D,E,F,G : out std_logic);
end PS2_controller;

architecture Behavioral of PS2_controller is

--States
constant start : std_logic_vector (3 downto 0) := "0000";
constant reset : std_logic_vector (3 downto 0) := "0001";
constant ACK : std_logic_vector (3 downto 0) := "0010";
constant BAT : std_logic_vector (3 downto 0) := "0011";
constant BAT_err : std_logic_vector (3 downto 0) := "0100";
constant ID_rx : std_logic_vector (3 downto 0) := "0101";
constant data_rep : std_logic_vector (3 downto 0) := "0110";
constant ack_data_rep : std_logic_vector (3 downto 0) := "0111";
constant data_stream : std_logic_vector (3 downto 0) := "1000";
constant resend_data : std_logic_vector (3 downto 0) := "1001";

signal state : std_logic_vector (3 downto 0) := start;

--ILA Component
component ila_0 IS PORT (clk : IN STD_LOGIC;
                         probe0 : IN STD_LOGIC_VECTOR(10 DOWNTO 0); --reset byte
                         probe1 : IN STD_LOGIC_VECTOR(10 DOWNTO 0); --ack byte
                         probe2 : IN STD_LOGIC_VECTOR(10 DOWNTO 0); --BAT byte
                         probe3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);  --State
                         probe4 : IN STD_LOGIC_VECTOR(32 DOWNTO 0));--Stream byte     
END component;

--Seven Segment Driver Component
component sev_seg_driver is Port (in_bin : in std_logic_vector (3 downto 0);
                                  an_en : in std_logic_vector (3 downto 0);
                                  an : out std_logic_vector (3 downto 0);
                                  A,B,C,D,E,F,G : out std_logic);
end component;

-- Make sure the controller is not stuck in any state by not staying in it more than 2ms.
procedure safety_count_procedure (signal act_count: inout integer;
                                  signal state : inout std_logic_vector (3 downto 0)) is 
begin    
    if (act_count < 200000)then
        act_count <= act_count + 1;
    else  
        state <= "0000";        
    end if; 
end procedure;

-- Check for error in the 11 bit packet receieved.
-- Parity bit is the 9th bit.
procedure check_byte_error (signal err_flag : inout std_logic;
                            signal byte : in std_logic_vector(10 downto 0)) is
begin
err_flag <= byte(0) and byte(10) and (byte(1) xor byte(2) xor byte(3) xor byte(4) xor byte(5) xor byte(6) xor byte(7) xor byte(8) xor byte(9)); --if '0'->correct, if '1'-> error.
end procedure;

--general signals
signal timer : integer := 0;
signal PS2_prev_clk : std_logic;
signal init_clk_low : integer := 10000;
signal safety_count : integer := 0;                         --counts for 200us in one state to prevent being stuck at a state.
signal err_flag : std_logic;
signal filter_count : integer := 0;                         --filter intput PS2_data from noise.
signal filter_buffer,filter_data_buffer : std_logic_vector (7 downto 0);       --filter buffer.
signal PS2_clk_filtered,PS2_prev_fclk,PS2_data_filtered : std_logic;

--Host/Device Communication Bytes
signal reset_byte : std_logic_vector(10 downto 0) := "11111111110";         --0xFF
signal ack_byte : std_logic_vector(10 downto 0);                            -- Must be equal to 0xFA;
signal BAT_byte : std_logic_vector(10 downto 0);                            -- Must be equal to 0xAA for Success / Error code 0xFC;
signal ID_byte : std_logic_vector(10 downto 0);                             -- Must be 0x00 for Mouse ID.
signal rep_cmd_byte : std_logic_vector(10 downto 0) := "10111101000";       --0xF4
signal resend_cmd_byte : std_logic_vector(10 downto 0) := "10111111100";    --0xFE

signal cmd_done : std_logic := '0'; 
signal status_data,x_data,y_data : std_logic_vector(10 downto 0);
signal data_stream_bytes : std_logic_vector (32 downto 0); 
signal byte_num : integer:= 1;

--Seven Segment Display Signals
signal clicks_counter : integer := 0;
signal refresh_sig : integer := 0;
signal an_en: std_logic_vector(3 downto 0);
signal bits_to_sev: std_logic_vector(3 downto 0);


begin

Process (clk_100MHz)begin
    if rising_edge(clk_100MHz) then
        
        if filter_count < 8 then
            filter_buffer(filter_count) <= PS2_clk;
            filter_data_buffer(filter_count) <= PS2_data;
            filter_count <= filter_count + 1;
        else   -- check sonsistency in 1 or 0 and ignore anyother case. 
            if (filter_buffer = B"00000000") then 
                PS2_clk_filtered <= '0';
            elsif (filter_buffer = B"11111111") then
                PS2_clk_filtered <= '1';
            end if;        
            if (filter_data_buffer = B"00000000") then 
                PS2_data_filtered <= '0';
            elsif (filter_data_buffer = B"11111111") then
                PS2_data_filtered <= '1';
            end if;        
            filter_count <= 0;    
        end if;
        PS2_prev_fclk <= PS2_clk_filtered;                          
        PS2_prev_clk <= PS2_clk;
        if rst = '1' then
            state <= start;
        else   
            case state is
                ------------------------
                ---START STATE '0'
                ------------------------
                when start => 
                    if timer < init_clk_low-1 then
                        PS2_clk <= '0';
                        PS2_data <= 'Z';
                        timer <= timer + 1;
                        
                    else
                        PS2_clk <= 'Z';
                        PS2_data <= '0';    --start bit
                        timer <= 0;       
                        filter_buffer <= "00000000";     
                        state <= reset;
                        ack_byte <= "00000000000";
                        BAT_byte <= "00000000000";
                        cmd_done <= '0';
                        safety_count <= 0;
                    end if;
                ------------------------
                ---RESET STATE '1'
                ------------------------    
                when reset =>
    
                    if PS2_prev_clk /= PS2_clk then
                        if PS2_prev_clk <= '0' and PS2_clk = '1' then   --Write at rising edge of PS/2 clock
                            if timer < 11 then 
                                PS2_data <= reset_byte(timer);
                                timer <= timer + 1;
                            else
                                timer <= 0;  
                                PS2_data <= 'Z'; 
                                state <= ACK;
                                safety_count <= 0; 
                            end if;  
                        else
                            state <= reset;          
                        end if;  
                    else
                        state <= reset;   
                        safety_count_procedure(safety_count , state); 
                    end if;

                ------------------------
                ---ACK STATE '2'
                ------------------------    
                when ACK =>     --wait for acknowledge signal from device
                    if PS2_prev_clk /= PS2_clk then
                        if PS2_prev_clk <= '1' and PS2_clk = '0' then   --Read at falling edge of PS/2 clock
                            if timer < 33 then 
                                --ack_byte(timer) <= PS2_data;
                                ack_byte <= PS2_data & ack_byte(10 downto 1);
                                timer <= timer + 1;
                            end if;
                            
                            --check the ack byte
                            if timer < 33 then
                                if ack_byte(8 downto 1) = X"FA" then --the 11 bits read 0x3FA
                                    state <= BAT;
                                    timer <= 0;
                                    safety_count <= 0;
                                    ack_byte <= "00000000000";
                                else 
                                    state <= ACK;
                                    --timer <= 0;
                                    --ack_byte <= "00000000000";  
                                end if;     
                            end if;
                            
                            if timer = 33 then 
                                state <= start;
                                timer <= 0;
                            end if;  
                        end if;
                        
                    else --to make sure ACK state not left if the PS2 falling clock didn't come yet.
                        state <= ACK;
                        safety_count_procedure(safety_count , state);
                    end if;
                    
                ---------------------------------
                ---BASIC ASSURANCE TEST STATE '3'
                ---------------------------------    
                when BAT =>
                    if PS2_prev_clk /= PS2_clk then
                        if PS2_prev_clk <= '1' and PS2_clk = '0' then   --Read at falling edge of PS/2 clock
                            if timer < 33 then 
                                --ack_byte(timer) <= PS2_data;
                                BAT_byte <= PS2_data & BAT_byte(10 downto 1);
                                timer <= timer + 1;
                            end if;
                            
                            --check the ack byte
                            if timer < 33 then
                                if BAT_byte(8 downto 1) = X"AA" then --the 11 bits read 0x3FA
                                    state <= ID_rx;
                                    timer <= 0;
                                    safety_count <= 0;
                                elsif BAT_byte(8 downto 1) = X"FC" then --BAT Error
                                    state <= BAT_err;
                                    timer <= 0;      
                                else 
                                    state <= BAT;
                                end if;     
                            end if;
                            
                            if timer = 33 then 
                                state <= start;
                                timer <= 0;
                            end if;
                        end if;
                        
                    else --to make sure BAT state not left if the PS2 falling clock didn't come yet.
                        state <= BAT;
                        safety_count_procedure(safety_count , state);
                    end if;
                    
                ------------------------
                ---BATE ERROR STATE '4'
                ------------------------
                when BAT_err =>
                    state <= start; 
                    
                ------------------------
                ---READ ID STATE '5'
                ------------------------        
                when ID_rx =>
                    state <= ID_rx;   
                    if PS2_prev_clk /= PS2_clk then
                        if PS2_prev_clk <= '1' and PS2_clk = '0' then   --Read at falling edge of PS/2 clock
                            if timer < 33 then 
                                --ack_byte(timer) <= PS2_data;
                                ID_byte <= PS2_data & ID_byte(10 downto 1);
                                timer <= timer + 1;
                            end if;
                            
                            --check the ack byte
                            if timer < 33 then
                                if ID_byte(8 downto 1) = X"00" then -- Means it is a mouse
                                    state <= data_rep;
                                    timer <= 0;
                                    safety_count <= 0;    
                                else 
                                    state <= ID_rx;
                                end if;     
                            end if;
                            
                            if timer = 33 then 
                                state <= start;
                                timer <= 0;
                            end if;
                        end if;
                        
                    else --to make sure BAT state not left if the PS2 falling clock didn't come yet.
                        state <= ID_rx;
                        safety_count_procedure(safety_count , state);
                    end if;
                ---------------------------------------
                ---DATA REPORT CMD STATE '6'
                -- Send command to report movement data 
                ---------------------------------------
                when data_rep =>
                    if cmd_done = '0' then
                    
                        if timer < init_clk_low-1 then
                            PS2_clk <= '0';
                            PS2_data <= 'Z';
                            timer <= timer + 1;
                            state <= data_rep;
                            cmd_done <= '0';
                        else
                            timer <= 0;
                            PS2_clk <= 'Z';
                            PS2_data <= '0';
                            cmd_done <= '1';
                            state <= data_rep;
                        end if;  
                        
                    else      
                        if PS2_prev_clk /= PS2_clk then
                            if PS2_prev_clk <= '0' and PS2_clk = '1' then   --Write at rising edge of PS/2 clock
                                if timer < 11 then 
                                    PS2_data <= rep_cmd_byte(timer);
                                    timer <= timer + 1;
                                else
                                    timer <= 0;  
                                    PS2_data <= 'Z'; 
                                    state <= ack_data_rep;
                                    safety_count <= 0;
                                    cmd_done <= '0'; 
                                end if;  
                            else
                                state <= data_rep;          
                            end if;  
                        else
                            state <= data_rep;    
                            safety_count_procedure(safety_count , state);
                        end if;
                    end if; 
                    
                ---------------------------------------
                ---DATA REPORT ACK CMD STATE '7'    
                --Receive acknowldge for data reporting
                ---------------------------------------
                when ack_data_rep =>
                    if PS2_prev_clk /= PS2_clk then
                        if PS2_prev_clk <= '1' and PS2_clk = '0' then   --Read at falling edge of PS/2 clock
                            if timer < 33 then 
                                ack_byte <= PS2_data & ack_byte(10 downto 1);
                                timer <= timer + 1;
                            end if;
                            
                            --check the ack byte
                            if timer < 33 then
                                if ack_byte(8 downto 1) = X"FA" then --the 11 bits read 0x3FA
                                    state <= data_stream;
                                    timer <= 0;
                                    safety_count <= 0;
                                else 
                                    state <= ack_data_rep;
                                end if;     
                            end if;
                            
                            if timer = 33 then 
                                state <= start;
                                timer <= 0;
                            end if;  
                        end if;
                        
                    else --to make sure ACK state not left if the PS2 falling clock didn't come yet.
                        state <= ack_data_rep;
                        --safety_count_procedure(safety_count , state);
                    end if;
                    
                --------------------------------------------------------------------------
                --DATA STREAM MODE STATE '8'
                --Now the Mouse will send 33 bits of data whenever it is moved or clicked.
                --------------------------------------------------------------------------     
                when data_stream =>
                       
                    if PS2_prev_fclk /= PS2_clk_filtered then
                        if PS2_prev_fclk <= '1' and PS2_clk_filtered = '0' then   --Read at falling edge of PS/2 clock
 
                          if timer < 33 then --33 bits window
                                    data_stream_bytes <= PS2_data_filtered & data_stream_bytes(32 downto 1);
                                    timer <= timer + 1;
                                else
                                    timer <= 0; 
                                    --data_stream_bytes <= "00000000000"; 
                          end if;
                                
                        if timer = 10 then
                            check_byte_error(err_flag,data_stream_bytes(10 downto 0));
                            if err_flag = '0' then  --no error
                                status_data <= data_stream_bytes(10 downto 0);
                                byte_num <= 2;
                                err_flag <= '0';
                            end if;
                        end if;
                        if timer = 21 then
                            check_byte_error(err_flag,data_stream_bytes(21 downto 11));
                            if err_flag = '0' then  --no error
                                x_data <= data_stream_bytes(21 downto 11);
                                byte_num <= 3;
                                err_flag <= '0';
                            end if;
                        end if;
                        if timer = 32 then
                            check_byte_error(err_flag,data_stream_bytes(32 downto 22));
                            if err_flag = '0' then  --no error
                                y_data <= data_stream_bytes(32 downto 22);
                                byte_num <= 1;
                                err_flag <= '0';
                            end if;
                        end if;
                        
                        if timer = 33 then
                            IF clicks_counter < 15 then
                                if status_data(1) = '1' then
                                   clicks_counter <= clicks_counter +1;
                                elsif status_data(2) = '1' then     
                                    clicks_counter <= clicks_counter -1;
                                end if;
                            else
                                clicks_counter <= 0;            
                            end if;
                        end if;
                        
                    end if;        
                 end if;   
                    state <= data_stream;                      
                when others => state <= start;
            end case;
    end if;
    end if;
end process;

Seven_Seg_Refresher : Process (clk_100MHz)begin
    if rising_edge(clk_100MHz) then
        if refresh_sig < init_clk_low - 1 then 
            refresh_sig <= refresh_sig + 1;
        else
            if (an_en = "1110") then --clicks
                bits_to_sev <= std_logic_vector(to_unsigned(clicks_counter,4));
                an_en <= "1101";
            else    
                bits_to_sev <= state;  
                an_en <= "1110";     
            end if; 
            
            refresh_sig <= 0;
        end if;   
    end if;
end Process;    

Seven_Seg_driver: sev_seg_driver port map (in_bin =>bits_to_sev,
                                 an_en => an_en,
                                 an => an,
                                 A=>A,B=>B,C=>C,D=>D,E=>E,F=>F,G=>G);
                                 
debug: ila_0 PORT MAP (clk => clk_100MHz,
                        probe0 => status_data,
                        probe1 => x_data,
                        probe2 => y_data,
                        probe3 => state,
                        probe4 => data_stream_bytes);

end Behavioral;

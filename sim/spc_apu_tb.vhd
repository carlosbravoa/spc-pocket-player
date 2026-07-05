--------------------------------------------------------------------------------
-- Testbench for spc_apu: streams a real .spc file into the loader interface
-- exactly like data_loader would (16-bit LE words, spaced apart), pulses
-- LOAD_DONE, then runs the APU and writes every 32 kHz sample pair to a raw
-- little-endian s16 file ("audio_out.raw") for offline analysis.
--
-- Generics:
--   SPC_FILE   path to the .spc file to play
--   RUN_MS     how many milliseconds of audio to render
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;

entity spc_apu_tb is
	generic(
		SPC_FILE : string := "test_tone.spc";
		RUN_MS   : integer := 100
	);
end spc_apu_tb;

architecture sim of spc_apu_tb is

	constant CLK_PERIOD : time := 46.56 ns;  -- ~21.47727 MHz

	signal CLK         : std_logic := '0';
	signal RESET_N     : std_logic := '0';
	signal LOAD_ACTIVE : std_logic := '0';
	signal LOAD_WR     : std_logic := '0';
	signal LOAD_ADDR   : std_logic_vector(17 downto 0) := (others => '0');
	signal LOAD_DATA   : std_logic_vector(15 downto 0) := (others => '0');
	signal LOAD_DONE   : std_logic := '0';
	signal AUDIO_L     : std_logic_vector(15 downto 0);
	signal AUDIO_R     : std_logic_vector(15 downto 0);
	signal SND_RDY     : std_logic;
	signal PLAYING     : std_logic;

	signal sim_done    : boolean := false;

	type char_file_t is file of character;

begin

	CLK <= not CLK after CLK_PERIOD / 2 when not sim_done else '0';

	dut : entity work.spc_apu
	port map(
		CLK         => CLK,
		RESET_N     => RESET_N,
		LOAD_ACTIVE => LOAD_ACTIVE,
		LOAD_WR     => LOAD_WR,
		LOAD_ADDR   => LOAD_ADDR,
		LOAD_DATA   => LOAD_DATA,
		LOAD_DONE   => LOAD_DONE,
		AUDIO_L     => AUDIO_L,
		AUDIO_R     => AUDIO_R,
		SND_RDY     => SND_RDY,
		PLAYING     => PLAYING
	);

	stim : process
		file f          : char_file_t;
		variable c0, c1 : character;
		variable addr   : integer := 0;
		variable word   : std_logic_vector(15 downto 0);
	begin
		RESET_N <= '0';
		wait for 10 * CLK_PERIOD;
		wait until rising_edge(CLK);
		RESET_N <= '1';
		wait for 10 * CLK_PERIOD;

		report "loading " & SPC_FILE;
		LOAD_ACTIVE <= '1';
		file_open(f, SPC_FILE, read_mode);
		while not endfile(f) loop
			read(f, c0);
			if endfile(f) then
				c1 := character'val(0);
			else
				read(f, c1);
			end if;
			word(7 downto 0)  := std_logic_vector(to_unsigned(character'pos(c0), 8));
			word(15 downto 8) := std_logic_vector(to_unsigned(character'pos(c1), 8));

			wait until rising_edge(CLK);
			LOAD_ADDR <= std_logic_vector(to_unsigned(addr, 18));
			LOAD_DATA <= word;
			LOAD_WR   <= '1';
			wait until rising_edge(CLK);
			LOAD_WR   <= '0';
			-- pace like data_loader (several clocks between words)
			wait until rising_edge(CLK);
			wait until rising_edge(CLK);
			wait until rising_edge(CLK);

			addr := addr + 2;
		end loop;
		file_close(f);
		report "streamed " & integer'image(addr) & " bytes";

		LOAD_ACTIVE <= '0';
		wait until rising_edge(CLK);
		LOAD_DONE <= '1';
		wait until rising_edge(CLK);
		LOAD_DONE <= '0';

		wait until PLAYING = '1';
		report "APU running";

		wait for RUN_MS * 1 ms;
		sim_done <= true;
		report "sim finished";
		wait;
	end process;

	capture : process(CLK)
		file fout      : char_file_t open write_mode is "audio_out.raw";
		variable l, r  : integer;
		variable count : integer := 0;
	begin
		if rising_edge(CLK) then
			if SND_RDY = '1' and PLAYING = '1' then
				write(fout, character'val(to_integer(unsigned(AUDIO_L(7 downto 0)))));
				write(fout, character'val(to_integer(unsigned(AUDIO_L(15 downto 8)))));
				write(fout, character'val(to_integer(unsigned(AUDIO_R(7 downto 0)))));
				write(fout, character'val(to_integer(unsigned(AUDIO_R(15 downto 8)))));
				count := count + 1;
				if (count mod 3200) = 0 then
					report "samples: " & integer'image(count);
				end if;
			end if;
		end if;
	end process;

end sim;

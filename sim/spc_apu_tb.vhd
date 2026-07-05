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
		SPC_FILE  : string := "test_tone.spc";
		RUN_MS    : integer := 100;
		SPC_FILE2 : string := "";        -- if set, hot-reload this file mid-run
		RUN2_MS   : integer := 60
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
	signal TITLE_BITS  : std_logic_vector(511 downto 0);
	signal ADVANCE     : std_logic;
	signal ELAPSED_SEC : std_logic_vector(15 downto 0);
	signal LENGTH_SEC  : std_logic_vector(15 downto 0);
	signal FADE_LEVEL  : std_logic_vector(7 downto 0);
	signal VOICE_ENV   : std_logic_vector(87 downto 0);

	impure function title_str return string is
		variable s : string(1 to 64);
	begin
		for i in 0 to 63 loop
			s(i + 1) := character'val(to_integer(unsigned(TITLE_BITS(i*8+7 downto i*8))));
		end loop;
		return s;
	end function;

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
		PLAYING     => PLAYING,
		TITLE_BITS  => TITLE_BITS,
		ADVANCE     => ADVANCE,
		ELAPSED_SEC => ELAPSED_SEC,
		LENGTH_SEC  => LENGTH_SEC,
		FADE_LEVEL  => FADE_LEVEL,
		VOICE_ENV   => VOICE_ENV
	);

	adv_mon : process(CLK)
		variable last_fade : std_logic_vector(7 downto 0) := x"FF";
	begin
		if rising_edge(CLK) then
			if ADVANCE = '1' then
				report "ADVANCE pulse at " & time'image(now);
			end if;
			if FADE_LEVEL /= last_fade and FADE_LEVEL(5 downto 0) = "000000" then
				report "FADE_LEVEL=" & integer'image(to_integer(unsigned(FADE_LEVEL)))
					& " elapsed=" & integer'image(to_integer(unsigned(ELAPSED_SEC)))
					& " at " & time'image(now);
			end if;
			last_fade := FADE_LEVEL;
		end if;
	end process;

	stim : process
		file f          : char_file_t;
		variable c0, c1 : character;
		variable addr   : integer;
		variable word   : std_logic_vector(15 downto 0);

		procedure stream_file(fname : string) is
		begin
			report "loading " & fname;
			LOAD_ACTIVE <= '1';
			addr := 0;
			file_open(f, fname, read_mode);
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
		end procedure;
	begin
		RESET_N <= '0';
		wait for 10 * CLK_PERIOD;
		wait until rising_edge(CLK);
		RESET_N <= '1';
		wait for 10 * CLK_PERIOD;

		stream_file(SPC_FILE);

		wait until PLAYING = '1';
		report "APU running";
		report "title: [" & title_str & "]";

		wait for 15 ms;
		report "voice env: v0=" & integer'image(to_integer(unsigned(VOICE_ENV(10 downto 0))))
			& " v1=" & integer'image(to_integer(unsigned(VOICE_ENV(21 downto 11))))
			& " v2=" & integer'image(to_integer(unsigned(VOICE_ENV(32 downto 22))));

		wait for RUN_MS * 1 ms;

		if SPC_FILE2'length > 0 then
			report "hot-reloading " & SPC_FILE2;
			stream_file(SPC_FILE2);
			wait until PLAYING = '1';
			report "APU running (2nd file)";
			wait for RUN2_MS * 1 ms;
		end if;

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

--------------------------------------------------------------------------------
-- spc_apu: standalone SNES APU (SPC700 SMP + S-DSP + 64KB ARAM) with an
-- SPC-file loader front end.
--
-- CLK must be 21.47727 MHz (SNES NTSC master clock); the DSP's internal CEGen
-- derives the 4.096 MHz APU enable and 32 kHz sample rate from it.
--
-- The loader consumes the raw .spc file as a stream of 16-bit little-endian
-- words at even byte offsets (as produced by data_loader with
-- OUTPUT_WORD_SIZE=2), routing each region of the file:
--
--   0x00000-0x000FF  header: forwarded as IO writes (SMP latches the SPC700
--                    CPU registers from offsets 0x24/0x26/0x28/0x2A)
--   0x00100-0x100FF  64KB ARAM image: written into BRAM; the $F0-$FF register
--                    page is additionally captured for post-load replay
--   0x10100-0x1017F  DSP registers: forwarded as IO writes at addr-0x10000
--   0x101C0-0x101FF  extra RAM: written to ARAM $FFC0-$FFFF
--
-- After LOAD_DONE the captured $F0-$FF page is replayed as IO writes to
-- 0x2F0-0x2FE (SMP control/timers/aux state and the DSP address latch),
-- then the APU reset is released and the SPC700 starts at the loaded PC.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spc_apu is
	port(
		CLK         : in std_logic;                      -- 21.47727 MHz
		RESET_N     : in std_logic;                      -- external reset (active low)

		LOAD_ACTIVE : in std_logic;                      -- high while a .spc is streaming in
		LOAD_WR     : in std_logic;                      -- 1-cycle strobe per 16-bit word
		LOAD_ADDR   : in std_logic_vector(17 downto 0);  -- raw .spc byte offset (even)
		LOAD_DATA   : in std_logic_vector(15 downto 0);  -- little-endian word
		LOAD_DONE   : in std_logic;                      -- 1-cycle strobe when file complete

		AUDIO_L     : out std_logic_vector(15 downto 0); -- signed PCM, updates at 32 kHz
		AUDIO_R     : out std_logic_vector(15 downto 0);
		SND_RDY     : out std_logic;                     -- 1-cycle strobe per sample
		PLAYING     : out std_logic;

		-- ID666 song title (32 chars) + game title (32 chars) from the header,
		-- sanitized to printable ASCII. Static while PLAYING; byte 0 in bits 7:0.
		TITLE_BITS  : out std_logic_vector(511 downto 0);

		-- auto-advance: .spcpak entries carry the play length (seconds) at
		-- offset 0x10180 with magic 0x4C50 ("PL") at 0x10182. ADVANCE pulses
		-- one CLK when the elapsed time reaches the tagged length.
		ADVANCE     : out std_logic;

		ELAPSED_SEC : out std_logic_vector(15 downto 0);
		LENGTH_SEC  : out std_logic_vector(15 downto 0);  -- 0 when untagged
		VOICE_ENV   : out std_logic_vector(87 downto 0);  -- 8 x 11-bit envelopes
		-- 255 = full volume; ramps to 0 over the last 2 seconds of a
		-- tagged song (fade-out)
		FADE_LEVEL  : out std_logic_vector(7 downto 0)
	);
end spc_apu;

architecture rtl of spc_apu is

	-- APU reset: held low until the load + register-init sequence completes
	signal APU_RST_N   : std_logic;

	-- SMP <-> DSP handshake
	signal SMP_CE      : std_logic;
	signal SMP_EN_R    : std_logic;
	signal SMP_EN_F    : std_logic;
	signal SMP_A       : std_logic_vector(15 downto 0);
	signal SMP_DO      : std_logic_vector(7 downto 0);
	signal SMP_DI      : std_logic_vector(7 downto 0);
	signal SMP_WE      : std_logic;

	-- DSP <-> ARAM
	signal RAM_A       : std_logic_vector(15 downto 0);
	signal RAM_D       : std_logic_vector(7 downto 0);
	signal RAM_Q       : std_logic_vector(7 downto 0);
	signal RAM_CE_N    : std_logic;
	signal RAM_OE_N    : std_logic;
	signal RAM_WE_N    : std_logic;

	-- IO (SPC state load) bus shared by SMP and DSP
	signal IO_ADDR     : std_logic_vector(16 downto 0);
	signal IO_DAT      : std_logic_vector(15 downto 0);
	signal IO_WR       : std_logic;

	signal ARAM_WE     : std_logic;

	-- loader-side ARAM write port
	signal LD_ARAM_A   : std_logic_vector(15 downto 0);
	signal LD_ARAM_D   : std_logic_vector(7 downto 0);
	signal LD_ARAM_WR  : std_logic;

	-- captured $F0-$FF register page (8 little-endian words)
	type PageF0_t is array (0 to 7) of std_logic_vector(15 downto 0);
	signal PAGEF0      : PageF0_t;

	-- captured ID666 titles (header bytes 0x2E-0x6D), 32 LE words
	type Title_t is array (0 to 31) of std_logic_vector(15 downto 0);
	signal TITLE_REG   : Title_t := (others => x"2020");

	-- play-length tag and elapsed-time tracking
	signal LEN_SEC      : unsigned(15 downto 0) := (others => '0');
	signal LEN_VALID    : std_logic := '0';
	signal SND_RDY_I    : std_logic;
	signal AUDIO_L_I    : std_logic_vector(15 downto 0);
	signal AUDIO_R_I    : std_logic_vector(15 downto 0);
	-- end-of-song detection: 4s of continuous silence advances the track
	signal QUIET_CNT    : integer range 0 to 127999 := 0;
	signal SAMP_CNT     : integer range 0 to 31999 := 0;
	signal ELAPSED      : unsigned(15 downto 0) := (others => '0');
	signal FADE_LVL     : unsigned(7 downto 0) := (others => '1');
	signal FADE_CNT     : integer range 0 to 249 := 0;

	function printable(b : std_logic_vector(7 downto 0)) return std_logic_vector is
	begin
		if unsigned(b) < 16#20# or unsigned(b) > 16#7E# then
			return x"20";
		end if;
		return b;
	end function;

	-- loader FSM
	type LoadState_t is (LS_IDLE, LS_ARAM_HI, LS_REGSEQ, LS_ECHO_CLR, LS_START, LS_RUN);
	signal LSTATE      : LoadState_t;
	signal REG_IDX     : unsigned(3 downto 0);
	signal SEQ_CNT     : unsigned(3 downto 0);

	-- echo-region clear: many .spc dumps carry garbage in the echo buffer,
	-- which plays back as a noise burst with an echo tail at song start.
	-- Zero ESA..ESA+len before releasing reset (only when echo writes are
	-- enabled - FLG bit 5 clear - so repurposed RAM is never touched).
	signal ECHO_ESA    : std_logic_vector(7 downto 0);
	signal ECHO_EDL    : unsigned(3 downto 0);
	signal ECHO_WR_OFF : std_logic;
	signal CLR_CNT     : unsigned(14 downto 0);
	signal CLR_LEN     : unsigned(14 downto 0);

	signal ADDR_U      : unsigned(17 downto 0);

begin

	ADDR_U <= unsigned(LOAD_ADDR);

	SMP : entity work.SMP
	port map(
		CLK        => CLK,
		RST_N      => APU_RST_N,
		CE         => SMP_CE,
		EN_R       => SMP_EN_R,
		EN_F       => SMP_EN_F,
		SYSCLKF_CE => '0',

		A          => SMP_A,
		DI         => SMP_DI,
		DO         => SMP_DO,
		WE         => SMP_WE,

		PA         => "00",
		PARD_N     => '1',
		PAWR_N     => '1',
		CPU_DI     => x"00",
		CPU_DO     => open,
		CS         => '0',
		CS_N       => '1',

		SPC_S0     => open,

		IO_ADDR    => IO_ADDR,
		IO_DAT     => IO_DAT,
		IO_WR      => IO_WR,

		SS_ADDR    => x"00",
		SS_WR      => '0',
		SS_DI      => x"00",
		SS_DO      => open
	);

	DSP : entity work.DSP
	port map(
		CLK        => CLK,
		RST_N      => APU_RST_N,
		ENABLE     => '1',
		PAL        => '0',
		FREQ       => '0',

		SMP_EN_F   => SMP_EN_F,
		SMP_EN_R   => SMP_EN_R,
		SMP_A      => SMP_A,
		SMP_DO     => SMP_DO,
		SMP_DI     => SMP_DI,
		SMP_WE     => SMP_WE,
		SMP_CE     => SMP_CE,

		RAM_A      => RAM_A,
		RAM_D      => RAM_D,
		RAM_Q      => RAM_Q,
		RAM_CE_N   => RAM_CE_N,
		RAM_OE_N   => RAM_OE_N,
		RAM_WE_N   => RAM_WE_N,

		LRCK       => open,
		BCK        => open,
		SDAT       => open,

		IO_ADDR    => IO_ADDR,
		IO_DAT     => IO_DAT,
		IO_WR      => IO_WR,

		SS_ADDR    => (others => '0'),
		SS_REGS_SEL=> '0',
		SS_WR      => '0',
		SS_DI      => x"00",
		SS_DO      => open,

		AUDIO_L    => AUDIO_L_I,
		AUDIO_R    => AUDIO_R_I,
		SND_RDY    => SND_RDY_I,
		VOICE_ENV  => VOICE_ENV
	);

	AUDIO_L <= AUDIO_L_I;
	AUDIO_R <= AUDIO_R_I;

	SND_RDY <= SND_RDY_I;

	ELAPSED_SEC <= std_logic_vector(ELAPSED);
	LENGTH_SEC  <= std_logic_vector(LEN_SEC) when LEN_VALID = '1' else (others => '0');
	FADE_LEVEL  <= std_logic_vector(FADE_LVL);

	-- elapsed-time counter, fade-out ramp and auto-advance pulse
	process(CLK, RESET_N)
	begin
		if RESET_N = '0' then
			SAMP_CNT <= 0;
			ELAPSED  <= (others => '0');
			ADVANCE  <= '0';
			FADE_LVL <= (others => '1');
			FADE_CNT <= 0;
		elsif rising_edge(CLK) then
			ADVANCE <= '0';
			if LSTATE /= LS_RUN then
				SAMP_CNT <= 0;
				ELAPSED  <= (others => '0');
				FADE_LVL <= (others => '1');
				FADE_CNT <= 0;
				QUIET_CNT <= 0;
			elsif SND_RDY_I = '1' then
				-- end-of-song: both channels essentially silent for 4s
				if signed(AUDIO_L_I) < 64 and signed(AUDIO_L_I) > -64 and
				   signed(AUDIO_R_I) < 64 and signed(AUDIO_R_I) > -64 then
					if QUIET_CNT = 127999 then
						QUIET_CNT <= 0;
						ADVANCE   <= '1';
					else
						QUIET_CNT <= QUIET_CNT + 1;
					end if;
				else
					QUIET_CNT <= 0;
				end if;

				if SAMP_CNT = 31999 then
					SAMP_CNT <= 0;
					ELAPSED  <= ELAPSED + 1;
					if LEN_VALID = '1' and LEN_SEC /= 0 and ELAPSED + 1 = LEN_SEC then
						ADVANCE <= '1';
					end if;
				else
					SAMP_CNT <= SAMP_CNT + 1;
				end if;

				-- 2s fade: 256 steps x 250 samples = 64000 samples
				if LEN_VALID = '1' and LEN_SEC > 2 and ELAPSED >= LEN_SEC - 2 then
					if FADE_CNT = 249 then
						FADE_CNT <= 0;
						if FADE_LVL /= 0 then
							FADE_LVL <= FADE_LVL - 1;
						end if;
					else
						FADE_CNT <= FADE_CNT + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- 64KB ARAM: port A serves the DSP (which arbitrates SMP accesses),
	-- port B belongs to the loader.
	ARAM_WE <= not RAM_WE_N and not RAM_CE_N;

	ARAM : entity work.dpram generic map(16, 8)
	port map(
		clock     => CLK,
		address_a => RAM_A,
		data_a    => RAM_D,
		wren_a    => ARAM_WE,
		q_a       => RAM_Q,

		address_b => LD_ARAM_A,
		data_b    => LD_ARAM_D,
		wren_b    => LD_ARAM_WR,
		q_b       => open
	);

	PLAYING <= '1' when LSTATE = LS_RUN else '0';

	title_map : for i in 0 to 31 generate
		TITLE_BITS(i*16+15 downto i*16) <= TITLE_REG(i);
	end generate;

	process(CLK, RESET_N)
	begin
		if RESET_N = '0' then
			LSTATE     <= LS_IDLE;
			APU_RST_N  <= '0';
			IO_WR      <= '0';
			IO_ADDR    <= (others => '0');
			IO_DAT     <= (others => '0');
			LD_ARAM_WR <= '0';
			REG_IDX    <= (others => '0');
			SEQ_CNT    <= (others => '0');
		elsif rising_edge(CLK) then
			IO_WR      <= '0';
			LD_ARAM_WR <= '0';

			case LSTATE is
				when LS_IDLE | LS_RUN =>
					if LOAD_ACTIVE = '1' then
						APU_RST_N <= '0';
					end if;

					if LOAD_WR = '1' then
						APU_RST_N <= '0';
						if ADDR_U <= x"000FE" then
							-- .spc header: SMP latches CPU registers at 0x24-0x2A
							IO_ADDR <= LOAD_ADDR(16 downto 0);
							IO_DAT  <= LOAD_DATA;
							IO_WR   <= '1';
							-- ID666 song+game title bytes at 0x2E-0x6D
							if ADDR_U >= x"0002E" and ADDR_U <= x"0006C" then
								TITLE_REG(to_integer(ADDR_U(6 downto 1) - 16#17#)) <=
									printable(LOAD_DATA(15 downto 8)) & printable(LOAD_DATA(7 downto 0));
							end if;
							-- new stream: invalidate the previous length tag
							if ADDR_U = 0 then
								LEN_SEC   <= (others => '0');
								LEN_VALID <= '0';
							end if;
						elsif ADDR_U <= x"100FF" then
							-- 64KB ARAM image (file offset - 0x100), low byte now
							LD_ARAM_A  <= std_logic_vector(resize(ADDR_U - x"100", 16));
							LD_ARAM_D  <= LOAD_DATA(7 downto 0);
							LD_ARAM_WR <= '1';
							LSTATE     <= LS_ARAM_HI;
							-- capture the $F0-$FF register page for replay
							if ADDR_U(17 downto 4) = ("00" & x"01F") then
								PAGEF0(to_integer(ADDR_U(3 downto 1))) <= LOAD_DATA;
							end if;
						elsif ADDR_U >= x"10100" and ADDR_U <= x"1017E" then
							-- DSP register file -> IO 0x100-0x17F
							IO_ADDR <= std_logic_vector(resize(ADDR_U - x"10000", 17));
							IO_DAT  <= LOAD_DATA;
							IO_WR   <= '1';
							-- snoop echo configuration (FLG/ESA at 0x6C/0x6D, EDL at 0x7D)
							if ADDR_U = x"1016C" then
								ECHO_WR_OFF <= LOAD_DATA(5);
								ECHO_ESA    <= LOAD_DATA(15 downto 8);
							elsif ADDR_U = x"1017C" then
								ECHO_EDL <= unsigned(LOAD_DATA(11 downto 8));
							end if;
						elsif ADDR_U = x"10180" then
							-- .spcpak play-length tag (seconds)
							LEN_SEC <= unsigned(LOAD_DATA);
						elsif ADDR_U = x"10182" then
							-- magic "PL" validates the length tag
							if LOAD_DATA = x"4C50" then
								LEN_VALID <= '1';
							else
								LEN_VALID <= '0';
							end if;
						elsif ADDR_U >= x"101C0" and ADDR_U <= x"101FE" then
							-- extra RAM -> ARAM $FFC0-$FFFF, low byte now
							LD_ARAM_A  <= std_logic_vector(resize(ADDR_U - x"101C0" + x"FFC0", 16));
							LD_ARAM_D  <= LOAD_DATA(7 downto 0);
							LD_ARAM_WR <= '1';
							LSTATE     <= LS_ARAM_HI;
						end if;
					elsif LOAD_DONE = '1' then
						REG_IDX <= (others => '0');
						SEQ_CNT <= (others => '0');
						LSTATE  <= LS_REGSEQ;
					end if;

				when LS_ARAM_HI =>
					-- high byte of the word on the following cycle
					LD_ARAM_A  <= std_logic_vector(unsigned(LD_ARAM_A) + 1);
					LD_ARAM_D  <= LOAD_DATA(15 downto 8);
					LD_ARAM_WR <= '1';
					if LOAD_DONE = '1' then
						REG_IDX <= (others => '0');
						SEQ_CNT <= (others => '0');
						LSTATE  <= LS_REGSEQ;
					else
						LSTATE <= LS_IDLE;
					end if;

				when LS_REGSEQ =>
					-- replay ARAM $F0-$FF page into IO 0x2F0-0x2FE, one word
					-- every 8 cycles (the DSP register path needs 2 cycles of
					-- stable IO_ADDR/IO_DAT after each strobe)
					SEQ_CNT <= SEQ_CNT + 1;
					if SEQ_CNT = 0 then
						IO_ADDR <= std_logic_vector(to_unsigned(16#2F0#, 17) + (resize(REG_IDX, 17) sll 1));
						IO_DAT  <= PAGEF0(to_integer(REG_IDX(2 downto 0)));
						IO_WR   <= '1';
					elsif SEQ_CNT = 7 then
						if REG_IDX = 7 then
							SEQ_CNT <= (others => '0');
							CLR_CNT <= (others => '0');
							if ECHO_EDL = 0 then
								CLR_LEN <= to_unsigned(4, 15);
							else
								CLR_LEN <= resize(ECHO_EDL, 15) sll 11;  -- EDL*2048
							end if;
							if ECHO_WR_OFF = '1' then
								LSTATE <= LS_START;
							else
								LSTATE <= LS_ECHO_CLR;
							end if;
						else
							REG_IDX <= REG_IDX + 1;
						end if;
					end if;

				when LS_ECHO_CLR =>
					-- zero the echo buffer (1 byte per clock, max 30KB = 1.4ms)
					LD_ARAM_A  <= std_logic_vector((resize(unsigned(ECHO_ESA), 16) sll 8) + resize(CLR_CNT, 16));
					LD_ARAM_D  <= x"00";
					LD_ARAM_WR <= '1';
					CLR_CNT <= CLR_CNT + 1;
					if CLR_CNT = CLR_LEN - 1 then
						LSTATE <= LS_START;
					end if;

				when LS_START =>
					-- a few idle cycles with IO_WR low so REG_SET can settle,
					-- then release the APU
					SEQ_CNT <= SEQ_CNT + 1;
					if SEQ_CNT = 15 then
						APU_RST_N <= '1';
						LSTATE    <= LS_RUN;
					end if;
			end case;
		end if;
	end process;

end rtl;

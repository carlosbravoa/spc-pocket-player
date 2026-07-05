//
// User core top-level: SPC Player
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable,

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,

///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,

output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
//
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
//   [31:28] type
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [31:0]  cont1_key,
input   wire    [31:0]  cont2_key,
input   wire    [31:0]  cont3_key,
input   wire    [31:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig

);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3 = 8'hzz;
assign cart_tran_bank3_dir = 1'b0;
assign cart_tran_bank2 = 8'hzz;
assign cart_tran_bank2_dir = 1'b0;
assign cart_tran_bank1 = 8'hzz;
assign cart_tran_bank1_dir = 1'b0;
assign cart_tran_bank0 = 4'hf;
assign cart_tran_bank0_dir = 1'b1;
assign cart_tran_pin30 = 1'b0;      // reset or cs2, we let the hw control it by itself
assign cart_tran_pin30_dir = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
assign cart_tran_pin31 = 1'bz;      // input
assign cart_tran_pin31_dir = 1'b0;  // input

// link port is unused, set to input only to be safe
// each bit may be bidirectional in some applications
assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;     // SO is output only
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;     // SI is input only
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a = 'h0;
assign cram0_dq = {16{1'bZ}};
assign cram0_clk = 0;
assign cram0_adv_n = 1;
assign cram0_cre = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n = 1;
assign cram0_we_n = 1;
assign cram0_ub_n = 1;
assign cram0_lb_n = 1;

assign cram1_a = 'h0;
assign cram1_dq = {16{1'bZ}};
assign cram1_clk = 0;
assign cram1_adv_n = 1;
assign cram1_cre = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n = 1;
assign cram1_we_n = 1;
assign cram1_ub_n = 1;
assign cram1_lb_n = 1;

assign dram_a = 'h0;
assign dram_ba = 'h0;
assign dram_dq = {16{1'bZ}};
assign dram_dqm = 'h0;
assign dram_clk = 'h0;
assign dram_cke = 'h0;
assign dram_ras_n = 'h1;
assign dram_cas_n = 'h1;
assign dram_we_n = 'h1;

assign sram_a = 'h0;
assign sram_dq = {16{1'bZ}};
assign sram_oe_n  = 1;
assign sram_we_n  = 1;
assign sram_ub_n  = 1;
assign sram_lb_n  = 1;

assign dbg_tx = 1'bZ;
assign user1 = 1'bZ;
assign aux_scl = 1'bZ;
assign vpll_feed = 1'bZ;


// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always @(*) begin
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end


//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;

// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked_s;
    wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire    [31:0]  dataslot_requestwrite_size;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_update;
    wire    [15:0]  dataslot_update_id;
    wire    [31:0]  dataslot_update_size;

    wire            dataslot_allcomplete;

    wire     [31:0] rtc_epoch_seconds;
    wire     [31:0] rtc_date_bcd;
    wire     [31:0] rtc_time_bcd;
    wire            rtc_valid;

    wire            savestate_supported = 0;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;

    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

    reg             target_dataslot_read = 0;
    reg             target_dataslot_write = 0;
    reg             target_dataslot_getfile = 0;    // require additional param/resp structs to be mapped
    reg             target_dataslot_openfile = 0;   // require additional param/resp structs to be mapped

    wire            target_dataslot_ack;
    wire            target_dataslot_done;
    wire    [2:0]   target_dataslot_err;

    reg     [15:0]  target_dataslot_id;
    reg     [31:0]  target_dataslot_slotoffset;
    reg     [31:0]  target_dataslot_bridgeaddr;
    reg     [31:0]  target_dataslot_length;

    wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands

// bridge data slot access
// synchronous to clk_74a

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;

core_bridge_cmd icb (

    .clk                ( clk_74a ),
    .reset_n            ( reset_n ),

    .bridge_endian_little   ( bridge_endian_little ),
    .bridge_addr            ( bridge_addr ),
    .bridge_rd              ( bridge_rd ),
    .bridge_rd_data         ( cmd_bridge_rd_data ),
    .bridge_wr              ( bridge_wr ),
    .bridge_wr_data         ( bridge_wr_data ),

    .status_boot_done       ( status_boot_done ),
    .status_setup_done      ( status_setup_done ),
    .status_running         ( status_running ),

    .dataslot_requestread       ( dataslot_requestread ),
    .dataslot_requestread_id    ( dataslot_requestread_id ),
    .dataslot_requestread_ack   ( dataslot_requestread_ack ),
    .dataslot_requestread_ok    ( dataslot_requestread_ok ),

    .dataslot_requestwrite      ( dataslot_requestwrite ),
    .dataslot_requestwrite_id   ( dataslot_requestwrite_id ),
    .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
    .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack ),
    .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok ),

    .dataslot_update            ( dataslot_update ),
    .dataslot_update_id         ( dataslot_update_id ),
    .dataslot_update_size       ( dataslot_update_size ),

    .dataslot_allcomplete   ( dataslot_allcomplete ),

    .rtc_epoch_seconds      ( rtc_epoch_seconds ),
    .rtc_date_bcd           ( rtc_date_bcd ),
    .rtc_time_bcd           ( rtc_time_bcd ),
    .rtc_valid              ( rtc_valid ),

    .savestate_supported    ( savestate_supported ),
    .savestate_addr         ( savestate_addr ),
    .savestate_size         ( savestate_size ),
    .savestate_maxloadsize  ( savestate_maxloadsize ),

    .savestate_start        ( savestate_start ),
    .savestate_start_ack    ( savestate_start_ack ),
    .savestate_start_busy   ( savestate_start_busy ),
    .savestate_start_ok     ( savestate_start_ok ),
    .savestate_start_err    ( savestate_start_err ),

    .savestate_load         ( savestate_load ),
    .savestate_load_ack     ( savestate_load_ack ),
    .savestate_load_busy    ( savestate_load_busy ),
    .savestate_load_ok      ( savestate_load_ok ),
    .savestate_load_err     ( savestate_load_err ),

    .osnotify_inmenu        ( osnotify_inmenu ),

    .target_dataslot_read       ( target_dataslot_read ),
    .target_dataslot_write      ( target_dataslot_write ),
    .target_dataslot_getfile    ( target_dataslot_getfile ),
    .target_dataslot_openfile   ( target_dataslot_openfile ),

    .target_dataslot_ack        ( target_dataslot_ack ),
    .target_dataslot_done       ( target_dataslot_done ),
    .target_dataslot_err        ( target_dataslot_err ),

    .target_dataslot_id         ( target_dataslot_id ),
    .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
    .target_dataslot_length     ( target_dataslot_length ),

    .target_buffer_param_struct ( target_buffer_param_struct ),
    .target_buffer_resp_struct  ( target_buffer_resp_struct ),

    .datatable_addr         ( datatable_addr ),
    .datatable_wren         ( datatable_wren ),
    .datatable_data         ( datatable_data ),
    .datatable_q            ( datatable_q )

);



////////////////////////////////////////////////////////////////////////////////////////
// Track controller (clk_74a domain)
//
// The data slot (id 0) is marked deferload, so APF never streams it by
// itself. This FSM reads the slot size from the data table, computes the
// number of 0x10200-byte songs in the file (.spcpak = concatenated
// normalized SPCs; a plain .spc is a 1-song pack), and issues
// target_dataslot_read commands to pull one song at a time to bridge
// address 0x10000000 - which flows through data_loader into the APU.
//
// Controls: dpad right = next, dpad left = prev, A = restart.

    localparam SONG_BYTES = 32'h10200;

    wire    [31:0]  cont1_key_s74;
synch_3 #(.WIDTH(32)) s_cont(cont1_key, cont1_key_s74, clk_74a);

    reg     [31:0]  cont1_key_prev = 0;
    wire            btn_next    = cont1_key_s74[3] & ~cont1_key_prev[3];
    wire            btn_prev    = cont1_key_s74[2] & ~cont1_key_prev[2];
    wire            btn_restart = cont1_key_s74[4] & ~cont1_key_prev[4];
    wire            btn_shuffle = cont1_key_s74[7] & ~cont1_key_prev[7];   // Y

    reg             shuffle_en = 0;
    reg     [15:0]  lfsr = 16'hACE1;
    reg             pending_random = 0;
    reg     [15:0]  rand_rem;

    reg             allcomplete_1 = 0;
    reg             reset_n_1 = 0;

    reg     [31:0]  pak_size = 0;
    reg     [31:0]  count_rem;
    reg     [9:0]   song_count = 0;
    reg     [9:0]   song_index = 0;
    reg     [9:0]   issue_index;
    reg             have_pak = 0;       // slot size known
    reg             track_loading = 0;

    reg             pending_load = 0;
    reg             pending_recount = 0;
    reg     [9:0]   pending_index = 0;

    reg     [3:0]   tkstate = 0;
    localparam TK_IDLE     = 0;
    localparam TK_SIZE0    = 1;
    localparam TK_SIZE1    = 2;
    localparam TK_SIZE1B   = 8;
    localparam TK_SIZE2    = 3;
    localparam TK_COUNT    = 4;
    localparam TK_ISSUE    = 5;
    localparam TK_ACK      = 6;
    localparam TK_WAIT     = 7;
    localparam TK_RETRY    = 9;
    localparam TK_RAND     = 10;

    // retry management: heals boot-time races where the data table is not
    // yet populated, and read errors (with a shorter fallback length that
    // avoids reading up to the exact end-of-file)
    reg     [23:0]  retry_timer = 0;
    reg     [3:0]   retry_cnt = 0;
    reg             short_read = 0;     // fallback: skip the extra-RAM tail
    reg             load_error = 0;     // sticky: retries exhausted

    reg     [9:0]   datatable_addr_r = 0;
assign datatable_addr = datatable_addr_r;
assign datatable_wren = 0;
assign datatable_data = 0;

    wire    [31:0]  song_offset = ({22'd0, issue_index} << 16) + ({22'd0, issue_index} << 9);

always @(posedge clk_74a) begin
    cont1_key_prev <= cont1_key_s74;
    allcomplete_1  <= dataslot_allcomplete;
    reset_n_1      <= reset_n;

    lfsr <= lfsr[0] ? (lfsr >> 1) ^ 16'hB400 : lfsr >> 1;
    if (btn_shuffle)
        shuffle_en <= ~shuffle_en;

    case (tkstate)
        TK_IDLE: begin
            if (pending_load) begin
                pending_load <= 0;
                issue_index  <= pending_index;
                if (pending_recount) begin
                    pending_recount <= 0;
                    pending_random  <= 0;
                    tkstate <= TK_SIZE0;
                end else if (pending_random) begin
                    pending_random <= 0;
                    rand_rem <= lfsr;
                    tkstate <= TK_RAND;
                end else begin
                    tkstate <= TK_ISSUE;
                end
            end
        end

        TK_RAND: begin
            // rand_rem mod song_count by repeated subtraction, then avoid
            // repeating the current song
            if (rand_rem >= {6'd0, song_count}) begin
                rand_rem <= rand_rem - {6'd0, song_count};
            end else begin
                if (rand_rem[9:0] == song_index)
                    issue_index <= (rand_rem[9:0] + 1'b1 == song_count) ? 10'd0
                                                                        : rand_rem[9:0] + 1'b1;
                else
                    issue_index <= rand_rem[9:0];
                tkstate <= TK_ISSUE;
            end
        end

        // read slot 0 size from the data table (slot index 0 -> word 1)
        TK_SIZE0: begin
            datatable_addr_r <= 10'd1;
            tkstate <= TK_SIZE1;
        end
        TK_SIZE1: tkstate <= TK_SIZE1B;     // datatable BRAM: registered address
        TK_SIZE1B: tkstate <= TK_SIZE2;     // ... and registered output (2-cycle)
        TK_SIZE2: begin
            pak_size  <= datatable_q;
            count_rem <= datatable_q;
            song_count <= 0;
            tkstate <= TK_COUNT;
        end
        TK_COUNT: begin
            if (count_rem >= SONG_BYTES && song_count != 10'h3FF) begin
                count_rem  <= count_rem - SONG_BYTES;
                song_count <= song_count + 1'b1;
            end else begin
                // a trailing 0x10180-byte SPC (no extra-RAM section) counts
                if (count_rem >= 32'h10180)
                    song_count <= song_count + 1'b1;
                have_pak <= 1;
                tkstate  <= TK_ISSUE;
            end
        end

        TK_ISSUE: begin
            if (song_count == 0) begin
                // data table not populated yet (boot race) - retry
                retry_timer <= 0;
                tkstate <= TK_RETRY;
            end else begin
                song_index <= issue_index;
                target_dataslot_id         <= 16'h0;
                target_dataslot_slotoffset <= song_offset;
                target_dataslot_bridgeaddr <= 32'h10000000;
                // for the last (or only) track, request 0xFFFFFFFF: APF caps
                // the read at end-of-file, sidestepping any exact-EOF edge
                target_dataslot_length     <=
                    short_read ? 32'h10180
                    : (pak_size - song_offset > SONG_BYTES) ? SONG_BYTES
                                                            : 32'hFFFFFFFF;
                target_dataslot_read <= 1;
                track_loading <= 1;
                tkstate <= TK_ACK;
            end
        end
        TK_ACK: begin
            if (target_dataslot_ack) begin
                target_dataslot_read <= 0;
                tkstate <= TK_WAIT;
            end
        end
        TK_WAIT: begin
            if (target_dataslot_done) begin
                track_loading <= 0;
                if (target_dataslot_err != 0) begin
                    short_read <= 1;        // next attempt avoids the EOF edge
                    retry_timer <= 0;
                    tkstate <= TK_RETRY;
                end else begin
                    retry_cnt  <= 0;
                    load_error <= 0;
                    tkstate <= TK_IDLE;
                end
            end
        end

        TK_RETRY: begin
            // wait ~220ms, then re-run the whole flow (size + count + load)
            retry_timer <= retry_timer + 1'b1;
            if (&retry_timer) begin
                if (retry_cnt == 4'd10) begin
                    load_error <= 1;        // give up until the user acts
                    tkstate <= TK_IDLE;
                end else begin
                    retry_cnt <= retry_cnt + 1'b1;
                    pending_load    <= 1;
                    pending_recount <= 1;
                    pending_index   <= issue_index;
                    tkstate <= TK_IDLE;
                end
            end
        end

        default: tkstate <= TK_IDLE;
    endcase

    // triggers: initial load (allcomplete or reset exit), file change,
    // buttons, auto-advance. placed after the FSM case so a trigger arriving
    // in the same cycle TK_IDLE consumes the previous request is not lost
    // (last write wins)
    adv_toggle_1 <= adv_toggle_s;
    if ((dataslot_allcomplete & ~allcomplete_1) ||
        (reset_n & ~reset_n_1) ||
        (dataslot_update && dataslot_update_id == 16'h0)) begin
        pending_load    <= 1;
        pending_recount <= 1;
        pending_random  <= 0;
        pending_index   <= 0;
        retry_cnt       <= 0;
        load_error      <= 0;
        short_read      <= 0;
    end else if (have_pak && song_count != 0) begin
        if (btn_next || (adv_toggle_s ^ adv_toggle_1)) begin
            pending_load  <= 1;
            pending_random <= shuffle_en && song_count > 1;
            pending_index <= (song_index + 1'b1 == song_count) ? 10'd0 : song_index + 1'b1;
            retry_cnt     <= 0;
            load_error    <= 0;
        end else if (btn_prev) begin
            pending_load  <= 1;
            pending_random <= 0;
            pending_index <= (song_index == 0) ? song_count - 1'b1 : song_index - 1'b1;
            retry_cnt     <= 0;
            load_error    <= 0;
        end else if (btn_restart) begin
            pending_load  <= 1;
            pending_random <= 0;
            pending_index <= song_index;
            retry_cnt     <= 0;
            load_error    <= 0;
        end
    end
end

    wire            adv_toggle_s;
    reg             adv_toggle_1 = 0;
synch_3 s_adv(apu_adv_toggle, adv_toggle_s, clk_74a);

    // 0 = waiting for file (red), 1 = loading (orange), 2 = error (magenta)
    wire    [1:0]   load_status = load_error ? 2'd2 : track_loading ? 2'd1 : 2'd0;

    wire    spc_downloading_s;
synch_3 s_dl(track_loading, spc_downloading_s, clk_sys_21_48);

    reg     spc_downloading_s1 = 0;
    reg     spc_load_done = 0;
always @(posedge clk_sys_21_48) begin
    spc_downloading_s1 <= spc_downloading_s;
    spc_load_done <= spc_downloading_s1 & ~spc_downloading_s;   // falling edge
end

    // NOTE: the APU is deliberately NOT reset by reset_n. APF streams the
    // data slot while the core is still held in reset, so the loader and APU
    // only depend on the PLL being locked; playback start is sequenced by
    // LOAD_DONE inside spc_apu.
    wire            pll_locked_sys;
synch_3 s_rst(pll_core_locked, pll_locked_sys, clk_sys_21_48);

    wire            inmenu_s;
synch_3 s_menu(osnotify_inmenu, inmenu_s, clk_sys_21_48);

////////////////////////////////////////////////////////////////////////////////////////
// SPC file loader: bridge writes at 0x1xxxxxxx -> 16-bit LE words in sys domain

    wire            loader_wr;
    wire    [17:0]  loader_addr;
    wire    [15:0]  loader_data;

data_loader #(
    .ADDRESS_MASK_UPPER_4       ( 4'h1 ),
    .ADDRESS_SIZE               ( 18 ),
    .WRITE_MEM_CLOCK_DELAY      ( 4 ),
    .OUTPUT_WORD_SIZE           ( 2 )
) spc_loader (
    .clk_74a                ( clk_74a ),
    .clk_memory             ( clk_sys_21_48 ),

    .bridge_wr              ( bridge_wr ),
    .bridge_endian_little   ( bridge_endian_little ),
    .bridge_addr            ( bridge_addr ),
    .bridge_wr_data         ( bridge_wr_data ),

    .write_en               ( loader_wr ),
    .write_addr             ( loader_addr ),
    .write_data             ( loader_data )
);

////////////////////////////////////////////////////////////////////////////////////////
// The APU itself

    wire    [15:0]  apu_audio_l;
    wire    [15:0]  apu_audio_r;
    wire            apu_snd_rdy;
    wire            apu_playing;
    wire    [511:0] apu_title_bits;
    wire            apu_advance;
    wire    [15:0]  apu_elapsed;
    wire    [15:0]  apu_length;
    wire    [7:0]   apu_fade;

spc_apu apu (
    .CLK            ( clk_sys_21_48 ),
    .RESET_N        ( pll_locked_sys ),

    .LOAD_ACTIVE    ( spc_downloading_s ),
    .LOAD_WR        ( loader_wr ),
    .LOAD_ADDR      ( loader_addr ),
    .LOAD_DATA      ( loader_data ),
    .LOAD_DONE      ( spc_load_done ),

    .AUDIO_L        ( apu_audio_l ),
    .AUDIO_R        ( apu_audio_r ),
    .SND_RDY        ( apu_snd_rdy ),
    .PLAYING        ( apu_playing ),
    .TITLE_BITS     ( apu_title_bits ),
    .ADVANCE        ( apu_advance ),
    .ELAPSED_SEC    ( apu_elapsed ),
    .LENGTH_SEC     ( apu_length ),
    .FADE_LEVEL     ( apu_fade )
);

// auto-advance pulse -> toggle for safe crossing into clk_74a
    reg     apu_adv_toggle = 0;
always @(posedge clk_sys_21_48) begin
    if (apu_advance)
        apu_adv_toggle <= ~apu_adv_toggle;
end

// mute while the Pocket menu is open, while a track is loading, and for
// ~20ms after playback starts (the DSP pipelines settle with stale state
// right after reset release, which is audible otherwise)
    reg     [9:0]   unmute_cnt = 0;
always @(posedge clk_sys_21_48) begin
    if (!apu_playing)
        unmute_cnt <= 0;
    else if (apu_snd_rdy && unmute_cnt != 10'd640)
        unmute_cnt <= unmute_cnt + 1'b1;
end

    wire audio_muted = inmenu_s | ~apu_playing | (unmute_cnt != 10'd640);

// fade-out: scale by the APU's fade level (255 = unity)
    wire signed [24:0] fade_mul_l = $signed(apu_audio_l) * $signed({1'b0, apu_fade});
    wire signed [24:0] fade_mul_r = $signed(apu_audio_r) * $signed({1'b0, apu_fade});
    wire signed [15:0] audio_l_out = audio_muted ? 16'sd0 : fade_mul_l[23:8];
    wire signed [15:0] audio_r_out = audio_muted ? 16'sd0 : fade_mul_r[23:8];

////////////////////////////////////////////////////////////////////////////////////////
// VU levels for the visualization (sys domain, sampled by video domain)
//
// Peak detector with exponential decay (~8ms time constant at 32kHz).

    reg     [14:0]  vu_level_l = 0;
    reg     [14:0]  vu_level_r = 0;

    wire    [14:0]  abs_l = audio_l_out[15] ? (~audio_l_out[14:0] + 1'b1) : audio_l_out[14:0];
    wire    [14:0]  abs_r = audio_r_out[15] ? (~audio_r_out[14:0] + 1'b1) : audio_r_out[14:0];

always @(posedge clk_sys_21_48) begin
    if (apu_snd_rdy) begin
        vu_level_l <= (abs_l > vu_level_l) ? abs_l : vu_level_l - (vu_level_l >> 8);
        vu_level_r <= (abs_r > vu_level_r) ? abs_r : vu_level_r - (vu_level_r >> 8);
    end
end

////////////////////////////////////////////////////////////////////////////////////////
// video generation: 512x240 active raster at 10.738635 MHz dot clock
// 682 x 262 total -> 60.09 Hz (SNES-like timing)

assign video_rgb_clock = clk_video_10_74;
assign video_rgb_clock_90 = clk_video_10_74_90deg;
assign video_rgb = vidout_rgb;
assign video_de = vidout_de;
assign video_skip = 1'b0;
assign video_vs = vidout_vs;
assign video_hs = vidout_hs;

    localparam  VID_V_BPORCH = 'd10;
    localparam  VID_V_ACTIVE = 'd240;
    localparam  VID_V_TOTAL  = 'd262;
    localparam  VID_H_BPORCH = 'd120;
    localparam  VID_H_ACTIVE = 'd512;
    localparam  VID_H_TOTAL  = 'd682;

    reg [9:0]   x_count;
    reg [8:0]   y_count;

    wire [9:0]  visible_x = x_count - VID_H_BPORCH;
    wire [8:0]  visible_y = y_count - VID_V_BPORCH;

    reg [23:0]  vidout_rgb;
    reg         vidout_de;
    reg         vidout_vs;
    reg         vidout_hs;

    // levels resampled into the video domain once per frame (quasi-static)
    reg [14:0]  vu_l_vid, vu_r_vid;
    reg         playing_vid;
    reg [511:0] title_vid;
    reg [9:0]   idx_vid, cnt_vid;
    reg [1:0]   status_vid;
    reg [15:0]  elapsed_vid, length_vid;
    reg         shuffle_vid;

    reg [23:0]  border_rgb;
always @(*) begin
    case (status_vid)
        2'd1:    border_rgb = 24'hC08020;   // loading: orange
        2'd2:    border_rgb = 24'hC030C0;   // read error: magenta
        default: border_rgb = 24'h802020;   // waiting for a file: red
    endcase
end

    // bar lengths in pixels (0-511): use upper bits of the 15-bit level
    wire [8:0]  bar_l = vu_l_vid[14:6];
    wire [8:0]  bar_r = vu_r_vid[14:6];

    //
    // text overlay: 32 chars x 16px cells (8x8 font at 2x)
    //   y 32-47:  track counter "NNN/MMM"
    //   y 64-79:  song title
    //   y 96-111: game title
    //
    wire        line_track = (visible_y[8:4] == 'd2);
    wire        line_title = (visible_y[8:4] == 'd4);
    wire        line_game  = (visible_y[8:4] == 'd6);
    wire        any_text_line = line_track | line_title | line_game;

    // track counter digits (from once-per-frame latched values)
    wire [9:0]  disp_n = idx_vid + 1'b1;
    wire [3:0]  n_d2 = disp_n / 'd100;
    wire [3:0]  n_d1 = (disp_n / 'd10) % 'd10;
    wire [3:0]  n_d0 = disp_n % 'd10;
    wire [3:0]  c_d2 = cnt_vid / 'd100;
    wire [3:0]  c_d1 = (cnt_vid / 'd10) % 'd10;
    wire [3:0]  c_d0 = cnt_vid % 'd10;

    // elapsed / total time, capped at 99:59
    wire [15:0] el_cap = (elapsed_vid > 16'd5999) ? 16'd5999 : elapsed_vid;
    wire [15:0] ln_cap = (length_vid > 16'd5999) ? 16'd5999 : length_vid;
    wire [6:0]  el_m = el_cap / 'd60;
    wire [5:0]  el_s = el_cap % 'd60;
    wire [6:0]  ln_m = ln_cap / 'd60;
    wire [5:0]  ln_s = ln_cap % 'd60;
    wire        has_len = (length_vid != 0);
    wire [3:0]  el_m_t = el_m / 'd10;
    wire [3:0]  el_m_o = el_m % 'd10;
    wire [3:0]  el_s_t = el_s / 'd10;
    wire [3:0]  el_s_o = el_s % 'd10;
    wire [3:0]  ln_m_t = ln_m / 'd10;
    wire [3:0]  ln_m_o = ln_m % 'd10;
    wire [3:0]  ln_s_t = ln_s / 'd10;
    wire [3:0]  ln_s_o = ln_s % 'd10;

    // font lookup is registered, so address it with a 1-pixel lookahead;
    // the whole text layer lands shifted 1px left, uniformly (invisible)
    wire [9:0]  la_vx = x_count + 1'b1 - VID_H_BPORCH;
    wire [4:0]  la_ci = la_vx[8:4];         // character cell 0-31

    reg  [7:0]  track_ch;
always @(*) begin
    case (la_ci)
        5'd1:    track_ch = (n_d2 == 0) ? 8'h20 : {4'h3, n_d2};
        5'd2:    track_ch = (n_d2 == 0 && n_d1 == 0) ? 8'h20 : {4'h3, n_d1};
        5'd3:    track_ch = {4'h3, n_d0};
        5'd4:    track_ch = 8'h2F;          // '/'
        5'd5:    track_ch = (c_d2 == 0) ? 8'h20 : {4'h3, c_d2};
        5'd6:    track_ch = (c_d2 == 0 && c_d1 == 0) ? 8'h20 : {4'h3, c_d1};
        5'd7:    track_ch = {4'h3, c_d0};
        5'd10:   track_ch = shuffle_vid ? 8'h53 : 8'h20;    // 'S'
        // elapsed MM:SS / total MM:SS, right side
        5'd20:   track_ch = {4'h3, el_m_t};
        5'd21:   track_ch = {4'h3, el_m_o};
        5'd22:   track_ch = 8'h3A;          // ':'
        5'd23:   track_ch = {4'h3, el_s_t};
        5'd24:   track_ch = {4'h3, el_s_o};
        5'd25:   track_ch = has_len ? 8'h2F : 8'h20;
        5'd26:   track_ch = has_len ? {4'h3, ln_m_t} : 8'h20;
        5'd27:   track_ch = has_len ? {4'h3, ln_m_o} : 8'h20;
        5'd28:   track_ch = has_len ? 8'h3A : 8'h20;
        5'd29:   track_ch = has_len ? {4'h3, ln_s_t} : 8'h20;
        5'd30:   track_ch = has_len ? {4'h3, ln_s_o} : 8'h20;
        default: track_ch = 8'h20;
    endcase
end

    wire [7:0]  font_ch = line_title ? title_vid[{4'd0, la_ci, 3'd0} +: 8]
                        : line_game  ? title_vid[{4'd1, la_ci, 3'd0} +: 8]
                        : track_ch;

    wire [7:0]  font_bits;
    reg  [2:0]  font_col_r;

font_rom fnt (
    .clk    ( clk_video_10_74 ),
    .char   ( font_ch[6:0] ),
    .row    ( visible_y[3:1] ),
    .bits   ( font_bits )
);

    wire        text_px = font_bits[font_col_r];

always @(posedge clk_video_10_74 or negedge reset_n) begin

    if(~reset_n) begin

        x_count <= 0;
        y_count <= 0;

    end else begin
        vidout_de <= 0;
        vidout_vs <= 0;
        vidout_hs <= 0;

        font_col_r <= la_vx[3:1];

        // x and y counters
        x_count <= x_count + 1'b1;
        if(x_count == VID_H_TOTAL-1) begin
            x_count <= 0;

            y_count <= y_count + 1'b1;
            if(y_count == VID_V_TOTAL-1) begin
                y_count <= 0;
            end
        end

        // generate sync
        if(x_count == 0 && y_count == 0) begin
            vidout_vs <= 1;
            // latch the (asynchronous) status once per frame, during blank
            vu_l_vid <= vu_level_l;
            vu_r_vid <= vu_level_r;
            playing_vid <= apu_playing;
            title_vid <= apu_title_bits;
            idx_vid <= song_index;
            cnt_vid <= song_count;
            status_vid <= load_status;
            elapsed_vid <= apu_elapsed;
            length_vid <= apu_length;
            shuffle_vid <= shuffle_en;
        end

        // we want HS to occur a bit after VS, not on the same cycle
        if(x_count == 3) begin
            vidout_hs <= 1;
        end

        // inactive screen areas are black
        vidout_rgb <= 24'h0;
        // generate active video
        if(x_count >= VID_H_BPORCH && x_count < VID_H_ACTIVE+VID_H_BPORCH) begin

            if(y_count >= VID_V_BPORCH && y_count < VID_V_ACTIVE+VID_V_BPORCH) begin
                // data enable. this is the active region of the line
                vidout_de <= 1;

                // dark background
                vidout_rgb <= 24'h101018;

                if (!playing_vid) begin
                    // status frame border: red = waiting for a file,
                    // orange = loading, magenta = read error
                    if (visible_x == 0 || visible_x == VID_H_ACTIVE-1 ||
                        visible_y == 0 || visible_y == VID_V_ACTIVE-1)
                        vidout_rgb <= border_rgb;
                end else begin
                    if (line_track && text_px)
                        vidout_rgb <= 24'h70D080;
                    else if (line_title && text_px)
                        vidout_rgb <= 24'hF0F0F0;
                    else if (line_game && text_px)
                        vidout_rgb <= 24'h9098A8;
                    // VU meters: L rows 144-167, R rows 184-207
                    else if (visible_y >= 'd144 && visible_y < 'd168) begin
                        if (visible_x < bar_l)
                            vidout_rgb <= 24'h30C060;   // green
                    end else if (visible_y >= 'd184 && visible_y < 'd208) begin
                        if (visible_x < bar_r)
                            vidout_rgb <= 24'h3060C0;   // blue
                    end else if (visible_y == 'd136 || visible_y == 'd176 ||
                                 visible_y == 'd216) begin
                        // faint separator lines
                        vidout_rgb <= 24'h202028;
                    end
                end
            end
        end
    end
end


//
// audio i2s from the APU (32kHz samples resampled by sound_i2s at 48kHz)
//

sound_i2s #(
    .CHANNEL_WIDTH  ( 16 ),
    .SIGNED_INPUT   ( 1 )
) i2s (
    .clk_74a    ( clk_74a ),
    .clk_audio  ( clk_sys_21_48 ),

    .audio_l    ( audio_l_out ),
    .audio_r    ( audio_r_out ),

    .audio_mclk ( audio_mclk ),
    .audio_lrck ( audio_lrck ),
    .audio_dac  ( audio_dac )
);


///////////////////////////////////////////////


    wire    clk_mem_85_9;
    wire    clk_sys_21_48;
    wire    clk_video_10_74;
    wire    clk_video_10_74_90deg;

    wire    pll_core_locked;
    wire    pll_core_locked_s;
synch_3 s01(pll_core_locked, pll_core_locked_s, clk_74a);

mf_pllbase mp1 (
    .refclk         ( clk_74a ),
    .rst            ( 0 ),

    .outclk_0       ( clk_mem_85_9 ),
    .outclk_1       ( clk_sys_21_48 ),
    .outclk_2       ( clk_video_10_74 ),
    .outclk_3       ( clk_video_10_74_90deg ),

    .locked         ( pll_core_locked )
);



endmodule

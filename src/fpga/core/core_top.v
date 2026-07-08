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
    32'h40xxxxxx: begin
        bridge_rd_data <= fbuf_q;       // getfile/openfile struct buffer
    end
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end

// filename struct buffer for target getfile/openfile (0x108 bytes):
// path[256] at 0x0, flags at 0x100, size at 0x104 (kept zero - plain open)
    reg     [31:0]  fbuf [0:65];
    reg     [31:0]  fbuf_q;
    integer         fi;
initial begin
    for (fi = 0; fi < 66; fi = fi + 1) fbuf[fi] = 0;
end
always @(posedge clk_74a) begin
    fbuf_q <= fbuf[bridge_addr[9:2]];
    if (bridge_wr && bridge_addr[31:24] == 8'h40 && bridge_addr[9:2] < 8'd64)
        fbuf[bridge_addr[9:2]] <= bridge_wr_data;
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

    wire    [31:0]  target_buffer_param_struct = 32'h40000000; // openfile reads path from fbuf
    wire    [31:0]  target_buffer_resp_struct  = 32'h40000000; // getfile writes path into fbuf

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
    wire            btn_scope   = cont1_key_s74[6] & ~cont1_key_prev[6];   // X
    wire            btn_alb_prev = cont1_key_s74[8] & ~cont1_key_prev[8];  // L1
    wire            btn_alb_next = cont1_key_s74[9] & ~cont1_key_prev[9];  // R1
    wire            btn_browse  = cont1_key_s74[14] & ~cont1_key_prev[14]; // Select
    wire            btn_up      = cont1_key_s74[0] & ~cont1_key_prev[0];   // dpad up
    wire            btn_down    = cont1_key_s74[1] & ~cont1_key_prev[1];   // dpad down

    reg             shuffle_en = 0;
    reg             scope_album = 0;    // 0 = whole pack, 1 = current album
    reg     [15:0]  lfsr = 16'hACE1;
    reg             pending_random = 0;
    reg     [15:0]  rand_rem;

    // current album bounds (valid for indexed packs), updated after each load
    reg     [11:0]  alb_lo = 0;
    reg     [11:0]  alb_hi = 0;         // exclusive
    // effective playback scope for next/prev/shuffle
    wire    [11:0]  scope_lo = (scope_album && pak_indexed) ? alb_lo : 12'd0;
    wire    [11:0]  scope_hi = (scope_album && pak_indexed) ? alb_hi : song_count;

    // album browser overlay
    localparam      BROWSE_ROWS = 26;   // y32..448 at 16px/row
    reg             browse_mode = 0;
    reg     [7:0]   browse_cursor = 0;
    reg     [7:0]   browse_top = 0;     // first visible album row
    reg     [5:0]   browse_hscroll = 0; // horizontal scroll of the cursor row
    reg             album_goto = 0;     // 1 = jump to browse_cursor, 0 = step

    reg             allcomplete_1 = 0;
    reg             reset_n_1 = 0;

    reg     [31:0]  pak_size = 0;
    reg     [31:0]  count_rem;
    reg     [11:0]  song_count = 0;    // up to 4095 songs
    reg     [11:0]  song_index = 0;
    reg     [11:0]  issue_index;
    reg             have_pak = 0;       // slot size known
    reg             track_loading = 0;

    reg             pending_load = 0;
    reg             pending_recount = 0;
    reg             pending_reopen = 0;
    reg     [11:0]  pending_index = 0;

    reg     [5:0]   tkstate = 0;
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
    localparam TK_DEFER    = 11;
    localparam TK_DONE     = 12;
    localparam TK_GETFILE  = 13;
    localparam TK_GF_WAIT  = 14;
    localparam TK_OPENFILE = 15;
    localparam TK_OF_WAIT  = 16;
    localparam TK_IDX_ISSUE = 17;
    localparam TK_IDX_EVAL  = 18;
    localparam TK_ALB0     = 20;
    localparam TK_ALB1     = 21;
    localparam TK_ALB2     = 22;
    localparam TK_ALB3     = 23;
    localparam TK_ALB4     = 24;
    localparam TK_ALB5     = 25;
    localparam TK_ALB6     = 26;
    localparam TK_ALB7     = 27;
    localparam TK_BND0     = 28;
    localparam TK_BND1     = 29;
    localparam TK_BND2     = 30;
    localparam TK_BND3     = 31;
    localparam TK_BND4     = 32;
    localparam TK_BND5     = 33;

    reg             probing = 0;
    reg             pending_album = 0;
    reg             album_dir = 0;
    reg     [8:0]   cur_alb;
    reg     [8:0]   target_alb;

    // wait ~450ms after a file change before touching the slot - reads
    // issued while APF is still swapping files never complete
    reg     [24:0]  defer_timer = 0;
    reg             load_ok = 0;

    // .spcpak index (entry 0 when magic "SPCPAKIX" present):
    // u16 track_count @0x8, u16 album_count @0xA, u16 album_start[256] @0x10.
    // Captured from raw bridge writes during the index probe read, entirely
    // in this clock domain.
    reg             index_loading = 0;
    reg             idx_magic1 = 0, idx_magic2 = 0;
    reg     [15:0]  idx_tracks = 0;
    reg     [15:0]  idx_albums = 0;
    reg             pak_indexed = 0;
    reg     [31:0]  astart_ram [0:127];    // raw index words 0x10-0x20F
    reg     [31:0]  astart_q;
    wire            idx_bwr = bridge_wr && bridge_addr[31:28] == 4'h1 && index_loading;

    reg             index_loading_1 = 0;
always @(posedge clk_74a) begin
    index_loading_1 <= index_loading;
    if (index_loading & ~index_loading_1) begin
        // probe starting: forget the previous file's index
        idx_magic1 <= 0;
        idx_magic2 <= 0;
    end else if (idx_bwr) begin
        case (bridge_addr[16:0])
            17'h0: idx_magic1 <= (bridge_wr_data == "SPCP");
            17'h4: idx_magic2 <= (bridge_wr_data == "AKIX");
            17'h8: begin
                // little-endian u16s inside a big-endian bridge word
                idx_tracks <= {bridge_wr_data[23:16], bridge_wr_data[31:24]};
                idx_albums <= {bridge_wr_data[7:0],   bridge_wr_data[15:8]};
            end
            default: ;
        endcase
    end
    if (idx_bwr && bridge_addr[16:0] >= 17'h10 && bridge_addr[16:0] < 17'h210)
        astart_ram[bridge_addr[9:2] - 8'd4] <= bridge_wr_data;
    astart_q <= astart_ram[alb_scan[8:1]];
    // album names: 64 bytes each at index offset 0x210-0x4210 (4096 words)
    if (idx_bwr && bridge_addr[16:0] >= 17'h210 && bridge_addr[16:0] < 17'h4210)
        name_ram[bridge_addr[16:2] - 15'h84] <= bridge_wr_data;
end

    // album name table, written above (clk_74a), read by the video domain
    reg     [31:0]  name_ram [0:4095];
    reg     [31:0]  name_q;

    // album_start[a]: even entries in the word's high half, odd in the low,
    // each little-endian
    reg     [8:0]   alb_scan;
    wire    [15:0]  astart_val = alb_scan[0] ? {astart_q[7:0],   astart_q[15:8]}
                                             : {astart_q[23:16], astart_q[31:24]};

    // retry management: heals boot-time races where the data table is not
    // yet populated, and read errors (with a shorter fallback length that
    // avoids reading up to the exact end-of-file)
    reg     [23:0]  retry_timer = 0;
    reg     [5:0]   retry_cnt = 0;
    reg             short_read = 0;     // fallback: skip the extra-RAM tail
    reg             load_error = 0;     // sticky: retries exhausted

    reg     [9:0]   datatable_addr_r = 0;
assign datatable_addr = datatable_addr_r;
assign datatable_wren = 0;
assign datatable_data = 0;

    // indexed packs: entry 0 is the index, songs shift up by one
    wire    [12:0]  eff_index   = {1'b0, issue_index} + {12'd0, pak_indexed};
    wire    [31:0]  song_offset = ({19'd0, eff_index} << 16) + ({19'd0, eff_index} << 9);

always @(posedge clk_74a) begin
    cont1_key_prev <= cont1_key_s74;
    allcomplete_1  <= dataslot_allcomplete;
    reset_n_1      <= reset_n;

    lfsr <= lfsr[0] ? (lfsr >> 1) ^ 16'hB400 : lfsr >> 1;

    // browse mode: Select opens/closes the album list; up/down move the
    // cursor; A jumps to the highlighted album (handled in the trigger block)
    if (btn_browse && pak_indexed && idx_albums > 1)
        browse_mode <= ~browse_mode;

    if (browse_mode) begin
        if (btn_up && browse_cursor != 0) begin
            browse_cursor <= browse_cursor - 1'b1;
            browse_hscroll <= 0;            // reset scroll when the row changes
        end else if (btn_down && browse_cursor + 1'b1 < idx_albums[7:0]) begin
            browse_cursor <= browse_cursor + 1'b1;
            browse_hscroll <= 0;
        end else if (btn_prev && browse_hscroll != 0)      // dpad left
            browse_hscroll <= browse_hscroll - 1'b1;
        else if (btn_next && browse_hscroll < 6'd32)       // dpad right
            browse_hscroll <= browse_hscroll + 1'b1;
        // keep the cursor inside the visible window (BROWSE_ROWS rows)
        if (browse_cursor < browse_top)
            browse_top <= browse_cursor;
        else if (browse_cursor >= browse_top + BROWSE_ROWS)
            browse_top <= browse_cursor - (BROWSE_ROWS - 1);
    end else begin
        if (btn_shuffle)
            shuffle_en <= ~shuffle_en;
        if (btn_scope && pak_indexed && idx_albums > 1)
            scope_album <= ~scope_album;
    end

    case (tkstate)
        TK_IDLE: begin
            if (pending_album) begin
                pending_album <= 0;
                tkstate <= TK_ALB0;
            end else if (pending_load) begin
                pending_load <= 0;
                issue_index  <= pending_index;
                if (pending_recount) begin
                    pending_recount <= 0;
                    pending_random  <= 0;
                    defer_timer <= 0;
                    tkstate <= TK_DEFER;
                end else if (pending_random) begin
                    pending_random <= 0;
                    rand_rem <= lfsr;
                    tkstate <= TK_RAND;
                end else begin
                    tkstate <= TK_ISSUE;
                end
            end
        end

        TK_DEFER: begin
            defer_timer <= defer_timer + 1'b1;
            if (&defer_timer) begin
                // A mid-session file re-pick is handled EXACTLY like boot:
                // re-read the new size and re-issue the plain target read.
                // This mirrors the proven live-swap cores (Amiga floppy,
                // PCE-CD disc). Do NOT call getfile/openfile here - a failed
                // openfile corrupts the slot handle and wedges the reads
                // (that was the actual cause of "new file won't load").
                pending_reopen <= 0;
                tkstate <= TK_SIZE0;
            end
        end

        // getfile -> openfile: ask APF for the slot's (possibly just
        // changed) filename, then force a FRESH file handle. Without this,
        // reads after a mid-session file change never complete.
        TK_GETFILE: begin
            target_dataslot_id      <= 16'h0;
            target_dataslot_getfile <= 1;
            retry_timer <= 0;
            tkstate <= TK_GF_WAIT;
        end
        TK_GF_WAIT: begin
            retry_timer <= retry_timer + 1'b1;
            if (target_dataslot_done && retry_timer > 24'd16) begin
                target_dataslot_getfile <= 0;
                // best-effort: a failed getfile must not block the load -
                // skip the reopen and try the plain read
                if (target_dataslot_err == 0)
                    tkstate <= TK_OPENFILE;
                else
                    tkstate <= TK_SIZE0;
            end else if (target_dataslot_ack) begin
                target_dataslot_getfile <= 0;
            end else if (&retry_timer) begin
                target_dataslot_getfile <= 0;
                tkstate <= TK_SIZE0;
            end
        end
        TK_OPENFILE: begin
            target_dataslot_id       <= 16'h0;
            target_dataslot_openfile <= 1;
            retry_timer <= 0;
            tkstate <= TK_OF_WAIT;
        end
        TK_OF_WAIT: begin
            retry_timer <= retry_timer + 1'b1;
            if (target_dataslot_done && retry_timer > 24'd16) begin
                target_dataslot_openfile <= 0;
                // best-effort: proceed to the read whether the reopen
                // worked or not (err stays visible in the debug readout)
                tkstate <= TK_SIZE0;
            end else if (target_dataslot_ack) begin
                target_dataslot_openfile <= 0;
            end else if (&retry_timer) begin
                target_dataslot_openfile <= 0;
                tkstate <= TK_SIZE0;
            end
        end

        TK_RAND: begin
            // rand_rem mod song_count by repeated subtraction, then avoid
            // repeating the current song
            // random index within [scope_lo, scope_hi): rand mod range + lo
            if (rand_rem >= {4'd0, (scope_hi - scope_lo)}) begin
                rand_rem <= rand_rem - {4'd0, (scope_hi - scope_lo)};
            end else begin
                if (scope_lo + rand_rem[11:0] == song_index)
                    issue_index <= (scope_lo + rand_rem[11:0] + 1'b1 >= scope_hi)
                                   ? scope_lo : scope_lo + rand_rem[11:0] + 1'b1;
                else
                    issue_index <= scope_lo + rand_rem[11:0];
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
            if (count_rem >= SONG_BYTES && song_count != 12'hFFF) begin
                count_rem  <= count_rem - SONG_BYTES;
                song_count <= song_count + 1'b1;
            end else begin
                // a trailing 0x10180-byte SPC (no extra-RAM section) counts,
                // but only if we stopped because the data ran out - not
                // because we hit the count cap (which would overflow)
                if (song_count != 12'hFFF && count_rem >= 32'h10180)
                    song_count <= song_count + 1'b1;
                have_pak <= 1;
                tkstate  <= TK_IDX_ISSUE;
            end
        end

        // probe entry 0 for the "SPCPAKIX" index (captured from the raw
        // bridge stream; the APU loader is gated off during this read)
        TK_IDX_ISSUE: begin
            if (song_count == 0) begin
                retry_timer <= 0;
                tkstate <= TK_RETRY;
            end else begin
                index_loading <= 1;
                probing <= 1;
                pak_indexed <= 0;
                target_dataslot_id         <= 16'h0;
                target_dataslot_slotoffset <= 32'd0;
                target_dataslot_bridgeaddr <= 32'h10000000;
                target_dataslot_length     <=
                    (pak_size > SONG_BYTES) ? SONG_BYTES : (pak_size - 32'd2);
                target_dataslot_read <= 1;
                track_loading <= 1;
                load_ok <= 0;
                retry_timer <= 0;
                tkstate <= TK_ACK;
            end
        end
        TK_IDX_EVAL: begin
            index_loading <= 0;
            probing <= 0;
            track_loading <= 0;
            if (idx_magic1 && idx_magic2) begin
                pak_indexed <= 1;
                // songs = entries minus the index, clamped to the count
                // the index itself declares
                if ({4'd0, idx_tracks[11:0]} == idx_tracks &&
                    idx_tracks[11:0] < song_count - 1'b1)
                    song_count <= idx_tracks[11:0];
                else
                    song_count <= song_count - 1'b1;
            end
            tkstate <= TK_ISSUE;
        end

        // album jump: find the target album (browse cursor, or step from the
        // current one), then load its first track and set the album bounds
        TK_ALB0: begin
            alb_scan <= 0;
            cur_alb  <= 0;
            tkstate  <= TK_ALB1;
        end
        TK_ALB1: tkstate <= TK_ALB2;        // astart_q catches up
        TK_ALB2: begin
            if (astart_val <= {4'd0, song_index})
                cur_alb <= alb_scan;
            if (alb_scan == idx_albums[8:0] - 1'b1) begin
                tkstate <= TK_ALB3;
            end else begin
                alb_scan <= alb_scan + 1'b1;
                tkstate  <= TK_ALB1;
            end
        end
        TK_ALB3: begin
            // pick the target album, then read album_start[target]
            if (album_goto)
                target_alb <= {1'b0, browse_cursor};
            else if (album_dir)
                target_alb <= (cur_alb + 1'b1 == idx_albums[8:0]) ? 9'd0 : cur_alb + 1'b1;
            else
                target_alb <= (cur_alb == 0) ? idx_albums[8:0] - 1'b1 : cur_alb - 1'b1;
            alb_scan <= album_goto ? {1'b0, browse_cursor}
                      : album_dir  ? ((cur_alb + 1'b1 == idx_albums[8:0]) ? 9'd0 : cur_alb + 1'b1)
                                   : ((cur_alb == 0) ? idx_albums[8:0] - 1'b1 : cur_alb - 1'b1);
            tkstate <= TK_ALB4;
        end
        TK_ALB4: tkstate <= TK_ALB5;        // astart_q catches up
        TK_ALB5: begin
            // alb_lo = album_start[target]; now read album_start[target+1]
            alb_lo <= (astart_val < {4'd0, song_count}) ? astart_val[11:0] : 12'd0;
            issue_index <= (astart_val < {4'd0, song_count}) ? astart_val[11:0] : 12'd0;
            alb_scan <= target_alb + 1'b1;
            tkstate <= TK_ALB6;
        end
        TK_ALB6: tkstate <= TK_ALB7;        // astart_q catches up
        TK_ALB7: begin
            // alb_hi = album_start[target+1], or song_count for the last album
            alb_hi <= (target_alb + 1'b1 >= idx_albums[8:0]) ? song_count
                    : (astart_val < {4'd0, song_count}) ? astart_val[11:0] : song_count;
            tkstate <= TK_ISSUE;
        end

        // recompute the current album bounds for song_index after a load
        // (so scope=album works no matter how we got here)
        TK_BND0: begin
            alb_scan <= 0;
            cur_alb  <= 0;
            alb_lo   <= 0;
            tkstate  <= TK_BND1;
        end
        TK_BND1: tkstate <= TK_BND2;
        TK_BND2: begin
            if (astart_val <= {4'd0, song_index}) begin
                cur_alb <= alb_scan;
                alb_lo  <= astart_val[11:0];
            end
            if (alb_scan == idx_albums[8:0] - 1'b1)
                tkstate <= TK_BND3;         // let cur_alb settle
            else begin
                alb_scan <= alb_scan + 1'b1;
                tkstate  <= TK_BND1;
            end
        end
        TK_BND3: begin
            alb_scan <= cur_alb + 1'b1;     // read album_start[cur_alb+1]
            tkstate  <= TK_BND4;
        end
        TK_BND4: tkstate <= TK_BND5;        // astart_q catches up
        TK_BND5: begin
            alb_hi <= (cur_alb + 1'b1 >= idx_albums[8:0]) ? song_count
                    : (astart_val < {4'd0, song_count}) ? astart_val[11:0] : song_count;
            tkstate <= TK_IDLE;
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
                // never let a read end exactly at end-of-file: reads that
                // touch EOF hang APF (hardware-observed). For the last (or
                // only) track, stop 2 bytes short - only the tail of the
                // extra-RAM mirror is lost.
                target_dataslot_length     <=
                    short_read ? 32'h10180
                    : (pak_size - song_offset > SONG_BYTES) ? SONG_BYTES
                    : (pak_size - song_offset - 32'd2);
                target_dataslot_read <= 1;
                track_loading <= 1;
                load_ok <= 0;
                retry_timer <= 0;
                tkstate <= TK_ACK;
            end
        end
        TK_ACK: begin
            retry_timer <= retry_timer + 1'b1;
            // done can arrive without a busy/ack phase (fast or rejected
            // commands) - accept it here too, but only after the stale done
            // from a previous command has been cleared (a few cycles)
            if (target_dataslot_done && retry_timer > 24'd16) begin
                target_dataslot_read <= 0;
                if (target_dataslot_err != 0) begin
                    track_loading <= 0;
                    short_read <= 1;
                    retry_timer <= 0;
                    tkstate <= TK_RETRY;
                end else if (probing) begin
                    tkstate <= TK_IDX_EVAL;
                end else begin
                    load_ok <= 1;
                    tkstate <= TK_DONE;
                end
            end else if (target_dataslot_ack) begin
                target_dataslot_read <= 0;
                tkstate <= TK_WAIT;
            end else if (&retry_timer) begin
                // watchdog (~220ms): command never started - abort and retry
                target_dataslot_read <= 0;
                track_loading <= 0;
                short_read <= 1;
                tkstate <= TK_RETRY;
            end
        end
        TK_WAIT: begin
            retry_timer <= retry_timer + 1'b1;
            if (target_dataslot_done) begin
                if (target_dataslot_err != 0) begin
                    track_loading <= 0;
                    short_read <= 1;        // next attempt avoids the EOF edge
                    retry_timer <= 0;
                    tkstate <= TK_RETRY;
                end else if (probing) begin
                    tkstate <= TK_IDX_EVAL;
                end else begin
                    load_ok <= 1;
                    tkstate <= TK_DONE;
                end
            end else if (&retry_timer) begin
                // watchdog: transfer never completed - abort and retry
                track_loading <= 0;
                short_read <= 1;
                tkstate <= TK_RETRY;
            end
        end
        TK_DONE: begin
            // load_ok is set one cycle before track_loading falls so the
            // sys-domain LOAD_DONE gate samples it reliably
            track_loading <= 0;
            retry_cnt  <= 0;
            load_error <= 0;
            // refresh album bounds for the loaded song (indexed packs only)
            tkstate <= pak_indexed ? TK_BND0 : TK_IDLE;
        end

        TK_RETRY: begin
            // wait ~220ms, then re-run the whole flow (size + count + load)
            probing <= 0;
            index_loading <= 0;
            retry_timer <= retry_timer + 1'b1;
            if (&retry_timer) begin
                if (retry_cnt == 6'd8) begin
                    load_error <= 1;        // give up until the user acts
                    tkstate <= TK_IDLE;
                end else begin
                    retry_cnt <= retry_cnt + 1'b1;
                    pending_load    <= 1;
                    pending_recount <= 1;
                    pending_reopen  <= 1;   // retries try a fresh handle
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
        (dataslot_update && dataslot_update_id == 16'h0) ||
        (dataslot_requestwrite && dataslot_requestwrite_id == 16'h0)) begin
        pending_load    <= 1;
        pending_recount <= 1;
        pending_album   <= 0;
        // only a mid-session file change needs the fresh-handle reopen;
        // boot (including its deferload update notification, when have_pak
        // is still 0) uses the plain proven path
        pending_reopen  <= have_pak &&
                           ((dataslot_update && dataslot_update_id == 16'h0) ||
                            (dataslot_requestwrite && dataslot_requestwrite_id == 16'h0));
        pending_random  <= 0;
        pending_index   <= 0;
        retry_cnt       <= 0;
        load_error      <= 0;
        short_read      <= 0;
    end else if (browse_mode) begin
        // A jumps to the highlighted album (scope follows into album mode)
        if (btn_restart && pak_indexed) begin
            pending_album <= 1;
            album_dir     <= 1'b0;
            album_goto    <= 1'b1;
            retry_cnt     <= 0;
            load_error    <= 0;
            browse_mode   <= 0;
        end
    end else if (have_pak && song_count != 0) begin
        // next/auto-advance: within the active scope (whole pack or album)
        if (btn_next || (adv_toggle_s ^ adv_toggle_1)) begin
            pending_load  <= 1;
            pending_random <= shuffle_en && (scope_hi - scope_lo > 12'd1);
            pending_index <= (song_index + 1'b1 >= scope_hi) ? scope_lo : song_index + 1'b1;
            retry_cnt     <= 0;
            load_error    <= 0;
        end else if (btn_prev) begin
            pending_load  <= 1;
            pending_random <= 0;
            pending_index <= (song_index <= scope_lo) ? scope_hi - 1'b1 : song_index - 1'b1;
            retry_cnt     <= 0;
            load_error    <= 0;
        end else if (btn_restart) begin
            pending_load  <= 1;
            pending_random <= 0;
            pending_index <= song_index;
            retry_cnt     <= 0;
            load_error    <= 0;
        end else if ((btn_alb_next || btn_alb_prev) && pak_indexed && idx_albums > 1) begin
            pending_album <= 1;
            album_dir     <= btn_alb_next;
            album_goto    <= 1'b0;
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

    wire    load_ok_s;
synch_3 s_lok(load_ok, load_ok_s, clk_sys_21_48);

    wire    index_loading_s;
synch_3 s_il(index_loading, index_loading_s, clk_sys_21_48);

    reg     spc_downloading_s1 = 0;
    reg     spc_load_done = 0;
always @(posedge clk_sys_21_48) begin
    spc_downloading_s1 <= spc_downloading_s;
    // only start the APU when the transfer actually succeeded - a failed
    // load must not replay stale data
    spc_load_done <= spc_downloading_s1 & ~spc_downloading_s & load_ok_s;
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
    wire    [87:0]  apu_voice_env;

spc_apu apu (
    .CLK            ( clk_sys_21_48 ),
    .RESET_N        ( pll_locked_sys ),

    // loader writes only pass while a SONG read we commanded is in flight -
    // APF's own re-pick streaming and the index probe must not touch the APU
    .LOAD_ACTIVE    ( spc_downloading_s ),
    .LOAD_WR        ( loader_wr & spc_downloading_s & ~index_loading_s ),
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
    .VOICE_ENV      ( apu_voice_env ),
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

// per-voice envelope peaks with decay (~4ms) for the voice bars
    reg     [10:0]  venv_peak [0:7];
    integer         vi;
always @(posedge clk_sys_21_48) begin
    if (apu_snd_rdy) begin
        for (vi = 0; vi < 8; vi = vi + 1) begin
            if (!audio_muted && apu_voice_env[vi*11 +: 11] > venv_peak[vi])
                venv_peak[vi] <= apu_voice_env[vi*11 +: 11];
            else
                venv_peak[vi] <= venv_peak[vi] - (venv_peak[vi] >> 7);
        end
    end
end

////////////////////////////////////////////////////////////////////////////////////////
// video generation: 512x480 active raster at 21.477270 MHz dot clock
// 682 x 524 total -> 60.09 Hz. Fills the Pocket's ~10:9 screen (see video.json).
// NOTE: the clk_video_10_74 nets are now 21.477 MHz (doubled); name kept.

assign video_rgb_clock = clk_video_10_74;
assign video_rgb_clock_90 = clk_video_10_74_90deg;
assign video_rgb = vidout_rgb;
assign video_de = vidout_de;
assign video_skip = 1'b0;
assign video_vs = vidout_vs;
assign video_hs = vidout_hs;

    localparam  VID_V_BPORCH = 'd20;
    localparam  VID_V_ACTIVE = 'd480;
    localparam  VID_V_TOTAL  = 'd524;
    localparam  VID_H_BPORCH = 'd120;
    localparam  VID_H_ACTIVE = 'd512;
    localparam  VID_H_TOTAL  = 'd682;

    reg [9:0]   x_count;
    reg [9:0]   y_count;

    wire [9:0]  visible_x = x_count - VID_H_BPORCH;
    wire [9:0]  visible_y = y_count - VID_V_BPORCH;

    reg [23:0]  vidout_rgb;
    reg         vidout_de;
    reg         vidout_vs;
    reg         vidout_hs;

    // levels resampled into the video domain once per frame (quasi-static)
    reg [14:0]  vu_l_vid, vu_r_vid;
    reg         playing_vid;
    reg [511:0] title_vid;
    reg [11:0]  idx_vid, cnt_vid;
    reg [1:0]   status_vid;
    reg [15:0]  elapsed_vid, length_vid;
    reg         shuffle_vid;
    reg         ever_played = 0;
    reg [5:0]   venv_vid [0:7];
    integer     vj;
    reg [5:0]   dbg_state;
    reg [2:0]   dbg_err;
    reg [5:0]   dbg_retry;
    reg [31:0]  dbg_size;
    reg [11:0]  dbg_count;
    reg         dbg_idx;
    reg [255:0] path_vid;
    integer     pk;
    reg         scope_vid;
    reg         browse_vid;
    reg [7:0]   cursor_vid;
    reg [7:0]   top_vid;
    reg [8:0]   nalb_vid;
    reg [5:0]   hscroll_vid;

    function [7:0] hexch(input [3:0] d);
        hexch = (d < 10) ? {4'h3, d} : (8'h37 + {4'd0, d});
    endfunction

    // album browser: geometry and name-RAM read (video clock).
    // BROWSE_Y0 must be a multiple of 16 so the shared font row index
    // (visible_y[3:1]) lines up with each 16px browser row.
    localparam  BROWSE_Y0 = 'd32;       // first row top (16-aligned)
    wire [8:0]  browse_row  = (visible_y - BROWSE_Y0) >> 4;         // 16px/row
    wire [7:0]  browse_alb  = top_vid + browse_row[7:0];
    wire        browse_area = browse_vid && visible_y >= BROWSE_Y0 &&
                              browse_row < BROWSE_ROWS && browse_alb < nalb_vid;
    // 64-byte names; the highlighted row scrolls horizontally. Read the char
    // one ahead (registered BRAM), MSB-first within each 32-bit word.
    wire [5:0]  name_col = la_ci + ((browse_alb == cursor_vid) ? hscroll_vid : 6'd0);
    wire [11:0] name_radr = {browse_alb[7:0], name_col[5:2]};
    reg  [1:0]  name_bsel;
always @(posedge clk_video_10_74) begin
    name_q    <= name_ram[name_radr];
    name_bsel <= name_col[1:0];
end
    wire [7:0]  name_raw = name_q[(3 - name_bsel)*8 +: 8];
    wire [7:0]  name_ch  = (name_raw < 8'h20 || name_raw > 8'h7E) ? 8'h20 : name_raw;

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
    wire        line_track = (visible_y[9:4] == 'd2);   // y32-47
    wire        line_title = (visible_y[9:4] == 'd4);   // y64-79
    wire        line_game  = (visible_y[9:4] == 'd6);   // y96-111
    wire        line_hint  = (visible_y[9:4] == 'd28);  // y448-463
    wire        line_hint2 = (visible_y[9:4] == 'd29);  // y464-479
    wire        any_text_line = line_track | line_title | line_game |
                                line_hint | line_hint2 | browse_area;

    // subtle control hints, two lines at the bottom of the screen
    localparam [8*32-1:0] HINTS  = "L/R:PREV NEXT  A:RST  Y:SHUFFL";
    localparam [8*32-1:0] HINTS2 = "X:SCOPE  L1/R1:ALBUM  SEL:LIST ";
    wire [7:0]  hint_ch  = HINTS [(31 - la_ci)*8 +: 8];
    wire [7:0]  hint2_ch = HINTS2[(31 - la_ci)*8 +: 8];

    // track counter digits (from once-per-frame latched values)
    // 3-digit counter (saturates at 999 for display; core supports 4095)
    wire [12:0] disp_n = idx_vid + 1'b1;
    wire [12:0] disp_n_c = (disp_n > 13'd999) ? 13'd999 : disp_n;
    wire [12:0] disp_c_c = (cnt_vid > 12'd999) ? 13'd999 : {1'b0, cnt_vid};
    wire [3:0]  n_d2 = disp_n_c / 'd100;
    wire [3:0]  n_d1 = (disp_n_c / 'd10) % 'd10;
    wire [3:0]  n_d0 = disp_n_c % 'd10;
    wire [3:0]  c_d2 = disp_c_c / 'd100;
    wire [3:0]  c_d1 = (disp_c_c / 'd10) % 'd10;
    wire [3:0]  c_d0 = disp_c_c % 'd10;

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
        5'd9:    track_ch = scope_vid   ? 8'h41 : 8'h20;    // 'A' = album scope
        5'd10:   track_ch = shuffle_vid ? 8'h53 : 8'h20;    // 'S' = shuffle
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

    // when stopped, the game-title line shows the getfile path (debug):
    // 32 chars, MSB-first within each 32-bit bridge word
    wire [7:0]  path_raw = path_vid[{la_ci[4:2], ~la_ci[1:0], 3'b000} +: 8];
    wire [7:0]  path_ch  = (path_raw < 8'h20 || path_raw > 8'h7E) ? 8'h2E : path_raw;

    // title line when stopped: "SZ<size8> N<count3> I<idx1>" diagnostic
    reg [7:0]  title_dbg_ch;
always @(*) begin
    case (la_ci)
        5'd0:    title_dbg_ch = 8'h53;   // S
        5'd1:    title_dbg_ch = 8'h5A;   // Z
        5'd2:    title_dbg_ch = hexch(dbg_size[31:28]);
        5'd3:    title_dbg_ch = hexch(dbg_size[27:24]);
        5'd4:    title_dbg_ch = hexch(dbg_size[23:20]);
        5'd5:    title_dbg_ch = hexch(dbg_size[19:16]);
        5'd6:    title_dbg_ch = hexch(dbg_size[15:12]);
        5'd7:    title_dbg_ch = hexch(dbg_size[11:8]);
        5'd8:    title_dbg_ch = hexch(dbg_size[7:4]);
        5'd9:    title_dbg_ch = hexch(dbg_size[3:0]);
        5'd11:   title_dbg_ch = 8'h4E;   // N
        5'd12:   title_dbg_ch = hexch(dbg_count[11:8]);
        5'd13:   title_dbg_ch = hexch(dbg_count[7:4]);
        5'd14:   title_dbg_ch = hexch(dbg_count[3:0]);
        5'd16:   title_dbg_ch = 8'h49;   // I
        5'd17:   title_dbg_ch = hexch({3'd0, dbg_idx});
        default: title_dbg_ch = 8'h20;
    endcase
end

    wire [7:0]  font_ch = browse_vid ? (browse_area ? name_ch : 8'h20)
                        : line_title ? title_vid[{4'd0, la_ci, 3'd0} +: 8]
                        : line_game  ? title_vid[{4'd1, la_ci, 3'd0} +: 8]
                        : line_hint  ? hint_ch
                        : line_hint2 ? hint2_ch
                        : track_ch;

    wire [7:0]  font_bits;
    reg  [2:0]  font_col_r;

font_rom fnt (
    .clk    ( clk_video_10_74 ),
    .char   ( font_ch[6:0] ),
    .row    ( visible_y[3:1] ),
    .bits   ( font_bits )
);

    // browser adds one pipeline stage (registered name-RAM read), so its
    // glyph column select is delayed one extra cycle to stay aligned
    reg  [2:0]  font_col_r2;
    wire        text_px = font_bits[browse_vid ? font_col_r2 : font_col_r];

    // per-voice envelope bars: 8 columns of 64px, y 128-407, grow up from 408
    wire [2:0]  vbar_v = visible_x[8:6];
    wire [5:0]  vbar_x = visible_x[5:0];
    wire [5:0]  vbar_h = venv_vid[vbar_v];
    wire [8:0]  vbar_px = {vbar_h, 2'b00};   // envelope x4 -> up to 252px tall
    wire        vbar_on = (visible_y >= 'd128 && visible_y < 'd408) &&
                          (vbar_x >= 'd8 && vbar_x < 'd56) &&
                          (vbar_h != 0) &&
                          (visible_y >= (10'd408 - {1'b0, vbar_px}));
    reg [23:0]  vbar_rgb;
always @(*) begin
    case (vbar_v)
        3'd0:    vbar_rgb = 24'hE05050;
        3'd1:    vbar_rgb = 24'hE09040;
        3'd2:    vbar_rgb = 24'hE0D040;
        3'd3:    vbar_rgb = 24'h60C850;
        3'd4:    vbar_rgb = 24'h40C0B0;
        3'd5:    vbar_rgb = 24'h4880E0;
        3'd6:    vbar_rgb = 24'h9060E0;
        default: vbar_rgb = 24'hD060B0;
    endcase
end

always @(posedge clk_video_10_74 or negedge reset_n) begin

    if(~reset_n) begin

        x_count <= 0;
        y_count <= 0;

    end else begin
        vidout_de <= 0;
        vidout_vs <= 0;
        vidout_hs <= 0;

        font_col_r <= la_vx[3:1];
        font_col_r2 <= font_col_r;

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
            if (apu_playing)
                ever_played <= 1;
            title_vid <= apu_title_bits;
            idx_vid <= song_index;
            cnt_vid <= song_count;
            status_vid <= load_status;
            elapsed_vid <= apu_elapsed;
            length_vid <= apu_length;
            shuffle_vid <= shuffle_en;
            scope_vid  <= scope_album;
            browse_vid <= browse_mode;
            cursor_vid <= browse_cursor;
            top_vid    <= browse_top;
            nalb_vid   <= idx_albums[8:0];
            hscroll_vid <= browse_hscroll;
            for (vj = 0; vj < 8; vj = vj + 1)
                venv_vid[vj] <= venv_peak[vj][10:5];
            dbg_state <= tkstate;
            dbg_err   <= target_dataslot_err;
            dbg_retry <= retry_cnt;
            dbg_size  <= pak_size;
            dbg_count <= song_count;
            dbg_idx   <= pak_indexed;
            for (pk = 0; pk < 8; pk = pk + 1)
                path_vid[pk*32 +: 32] <= fbuf[pk];
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

                if (browse_vid) begin
                    // album browser overlay (full screen)
                    if (browse_alb == cursor_vid && browse_area)
                        vidout_rgb <= 24'h283048;   // highlighted row background
                    if (browse_area && text_px)
                        vidout_rgb <= (browse_alb == cursor_vid) ? 24'hF0F0A0
                                                                 : 24'hC0C0C0;
                end else if (!playing_vid && (!ever_played || status_vid == 2'd2)) begin
                    // status frame border, shown only before the first song
                    // has ever played or on a persistent error - brief track
                    // loads keep the normal UI (no flashing):
                    // red = waiting for a file, orange = loading,
                    // magenta = read error
                    if (visible_x == 0 || visible_x == VID_H_ACTIVE-1 ||
                        visible_y == 0 || visible_y == VID_V_ACTIVE-1)
                        vidout_rgb <= border_rgb;
                end else begin
                    if (!playing_vid && visible_x >= 'd498 && visible_x < 'd506 &&
                        visible_y >= 'd4 && visible_y < 'd12)
                        // small status square while not playing:
                        // orange = loading, magenta = error, red = waiting
                        vidout_rgb <= border_rgb;
                    else if (line_track && text_px)
                        vidout_rgb <= 24'h70D080;
                    else if (line_title && text_px)
                        vidout_rgb <= 24'hF0F0F0;
                    else if (line_game && text_px)
                        vidout_rgb <= 24'h9098A8;
                    else if (line_hint && text_px)
                        vidout_rgb <= 24'h50505C;
                    else if (line_hint2 && text_px)
                        vidout_rgb <= 24'h50505C;
                    // per-voice envelope bars, y 128-407
                    else if (vbar_on)
                        vidout_rgb <= vbar_rgb;
                    else if (visible_y == 'd410)
                        // baseline under the voice bars
                        vidout_rgb <= 24'h202028;
                    // L/R VU strips, y 416-431 / 432-447
                    else if (visible_y >= 'd416 && visible_y < 'd432) begin
                        if (visible_x < bar_l)
                            vidout_rgb <= 24'h30C060;   // green
                    end else if (visible_y >= 'd432 && visible_y < 'd448) begin
                        if (visible_x < bar_r)
                            vidout_rgb <= 24'h3060C0;   // blue
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

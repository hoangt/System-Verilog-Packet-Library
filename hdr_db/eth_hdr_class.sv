/*
Copyright (c) 2011, Sachin Gandhi
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// ----------------------------------------------------------------------
//  This hdr_class generates Ethernet header.
//  Ethernet header format
//  +-------------------+
//  |     da[47:0]      |
//  +-------------------+
//  |     sa[47:0]      |
//  +-------------------+
//  |     etype[15:0]   |
//  +-------------------+
//  |     ...           | -
//  +-------------------+  |_ Other hdrs
//  |     ...           |  |
//  +-------------------+ -
// ----------------------------------------------------------------------
//  Control Variables :
//  ==================
//  +-------+---------+-------------+------------------------------------+
//  | Width | Default | Variable    | Description                        |
//  +-------+---------+-------------+------------------------------------+
//  | 1     | 1'b0    | is_multi_da | If 1, Multicast DA                 |
//  +-------+---------+-------------+------------------------------------+
//  | 1     | 1'b0    | is_broad_da | If 1, Broadcast DA                 |
//  +-------+---------+-------------+------------------------------------+
// 
// ----------------------------------------------------------------------

class eth_hdr_class extends hdr_class; // {

  // ~~~~~~~~~~ Class members ~~~~~~~~~~
  rand bit [47:0] da;
  rand bit [47:0] sa;
  rand bit [15:0] etype;

  // ~~~~~~~~~~ Local Variables ~~~~~~~~~~

  // ~~~~~~~~~~ Control variables ~~~~~~~~~~
       bit        is_multi_da = 1'b0; 
       bit        is_broad_da = 1'b0; 

  // ~~~~~~~~~~ Constraints begins ~~~~~~~~~~

  constraint eth_hdr_user_constraint
  {
  }

  constraint legal_total_hdr_len
  {
    `LEGAL_TOTAL_HDR_LEN_CONSTRAINTS;
  }

  constraint legal_etype
  {
    `LEGAL_ETH_TYPE_CONSTRAINTS;
  }

  constraint legal_hdr_len
  {
    hdr_len == 14;
  }

  constraint set_multicast_da
  {
    (is_multi_da == 1'b1) -> (da[40] == 1'b1);
  }

  constraint set_broadcast_da
  {
    (is_broad_da == 1'b1) -> (da == 48'hffffffffffff);
  }

  // ~~~~~~~~~~ Task begins ~~~~~~~~~~

  function new (pktlib_main_class plib,
                int               inst_no); // {
    super.new (plib);
    hid          = ETH_HID;
    this.inst_no = inst_no;
    $sformat (hdr_name, "eth[%0d]",inst_no);
    super.update_hdr_db (hid, inst_no);
  endfunction : new // }

  function void pre_randomize (); // {
    if (super) super.pre_randomize();
  endfunction : pre_randomize // }

  task pack_hdr (ref   bit [7:0] pkt [],
                 ref   int       index,
                 input bit       last_pack = 1'b0); // {
    // pack class members
    `ifdef SVFNYI_0
    pack_vec = {da, sa, etype};
    harray.pack_bit (pkt, pack_vec, index, hdr_len*8);
    `else
    hdr = {>>{da, sa, etype}};
    harray.pack_array_8 (hdr, pkt, index);
    `endif
    // pack next hdr
    if (~last_pack)
    begin // {
        `ifdef DEBUG_PKTLIB
        $display ("    pkt_lib : Packing %s nxt_hdr %s index %0d", hdr_name, nxt_hdr.hdr_name, index); 
        `endif
        this.nxt_hdr.pack_hdr (pkt, index);
    end // }
  endtask : pack_hdr // }

  task unpack_hdr (ref   bit [7:0] pkt   [],
                   ref   int       index,
                   ref   hdr_class hdr_q [$],
                   input int       mode        = DUMB_UNPACK,
                   input bit       last_unpack = 1'b0); // {
    hdr_class lcl_class;
    // unpack class members
    hdr_len   = 14;
    start_off = index;
    `ifdef SVFNYI_0
    harray.unpack_array (pkt, pack_vec, index, hdr_len);
    {da, sa, etype} = pack_vec;
    `else
    harray.copy_array (pkt, hdr, index, hdr_len);
    {>>{da, sa, etype}} = hdr;
    `endif
    // get next hdr and update common nxt_hdr fields
    if (mode == SMART_UNPACK)
    begin // {
        $cast (lcl_class, this);
        if (unpack_en[get_hid_from_etype(etype)] & (pkt.size > index))
            super.update_nxt_hdr_info (lcl_class, hdr_q, get_hid_from_etype (etype));
        else
            super.update_nxt_hdr_info (lcl_class, hdr_q, DATA_HID);
    end // }
    // unpack next hdr
    if (~last_unpack)
    begin // {
        `ifdef DEBUG_PKTLIB
        $display ("    pkt_lib : Unpacking %s nxt_hdr %s index %0d", hdr_name, nxt_hdr.hdr_name, index); 
        `endif
        this.nxt_hdr.unpack_hdr (pkt, index, hdr_q, mode);
    end // }
    // update all hdr
    if (mode == SMART_UNPACK)
        super.all_hdr = hdr_q;
  endtask : unpack_hdr // }

  task cpy_hdr (hdr_class cpy_cls,
                bit       last_cpy = 1'b0); // {
    eth_hdr_class lcl;
    super.cpy_hdr (cpy_cls);
    $cast (lcl, cpy_cls);
    // ~~~~~~~~~~ Class members ~~~~~~~~~~
    this.da          = lcl.da;
    this.sa          = lcl.sa;
    this.etype       = lcl.etype;
    // ~~~~~~~~~~ Control variables ~~~~~~~~~~
    this.is_multi_da = lcl.is_multi_da;
    this.is_broad_da = lcl.is_broad_da;
    if (~last_cpy)
        this.nxt_hdr.cpy_hdr (cpy_cls.nxt_hdr, last_cpy);
  endtask : cpy_hdr // }

  task display_hdr (pktlib_display_class hdis,
                    hdr_class            cmp_cls,
                    int                  mode         = DISPLAY,
                    bit                  last_display = 1'b0); // {
    eth_hdr_class lcl;
    $cast (lcl, cmp_cls);
    if ((mode == DISPLAY_FULL) | (mode == COMPARE_FULL))
    hdis.display_fld (mode, hdr_name, STRING,  DEF, 000, "", 0, 0, '{}, '{}, "~~~~~~~~~~ Class members ~~~~~~~~~~");
    hdis.display_fld (mode, hdr_name, BIT_VEC, HEX, 048, "da", da, lcl.da);
    hdis.display_fld (mode, hdr_name, BIT_VEC, HEX, 048, "sa", sa, lcl.sa);
    hdis.display_fld (mode, hdr_name, BIT_VEC, HEX, 016, "etype", etype, lcl.etype, '{}, '{}, get_etype_name(etype));
    if ((mode == DISPLAY_FULL) | (mode == COMPARE_FULL))
    begin // {
    hdis.display_fld (mode, hdr_name, STRING,  DEF, 000, "", 0, 0, '{}, '{}, "~~~~~~~~~~ Control variables ~~~~~~");
    hdis.display_fld (mode, hdr_name, BIT_VEC, BIN, 001, "is_multi_da", is_multi_da, lcl.is_multi_da);
    hdis.display_fld (mode, hdr_name, BIT_VEC, BIN, 001, "is_broad_da", is_broad_da, lcl.is_broad_da);
    end // }
    if ((mode == DISPLAY_FULL) | (mode == COMPARE_FULL))
    begin // {
    hdis.display_fld (mode, hdr_name, STRING,  DEF, 000, "", 0, 0, '{}, '{}, "~~~~~~~~~~ Local variables ~~~~~~~~");
    hdis.display_fld (mode, hdr_name, BIT_VEC, DEF, 016, "hdr_len", hdr_len, lcl.hdr_len);
    hdis.display_fld (mode, hdr_name, BIT_VEC, DEF, 016, "total_hdr_len", total_hdr_len, lcl.total_hdr_len);
    end // }
    if (~last_display & (cmp_cls.nxt_hdr.hid == nxt_hdr.hid))
        this.nxt_hdr.display_hdr (hdis, cmp_cls.nxt_hdr, mode);
  endtask : display_hdr // }

endclass : eth_hdr_class // }

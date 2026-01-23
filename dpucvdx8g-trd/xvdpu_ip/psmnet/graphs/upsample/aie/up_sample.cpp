/**********
© Copyright 2020 Xilinx, Inc.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
**********/
#include "../params.h"
#include <adf.h>
#include <stdio.h>

void aie_upsample_init() {
  set_sat();
  set_rnd(rnd_sym_inf);
}

void aie_upsample(input_stream_uint8 *in, output_stream_uint8 *out,
                const int32 (&config)[2]) {
  int input_fp_pos = config[0];
  int output_fp_pos = config[1];
  // out_right_shift can be negative
  int out_right_shift = input_fp_pos - output_fp_pos;

  v32int8 data_mat_A[O_B_PP];
  v32int8 data_mat_B[O_B_PP];
  v32int8 data_mat_C[O_B_PP];
  v32int8 data_mat_D[O_B_PP];
  v32int16 fact = null_v32int16();

  v4int32 conf = as_v4int32(readincr_v16(in));
  uint16 w_scale = (uint16)ext_elem(conf, 0);
  uint16 h_scale = (uint16)ext_elem(conf, 1);

  int16 w_start = (uint16)ext_elem(conf, 2);
  int16 h_start = (uint16)ext_elem(conf, 3);

  int i;
  v32int8 *p;

  for (i = 0, p = data_mat_A; i < O_B_PP; i++) {
    *p = as_v32int8(concat(readincr_v16(in), readincr_v16(in)));
    p++;
  }
  for (i = 0, p = data_mat_B; i < O_B_PP; i++) {
    *p = as_v32int8(concat(readincr_v16(in), readincr_v16(in)));
    p++;
  }
  for (i = 0, p = data_mat_C; i < O_B_PP; i++) {
    *p = as_v32int8(concat(readincr_v16(in), readincr_v16(in)));
    p++;
  }
  for (i = 0, p = data_mat_D; i < O_B_PP; i++) {
    *p = as_v32int8(concat(readincr_v16(in), readincr_v16(in)));
    p++;
  }

  int32_t w_coff, w_coff_com, h_coff, h_coff_com;
  uint16_t coff_A, coff_B, coff_C, coff_D;
  for (int i = 0; i < O_B_PP; i++) {
    w_coff = (w_start + w_scale * (i % O_W_PP)) % (1 << FIX_POS);
    if (w_coff < 0) {
      w_coff = (1 << FIX_POS) + w_coff;
    }
    h_coff = (h_start + h_scale * (i / O_W_PP)) % (1 << FIX_POS);
    if (h_coff < 0) {
      h_coff = (1 << FIX_POS) + h_coff;
    }
    w_coff_com = (1 << FIX_POS) - w_coff;
    h_coff_com = (1 << FIX_POS) - h_coff;

    coff_A = (w_coff_com * h_coff_com) >> FIX_POS;
    coff_B = (w_coff * h_coff_com) >> FIX_POS;
    coff_C = (w_coff_com * h_coff) >> FIX_POS;
    coff_D = (w_coff * h_coff) >> FIX_POS;

    fact = upd_elem(fact, 0, coff_A);
    fact = upd_elem(fact, 2, coff_B);
    fact = upd_elem(fact, 4, coff_C);
    fact = upd_elem(fact, 6, coff_D);

    auto acc = null_v16acc48();
    acc = mac16(acc, fact, 0, 0x00000000, 0x00000000, 0, 0x1010, data_mat_A[i],
                0, 0x33221100, 0x77665544, 0, 0x3120);
    acc = mac16(acc, fact, 0, 0x01010101, 0x01010101, 0, 0x1010, data_mat_A[i],
                0, 0x33221100, 0x77665544, 0, 0x3120);
    acc = mac16(acc, fact, 0, 0x02020202, 0x02020202, 0, 0x1010, data_mat_A[i],
                0, 0x33221100, 0x77665544, 0, 0x3120);
    acc = mac16(acc, fact, 0, 0x03030303, 0x03030303, 0, 0x1010, data_mat_A[i],
                0, 0x33221100, 0x77665544, 0, 0x3120);
    writeincr(out, as_v16uint8(bsrs(acc, 11 + out_right_shift)));

    acc = null_v16acc48();
    acc = mac16(acc, fact, 0, 0x00000000, 0x00000000, 0, 0x1010, data_mat_A[i],
                0, 0xbbaa9988, 0xffeeddcc, 0, 0x3120);
    acc = mac16(acc, fact, 0, 0x01010101, 0x01010101, 0, 0x1010, data_mat_A[i],
                0, 0xbbaa9988, 0xffeeddcc, 0, 0x3120);
    acc = mac16(acc, fact, 0, 0x02020202, 0x02020202, 0, 0x1010, data_mat_A[i],
                0, 0xbbaa9988, 0xffeeddcc, 0, 0x3120);
    acc = mac16(acc, fact, 0, 0x03030303, 0x03030303, 0, 0x1010, data_mat_A[i],
                0, 0xbbaa9988, 0xffeeddcc, 0, 0x3120);
    writeincr(out, as_v16uint8(bsrs(acc, 11 + out_right_shift)));
  }
}

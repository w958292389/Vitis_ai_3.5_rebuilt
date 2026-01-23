/**
 * Copyright 2022 Xilinx Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdio.h>
#include <stdlib.h>

#include <adf.h>

#include "param.h"

alignas(alignof(v8float)) const float conv_param[VECTOR_LEN] = CONV_PARAM_ARRAY;

ALWAYS_INLINE float exp(int8_t in, const float (&exp_lut)[256]) {
  return exp_lut[in + 128];
}

ALWAYS_INLINE v8float float_v_sum(v8float i) {
    v8float tmp = i;

    i = fpadd(i, i, 0, 0x67452301);
    i = fpadd(i, i, 0, 0x45670123);
    i = fpadd(i, i, 0, 0x01234567);

    return i;
}

ALWAYS_INLINE void softmax_inner_loop(int n_loop, int8_t *data_in,
                                      const float (&exp_lut)[256],
                                      float *restrict out) {
  float *restrict Co = chess_copy(out);
  alignas(alignof(v8float)) float buff0[VECTOR_LEN];

  v8float *pv_buff0 = (v8float *)buff0;
  v8float *conv_p = (v8float *)conv_param;

  v8float x0 = null_v8float();
  v8float x1 = null_v8float();

  v8float buff = null_v8float();
  v8float v_sum = null_v8float();
  float e_sum = 0;

  for (int i = 0; i < n_loop * 32; i++)
    chess_prepare_for_pipelining chess_loop_range(192, 192) {
      buff0[i] = exp((data_in[i]), exp_lut);
    }

  for (int i = 0; i < n_loop * 4; i++)
    chess_prepare_for_pipelining chess_loop_range(24, 24) {
      buff = *pv_buff0++;
      v_sum = fpadd(v_sum, buff, 0, 0x76543210);
    }

  v_sum = float_v_sum(v_sum);

  //printf("vsum: %f\n", ext_elem(v_sum, 0));
  e_sum = inv(ext_elem(v_sum, 0));
  for (int i = 0; i < 8; i++) {
    v_sum = upd_elem(v_sum, i, e_sum);
  }

  pv_buff0 = (v8float *)buff0;

  for (int i = 0; i < n_loop * 4; i++)
    chess_prepare_for_pipelining chess_loop_range(24, 24) {
      buff = *pv_buff0++;
      x0 = fpmul(buff, 0, 0x76543210, v_sum, 0, 0x76543210);
      buff = *conv_p++;
      x1 = fpmac(x1, buff, 0, 0x76543210, x0, 0, 0x76543210);
    }

  x1 = float_v_sum(x1);

  *Co = ext_elem(x1, 0);
}

void softmax(input_stream_int8 *bufA, const int32 (&control)[6],
             const float (&exp_lut)[256], output_stream_float *bufC) {
  int32 len = control[1];
  int32 loop_n = len / 32;

  for (auto ol = 0; ol < OUTTER_LOOP; ol++) {
    // Read 192 int8 from stream_in
    v16int8 data_in[192 / 16];
    float data_out;
    for (auto i = 0; i < 192 / 16; i++)
      chess_prepare_for_pipelining chess_loop_range(192 / 16, 192 / 16) {
        data_in[i] = readincr_v16(bufA);
      }

    softmax_inner_loop(loop_n, (int8 *)data_in, exp_lut, &data_out);

    writeincr(bufC, data_out);
  }
}

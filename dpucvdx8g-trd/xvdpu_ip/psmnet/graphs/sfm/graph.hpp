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

#include "aie/kernel.hpp"
#include "aie/param.h"
#include <adf.h>

using namespace adf;

template <int BAT_NUM> class softmax_conv : public graph {
private:
  kernel superkernel[BAT_NUM];

public:
  input_gmio datain[BAT_NUM];
  output_gmio dataout[BAT_NUM];

  port<input> control[BAT_NUM];
  port<input> exp_lut[BAT_NUM];

  softmax_conv() {
    for (int i = 0; i < BAT_NUM; i++) {
      superkernel[i] = kernel::create(softmax);
      source(superkernel[i]) = "aie/softmax.cpp";

      datain[i] = input_gmio::create(256, 1000);
      dataout[i] = output_gmio::create(256, 1000);

      runtime<ratio>(superkernel[i]) = 0.9;

      connect<stream>(datain[i].out[0], async(superkernel[i].in[0]));
      connect<stream>(async(superkernel[i].out[0]), dataout[i].in[0]);

      connect<parameter>(control[i], async(superkernel[i].in[1]));
      connect<parameter>(exp_lut[i], async(superkernel[i].in[2]));

      location<stack>(superkernel[i]) = location<kernel>(superkernel[i]);
      location<buffer>(superkernel[i].in[1]) = location<kernel>(superkernel[i]);

      stack_size(superkernel[i]) = 1536;
      heap_size(superkernel[i]) = 1536;
    }
  } // end construction
};  // end class

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
#include <adf.h>
#include "./params.h"
#include "aie/kernel.h"

using namespace adf;

class graph_upsample_aie_hls: public graph
{
private:

public:
  kernel k_upsample_aie;

  input_plio pl_in;
  output_plio pl_out;

  port<direction::in> config;

  graph_upsample_aie_hls()
  {
		k_upsample_aie = kernel::create(aie_upsample);
		source(k_upsample_aie) = "aie/up_sample.cpp";
        initialization_function(k_upsample_aie) = "aie_upsample_init";
		runtime<ratio>(k_upsample_aie)= 0.9;

        pl_in = input_plio::create("pl_in", plio_128_bits);
        pl_out = output_plio::create("pl_out", plio_128_bits);
	
		connect<stream>(pl_in.out[0], async(k_upsample_aie.in[0]));
		connect<stream>(async(k_upsample_aie.out[0]), pl_out.in[0]);

        connect<parameter>(config, async(k_upsample_aie.in[1]));

        stack_size(k_upsample_aie) = 9216;
  };
};


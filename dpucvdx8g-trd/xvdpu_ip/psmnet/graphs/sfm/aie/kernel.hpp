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

#ifndef FUNCTION_KERNELS_H
#define FUNCTION_KERNELS_H
#include <adf.h>

void softmax(input_stream_int8 *bufA, const int32 (&control)[6],
             const float (&exp_lut)[256], output_stream_float *bufC);

#endif

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

typedef short int int16_t;
typedef unsigned short int uint16_t;
typedef unsigned int uint32_t;
typedef int int32_t;
typedef unsigned char uint8_t;

#define CHN_PER_GROP 16

#define CHN (32)
#define FIX_POS 10
#define FIX_POS_1 (1 << FIX_POS)
#define FIX_POS_0p5 (1 << (FIX_POS - 1))

//Output Pixel Parallelism
#define O_PP (8)
#define O_W_PP (8)
#define O_H_PP (8)
//Output Block Pixel Parallelism
#define O_B_PP (O_W_PP * O_H_PP)

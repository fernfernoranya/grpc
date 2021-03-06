#!/bin/bash
# Copyright 2018 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generate the list of boringssl symbols that need to be shadowed based on the
# current boringssl submodule. Requires local toolchain to build boringssl.
set -e

cd $(dirname $0)

symbol_list="../../src/objective-c/grpc_shadow_boringssl_symbol_list"

ssl_lib='../../third_party/boringssl-with-bazel/build/libssl.a'
crypto_lib='../../third_party/boringssl-with-bazel/build/libcrypto.a'

# Generate boringssl archives
( cd ../../third_party/boringssl-with-bazel ; mkdir -p build ; cd build ; cmake .. ; make -j ssl crypto )

# Generate shadow_boringssl.h
unameOut="$(uname -s)"
case "${unameOut}" in
  Linux*)
    outputs="$(nm $ssl_lib)"$'\n'"$(nm $crypto_lib)"
    symbols=$(echo "$outputs" | 
              grep '^[0-9a-f]* [A-Z] ' |               # Only public symbols
              grep -v '^[0-9a-f]* [A-Z] _' |           # Remove all symbols which look like for C++
              sed 's/[0-9a-f]* [A-Z] \(.*\)/\1/g' |    # Extract the symbol names
              sort)                                    # Sort symbol names
    ;;
  Darwin*)
    outputs="$(nm -C $ssl_lib)"$'\n'"$(nm -C $crypto_lib)"
    symbols=$(echo "$outputs" | 
              grep '^[0-9a-f]* [A-Z] ' |               # Only public symbols
              grep -v ' bssl::' |                      # Filter BoringSSL symbols since they are already namespaced
              sed 's/(.*//g' |                         # Remove parenthesis from C++ symbols
              grep '^[0-9a-f]* [A-Z] _' |              # Filter symbols that is not prefixed with '_'
              sed 's/[0-9a-f]* [A-Z] _\(.*\)/\1/g' |   # Extract the symbol names
              sort)                                    # Sort symbol names
    ;;
  *)
    echo "Supports only Linux and Darwin but this system is $unameOut"
    exit 1
    ;;
esac

commit=$(git submodule | grep "boringssl-with-bazel " | awk '{print $1}' | head -n 1)

echo "# Automatically generated by tools/distrib/generate_grpc_shadow_boringssl_symbol_list.sh" > $symbol_list
echo $commit >> $symbol_list
echo "$symbols" >> $symbol_list

exit 0

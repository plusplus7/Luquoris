# Pinned local runtime downloaded for the isolated development experiment.
set(runtime_lib "${LOQUIRIS_STREAMING_RUNTIME}/jniLibs/arm64-v8a")
file(SHA256 "${runtime_lib}/libsherpa-onnx-c-api.so" capi_sha)
file(SHA256 "${runtime_lib}/libonnxruntime.so" onnx_sha)
file(SHA256 "${LOQUIRIS_STREAMING_RUNTIME}/include/sherpa-onnx/c-api/c-api.h" header_sha)
if(NOT capi_sha STREQUAL "c85e2382e2ca12b0513826be926eaccfea896b4cbf568182e287671ba526f80d"
   OR NOT onnx_sha STREQUAL "33847ad43bffe204699fd4a27f7f3603452a8cdaf2f9a44983a0bc31ffcf2da1"
   OR NOT header_sha STREQUAL "2a1b95084be8fd1deb3228fcad2fd3f7f0258b64582f7402281ec174c7b7f4ce")
    message(FATAL_ERROR "streaming_spike_runtime_hash_mismatch")
endif()
add_library(streaming_capi SHARED IMPORTED)
set_target_properties(streaming_capi PROPERTIES IMPORTED_LOCATION "${runtime_lib}/libsherpa-onnx-c-api.so")
add_library(streaming_onnx SHARED IMPORTED)
set_target_properties(streaming_onnx PROPERTIES IMPORTED_LOCATION "${runtime_lib}/libonnxruntime.so")
add_library(loquiris_streaming_debug SHARED streaming_jni.cpp)
target_include_directories(loquiris_streaming_debug PRIVATE "${LOQUIRIS_STREAMING_RUNTIME}/include")
target_compile_options(loquiris_streaming_debug PRIVATE -Wall -Wextra -Werror)
target_link_options(loquiris_streaming_debug PRIVATE "-Wl,-rpath-link,${runtime_lib}")
target_link_libraries(loquiris_streaming_debug PRIVATE streaming_capi streaming_onnx)

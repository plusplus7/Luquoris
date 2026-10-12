#include <jni.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <limits>
#include <memory>
#include <mutex>
#include <new>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

#include "whisper.h"

namespace {

constexpr jint kSampleRateHz = 16000;
constexpr jint kMaxPcmSamples = 60 * kSampleRateHz;

thread_local const char *last_error_code = nullptr;
std::atomic<jlong> next_handle{1};

struct ContextHolder {
  using OwnedContext =
      std::unique_ptr<whisper_context, decltype(&whisper_free)>;

  explicit ContextHolder(OwnedContext value) : context(std::move(value)) {}

  OwnedContext context;
  std::mutex inference_mutex;
};

struct RunHolder {
  std::atomic<bool> cancelled{false};
};

struct Segment {
  jlong start_milliseconds;
  jlong end_milliseconds;
  std::string text;
};

struct ResultHolder {
  std::vector<Segment> segments;
};

struct SegmentReference {
  std::shared_ptr<ResultHolder> result;
  size_t index;
};

std::mutex handles_mutex;
std::unordered_map<jlong, std::shared_ptr<ContextHolder>> contexts;
std::unordered_map<jlong, std::shared_ptr<RunHolder>> runs;
std::unordered_map<jlong, std::shared_ptr<ResultHolder>> results;

void set_error(const char *code) { last_error_code = code; }

void clear_error() { last_error_code = nullptr; }

jlong allocate_handle() {
  const jlong handle = next_handle.fetch_add(1, std::memory_order_relaxed);
  if (handle <= 0 || handle == std::numeric_limits<jlong>::max()) {
    throw std::overflow_error("native handle space exhausted");
  }
  return handle;
}

template <typename T>
std::shared_ptr<T>
find_handle(const std::unordered_map<jlong, std::shared_ptr<T>> &map,
            jlong handle) {
  std::lock_guard<std::mutex> lock(handles_mutex);
  const auto item = map.find(handle);
  return item == map.end() ? nullptr : item->second;
}

template <typename T>
void erase_handle(std::unordered_map<jlong, std::shared_ptr<T>> &map,
                  jlong handle) {
  std::lock_guard<std::mutex> lock(handles_mutex);
  map.erase(handle);
}

template <typename T>
jlong publish_handle(std::unordered_map<jlong, std::shared_ptr<T>> &map,
                     std::shared_ptr<T> value) {
  const jlong handle = allocate_handle();
  std::lock_guard<std::mutex> lock(handles_mutex);
  map.emplace(handle, std::move(value));
  return handle;
}

std::string read_utf8(JNIEnv *env, jstring value) {
  if (value == nullptr) {
    throw std::invalid_argument("null string");
  }
  const char *characters = env->GetStringUTFChars(value, nullptr);
  if (characters == nullptr) {
    if (env->ExceptionCheck()) {
      env->ExceptionClear();
    }
    throw std::bad_alloc();
  }
  std::string result;
  try {
    result.assign(characters);
  } catch (...) {
    env->ReleaseStringUTFChars(value, characters);
    throw;
  }
  env->ReleaseStringUTFChars(value, characters);
  return result;
}

bool should_abort(void *user_data) {
  auto *run = static_cast<RunHolder *>(user_data);
  return run != nullptr && run->cancelled.load(std::memory_order_relaxed);
}

int inference_thread_count() {
  const unsigned int available = std::thread::hardware_concurrency();
  return static_cast<int>(
      std::max(1U, std::min(4U, available == 0 ? 1U : available)));
}

jlong add_milliseconds(jlong base, int64_t centiseconds) {
  const int64_t non_negative = std::max<int64_t>(0, centiseconds);
  if (non_negative > (std::numeric_limits<jlong>::max() - base) / 10) {
    throw std::overflow_error("segment timestamp overflow");
  }
  return base + non_negative * 10;
}

std::optional<SegmentReference> find_segment(jlong result_handle, jint index) {
  const auto result = find_handle(results, result_handle);
  if (result == nullptr || index < 0 ||
      static_cast<size_t>(index) >= result->segments.size()) {
    set_error("transcription_native_invalid_handle");
    return std::nullopt;
  }
  return SegmentReference{result, static_cast<size_t>(index)};
}

} // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeCreateContext(
    JNIEnv *env, jobject, jstring model_path) {
  try {
    const std::string path = read_utf8(env, model_path);
    if (path.empty()) {
      set_error("transcription_native_input_invalid");
      return 0;
    }
    whisper_context_params params = whisper_context_default_params();
    params.use_gpu = false;
    params.flash_attn = false;
    whisper_context *raw_context =
        whisper_init_from_file_with_params(path.c_str(), params);
    if (raw_context == nullptr) {
      set_error("transcription_model_load_failed");
      return 0;
    }
    ContextHolder::OwnedContext context(raw_context, &whisper_free);
    clear_error();
    return publish_handle(
        contexts, std::make_shared<ContextHolder>(std::move(context)));
  } catch (const std::bad_alloc &) {
    set_error("transcription_native_out_of_memory");
    return 0;
  } catch (...) {
    set_error("transcription_model_load_failed");
    return 0;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeFreeContext(
    JNIEnv *, jobject, jlong handle) {
  try {
    erase_handle(contexts, handle);
    clear_error();
  } catch (...) {
    set_error("transcription_native_failed");
  }
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeCreateRun(JNIEnv *,
                                                                      jobject) {
  try {
    clear_error();
    return publish_handle(runs, std::make_shared<RunHolder>());
  } catch (const std::bad_alloc &) {
    set_error("transcription_native_out_of_memory");
    return 0;
  } catch (...) {
    set_error("transcription_native_failed");
    return 0;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeCancelRun(
    JNIEnv *, jobject, jlong handle) {
  try {
    const auto run = find_handle(runs, handle);
    if (run == nullptr) {
      set_error("transcription_native_invalid_handle");
      return;
    }
    run->cancelled.store(true, std::memory_order_relaxed);
    clear_error();
  } catch (...) {
    set_error("transcription_native_failed");
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeFreeRun(
    JNIEnv *, jobject, jlong handle) {
  try {
    erase_handle(runs, handle);
    clear_error();
  } catch (...) {
    set_error("transcription_native_failed");
  }
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeTranscribePcm(
    JNIEnv *env, jobject, jlong context_handle, jlong run_handle,
    jshortArray pcm, jlong window_start_milliseconds, jstring language_hint) {
  try {
    const auto context = find_handle(contexts, context_handle);
    const auto run = find_handle(runs, run_handle);
    if (context == nullptr || run == nullptr) {
      set_error("transcription_native_invalid_handle");
      return 0;
    }
    if (pcm == nullptr || language_hint == nullptr || window_start_milliseconds < 0 ||
        window_start_milliseconds >
            std::numeric_limits<jlong>::max() - 60'000) {
      set_error("transcription_native_input_invalid");
      return 0;
    }
    const jsize sample_count = env->GetArrayLength(pcm);
    if (sample_count <= 0 || sample_count > kMaxPcmSamples) {
      set_error("transcription_native_input_invalid");
      return 0;
    }
    if (run->cancelled.load(std::memory_order_relaxed)) {
      set_error("transcription_cancelled");
      return 0;
    }

    const std::string requested_language = read_utf8(env, language_hint);
    const char *whisper_language = "auto";
    if (requested_language == "chinese") {
      whisper_language = "zh";
    } else if (requested_language == "english") {
      whisper_language = "en";
    } else if (requested_language != "mixed") {
      set_error("transcription_native_input_invalid");
      return 0;
    }

    std::vector<jshort> input(static_cast<size_t>(sample_count));
    env->GetShortArrayRegion(pcm, 0, sample_count, input.data());
    if (env->ExceptionCheck()) {
      env->ExceptionClear();
      set_error("transcription_native_input_invalid");
      return 0;
    }
    std::vector<float> samples(static_cast<size_t>(sample_count));
    std::transform(
        input.begin(), input.end(), samples.begin(),
        [](jshort sample) { return static_cast<float>(sample) / 32768.0F; });

    whisper_full_params params =
        whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = inference_thread_count();
    params.translate = false;
    params.language = whisper_language;
    params.no_context = true;
    params.no_timestamps = false;
    params.print_special = false;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.abort_callback = should_abort;
    params.abort_callback_user_data = run.get();

    auto result = std::make_shared<ResultHolder>();
    const jlong window_end_milliseconds =
        window_start_milliseconds +
        static_cast<jlong>(sample_count) * 1000 / kSampleRateHz;
    {
      std::lock_guard<std::mutex> lock(context->inference_mutex);
      const int status =
          whisper_full(context->context.get(), params, samples.data(),
                       static_cast<int>(samples.size()));
      if (status != 0) {
        set_error(run->cancelled.load(std::memory_order_relaxed)
                      ? "transcription_cancelled"
                      : "transcription_native_inference_failed");
        return 0;
      }
      const int segment_count =
          whisper_full_n_segments(context->context.get());
      result->segments.reserve(static_cast<size_t>(std::max(0, segment_count)));
      for (int index = 0; index < segment_count; ++index) {
        const jlong start =
            std::min(window_end_milliseconds,
                     add_milliseconds(
                         window_start_milliseconds,
                         whisper_full_get_segment_t0(context->context.get(),
                                                     index)));
        const jlong end = std::min(
            window_end_milliseconds,
            std::max(start, add_milliseconds(window_start_milliseconds,
                                             whisper_full_get_segment_t1(
                                                 context->context.get(),
                                                 index))));
        const char *text =
            whisper_full_get_segment_text(context->context.get(), index);
        result->segments.push_back(
            Segment{start, end, text == nullptr ? "" : text});
      }
    }
    clear_error();
    return publish_handle(results, std::move(result));
  } catch (const std::bad_alloc &) {
    set_error("transcription_native_out_of_memory");
    return 0;
  } catch (...) {
    set_error("transcription_native_inference_failed");
    return 0;
  }
}

extern "C" JNIEXPORT jint JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeSegmentCount(
    JNIEnv *, jobject, jlong result_handle) {
  try {
    const auto result = find_handle(results, result_handle);
    if (result == nullptr ||
        result->segments.size() >
            static_cast<size_t>(std::numeric_limits<jint>::max())) {
      set_error("transcription_native_invalid_handle");
      return 0;
    }
    clear_error();
    return static_cast<jint>(result->segments.size());
  } catch (...) {
    set_error("transcription_native_failed");
    return 0;
  }
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeSegmentStartMilliseconds(
    JNIEnv *, jobject, jlong result_handle, jint index) {
  try {
    const auto segment = find_segment(result_handle, index);
    if (!segment.has_value())
      return 0;
    clear_error();
    return segment->result->segments[segment->index].start_milliseconds;
  } catch (...) {
    set_error("transcription_native_failed");
    return 0;
  }
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeSegmentEndMilliseconds(
    JNIEnv *, jobject, jlong result_handle, jint index) {
  try {
    const auto segment = find_segment(result_handle, index);
    if (!segment.has_value())
      return 0;
    clear_error();
    return segment->result->segments[segment->index].end_milliseconds;
  } catch (...) {
    set_error("transcription_native_failed");
    return 0;
  }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeSegmentText(
    JNIEnv *env, jobject, jlong result_handle, jint index) {
  try {
    const auto segment = find_segment(result_handle, index);
    if (!segment.has_value())
      return nullptr;
    jstring value = env->NewStringUTF(
        segment->result->segments[segment->index].text.c_str());
    if (value == nullptr) {
      set_error("transcription_native_failed");
      return nullptr;
    }
    clear_error();
    return value;
  } catch (...) {
    set_error("transcription_native_failed");
    return nullptr;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeFreeResult(
    JNIEnv *, jobject, jlong handle) {
  try {
    erase_handle(results, handle);
    clear_error();
  } catch (...) {
    set_error("transcription_native_failed");
  }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeEngineVersion(
    JNIEnv *env, jobject) {
  try {
    clear_error();
    return env->NewStringUTF(whisper_version());
  } catch (...) {
    set_error("transcription_native_failed");
    return nullptr;
  }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeLastErrorCode(
    JNIEnv *env, jobject) {
  try {
    return last_error_code == nullptr ? nullptr
                                      : env->NewStringUTF(last_error_code);
  } catch (...) {
    return nullptr;
  }
}

extern "C" JNIEXPORT jlongArray JNICALL
Java_com_loquiris_transcription_WhisperNativeBindings_nativeActiveHandleCounts(
    JNIEnv *env, jobject) {
  try {
    jlong counts[3];
    {
      std::lock_guard<std::mutex> lock(handles_mutex);
      counts[0] = static_cast<jlong>(contexts.size());
      counts[1] = static_cast<jlong>(runs.size());
      counts[2] = static_cast<jlong>(results.size());
    }
    jlongArray output = env->NewLongArray(3);
    if (output == nullptr)
      return nullptr;
    env->SetLongArrayRegion(output, 0, 3, counts);
    return output;
  } catch (...) {
    set_error("transcription_native_failed");
    return nullptr;
  }
}

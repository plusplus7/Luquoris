#include <jni.h>
#include <sherpa-onnx/c-api/c-api.h>
#include <cmath>
#include <limits>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
struct Session {
  bool has_input = false;
  std::unique_ptr<const SherpaOnnxOnlineRecognizer,
      decltype(&SherpaOnnxDestroyOnlineRecognizer)> recognizer{
          nullptr, SherpaOnnxDestroyOnlineRecognizer};
  std::unique_ptr<const SherpaOnnxOnlineStream,
      decltype(&SherpaOnnxDestroyOnlineStream)> stream{
          nullptr, SherpaOnnxDestroyOnlineStream};
};
std::mutex registry_mutex;
std::unordered_map<jlong, std::unique_ptr<Session>> registry;
jlong next_id = 1;

void ThrowNativeFailure(JNIEnv* env, const char* type, const char* message) {
  if (env->ExceptionCheck()) return;
  const auto cls = env->FindClass(type);
  if (cls) env->ThrowNew(cls, message);
}

std::string ReadPath(JNIEnv* env, jstring value) {
  if (!value) throw std::invalid_argument("streaming_path_missing");
  const char* chars = env->GetStringUTFChars(value, nullptr);
  if (!chars) throw std::bad_alloc();
  std::string path;
  try { path = chars; } catch (...) {
    env->ReleaseStringUTFChars(value, chars);
    throw;
  }
  env->ReleaseStringUTFChars(value, chars);
  if (path.empty() || path.size() > 4096) throw std::invalid_argument("streaming_path_invalid");
  return path;
}

// Sherpa returns standard UTF-8, not JNI's modified UTF-8. Preserve 4-byte text.
jobject Utf8Text(JNIEnv* env, const std::string& text, bool endpoint) {
  if (text.size() > 1024 * 1024) throw std::runtime_error("streaming_text_too_large");
  const auto bytes = env->NewByteArray(static_cast<jsize>(text.size()));
  if (!bytes) return nullptr;
  env->SetByteArrayRegion(bytes, 0, static_cast<jsize>(text.size()),
                         reinterpret_cast<const jbyte*>(text.data()));
  if (env->ExceptionCheck()) return nullptr;
  const auto string_cls = env->FindClass("java/lang/String");
  if (!string_cls) return nullptr;
  const auto string_ctor = env->GetMethodID(string_cls, "<init>", "([BLjava/lang/String;)V");
  if (!string_ctor) return nullptr;
  const auto charset = env->NewStringUTF("UTF-8");
  if (!charset) return nullptr;
  const auto string = env->NewObject(string_cls, string_ctor, bytes, charset);
  if (!string || env->ExceptionCheck()) return nullptr;
  const auto cls = env->FindClass("com/loquiris/transcription/StreamingRemoteResult$Text");
  if (!cls) return nullptr;
  const auto ctor = env->GetMethodID(cls, "<init>", "(Ljava/lang/String;Z)V");
  if (!ctor) return nullptr;
  return env->NewObject(cls, ctor, string, static_cast<jboolean>(endpoint));
}
}  // namespace

extern "C" JNIEXPORT jint JNICALL
Java_com_loquiris_spike_StreamingNativeBridge_nativeAbiVersion(JNIEnv*, jobject) {
  return 2;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_loquiris_spike_StreamingNativeBridge_nativeCreate(
    JNIEnv* env, jobject, jstring encoder, jstring decoder, jstring joiner, jstring tokens) {
  try {
    std::lock_guard<std::mutex> lock(registry_mutex);
    if (!registry.empty() || next_id == std::numeric_limits<jlong>::max())
      throw std::runtime_error("streaming_native_owner_busy");
    const auto e = ReadPath(env, encoder), d = ReadPath(env, decoder);
    const auto j = ReadPath(env, joiner), t = ReadPath(env, tokens);
    SherpaOnnxOnlineRecognizerConfig config{};
    config.feat_config.sample_rate = 16000;
    config.feat_config.feature_dim = 80;
    config.model_config.transducer.encoder = e.c_str();
    config.model_config.transducer.decoder = d.c_str();
    config.model_config.transducer.joiner = j.c_str();
    config.model_config.tokens = t.c_str();
    config.model_config.num_threads = 1;
    config.model_config.provider = "cpu";
    config.decoding_method = "greedy_search";
    config.enable_endpoint = 1;
    config.rule1_min_trailing_silence = 2.4f;
    config.rule2_min_trailing_silence = 1.2f;
    config.rule3_min_utterance_length = 20.0f;
    auto session = std::make_unique<Session>();
    session->recognizer.reset(SherpaOnnxCreateOnlineRecognizer(&config));
    if (!session->recognizer) throw std::runtime_error("streaming_native_create_failed");
    session->stream.reset(SherpaOnnxCreateOnlineStream(session->recognizer.get()));
    if (!session->stream) throw std::runtime_error("streaming_native_stream_failed");
    const auto id = next_id++;
    registry.emplace(id, std::move(session));
    return id;
  } catch (const std::bad_alloc&) {
    ThrowNativeFailure(env, "java/lang/OutOfMemoryError", "streaming_native_memory");
  } catch (...) {
    ThrowNativeFailure(env, "java/lang/IllegalStateException", "streaming_native_create_failed");
  }
  return 0;
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_loquiris_spike_StreamingNativeBridge_nativeAccept(
    JNIEnv* env, jobject, jlong id, jfloatArray samples) {
  try {
    std::lock_guard<std::mutex> lock(registry_mutex);
    const auto found = registry.find(id);
    if (found == registry.end() || !found->second->stream || !samples)
      throw std::invalid_argument("streaming_handle_invalid");
    const auto size = env->GetArrayLength(samples);
    if (size < 1 || size > 16000) throw std::invalid_argument("streaming_pcm_invalid");
    std::vector<float> data(size);
    env->GetFloatArrayRegion(samples, 0, size, data.data());
    if (env->ExceptionCheck()) return nullptr;
    for (const auto value : data) {
      if (!std::isfinite(value) || std::abs(value) > 1.0f)
        throw std::invalid_argument("streaming_pcm_invalid");
    }
    auto& session = *found->second;
    const auto* recognizer = session.recognizer.get();
    const auto* stream = session.stream.get();
    SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, data.data(), size);
    session.has_input = true;
    int decodes = 0;
    while (SherpaOnnxIsOnlineStreamReady(recognizer, stream)) {
      if (++decodes > 10000) throw std::runtime_error("streaming_decode_unbounded");
      SherpaOnnxDecodeOnlineStream(recognizer, stream);
    }
    std::unique_ptr<const SherpaOnnxOnlineRecognizerResult,
        decltype(&SherpaOnnxDestroyOnlineRecognizerResult)> result(
            SherpaOnnxGetOnlineStreamResult(recognizer, stream), SherpaOnnxDestroyOnlineRecognizerResult);
    if (!result || !result->text) throw std::runtime_error("streaming_result_missing");
    const std::string text = result->text;
    const bool endpoint = SherpaOnnxOnlineStreamIsEndpoint(recognizer, stream) != 0;
    result.reset();
    if (endpoint) {
      SherpaOnnxOnlineStreamReset(recognizer, stream);
      session.has_input = false;
    }
    return Utf8Text(env, text, endpoint);
  } catch (const std::bad_alloc&) {
    ThrowNativeFailure(env, "java/lang/OutOfMemoryError", "streaming_native_memory");
  } catch (...) {
    ThrowNativeFailure(env, "java/lang/IllegalStateException", "streaming_native_decode_failed");
  }
  return nullptr;
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_loquiris_spike_StreamingNativeBridge_nativeFinish(JNIEnv* env, jobject, jlong id) {
  try {
    std::lock_guard<std::mutex> lock(registry_mutex);
    const auto found = registry.find(id);
    if (found == registry.end() || !found->second->stream)
      throw std::invalid_argument("streaming_handle_invalid");
    auto& session = *found->second;
    // An endpoint may already have reset this stream. Never manufacture a
    // silence-only utterance or duplicate a previously finalized hypothesis.
    if (!session.has_input) {
      // Natural endpoint Reset keeps encoder/token/audio context. An explicit
      // media boundary must discard it even when there is no new text to flush.
      session.stream.reset();
      session.stream.reset(SherpaOnnxCreateOnlineStream(session.recognizer.get()));
      if (!session.stream) throw std::runtime_error("streaming_native_stream_failed");
      return Utf8Text(env, "", true);
    }
    const auto* recognizer = session.recognizer.get();
    const auto* stream = session.stream.get();
    float padding[4800]{};  // Tail context, NOT unique captured media.
    SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, padding, 4800);
    SherpaOnnxOnlineStreamInputFinished(stream);
    int decodes = 0;
    while (SherpaOnnxIsOnlineStreamReady(recognizer, stream)) {
      if (++decodes > 10000) throw std::runtime_error("streaming_decode_unbounded");
      SherpaOnnxDecodeOnlineStream(recognizer, stream);
    }
    std::unique_ptr<const SherpaOnnxOnlineRecognizerResult,
        decltype(&SherpaOnnxDestroyOnlineRecognizerResult)> result(
            SherpaOnnxGetOnlineStreamResult(recognizer, stream), SherpaOnnxDestroyOnlineRecognizerResult);
    if (!result || !result->text) throw std::runtime_error("streaming_result_missing");
    const std::string text = result->text;
    result.reset();
    // InputFinished forbids further samples on this stream. Keep the one
    // recognizer, but destroy that stream before creating its replacement.
    session.stream.reset();
    session.stream.reset(SherpaOnnxCreateOnlineStream(recognizer));
    if (!session.stream) throw std::runtime_error("streaming_native_stream_failed");
    session.has_input = false;
    return Utf8Text(env, text, true);
  } catch (const std::bad_alloc&) {
    ThrowNativeFailure(env, "java/lang/OutOfMemoryError", "streaming_native_memory");
  } catch (...) {
    ThrowNativeFailure(env, "java/lang/IllegalStateException", "streaming_native_finish_failed");
  }
  return nullptr;
}

extern "C" JNIEXPORT void JNICALL
Java_com_loquiris_spike_StreamingNativeBridge_nativeClose(JNIEnv* env, jobject, jlong id) {
  try {
    std::lock_guard<std::mutex> lock(registry_mutex);
    const auto found = registry.find(id);
    if (found == registry.end()) throw std::invalid_argument("streaming_handle_invalid");
    // Erasing destroys stream before recognizer. Return only after both void calls return.
    registry.erase(found);
  } catch (...) {
    ThrowNativeFailure(env, "java/lang/IllegalStateException", "streaming_native_release_failed");
  }
}

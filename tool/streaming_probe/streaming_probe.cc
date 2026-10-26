// Standalone file-input development probe; never linked into the recorder.
#include "sherpa-onnx/c-api/c-api.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <thread>

using Clock = std::chrono::steady_clock;

std::string JsonString(const std::string &value) {
  std::string out = "\"";
  const char *hex = "0123456789abcdef";
  for (unsigned char ch : value) {
    if (ch == '"' || ch == '\\') {
      out += '\\';
      out += static_cast<char>(ch);
    } else if (ch < 0x20) {
      out += "\\u00";
      out += hex[ch >> 4];
      out += hex[ch & 15];
    } else {
      out += static_cast<char>(ch);
    }
  }
  return out + '"';
}

double MillisSince(Clock::time_point start) {
  return std::chrono::duration<double, std::milli>(Clock::now() - start).count();
}

int RunStreamingProbe(int argc, char **argv) {
  if (argc != 7 && argc != 8) {
    throw std::runtime_error(
        "usage: probe zipformer|paraformer wav encoder decoder tokens joiner|- [paced]");
  }
  const bool paced = argc == 8;
  if (paced && std::string(argv[7]) != "paced") {
    throw std::runtime_error("optional feed mode must be paced");
  }
  const std::string kind = argv[1];
  if (kind != "zipformer" && kind != "paraformer") {
    throw std::runtime_error("unsupported candidate");
  }
  // This trusted-fixture probe is not a general-purpose untrusted WAV importer.
  // Bound the file before the C API allocates its decoded sample array.
  struct stat info {};
  if (stat(argv[2], &info) != 0 || !S_ISREG(info.st_mode) ||
      info.st_size < 44 || info.st_size > 20 * 1024 * 1024) {
    throw std::runtime_error("WAV missing, not regular, or outside byte bound");
  }
  std::unique_ptr<const SherpaOnnxWave, decltype(&SherpaOnnxFreeWave)> wave(
      SherpaOnnxReadWave(argv[2]), SherpaOnnxFreeWave);
  if (!wave || !wave->samples || wave->sample_rate != 16000 ||
      wave->num_samples <= 0 || wave->num_samples > 16000 * 600) {
    throw std::runtime_error("requires nonempty mono 16 kHz WAV, at most 10 min");
  }
  for (int i = 0; i < wave->num_samples; ++i) {
    if (!std::isfinite(wave->samples[i]) || std::abs(wave->samples[i]) > 1.0f) {
      throw std::runtime_error("invalid normalized sample");
    }
  }
  const int input_samples = wave->num_samples;
  SherpaOnnxOnlineRecognizerConfig config{};
  config.feat_config.sample_rate = 16000;
  config.feat_config.feature_dim = 80;
  config.model_config.tokens = argv[5];
  config.model_config.num_threads = 1;
  config.model_config.provider = "cpu";
  config.model_config.debug = 0;
  if (kind == "zipformer") {
    config.model_config.transducer.encoder = argv[3];
    config.model_config.transducer.decoder = argv[4];
    config.model_config.transducer.joiner = argv[6];
  } else {
    config.model_config.paraformer.encoder = argv[3];
    config.model_config.paraformer.decoder = argv[4];
  }
  config.decoding_method = "greedy_search";
  config.enable_endpoint = 1;
  config.rule1_min_trailing_silence = 2.4f;
  config.rule2_min_trailing_silence = 1.2f;
  config.rule3_min_utterance_length = 20.0f;
  std::cout << std::fixed << std::setprecision(3)
            << "{\"event\":\"config\",\"candidate\":" << JsonString(kind)
            << ",\"sample_rate\":16000,\"feature_dim\":80,\"chunk_samples\":3200,"
               "\"enable_endpoint\":true,\"endpoint_rules_s\":[2.4,1.2,20.0],"
               "\"provider\":\"cpu\",\"threads\":1,\"decoding_method\":\"greedy_search\","
               "\"feed_mode\":" << JsonString(paced ? "paced" : "unpaced")
            << "}\n" << std::flush;
  const auto load_start = Clock::now();
  std::unique_ptr<const SherpaOnnxOnlineRecognizer,
                  decltype(&SherpaOnnxDestroyOnlineRecognizer)> recognizer(
      SherpaOnnxCreateOnlineRecognizer(&config),
      SherpaOnnxDestroyOnlineRecognizer);
  if (!recognizer) throw std::runtime_error("recognizer creation failed");
  std::unique_ptr<const SherpaOnnxOnlineStream,
                  decltype(&SherpaOnnxDestroyOnlineStream)> stream(
      SherpaOnnxCreateOnlineStream(recognizer.get()), SherpaOnnxDestroyOnlineStream);
  if (!stream) throw std::runtime_error("stream creation failed");
  const double load_ms = MillisSince(load_start);
  const auto feed_start = Clock::now();
  double processing_ms = 0;
  double first_text_ms = -1;
  int through = 0;
  int chunks = 0;
  int seq = 0;
  int utterance = 1;
  std::string last_text;
  // Call only on this standalone process's owner thread. Each result is freed
  // before resetting or destroying its stream; no pointers escape the C API.
  auto consume = [&](bool input_finished) {
    int decodes = 0;
    while (SherpaOnnxIsOnlineStreamReady(recognizer.get(), stream.get())) {
      if (++decodes > 10000) throw std::runtime_error("decode readiness unbounded");
      SherpaOnnxDecodeOnlineStream(recognizer.get(), stream.get());
    }
    std::unique_ptr<const SherpaOnnxOnlineRecognizerResult,
                    decltype(&SherpaOnnxDestroyOnlineRecognizerResult)> result(
        SherpaOnnxGetOnlineStreamResult(recognizer.get(), stream.get()),
        SherpaOnnxDestroyOnlineRecognizerResult);
    if (!result || !result->text) throw std::runtime_error("result unavailable");
    const std::string text = result->text;
    const bool endpoint =
        SherpaOnnxOnlineStreamIsEndpoint(recognizer.get(), stream.get()) != 0;
    const bool final = input_finished || endpoint;
    if (text.find_first_not_of(" \r\n\t") != std::string::npos &&
        (final || text != last_text)) {
      if (first_text_ms < 0) first_text_ms = MillisSince(feed_start);
      std::cout << "{\"event\":" << JsonString(final ? "final" : "partial")
                << ",\"seq\":" << ++seq << ",\"utterance\":" << utterance
                << ",\"capture_through_samples\":" << through
                << ",\"feed_elapsed_ms\":" << MillisSince(feed_start)
                << ",\"text\":" << JsonString(text) << "}\n";
      last_text = text;
    }
    result.reset();
    if (endpoint && !input_finished) {
      SherpaOnnxOnlineStreamReset(recognizer.get(), stream.get());
      ++utterance;
      last_text.clear();
    }
  };
  while (through < input_samples) {
    const int n = std::min(3200, input_samples - through);
    if (paced) {
      // File-clock availability of the COMPLETE next chunk, not speech onset.
      // Late processing catches up without duplicating or skipping audio.
      std::this_thread::sleep_until(
          feed_start + std::chrono::microseconds((through + n) * 1000000LL / 16000));
    }
    const auto operation_start = Clock::now();
    SherpaOnnxOnlineStreamAcceptWaveform(stream.get(), 16000,
                                       wave->samples + through, n);
    through += n;
    ++chunks;
    consume(false);
    processing_ms += MillisSince(operation_start);
  }
  const auto flush_start = Clock::now();
  const float tail[4800] = {};
  SherpaOnnxOnlineStreamAcceptWaveform(stream.get(), 16000, tail, 4800);
  consume(false);
  SherpaOnnxOnlineStreamInputFinished(stream.get());
  consume(true);
  processing_ms += MillisSince(flush_start);
  const double feed_wall_ms = MillisSince(feed_start);
  stream.reset();
  recognizer.reset();
  wave.reset();
  // Void destroy calls returned. This is NOT a leak/RSS/physical-release proof.
  std::cout << "{\"event\":\"summary\",\"unique_input_samples\":" << input_samples
            << ",\"tail_padding_samples\":4800,\"accepted_chunks\":" << chunks
            << ",\"load_ms\":" << load_ms
            << ",\"accept_decode_result_ms\":" << processing_ms
            << ",\"processing_to_file_duration_ratio\":"
            << processing_ms / (input_samples / 16.0)
            << ",\"feed_wall_ms\":" << feed_wall_ms
            << ",\"first_nonempty_ms_from_feed_start\":" << first_text_ms
            << ",\"release_calls_completed\":true}\n" << std::flush;
  return 0;
}

int main(int argc, char **argv) {
  try {
    return RunStreamingProbe(argc, argv);
  } catch (const std::exception &error) {
    std::cerr << "probe failed: " << error.what() << '\n';
    return 2;
  }
}

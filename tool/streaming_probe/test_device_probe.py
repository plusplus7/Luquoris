"""Opt-in integration tests: real models, existing WAV, no microphone or APK.

Run with LOQUIRIS_STREAMING_PROBE_DEVICE=<adb serial>. The compiled probe and
pinned runtime/models must already exist in the documented task-only directory.
Changing chunk accounting, skipping inference or reporting release prematurely
must fail these tests; expected fixture length is independently fixed at 45 s.
"""

import json
import os
import subprocess
import unittest


@unittest.skipUnless(
    os.environ.get("LOQUIRIS_STREAMING_PROBE_DEVICE"),
    "requires explicitly selected streaming-probe device",
)
class StreamingDeviceProbeTest(unittest.TestCase):
    def test_paced_feed_never_delivers_future_file_audio(self):
        root = "/data/local/tmp/loquiris-streaming-spike-20261015"
        model = root + "/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17"
        result = subprocess.run(
            [os.environ.get("ADB", "adb"), "-s",
             os.environ["LOQUIRIS_STREAMING_PROBE_DEVICE"], "shell", "env",
             "LD_LIBRARY_PATH=" + root + "/lib", root + "/streaming-common-probe",
             "zipformer", model + "/test_wavs/0.wav",
             model + "/encoder-epoch-99-avg-1.onnx",
             model + "/decoder-epoch-99-avg-1.onnx", model + "/tokens.txt",
             model + "/joiner-epoch-99-avg-1.onnx", "paced"],
            capture_output=True, text=True, timeout=90, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        events = [json.loads(line) for line in result.stdout.splitlines()]
        print(result.stdout, end="", flush=True)
        self.assertEqual(events[0]["feed_mode"], "paced")
        text_events = [e for e in events if e["event"] in ("partial", "final")]
        self.assertTrue(text_events)
        for event in text_events:
            # Entire chunk must have become available on the file clock first.
            self.assertGreaterEqual(event["feed_elapsed_ms"],
                                    event["capture_through_samples"] / 16)
        self.assertEqual(events[-1]["unique_input_samples"], 720000)
        self.assertGreaterEqual(events[-1]["feed_wall_ms"], 45000)
        self.assertTrue(events[-1]["release_calls_completed"])

    def test_candidates_consume_identical_pcm_and_release(self):
        root = "/data/local/tmp/loquiris-streaming-spike-20261015"
        zip_dir = root + "/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17"
        para_dir = (
            root + "/paraformer-published/"
            "sherpa-onnx-streaming-paraformer-bilingual-zh-en"
        )
        candidates = [
            ("zipformer", zip_dir + "/encoder-epoch-99-avg-1.onnx",
             zip_dir + "/decoder-epoch-99-avg-1.onnx", zip_dir + "/tokens.txt",
             zip_dir + "/joiner-epoch-99-avg-1.onnx"),
            ("paraformer", para_dir + "/encoder.int8.onnx",
             para_dir + "/decoder.int8.onnx", para_dir + "/tokens.txt", "-"),
        ]
        for kind, encoder, decoder, tokens, joiner in candidates:
            with self.subTest(candidate=kind):
                command = [
                    os.environ.get("ADB", "adb"), "-s",
                    os.environ["LOQUIRIS_STREAMING_PROBE_DEVICE"], "shell",
                    "env", "LD_LIBRARY_PATH=" + root + "/lib",
                    root + "/streaming-common-probe", kind,
                    zip_dir + "/test_wavs/0.wav", encoder, decoder, tokens, joiner,
                ]
                result = subprocess.run(
                    command, capture_output=True, text=True, timeout=90,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                events = [json.loads(line) for line in result.stdout.splitlines()]
                print(result.stdout, end="", flush=True)
                config = events[0]
                self.assertEqual(config["event"], "config")
                self.assertEqual(config["candidate"], kind)
                self.assertEqual(config["sample_rate"], 16000)
                self.assertEqual(config["chunk_samples"], 3200)
                self.assertEqual(config["endpoint_rules_s"], [2.4, 1.2, 20.0])
                self.assertTrue(config["enable_endpoint"])
                self.assertEqual(config["provider"], "cpu")
                self.assertEqual(config["threads"], 1)
                self.assertEqual(config["feed_mode"], "unpaced")
                text_events = [e for e in events if e["event"] in ("partial", "final")]
                self.assertTrue(text_events, "real inference must produce text")
                self.assertTrue(any(e["event"] == "partial" for e in text_events))
                self.assertTrue(any(e["event"] == "final" for e in text_events))
                utterances = [e["utterance"] for e in text_events]
                self.assertEqual(utterances, sorted(utterances))
                self.assertGreater(len(set(utterances)), 1,
                                   "fixture must exercise endpoint reset")
                finalized = set()
                for event in text_events:
                    self.assertNotIn(event["utterance"], finalized,
                                     "no events after an utterance is final")
                    if event["event"] == "final":
                        finalized.add(event["utterance"])
                self.assertEqual([e["seq"] for e in text_events],
                                 list(range(1, len(text_events) + 1)))
                positions = [e["capture_through_samples"] for e in text_events]
                self.assertEqual(positions, sorted(positions))
                for event in text_events:
                    self.assertTrue(event["text"].strip())
                    self.assertGreater(event["utterance"], 0)
                    self.assertGreater(event["capture_through_samples"], 0)
                    self.assertLessEqual(event["capture_through_samples"], 720000)
                summary = events[-1]
                self.assertEqual(summary["event"], "summary")
                self.assertEqual(summary["unique_input_samples"], 720000)
                self.assertEqual(summary["tail_padding_samples"], 4800)
                self.assertEqual(summary["accepted_chunks"], 225)
                self.assertTrue(summary["release_calls_completed"])
                self.assertGreater(summary["load_ms"], 0)
                self.assertGreater(summary["accept_decode_result_ms"], 0)
                self.assertGreaterEqual(summary["first_nonempty_ms_from_feed_start"], 0)


if __name__ == "__main__":
    unittest.main()

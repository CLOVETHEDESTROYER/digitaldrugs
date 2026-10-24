"""Offline generator checks. No API requests or real speech generation."""
import contextlib
import importlib.util
import io
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import wave

spec = importlib.util.spec_from_file_location('voice_generator', Path(__file__).with_name('generate-breath-voice.py'))
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


def wav_bytes():
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(24000)
        output.writeframes(b''.join(struct.pack('<h', int(math.sin(i * math.pi / 50) * 9000)) for i in range(7200)))
    return stream.getvalue()


class VoiceGeneratorTests(unittest.TestCase):
    def testCompletePackAndReuseWithoutMoreRequests(self):
        requests = []
        def respond(request, timeout, **kwargs):
            requests.append(json.loads(request.data))
            return contextlib.closing(io.BytesIO(wav_bytes()))
        with tempfile.TemporaryDirectory() as folder, patch.object(generator, 'key', return_value='test-only-key'), \
                patch.object(generator.urllib.request, 'urlopen', side_effect=respond), contextlib.redirect_stdout(io.StringIO()):
            root = Path(folder)
            generator.generate(root, 'marin', False)
            self.assertEqual(len(requests), 16)
            self.assertTrue(all(r['voice'] == 'marin' and r['response_format'] == 'wav' for r in requests))
            pack = json.loads((root / 'manifest.json').read_text())
            self.assertEqual(len(pack['clips']), 16)
            self.assertTrue(pack['aiGenerated'])
            self.assertNotIn('test-only-key', (root / 'manifest.json').read_text())
            generator.generate(root, 'marin', False)
            self.assertEqual(len(requests), 16)
            with self.assertRaises(ValueError):
                generator.generate(root, 'cedar', False)

    def testMissingCredentialsDoesNotCreatePartialPack(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(generator, 'key', return_value=''):
            destination = Path(folder) / 'missing'
            with self.assertRaises(ValueError):
                generator.generate(destination, 'marin', False)
            self.assertFalse(destination.exists())


if __name__ == '__main__':
    unittest.main()

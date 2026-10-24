#!/usr/bin/env python3
"""Generate the reusable OpenAI breathing voice pack; never ship credentials in the app."""
import argparse
from array import array
import datetime
import hashlib
import json
import os
import shutil
import ssl
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / 'Sources/ZenWaveStudio/Resources/BreathVoice'
MODEL = 'gpt-4o-mini-tts-2025-12-15'
INSTRUCTIONS = ('You are a warm, calm breathwork guide. Speak in clear natural English with a soft, '
                'grounded, reassuring delivery. No music, sound effects, added words, or dramatic whispering. '
                'For a single word or number, say it gently but concisely in less than 0.85 seconds; '
                'do not draw out syllables. The application adds the pauses between counts. '
                'For a sentence, use an unhurried natural pace and finish within 4.5 seconds.')
CUES = {'settle': 'Find a comfortable breath. Follow the circle.',
        'finish': 'Return to your natural breathing.',
        'inhale': 'Inhale', 'hold': 'Hold', 'exhale': 'Exhale', 'pause': 'Pause'}
CUES.update({f'count-{n}': str(n) for n in range(1, 11)})


def key():
    value = os.environ.get('OPENAI_API_KEY', '').strip()
    if value:
        return value
    if sys.platform == 'darwin':
        result = subprocess.run(['security', 'find-generic-password', '-s', 'com.zenwave.openai.api-key', '-w'],
                                capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    return ''


def validate_wav(path):
    with wave.open(str(path), 'rb') as stream:
        if stream.getnframes() == 0 or stream.getnchannels() != 1 or stream.getsampwidth() != 2:
            raise ValueError(f'Invalid mono PCM speech file: {path.name}')
        return stream.getnframes() / stream.getframerate()



def prepare_wav(path, identifier):
    with wave.open(str(path), 'rb') as stream:
        rate = stream.getframerate()
        samples = array('h', stream.readframes(stream.getnframes()))
    if sys.byteorder != 'little':
        samples.byteswap()
    threshold = max(40, max(abs(x) for x in samples) * 0.015)
    active = [i for i, x in enumerate(samples) if abs(x) > threshold]
    if not active:
        raise ValueError(f'OpenAI returned silent audio for {identifier}.')
    padding = int(rate * 0.007)
    samples = samples[max(0, active[0] - padding):min(len(samples), active[-1] + padding + 1)]
    if sys.byteorder != 'little':
        samples.byteswap()
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(1); stream.setsampwidth(2); stream.setframerate(rate)
        stream.writeframes(samples.tobytes())
    maximum = 4.9 if identifier == 'settle' else 3.4 if identifier == 'finish' else 0.88
    duration = validate_wav(path)
    if duration > maximum:
        executable = shutil.which('ffmpeg')
        factor = duration / maximum
        if not executable or factor > 1.6:
            raise ValueError(f'{identifier} is too long for its cue slot. Regenerate that cue with a more concise delivery; ffmpeg is needed for minor pitch-preserving timing adjustments.')
        fitted = path.with_suffix('.fitted.wav')
        try:
            subprocess.run([executable, '-v', 'error', '-i', str(path), '-af', f'atempo={factor:.8f}',
                            '-ac', '1', '-c:a', 'pcm_s16le', str(fitted)], check=True, capture_output=True)
            if validate_wav(fitted) > maximum + 0.015:
                raise ValueError(f'{identifier} still exceeds its cue slot. Regenerate it.')
            fitted.replace(path)
        finally:
            fitted.unlink(missing_ok=True)


def generate(destination, voice, dry_run):
    manifest = {'schemaVersion': 1, 'provider': 'OpenAI', 'model': MODEL, 'voice': voice,
                'aiGenerated': True, 'disclosure': 'AI-generated voice', 'instructions': INSTRUCTIONS,
                'countDelivery': 'Concise, friendly single-number cues with app-timed one-second spacing',
                'generatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'clips': []}
    if dry_run:
        print(json.dumps({'destination': str(destination), 'model': MODEL, 'voice': voice, 'requests': len(CUES),
                          'texts': list(CUES.values())}, indent=2))
        return
    api_key = key()
    if not api_key:
        raise ValueError('Set OPENAI_API_KEY locally or use macOS Keychain service com.zenwave.openai.api-key. Do not put the key in this repository.')
    destination.mkdir(parents=True, exist_ok=True)
    # A complete manifest is the commit marker. Interrupted runs cannot publish a partial pack.
    fingerprint = {'model': MODEL, 'voice': voice, 'instructions': INSTRUCTIONS}
    marker = destination / '.generation.json'
    if marker.exists() and json.loads(marker.read_text()) != fingerprint:
        raise ValueError('An interrupted generation used different voice settings. Use another --output folder.')
    marker.write_text(json.dumps(fingerprint))
    prior = destination / 'manifest.json'
    cached = json.loads(prior.read_text()) if prior.exists() else {}
    if cached and (cached.get('model') != MODEL or cached.get('voice') != voice or cached.get('instructions') != INSTRUCTIONS):
        raise ValueError('This folder contains a different voice pack. Use another --output folder; existing assets are preserved.')
    for identifier, text in CUES.items():
        target = destination / f'{identifier}.wav'
        if target.exists():
            validate_wav(target)
        else:
            number_words = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']
            request_text = number_words[int(text) - 1] if text.isdigit() else text
            delivery = ('Say this single number once, as a clear friendly American voice counting down steadily. '
                        'Keep the utterance short and natural, approximately half a second. No drawl, whisper, '
                        'extra words, sigh, breath noises or trailing sounds. The app supplies silence between counts.') if text.isdigit() else INSTRUCTIONS
            for attempt in range(3):
                body = {'model': MODEL, 'voice': voice, 'input': request_text, 'instructions': delivery,
                        'response_format': 'wav'}
                request = urllib.request.Request('https://api.openai.com/v1/audio/speech',
                    data=json.dumps(body).encode(), headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'})
                try:
                    with urllib.request.urlopen(request, timeout=90, context=ssl.create_default_context(cafile='/etc/ssl/cert.pem' if Path('/etc/ssl/cert.pem').exists() else None)) as response:
                        audio = response.read()
                except urllib.error.HTTPError as error:
                    # Do not print headers/request bodies or credentials.
                    raise ValueError(f'OpenAI speech request failed (HTTP {error.code}) for {identifier}. Check API access/billing; completed files are retained.') from None
                with tempfile.NamedTemporaryFile(dir=destination, suffix='.wav', delete=False) as stream:
                    temporary = Path(stream.name)
                    stream.write(audio)
                try:
                    validate_wav(temporary)
                    prepare_wav(temporary, identifier)
                    temporary.replace(target)
                    break
                except ValueError:
                    if attempt == 2:
                        raise
                    print(f"Retrying concise delivery: {identifier}")
                finally:
                    temporary.unlink(missing_ok=True)
        manifest['clips'].append({'text': text, 'file': target.name, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                                  'duration': validate_wav(target)})
        print(f'Ready: {identifier}')
    staged = destination / 'manifest.json.tmp'
    staged.write_text(json.dumps(manifest, indent=2) + '\n')
    staged.replace(prior)
    print(f'Completed OpenAI {voice} pack: {destination}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--voice', choices=['marin', 'cedar', 'coral'], default='marin')
    parser.add_argument('--output', type=Path, default=DESTINATION)
    parser.add_argument('--dry-run', action='store_true')
    arguments = parser.parse_args()
    try:
        generate(arguments.output.resolve(), arguments.voice, arguments.dry_run)
    except (ValueError, OSError, urllib.error.URLError) as error:
        print(f'Voice generation stopped: {error}', file=sys.stderr)
        sys.exit(1)

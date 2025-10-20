#!/usr/bin/env python3
"""
Audiobook Generator using Eleven Labs API
Converts text or text files into high-quality audiobooks
"""

import os
import sys
import argparse
from pathlib import Path
from dotenv import load_dotenv
from elevenlabs import generate, save, set_api_key, voices

# Load environment variables
load_dotenv()


class AudiobookGenerator:
    def __init__(self, api_key=None, voice_id=None):
        """
        Initialize the Audiobook Generator

        Args:
            api_key: Eleven Labs API key (defaults to ELEVENLABS_API_KEY env var)
            voice_id: Voice ID to use (defaults to DEFAULT_VOICE_ID env var)
        """
        self.api_key = api_key or os.getenv('ELEVENLABS_API_KEY')
        if not self.api_key:
            raise ValueError(
                "API key not found. Set ELEVENLABS_API_KEY environment variable "
                "or pass api_key parameter"
            )

        set_api_key(self.api_key)
        self.voice_id = voice_id or os.getenv('DEFAULT_VOICE_ID', '21m00Tcm4TlvDq8ikWAM')

    def list_voices(self):
        """List all available voices"""
        print("Available voices:")
        print("-" * 60)
        voice_list = voices()
        for voice in voice_list:
            print(f"Name: {voice.name}")
            print(f"ID: {voice.voice_id}")
            print(f"Category: {voice.category}")
            print("-" * 60)
        return voice_list

    def read_text_from_file(self, file_path):
        """
        Read text content from a file

        Args:
            file_path: Path to the text file

        Returns:
            str: Content of the file
        """
        file_path = Path(file_path)
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")

        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()

    def generate_audiobook(self, text, output_path, voice_id=None, model="eleven_monolingual_v1"):
        """
        Generate an audiobook from text

        Args:
            text: Text content to convert to audio
            output_path: Path where the audio file will be saved
            voice_id: Voice ID to use (optional, uses default if not provided)
            model: Eleven Labs model to use
        """
        if not text:
            raise ValueError("Text content is empty")

        voice = voice_id or self.voice_id

        print(f"Generating audiobook...")
        print(f"Voice ID: {voice}")
        print(f"Model: {model}")
        print(f"Text length: {len(text)} characters")

        # Generate audio
        audio = generate(
            text=text,
            voice=voice,
            model=model
        )

        # Save to file
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        save(audio, str(output_path))
        print(f"\nAudiobook saved to: {output_path}")
        print(f"File size: {output_path.stat().st_size / 1024 / 1024:.2f} MB")

        return output_path

    def generate_from_file(self, input_file, output_path=None, voice_id=None):
        """
        Generate an audiobook from a text file

        Args:
            input_file: Path to input text file
            output_path: Path for output audio file (auto-generated if not provided)
            voice_id: Voice ID to use (optional)
        """
        input_path = Path(input_file)

        # Read text from file
        text = self.read_text_from_file(input_path)

        # Generate output filename if not provided
        if output_path is None:
            output_path = input_path.with_suffix('.mp3')

        return self.generate_audiobook(text, output_path, voice_id)


def main():
    parser = argparse.ArgumentParser(
        description='Generate audiobooks from text using Eleven Labs API'
    )

    parser.add_argument(
        '-t', '--text',
        help='Text content to convert to audio'
    )
    parser.add_argument(
        '-f', '--file',
        help='Path to text file to convert'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output audio file path (default: auto-generated)'
    )
    parser.add_argument(
        '-v', '--voice',
        help='Voice ID to use (default: from .env or Rachel)'
    )
    parser.add_argument(
        '--list-voices',
        action='store_true',
        help='List all available voices and exit'
    )
    parser.add_argument(
        '--model',
        default='eleven_monolingual_v1',
        help='Eleven Labs model to use (default: eleven_monolingual_v1)'
    )

    args = parser.parse_args()

    try:
        generator = AudiobookGenerator()

        # List voices if requested
        if args.list_voices:
            generator.list_voices()
            return 0

        # Validate input
        if not args.text and not args.file:
            parser.error("Either --text or --file must be provided")

        if args.text and args.file:
            parser.error("Cannot use both --text and --file simultaneously")

        # Generate from file
        if args.file:
            generator.generate_from_file(
                args.file,
                output_path=args.output,
                voice_id=args.voice
            )

        # Generate from text
        elif args.text:
            output_path = args.output or 'output.mp3'
            generator.generate_audiobook(
                args.text,
                output_path=output_path,
                voice_id=args.voice,
                model=args.model
            )

        print("\nAudiobook generation completed successfully!")
        return 0

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

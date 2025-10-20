#!/usr/bin/env python3
"""
Usage examples for the Audiobook Generator
"""

from audiobook_generator import AudiobookGenerator

# Example 1: Generate audiobook from direct text
def example_text_to_audio():
    generator = AudiobookGenerator()

    text = """
    Welcome to the audiobook generator!
    This is a simple example of converting text to speech
    using the Eleven Labs API.
    """

    generator.generate_audiobook(
        text=text,
        output_path='output/example_text.mp3'
    )


# Example 2: Generate audiobook from a file
def example_file_to_audio():
    generator = AudiobookGenerator()

    generator.generate_from_file(
        input_file='example.txt',
        output_path='output/example_book.mp3'
    )


# Example 3: Use a specific voice
def example_with_custom_voice():
    generator = AudiobookGenerator()

    # First, list available voices to find the one you want
    voices = generator.list_voices()

    # Then use a specific voice ID
    text = "This audiobook uses a custom voice from Eleven Labs."

    generator.generate_audiobook(
        text=text,
        output_path='output/custom_voice.mp3',
        voice_id='21m00Tcm4TlvDq8ikWAM'  # Replace with desired voice ID
    )


# Example 4: Process multiple files
def example_batch_processing():
    generator = AudiobookGenerator()

    files = ['chapter1.txt', 'chapter2.txt', 'chapter3.txt']

    for i, file in enumerate(files, 1):
        try:
            generator.generate_from_file(
                input_file=file,
                output_path=f'output/chapter_{i}.mp3'
            )
            print(f"Processed {file}")
        except FileNotFoundError:
            print(f"File {file} not found, skipping...")


if __name__ == '__main__':
    print("Run individual example functions to test the audiobook generator")
    print("Examples:")
    print("  - example_text_to_audio()")
    print("  - example_file_to_audio()")
    print("  - example_with_custom_voice()")
    print("  - example_batch_processing()")

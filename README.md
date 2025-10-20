# Audiobook Generator

Generate high-quality audiobooks from text or text files using the Eleven Labs API.

## Features

- Convert text directly to audio
- Convert text files to audiobooks
- Support for multiple voice options
- Easy-to-use command-line interface
- Python API for programmatic usage

## Prerequisites

- Python 3.7 or higher
- Eleven Labs API key (get one at https://elevenlabs.io)

## Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd hello-world
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up your API key:
```bash
cp .env.example .env
```

Edit `.env` and add your Eleven Labs API key:
```
ELEVENLABS_API_KEY=your_api_key_here
```

## Usage

### Command Line Interface

Generate audiobook from text:
```bash
python audiobook_generator.py --text "Your text here" --output my_audiobook.mp3
```

Generate audiobook from a file:
```bash
python audiobook_generator.py --file example.txt --output example.mp3
```

List available voices:
```bash
python audiobook_generator.py --list-voices
```

Use a specific voice:
```bash
python audiobook_generator.py --file example.txt --voice <voice-id> --output custom_voice.mp3
```

### Python API

```python
from audiobook_generator import AudiobookGenerator

# Initialize generator
generator = AudiobookGenerator()

# Generate from text
generator.generate_audiobook(
    text="Your text content here",
    output_path="output.mp3"
)

# Generate from file
generator.generate_from_file(
    input_file="book.txt",
    output_path="audiobook.mp3"
)

# List available voices
generator.list_voices()
```

## Examples

Check out `usage_examples.py` for more detailed examples including:
- Direct text to audio conversion
- File to audio conversion
- Using custom voices
- Batch processing multiple files

Run the example:
```bash
python audiobook_generator.py --file example.txt
```

## Configuration

You can configure the following options in your `.env` file:

- `ELEVENLABS_API_KEY`: Your Eleven Labs API key (required)
- `DEFAULT_VOICE_ID`: Default voice ID to use (optional, defaults to Rachel)

## Available Models

- `eleven_monolingual_v1`: English-only model (default)
- `eleven_multilingual_v1`: Supports multiple languages
- `eleven_turbo_v2`: Faster generation with good quality

Specify model with `--model` flag:
```bash
python audiobook_generator.py --file text.txt --model eleven_turbo_v2
```

## Output

Generated audiobooks are saved as MP3 files. The output location can be:
- Specified with `--output` flag
- Auto-generated based on input filename
- Placed in `output/` directory for programmatic usage

## Troubleshooting

**API Key Error**: Make sure your `.env` file contains a valid `ELEVENLABS_API_KEY`

**File Not Found**: Ensure the input file path is correct and the file exists

**Voice ID Error**: List available voices with `--list-voices` and use a valid voice ID

## API Rate Limits

Be aware of Eleven Labs API rate limits and quotas for your subscription tier. Check your usage at https://elevenlabs.io/app/usage

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

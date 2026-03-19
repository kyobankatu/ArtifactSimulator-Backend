# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Run locally:**
```bash
python main.py
```

**Run with Gunicorn (production):**
```bash
gunicorn main:app
```

**Build and run with Docker:**
```bash
docker build -t artifact-simulator .
docker run -p 5000:5000 -e GOOGLE_CLOUD_VISION_API_KEY=<api-key> artifact-simulator
```

The app requires a `GOOGLE_CLOUD_VISION_API_KEY` environment variable for the image scanning endpoint.

## Architecture

Single-file Flask app (`main.py`) with two main classes and three API endpoints.

### Classes

**`ArtifactReader`** — Processes artifact screenshots via Google Cloud Vision OCR:
- Converts image to grayscale/binary before OCR
- Parses extracted text to identify sub-options, main stat, artifact position, and level
- Calculates the current score based on active sub-options
- Handles the Luna 1+ system where the 4th option is visible before reinforcement

**`Calculator`** — Computes probability distributions using dynamic programming:
- `getDistribution()` — Base case: calculates all possible score outcomes after reinforcing an artifact
- `getDistributionElixir()` — Extends base case to account for the elixir system (minimum upgrade guarantees on a 2-turn cycle)
- Both methods handle the pre-Luna 1 (unknown 4th option) vs. post-Luna 1 (known 4th option) distinction by iterating over possible 4th-option scenarios when needed

### API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /scan-img` | Accepts a base64-encoded image, returns artifact data (options, score, position, level) |
| `POST /get-dist` | Accepts artifact state + scoring config, returns a base64-encoded bar chart of the score distribution |
| `POST /get-data` | Accepts artifact state + scoring config, returns statistics (percentiles, mean, variance, skewness, kurtosis) |

### Game System Details

- **Scoring types:** `atk`, `hp`, `em` — each maps sub-option values differently (crit-rate ×2, em ÷4, others ×1)
- **Score unit:** All values internally use ×10 integer math to avoid floating-point issues
- **Stat upgrade tables:** `CRIT`, `ATK`, `HP`, `EM` arrays define the 4 possible upgrade magnitudes per stat
- **Luna 1+ system:** The `is_4th_op_active` flag in requests indicates whether the 4th sub-option is already visible (post-Luna 1), which affects how distributions are calculated
- **Elixir system:** Guarantees a minimum roll on every 2nd upgrade; toggled via `use_elixir` in requests

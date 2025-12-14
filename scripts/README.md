# Face Recognition Data Augmentation

This directory contains scripts for augmenting face recognition training data.

## augment_faces.py

A Python script that performs data augmentation on face images to improve face recognition model training.

### Features

- **Multiple Augmentation Techniques:**
  - Random rotation (-15° to +15°)
  - Brightness adjustment (0.7x to 1.3x)
  - Contrast adjustment (0.8x to 1.2x)
  - Horizontal flip
  - Gaussian noise addition
  - Zoom variations (0.9x to 1.1x)

- **Batch Processing:** Process entire directories of images
- **Configurable:** Customize number of augmentations and transformations per image
- **Reproducible:** Set random seed for consistent results

### Requirements

Install required dependencies:

```bash
pip install opencv-python numpy
```

### Usage

Basic usage:

```bash
python scripts/augment_faces.py --input_dir ./faces --output_dir ./augmented_faces
```

With custom parameters:

```bash
python scripts/augment_faces.py \
  --input_dir ./faces \
  --output_dir ./augmented_faces \
  --augmentations_per_image 10 \
  --num_transforms 3 \
  --seed 42
```

### Parameters

- `--input_dir`: Directory containing input face images (required)
- `--output_dir`: Directory to save augmented images (required)
- `--augmentations_per_image`: Number of augmented versions per image (default: 5)
- `--num_transforms`: Number of transformations to apply per augmentation (default: 2)
- `--seed`: Random seed for reproducibility (default: 42)

### Example

If you have 10 face images and use `--augmentations_per_image 5`, you'll get:
- 10 original images (copied to output)
- 50 augmented images (5 per original)
- **Total: 60 images** in the output directory

This increases your training dataset size by 6x!

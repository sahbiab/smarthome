"""
Face Recognition Data Augmentation Script

This script performs data augmentation on face images to improve
face recognition model training by generating variations of existing images.

Usage:
    python augment_faces.py --input_dir <input_directory> --output_dir <output_directory> --augmentations_per_image <number>

Example:
    python augment_faces.py --input_dir ./faces --output_dir ./augmented_faces --augmentations_per_image 5
"""

import os
import argparse
import cv2
import numpy as np
from pathlib import Path
import random


class FaceAugmenter:
    """Handles various image augmentation techniques for face images."""
    
    def __init__(self, seed=42):
        """Initialize the augmenter with a random seed for reproducibility."""
        random.seed(seed)
        np.random.seed(seed)
    
    def rotate(self, image, angle_range=(-15, 15)):
        """Rotate image by a random angle within the specified range."""
        angle = random.uniform(angle_range[0], angle_range[1])
        height, width = image.shape[:2]
        center = (width // 2, height // 2)
        
        rotation_matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
        rotated = cv2.warpAffine(image, rotation_matrix, (width, height), 
                                  borderMode=cv2.BORDER_REFLECT)
        return rotated
    
    def adjust_brightness(self, image, factor_range=(0.7, 1.3)):
        """Adjust image brightness by a random factor."""
        factor = random.uniform(factor_range[0], factor_range[1])
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        hsv = hsv.astype(np.float32)
        hsv[:, :, 2] = hsv[:, :, 2] * factor
        hsv[:, :, 2] = np.clip(hsv[:, :, 2], 0, 255)
        hsv = hsv.astype(np.uint8)
        return cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)
    
    def adjust_contrast(self, image, factor_range=(0.8, 1.2)):
        """Adjust image contrast by a random factor."""
        factor = random.uniform(factor_range[0], factor_range[1])
        mean = np.mean(image)
        contrasted = (image - mean) * factor + mean
        return np.clip(contrasted, 0, 255).astype(np.uint8)
    
    def horizontal_flip(self, image):
        """Flip image horizontally."""
        return cv2.flip(image, 1)
    
    def add_gaussian_noise(self, image, mean=0, std_range=(5, 15)):
        """Add Gaussian noise to the image."""
        std = random.uniform(std_range[0], std_range[1])
        noise = np.random.normal(mean, std, image.shape).astype(np.float32)
        noisy_image = image.astype(np.float32) + noise
        return np.clip(noisy_image, 0, 255).astype(np.uint8)
    
    def zoom(self, image, zoom_range=(0.9, 1.1)):
        """Apply random zoom to the image."""
        zoom_factor = random.uniform(zoom_range[0], zoom_range[1])
        height, width = image.shape[:2]
        
        new_height, new_width = int(height * zoom_factor), int(width * zoom_factor)
        resized = cv2.resize(image, (new_width, new_height))
        
        if zoom_factor > 1:
            # Crop center
            start_y = (new_height - height) // 2
            start_x = (new_width - width) // 2
            return resized[start_y:start_y + height, start_x:start_x + width]
        else:
            # Pad to original size
            pad_y = (height - new_height) // 2
            pad_x = (width - new_width) // 2
            return cv2.copyMakeBorder(resized, pad_y, height - new_height - pad_y,
                                       pad_x, width - new_width - pad_x,
                                       cv2.BORDER_REFLECT)
    
    def augment(self, image, augmentation_type=None):
        """
        Apply a specific augmentation or random augmentation to the image.
        
        Args:
            image: Input image
            augmentation_type: Type of augmentation to apply. If None, applies random augmentation.
        
        Returns:
            Augmented image
        """
        augmentations = {
            'rotate': self.rotate,
            'brightness': self.adjust_brightness,
            'contrast': self.adjust_contrast,
            'flip': self.horizontal_flip,
            'noise': self.add_gaussian_noise,
            'zoom': self.zoom
        }
        
        if augmentation_type is None:
            augmentation_type = random.choice(list(augmentations.keys()))
        
        return augmentations[augmentation_type](image)
    
    def augment_multiple(self, image, num_augmentations=2):
        """
        Apply multiple random augmentations to the image.
        
        Args:
            image: Input image
            num_augmentations: Number of augmentations to apply
        
        Returns:
            Augmented image
        """
        augmented = image.copy()
        augmentation_types = random.sample(['rotate', 'brightness', 'contrast', 
                                            'noise', 'zoom'], 
                                           min(num_augmentations, 5))
        
        for aug_type in augmentation_types:
            augmented = self.augment(augmented, aug_type)
        
        # Randomly apply flip (50% chance)
        if random.random() > 0.5:
            augmented = self.horizontal_flip(augmented)
        
        return augmented


def process_directory(input_dir, output_dir, augmentations_per_image=5, 
                      num_transforms_per_aug=2):
    """
    Process all images in the input directory and generate augmented versions.
    
    Args:
        input_dir: Directory containing input images
        output_dir: Directory to save augmented images
        augmentations_per_image: Number of augmented versions to create per image
        num_transforms_per_aug: Number of transformations to apply per augmentation
    """
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    augmenter = FaceAugmenter()
    
    # Supported image extensions
    image_extensions = {'.jpg', '.jpeg', '.png', '.bmp'}
    
    # Get all image files
    image_files = [f for f in input_path.iterdir() 
                   if f.suffix.lower() in image_extensions]
    
    if not image_files:
        print(f"No images found in {input_dir}")
        return
    
    print(f"Found {len(image_files)} images in {input_dir}")
    print(f"Generating {augmentations_per_image} augmentations per image...")
    
    total_generated = 0
    
    for img_file in image_files:
        # Read original image
        image = cv2.imread(str(img_file))
        
        if image is None:
            print(f"Warning: Could not read {img_file.name}, skipping...")
            continue
        
        # Save original image to output directory
        original_output = output_path / img_file.name
        cv2.imwrite(str(original_output), image)
        
        # Generate augmented versions
        for i in range(augmentations_per_image):
            augmented = augmenter.augment_multiple(image, num_transforms_per_aug)
            
            # Create output filename
            name_without_ext = img_file.stem
            ext = img_file.suffix
            output_filename = f"{name_without_ext}_aug_{i+1}{ext}"
            output_filepath = output_path / output_filename
            
            # Save augmented image
            cv2.imwrite(str(output_filepath), augmented)
            total_generated += 1
        
        print(f"Processed {img_file.name}: generated {augmentations_per_image} augmentations")
    
    print(f"\nAugmentation complete!")
    print(f"Original images: {len(image_files)}")
    print(f"Augmented images: {total_generated}")
    print(f"Total images: {len(image_files) + total_generated}")
    print(f"Output directory: {output_path.absolute()}")


def main():
    """Main function to parse arguments and run augmentation."""
    parser = argparse.ArgumentParser(
        description='Augment face images for improved face recognition training'
    )
    
    parser.add_argument(
        '--input_dir',
        type=str,
        required=True,
        help='Directory containing input face images'
    )
    
    parser.add_argument(
        '--output_dir',
        type=str,
        required=True,
        help='Directory to save augmented images'
    )
    
    parser.add_argument(
        '--augmentations_per_image',
        type=int,
        default=5,
        help='Number of augmented versions to create per image (default: 5)'
    )
    
    parser.add_argument(
        '--num_transforms',
        type=int,
        default=2,
        help='Number of transformations to apply per augmentation (default: 2)'
    )
    
    parser.add_argument(
        '--seed',
        type=int,
        default=42,
        help='Random seed for reproducibility (default: 42)'
    )
    
    args = parser.parse_args()
    
    # Set random seed
    random.seed(args.seed)
    np.random.seed(args.seed)
    
    # Process directory
    process_directory(
        args.input_dir,
        args.output_dir,
        args.augmentations_per_image,
        args.num_transforms
    )


if __name__ == '__main__':
    main()

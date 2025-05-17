#!/usr/bin/env python3
from PIL import Image
import os

# Define iOS icon sizes needed
sizes = [1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29, 20]

def resize_icon(source_image_path, output_dir):
    # Open the source image
    try:
        source_image = Image.open(source_image_path)
        print(f"Opened source image: {source_image_path}")
    except Exception as e:
        print(f"Error opening source image: {e}")
        return
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate all required sizes
    for size in sizes:
        output_path = os.path.join(output_dir, f"icon_{size}.png")
        try:
            # Resize the image with high quality
            resized_image = source_image.resize((size, size), Image.LANCZOS)
            resized_image.save(output_path)
            print(f"Created icon {size}x{size}px: {output_path}")
        except Exception as e:
            print(f"Error creating {size}x{size} icon: {e}")

if __name__ == "__main__":
    # Source image path
    source_path = "/Users/meetri/Documents/dev/apps/voicejournal/dalle-1746388708791.png"
    # Output directory (app-icon folder)
    output_dir = os.path.dirname(os.path.abspath(__file__))
    
    if not os.path.exists(source_path):
        print(f"Source image not found at: {source_path}")
    else:
        resize_icon(source_path, output_dir)
        print(f"Icon generation complete. Icons saved to: {output_dir}")
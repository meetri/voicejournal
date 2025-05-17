#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import os

# Create the base icon
def create_voicejournal_icon(save_path, size=1024):
    # Create a new image with a white background
    icon = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(icon)
    
    # Rounded square background with gradient
    # Create a mask for the rounded corners
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = size // 5  # Adjust for desired roundness
    mask_draw.rounded_rectangle([(0, 0), (size, size)], corner_radius, fill=255)
    
    # Create gradient background
    gradient = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gradient_draw = ImageDraw.Draw(gradient)
    
    # Blue gradient (from lighter to darker)
    for y in range(size):
        # Calculate color based on position
        r = int(41 + (33 - 41) * y / size)  # Darker blue at bottom
        g = int(128 + (76 - 128) * y / size)
        b = int(185 + (156 - 185) * y / size)
        gradient_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    
    # Apply the mask to the gradient
    icon.paste(gradient, (0, 0), mask)
    
    # Draw a stylized journal/notebook page
    page_width = size * 0.7
    page_height = size * 0.8
    page_x = (size - page_width) / 2
    page_y = (size - page_height) / 2
    
    # Create another mask for the page with slightly rounded corners
    page_mask = Image.new('L', (size, size), 0)
    page_mask_draw = ImageDraw.Draw(page_mask)
    page_corner_radius = size // 20
    page_mask_draw.rounded_rectangle([(page_x, page_y), (page_x + page_width, page_y + page_height)], 
                                   page_corner_radius, fill=255)
    
    # Create the page with a subtle gradient
    page = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    page_draw = ImageDraw.Draw(page)
    
    # White to very light blue gradient for the page
    for y in range(int(page_y), int(page_y + page_height)):
        progress = (y - page_y) / page_height
        # Very subtle gradient from white to light blue-gray
        r = int(255 - 10 * progress)
        g = int(255 - 5 * progress)
        b = int(255)
        page_draw.line([(page_x, y), (page_x + page_width, y)], fill=(r, g, b, 255))
    
    # Add a subtle shadow to the page
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_offset = size // 50
    shadow_draw.rounded_rectangle(
        [(page_x + shadow_offset, page_y + shadow_offset), 
         (page_x + page_width + shadow_offset, page_y + page_height + shadow_offset)], 
        page_corner_radius, fill=(0, 0, 0, 50))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size // 100))
    
    # Composite the shadow onto the icon first (so it's behind the page)
    icon = Image.alpha_composite(icon, shadow)
    
    # Then apply the page mask to the page and paste it onto the icon
    icon.paste(page, (0, 0), page_mask)
    
    # Draw sound wave lines in the middle of the page
    wave_height = page_height * 0.5
    wave_width = page_width * 0.7
    wave_x = (size - wave_width) / 2
    wave_y = (size - wave_height) / 2 + size * 0.05  # Slightly above center
    
    # Generate sound wave points
    num_lines = 7
    line_spacing = wave_width / (num_lines - 1)
    max_amplitude = wave_height * 0.25
    
    # The central line should be tallest, with lines tapering off to sides
    amplitudes = []
    for i in range(num_lines):
        # Position from center (0 = center, 1 = edge)
        distance_from_center = abs(i - (num_lines - 1) / 2) / ((num_lines - 1) / 2)
        # Smaller amplitude as we move away from center
        amplitude = max_amplitude * (1 - 0.8 * distance_from_center**2)
        amplitudes.append(amplitude)
    
    # Draw the sound wave lines with gradient color
    wave_overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    wave_draw = ImageDraw.Draw(wave_overlay)
    
    for i in range(num_lines):
        x = wave_x + i * line_spacing
        amplitude = amplitudes[i]
        
        # Central position determines color intensity
        center_factor = 1 - abs(i - (num_lines - 1) / 2) / ((num_lines - 1) / 2)
        
        # Gradient from purple to blue
        r = int(89 + (41 - 89) * center_factor)
        g = int(65 + (128 - 65) * center_factor)
        b = int(169 + (185 - 169) * center_factor)
        
        line_width = max(2, int(size * 0.015 * (0.5 + 0.5 * center_factor)))  # Thicker in center
        
        # Draw rounded line segments
        wave_draw.rounded_rectangle(
            [(x - line_width/2, wave_y + wave_height/2 - amplitude),
             (x + line_width/2, wave_y + wave_height/2 + amplitude)],
            radius=line_width/2,
            fill=(r, g, b, 240)
        )
    
    # Add a subtle glow effect to the wave
    glow = wave_overlay.copy()
    glow = glow.filter(ImageFilter.GaussianBlur(size // 50))
    
    # Composite the glow and wave onto the icon
    wave_mask = Image.new('L', (size, size), 0)
    wave_mask_draw = ImageDraw.Draw(wave_mask)
    wave_mask_draw.rounded_rectangle([(page_x, page_y), (page_x + page_width, page_y + page_height)], 
                                   page_corner_radius, fill=255)
    
    # Apply mask to ensure glow stays within page boundaries
    glow_masked = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_masked.paste(glow, (0, 0), wave_mask)
    
    # Composite onto main image
    icon = Image.alpha_composite(icon, glow_masked)
    icon = Image.alpha_composite(icon, wave_overlay)
    
    # Add horizontal notebook lines on the page
    line_spacing = page_height / 8
    line_color = (200, 210, 230, 100)  # Very light gray-blue, semi-transparent
    
    for i in range(1, 8):
        y_pos = page_y + i * line_spacing
        draw.line([(page_x + page_width * 0.1, y_pos), (page_x + page_width * 0.9, y_pos)], 
                 fill=line_color, width=max(1, int(size * 0.002)))
    
    # Save the icon
    icon.save(save_path)
    return icon

# Create various sizes for iOS
def create_ios_icon_set(base_path):
    sizes = [1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29, 20]
    icon_paths = {}
    
    # Create the base icon at 1024x1024
    base_icon = create_voicejournal_icon(os.path.join(base_path, "icon_1024.png"), 1024)
    icon_paths[1024] = os.path.join(base_path, "icon_1024.png")
    
    # Create other sizes by scaling down
    for size in sizes:
        if size != 1024:  # Skip the base size which we already created
            scaled_icon = base_icon.resize((size, size), Image.LANCZOS)
            file_path = os.path.join(base_path, f"icon_{size}.png")
            scaled_icon.save(file_path)
            icon_paths[size] = file_path
    
    return icon_paths

if __name__ == "__main__":
    # Create the icon set
    base_path = os.path.dirname(os.path.abspath(__file__))
    icons = create_ios_icon_set(base_path)
    print(f"Created icon set at: {base_path}")
    for size, path in icons.items():
        print(f"Icon {size}x{size}px: {path}")
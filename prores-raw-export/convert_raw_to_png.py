#!/usr/bin/env python3
"""
Convert ProRes RAW files to PNG images with proper demosaicing.

This script converts ProRes RAW files to both interlaced grayscale and RGB PNG images.
The RGB conversion uses proper demosaicing algorithms instead of simple channel stacking.

Available demosaicing algorithms:
- bilinear: Simple bilinear interpolation (fastest)
- malvar2004: Malvar et al. 2004 algorithm (good quality)
- menon2007: Menon et al. 2007 algorithm (highest quality, default)
"""

import os
import glob
import numpy as np
from PIL import Image
import argparse
from colour_demosaicing import demosaicing_CFA_Bayer_bilinear, demosaicing_CFA_Bayer_Malvar2004, demosaicing_CFA_Bayer_Menon2007


def reconstruct_interlaced_image(r_channel, g1_channel, g2_channel, b_channel):
    """Reconstruct the original interlaced sensor image from the four channels."""
    # Original sensor resolution is 4288x2408
    # The four channels are stacked vertically in the RAW file
    # We need to interlace them back to the original RGGB pattern
    
    # Each channel has the same dimensions
    channel_height, channel_width = r_channel.shape
    
    # Create the full sensor image
    # RGGB pattern: R G R G R G ...
    #               G B G B G B ...
    full_height = channel_height * 2
    full_width = channel_width * 2
    
    # Initialize the interlaced image
    interlaced = np.zeros((full_height, full_width), dtype=np.uint16)
    
    # Use vectorized operations to fill the RGGB pattern
    # Red pixels: every other pixel starting at (0,0)
    interlaced[0::2, 0::2] = r_channel
    
    # Green pixels (G1): every other pixel starting at (0,1)
    interlaced[0::2, 1::2] = g1_channel
    
    # Green pixels (G2): every other pixel starting at (1,0)
    interlaced[1::2, 0::2] = g2_channel
    
    # Blue pixels: every other pixel starting at (1,1)
    interlaced[1::2, 1::2] = b_channel
    
    return interlaced


def demosaic_with_colour_demosaicing(interlaced_img, algorithm='menon2007'):
    """Use colour-demosaicing to perform proper demosaicing on the interlaced image."""
    # Convert to float32 for the demosaicing library
    if interlaced_img.dtype != np.float32:
        interlaced_img = interlaced_img.astype(np.float32)
    
    # Normalize the values to 0-1 range for the demosaicing library
    # Assuming 16-bit data, max value is 65535
    max_val = np.max(interlaced_img)
    if max_val > 1.0:
        interlaced_img = interlaced_img / max_val
    
    # Perform demosaicing using the specified algorithm
    # The pattern is RGGB, which corresponds to 'RGGB' in the library
    if algorithm == 'bilinear':
        rgb = demosaicing_CFA_Bayer_bilinear(interlaced_img, 'RGGB')
    elif algorithm == 'malvar2004':
        rgb = demosaicing_CFA_Bayer_Malvar2004(interlaced_img, 'RGGB')
    elif algorithm == 'menon2007':
        rgb = demosaicing_CFA_Bayer_Menon2007(interlaced_img, 'RGGB')
    else:
        # Default to Menon2007 if unknown algorithm
        rgb = demosaicing_CFA_Bayer_Menon2007(interlaced_img, 'RGGB')
    
    # Scale back to the original range
    rgb = rgb * max_val
    
    # Convert back to uint16
    rgb = np.clip(rgb, 0, 65535).astype(np.uint16)
    
    return rgb


def load_prores_raw(fn, demosaic_algorithm='menon2007'):
    """Load a ProRes RAW file and return both interlaced grayscale and RGB numpy arrays."""
    # Original sensor resolution is 4288x2408
    # Load as 4816x2144 to get the four RGGB channels stacked vertically
    # User specified WxH as 2144x4816, so numpy order is (4816, 2144)
    height, width = 4832, 2144
    padding = 248
    buffer = np.fromfile(fn, dtype=np.uint16, count=padding+width*height)
    img = buffer[padding:].reshape(height, width)
    
    # Split into four quarters (RGGB pattern)
    quarter_height = height // 4
    r_channel = img[0:quarter_height, :]  # First quarter - Red
    g1_channel = img[quarter_height:2*quarter_height, :]  # Second quarter - Green 1
    g2_channel = img[2*quarter_height:3*quarter_height, :]  # Third quarter - Green 2
    b_channel = img[3*quarter_height:4*quarter_height, :]  # Fourth quarter - Blue
    
    # Reconstruct the original interlaced sensor image
    interlaced_img = reconstruct_interlaced_image(r_channel, g1_channel, g2_channel, b_channel)
    
    # Use proper demosaicing instead of simple channel stacking
    rgb_img = demosaic_with_colour_demosaicing(interlaced_img, demosaic_algorithm)
    
    return interlaced_img, rgb_img


def convert_raw_to_png(raw_file, output_dir=None, demosaic_algorithm='menon2007'):
    """Convert a single RAW file to PNG (both interlaced grayscale and RGB)."""
    try:
        # Load the RAW file
        interlaced_img, rgb_img = load_prores_raw(raw_file, demosaic_algorithm)
        
        # Determine output filename
        base_name = os.path.splitext(os.path.basename(raw_file))[0]
        
        # Save interlaced grayscale image
        # Normalize to 0-255 range for PNG
        interlaced_normalized = np.clip(interlaced_img / 1024.0 * 255, 0, 255).astype(np.uint8)
        interlaced_pil = Image.fromarray(interlaced_normalized)  # Grayscale
        
        if output_dir:
            interlaced_path = os.path.join(output_dir, f"{base_name}_interlaced.png")
        else:
            interlaced_path = f"{base_name}_interlaced.png"
        
        interlaced_pil.save(interlaced_path)
        print(f"Converted {raw_file} -> {interlaced_path} (interlaced grayscale)")
        
        # Save RGB color image
        rgb_normalized = np.clip(rgb_img / 1024.0 * 255, 0, 255).astype(np.uint8)
        rgb_pil = Image.fromarray(rgb_normalized)
        
        if output_dir:
            rgb_path = os.path.join(output_dir, f"{base_name}_rgb.png")
        else:
            rgb_path = f"{base_name}_rgb.png"
        
        rgb_pil.save(rgb_path)
        print(f"Converted {raw_file} -> {rgb_path} (RGB color, {demosaic_algorithm} demosaicing)")
        
        return interlaced_path, rgb_path
        
    except Exception as e:
        print(f"Error converting {raw_file}: {e}")
        return None, None


def main():
    parser = argparse.ArgumentParser(description='Convert ProRes RAW files to PNG images')
    parser.add_argument('input_pattern', help='Glob pattern for RAW files (e.g., "*.raw")')
    parser.add_argument('-o', '--output-dir', help='Output directory for PNG files (default: same as input)')
    parser.add_argument('--start-frame', type=int, default=0, help='Start frame number (default: 0)')
    parser.add_argument('--end-frame', type=int, help='End frame number (default: all frames)')
    parser.add_argument('--demosaic', choices=['bilinear', 'malvar2004', 'menon2007'], 
                       default='menon2007', help='Demosaicing algorithm (default: menon2007)')
    
    args = parser.parse_args()
    
    # Find all RAW files matching the pattern
    raw_files = sorted(glob.glob(args.input_pattern))
    
    if not raw_files:
        print(f"No files found matching pattern: {args.input_pattern}")
        return
    
    print(f"Found {len(raw_files)} RAW files")
    print(f"Using {args.demosaic} demosaicing algorithm")
    
    # Create output directory if specified
    if args.output_dir and not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)
        print(f"Created output directory: {args.output_dir}")
    
    # Process files
    converted_count = 0
    for i, raw_file in enumerate(raw_files):
        # Apply frame range filtering
        if i < args.start_frame:
            continue
        if args.end_frame and i >= args.end_frame:
            break
            
        interlaced_path, rgb_path = convert_raw_to_png(raw_file, args.output_dir, args.demosaic)
        if interlaced_path and rgb_path:
            converted_count += 1
    
    print(f"\nConversion complete! Converted {converted_count} files (2 images per file).")


if __name__ == "__main__":
    main() 
# prores-raw-export

Simple command line app for converting ProRes Raw files to sequences of raw 16-bit data, pre-debayering.

This is useful in conjunction with tools that can process this raw data as a sequence of grayscale images.

## Usage

```
./prores-raw-export filename.mov [frame count]
```

Running this command will export files called `filename.mov.000000.raw`, with `000000` incrementing for each frame, in the same location as `filename.mov`

## Opening Raw Files in Photoshop

For example, for videos recorded with the Sony a7S III and the Ninja V, draw a .raw file into Photoshop with the following options:

* Width: 4288 pixels
* Height: 2408 pixels
* Count: 1
* Depth: 16 bits
* Byte Order: IBM PC
* Header Size: 0 bytes

After loading the image you will want to crop out noise (metadata?) on the right side, as the proper width is 4264 pixels.

## Opening Raw Files in Python

```python
def load_prores_raw(fn):
    height, width = 2408, 4288
    buffer = np.fromfile(fn, dtype=np.uint16, count=width*height)
    img = buffer.reshape(height, width)[:,:4264]
    return img
```

## Credit

Thanks to [Anton Marini](https://twitter.com/_vade) for providing the original code.
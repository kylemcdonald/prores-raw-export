# prores-raw-export

Simple command line app for converting ProRes Raw files to sequences of raw 16-bit data, pre-debayering.

This is useful in conjunction with tools that can process this raw data as a sequence of grayscale images.

## Usage

```
./prores-raw-export filename.mov [frame count]
```

Running this command will export files called `filename.mov.000000.raw`, with `000000` incrementing for each frame, in the same location as `filename.mov`

## Credit

Thanks to [Anton Marini](https://twitter.com/_vade) for providing the original code.
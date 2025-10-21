# Image memoriser

Tools to memorise named places in images.
This documentation was largely written by an LLM, but the human confirms that it is correct.

## Setup
- Have a working POSIX shell at `/bin/sh` with coreutils
- Install [`dmenu`]( https://tools.suckless.org/dmenu/ ) to somewhere in `$PATH`
- Install [`iv`]( https://git.dkl9.net/iv ) to `/usr/local/bin/iv` (or elsewhere, and edit `main.sh`)
- Install [ImageMagick]( https://imagemagick.org/ ) to somewhere in `$PATH`

## Usages

Run
```sh
./main.sh MODE IMAGE LABELS
```
where `MODE` is a keyword listed below, `IMAGE` is a path to an image file, and `LABELS` is a path to a text file in the data format used here.

The modes:

| Mode   | Purpose | Command example | Notes |
|--------|---------|-----------------|-------|
| label  | Middle-click on an image to assign names (creates label file) | |
| teach  | Annotate the image with labels from the file | Prompts for output filename and shows the annotated image. |
| names  | Quiz: shown each point in turn, type its label | Uses dmenu to pick a name. Wrong answers are saved to reteach. Enter `quit` in dmenu to stop early. |
| place  | Quiz: shown each label in turn, middle-click its place | A click is correct iff the nearest labelled point is the target. Mistakes are saved likewise. |
| close  | Quiz: identify nearest neighbours to given places | Expects *K* of the 2 *K* nearest neighbours. *K* defaults to 2. Mistakes are saved likewise. |

## Data format

A label file is text, with one entry per line, in the form `X Y NAME`.
- X and Y: integer pixel coordinates in the image (space-separated)
- NAME: label (may contain spaces)

For example:
```
120 340 Eiffel Tower
482 91 Notre-Dame
```

## Example sessions

1. Create a label file interactively:
   `./main.sh label map.png map.labels`
   - Click points on the image; for each click give a name when prompted.

2. Produce an annotated image with names shown:
   `./main.sh teach map.png map.labels`
   - Follow the prompt to save the annotated image (e.g. `map-annotated.png`).

3. Quiz on names (point → name):
   `./main.sh names map.png map.labels`

4. Quiz on placement (name → point):
   `./main.sh place map.png map.labels`

5. Quiz on nearby places:
   `./main.sh close map.png map.labels`

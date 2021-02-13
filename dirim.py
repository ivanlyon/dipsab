"""
Create an image centered, of images found in a single directory. No
resizing of icons will be performed.

Input:
------
    Input parameters include the final directory, width, height and padding.
Test cases are formatted in a serial fashion.
  +------------------------------------------------------------------+
  | test/dir1 0 1920 10                                              |
  +------------------------------------------------------------------+

Output:
-------
    For each test case a directory's worth of icons into a single image.
  +------------------------------------------------------------------+
  | image1.jpg                                                       |
  +------------------------------------------------------------------+
"""

import os
import re
import argparse
from PIL import Image

__version__ = "0.1.0"
__license__ = "MIT"

IMAGE_SUFFIXES = ('.jpg', '.png')

###############################################################################

def dir_path(path):
    "Test directory input command line parameter."
    if os.path.isdir(path):
        return path
    else:
        raise argparse.ArgumentTypeError(f"readable_dir:{path} is not a valid path")

###############################################################################

def sorted_filepaths(input_dir, case_sensitive, articles):

    lower_articles = '|'.join(('a', 'an', 'the'))
    cased_articles = '|'.join(('A', 'An', 'The', 'AN', 'THE')) + '|' + lower_articles

    basic_lambda = lambda x: os.path.splitext(x)[0]
    lower_lambda = lambda x: os.path.splitext(x)[0].lower()
    artlo_lambda = lambda x: re.sub("^(" + lower_articles + ") ","",os.path.splitext(x)[0].lower())
    cased_lambda = lambda x: re.sub("^(" + cased_articles + ") ","",os.path.splitext(x)[0])

    filepaths = []
    for root, folders, files in os.walk(input_dir):
        if folders:
            continue
        for filename in files:
            for i in IMAGE_SUFFIXES:
                if filename.endswith(i):
                    filepaths.append(os.path.join(root, filename))

    if case_sensitive and articles:
        filepaths = sorted(filepaths, key=basic_lambda, reverse=True)
    elif case_sensitive:
        filepaths = sorted(filepaths, key=cased_lambda, reverse=True)
    elif articles:
        filepaths = sorted(filepaths, key=artlo_lambda, reverse=True)
    else:
        filepaths = sorted(filepaths, key=lower_lambda, reverse=True)

    return filepaths

###############################################################################

def rows_filenames(input_dir, max_width, hpad, case_sensitive, articles):
    "Create a sequence of rows each containing filenames."

    row_height = 0
    row_width = max_width
    row_images = []
    rowed = []

    for file_path in sorted_filepaths(input_dir, case_sensitive, articles):
        picture = Image.open(file_path)
        img_width, img_height = picture.size
        row_height = max(row_height, img_height)

        if rowed:
            if row_width - img_width - hpad >= 0:
                row_width -= img_width + hpad
            else:
                rowed.reverse()
                row_images.append(rowed)
                rowed = []
                row_width = max_width - img_width
        else:
            row_width -= img_width

        rowed.append(file_path)

    if rowed:
        rowed.reverse()
        row_images.append(rowed)

    return row_images

###############################################################################

def dirim(cl_args):
    """Read a line of input, parse integers, throw rest of line away"""

    max_width = cl_args['width']
    hpad = cl_args['hpad']
    vpad = cl_args['vpad']
    case_sensitive = cl_args['case']
    articles = cl_args['articles']

    layers = []
    row_images = rows_filenames(cl_args['input'], max_width, hpad, case_sensitive, articles)

    total_height = vpad * (len(row_images) - 1)
    for row in row_images:
        images = map(Image.open, row)
        widths, heights = zip(*(i.size for i in images))

        max_height = max(heights)
        total_width = sum(widths) + hpad * (len(widths) - 1)
        offset_x = (max_width - total_width) // 2

        result_row = Image.new('RGBA', (max_width, max_height), color=cl_args['bgcolor'])
        images = map(Image.open, row)
        for img in row:
            showing = Image.open(img).convert('RGBA')
            bbox = (offset_x, 0, offset_x + showing.size[0], showing.size[1])
            cropped = result_row.crop(bbox)
            showing = Image.composite(showing, cropped, mask=showing)
            result_row.paste(showing, (offset_x, 0))
            offset_x += hpad + showing.size[0]

        layers.append(result_row)
        total_height += result_row.size[1]

    layers.reverse()
    offset_y = 0
    final_image = Image.new('RGBA', (max_width, total_height), color=cl_args['bgcolor'])
    for row in layers:
        final_image.paste(row, (0, offset_y))
        offset_y += vpad + row.size[1]

    return final_image.convert("RGB") # Remove alpha to workaround JPG bug

###############################################################################

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Create an image of directory contents.')
    parser.add_argument("input", type=dir_path, help="Input directory")
    parser.add_argument("--bgcolor", help="Background color", default='black')
    parser.add_argument("--output", help="Output image path", type=argparse.FileType('wb'),
                        default='dirim.jpg')
    parser.add_argument("--height", help="Height of final image in pixels", type=int,
                        default=0)
    parser.add_argument("--width", help="Width of final image in pixels", type=int,
                        default=0)
    parser.add_argument("--vpad", help="Vertical pixels between images", type=int,
                        default=0)
    parser.add_argument("--hpad", help="Horizontal pixels between images", type=int,
                        default=0)
    parser.add_argument("--case", help="File name sorting case sensitivity", type=int,
                        default=1)
    parser.add_argument("--articles", help="File name sorting articles sensitivity", type=int,
                        default=1)

    # Specify output of "--version"
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    args.output.close()
    args.output = args.output.name
    if not args.output.endswith('.jpg'):
        args.output = args.output + '.jpg'

    result = dirim(vars(args))
    result.save(args.output)

###############################################################################

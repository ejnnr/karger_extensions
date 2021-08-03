#!/bin/bash

set -euo pipefail

mkdir -p data
cd data

################################################
# Grabcut                                      #
################################################

curl https://www.robots.ox.ac.uk/~vgg/data/iseg/data/images.tgz -o images.tgz
curl https://www.robots.ox.ac.uk/~vgg/data/iseg/data/images-gt.tgz -o images-gt.tgz
curl https://www.robots.ox.ac.uk/~vgg/data/iseg/data/images-labels.tgz -o images-labels.tgz

tar --extract --file images.tgz
tar --extract --file images-gt.tgz
tar --extract --file images-labels.tgz

rm images.tgz images-gt.tgz images-labels.tgz

# remove the '-anno' part of label file names
cd images-labels
for file in ./*; do
    mv -- "$file" "${file/-anno/}"
done
cd -

# now we remove all but the actual Grabcut images
# (the dataset we downloaded contains additional ones)
for folder in images images-gt images-labels; do
    cd "$folder"
    for file in *; do
        # the sed command removes the extension
        name="$(echo $file | sed 's/\.[^.]*$//')"
        # if the image is not in grabcut.txt, we delete it
        if ! grep -q "$name" ../../grabcut.txt; then
            rm "$file"
        fi
    done
    cd -
done

# make sure all images have the same format for ease
# of later processing (we use jpg)
cd images
mogrify -format jpg *.bmp
cd -

mv images-labels seeds
mv images-gt ground_truth

################################################
# HED weights for Grabcut                      #
################################################

curl https://ejnnr.github.io/hed_grabcut.zip -o hed_grabcut.zip
unzip hed_grabcut.zip -d hed
rm hed_grabcut.zip

################################################
# USPS                                         #
################################################

curl https://web.stanford.edu/~hastie/ElemStatLearn/datasets/zip.train.gz -o zip.train.gz
gzip -d zip.train.gz

# go back out of /data directory
cd ..

# convert the USPS data to .h5
python src/read_usps.py
rm data/zip.train
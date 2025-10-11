#!/bin/bash
cd /home/lips/20251005_ananti/cgv_js_files
while IFS= read -r url
do
  filename=$(basename "$url")
  echo "Downloading $filename..."
  curl -s "$url" -o "$filename"
done < js_urls.txt
echo "Download complete!"
ls -lh | wc -l

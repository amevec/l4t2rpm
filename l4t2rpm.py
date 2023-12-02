#!/usr/bin/python3

from concurrent.futures import ThreadPoolExecutor, as_completed
from html.parser import HTMLParser
from pathlib import Path
from tqdm import tqdm
import subprocess
import requests
import argparse
import os

firstFind = False
inVersion = False
inFocus = False
urls = []

class L4T2RPMParser(HTMLParser):
    def handle_starttag(self, tag, attrs):
        global urls
        if (inFocus and tag == "a"):
            urls.append(attrs[0][1])

    def handle_endtag(self, tag):
        global inFocus
        global inVersion
        if (inFocus and tag == "table"):
            inFocus = False
            inVersion = False

    def handle_data(self, data):
        global firstFind
        global inFocus
        global inVersion
        if (inVersion and data == args.target):
            inFocus = True
        if (firstFind and data == args.jetpack):
            inVersion = True
        if (data == args.jetpack):
            firstFind = True

def download_file(url, cache):
    response = requests.get(url, stream=True)
    total_size_in_byte = int(response.headers.get('content-length', 0))
    fname = url.rsplit('/',1)[1]
    pbar = tqdm(total=total_size_in_byte, desc=fname, unit='iB', unit_scale=True)
    with open(cache + fname, "wb") as handle:
        for chunk in response.iter_content(chunk_size=args.blocksize):
            pbar.update(len(chunk))
            handle.write(chunk)
        pbar.close()

def convert_file(file):
    FNULL = open(os.devnull, 'w')
    subprocess.call(["alien", "--scripts", "-r", "--target=aarch64", file], stdout=FNULL, stderr=subprocess.STDOUT) 

parser = argparse.ArgumentParser("l4t2rpm", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("--url", nargs="?", default="https://repo.download.nvidia.com/jetson/", help="The URL location of the Jetson repo", type=str)
parser.add_argument("--jetpack", nargs="?", default="Jetpack 5.1.2", help="The Jetpack target version", type=str)
parser.add_argument("--target", nargs="?", default="common", help="The target platform. For example: t234 or common", type=str)
parser.add_argument("--no-download", help="Disable file downloads", dest="download", action="store_false")
parser.add_argument("--no-convert", help="Disable file conversions", dest="convert", action='store_false')
parser.add_argument("--blocksize", nargs="?", default=1024, help="Block size for file downloads", type=int)
parser.set_defaults(download=True)
parser.set_defaults(convert=True)

args = parser.parse_args()

response = requests.get(args.url)
parser = L4T2RPMParser()
parser.feed(response.text)

cache = os.getcwd() + "/l4t2rpm/cache/" + args.jetpack.split(" ")[1] + "/" + args.target
debCache = cache + "/debs/"
rpmCache = cache + "/rpms/"
os.makedirs(debCache, exist_ok=True)
os.makedirs(rpmCache, exist_ok=True)

if (args.download):
    print("Downloading files from: " + args.url + " for Jetpack: " + args.jetpack + " with target: " + args.target)
    for url in urls:
        download_file(url, debCache)
    print("Downloads completed!")
else:
    print("Skipping downloads...")

if (args.convert):
    print("Converting files from: " + debCache)
    debs = list(Path(debCache).glob('*.deb'))
    os.chdir(rpmCache)
    with tqdm(total=len(debs), unit="files") as pbar:
        with ThreadPoolExecutor(max_workers=len(debs)) as ex:
            futures = [ex.submit(convert_file, deb) for deb in debs]
            for future in as_completed(futures):
                result = future.result()
                pbar.update(1)
else:
    print("Skipping conversion...")
